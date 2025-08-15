# CI/CD Security Gating Platform PoC

A proof of concept implementation for a modern CI/CD security gating platform that replaces legacy GATR system using Permit.io, Snyk, and GitHub Actions.

## Overview

This PoC demonstrates an end-to-end security and quality gating solution that:

- **Scans** code for vulnerabilities using Snyk
- **Analyzes** code quality and security using SonarQube Cloud
- **Evaluates** security and quality policies using Permit.io Policy Decision Point (PDP)
- **Enforces** combined gates in CI/CD pipelines via GitHub Actions
- **Supports** both hard gates (blocking) and soft gates (warning)
- **Provides** comprehensive quality ratings (Security: A, Reliability: A, Maintainability: A)

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  GitHub Actions │────▶│ Snyk Scanner │────▶│ Vulnerability   │
│    Pipeline     │     │              │     │     Data        │
└─────────┬───────┘     └──────────────┘     └────────┬────────┘
          │                                           │
          ▼                                           │
┌─────────────────┐     ┌──────────────┐              │
│ SonarQube Cloud │────▶│ Quality Data │              │
│    Analysis     │     │ • Bugs: 0    │              │
│                 │     │ • Security: A│              │
│                 │     │ • Reliability│              │
│                 │     │ • Coverage   │              │
└─────────────────┘     └──────┬───────┘              │
                               │                      │
                               ▼                      ▼
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│ Gate Evaluation │◀────│  Permit.io   │◀────│  OPAL Data     │
│     Script      │     │     PDP      │     │    Fetcher     │
│ • Security Gate │     │              │     │                │
│ • Quality Gate  │     │              │     │                │
└─────────────────┘     └──────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│ Combined Result │
│  - Pass         │
│  - Warn         │
│  - Fail         │
│  - Override     │
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

### 2. SonarQube Cloud Integration

- **Location**: `/sonarqube-cloud-scanning`
- **Purpose**: Code quality and security analysis with comprehensive metrics
- **Quality Gates**: Pass/Fail criteria based on configurable thresholds
- **Metrics Tracked**:
  - **Security Rating**: A (no vulnerabilities)
  - **Reliability Rating**: A (no bugs) 
  - **Maintainability Rating**: A (no code smells)
  - **Test Coverage**: 25% with JaCoCo integration
  - **Code Duplication**: 0% duplication detected
- **Integration**: Maven plugin with automatic CI/CD analysis

### 3. Docker Compose Infrastructure

- **Permit.io PDP**: Policy Decision Point for gate evaluation
- **OPAL Server**: Manages policy updates and data synchronization
- **OPAL Fetcher**: Custom service to fetch Snyk vulnerability data
- **Redis**: Message broker for OPAL pub/sub
- **Spring App**: The mock application being tested

### 4. Security Policies & Role-Based Access

- **Hard Gate**: Fails pipeline on critical vulnerabilities
- **Soft Gate**: Warns on high severity vulnerabilities
- **Info Gate**: Provides information on medium severity issues
- **Quality Gate**: Evaluates code quality metrics and ratings
- **Editor Override**: Allows authorized users to bypass security gates with full audit trail
- **Role-Based Permissions**: Different access levels (ci-pipeline, editor) with appropriate permissions

### 5. Gate Evaluation Scripts (`permit-gating/scripts/`)

- **evaluate-gates.sh**: Main security gate evaluation script with role-based override support
- **test-gates-local.sh**: Local testing utility for full pipeline simulation
- **validate-permit.sh**: Permit.io configuration validation script
- **Enhanced .env Configuration**: Flexible user role and key management

### 6. SonarQube Analysis Scripts (`sonarqube-cloud-scanning/scripts/`)

- **validate-sonarqube.sh**: SonarQube Cloud configuration validation
- **analyze-quality-gates.sh**: Quality gate analysis and metrics extraction
- **test-sonarqube-local.sh**: Local SonarQube testing utility

### 7. GitHub Actions Workflow

- Builds and scans the application with both Snyk and SonarQube
- Evaluates combined security and quality gates with role-based access
- Makes deployment decisions based on both gate results and user permissions
- Displays comprehensive metrics including A/A/A quality ratings

## Prerequisites

