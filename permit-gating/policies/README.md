# Safe Deployment Gate Policies

This directory contains the policy definitions and configurations for the Permit.io-based Safe Deployment Gate security gating system using inverted ABAC logic.

## 🔄 Safe Deployment Gate Overview

The Safe Deployment Gate uses **inverted ABAC logic** - instead of blocking dangerous deployments, we **allow safe deployments**:

- **Resource Set**: "Safe Deployment Gate" matches when `criticalCount = 0`
- **Safe Deployments**: Developers can deploy when no critical vulnerabilities exist
- **Critical Vulnerabilities**: Fall back to base deployment resource (restricted access)
- **Override Capability**: Editor/Security Officer roles have permissions on both resources

## Policy Files

### `gating_policy.rego`
**Reference-only** Open Policy Agent (OPA) Rego policy for documentation purposes. The actual ABAC logic is now handled by Permit.io cloud configuration with Safe Deployment Gate Resource Set.

**Key Changes from v1.0**:
- Serves as documentation rather than active policy
- Shows Safe Deployment Gate logic for reference
- Actual authorization decisions made by Permit.io Resource Sets

### `permit_config.json`
Complete configuration schema for Safe Deployment Gate including:
- **Safe Deployment Gate Resource Set**: Matches `criticalCount = 0`
- **Base Deployment Resource**: Fallback for critical vulnerabilities
- **Role Definitions**: developer, editor, Security Officer, ci-pipeline
- **Permission Matrix**: Safe deployment access vs override capabilities

## Safe Deployment Gate Logic

### How It Works
1. **Vulnerability Scan**: Snyk scans code and generates vulnerability counts
2. **Resource Set Evaluation**: Permit.io evaluates request against Safe Deployment Gate condition
3. **Safe Deployment Check**: If `criticalCount = 0`, Safe Deployment Gate Resource Set matches
4. **Permission Check**: User's role determines access to matched resource
5. **Decision**: Allow, warn, or block based on role and vulnerability profile

### Decision Matrix

| Critical Count | Resource Set Match | Developer Access | Editor Access | Rationale |
|----------------|-------------------|------------------|---------------|-----------:|
| 0 | Safe Deployment Gate | ✅ ALLOW | ✅ ALLOW | No critical vulnerabilities - safe to deploy |
| > 0 | None (base deployment) | ❌ DENY | ✅ OVERRIDE | Critical vulnerabilities - requires override |

## Role-Based Access Control

### Developer/CI Pipeline Roles (`developer`, `ci-pipeline`)
- **Safe Deployment Gate**: ✅ Deploy permission (when `criticalCount = 0`)
- **Base Deployment**: ❌ No permission (when `criticalCount > 0`)
- **Result**: Can only deploy safe applications, blocked when critical vulnerabilities present

### Editor Role (`editor`)
- **Safe Deployment Gate**: ✅ Deploy permission (when `criticalCount = 0`)
- **Base Deployment**: ✅ Deploy permission (when `criticalCount > 0`)
- **Result**: Can deploy both safe applications AND override critical vulnerabilities

### Security Officer Role (`security`)
- **Safe Deployment Gate**: ✅ Deploy permission (when `criticalCount = 0`)
- **Base Deployment**: ✅ Deploy permission (when `criticalCount > 0`)
- **Result**: Full override capabilities with complete audit trail

## Gate Scenarios

### Safe Deployment (criticalCount = 0)
```bash
# All roles can deploy - Safe Deployment Gate matches
✅ Developer: ALLOW (Safe Deployment Gate permission)
✅ Editor: ALLOW (Safe Deployment Gate permission)  
✅ Security Officer: ALLOW (Safe Deployment Gate permission)
```

### Critical Vulnerabilities (criticalCount > 0)
```bash
# Only override roles can deploy - falls back to base deployment
❌ Developer: DENY (no permission on base deployment)
🔓 Editor: OVERRIDE (permission on base deployment)
🔓 Security Officer: OVERRIDE (permission on base deployment)
```

## Authorization Matrix

| Vulnerability Level | Resource | developer | ci-pipeline | editor | Security Officer |
|-------------------|----------|-----------|-------------|---------|------------------|
| **criticalCount = 0** | Safe Deployment Gate | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW |
| **criticalCount > 0** | Base Deployment | ❌ DENY | ❌ DENY | 🔓 OVERRIDE | 🔓 OVERRIDE |
| **Non-blocking** | Any matched resource | ⚠️ WARN | ⚠️ WARN | ⚠️ WARN | ⚠️ WARN |

## Permit.io Configuration

### Required Setup Steps
1. **Create Safe Deployment Gate Resource Set**:
   - Name: "Safe Deployment Gate"
   - Parent Resource: "Deployment"
   - Condition: `resource.criticalCount equals 0`

2. **Configure Role Permissions**:
   - **developer/ci-pipeline**: Deploy permission ONLY on Safe Deployment Gate
   - **editor/Security Officer**: Deploy permission on BOTH Safe Deployment Gate AND base Deployment

3. **Resource Attributes**:
   ```json
   {
     "criticalCount": "number",
     "highCount": "number", 
     "mediumCount": "number",
     "lowCount": "number",
     "vulnerabilities": "object",
     "summary": "object"
   }
   ```

### Environment Variables
```bash
# Required for Permit.io integration
PERMIT_API_KEY=permit_key_your_key_here

# User context (set dynamically)
USER_ROLE=developer           # Standard role - restricted to safe deployments
USER_KEY=test-developer-user  # Standard user

# Override roles for emergency deployments:
# USER_ROLE=editor              # Can override critical vulnerability blocks
# USER_ROLE="Security Officer"  # Full override capabilities
```

