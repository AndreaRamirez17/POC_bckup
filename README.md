# CI/CD Security Gating Platform PoC

A proof of concept implementation for a modern CI/CD security gating platform that replaces legacy GATR system using Permit.io, Snyk, and GitHub Actions.

## Overview

This PoC demonstrates an end-to-end security gating solution that:
- **Scans** code for vulnerabilities using Snyk
- **Evaluates** security policies using Permit.io Policy Decision Point (PDP)
- **Enforces** gates in CI/CD pipelines via GitHub Actions
- **Supports** both hard gates (blocking) and soft gates (warning)

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  GitHub Actions │────▶│ Snyk Scanner │────▶│ Vulnerability   │
│    Pipeline     │     │              │     │     Data        │
└─────────────────┘     └──────────────┘     └────────┬────────┘
                                                       │
                                                       ▼
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│ Gate Evaluation │◀────│  Permit.io   │◀────│  OPAL Data     │
│     Script      │     │     PDP      │     │    Fetcher     │
└─────────────────┘     └──────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│ Pipeline Result │
│  - Pass         │
│  - Warn         │
│  - Fail         │
└─────────────────┘
```

## Components

### 1. Mock Spring Boot Application
- **Location**: `/microservice-moc-app`
- **Purpose**: Simulates a real application with intentionally vulnerable dependencies
- **Vulnerabilities**:
  - **Critical**: Log4j 2.14.1 (CVE-2021-44228)
  - **High**: Commons Collections 3.2.1 (CVE-2015-6420)
  - **Medium**: Jackson Databind 2.9.10.1

### 2. Docker Compose Infrastructure
- **Permit.io PDP**: Policy Decision Point for gate evaluation
- **OPAL Server**: Manages policy updates and data synchronization
- **OPAL Fetcher**: Custom service to fetch Snyk vulnerability data
- **Redis**: Message broker for OPAL pub/sub
- **Spring App**: The mock application being tested

### 3. Security Policies & Role-Based Access
- **Hard Gate**: Fails pipeline on critical vulnerabilities
- **Soft Gate**: Warns on high severity vulnerabilities
- **Info Gate**: Provides information on medium severity issues
- **Editor Override**: Allows authorized users to bypass security gates with full audit trail
- **Role-Based Permissions**: Different access levels (ci-pipeline, editor) with appropriate permissions

### 4. Gate Evaluation Scripts (`permit-gating/scripts/`)
- **evaluate-gates.sh**: Main security gate evaluation script with role-based override support
- **test-gates-local.sh**: Local testing utility for full pipeline simulation
- **validate-permit.sh**: Permit.io configuration validation script
- **Enhanced .env Configuration**: Flexible user role and key management

### 5. GitHub Actions Workflow
- Builds and scans the application
- Evaluates security gates with role-based access
- Makes deployment decisions based on gate results and user permissions

## Prerequisites

- Docker & Docker Compose (20.10.0+)
- Java 11+ and Maven 3.8+
- Node.js 14+ (for Snyk CLI)
- Git
- **Permit.io account and API key** ([Configuration Guide](CONFIGURATION_GUIDE.md))
- **Snyk account and API token** ([Configuration Guide](CONFIGURATION_GUIDE.md))
- **OPA CLI** (Optional - automatically installed for policy validation)

## Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd cicd-pipeline-poc
```

### 2. Configure Services
**IMPORTANT**: Before running the PoC, you need to configure Snyk and Permit.io accounts.

📖 **Follow the detailed [Configuration Guide](CONFIGURATION_GUIDE.md)** for step-by-step instructions.

**Quick setup summary:**
```bash
# Copy environment template (if it exists)
cp .env.example .env || echo "Using existing .env file"

# Edit .env with your API keys (see Configuration Guide for details)
# PERMIT_API_KEY=your_permit_api_key_here
# SNYK_TOKEN=your_snyk_token_here
# SNYK_ORG_ID=your_snyk_org_id_here

# Configure user role (optional - for testing editor override)
# USER_ROLE=editor
# USER_KEY=your_editor_user_key

# Validate configurations
chmod +x snyk-scanning/scripts/validate-snyk.sh
./snyk-scanning/scripts/validate-snyk.sh

chmod +x permit-gating/scripts/validate-permit.sh  
./permit-gating/scripts/validate-permit.sh

# Note: The validate-permit.sh script will automatically install OPA CLI if needed
# for policy syntax validation. You can skip the installation when prompted if
# you don't need syntax checking (the policies will still work with Permit.io PDP)
```