- Docker & Docker Compose (20.10.0+)
- Java 11+ and Maven 3.8+
- Node.js 14+ (for Snyk CLI)
- Git
- **Permit.io account and API key** ([Configuration Guide](CONFIGURATION_GUIDE.md))
- **Snyk account and API token** ([Configuration Guide](CONFIGURATION_GUIDE.md))
- **SonarQube Cloud account and token** ([SonarQube Setup Guide](sonarqube-cloud-scanning/docs/SETUP_GUIDE.md))
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

chmod +x sonarqube-cloud-scanning/scripts/validate-sonarqube.sh
./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh

# Note: The validate-permit.sh script will automatically install OPA CLI if needed
# for policy syntax validation. You can skip the installation when prompted if
# you don't need syntax checking (the policies will still work with Permit.io PDP)
```

### 3. Run Local Tests

**Security Gates Test:**
```bash
chmod +x permit-gating/scripts/test-gates-local.sh
./permit-gating/scripts/test-gates-local.sh
```

**SonarQube Quality Gates Test:**
```bash
chmod +x sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh
./sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh
```

Select option 1 for a full test run in both cases.

## Manual Testing

### Start Services

```bash
docker-compose up -d
```

### Run Security Scans

**Snyk Vulnerability Scan:**
```bash
cd microservice-moc-app
mvn clean compile
snyk test --json > ../snyk-scanning/results/snyk-results.json
cd ..
```

**SonarQube Quality Analysis:**
```bash
cd microservice-moc-app
mvn clean test sonar:sonar
cd ..
```

### Evaluate Gates

**Security Gates:**
```bash
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

**Quality Gates:**
```bash
./sonarqube-cloud-scanning/scripts/analyze-quality-gates.sh -k poc-pipeline_poc-pipeline -o sonarqube-cloud-scanning/results/quality-gate-result.json
```

### Expected Results

**Security Scan Results:**
With the included vulnerable dependencies, you should see:

- **Hard Gate**: FAIL (due to critical Log4j vulnerability)
- **Soft Gate**: WARN (due to high severity Commons Collections vulnerability)
- **Info**: Medium severity Jackson Databind vulnerability

**Quality Analysis Results:**
With the current clean codebase, you should see:

- **Quality Gate**: PASS ✅
- **Security Rating**: A (no vulnerabilities)
- **Reliability Rating**: A (no bugs) 
- **Maintainability Rating**: A (no code smells)
- **Test Coverage**: 25% with JaCoCo integration
- **Code Duplication**: 0%

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
- `SONAR_TOKEN`: Your SonarQube Cloud authentication token
- `SONAR_ORGANIZATION`: Your SonarQube Cloud organization key
- `SONAR_PROJECT_KEY`: Your SonarQube Cloud project key

### 2. Push Code

The pipeline will automatically trigger on:

- Push to `main` or `develop` branches
- Pull requests to `main` branch
- Manual workflow dispatch

### 3. Monitor Pipeline

Check the Actions tab to see:

- Build and scan results (Snyk + SonarQube)
- Security and quality gate evaluation outcomes
- Combined gate decision matrix
- Comprehensive quality ratings (A/A/A)
- Deployment status

## Gate Scenarios

### Scenario 1: Critical Vulnerability (Hard Gate)

**Setup**: Application includes Log4j 2.14.1
**Security Result**: FAIL - Pipeline blocked
**Quality Result**: PASS (A/A/A ratings)
**Combined Result**: BLOCKED 
**Message**: "Critical vulnerabilities must be resolved before deployment"

### Scenario 2: High Severity (Soft Gate) + Quality Issues

**Setup**: Remove critical vulnerabilities, keep high severity ones + introduce code smells
**Security Result**: WARN - High severity detected
**Quality Result**: FAIL - Maintainability below threshold
**Combined Result**: BLOCKED
**Message**: "Quality gate failed - address code quality issues"

### Scenario 3: Clean Build (Both Gates Pass)

**Setup**: Update all dependencies to secure versions + clean code
**Security Result**: PASS - No vulnerabilities
**Quality Result**: PASS (A/A/A ratings)
**Combined Result**: DEPLOY
**Message**: "All security and quality gates passed"

### Scenario 4: Quality Pass + Security Warning

**Setup**: High severity vulnerabilities + clean code
**Security Result**: WARN - High severity detected
**Quality Result**: PASS (A/A/A ratings)
**Combined Result**: REVIEW & DEPLOY
**Message**: "Quality gates passed, security review recommended"

### Scenario 5: Editor Override (Security Gate Bypass)

