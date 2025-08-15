#!/bin/bash

# Test Payload Generator for Permit.io Security Gates
# Usage: ./test-payload.sh [CRITICAL] [HIGH] [MEDIUM] [LOW] [USER_ROLE] [USER_KEY]
# Example: ./test-payload.sh 0 3 5 2 developer test-developer-user

# Default values (critical vulnerabilities for hard gate test)
CRITICAL_COUNT=${1:-7}
HIGH_COUNT=${2:-25}
MEDIUM_COUNT=${3:-19}
LOW_COUNT=${4:-9}
USER_ROLE=${5:-ci-pipeline}
USER_KEY=${6:-github-actions}

# Generate appropriate vulnerability arrays based on counts
generate_vulns() {
    local count=$1
    local severity=$2
    
    if [ "$count" -eq 0 ]; then
        echo "[]"
    else
        # Generate simplified vulnerability objects
        local vulns="["
        for ((i=1; i<=count && i<=5; i++)); do  # Limit to 5 for performance
            if [ $i -gt 1 ]; then vulns="$vulns,"; fi
            vulns="$vulns{\"id\":\"SNYK-TEST-$severity-$i\",\"severity\":\"$severity\",\"title\":\"Test $severity vulnerability $i\"}"
        done
        vulns="$vulns]"
        echo "$vulns"
    fi
}

CRITICAL_VULNS=$(generate_vulns $CRITICAL_COUNT "critical")
HIGH_VULNS=$(generate_vulns $HIGH_COUNT "high")
MEDIUM_VULNS=$(generate_vulns $MEDIUM_COUNT "medium")

TOTAL_COUNT=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))

cat <<PAYLOAD
{
  "user": {
    "key": "$USER_KEY",
    "attributes": {
      "role": "$USER_ROLE"
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
    "environment": "development",
    "repository": "unknown",
    "commit": "unknown",
    "workflow": "manual"
  }
}
PAYLOAD
