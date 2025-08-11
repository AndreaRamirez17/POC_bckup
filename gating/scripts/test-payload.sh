#\!/bin/bash
CRITICAL_COUNT=7
HIGH_COUNT=25
MEDIUM_COUNT=19
LOW_COUNT=9
CRITICAL_VULNS='[]'
HIGH_VULNS='[]'
MEDIUM_VULNS='[]'

cat <<PAYLOAD
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
        "total": 60,
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
