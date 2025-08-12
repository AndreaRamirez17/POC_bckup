#!/bin/bash

# CI/CD Security Gate Evaluation Script
# This script evaluates security gates using Permit.io PDP
# Exit codes:
#   0 - All gates passed
#   1 - Soft gate warning (non-blocking)
#   2 - Hard gate failure (blocking)

set -e

# Configuration
PDP_URL="${PDP_URL:-http://localhost:7001}"
SNYK_RESULTS_FILE="${1:-snyk-scanning/results/snyk-results.json}"

# Try to load .env file if it exists and PERMIT_API_KEY is not already set
if [ -z "$PERMIT_API_KEY" ]; then
    # Get the script's directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    ENV_FILE="${SCRIPT_DIR}/../../.env"
    
    if [ -f "$ENV_FILE" ]; then
        echo "Loading environment variables from .env file..." >&2
        # Export variables while sourcing
        set -a
        source "$ENV_FILE"
        set +a
    fi
fi

# Get the API key from environment
PERMIT_API_KEY="${PERMIT_API_KEY}"

# Check if PERMIT_API_KEY is set
if [ -z "$PERMIT_API_KEY" ]; then
    echo "Error: PERMIT_API_KEY environment variable is not set"
    echo "Please set it by running: export PERMIT_API_KEY=your_api_key"
    echo "Or create a .env file in the project root with: PERMIT_API_KEY=your_api_key"
    exit 2
fi

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if PDP is ready
check_pdp_ready() {
    local max_attempts=30
    local attempt=1
    
    print_color "$YELLOW" "Checking PDP readiness..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "http://localhost:7001/healthy" > /dev/null 2>&1; then
            print_color "$GREEN" "✓ PDP is ready"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts: PDP not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_color "$RED" "✗ PDP failed to become ready after $max_attempts attempts"
    return 1
}

# Function to parse Snyk results
parse_snyk_results() {
    local results_file=$1
    
    if [ ! -f "$results_file" ]; then
        print_color "$RED" "Error: Snyk results file not found: $results_file"
        exit 2
    fi
    
    # Extract vulnerability counts with error handling
    CRITICAL_COUNT=$(jq -r '.vulnerabilities | map(select(.severity == "critical")) | length // 0' "$results_file" 2>/dev/null || echo "0")
    HIGH_COUNT=$(jq -r '.vulnerabilities | map(select(.severity == "high")) | length // 0' "$results_file" 2>/dev/null || echo "0")
    MEDIUM_COUNT=$(jq -r '.vulnerabilities | map(select(.severity == "medium")) | length // 0' "$results_file" 2>/dev/null || echo "0")
    LOW_COUNT=$(jq -r '.vulnerabilities | map(select(.severity == "low")) | length // 0' "$results_file" 2>/dev/null || echo "0")
    TOTAL_COUNT=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))
    
    # Extract vulnerability details with error handling (simplified to avoid large payloads)
    # Limiting to first 5 vulnerabilities of each type to avoid payload size issues
    CRITICAL_VULNS=$(timeout 5s jq -c '.vulnerabilities | map(select(.severity == "critical")) | .[0:5] | map({id: .id, title: .title, packageName: .packageName, version: .version})' "$results_file" 2>/dev/null || echo "[]")
    HIGH_VULNS=$(timeout 5s jq -c '.vulnerabilities | map(select(.severity == "high")) | .[0:5] | map({id: .id, title: .title, packageName: .packageName, version: .version})' "$results_file" 2>/dev/null || echo "[]")
    MEDIUM_VULNS=$(timeout 5s jq -c '.vulnerabilities | map(select(.severity == "medium")) | .[0:5] | map({id: .id, title: .title, packageName: .packageName, version: .version})' "$results_file" 2>/dev/null || echo "[]")
}

