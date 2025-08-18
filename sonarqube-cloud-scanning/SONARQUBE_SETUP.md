# SonarQube Cloud Setup Instructions

## Issue: Automatic Analysis Conflict

The project currently has **Automatic Analysis** enabled in SonarQube Cloud, which conflicts with manual analysis from CI/CD pipelines.

## Resolution Steps

### Option 1: Disable Automatic Analysis (Recommended for CI/CD)

1. **Log in to SonarQube Cloud**
   - Go to https://sonarcloud.io
   - Sign in with your GitHub account

2. **Navigate to Your Project**
   - Go to project: `poc-pipeline_poc-pipeline`
   - Or direct link: https://sonarcloud.io/project/configuration?id=poc-pipeline_poc-pipeline

3. **Disable Automatic Analysis**
   - Go to **Administration** → **Analysis Method**
   - Turn OFF **Automatic Analysis**
   - Save the changes

4. **Verify the Change**
   - The project should now accept manual analysis from Maven/CI pipelines
   - Re-run the local test script: `./sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh`

### Option 2: Use Automatic Analysis Only

If you prefer to keep Automatic Analysis:

1. **Remove Manual Analysis from CI/CD**
   - Comment out or remove the SonarQube analysis steps in the GitHub Actions workflow
   - Automatic Analysis will scan your code on every push to GitHub

2. **View Results**
   - Results will appear automatically in SonarQube Cloud after each push
   - No manual triggering needed

## Current Configuration

- **Project Key**: poc-pipeline_poc-pipeline
- **Organization**: poc-pipeline
- **Analysis Method**: Automatic Analysis (ENABLED) ⚠️
- **Manual Analysis**: BLOCKED due to Automatic Analysis

## Recommended Action

For this POC with CI/CD pipeline integration, **disable Automatic Analysis** to allow:
- Manual analysis from local development
- Controlled analysis in CI/CD pipeline
- Quality gate integration with deployment decisions

## Testing After Fix

Once Automatic Analysis is disabled:

```bash
# Run local test
./sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh

# Or run analysis directly
cd microservice-moc-app
mvn sonar:sonar \
  -Dsonar.host.url=https://sonarcloud.io \
  -Dsonar.token=$SONAR_TOKEN \
  -Dsonar.organization=$SONAR_ORGANIZATION \
  -Dsonar.projectKey=$SONAR_PROJECT_KEY
```

## Quality Gate Status

After successful analysis, check quality gate:

```bash
./sonarqube-cloud-scanning/scripts/analyze-quality-gates.sh \
  -k poc-pipeline_poc-pipeline \
  -o sonarqube-cloud-scanning/results/quality-gate-result.json
```