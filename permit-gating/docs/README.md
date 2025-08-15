# CI/CD Security Gating with Permit.io - Safe Deployment Gate

This directory contains all Permit.io-based security gating components for the CI/CD pipeline. The gating system uses **Safe Deployment Gate** with inverted ABAC logic to provide role-based access control and policy enforcement for deployment decisions.

## 🔄 **Safe Deployment Gate Logic**

Instead of blocking dangerous deployments, we **allow safe deployments**:
- **Resource Set**: "Safe Deployment Gate" matches when `criticalCount = 0`
- **Safe Deployments**: Developers can deploy when no critical vulnerabilities exist
- **Critical Vulnerabilities**: Fall back to base deployment resource (restricted access)
- **Override Capability**: Editor/Security Officer roles have permissions on both resources

## Directory Structure

```
permit-gating/
├── docs/                           # Documentation
│   ├── README.md                   # This file - Safe Deployment Gate setup guide
│   └── PERMIT_IO_GATING_BRD.md    # Business requirements document
├── scripts/                        # Gate evaluation scripts
│   ├── evaluate-gates.sh          # Main gate evaluation script with Safe Deployment Gate logic
│   ├── validate-permit.sh         # Permit.io configuration validation
│   ├── verify-cloud-config.sh     # Verify Permit.io cloud configuration alignment
│   ├── test-gates-local.sh        # Local testing utility with role-based tests
│   └── test-payload.sh            # Test payload generator for different scenarios
├── policies/                       # Policy definitions
│   ├── gating_policy.rego         # OPA/Rego reference policies (informational)
│   ├── permit_config.json         # Safe Deployment Gate configuration schema
│   └── README.md                   # Policy documentation
├── opal-fetcher/                   # OPAL data fetcher service (optional)
│   ├── main.py                    # Python service for fetching Snyk data
│   ├── Dockerfile                 # Container definition
│   └── requirements.txt           # Python dependencies
├── workflows/                      # GitHub Actions workflows
│   └── gating-pipeline.yml        # CI/CD gating pipeline (reference copy)
├── docker/                        # Docker configurations
│   └── docker-compose.gating.yml  # Gating services composition
└── config/                        # Configuration files (future use)
```

## Quick Start

### 1. Prerequisites
- Docker and Docker Compose installed
- Permit.io account and API key
- Snyk account and API token
- Configured `.env` file in project root

### 2. Start Gating Services
```bash
# From project root directory
cd permit-gating/docker
docker compose -f docker-compose.gating.yml up -d
```

### 3. Validate Configuration
```bash
# Validate Permit.io setup and Safe Deployment Gate
./permit-gating/scripts/validate-permit.sh

# Verify cloud configuration alignment (recommended after UI changes)
./permit-gating/scripts/verify-cloud-config.sh

# Test gate evaluation
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

### 4. Run Local Tests
```bash
# Full integration test with role-based scenarios
./permit-gating/scripts/test-gates-local.sh
# Select option 5: "Test different user roles with ABAC"
```

## Core Components

### Security Gate Evaluation (`scripts/evaluate-gates.sh`)

The main script that evaluates security gates using Permit.io PDP with Safe Deployment Gate logic. Features:

- **Safe Deployment Gate**: Uses inverted ABAC logic - allows safe deployments (criticalCount = 0)
- **Role-Based Access Control**: Supports `developer`, `editor`, `Security Officer`, and `ci-pipeline` roles
- **Vulnerability Analysis**: Processes Snyk scan results for security evaluation
- **Override Capability**: Editor and Security Officer can deploy even with critical vulnerabilities
- **Audit Trail**: Full logging of all deployment decisions and overrides

**Usage:**
```bash
# Standard evaluation with developer role
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json

# Test with different scenarios
./permit-gating/scripts/test-payload.sh 0 3 2 1 developer test-dev | curl -X POST -H "Content-Type: application/json" -d @- http://localhost:7766/allowed
```

**Exit Codes:**
- `0`: Gates passed (safe deployment or override active)
- `1`: Soft gate warning (high/medium vulnerabilities, non-blocking)
- `2`: Hard gate failure (critical vulnerabilities, blocking)

### Policy Decision Point (Permit.io PDP)

The PDP evaluates Safe Deployment Gate policies against vulnerability data:

- **High Performance**: Local PDP deployment for low latency
- **Cloud Configuration**: Centralized policy management via Permit.io dashboard
- **Real-time Decisions**: Instant policy evaluation during CI/CD
- **Resource Set Logic**: Safe Deployment Gate matching for conditional access

## Gate Scenarios

### Developer/CI Pipeline (developer, ci-pipeline roles)
- ✅ **Pass**: No critical vulnerabilities (Safe Deployment Gate matches)
- ⚠️ **Warn**: High severity vulnerabilities only (Safe Deployment Gate matches)
- ❌ **Fail**: Critical vulnerabilities present (no permission on base deployment)

### Editor/Security Officer Override (editor, Security Officer roles)
- 🔓 **Override**: Can deploy even with critical vulnerabilities (base deployment permission)
- ✅ **Safe Deployments**: Can also deploy safe deployments (Safe Deployment Gate permission)
- 📋 **Audit Trail**: Records who, when, and what was overridden
- ⚠️ **Risk Visibility**: Clear display of security risks being accepted

## Configuration

### Environment Variables (.env in project root)
```bash
# Permit.io Configuration
PERMIT_API_KEY=permit_key_your_key_here

# Snyk Configuration
SNYK_TOKEN=your_snyk_token_here
SNYK_ORG_ID=your_snyk_org_id_here

# User Role Configuration
USER_ROLE=developer           # Standard role (default) - restricted to safe deployments
USER_KEY=test-developer-user  # Standard user (default)

