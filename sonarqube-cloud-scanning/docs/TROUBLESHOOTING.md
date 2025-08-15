# SonarQube Cloud Troubleshooting Guide

## Table of Contents
1. [Common Issues](#common-issues)
2. [Authentication Problems](#authentication-problems)
3. [Analysis Failures](#analysis-failures)
4. [Quality Gate Issues](#quality-gate-issues)
5. [Coverage Problems](#coverage-problems)
6. [GitHub Actions Issues](#github-actions-issues)
7. [Performance Issues](#performance-issues)
8. [Debugging Tools](#debugging-tools)

## Common Issues

### Issue: SonarQube analysis not appearing in dashboard

**Symptoms:**
- Analysis completes successfully in GitHub Actions
- No results visible in SonarQube Cloud dashboard

**Solutions:**

1. **Verify project key matches:**
   ```bash
   # Check configured project key
   grep "sonar.projectKey" sonarqube-cloud-scanning/config/sonar-project.properties
   
   # Verify in pom.xml
   grep "sonar.projectKey" microservice-moc-app/pom.xml
   ```

2. **Check organization key:**
   ```bash
   # Validate organization
   curl -u "$SONAR_TOKEN:" \
     "https://sonarcloud.io/api/organizations/search?organizations=$SONAR_ORGANIZATION"
   ```

3. **Ensure project exists in SonarQube Cloud:**
   - Log into SonarQube Cloud
   - Navigate to your organization
   - Check if project is listed
   - If not, import it manually

### Issue: "Project not found" error

**Symptoms:**
```
ERROR: Project not found. Please check the 'sonar.projectKey' property
```

**Solutions:**

1. **Create project in SonarQube Cloud:**
   ```bash
   # Use API to create project
   curl -X POST -u "$SONAR_TOKEN:" \
     "https://sonarcloud.io/api/projects/create" \
     -d "name=CI/CD Pipeline POC" \
     -d "project=$SONAR_PROJECT_KEY" \
     -d "organization=$SONAR_ORGANIZATION"
   ```

2. **Update configuration:**
   ```properties
   # sonar-project.properties
   sonar.organization=your-actual-org
   sonar.projectKey=your-actual-key
   ```

## Authentication Problems

### Issue: "Not authorized" error

**Symptoms:**
```
ERROR: Not authorized. Please check the properties sonar.login and sonar.password
```

**Solutions:**

1. **Verify token is valid:**
   ```bash
   ./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh
   ```

2. **Check token permissions:**
   ```bash
   curl -u "$SONAR_TOKEN:" \
     "https://sonarcloud.io/api/authentication/validate"
   ```

3. **Regenerate token if needed:**
   - Go to SonarQube Cloud → My Account → Security
   - Revoke old token
   - Generate new token
   - Update GitHub secret

### Issue: GitHub secret not available

**Symptoms:**
```
Error: SONAR_TOKEN is not set
```

**Solutions:**

1. **Verify secret exists:**
   - Go to GitHub repository → Settings → Secrets
   - Check if `SONAR_TOKEN` exists

2. **Check workflow syntax:**
   ```yaml
   env:
     SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
   ```

3. **For forked repositories:**
   - Secrets are not available to forked repos by default
   - Use pull_request_target event or configure in fork

## Analysis Failures

### Issue: Maven build fails during analysis

**Symptoms:**
```
[ERROR] Failed to execute goal org.sonarsource.scanner.maven:sonar-maven-plugin
```

**Solutions:**

1. **Check Maven configuration:**
   ```bash
   # Verify Maven settings
   mvn -X sonar:sonar
   ```

2. **Clear Maven cache:**
   ```bash
   rm -rf ~/.m2/repository/org/sonarsource
   mvn clean install
   ```

3. **Update plugin version:**
   ```xml
   <plugin>
     <groupId>org.sonarsource.scanner.maven</groupId>
     <artifactId>sonar-maven-plugin</artifactId>
     <version>3.10.0.2594</version>
   </plugin>
   ```

### Issue: Analysis timeout

**Symptoms:**
```
ERROR: Quality gate timeout exceeded
```

**Solutions:**

1. **Increase timeout:**
   ```bash
   mvn sonar:sonar -Dsonar.qualitygate.timeout=600
   ```

2. **Check server status:**
   ```bash
   curl -I https://sonarcloud.io/api/system/status
   ```

3. **Run without quality gate wait:**
   ```bash
   mvn sonar:sonar -Dsonar.qualitygate.wait=false
   ```

## Quality Gate Issues

### Issue: Quality gate always fails

**Symptoms:**
- Analysis completes but quality gate shows "Failed"
- No obvious issues in code

**Solutions:**

1. **Check quality gate configuration:**
   - Go to Project Settings → Quality Gate
   - Review thresholds
   - Consider using "Sonar way" initially

2. **Review specific conditions:**
   ```bash
   # Get quality gate details
   curl -u "$SONAR_TOKEN:" \
     "https://sonarcloud.io/api/qualitygates/project_status?projectKey=$SONAR_PROJECT_KEY"
   ```

3. **Focus on new code:**
   ```properties
   # Only apply gates to new code
   sonar.qualitygate.wait=true
   sonar.newCode.referenceBranch=main
   ```

### Issue: Metrics not updating

**Symptoms:**
- Old metrics shown despite new analysis
- Coverage stuck at 0%

**Solutions:**

1. **Force refresh:**
   ```bash
   # Trigger new analysis
   mvn clean test sonar:sonar -Dsonar.forceAnalysis=true
   ```

2. **Check analysis date:**
   - In SonarQube Cloud, check "Last analysis" timestamp
   - Ensure it matches recent run

## Coverage Problems

### Issue: Coverage shows 0%

**Symptoms:**
- Tests run successfully
- Coverage remains at 0% in SonarQube

**Solutions:**

1. **Verify JaCoCo configuration:**
   ```xml
   <plugin>
     <groupId>org.jacoco</groupId>
     <artifactId>jacoco-maven-plugin</artifactId>
     <executions>
       <execution>
         <id>prepare-agent</id>
         <goals><goal>prepare-agent</goal></goals>
       </execution>
       <execution>
         <id>report</id>
         <phase>test</phase>
         <goals><goal>report</goal></goals>
       </execution>
     </executions>
   </plugin>
   ```

2. **Check report generation:**
   ```bash
   # Verify JaCoCo report exists
   ls -la microservice-moc-app/target/site/jacoco/jacoco.xml
   ```

3. **Run with correct order:**
   ```bash
   mvn clean test jacoco:report sonar:sonar
   ```

4. **Verify path configuration:**
   ```properties
   sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
   ```

### Issue: Partial coverage reporting

**Symptoms:**
- Some classes show coverage, others don't
- Inconsistent coverage metrics

**Solutions:**

1. **Check exclusions:**
   ```properties
   # Remove overly broad exclusions
   sonar.coverage.exclusions=**/test/**,**/config/**
   ```

2. **Ensure all modules included:**
   ```xml
   <sonar.sources>src/main/java</sonar.sources>
   <sonar.tests>src/test/java</sonar.tests>
   ```

## GitHub Actions Issues

### Issue: Workflow fails silently

**Symptoms:**
- Workflow shows as failed
- No clear error message

**Solutions:**

1. **Enable debug logging:**
   ```yaml
   - name: Run SonarQube Analysis
     env:
       ACTIONS_STEP_DEBUG: true
     run: mvn sonar:sonar -X
   ```

2. **Check runner logs:**
   - Click on failed job in GitHub Actions
   - Expand each step
   - Look for error indicators

3. **Add error handling:**
   ```yaml
   - name: Run SonarQube Analysis
     run: |
       set -e
       mvn sonar:sonar || {
         echo "SonarQube analysis failed with exit code $?"
         exit 1
       }
   ```

### Issue: Secrets not accessible

**Symptoms:**
```
Error: Input required and not supplied: token
```

**Solutions:**

1. **Check secret scope:**
   - Repository secrets only available to that repo
   - Organization secrets need to be allowed for repo

2. **Verify workflow permissions:**
   ```yaml
   permissions:
     contents: read
     pull-requests: write
   ```

## Performance Issues

### Issue: Analysis takes too long

**Symptoms:**
- Analysis runs for > 10 minutes
- Timeout errors

**Solutions:**

1. **Optimize analysis scope:**
   ```properties
   # Exclude unnecessary files
   sonar.exclusions=**/target/**,**/node_modules/**,**/*.min.js
   ```

2. **Use incremental analysis:**
   ```bash
   mvn sonar:sonar -Dsonar.analysis.mode=incremental
   ```

3. **Cache dependencies:**
   ```yaml
   - uses: actions/cache@v4
     with:
       path: |
         ~/.m2/repository
         ~/.sonar/cache
       key: ${{ runner.os }}-sonar-${{ hashFiles('**/pom.xml') }}
   ```

### Issue: Memory issues during analysis

**Symptoms:**
```
java.lang.OutOfMemoryError: Java heap space
```

**Solutions:**

1. **Increase memory:**
   ```bash
   export MAVEN_OPTS="-Xmx3072m -XX:MaxPermSize=512m"
   mvn sonar:sonar
   ```

2. **In GitHub Actions:**
   ```yaml
   - name: Run SonarQube Analysis
     env:
       MAVEN_OPTS: "-Xmx3072m"
     run: mvn sonar:sonar
   ```

## Debugging Tools

### Validation Script

Always start with validation:
```bash
./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh
```

### API Testing

Test API endpoints directly:

```bash
# Check authentication
curl -u "$SONAR_TOKEN:" \
  "https://sonarcloud.io/api/authentication/validate"

# Get project status
curl -u "$SONAR_TOKEN:" \
  "https://sonarcloud.io/api/qualitygates/project_status?projectKey=$SONAR_PROJECT_KEY"

# Get project metrics
curl -u "$SONAR_TOKEN:" \
  "https://sonarcloud.io/api/measures/component?component=$SONAR_PROJECT_KEY&metricKeys=bugs,vulnerabilities,coverage"
```

### Local Testing

Test locally before pushing:
```bash
# Full local test
./sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh

# Just analysis
cd microservice-moc-app
mvn clean test sonar:sonar -Dsonar.host.url=https://sonarcloud.io
```

### Verbose Logging

Enable detailed logging:
```bash
# Maven debug mode
mvn sonar:sonar -X

# SonarQube verbose
mvn sonar:sonar -Dsonar.verbose=true

# Combined
mvn sonar:sonar -X -Dsonar.verbose=true -Dsonar.log.level=DEBUG
```

## Getting Help

If issues persist after trying these solutions:

1. **Check SonarQube Cloud Status:**
   - https://status.sonarcloud.io/

2. **Community Forum:**
   - https://community.sonarsource.com/

3. **GitHub Issues:**
   - Report workflow issues in your repository
   - Report SonarQube issues at https://github.com/SonarSource/sonar-scanner-maven/issues

4. **Documentation:**
   - [SonarQube Cloud Docs](https://docs.sonarcloud.io)
   - [Maven Scanner Docs](https://docs.sonarcloud.io/advanced-setup/ci-based-analysis/sonarscanner-for-maven/)

## Quick Reference

### Essential Commands

```bash
# Validate setup
./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh

# Run analysis
mvn clean test jacoco:report sonar:sonar

# Check quality gate
./sonarqube-cloud-scanning/scripts/analyze-quality-gates.sh

# Local test
./sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh
```

### Key Environment Variables

```bash
export SONAR_TOKEN="your-token"
export SONAR_ORGANIZATION="your-org"
export SONAR_PROJECT_KEY="your-project"
export SONAR_HOST_URL="https://sonarcloud.io"
```

### Useful Properties

```properties
sonar.qualitygate.wait=true
sonar.qualitygate.timeout=300
sonar.verbose=true
sonar.log.level=DEBUG
sonar.forceAnalysis=true
```