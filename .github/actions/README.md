# Composite Actions Documentation

## Overview

This directory contains reusable composite actions that encapsulate common step sequences used across multiple workflows. These actions promote code reuse, consistency, and maintainability in our CI/CD pipelines.

## What are Composite Actions?

Composite actions are a way to bundle multiple workflow steps into a single reusable action. They:
- Reduce duplication across workflows
- Ensure consistency in common operations
- Simplify workflow maintenance
- Can accept inputs and provide outputs
- Run directly on the runner (no container overhead)

## Available Actions

### 1. `setup-java-maven`

**Purpose:** Sets up JDK and Maven with intelligent caching for consistent build environments.

**Location:** `./setup-java-maven/action.yml`

#### Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `java-version` | Java version to use | No | `'17'` |
| `distribution` | Java distribution | No | `'temurin'` |
| `project-path` | Path to project for cache key | No | `'.'` |

#### Usage Example

```yaml
steps:
  - name: Setup Java and Maven
    uses: ./.github/actions/setup-java-maven
    with:
      java-version: '17'
      distribution: 'temurin'
```

#### Features
- Automatic Maven dependency caching
- Build artifact caching for `microservice-moc-app/target`
- Intelligent cache key generation based on `pom.xml` and source files
- Fallback cache restore keys for faster builds

---

### 2. `download-build-artifacts`

**Purpose:** Standardizes artifact download with verification and structure validation.

**Location:** `./download-build-artifacts/action.yml`

#### Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `artifact-name` | Name of the artifact to download | No | `'build-artifacts'` |
| `download-path` | Path where to extract artifacts | No | `'.'` |

#### Usage Example

```yaml
steps:
  - name: Download build artifacts
    uses: ./.github/actions/download-build-artifacts
    with:
      artifact-name: 'build-artifacts'
      download-path: '.'
```

#### Features
- Automatic artifact download using `actions/download-artifact@v4`
- Directory structure verification
- Validates expected `microservice-moc-app` directory
- Provides detailed logging for troubleshooting

---

### 3. `generate-security-summary`

**Purpose:** Parses Snyk security scan results and generates comprehensive GitHub step summaries.

**Location:** `./generate-security-summary/action.yml`

#### Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `results-file` | Path to Snyk results JSON file | Yes | - |
| `summary-title` | Title for security summary section | No | `'🔒 Security Scan Results'` |

#### Outputs

| Name | Description |
|------|-------------|
| `critical-count` | Number of critical vulnerabilities found |
| `high-count` | Number of high vulnerabilities found |
| `medium-count` | Number of medium vulnerabilities found |
| `low-count` | Number of low vulnerabilities found |
| `total-count` | Total number of vulnerabilities found |

#### Usage Example

```yaml
steps:
  - name: Generate security summary
    id: security-summary
    uses: ./.github/actions/generate-security-summary
    with:
      results-file: snyk-scanning/results/snyk-results.json
      summary-title: '🔒 Dependency Security Analysis'
    
  - name: Use outputs
    run: |
      echo "Critical vulnerabilities: ${{ steps.security-summary.outputs.critical-count }}"
      echo "Total vulnerabilities: ${{ steps.security-summary.outputs.total-count }}"
```

#### Features
- JSON parsing with `jq`
- Vulnerability categorization by severity
- Visual GitHub step summary with tables
- Top 5 critical/high vulnerability details
- Scan metadata including timestamp
- Error handling for missing or malformed files

#### Generated Summary Format
```markdown
## 🔒 Security Scan Results

### 📊 Vulnerability Overview
| Severity | Count | Impact |
|----------|-------|--------|
| 🔴 Critical | 2 | ❌ Deployment Blocked |
| 🟠 High | 5 | ⚠️ Review Required |
| 🟡 Medium | 10 | ℹ️ Informational |
| ⚪ Low | 15 | ✅ OK |
| **Total** | **32** | - |

### 🎯 Priority Fixes Required
[Details of top vulnerabilities...]

### 📝 Scan Details
- **Project:** microservice-moc-app
- **Type:** Dependencies (Maven)
- **Timestamp:** 2025-08-15 10:30:00 UTC
```

---

### 4. `generate-quality-summary`

**Purpose:** Parses SonarQube quality gate results and generates detailed quality metrics summaries.

**Location:** `./generate-quality-summary/action.yml`

#### Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `results-file` | Path to SonarQube results JSON | Yes | - |
| `project-key` | SonarQube project key | Yes | - |
| `branch-name` | Current branch name | No | `'main'` |
| `summary-title` | Title for quality summary | No | `'📊 Code Quality Analysis (SonarQube Cloud)'` |

#### Outputs

| Name | Description |
|------|-------------|
| `quality-gate-status` | Quality gate status (PASSED/FAILED/UNKNOWN) |
| `bugs-count` | Number of bugs found |
| `vulnerabilities-count` | Number of vulnerabilities found |
| `security-rating` | Security rating (A-E) |
| `reliability-rating` | Reliability rating (A-E) |
| `maintainability-rating` | Maintainability rating (A-E) |

#### Usage Example

```yaml
steps:
  - name: Generate quality summary
    id: quality-summary
    uses: ./.github/actions/generate-quality-summary
    with:
      results-file: sonarqube-cloud-scanning/results/quality-gate-result.json
      project-key: 'poc-pipeline_poc-pipeline'
      branch-name: ${{ github.ref_name }}
    
  - name: Check quality gate
    if: steps.quality-summary.outputs.quality-gate-status == 'FAILED'
    run: echo "Quality gate failed!"
```

#### Features
- Comprehensive metric extraction
- Quality ratings visualization (A-E scale)
- Branch-specific dashboard links
- Test coverage and code duplication metrics
- Detailed quality metrics table
- Graceful handling of missing data