# Alternative Roles:
# USER_ROLE=ci-pipeline         # CI/CD pipeline - same restrictions as developer
# USER_KEY=github-actions

# Override Roles (for emergency deployments):
# USER_ROLE=editor              # Can override critical vulnerability blocks
# USER_KEY=your_editor_user_key

# USER_ROLE="Security Officer"  # Full override capabilities
# USER_KEY=security_admin_user
```

### Permit.io Setup
1. Create account at [app.permit.io](https://app.permit.io)
2. Generate API key in Settings → API Keys
3. Configure Safe Deployment Gate:
   - **Resource Set**: "Safe Deployment Gate" with condition `resource.criticalCount equals 0`
   - **Parent Resource**: "Deployment" with ABAC attributes
4. Configure roles and permissions:
   - **developer/ci-pipeline**: Deploy permission ONLY on Safe Deployment Gate
   - **editor/Security Officer**: Deploy permission on BOTH Safe Deployment Gate AND base Deployment
5. Add users and assign appropriate roles

## Safe Deployment Gate Logic

### How It Works
1. **Vulnerability Scan**: Snyk scans code and generates vulnerability counts
2. **Gate Evaluation**: Permit.io evaluates request against Resource Set conditions
3. **Safe Deployment Check**: If `criticalCount = 0`, Safe Deployment Gate matches
4. **Permission Check**: User's role determines access to matched resource
5. **Decision**: Allow, warn, or block based on role and vulnerability profile

### Decision Matrix

| Critical Count | Resource Set Match | Developer Access | Editor Access | Rationale |
|----------------|-------------------|------------------|---------------|-----------|
| 0 | Safe Deployment Gate | ✅ ALLOW | ✅ ALLOW | No critical vulnerabilities - safe to deploy |
| > 0 | None (base deployment) | ❌ DENY | ✅ OVERRIDE | Critical vulnerabilities - requires override |

### Testing Scenarios
```bash
# Test 1: Safe deployment (should PASS for developer)
./permit-gating/scripts/test-payload.sh 0 3 2 1 developer test-dev

# Test 2: Critical vulnerabilities (should FAIL for developer)
./permit-gating/scripts/test-payload.sh 2 1 0 0 developer test-dev

# Test 3: Override capability (should PASS for editor)
./permit-gating/scripts/test-payload.sh 2 1 0 0 editor test-editor
```

## Security Considerations

### Role-Based Access Control
- **Principle of Least Privilege**: Developers can only deploy safe applications
- **Override Controls**: Editor/Security Officer roles for emergency deployments
- **Audit Requirements**: All override actions are logged and traceable
- **Clear Permissions**: Explicit allow/deny based on vulnerability profile

### Production Usage
- Monitor override frequency and patterns
- Set up alerts for critical vulnerability deployments
- Regular access reviews for override role assignments
- Document all override justifications for compliance

### Emergency Procedures
1. Verify critical business need for override
2. Document security risk assessment
3. Use editor or Security Officer role temporarily
4. Deploy with full audit trail
5. Address vulnerabilities immediately post-deployment
6. Revert to normal security gates
7. Document incident and lessons learned

## Troubleshooting

### Common Issues

**Safe Deployment Gate not working:**
```bash
# Check Resource Set configuration in Permit.io dashboard
# Verify condition: resource.criticalCount equals 0
# Ensure developer role has deploy permission on Safe Deployment Gate

# Test with direct payload
./permit-gating/scripts/test-payload.sh 0 2 1 0 developer test-dev > /tmp/safe.json
curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $PERMIT_API_KEY" -d @/tmp/safe.json http://localhost:7766/allowed
```

**Override not working:**
```bash
# Check role configuration
grep USER_ROLE ../../.env

# Verify editor role has deploy permission on base Deployment resource
# Test override scenario
./permit-gating/scripts/test-payload.sh 3 0 0 0 editor test-editor > /tmp/override.json
```

**Docker services not starting:**
```bash
# Check logs
docker compose -f permit-gating/docker/docker-compose.gating.yml logs permit-pdp

# Restart services with API key
export PERMIT_API_KEY="your_key_here"
docker compose -f permit-gating/docker/docker-compose.gating.yml restart
```

### Support Resources
- **Business Requirements**: [`PERMIT_IO_GATING_BRD.md`](PERMIT_IO_GATING_BRD.md)
- **Configuration Fix Guide**: [`PERMIT_IO_CONFIGURATION_FIX.md`](PERMIT_IO_CONFIGURATION_FIX.md) - **RESOLVED ✅**
- **Permit.io Documentation**: [docs.permit.io](https://docs.permit.io)
- **Main Project Guide**: [`../../README.md`](../../README.md)
- **Policy Configuration**: [`../policies/permit_config.json`](../policies/permit_config.json)

## Development

### Adding New Test Scenarios
```bash
# Use parameterized payload generator
./permit-gating/scripts/test-payload.sh [CRITICAL] [HIGH] [MEDIUM] [LOW] [ROLE] [USER]

# Example: High vulnerability scenario
./permit-gating/scripts/test-payload.sh 0 5 2 1 developer test-dev
```

### Extending Roles
1. Add role in Permit.io dashboard
2. Configure permissions on Safe Deployment Gate and/or base Deployment
3. Update `policies/permit_config.json` documentation
4. Add test scenarios in `scripts/test-gates-local.sh`

### Policy Updates
1. Modify Resource Set conditions in Permit.io dashboard
2. Update reference documentation in `policies/gating_policy.rego`
3. Test with `scripts/validate-permit.sh`
4. Update deployment scripts and workflows

## Version History

- **v1.0**: Original critical vulnerability blocking (deprecated)
- **v2.0**: Safe Deployment Gate with inverted ABAC logic (current)

## License
Part of the CI/CD Pipeline PoC - Internal Use Only