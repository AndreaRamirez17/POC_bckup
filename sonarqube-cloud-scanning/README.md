# SonarQube Cloud Integration

This directory contains all the configuration, scripts, and documentation for integrating SonarQube Cloud code quality and security analysis into the CI/CD pipeline.

## 📁 Directory Structure

```
sonarqube-cloud-scanning/
├── config/
│   └── sonar-project.properties    # SonarQube project configuration
├── scripts/
│   ├── validate-sonarqube.sh       # Configuration validation script
│   ├── analyze-quality-gates.sh    # Quality gate analysis script
│   └── test-sonarqube-local.sh     # Local testing script
├── results/
│   └── .gitkeep                     # Directory for analysis results
└── docs/
    ├── SETUP_GUIDE.md               # Complete setup instructions
    ├── INTEGRATION_GUIDE.md         # GitHub Actions integration details
    └── TROUBLESHOOTING.md           # Common issues and solutions
```

## 🚀 Quick Start

### Prerequisites

1. **SonarQube Cloud Account**: Sign up at [sonarcloud.io](https://sonarcloud.io)
2. **GitHub Repository**: With admin access to configure secrets
3. **Local Development**: Java 11+ and Maven 3.6+

### Setup Steps

1. **Configure SonarQube Cloud**:
   ```bash
   # Set environment variables
   export SONAR_TOKEN="your-token-here"
   export SONAR_ORGANIZATION="your-org-key"
   export SONAR_PROJECT_KEY="your-project-key"
   ```

2. **Validate Configuration**:
   ```bash
   ./scripts/validate-sonarqube.sh
   ```

3. **Run Local Test**:
   ```bash
   ./scripts/test-sonarqube-local.sh
   ```

4. **Configure GitHub Secrets**:
   - Add `SONAR_TOKEN` to repository secrets
   - Add `SONAR_ORGANIZATION` to repository secrets
   - Add `SONAR_PROJECT_KEY` to repository secrets

## 📊 Features

### Code Quality Analysis
- **Bugs Detection**: Identifies potential bugs in code
- **Code Smells**: Detects maintainability issues
- **Technical Debt**: Calculates time to fix all issues
- **Duplications**: Finds duplicated code blocks

### Security Analysis
- **Vulnerabilities**: Identifies security vulnerabilities
- **Security Hotspots**: Points needing security review
- **OWASP Top 10**: Coverage of common security issues
- **CWE Coverage**: Common Weakness Enumeration detection

### Test Coverage
- **Line Coverage**: Percentage of lines covered by tests
- **Branch Coverage**: Percentage of branches covered
- **JaCoCo Integration**: Automatic coverage report processing
- **Coverage Trends**: Track coverage over time

### Quality Gates
- **Pass/Fail Criteria**: Configurable quality thresholds
- **New Code Focus**: Apply stricter rules to new code
- **Custom Gates**: Create project-specific requirements
- **PR Blocking**: Prevent merging of failing code

## 🔧 Configuration

### Maven Configuration

The project's `pom.xml` is configured with:
- SonarQube Maven Plugin (v3.10.0.2594)
- JaCoCo Plugin for coverage (v0.8.8)
- Proper source and test directories

### Properties Configuration

Edit `config/sonar-project.properties`:
```properties
sonar.organization=your-organization-key
sonar.projectKey=your-project-key
sonar.projectName=Your Project Name
```

## 📈 Integration with CI/CD Pipeline

### Pipeline Integration

SonarQube analysis is integrated into the `gating-pipeline.yml` workflow:

1. **Build & Test**: Compile code and run tests with coverage
2. **SonarQube Analysis**: Send results to SonarQube Cloud
3. **Quality Gate Check**: Wait for and evaluate quality gate
4. **Gate Decision**: Combined with security gates for deployment decision

### Quality Gate Matrix

| SonarQube Status | Security Status | Result |
|-----------------|-----------------|---------|
| ✅ Passed | ✅ Clean | Deploy |
| ✅ Passed | ⚠️ Warnings | Review & Deploy |
| ❌ Failed | ✅ Clean | Block |
| ❌ Failed | ❌ Critical | Block |

## 📝 Scripts

### validate-sonarqube.sh
Validates SonarQube Cloud configuration:
- Checks environment variables
- Tests API connectivity
- Verifies organization access
- Validates project configuration

### analyze-quality-gates.sh
Analyzes quality gate results:
- Fetches current quality gate status
- Retrieves project metrics
- Evaluates gate decision
- Outputs JSON results

### test-sonarqube-local.sh
Complete local testing workflow:
- Builds the project
- Runs tests with coverage
- Performs SonarQube analysis
- Checks quality gate status

## 🐛 Troubleshooting

Common issues and solutions:

1. **Authentication Failed**:
   - Verify SONAR_TOKEN is correct
   - Check token permissions in SonarQube Cloud

2. **Project Not Found**:
   - Ensure project exists in SonarQube Cloud
   - Verify project key matches configuration

3. **Coverage Missing**:
   - Check JaCoCo plugin configuration
   - Ensure tests run before analysis

4. **Quality Gate Timeout**:
   - Increase timeout value in configuration
   - Check SonarQube Cloud service status

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 📚 Documentation

- **[Setup Guide](docs/SETUP_GUIDE.md)**: Complete setup instructions
- **[Integration Guide](docs/INTEGRATION_GUIDE.md)**: GitHub Actions integration
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**: Common issues and solutions

## 🔗 Resources

- [SonarQube Cloud](https://sonarcloud.io)
- [Documentation](https://docs.sonarcloud.io)
- [Community Forum](https://community.sonarsource.com)
- [Maven Scanner](https://docs.sonarcloud.io/advanced-setup/ci-based-analysis/sonarscanner-for-maven/)

## 📄 License

This integration is part of the CI/CD Pipeline POC project.