**Setup**: Configure editor role in .env and run with critical vulnerabilities
**Security Result**: OVERRIDE - Editor privileges
**Quality Result**: PASS (A/A/A ratings)
**Combined Result**: DEPLOY WITH AUDIT
**Message**: "EDITOR OVERRIDE - Deployment allowed with editor privileges"
**Details**:

- Shows clear audit trail of who overrode the gates
- Lists all critical vulnerabilities being overridden
- Quality metrics still evaluated and displayed
- Provides recommendations for post-deployment remediation

## Customization

### Adding New Security Gates

Edit `permit-gating/policies/gating_policy.rego` to add custom rules:

```rego
custom_gate_fail if {
    input.resource.attributes.customMetric > threshold
}
```

### Modifying Security Thresholds

Update the policy rules in `gating_policy.rego`:

```rego
hard_gate_fail if {
    input.resource.attributes.criticalCount > 0  # Change threshold here
}
```

### Customizing SonarQube Quality Gates

Modify quality gate thresholds in SonarQube Cloud:

1. Go to **Quality Gates** in your SonarQube Cloud project
2. Edit conditions for:
   - **Coverage**: Minimum % coverage required
   - **Duplicated Lines**: Maximum % duplication allowed
   - **Maintainability Rating**: Acceptable rating (A-E)
   - **Reliability Rating**: Acceptable rating (A-E)
   - **Security Rating**: Acceptable rating (A-E)

### Adding Data Sources

Extend the OPAL fetcher in `/opal-fetcher/main.py` to integrate additional security tools.

### SonarQube Project Configuration

Edit `sonarqube-cloud-scanning/config/sonar-project.properties`:

```properties
# Quality Gate Settings
sonar.qualitygate.wait=true
sonar.qualitygate.timeout=300

# Coverage Settings
sonar.coverage.exclusions=**/test/**,**/mock/**

# Analysis Settings
sonar.projectName=Your Custom Project Name
sonar.projectVersion=1.0.0
```

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

### Audit Logging Configuration

For audit logs to appear correctly in Permit.io, several configuration requirements must be met:

#### Environment Variables

**Local Environment (.env file):**
```bash
USER_KEY=david-santander
USER_ROLE=editor
```

**GitHub Actions (automatically configured in workflow):**
```yaml
USER_KEY: david-santander
USER_ROLE: ${{ github.event.inputs.user_role || 'editor' }}
```

#### Docker Compose Configuration

The PDP container requires explicit audit logging environment variables:

```yaml
environment:
  - PDP_API_KEY=${PERMIT_API_KEY}
  - PDP_DEBUG=true
  - PDP_LOG_LEVEL=DEBUG
  - PDP_AUDIT_LOG_ENABLED=true
  - PDP_AUDIT_LOG_LEVEL=info
  - PDP_DECISION_LOG_ENABLED=true
```

#### GitHub Actions Requirements

The GitHub Actions workflow includes several critical steps for audit logging:

1. **PDP Synchronization Verification**: Ensures user data is synced before evaluation
2. **Network Connectivity Test**: Verifies connection to Permit.io cloud
3. **Audit Log Delay**: 10-second delay after evaluation to ensure logs are sent

#### Troubleshooting Audit Logs

**Issue: Audit logs appear locally but not in GitHub Actions**

**Root Causes:**
- Missing USER_KEY and USER_ROLE in GitHub Actions environment
- PDP not synchronized with Permit.io cloud
- Network connectivity issues
- Missing audit logging environment variables

**Solutions:**
1. **Verify Environment Variables**: Ensure USER_KEY and USER_ROLE are included in GitHub Actions .env file creation
2. **Check PDP Sync**: Look for "PDP is fully synced with Permit.io cloud" message in logs
3. **Test Connectivity**: Verify "Successfully connected to Permit.io cloud API" message
4. **Enable Audit Logging**: Ensure PDP_AUDIT_LOG_ENABLED=true in Docker Compose
5. **Allow Processing Time**: 10-second delay after evaluation ensures logs are transmitted

**Verification Steps:**
```bash
# Check local audit logs
./permit-gating/scripts/test-gates-local.sh

# Verify in Permit.io dashboard:
# 1. Login to https://app.permit.io
# 2. Navigate to Audit Logs
# 3. Filter by User: david-santander, Action: deploy
```

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
DEBUG=true ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

### Audit Logs Not Appearing

**Issue**: Audit logs work locally but don't appear in GitHub Actions