#### Generated Summary Format
```markdown
### 📊 Code Quality Analysis (SonarQube Cloud)

| Metric | Status |
|--------|--------|
| Quality Gate | ✅ **PASSED** |
| Project | poc-pipeline_poc-pipeline |
| Branch | main |
| Dashboard | [View Analysis Results](https://sonarcloud.io/...) |

**Detailed Quality Metrics:**

| Metric | Value | Rating |
|--------|-------|--------|
| 🐛 Bugs | 0 | 🏆 **A** |
| 🔒 Vulnerabilities | 0 | 🛡️ **A** |
| 🔥 Security Hotspots | 0 | - |
| 💨 Code Smells | 5 | 🧹 **A** |
| 📊 Test Coverage | 25% | - |
| 📋 Code Duplication | 0% | - |
```

## Creating New Composite Actions

### Structure Template

```yaml
name: 'Action Name'
description: 'Clear description of what this action does'

inputs:
  input-name:
    description: 'Input description'
    required: true/false
    default: 'default-value'

outputs:
  output-name:
    description: 'Output description'
    value: ${{ steps.step-id.outputs.variable }}

runs:
  using: 'composite'
  steps:
    - name: Step name
      shell: bash
      run: |
        echo "Running composite action"
        
    - name: Set output
      id: step-id
      shell: bash
      run: |
        echo "variable=value" >> $GITHUB_OUTPUT
```

### Best Practices

1. **Single Responsibility**: Each action should do one thing well
2. **Clear Naming**: Use descriptive names for actions and inputs
3. **Comprehensive Documentation**: Include usage examples
4. **Error Handling**: Handle missing files and invalid inputs gracefully
5. **Output Validation**: Ensure outputs are always set, even on error
6. **Shell Specification**: Always specify `shell: bash` for run steps
7. **Idempotency**: Actions should be safe to run multiple times

## Using Composite Actions

### From Same Repository

```yaml
steps:
  - name: Use composite action
    uses: ./.github/actions/action-name
    with:
      input-name: 'value'
```

### From External Repository

```yaml
steps:
  - name: Use external composite action
    uses: org/repo/.github/actions/action-name@main
    with:
      input-name: 'value'
```

### In Reusable Workflows

Composite actions work seamlessly within reusable workflows:

```yaml
# .github/workflows/reusable.yml
jobs:
  job-name:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-java-maven
        with:
          java-version: '17'
```

## Testing Composite Actions

### Local Testing

1. Create a test workflow in `.github/workflows/test-actions.yml`
2. Reference the local action
3. Run with `act` tool or push to feature branch

### Test Workflow Example

```yaml
name: Test Composite Actions
on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Test setup-java-maven
        uses: ./.github/actions/setup-java-maven
        with:
          java-version: '17'
      
      - name: Verify Java installation
        run: java -version
```

## Versioning

When making breaking changes to composite actions:

1. **Document changes** in action's comments
2. **Update examples** in this README
3. **Test thoroughly** before merging
4. **Consider compatibility** with existing workflows
5. **Communicate changes** to team

## Performance Considerations

### Caching Strategy

The `setup-java-maven` action implements intelligent caching:

```yaml
key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}-${{ hashFiles('microservice-moc-app/src/**') }}
restore-keys: |
  ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}-
  ${{ runner.os }}-maven-
```

This ensures:
- Exact matches when code hasn't changed
- Partial matches for dependency-only changes
- Fallback to any Maven cache as last resort

### Execution Time

| Action | Typical Duration | Notes |
|--------|-----------------|-------|
| `setup-java-maven` | 30-60s | Faster with cache hit |
| `download-build-artifacts` | 5-10s | Depends on artifact size |
| `generate-security-summary` | 2-5s | JSON parsing overhead |
| `generate-quality-summary` | 2-5s | JSON parsing overhead |

## Troubleshooting

### Common Issues

#### 1. Action Not Found
**Error:** "Can't find 'action.yml'"
**Solution:** Ensure path is correct and action.yml exists

#### 2. Input Not Provided
**Error:** "Input required and not supplied"
**Solution:** Provide all required inputs in workflow

#### 3. Output Not Available
**Error:** "Output 'X' not found"
**Solution:** Ensure the step generating output has an `id`

#### 4. Shell Not Specified
**Error:** "Shell not specified"
**Solution:** Add `shell: bash` to all run steps

### Debug Tips

1. **Enable debug logging**: Set `ACTIONS_STEP_DEBUG` secret to `true`
2. **Add echo statements**: Debug values in composite actions
3. **Check paths**: Use `pwd` and `ls` to verify working directory
4. **Validate JSON**: Ensure JSON files are valid before parsing

## Migration Guide

### Converting Inline Steps to Composite Action

Before (inline in workflow):
```yaml
steps:
  - uses: actions/setup-java@v4
    with:
      java-version: '17'
      distribution: 'temurin'
  - uses: actions/cache@v4
    with:
      path: ~/.m2/repository
      key: maven-${{ hashFiles('**/pom.xml') }}
```

After (using composite action):
```yaml
steps:
  - uses: ./.github/actions/setup-java-maven
    with:
      java-version: '17'
```

## Contributing

When adding new composite actions:

1. **Follow the template** structure above
2. **Add comprehensive documentation** to this README
3. **Include usage examples**
4. **Test thoroughly** before merging
5. **Update dependent workflows** if needed

## Support

For issues or questions about composite actions:
- Review this documentation
- Check action logs in workflow runs
- Enable debug mode for detailed output
- Consult [GitHub's composite actions documentation](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)