## Testing Scenarios

### Test 1: Safe Deployment (Should PASS for developer)
```bash
./scripts/test-payload.sh 0 3 2 1 developer test-dev
# Expected: ✅ ALLOW - Safe Deployment Gate matches
```

### Test 2: Critical Vulnerabilities (Should FAIL for developer)
```bash  
./scripts/test-payload.sh 2 1 0 0 developer test-dev
# Expected: ❌ DENY - No permission on base deployment
```

### Test 3: Override Capability (Should PASS for editor)
```bash
./scripts/test-payload.sh 2 1 0 0 editor test-editor  
# Expected: 🔓 OVERRIDE - Permission on base deployment
```

### Test 4: Security Officer Override (Should PASS)
```bash
./scripts/test-payload.sh 5 0 0 0 "Security Officer" security-admin
# Expected: 🔓 OVERRIDE - Full override capabilities
```

## Security Considerations

### Principle of Least Privilege
- **Developers**: Can only deploy safe applications (no critical vulnerabilities)
- **Override Roles**: Emergency deployment capability with full audit trail
- **Clear Boundaries**: Explicit resource-based access control

### Audit Requirements
- All deployment decisions logged with vulnerability context
- Override events include user role, vulnerability counts, and justification
- Permit.io dashboard provides real-time audit visibility
- Comprehensive audit trail for compliance and security review

### Override Controls
- Editor/Security Officer overrides are logged and auditable
- Post-deployment remediation plans required for critical vulnerability overrides
- Regular access review for override role assignments
- Clear escalation procedures for emergency deployments

## Version History

### v1.0.0 (Deprecated)
- **Critical Vulnerability Gate**: Hard-coded blocking for criticalCount > 0
- **Issues**: Poor override support, confusing policy matrix configuration
- **Reason for Deprecation**: Did not properly support role-based overrides

### v2.0.0 (Current - Safe Deployment Gate)
- **Safe Deployment Gate**: Inverted ABAC logic using Resource Sets
- **Improvements**:
  - Clear role-based override support
  - Simplified policy logic with Resource Set conditions  
  - Better audit trail and logging
  - Easier testing and validation
  - Proper separation between safe deployments and overrides

## Testing and Validation

### Local Testing Commands
```bash
# Comprehensive gate testing with role scenarios
./scripts/test-gates-local.sh

# Validate Safe Deployment Gate configuration
./scripts/validate-permit.sh

# Test specific scenarios with custom payloads
./scripts/test-payload.sh [CRITICAL] [HIGH] [MEDIUM] [LOW] [ROLE] [USER]
```

### Policy Validation
When validating Safe Deployment Gate setup:
1. Verify Resource Set condition: `resource.criticalCount equals 0`
2. Check role permissions on both Safe Deployment Gate and base Deployment
3. Test with different vulnerability profiles and user roles
4. Confirm audit logs appear in Permit.io dashboard

### OPA CLI Integration (Optional)
For local Rego policy development and validation:

```bash
# Install OPA CLI (Linux/WSL)
curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.68.0/opa_linux_amd64_static
chmod +x opa && sudo mv opa /usr/local/bin/

# Validate Rego syntax (reference policy only)
opa fmt policies/gating_policy.rego
opa test policies/gating_policy.rego
```

## Troubleshooting

### Safe Deployment Gate Not Working
```bash
# Check Resource Set configuration in Permit.io dashboard
# Verify condition: resource.criticalCount equals 0  
# Ensure developer role has deploy permission on Safe Deployment Gate

# Test with direct payload
./scripts/test-payload.sh 0 2 1 0 developer test-dev > /tmp/safe.json
curl -X POST -H "Content-Type: application/json" -d @/tmp/safe.json http://localhost:7766/allowed
```

### Override Not Working
```bash
# Check role configuration
grep USER_ROLE ../../.env

# Verify editor role has deploy permission on base Deployment resource
# Test override scenario
./scripts/test-payload.sh 3 0 0 0 editor test-editor > /tmp/override.json
curl -X POST -H "Content-Type: application/json" -d @/tmp/override.json http://localhost:7766/allowed
```

### Common Issues
1. **Resource Set Condition**: Ensure condition is `resource.criticalCount equals 0` (not "does not equal")
2. **Role Permissions**: Developer should NOT have deploy permission on base Deployment
3. **Policy Matrix**: In Permit.io dashboard, developer role should have "deny" permission UNCHECKED for base Deployment
4. **API Key**: Verify PERMIT_API_KEY is correctly set and PDP can sync with cloud

## Integration Points

### GitHub Actions Integration
```yaml
# Environment variables automatically set in pipeline
env:
  USER_ROLE: ${{ github.event_name == 'pull_request' && 'developer' || 'ci-pipeline' }}
  USER_KEY: ${{ github.actor }}
```

### Exit Code Mapping
- **0**: Gates passed (safe deployment or override active)
- **1**: Soft gate warning (high/medium vulnerabilities, non-blocking)
- **2**: Hard gate failure (critical vulnerabilities, blocking for standard roles)

### Audit Dashboard
- **Permit.io Dashboard**: Real-time audit log visibility
- **Decision History**: Complete trail of who deployed what and when
- **Override Tracking**: Specific logging for emergency deployments

## Support Resources
- **Business Requirements**: [`../docs/PERMIT_IO_GATING_BRD.md`](../docs/PERMIT_IO_GATING_BRD.md)
- **Permit.io Documentation**: [docs.permit.io](https://docs.permit.io) 
- **Configuration Schema**: [`permit_config.json`](permit_config.json)
- **Main Project Guide**: [`../../README.md`](../../README.md)