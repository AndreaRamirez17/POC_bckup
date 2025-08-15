#!/bin/bash

# SonarQube Quality Gate Analysis Script
# This script analyzes SonarQube quality gate results and determines deployment eligibility
# It integrates with the existing security gating system

set -e

# Source .env file if it exists and environment variables are not already set
if [ -f ".env" ] && [ -z "$SONAR_TOKEN" ]; then
    source .env
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_KEY="${SONAR_PROJECT_KEY:-cicd-pipeline-poc}"
SONAR_HOST="${SONAR_HOST_URL:-https://sonarcloud.io}"
QUALITY_GATE_STATUS="UNKNOWN"
EXIT_CODE=0

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k, --project-key KEY     SonarQube project key (default: from env or cicd-pipeline-poc)"
    echo "  -t, --token TOKEN         SonarQube token (default: from SONAR_TOKEN env)"
    echo "  -o, --output FILE         Output results to JSON file"
    echo "  -w, --wait                Wait for quality gate computation"
    echo "  -h, --help                Display this help message"
    echo ""
    echo "Environment Variables:"
    echo "  SONAR_TOKEN              SonarQube authentication token"
    echo "  SONAR_PROJECT_KEY        Project key in SonarQube"
    echo "  SONAR_HOST_URL          SonarQube server URL (default: https://sonarcloud.io)"
    exit 0
}

# Parse command line arguments
OUTPUT_FILE=""
WAIT_FOR_QG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--project-key)
            PROJECT_KEY="$2"
            shift 2
            ;;
        -t|--token)
            SONAR_TOKEN="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_FOR_QG=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$SONAR_TOKEN" ]; then
    echo -e "${RED}Error: SONAR_TOKEN is not set${NC}"
    echo "Please set the SONAR_TOKEN environment variable or use -t option"
    exit 2
fi

echo "========================================="
echo "   SonarQube Quality Gate Analysis"
echo "========================================="
echo ""
echo "Project Key: $PROJECT_KEY"
echo "SonarQube URL: $SONAR_HOST"
echo ""

# Function to get project status from SonarQube
get_project_status() {
    local response
    response=$(curl -s -u "$SONAR_TOKEN:" \
        "${SONAR_HOST}/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" \
        2>/dev/null || echo '{"error": "Failed to connect"}')
    
    echo "$response"
}

# Function to get project metrics
get_project_metrics() {
    local metrics="bugs,vulnerabilities,security_hotspots,code_smells,coverage,duplicated_lines_density,security_rating,reliability_rating,sqale_rating"
    local response
    response=$(curl -s -u "$SONAR_TOKEN:" \
        "${SONAR_HOST}/api/measures/component?component=${PROJECT_KEY}&metricKeys=${metrics}" \
        2>/dev/null || echo '{"error": "Failed to connect"}')
    
    echo "$response"
}

# Function to wait for quality gate computation
wait_for_quality_gate() {
    local max_attempts=60  # 5 minutes max wait (60 * 5 seconds)
    local attempt=0
    
    echo "Waiting for quality gate computation..."
    
    while [ $attempt -lt $max_attempts ]; do
        local status_response
        status_response=$(get_project_status)
        
        local qg_status
        qg_status=$(echo "$status_response" | grep -o '"status":"[^"]*' | cut -d'"' -f4 || echo "")
        
        if [ -n "$qg_status" ] && [ "$qg_status" != "NONE" ]; then
            echo -e "${GREEN}Quality gate computed: $qg_status${NC}"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    echo ""
    echo -e "${YELLOW}Warning: Quality gate computation timeout${NC}"
    return 1
}

# Wait for quality gate if requested
if [ "$WAIT_FOR_QG" = true ]; then
    wait_for_quality_gate
fi

# Get project quality gate status
echo "Fetching quality gate status..."
QG_RESPONSE=$(get_project_status)

# Check for errors
if echo "$QG_RESPONSE" | grep -q '"error"'; then
    ERROR_MSG=$(echo "$QG_RESPONSE" | grep -o '"error":"[^"]*' | cut -d'"' -f4 || echo "Unknown error")
    echo -e "${RED}Error fetching quality gate status: $ERROR_MSG${NC}"
    exit 2
fi

# Parse quality gate status
if command -v jq &> /dev/null; then
    # Use jq for proper JSON parsing if available
    QUALITY_GATE_STATUS=$(echo "$QG_RESPONSE" | jq -r '.projectStatus.status // "UNKNOWN"' 2>/dev/null)
