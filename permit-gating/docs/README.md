# CI/CD Security Gating with Permit.io

This directory contains all Permit.io-based security gating components for the CI/CD pipeline. The gating system provides role-based access control and policy enforcement for deployment decisions.

## Directory Structure

```
permit-gating/
├── docs/                           # Documentation
│   ├── README.md                   # This file - gating setup guide
│   └── PERMIT_IO_GATING_BRD.md    # Business requirements document
├── scripts/                        # Gate evaluation scripts
│   ├── evaluate-gates.sh          # Main gate evaluation script with editor override support
│   ├── validate-permit.sh         # Permit.io configuration validation
│   └── test-gates-local.sh        # Local testing utility
├── policies/                       # Policy definitions
│   ├── gating_policy.rego         # OPA/Rego security policies
│   ├── permit_config.json         # Permit.io configuration schema
│   └── README.md                   # Policy documentation
├── opal-fetcher/                   # OPAL data fetcher service
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
docker-compose up -d

# Or start only gating services
cd permit-gating/docker
docker-compose -f docker-compose.gating.yml up -d
```

### 3. Validate Configuration
```bash
# Validate Permit.io setup
./permit-gating/scripts/validate-permit.sh

# Test gate evaluation
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

### 4. Run Local Tests
```bash
# Full integration test
./permit-gating/scripts/test-gates-local.sh
```

## Core Components

### Security Gate Evaluation (`scripts/evaluate-gates.sh`)

The main script that evaluates security gates using Permit.io PDP. Features:

- **Role-Based Access Control**: Supports `ci-pipeline` (standard) and `editor` (override) roles
- **Vulnerability Analysis**: Processes Snyk scan results for security evaluation
- **Gate Types**: Hard gates (blocking), soft gates (warnings), and editor overrides
- **Audit Trail**: Full logging of who made override decisions and why

**Usage:**
```bash
# Standard evaluation
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json

# With editor override (configured in .env)
USER_ROLE=editor USER_KEY=your_editor_user ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

**Exit Codes:**
- `0`: Gates passed (or editor override active)
- `1`: Soft gate warning (non-blocking)
- `2`: Hard gate failure (blocking)

### Policy Decision Point (Permit.io PDP)

The PDP evaluates policies against vulnerability data and user permissions:

- **High Performance**: Local PDP deployment for low latency
- **Policy as Code**: Centralized policy management via Permit.io
- **Real-time Decisions**: Instant policy evaluation during CI/CD
- **Role-Based**: Different access levels for different user types

### OPAL Data Fetcher (`opal-fetcher/main.py`)

Custom service that fetches vulnerability data from Snyk and formats it for Permit.io:

- **Snyk Integration**: Fetches vulnerability data from Snyk API
- **Data Transformation**: Formats data for policy evaluation
- **Mock Data Support**: Provides fallback data for testing
- **RESTful API**: Exposes endpoints for health checks and data retrieval

## Gate Scenarios

### Normal CI/CD Pipeline (ci-pipeline role)
- ✅ **Pass**: No critical vulnerabilities
- ⚠️ **Warn**: High severity vulnerabilities (soft gate)
- ❌ **Fail**: Critical vulnerabilities (hard gate)

### Editor Override (editor role)
- 🔓 **Override**: Allows deployment despite critical vulnerabilities
- 📋 **Audit Trail**: Records who, when, and what was overridden
- ⚠️ **Warnings**: Clear visibility of security risks being accepted

## Configuration

### Environment Variables (.env in project root)
```bash
# Permit.io Configuration
PERMIT_API_KEY=permit_key_your_key_here

# Snyk Configuration
SNYK_TOKEN=your_snyk_token_here
SNYK_ORG_ID=your_snyk_org_id_here

# User Role Configuration
USER_ROLE=ci-pipeline        # Standard role (default)
USER_KEY=github-actions      # Standard user (default)

# Editor Override (uncomment to enable)
# USER_ROLE=editor
# USER_KEY=your_editor_user_key
```

### Permit.io Setup
1. Create account at [app.permit.io](https://app.permit.io)
2. Generate API key in Settings → API Keys
3. Configure roles and permissions:
   - **ci-pipeline**: Standard deployment permissions
   - **editor**: Override permissions for emergency deployments
4. Add users and assign appropriate roles

## Security Considerations

### Role-Based Access Control
- **Principle of Least Privilege**: Assign editor role only when necessary
- **Audit Requirements**: All override actions are logged and traceable
- **Time-Bound Access**: Consider temporary editor permissions for emergencies
- **Approval Workflows**: Implement approval processes for editor role assignments

### Production Usage
- Monitor override frequency and patterns
- Set up alerts for editor override usage  
- Regular access reviews for editor role assignments
- Document all override justifications for compliance

### Emergency Procedures
1. Verify critical business need for override
2. Document security risk assessment
3. Enable editor override temporarily  
4. Deploy with full audit trail
5. Address vulnerabilities immediately post-deployment
6. Revert to normal security gates
7. Document incident and lessons learned

## Troubleshooting

### Common Issues

**Gate evaluation fails:**
```bash
# Check PDP status
curl http://localhost:7001/healthy

# Verify environment variables
echo $PERMIT_API_KEY | head -c 20

# Run with debug mode
DEBUG=true ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

**Editor override not working:**
```bash
# Check role configuration
grep USER_ROLE ../../.env

# Verify user exists in Permit.io dashboard
# Ensure editor role has deploy permissions
```

**Docker services not starting:**
```bash
# Check logs
docker-compose logs permit-pdp
docker-compose logs opal-fetcher

# Restart services
docker-compose restart
```

### Support Resources
- **Business Requirements**: [`docs/PERMIT_IO_GATING_BRD.md`](PERMIT_IO_GATING_BRD.md)
- **Permit.io Documentation**: [docs.permit.io](https://docs.permit.io)
- **Main Project Guide**: [`../../README.md`](../../README.md)
- **Configuration Guide**: [`../../CONFIGURATION_GUIDE.md`](../../CONFIGURATION_GUIDE.md)

## Development

### Adding New Policies
1. Edit `policies/gating_policy.rego` for OPA rules
2. Update `policies/permit_config.json` for Permit.io schema
3. Test with `scripts/test-gates-local.sh`

### Extending Data Sources
1. Modify `opal-fetcher/main.py` to add new data sources
2. Update policy schemas in `policies/`
3. Add validation in `scripts/validate-permit.sh`

### Custom Workflows
1. Copy `workflows/gating-pipeline.yml` to `.github/workflows/`
2. Modify as needed for your CI/CD requirements
3. Update script paths if moved outside gating directory

## License
Part of the CI/CD Pipeline PoC - Internal Use Only