### 3. Run Local Test
```bash
chmod +x permit-gating/scripts/test-gates-local.sh
./permit-gating/scripts/test-gates-local.sh
```

Select option 1 for a full test run.

## Manual Testing

### Start Services
```bash
docker-compose up -d
```

### Run Snyk Scan
```bash
cd microservice-moc-app
mvn clean compile
snyk test --json > ../snyk-scanning/results/snyk-results.json
cd ..
```

### Evaluate Gates
```bash
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

### Expected Results

With the included vulnerable dependencies, you should see:
- **Hard Gate**: FAIL (due to critical Log4j vulnerability)
- **Soft Gate**: WARN (due to high severity Commons Collections vulnerability)
- **Info**: Medium severity Jackson Databind vulnerability

### Editor Override Testing

To test the editor override functionality:
```bash
# Enable editor override in .env file
# Uncomment these lines:
# USER_ROLE=editor  
# USER_KEY=santander.david.19

# Run the gate evaluation
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

**Expected Editor Override Results:**
- **Decision**: EDITOR_OVERRIDE - Deployment allowed despite critical vulnerabilities
- **Output**: Clear warning showing editor privileges are active
- **Audit Trail**: Shows user, role, and specific vulnerabilities being overridden
- **Exit Code**: 0 (deployment proceeds)

## GitHub Actions Setup

### 1. Add Repository Secrets
Go to Settings → Secrets and add:
- `PERMIT_API_KEY`: Your Permit.io API key
- `SNYK_TOKEN`: Your Snyk authentication token
- `SNYK_ORG_ID`: Your Snyk organization ID

### 2. Push Code
The pipeline will automatically trigger on:
- Push to `main` or `develop` branches
- Pull requests to `main` branch
- Manual workflow dispatch

### 3. Monitor Pipeline
Check the Actions tab to see:
- Build and scan results
- Gate evaluation outcomes
- Deployment status

## Gate Scenarios

### Scenario 1: Critical Vulnerability (Hard Gate)
**Setup**: Application includes Log4j 2.14.1
**Result**: Pipeline FAILS and deployment is blocked
**Message**: "Critical vulnerabilities must be resolved before deployment"

### Scenario 2: High Severity (Soft Gate)
**Setup**: Remove critical vulnerabilities, keep high severity ones
**Result**: Pipeline PASSES with warnings
**Message**: "High severity vulnerabilities detected. Review recommended"

### Scenario 3: Clean Build
**Setup**: Update all dependencies to secure versions
**Result**: Pipeline PASSES
**Message**: "All security gates passed"

### Scenario 4: Editor Override (Security Gate Bypass)
**Setup**: Configure editor role in .env and run with critical vulnerabilities
**Result**: Pipeline PASSES with override warning
**Message**: "EDITOR OVERRIDE - Deployment allowed with editor privileges"
**Details**: 
- Shows clear audit trail of who overrode the gates
- Lists all critical vulnerabilities being overridden
- Provides recommendations for post-deployment remediation

## Customization

### Adding New Gates
Edit `permit-gating/policies/gating_policy.rego` to add custom rules:
```rego
custom_gate_fail if {
    input.resource.attributes.customMetric > threshold
}
```

### Modifying Thresholds
Update the policy rules in `gating_policy.rego`:
```rego
hard_gate_fail if {
    input.resource.attributes.criticalCount > 0  # Change threshold here
}
```

### Adding Data Sources
Extend the OPAL fetcher in `/opal-fetcher/main.py` to integrate additional security tools.

## Audit Logging

All security gate evaluations are automatically logged to the Permit.io audit system for compliance and monitoring purposes.