# Function to create Permit.io request payload
create_permit_payload() {
    # Allow role override via environment variable (default to ci-pipeline)
    local user_role="${USER_ROLE:-ci-pipeline}"
    local user_key="${USER_KEY:-github-actions}"
    
    cat <<EOF
{
  "user": {
    "key": "$user_key",
    "attributes": {
      "role": "$user_role"
    }
  },
  "action": "deploy",
  "resource": {
    "type": "deployment",
    "key": "$(uuidgen || echo 'deployment-001')",
    "tenant": "default",
    "attributes": {
      "criticalCount": $CRITICAL_COUNT,
      "highCount": $HIGH_COUNT,
      "mediumCount": $MEDIUM_COUNT,
      "lowCount": $LOW_COUNT,
      "vulnerabilities": {
        "critical": $CRITICAL_VULNS,
        "high": $HIGH_VULNS,
        "medium": $MEDIUM_VULNS
      },
      "summary": {
        "total": $TOTAL_COUNT,
        "critical": $CRITICAL_COUNT,
        "high": $HIGH_COUNT,
        "medium": $MEDIUM_COUNT,
        "low": $LOW_COUNT
      },
      "scanTimestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    }
  },
  "context": {
    "environment": "${GITHUB_REF_NAME:-development}",
    "repository": "${GITHUB_REPOSITORY:-unknown}",
    "commit": "${GITHUB_SHA:-unknown}",
    "workflow": "${GITHUB_WORKFLOW:-manual}"
  }
}
EOF
}

# Function to call Permit.io PDP
call_permit_pdp() {
    local payload=$1
    local response
    local http_status
    
    print_color "$YELLOW" "Calling Permit.io PDP for gate evaluation..." >&2
    
    # Make the API call with timeout and debug output
    print_color "$YELLOW" "Making PDP call to: ${PDP_URL}/allowed" >&2
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "Using API Key: ${PERMIT_API_KEY:0:20}..." >&2
    fi
    
    # Use curl with proper options to capture response and status separately
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${PERMIT_API_KEY}" \
        -d "$payload" \
        --connect-timeout 5 \
        --max-time 10 \
        "${PDP_URL}/allowed" 2>/dev/null)
    
    # Extract HTTP status code from the last line
    http_status=$(echo "$response" | tail -n1)
    # Extract response body (everything except the last line)
    response=$(echo "$response" | sed '$d')
    
    # Check HTTP status
    if [ "$http_status" != "200" ]; then
        print_color "$RED" "Error: PDP returned HTTP status $http_status" >&2
        if [ "$http_status" = "401" ] || [ "$http_status" = "403" ]; then
            print_color "$RED" "Authentication failed. Please check your PERMIT_API_KEY" >&2
        fi
        print_color "$RED" "Response: $response" >&2
        return 2
    fi
    
    # Validate JSON response
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        print_color "$RED" "Error: Invalid JSON response from PDP" >&2
        print_color "$RED" "Response: $response" >&2
        return 2
    fi
    
    echo "$response"
}

# Function to evaluate gate response
evaluate_response() {
    local response=$1
    local allow
    local decision="UNKNOWN"
    local violations
    
    # Parse response with error handling
    allow=$(echo "$response" | jq -r '.allow // false' 2>/dev/null || echo "false")
    
    # The PDP doesn't return a 'decision' field, so we need to determine it based on the response
    # Check if there's a debug field with error codes
    local error_code=$(echo "$response" | jq -r '.debug.abac.code // .debug.rbac.code // ""' 2>/dev/null || echo "")
    
    # Check if user has editor role override
    local is_editor_override=false
    if [ "$USER_ROLE" = "editor" ] && [ "$allow" = "true" ]; then
        is_editor_override=true
    fi
    
    # Determine decision based on allow field and vulnerability counts
    if [ "$allow" = "true" ]; then
        if [ "$is_editor_override" = "true" ] && [ "$CRITICAL_COUNT" -gt 0 ]; then
            decision="EDITOR_OVERRIDE"
        elif [ "$HIGH_COUNT" -gt 0 ]; then
            decision="PASS_WITH_WARNINGS"
        elif [ "$MEDIUM_COUNT" -gt 0 ]; then
            decision="PASS_WITH_INFO"
        else
            decision="PASS"
        fi
    else
        # Check if it's due to critical vulnerabilities
        if [ "$CRITICAL_COUNT" -gt 0 ]; then
            decision="FAIL"
        elif [ -n "$error_code" ]; then
            # If there's an error code, it means the policy evaluation failed
            decision="FAIL"
        else
            decision="UNKNOWN"
        fi
    fi
    violations=$(echo "$response" | jq -r '.violations // []' 2>/dev/null || echo "[]")
    
    # Display results
    echo ""
    print_color "$YELLOW" "════════════════════════════════════════════════════════════════"
    print_color "$YELLOW" "                    SECURITY GATE EVALUATION RESULTS"
    print_color "$YELLOW" "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Display vulnerability summary
    echo "📊 Vulnerability Summary:"
    echo "   • Critical: $CRITICAL_COUNT"
    echo "   • High:     $HIGH_COUNT"
    echo "   • Medium:   $MEDIUM_COUNT"
    echo "   • Low:      $LOW_COUNT"
    echo "   • Total:    $TOTAL_COUNT"
    echo ""
    
    # Display decision
    case "$decision" in
        "PASS")
            print_color "$GREEN" "✅ DECISION: PASS - All security gates passed"
            echo ""
            print_color "$GREEN" "🎉 No blocking vulnerabilities found. Deployment can proceed."
            return 0
            ;;
        "EDITOR_OVERRIDE")
            print_color "$YELLOW" "🔓 DECISION: EDITOR OVERRIDE - Deployment allowed with editor privileges"
            echo ""
            echo "⚠️  Editor Override Active:"
            echo "   • User Role: editor"
            echo "   • Critical vulnerabilities present: $CRITICAL_COUNT"
            echo ""
            if [ "$CRITICAL_COUNT" -gt 0 ]; then
                echo "🔴 Critical Vulnerabilities (Editor Override Applied):"
                echo "$CRITICAL_VULNS" | jq -r '.[] | "   • \(.packageName)@\(.version): \(.title)"' 2>/dev/null || echo "   Unable to display vulnerability details"
                echo ""
            fi
            print_color "$YELLOW" "⚡ DEPLOYMENT PROCEEDING: Editor has overridden security gates."
            echo "   Ensure critical vulnerabilities are addressed post-deployment."
            return 0
            ;;
        "PASS_WITH_WARNINGS")
            print_color "$YELLOW" "⚠️  DECISION: PASS WITH WARNINGS - Soft gate triggered"
            echo ""
            echo "📋 Warnings:"
            echo "   • $HIGH_COUNT high severity vulnerabilities detected"
            if [ "$HIGH_COUNT" -gt 0 ]; then
                echo ""
                echo "High severity vulnerabilities (showing first 5):"
                echo "$HIGH_VULNS" | jq -r '.[] | "   • \(.packageName)@\(.version): \(.title)"' 2>/dev/null || echo "   Unable to display vulnerability details"
            fi
            echo ""
            print_color "$YELLOW" "⚡ High severity vulnerabilities detected. Review recommended before production deployment."
            return 1
            ;;
        "PASS_WITH_INFO")
            print_color "$YELLOW" "ℹ️  DECISION: PASS WITH INFO - Informational findings"
            echo ""
            echo "📋 Information:"
            echo "   • $MEDIUM_COUNT medium severity vulnerabilities detected"
            if [ "$MEDIUM_COUNT" -gt 0 ]; then
                echo ""
                echo "Medium severity vulnerabilities (showing first 5):"
                echo "$MEDIUM_VULNS" | jq -r '.[] | "   • \(.packageName)@\(.version): \(.title)"' 2>/dev/null || echo "   Unable to display vulnerability details"
            fi
            echo ""
            print_color "$YELLOW" "💡 Medium severity vulnerabilities detected. Consider remediation in next maintenance window."
            return 1
            ;;
        "FAIL")
            print_color "$RED" "❌ DECISION: FAIL - Hard gate triggered"
            echo ""
            
            # Display reason from PDP debug information
            local reason=$(echo "$response" | jq -r '.debug.abac.reason // .debug.rbac.reason // "Policy evaluation failed"' 2>/dev/null || echo "Policy evaluation failed")
            echo "🚫 Blocking Issue: $reason"
            echo ""
            
            # Display critical vulnerabilities
            if [ "$CRITICAL_COUNT" -gt 0 ]; then
                echo "🔴 Critical Vulnerabilities Found ($CRITICAL_COUNT):"
                # Display the critical vulnerabilities from our parsed data
                echo "$CRITICAL_VULNS" | jq -r '.[] | "   • \(.packageName)@\(.version): \(.title)"' 2>/dev/null || echo "   Unable to display vulnerability details"
                echo ""
            fi
            
            print_color "$RED" "🛑 DEPLOYMENT BLOCKED: Critical vulnerabilities must be resolved before deployment."
            echo ""
            echo "📌 Recommendations:"
            echo "   • Review and fix critical vulnerabilities"
            echo "   • Update vulnerable dependencies to secure versions"
            echo "   • Run security scan again after fixes"
            return 2
            ;;
        *)
            print_color "$RED" "❓ DECISION: UNKNOWN - Unexpected response from PDP"
            echo "Response: $response"
            return 2
            ;;
    esac
}

