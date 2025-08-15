# SonarQube Cloud Setup Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [SonarQube Cloud Account Setup](#sonarqube-cloud-account-setup)
4. [Project Configuration](#project-configuration)
5. [GitHub Integration](#github-integration)
6. [Local Development Setup](#local-development-setup)
7. [Verification](#verification)

## Overview

SonarQube Cloud is a cloud-based code quality and security service that integrates seamlessly with GitHub Actions. This guide will walk you through setting up SonarQube Cloud for the CI/CD Pipeline POC project.

## Prerequisites

Before starting, ensure you have:
- A GitHub account with access to your repository
- Administrative access to create GitHub secrets
- Java 11+ installed locally (for testing)
- Maven 3.6+ installed locally (for testing)

## SonarQube Cloud Account Setup

### Step 1: Create a SonarQube Cloud Account

1. Navigate to [https://sonarcloud.io](https://sonarcloud.io)
2. Click **"Log in"** in the top right corner
3. Select **"Log in with GitHub"**
4. Authorize SonarQube Cloud to access your GitHub account

### Step 2: Create an Organization

1. After logging in, click your profile avatar → **"My Organizations"**
2. Click **"Create Organization"**
3. Choose **"Import from GitHub"**
4. Select your GitHub organization or personal account
5. Choose a unique organization key (e.g., `your-username-org`)
6. Click **"Continue"** and complete the setup

> **Note**: The organization key will be used in your configuration. Save it for later use.

### Step 3: Generate an Authentication Token

1. Click your profile avatar → **"My Account"**
2. Navigate to the **"Security"** tab
3. Under **"Generate Tokens"**, enter a token name (e.g., `github-actions-token`)
4. Click **"Generate"**
5. **Copy the token immediately** - you won't be able to see it again!

> **Important**: Store this token securely. You'll need it for GitHub secrets.

## Project Configuration

### Step 1: Import Your Project

1. In SonarQube Cloud, go to your organization dashboard
2. Click **"Analyze new project"**
3. Select your repository from the list (e.g., `cicd-pipeline-poc`)
4. Click **"Set Up"**

### Step 2: Configure Project Settings

1. Choose **"With GitHub Actions"** as your analysis method
2. Note down the provided values:
   - **Organization Key**: Your organization identifier
   - **Project Key**: Usually `organization_repository-name`

### Step 3: Configure Quality Gate

1. Navigate to your project → **"Project Settings"** → **"Quality Gate"**
2. Select **"Sonar way"** (recommended) or create a custom quality gate
3. Configure thresholds for:
   - Code Coverage (recommended: 80% for new code)
   - Duplicated Lines (recommended: < 3%)
   - Maintainability Rating (recommended: A)
   - Reliability Rating (recommended: A)
   - Security Rating (recommended: A)

### Step 4: Set Up Branch Analysis

1. Go to **"Project Settings"** → **"Branches & Pull Requests"**
2. Ensure **"Automatic branch analysis"** is enabled
3. Configure long-lived branch patterns (e.g., `main`, `develop`)
4. Enable **"Pull Request decoration"** for GitHub

## GitHub Integration

### Step 1: Add GitHub Secrets

Add the following secrets to your GitHub repository:

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `SONAR_TOKEN` | Your SonarQube token | Authentication token from Step 3 of account setup |
| `SONAR_ORGANIZATION` | Your org key | Organization key from SonarQube Cloud |
| `SONAR_PROJECT_KEY` | Your project key | Project key (usually `org_repo-name`) |

### Step 2: Configure Repository Settings

1. In your repository settings, go to **"Branches"**
2. Add a branch protection rule for `main`
3. Enable **"Require status checks to pass before merging"**
4. Add **"SonarQube Code Analysis"** as a required status check

### Step 3: Update Project Files

Update the following configuration in your project:

#### `sonarqube-cloud-scanning/config/sonar-project.properties`
```properties
sonar.organization=your-actual-org-key
sonar.projectKey=your-actual-project-key
```

#### `microservice-moc-app/pom.xml`
```xml
<properties>
    <sonar.organization>your-actual-org-key</sonar.organization>
    <sonar.projectKey>your-actual-project-key</sonar.projectKey>
</properties>
```

## Local Development Setup

### Step 1: Set Environment Variables

#### Linux/Mac:
```bash
export SONAR_TOKEN="your-token-here"
export SONAR_ORGANIZATION="your-org-key"
export SONAR_PROJECT_KEY="your-project-key"
```

#### Windows (PowerShell):
```powershell
$env:SONAR_TOKEN="your-token-here"
$env:SONAR_ORGANIZATION="your-org-key"
$env:SONAR_PROJECT_KEY="your-project-key"
```

### Step 2: Install Dependencies

Ensure you have the following installed:
```bash
# Check Java version
java -version  # Should be 11 or higher

# Check Maven version
mvn -version  # Should be 3.6 or higher

# Install jq for JSON parsing (optional but recommended)
# Ubuntu/Debian
sudo apt-get install jq

# Mac
brew install jq
```

### Step 3: Run Local Analysis

```bash
# Make scripts executable
chmod +x sonarqube-cloud-scanning/scripts/*.sh

# Validate configuration
./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh

# Run local test
./sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh
```

## Verification

### Step 1: Check SonarQube Cloud Dashboard

1. Navigate to [https://sonarcloud.io](https://sonarcloud.io)
2. Go to your project dashboard
3. Verify that analysis results appear
4. Check the quality gate status

### Step 2: Verify GitHub Integration

1. Create a pull request in your repository
2. Wait for the GitHub Actions workflow to complete
3. Check that SonarQube analysis appears in PR checks
4. Verify that quality gate status is shown

### Step 3: Test Quality Gates

Run the analysis script to check quality gates:
```bash
./sonarqube-cloud-scanning/scripts/analyze-quality-gates.sh \
  -k "your-project-key" \
  -o results.json
```

## Common Configuration Options

### Code Coverage

To enable code coverage reporting:

1. Ensure JaCoCo plugin is configured in `pom.xml`
2. Run tests with coverage:
   ```bash
   mvn clean test jacoco:report
   ```
3. Coverage reports will be automatically picked up by SonarQube

### Exclusions

To exclude files from analysis, update `sonar-project.properties`:
```properties
# Exclude test files from coverage
sonar.coverage.exclusions=**/*Test.java,**/test/**

# Exclude generated code
sonar.exclusions=**/target/**,**/generated/**
```

### Custom Rules

1. In SonarQube Cloud, go to **"Quality Profiles"**
2. Create a new profile or extend existing ones
3. Activate/deactivate rules as needed
4. Assign the profile to your project

## Troubleshooting

If you encounter issues:

1. Run the validation script:
   ```bash
   ./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh
   ```

2. Check the logs in GitHub Actions

3. Verify your tokens and secrets are correctly set

4. Consult the [Troubleshooting Guide](TROUBLESHOOTING.md)

## Next Steps

- Review the [Integration Guide](INTEGRATION_GUIDE.md) for GitHub Actions details
- Configure additional quality gates based on your requirements
- Set up notifications for quality gate failures
- Integrate with your IDE using SonarLint

## Support

For additional help:
- [SonarQube Cloud Documentation](https://docs.sonarcloud.io)
- [GitHub Actions Integration](https://docs.sonarcloud.io/advanced-setup/ci-based-analysis/github-actions-for-sonarcloud/)
- [Community Forum](https://community.sonarsource.com/)