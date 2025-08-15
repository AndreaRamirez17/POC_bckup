package banamex.gating

import future.keywords.if
import future.keywords.in

# IMPORTANT: This Rego policy is for reference only
# The actual ABAC logic is now handled by Permit.io cloud configuration
# with Safe Deployment Gate Resource Set (criticalCount = 0)

# Default deny for demonstration purposes
default allow = false

# Safe Deployment Gate Logic (for reference)
# In Permit.io configuration:
# - Resource Set: "Safe Deployment Gate" matches when criticalCount = 0
# - Developers get deploy permission ONLY on Safe Deployment Gate
# - Critical vulnerabilities (criticalCount > 0) fall back to base deployment resource
# - Only editor/Security Officer roles have deploy permission on base deployment

# Reference vulnerability analysis functions
critical_vulnerabilities_present if {
    input.resource.attributes.criticalCount > 0
}

high_vulnerabilities_present if {
    input.resource.attributes.highCount > 0
}

medium_vulnerabilities_present if {
    input.resource.attributes.mediumCount > 0
}

# Safe deployment check (matches Permit.io Resource Set condition)
safe_deployment if {
    input.resource.attributes.criticalCount == 0
}

# Risk assessment for reference
risk_level = "CRITICAL" if {
    critical_vulnerabilities_present
} else = "HIGH" if {
    high_vulnerabilities_present
} else = "MEDIUM" if {
    medium_vulnerabilities_present
} else = "LOW"

# Vulnerability summary for auditing
vulnerability_summary = {
    "critical": input.resource.attributes.criticalCount,
    "high": input.resource.attributes.highCount,
    "medium": input.resource.attributes.mediumCount,
    "low": input.resource.attributes.lowCount,
    "total": input.resource.attributes.criticalCount + 
             input.resource.attributes.highCount + 
             input.resource.attributes.mediumCount + 
             input.resource.attributes.lowCount,
    "risk_level": risk_level,
    "safe_deployment": safe_deployment
}

# Gate decision logic (for reference - actual decisions made by Permit.io)
gate_decision = {
    "action": "BLOCK",
    "reason": "Critical vulnerabilities present - requires override",
    "gate_type": "HARD_GATE"
} if {
    critical_vulnerabilities_present
    input.user.attributes.role != "editor"
    input.user.attributes.role != "Security Officer"
} else = {
    "action": "OVERRIDE",
    "reason": "Editor/Security Officer override for critical vulnerabilities",
    "gate_type": "OVERRIDE_GATE"
} if {
    critical_vulnerabilities_present
    input.user.attributes.role in ["editor", "Security Officer"]
} else = {
    "action": "WARNING",
    "reason": "High severity vulnerabilities detected",
    "gate_type": "SOFT_GATE"
} if {
    high_vulnerabilities_present
} else = {
    "action": "INFO",
    "reason": "Medium severity vulnerabilities detected",
    "gate_type": "INFO_GATE"
} else = {
    "action": "PASS",
    "reason": "No significant vulnerabilities detected",
    "gate_type": "CLEAN_GATE"
}

# Comprehensive evaluation result for auditing
evaluation_result = {
    "vulnerability_summary": vulnerability_summary,
    "gate_decision": gate_decision,
    "user": {
        "key": input.user.key,
        "role": input.user.attributes.role
    },
    "resource": {
        "type": input.resource.type,
        "safe_deployment": safe_deployment
    },
    "timestamp": time.now_ns(),
    "policy_version": "2.0.0-safe-deployment-gate"
}

# Main allow decision (NOTE: Actual authorization handled by Permit.io cloud)
# This policy serves as documentation and audit trail
allow = true if {
    # This Rego policy is informational only
    # Real authorization decisions are made by Permit.io Resource Sets:
    # - Safe Deployment Gate (criticalCount = 0) → Developer allowed
    # - Base Deployment (criticalCount > 0) → Only editor/Security Officer allowed
    true
}

# Return evaluation details for audit logging
response = evaluation_result