# Main execution
main() {
    print_color "$YELLOW" "Starting Security Gate Evaluation..."
    echo ""
    
    # Check if running in CI environment
    if [ -n "$GITHUB_ACTIONS" ]; then
        echo "Running in GitHub Actions environment"
    else
        echo "Running in local environment"
    fi
    
    # Display user context if editor role is being used
    if [ "$USER_ROLE" = "editor" ]; then
        print_color "$YELLOW" "🔑 Running with editor role privileges"
        echo "   User: ${USER_KEY:-github-actions}"
        echo "   Role: editor"
        echo ""
    fi
    
    # Check PDP readiness
    check_pdp_ready || exit 2
    
    # Parse Snyk results
    print_color "$YELLOW" "Parsing Snyk scan results..."
    parse_snyk_results "$SNYK_RESULTS_FILE"
    
    # Create Permit payload
    PERMIT_PAYLOAD=$(create_permit_payload)
    
    # For debugging (only in debug mode)
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "Debug: Permit Payload:"
        echo "$PERMIT_PAYLOAD" | jq '.'
    fi
    
    # Call Permit PDP
    PERMIT_RESPONSE=$(call_permit_pdp "$PERMIT_PAYLOAD")
    
    # For debugging (only in debug mode)
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "Debug: Permit Response:"
        echo "$PERMIT_RESPONSE" | jq '.'
    fi
    
    # Evaluate response and determine exit code
    evaluate_response "$PERMIT_RESPONSE"
    EXIT_CODE=$?
    
    echo ""
    print_color "$YELLOW" "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Exit with appropriate code
    exit $EXIT_CODE
}

# Run main function
main "$@"