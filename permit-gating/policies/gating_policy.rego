package banamex.gating

import future.keywords.if
import future.keywords.in

# Default deny
default allow = false

# Hard Gate: FAIL on Critical vulnerabilities
hard_gate_fail if {
    input.resource.attributes.criticalCount > 0
}

# Soft Gate: WARN on High vulnerabilities  
soft_gate_warn if {
    input.resource.attributes.highCount > 0
}

# Medium vulnerabilities informational warning
medium_warn if {
    input.resource.attributes.mediumCount > 0
}

# Main allow decision with detailed response
allow = response if {
    response := evaluate_gates
}

# Evaluate all gates and return structured response
evaluate_gates = result if {
    # Check for hard gate violations
    hard_gate_violations := [msg |
        hard_gate_fail
        msg := {
            "type": "CRITICAL_VULNERABILITY",
            "severity": "CRITICAL",
            "action": "FAIL",
            "message": sprintf("Found %d critical vulnerabilities - Build must be stopped", [input.resource.attributes.criticalCount]),
            "vulnerabilities": input.resource.attributes.vulnerabilities.critical
        }
    ]
    
    # Check for soft gate violations
    soft_gate_violations := [msg |
        soft_gate_warn
        not hard_gate_fail  # Only warn if not already failing
        msg := {
            "type": "HIGH_VULNERABILITY",
            "severity": "HIGH",
            "action": "WARN",
            "message": sprintf("Found %d high severity vulnerabilities - Review recommended", [input.resource.attributes.highCount]),
            "vulnerabilities": input.resource.attributes.vulnerabilities.high
        }
    ]
    
    # Check for medium severity warnings
    medium_violations := [msg |
        medium_warn
        not hard_gate_fail  # Only warn if not already failing
        not soft_gate_warn  # Only warn if not already warning for high
        msg := {
            "type": "MEDIUM_VULNERABILITY",
            "severity": "MEDIUM",
            "action": "INFO",
            "message": sprintf("Found %d medium severity vulnerabilities - Consider reviewing", [input.resource.attributes.mediumCount]),
            "vulnerabilities": input.resource.attributes.vulnerabilities.medium
        }
    ]
    
    # Combine all violations
    all_violations := array.concat(hard_gate_violations, array.concat(soft_gate_violations, medium_violations))
    
    # Determine overall result
    overall_result := determine_overall_result(all_violations)
    
    # Build final response
    result := {
        "allow": overall_result.allow,
        "decision": overall_result.decision,
        "timestamp": time.now_ns(),
        "project_id": input.resource.id,
        "summary": {
            "critical_count": input.resource.attributes.criticalCount,
            "high_count": input.resource.attributes.highCount,
            "medium_count": input.resource.attributes.mediumCount,
            "total_vulnerabilities": input.resource.attributes.summary.total
        },
        "violations": all_violations,
        "recommendations": get_recommendations(overall_result.decision)
    }
}

# Determine overall result based on violations
determine_overall_result(violations) = result if {
    count(violations) == 0
    result := {
        "allow": true,
        "decision": "PASS"
    }
} else = result if {
    some violation in violations
    violation.action == "FAIL"
    result := {
        "allow": false,
        "decision": "FAIL"
    }
} else = result if {
    some violation in violations
    violation.action == "WARN"
    result := {
        "allow": true,
        "decision": "PASS_WITH_WARNINGS"
    }
} else = result if {
    result := {
        "allow": true,
        "decision": "PASS_WITH_INFO"
    }
}

# Get recommendations based on decision
get_recommendations(decision) = recommendations if {
    decision == "FAIL"
    recommendations := [
        "Critical vulnerabilities detected - immediate action required",
        "Update vulnerable dependencies to secure versions",
        "Run 'snyk fix' to apply available patches",
        "Review security advisory for each critical vulnerability",
        "Consider requesting an exception if remediation is not immediately possible"
    ]
} else = recommendations if {
    decision == "PASS_WITH_WARNINGS"
    recommendations := [
        "High severity vulnerabilities detected - review recommended",
        "Plan remediation for high severity issues",
        "Monitor for available patches",
        "Consider impact on production systems"
    ]
} else = recommendations if {
    decision == "PASS_WITH_INFO"
    recommendations := [
        "Medium severity vulnerabilities detected",
        "Schedule remediation in next maintenance window",
        "Keep dependencies up to date"
    ]
} else = recommendations if {
    recommendations := ["No vulnerabilities detected - good job maintaining security!"]
}