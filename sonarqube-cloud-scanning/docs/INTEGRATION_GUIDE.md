# SonarQube Cloud GitHub Actions Integration Guide

## Table of Contents
1. [Overview](#overview)
2. [Integration Architecture](#integration-architecture)
3. [GitHub Actions Workflow](#github-actions-workflow)
4. [Security Gates Integration](#security-gates-integration)
5. [Pull Request Decoration](#pull-request-decoration)
6. [Advanced Configuration](#advanced-configuration)
7. [Best Practices](#best-practices)

## Overview

This guide details how SonarQube Cloud is integrated into the CI/CD pipeline using GitHub Actions, working alongside Snyk security scanning and Permit.io policy-based gating.

## Integration Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  GitHub Events  │────▶│  GitHub Actions  │────▶│  Build & Test   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                           │
                                ┌──────────────────────────┼──────────────────────────┐
                                │                          │                          │
                                ▼                          ▼                          ▼
                    ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
                    │  Snyk Security   │     │  SonarQube Cloud │     │    JaCoCo        │
                    │     Scanning      │     │     Analysis     │     │   Coverage       │
                    └──────────────────┘     └──────────────────┘     └──────────────────┘
                                │                          │                          │
                                └──────────────────────────┼──────────────────────────┘
                                                           │
                                                           ▼
                                                ┌──────────────────┐
                                                │  Quality Gates   │
                                                │   Evaluation     │
                                                └──────────────────┘
                                                           │
                                                           ▼
                                                ┌──────────────────┐
                                                │   Permit.io      │
                                                │  Authorization   │
                                                └──────────────────┘
```

## GitHub Actions Workflow

### Workflow Structure

The SonarQube Cloud integration is embedded in the `gating-pipeline.yml` workflow:

```yaml
name: CI/CD Security Gating Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
```

### Key Job Steps

#### 1. Build and Test Phase
```yaml
- name: Build Spring Boot application
  run: |
    cd microservice-moc-app
    mvn clean compile test
```

#### 2. SonarQube Validation
```yaml
- name: Validate SonarQube configuration
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_ORGANIZATION: ${{ secrets.SONAR_ORGANIZATION }}
  run: |
    chmod +x sonarqube-cloud-scanning/scripts/validate-sonarqube.sh
    ./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh
```

#### 3. SonarQube Analysis
```yaml
- name: Run SonarQube Cloud Analysis
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  run: |
    cd microservice-moc-app
    mvn sonar:sonar \
      -Dsonar.host.url=https://sonarcloud.io \
      -Dsonar.token=$SONAR_TOKEN \
      -Dsonar.qualitygate.wait=true
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SONAR_TOKEN` | Yes | Authentication token for SonarQube Cloud |
| `SONAR_ORGANIZATION` | Yes | Organization identifier in SonarQube Cloud |
| `SONAR_PROJECT_KEY` | No | Project key (defaults to `cicd-pipeline-poc`) |
| `GITHUB_TOKEN` | Yes | Automatically provided by GitHub Actions |

## Security Gates Integration

### Combined Gate Evaluation

The pipeline combines multiple security and quality checks:

1. **Snyk Vulnerability Scanning**
   - Critical vulnerabilities → Hard gate (blocking)
   - High vulnerabilities → Soft gate (warning)
   - Medium/Low → Informational

2. **SonarQube Quality Gate**
   - Failed quality gate → Hard gate (blocking)
   - Warnings → Soft gate (warning)
   - Passed → Continue

3. **Permit.io Policy Decision**
   - Role-based authorization
   - Context-aware decisions
   - Audit trail logging

### Gate Decision Matrix

| Snyk Result | SonarQube Result | Permit.io Decision | Pipeline Action |
|-------------|------------------|-------------------|-----------------|
| Critical vulns | Any | Deny | ❌ Block deployment |
| High vulns | Failed | Deny | ❌ Block deployment |
| High vulns | Passed | Allow (with warning) | ⚠️ Proceed with caution |
| None | Failed | Deny | ❌ Block deployment |
| None | Passed | Allow | ✅ Deploy |

### Implementation Example

```bash
# Combine gate results
if [ $SECURITY_GATE_RESULT -eq 2 ] || [ $QUALITY_GATE_RESULT -eq 2 ]; then
    GATE_RESULT=2  # FAIL
elif [ $SECURITY_GATE_RESULT -eq 1 ] || [ $QUALITY_GATE_RESULT -eq 1 ]; then
    GATE_RESULT=1  # WARNING
else
    GATE_RESULT=0  # PASS
fi
```

## Pull Request Decoration

### Automatic PR Comments

SonarQube Cloud automatically adds status checks and comments to pull requests:

1. **Status Check**: Shows quality gate pass/fail status
2. **Detailed Metrics**: New code coverage, issues, duplications
3. **Direct Links**: Links to detailed analysis in SonarQube Cloud

### Enabling PR Decoration

1. In SonarQube Cloud, go to **Project Settings** → **Pull Request Decoration**
2. Select **GitHub** as the provider
3. Configure the GitHub App (usually automatic)

### Branch Protection

Configure branch protection rules in GitHub:

```yaml
# Required status checks
- SonarQube Code Analysis
- Security Gate Evaluation
- Build and Test
```

## Advanced Configuration

### Custom Quality Profiles

Create project-specific quality profiles:

1. Navigate to **Quality Profiles** in SonarQube Cloud
2. Create a new profile extending "Sonar way"
3. Customize rules for your project needs
4. Assign to your project

### Monorepo Support

For monorepo configurations:

```properties
# sonar-project.properties
sonar.modules=module1,module2
module1.sonar.projectBaseDir=./module1
module2.sonar.projectBaseDir=./module2
```

### Coverage Thresholds

Configure coverage requirements:

```xml
<!-- pom.xml -->
<properties>
    <sonar.coverage.exclusions>
        **/*Test.java,
        **/*Application.java,
        **/config/**
    </sonar.coverage.exclusions>
    <sonar.coverage.jacoco.xmlReportPaths>
        target/site/jacoco/jacoco.xml
    </sonar.coverage.jacoco.xmlReportPaths>
</properties>
```

### Security Hotspot Review

Configure security hotspot settings:

```properties
# Maximum allowed security hotspots
sonar.security.hotspots.maxIssues=0

# Review priority
sonar.security.hotspots.review.priority=HIGH
```

## Best Practices

### 1. Incremental Analysis

- Run analysis on every push to feature branches
- Use `sonar.pullrequest.branch` for PR analysis
- Cache SonarQube packages in GitHub Actions

### 2. Quality Gate Configuration

**Recommended Settings:**
- **Coverage on New Code**: ≥ 80%
- **Duplicated Lines**: < 3%
- **Maintainability Rating**: A
- **Reliability Rating**: A
- **Security Rating**: A
- **Security Hotspots Reviewed**: 100%

### 3. Performance Optimization

```yaml
# Cache SonarQube packages
- uses: actions/cache@v4
  with:
    path: ~/.sonar/cache
    key: ${{ runner.os }}-sonar
    restore-keys: ${{ runner.os }}-sonar
```

### 4. Parallel Execution

Run SonarQube analysis in parallel with other checks:

```yaml
jobs:
  sonarqube:
    runs-on: ubuntu-latest
    # Run in parallel with security scanning
    
  snyk:
    runs-on: ubuntu-latest
    # Run in parallel with code quality
    
  gates:
    needs: [sonarqube, snyk]
    # Evaluate combined results
```

### 5. Notification Setup

Configure notifications for quality gate failures:

1. In SonarQube Cloud → **Project Settings** → **Notifications**
2. Enable notifications for:
   - Quality gate status changes
   - New issues on new code
   - Analysis failures

## Integration with CI/CD Pipeline

### Pipeline Stages

1. **Code Checkout** → Get latest code
2. **Build & Compile** → Maven build
3. **Unit Tests** → Run tests with JaCoCo
4. **Security Scan** → Snyk vulnerability scanning
5. **Code Analysis** → SonarQube Cloud analysis
6. **Quality Gates** → Combined gate evaluation
7. **Authorization** → Permit.io policy check
8. **Deployment** → If all gates pass

### Failure Handling

```yaml
- name: Handle Quality Gate Failure
  if: failure()
  run: |
    echo "Quality gate failed. Review issues at:"
    echo "https://sonarcloud.io/dashboard?id=${{ env.SONAR_PROJECT_KEY }}"
```

## Monitoring and Reporting

### GitHub Step Summary

The workflow generates comprehensive summaries:

```markdown
### 📊 Code Quality Analysis (SonarQube Cloud)

| Metric | Status |
|--------|--------|
| Quality Gate | ✅ PASSED |
| Bugs | 0 |
| Vulnerabilities | 0 |
| Security Hotspots | 2 |
| Code Smells | 15 |
| Coverage | 82.5% |
| Duplications | 2.1% |
```

### Metrics Tracking

Track quality trends over time:
- Coverage evolution
- Technical debt ratio
- Issue count trends
- Quality gate history

## Troubleshooting Common Issues

### Analysis Timeout

If analysis times out:
```yaml
-Dsonar.qualitygate.timeout=600  # Increase timeout to 10 minutes
```

### Missing Coverage

Ensure JaCoCo runs before SonarQube:
```bash
mvn clean test jacoco:report sonar:sonar
```

### Authentication Issues

Verify token permissions:
```bash
curl -u "$SONAR_TOKEN:" \
  "https://sonarcloud.io/api/authentication/validate"
```

## Next Steps

1. Review the [Troubleshooting Guide](TROUBLESHOOTING.md) for detailed problem resolution
2. Configure IDE integration with SonarLint
3. Set up custom quality profiles for your team
4. Implement security hotspot review process
5. Configure webhooks for external integrations

## Resources

- [SonarQube Cloud Documentation](https://docs.sonarcloud.io)
- [GitHub Actions for SonarCloud](https://docs.sonarcloud.io/advanced-setup/ci-based-analysis/github-actions-for-sonarcloud/)
- [Quality Gate Configuration](https://docs.sonarcloud.io/improving/quality-gates/)
- [Security Hotspot Review](https://docs.sonarcloud.io/digging-deeper/security-hotspots/)