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
- **Location**: `/mock-app`
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

### 3. Security Policies
- **Hard Gate**: Fails pipeline on critical vulnerabilities
- **Soft Gate**: Warns on high severity vulnerabilities
- **Info Gate**: Provides information on medium severity issues

### 4. GitHub Actions Workflow
- Builds and scans the application
- Evaluates security gates
- Makes deployment decisions based on gate results

## Prerequisites

- Docker & Docker Compose (20.10.0+)
- Java 11+ and Maven 3.8+
- Node.js 14+ (for Snyk CLI)
- Git
- **Permit.io account and API key** ([Configuration Guide](CONFIGURATION_GUIDE.md))
- **Snyk account and API token** ([Configuration Guide](CONFIGURATION_GUIDE.md))

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
# Copy environment template
cp .env.example .env

# Edit .env with your API keys (see Configuration Guide for details)
# PERMIT_API_KEY=your_permit_api_key_here
# SNYK_TOKEN=your_snyk_token_here
# SNYK_ORG_ID=your_snyk_org_id_here

# Validate configurations
chmod +x scripts/validate-snyk.sh
./scripts/validate-snyk.sh

chmod +x scripts/validate-permit.sh  
./scripts/validate-permit.sh
```

### 3. Run Local Test
```bash
chmod +x scripts/test-gates-local.sh
./scripts/test-gates-local.sh
```

Select option 1 for a full test run.

## Manual Testing

### Start Services
```bash
docker-compose up -d
```

### Run Snyk Scan
```bash
cd mock-app
mvn clean compile
snyk test --json > ../snyk-results.json
cd ..
```

### Evaluate Gates
```bash
./scripts/evaluate-gates.sh snyk-results.json
```

### Expected Results

With the included vulnerable dependencies, you should see:
- **Hard Gate**: FAIL (due to critical Log4j vulnerability)
- **Soft Gate**: WARN (due to high severity Commons Collections vulnerability)
- **Info**: Medium severity Jackson Databind vulnerability

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

## Customization

### Adding New Gates
Edit `/policies/gating_policy.rego` to add custom rules:
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

## Troubleshooting

### Services Not Starting
```bash
docker-compose logs permit-pdp
docker-compose logs opal-fetcher
```

### Gate Evaluation Failing
```bash
# Check PDP health
curl http://localhost:7766/ready

# Test with debug mode
DEBUG=true ./scripts/evaluate-gates.sh snyk-results.json
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
├── mock-app/
│   ├── src/                        # Spring Boot application source
│   ├── pom.xml                     # Maven config with vulnerable deps
│   └── Dockerfile                  # Application container
├── opal-fetcher/
│   ├── main.py                     # Custom Snyk data fetcher
│   └── Dockerfile                  # Fetcher container
├── policies/
│   ├── gating_policy.rego          # OPA/Rego security policies
│   └── permit_config.json          # Permit.io configuration
├── scripts/
│   ├── evaluate-gates.sh           # Gate evaluation script
│   └── test-gates-local.sh         # Local testing utility
├── docker-compose.yml              # Infrastructure definition
├── .env.example                    # Environment template
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
- Review the [Business Requirements Document](gating/PERMIT_IO_GATING_BRD.md)  
- Check service logs: `docker-compose logs`
- Enable debug mode: `DEBUG=true ./scripts/evaluate-gates.sh`
- Validate your setup: `./scripts/validate-snyk.sh` and `./scripts/validate-permit.sh`

## License

This is a proof of concept for internal use.