### Viewing Audit Logs
1. Log in to your [Permit.io Dashboard](https://app.permit.io)
2. Navigate to **Audit Logs** section
3. Filter by:
   - **User**: `david-santander` (or your configured USER_KEY)
   - **Action**: `deploy`
   - **Resource**: `deployment`

### Audit Log Details
Each gate evaluation creates an audit entry containing:
- **User Identity**: From `USER_KEY` environment variable
- **User Role**: From `USER_ROLE` environment variable (e.g., `editor`, `ci-pipeline`)
- **Action**: Always `deploy` for gate evaluations
- **Resource Type**: `deployment`
- **Decision**: `allow` or `deny` based on policy evaluation
- **Context**: Environment, repository, commit SHA, workflow details
- **Vulnerability Data**: Critical, high, medium, low counts and details

### Environment Configuration
For consistent audit trails, configure these environment variables:

**Local Environment (.env file):**
```bash
USER_KEY=david-santander
USER_ROLE=editor
```

**GitHub Actions (workflow secrets):**
```yaml
USER_KEY: david-santander
USER_ROLE: ${{ github.event.inputs.user_role || 'editor' }}
```

### Port Configuration
- **PDP API Endpoint**: `http://localhost:7766` (for authorization calls)
- **PDP Health Endpoint**: `http://localhost:7001/healthy` (for status checks)

## Troubleshooting

### Services Not Starting
```bash
docker-compose logs permit-pdp
docker-compose logs opal-fetcher
```

### Gate Evaluation Failing
```bash
# Check PDP health
curl http://localhost:7001/healthy

# Test with debug mode
DEBUG=true ./scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

### Snyk Not Working
- Verify API token is correct
- Check organization ID matches your Snyk account
- Use mock data mode if Snyk is not configured

## Project Structure
```
cicd-pipeline-poc/
├── .github/
│   └── workflows/
│       └── gating-pipeline.yml      # GitHub Actions workflow
├── permit-gating/                         # Security gating components
│   ├── docs/                       # Gating documentation
│   │   ├── README.md               # Gating setup guide
│   │   └── PERMIT_IO_GATING_BRD.md # Business requirements
│   ├── scripts/                    # Gate evaluation scripts
│   │   ├── evaluate-gates.sh       # Main gate evaluation script
│   │   ├── validate-permit.sh      # Permit.io validation
│   │   └── test-gates-local.sh     # Local testing utility
│   ├── policies/                   # Security policies
│   │   ├── gating_policy.rego      # OPA/Rego security policies
│   │   └── permit_config.json      # Permit.io configuration
│   ├── opal-fetcher/              # Custom data fetcher
│   │   ├── main.py                # Snyk data fetcher service
│   │   ├── Dockerfile             # Fetcher container
│   │   └── requirements.txt       # Python dependencies
│   ├── workflows/                  # Workflow templates
│   │   └── gating-pipeline.yml     # Gating pipeline workflow
│   └── docker/                     # Docker configurations
│       └── docker-compose.gating.yml # Gating services
├── microservice-moc-app/
│   ├── src/                        # Spring Boot application source
│   ├── pom.xml                     # Maven config with vulnerable deps
│   └── Dockerfile                  # Application container
├── scripts/
│   └── validate-snyk.sh            # Snyk validation script
├── docker-compose.yml              # Main infrastructure definition
├── .env                            # Environment configuration
└── README.md                       # This file
```

## Next Steps

After validating this PoC:
1. **Production Deployment**: Deploy PDP to Kubernetes for high availability
2. **GitOps Integration**: Implement policy-as-code workflow
3. **Additional Gates**: Add SonarQube, BlackDuck, and other scanners
4. **Exception Handling**: Integrate with Jira for exception management
5. **Reporting Dashboard**: Build visualization for gate metrics
6. **Maker-Checker Workflow**: Implement approval process for policy changes

## Support

For issues or questions:
- **Start here**: [Configuration Guide](CONFIGURATION_GUIDE.md) for setup help
- **Security Gating**: [Gating Documentation](permit-gating/docs/README.md) for gating-specific setup
- Review the [Business Requirements Document](permit-gating/docs/PERMIT_IO_GATING_BRD.md)  
- Check service logs: `docker-compose logs`
- Enable debug mode: `DEBUG=true ./permit-gating/scripts/evaluate-gates.sh`
- Validate your setup: `./snyk-scanning/scripts/validate-snyk.sh` and `./permit-gating/scripts/validate-permit.sh`

## License

This is a proof of concept for internal use.