else
    # Fallback to more specific grep pattern targeting the main projectStatus.status
    QUALITY_GATE_STATUS=$(echo "$QG_RESPONSE" | grep -o '"projectStatus"[^}]*"status":"[^"]*' | grep -o '"status":"[^"]*' | head -n 1 | cut -d'"' -f4 || echo "UNKNOWN")
fi

# Get detailed metrics
echo "Fetching project metrics..."
METRICS_RESPONSE=$(get_project_metrics)

# Parse individual metrics
parse_metric() {
    local metric_name=$1
    local response=$2
    # Use jq if available for better parsing, otherwise fallback to grep
    if command -v jq &> /dev/null; then
        local value=$(echo "$response" | jq -r ".component.measures[] | select(.metric==\"$metric_name\") | .value" 2>/dev/null || echo "")
        if [ -z "$value" ] || [ "$value" = "null" ]; then
            echo "0"
        else
            echo "$value"
        fi
    else
        echo "$response" | grep -o "\"metric\":\"$metric_name\"[^}]*\"value\":\"[^\"]*" | grep -o '"value":"[^"]*' | cut -d'"' -f4 || echo "0"
    fi
}

# Extract metrics with default values
BUGS=$(parse_metric "bugs" "$METRICS_RESPONSE")
VULNERABILITIES=$(parse_metric "vulnerabilities" "$METRICS_RESPONSE")
SECURITY_HOTSPOTS=$(parse_metric "security_hotspots" "$METRICS_RESPONSE")
CODE_SMELLS=$(parse_metric "code_smells" "$METRICS_RESPONSE")
COVERAGE=$(parse_metric "coverage" "$METRICS_RESPONSE")
DUPLICATED_LINES=$(parse_metric "duplicated_lines_density" "$METRICS_RESPONSE")
SECURITY_RATING=$(parse_metric "security_rating" "$METRICS_RESPONSE")
RELIABILITY_RATING=$(parse_metric "reliability_rating" "$METRICS_RESPONSE")
MAINTAINABILITY_RATING=$(parse_metric "sqale_rating" "$METRICS_RESPONSE")

# Ensure numeric values have defaults
BUGS=${BUGS:-0}
VULNERABILITIES=${VULNERABILITIES:-0}
SECURITY_HOTSPOTS=${SECURITY_HOTSPOTS:-0}
CODE_SMELLS=${CODE_SMELLS:-0}
COVERAGE=${COVERAGE:-0}
DUPLICATED_LINES=${DUPLICATED_LINES:-0}
SECURITY_RATING=${SECURITY_RATING:-0}
RELIABILITY_RATING=${RELIABILITY_RATING:-0}
MAINTAINABILITY_RATING=${MAINTAINABILITY_RATING:-0}

# Convert ratings from numbers to letters
convert_rating() {
    case $1 in
        1|1.0) echo "A" ;;
        2|2.0) echo "B" ;;
        3|3.0) echo "C" ;;
        4|4.0) echo "D" ;;
        5|5.0) echo "E" ;;
        *) echo "?" ;;
    esac
}

SECURITY_GRADE=$(convert_rating "$SECURITY_RATING")
RELIABILITY_GRADE=$(convert_rating "$RELIABILITY_RATING")
MAINTAINABILITY_GRADE=$(convert_rating "$MAINTAINABILITY_RATING")

# Display results
echo ""
echo "Quality Gate Status: $QUALITY_GATE_STATUS"
echo ""
echo "Project Metrics:"
echo "================"
echo -e "Bugs:                  ${BUGS}"
echo -e "Vulnerabilities:       ${VULNERABILITIES}"
echo -e "Security Hotspots:     ${SECURITY_HOTSPOTS}"
echo -e "Code Smells:           ${CODE_SMELLS}"
echo -e "Coverage:              ${COVERAGE}%"
echo -e "Duplicated Lines:      ${DUPLICATED_LINES}%"
echo -e "Security Rating:       ${SECURITY_GRADE}"
echo -e "Reliability Rating:    ${RELIABILITY_GRADE}"
echo -e "Maintainability Rating: ${MAINTAINABILITY_GRADE}"
echo ""

