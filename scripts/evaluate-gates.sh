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
PERMIT_API_KEY="${PERMIT_API_KEY}"
SNYK_RESULTS_FILE="${1:-snyk-results.json}"

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
    
    # Extract vulnerability details with error handling
    CRITICAL_VULNS=$(jq -c '.vulnerabilities | map(select(.severity == "critical")) | map({id: .id, title: .title, packageName: .packageName, version: .version})' "$results_file" 2>/dev/null || echo "[]")
    HIGH_VULNS=$(jq -c '.vulnerabilities | map(select(.severity == "high")) | map({id: .id, title: .title, packageName: .packageName, version: .version})' "$results_file" 2>/dev/null || echo "[]")
    MEDIUM_VULNS=$(jq -c '.vulnerabilities | map(select(.severity == "medium")) | map({id: .id, title: .title, packageName: .packageName, version: .version})' "$results_file" 2>/dev/null || echo "[]")
}

# Function to create Permit.io request payload
create_permit_payload() {
    cat <<EOF
{
  "user": {
    "key": "github-actions",
    "attributes": {
      "role": "ci-pipeline"
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
      "scanTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
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
    
    print_color "$YELLOW" "Calling Permit.io PDP for gate evaluation..."
    
    # Make the API call with timeout and debug output
    print_color "$YELLOW" "Making PDP call to: ${PDP_URL}/allowed"
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "Using API Key: ${PERMIT_API_KEY:0:20}..."
    fi
    
    response=$(timeout 10s curl -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${PERMIT_API_KEY}" \
        -d "$payload" \
        "${PDP_URL}/allowed" 2>&1) || {
        print_color "$RED" "Error: Failed to call Permit.io PDP"
        print_color "$RED" "Response: $response"
        return 2
    }
    
    echo "$response"
}

# Function to evaluate gate response
evaluate_response() {
    local response=$1
    local allow
    local decision
    local violations
    
    # Parse response with error handling
    allow=$(echo "$response" | jq -r '.allow // false' 2>/dev/null || echo "false")
    decision=$(echo "$response" | jq -r '.decision // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
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
        "PASS_WITH_WARNINGS")
            print_color "$YELLOW" "⚠️  DECISION: PASS WITH WARNINGS - Soft gate triggered"
            echo ""
            echo "📋 Warnings:"
            echo "$response" | jq -r '.violations[] | "   • \(.message)"'
            echo ""
            print_color "$YELLOW" "⚡ High severity vulnerabilities detected. Review recommended before production deployment."
            return 1
            ;;
        "PASS_WITH_INFO")
            print_color "$YELLOW" "ℹ️  DECISION: PASS WITH INFO - Informational findings"
            echo ""
            echo "📋 Information:"
            echo "$response" | jq -r '.violations[] | "   • \(.message)"'
            echo ""
            print_color "$YELLOW" "💡 Medium severity vulnerabilities detected. Consider remediation in next maintenance window."
            return 1
            ;;
        "FAIL")
            print_color "$RED" "❌ DECISION: FAIL - Hard gate triggered"
            echo ""
            echo "🚫 Blocking Issues:"
            echo "$response" | jq -r '.violations[] | "   • \(.message)"'
            echo ""
            
            # Display critical vulnerabilities
            if [ "$CRITICAL_COUNT" -gt 0 ]; then
                echo "🔴 Critical Vulnerabilities Found:"
                echo "$response" | jq -r '.violations[].vulnerabilities[]? | "   • \(.packageName)@\(.version): \(.title)"'
                echo ""
            fi
            
            print_color "$RED" "🛑 DEPLOYMENT BLOCKED: Critical vulnerabilities must be resolved before deployment."
            echo ""
            echo "📌 Recommendations:"
            echo "$response" | jq -r '.recommendations[]? | "   • \(.)"'
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