**Diagnosis Steps:**
```bash
# 1. Check PDP container logs
docker compose logs permit-pdp --tail=20

# 2. Verify user synchronization
curl -X POST http://localhost:7766/allowed \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PERMIT_API_KEY" \
  -d '{"user":{"key":"david-santander","attributes":{"role":"editor"}},"action":"test","resource":{"type":"deployment","key":"sync-test","attributes":{}}}'

# 3. Test connectivity to Permit.io
curl -sf https://api.permit.io/v2/projects -H "Authorization: Bearer $PERMIT_API_KEY"
```

**Common Solutions:**

1. **Missing Environment Variables in GitHub Actions:**
   - Ensure USER_KEY and USER_ROLE are added to .env file creation in workflow
   - Check that Docker Compose receives these variables

2. **PDP Synchronization Issues:**
   - Add sync verification loop in GitHub Actions
   - Wait for user data to be synchronized with Permit.io cloud

3. **Audit Logging Not Enabled:**
   - Add explicit audit logging environment variables to Docker Compose
   - Verify PDP_AUDIT_LOG_ENABLED=true

4. **Network Connectivity:**
   - Add connectivity test to Permit.io cloud in workflow
   - Ensure container can reach https://api.permit.io

5. **Insufficient Processing Time:**
   - Add 10-second delay after gate evaluation
   - Allow time for audit logs to be transmitted before container shutdown

### Snyk Not Working

- Verify API token is correct
- Check organization ID matches your Snyk account
- Use mock data mode if Snyk is not configured

## Project Structure

```
cicd-pipeline-poc/
├── .github/
│   └── workflows/
│       └── gating-pipeline.yml      # Enhanced workflow with SonarQube
├── permit-gating/                   # Security gating components
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
├── sonarqube-cloud-scanning/        # SonarQube Cloud integration
│   ├── config/                     # SonarQube configuration
│   │   └── sonar-project.properties # Project settings
│   ├── scripts/                    # Analysis scripts
│   │   ├── validate-sonarqube.sh   # Configuration validation
│   │   ├── analyze-quality-gates.sh # Quality gate analysis
│   │   └── test-sonarqube-local.sh # Local testing script
│   ├── results/                    # Analysis results
│   │   └── quality-gate-result.json # Quality metrics & ratings
│   └── docs/                       # SonarQube documentation
│       ├── SETUP_GUIDE.md          # Setup instructions
│       ├── INTEGRATION_GUIDE.md    # CI/CD integration
│       └── TROUBLESHOOTING.md      # Common issues
├── microservice-moc-app/
│   ├── src/                        # Spring Boot application source
│   ├── pom.xml                     # Maven config with SonarQube & JaCoCo
│   └── Dockerfile                  # Application container
├── snyk-scanning/                   # Snyk security scanning
│   ├── scripts/
│   │   └── validate-snyk.sh        # Snyk validation script
│   └── results/                    # Vulnerability scan results
├── docker-compose.yml              # Main infrastructure definition
├── .env                            # Environment configuration
└── README.md                       # This file (updated with SonarQube)
```

## Next Steps

After validating this PoC:

1. **Production Deployment**: Deploy PDP to Kubernetes for high availability
2. **GitOps Integration**: Implement policy-as-code workflow  
3. **Additional Security Scanners**: Add BlackDuck, Checkmarx, and other tools
4. **Advanced Quality Gates**: Implement custom SonarQube quality profiles
5. **Exception Handling**: Integrate with Jira for exception management
6. **Reporting Dashboard**: Build visualization for combined security and quality metrics
7. **Maker-Checker Workflow**: Implement approval process for policy changes
8. **Multi-Branch Support**: Enhance SonarQube PR decoration and branch analysis

## Support

For issues or questions:

- **Start here**: [Configuration Guide](CONFIGURATION_GUIDE.md) for setup help
- **Security Gating**: [Gating Documentation](permit-gating/docs/README.md) for gating-specific setup
- **SonarQube Integration**: [SonarQube Setup Guide](sonarqube-cloud-scanning/docs/SETUP_GUIDE.md) for quality gate configuration
- Review the [Business Requirements Document](permit-gating/docs/PERMIT_IO_GATING_BRD.md)  
- Check service logs: `docker-compose logs`
- Enable debug mode: `DEBUG=true ./permit-gating/scripts/evaluate-gates.sh`
- Validate your setup: 
  - `./snyk-scanning/scripts/validate-snyk.sh`
  - `./permit-gating/scripts/validate-permit.sh`
  - `./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh`

## License

This is a proof of concept for internal use.