# Determine gate decision based on quality gate status and metrics
determine_gate_decision() {
    local decision="PASS"
    local reason=""
    
    # Check quality gate status
    case "$QUALITY_GATE_STATUS" in
        "OK")
            decision="PASS"
            reason="Quality gate passed"
            EXIT_CODE=0
            ;;
        "WARN")
            decision="WARNING"
            reason="Quality gate has warnings"
            EXIT_CODE=1
            ;;
        "ERROR")
            decision="FAIL"
            reason="Quality gate failed"
            EXIT_CODE=2
            ;;
        *)
            decision="UNKNOWN"
            reason="Unable to determine quality gate status"
            EXIT_CODE=1
            ;;
    esac
    
    # Additional checks for critical metrics (with proper integer checks)
    if [ -n "$VULNERABILITIES" ] && [ "$VULNERABILITIES" -gt 0 ] 2>/dev/null || 
       [ -n "$SECURITY_HOTSPOTS" ] && [ "$SECURITY_HOTSPOTS" -gt 0 ] 2>/dev/null; then
        if [ "$decision" = "PASS" ]; then
            decision="WARNING"
            reason="$reason; Security issues detected"
            EXIT_CODE=1
        fi
    fi
    
    # Check security rating
    if [ "$SECURITY_GRADE" = "D" ] || [ "$SECURITY_GRADE" = "E" ]; then
        decision="FAIL"
        reason="$reason; Poor security rating ($SECURITY_GRADE)"
        EXIT_CODE=2
    fi
    
    echo "$decision|$reason"
}

# Get gate decision
GATE_RESULT=$(determine_gate_decision)
GATE_DECISION=$(echo "$GATE_RESULT" | cut -d'|' -f1)
GATE_REASON=$(echo "$GATE_RESULT" | cut -d'|' -f2)

echo "========================================="
echo "         Gate Decision"
echo "========================================="

case "$GATE_DECISION" in
    "PASS")
        echo -e "${GREEN}✓ GATE PASSED${NC}"
        echo "Reason: $GATE_REASON"
        ;;
    "WARNING")
        echo -e "${YELLOW}⚠ GATE WARNING${NC}"
        echo "Reason: $GATE_REASON"
        ;;
    "FAIL")
        echo -e "${RED}✗ GATE FAILED${NC}"
        echo "Reason: $GATE_REASON"
        ;;
    *)
        echo -e "${YELLOW}? GATE UNKNOWN${NC}"
        echo "Reason: $GATE_REASON"
        ;;
esac

# Generate JSON output if requested
if [ -n "$OUTPUT_FILE" ]; then
    cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project_key": "$PROJECT_KEY",
  "quality_gate": {
    "status": "$QUALITY_GATE_STATUS",
    "decision": "$GATE_DECISION",
    "reason": "$GATE_REASON"
  },
  "metrics": {
    "bugs": $BUGS,
    "vulnerabilities": $VULNERABILITIES,
    "security_hotspots": $SECURITY_HOTSPOTS,
    "code_smells": $CODE_SMELLS,
    "coverage": $COVERAGE,
    "duplicated_lines_density": $DUPLICATED_LINES,
    "ratings": {
      "security": "$SECURITY_GRADE",
      "reliability": "$RELIABILITY_GRADE",
      "maintainability": "$MAINTAINABILITY_GRADE"
    }
  },
  "gate_result": {
    "decision": "$GATE_DECISION",
    "exit_code": $EXIT_CODE
  }
}
EOF
    echo ""
    echo "Results saved to: $OUTPUT_FILE"
fi

# Integration with existing security gates
echo ""
echo "========================================="
echo "   Integration with Security Gates"
echo "========================================="

# Check if we should integrate with Permit.io gates
if [ -f "permit-gating/scripts/evaluate-gates.sh" ]; then
    echo "Combining with security vulnerability gates..."
    
    # Create combined gate evaluation
    COMBINED_EXIT_CODE=$EXIT_CODE
    
    # If SonarQube fails, that takes precedence
    if [ $EXIT_CODE -eq 2 ]; then
        echo -e "${RED}Code quality gate failed - deployment blocked${NC}"
    elif [ $EXIT_CODE -eq 1 ]; then
        echo -e "${YELLOW}Code quality warnings detected - review recommended${NC}"
    else
        echo -e "${GREEN}Code quality gate passed${NC}"
    fi
    
    exit $COMBINED_EXIT_CODE
else
    exit $EXIT_CODE
fi