# Configuration Guide - CI/CD Security Gating Platform

This guide provides step-by-step instructions for configuring Snyk and Permit.io for the CI/CD Security Gating Platform PoC.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Part 1: Snyk Configuration](#part-1-snyk-configuration)
- [Part 2: Permit.io Configuration](#part-2-permitio-configuration)
- [Part 3: Integration Setup](#part-3-integration-setup)
- [Part 4: Validation](#part-4-validation)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:
- A GitHub account (for code repository)
- An email address for service registrations
- Basic familiarity with CLI tools
- Docker Desktop installed and running
- curl command available (for API testing)
- Optional: OPA CLI for policy validation (auto-installed by validation script)

---

## Part 1: Snyk Configuration

### Step 1: Create Snyk Account

1. **Navigate to Snyk Sign-up**
   - Go to https://app.snyk.io/signup
   - Choose "Sign up for free"

2. **Select Sign-up Method**
   - Option A: Sign up with GitHub (recommended)
   - Option B: Sign up with Google
   - Option C: Sign up with email

3. **Complete Profile Setup**
   - Enter your name
   - Select "Security" or "Development" as your role
   - Choose "Java" as primary language (for this PoC)

### Step 2: Generate Snyk API Token

1. **Access Account Settings**
   - Click on your profile icon (top right)
   - Select "Account settings"

2. **Navigate to API Tokens**
   - In the left sidebar, click "General"
   - Scroll to "API Token" section

3. **Generate Token**
   - Click "Generate Token" or "Show Token"
   - Name your token: "CICD-Gating-PoC"
   - Copy the token immediately (it won't be shown again)
   - Store it securely

   ```bash
   # Example token format:
   # snyk_api_token_1234567890abcdef1234567890abcdef
   ```

### Step 3: Get Organization ID

1. **Access Organization Settings**
   - Click "Settings" in the left sidebar
   - Select your organization

2. **Copy Organization ID**
   - Find "Organization ID" in the settings
   - Copy the UUID-format ID
   
   ```bash
   # Example org ID format:
   # 12345678-1234-1234-1234-123456789012
   ```

### Step 4: Configure Snyk CLI (Optional but Recommended)

1. **Install Snyk CLI**
   ```bash
   # Using npm
   npm install -g snyk

   # Or using Homebrew (macOS)
   brew install snyk

   # Or using Scoop (Windows)
   scoop install snyk
   ```

2. **Authenticate CLI**
   ```bash
   snyk auth <your-api-token>
   ```

3. **Verify Installation**
   ```bash
   snyk --version
   snyk test --help
   ```

### Step 5: Import Project to Snyk (Optional)

1. **Connect Repository**
   - In Snyk dashboard, click "Add project"
   - Select "GitHub" as source
   - Authorize Snyk to access your repositories
   - Select your `cicd-pipeline-poc` repository

2. **Configure Project Settings**
   - Enable "Test for vulnerabilities"
   - Set test frequency to "Daily"
   - Enable "Fix Pull Requests" (optional)

---

## Part 2: Permit.io Configuration

### Step 1: Create Permit.io Account

1. **Sign Up**
   - Go to https://app.permit.io/signup
   - Enter your email address
   - Create a strong password
   - Verify your email

2. **Complete Onboarding**
   - Organization name: "Your-Org-Name"
   - Team size: Select appropriate option
   - Use case: Select "API Authorization"

### Step 2: Create Workspace and Project

1. **Create Workspace**
   - Click "Create Workspace"
   - Name: "CICD-Security-Gating"
   - Description: "Security gating for CI/CD pipelines"

2. **Create Environment**
   - Default environment "Development" is auto-created
   - Optionally create "Production" environment

### Step 3: Generate API Key

1. **Navigate to API Keys**
   - Click "Settings" in sidebar
   - Select "API Keys"

2. **Create New API Key**
   - Click "Create API Key"
   - Name: "CICD-Pipeline-PDP"
   - Environment: Select "Development"
   - Copy the generated key immediately

   ```bash
   # Example API key format:
   # permit_key_1234567890ABCDEFghijklmnop1234567890
   ```

### Step 4: Define Resources and Actions

1. **Navigate to Policy Editor**
   - In the left sidebar, click "Policy" 
   - This will show the Policy Editor interface with tabs: "Policy Editor", "Resources", "Roles", "ABAC Rules"

2. **Create Deployment Resource**
   - Click the "Resources" tab
   - Click "Create" or "+" button to add a new resource
   - Fill in the resource details:
     ```
     Name: Deployment
     Key: deployment
     Description: Application deployment resource for CI/CD gating
     ```
   - Add resource attributes for vulnerability data:
     - `criticalCount` (type: number)
     - `highCount` (type: number) 
     - `mediumCount` (type: number)
     - `vulnerabilities` (type: object)

3. **Create Actions** 
   - While still in Resources, add actions to the Deployment resource:
     - `deploy` - Deploy application to environment
     - `promote` - Promote application to next stage
   - These actions will appear in the permission matrix

### Step 5: Configure Role-Based Permissions

1. **Navigate to Roles Tab**
   - Click the "Roles" tab in the Policy Editor
   - You'll see a permission matrix interface

2. **Configure Role Permissions**
   The interface shows a matrix with:
   - **Roles**: admin, editor, viewer (across the top)
   - **Resources/Actions**: Deployment → deploy, promote (down the left side)
   
   **Set permissions by checking boxes in the matrix:**
   - **admin role**: Check all boxes (full access to deploy and promote)
   - **editor role**: Check "deploy" box (can deploy but not promote)
   - **viewer role**: Leave unchecked (read-only access)

3. **Create ABAC Rules for Vulnerability Gating**
   
   **Important**: Make sure you click the **"ABAC Rules" tab** (the 4th tab) in the Policy Editor, not the "Policy Editor" tab.
   
   - From your current screen (which shows the role matrix), click the "ABAC Rules" tab at the top
   - This will switch you to the attribute-based access control interface
   - Here you'll create the actual security gating logic based on vulnerability attributes
   
   **If the ABAC Rules tab shows an interface to create rules:**
   
   **Create Critical Vulnerability Hard Gate:**
   - Click "Create Rule", "Create", or "+" button
   - **When prompted to choose rule type, select "resource set"** (not "user")
   - Rule Name: `Critical Vulnerability Block`
   - Resource: `deployment`
   - Action: `deploy`
   - Effect: `Deny` (this blocks the action)
   - Condition: `resource.criticalCount > 0`
   
   **Create High Vulnerability Soft Gate:**
   - Click "Create Rule", "Create", or "+" button
   - Rule Name: `High Vulnerability Warning`
   - Resource: `deployment`
   - Action: `deploy`
   - Effect: `Allow` 
   - Add a condition or note for warnings
   
   **If ABAC Rules interface is not available or limited:**
   
   Don't worry - this is common and expected! Many Permit.io configurations rely on the role-based matrix you see in your current screen. 
   
   **Your PoC will work perfectly with just the role-based permissions** because:
   - The vulnerability gating logic is handled by the custom Rego policies in `policies/gating_policy.rego`
   - The role matrix just needs basic "deploy" permissions set up
   - All the hard gates, soft gates, and vulnerability blocking logic is in the code, not the UI
   
   **You can proceed to Step 6** - your configuration is complete for the PoC!

### Step 6: Configure GitOps Integration (Optional)

GitOps integration allows you to manage policies as code in GitHub, providing version control, code review, and automated deployment of policy changes.

**⚠️ Important Note**: If your GitHub organization has security policies that disable Deploy Keys (as shown in your screenshot), you have several alternatives below.

#### Option A: Quick Setup (For PoC Testing) - **RECOMMENDED**
**Skip GitOps for now** and use the local Rego policies included in the project. You can proceed directly to Step 7. This is the easiest approach for the PoC and doesn't require any GitHub repository configuration.

#### Option B: Full GitOps Setup (Production-Ready)

**1. Create SSH Deploy Key**
```bash
# Generate SSH key for Permit.io GitOps
ssh-keygen -t ecdsa -b 521 -C "permit-gitops@yourcompany.com" -f ~/.ssh/permit_gitops
```

**2. Add Deploy Key to GitHub**

**If Deploy Keys are Available:**
- Copy the public key: `cat ~/.ssh/permit_gitops.pub`
- Go to your GitHub repository → Settings → Deploy keys
- Click "Add deploy key"
- Title: "Permit.io GitOps"
- Key: Paste the public key content
- ✅ Check "Allow write access"
- Click "Add key"

**If Deploy Keys are Disabled by Organization Policy:**

You'll see a message like "Some settings on this page can't be changed because of a poc-pipeline policy" and the Deploy keys section will be disabled.

**Alternative Approach: Use GitHub App Integration**

**Option 2A: Request Permission (Recommended)**
- Contact your GitHub organization administrator
- Request permission to add deploy keys for this specific repository
- Explain it's for Permit.io policy management integration

**Option 2B: Use Personal Access Token (Less Secure)**
```bash
# Generate a Personal Access Token instead
# Go to GitHub → Settings → Developer settings → Personal access tokens
# Create token with 'repo' scope
# Use HTTPS instead of SSH
REPO_HTTPS_URL="https://github.com/yourusername/permit-policies.git"
GITHUB_TOKEN="your_personal_access_token"
```

**Option 2C: Use GitHub App (Most Secure)**
- Go to your GitHub organization settings
- Create a GitHub App with repository permissions
- Install the app to your policy repository
- Use the app's credentials for GitOps integration

**Option 2D: Skip GitOps for PoC (Simplest)**
- For this PoC, you can skip GitOps entirely
- The local Rego policies will work perfectly
- Implement GitOps later in production environment

**3. Create Policy Repository Structure**
```bash
# Create a separate repository for policies (recommended)
mkdir permit-policies
cd permit-policies
git init

# Create the required directory structure
mkdir -p custom/policies
mkdir -p custom/data

# Copy the PoC policies
cp ../policies/gating_policy.rego custom/policies/
cp ../policies/permit_config.json custom/data/

# Create initial commit
git add .
git commit -m "Initial policy setup for CI/CD gating"
git branch -M main
git remote add origin git@github.com:yourusername/permit-policies.git
git push -u origin main
```

**4. Configure GitOps in Permit.io**

**Get your project information:**
- In Permit.io dashboard, go to Settings
- Copy your Project Key/ID (needed for API calls)

**Configure the repository connection:**
```bash
# Set your Permit.io API key and project info
PERMIT_API_KEY="your_permit_api_key"
PROJECT_KEY="your_project_key"  # From Permit.io Settings
REPO_SSH_URL="git@github.com:yourusername/permit-policies.git"

# Create GitOps configuration
curl -X POST "https://api.permit.io/v2/projects/${PROJECT_KEY}/repos" \
  -H "Authorization: Bearer ${PERMIT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "'${REPO_SSH_URL}'",
    "main_branch_name": "main",
    "credentials": {
      "auth_type": "ssh",
      "private_key": "'"$(cat ~/.ssh/permit_gitops | sed ':a;N;$!ba;s/\n/\\n/g')"'"
    }
  }'

# Activate the repository
curl -X PUT "https://api.permit.io/v2/projects/${PROJECT_KEY}/repos/${REPO_SSH_URL}/activate" \
  -H "Authorization: Bearer ${PERMIT_API_KEY}"
```

**5. Verify GitOps Setup**
- In Permit.io dashboard, go to Settings → GitOps
- You should see your repository listed and active
- Permit.io will create environment-specific branches automatically

**6. Policy Management Workflow**

**Making policy changes:**
```bash
# Make changes only in the custom/ folder
vim custom/policies/gating_policy.rego

# Commit and push changes
git add custom/
git commit -m "Update vulnerability thresholds"
git push origin main
```

**Environment-specific policies:**
```bash
# Create environment-specific policies
git checkout -b development
# Make development-specific changes
git push origin development

git checkout -b production  
# Make production-specific changes
git push origin production
```

**Important GitOps Rules:**
- ✅ **Only edit files in the `custom/` folder**
- ❌ **Never edit auto-generated files outside `custom/`**
- 🔄 **Changes are automatically synced to PDP within minutes**
- 📝 **Use pull requests for policy reviews in production**

#### Option C: OPAL Data Integration (Advanced)

**Note**: This is separate from GitOps and handles dynamic data fetching (like Snyk results).

**Configure OPAL Data Sources:**
```bash
# The PoC includes a custom OPAL fetcher for Snyk data
# Configure it to sync vulnerability data to Permit.io

# In Permit.io dashboard:
# 1. Go to Settings → Data Sources
# 2. Add custom data source:
#    - URL: http://your-opal-fetcher:8000/snyk
#    - Method: GET
#    - Refresh Interval: 5 minutes
#    - Data Path: snyk_vulnerabilities
```

**For this PoC**: The OPAL fetcher is already configured in Docker Compose and will automatically provide Snyk data to the PDP.

### Step 7: Configure Editor Role for Security Gate Overrides

The PoC includes an **Editor Override** feature that allows authorized users to bypass security gates while maintaining full audit trail. This is useful for emergency deployments and testing scenarios.

#### 1. Create Users in Permit.io

1. **Navigate to User Management**
   - In Permit.io dashboard, go to "User Management"
   - Click the "Users" tab

2. **Add Editor User**
   - Click "Add user" or "Create user"
   - **User Key**: Use a descriptive identifier (e.g., `santander.david.19`, `your.name.editor`)
   - **Email**: Enter the user's email address
   - **First Name & Last Name**: Enter user details

3. **Assign Editor Role**
   - In the "Top Level Access" section, select **"editor"** role
   - Ensure the editor role has appropriate permissions configured (see Step 5 above)
   - Click "Save" or "Create User"

#### 2. Configure Editor Override in .env

1. **Update .env File**
   ```bash
   # Enable editor override by uncommenting and updating these lines:
   USER_ROLE=editor
   USER_KEY=your_editor_user_key_from_step_1
   
   # Example:
   # USER_ROLE=editor
   # USER_KEY=santander.david.19
   ```

2. **Test Editor Override**
   ```bash
   # Run gate evaluation with editor privileges
   ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
   
   # Expected result: EDITOR_OVERRIDE - Deployment allowed despite critical vulnerabilities
   ```

#### 3. Switch Between Normal and Override Modes

**Normal Security Gates (Default):**
```bash
# In .env file, use:
USER_ROLE=ci-pipeline
USER_KEY=github-actions
```

**Editor Override Mode:**
```bash
# In .env file, use:
USER_ROLE=editor
USER_KEY=your_editor_user_key
```

#### 4. Editor Override Behavior

When editor role is active:
- ✅ **Allows deployment** despite critical vulnerabilities
- 📋 **Shows clear audit trail** of who overrode the gates
- 🔍 **Lists all vulnerabilities** being overridden
- ⚠️ **Provides warnings** about security risks
- 📝 **Logs override decision** for compliance tracking
- ✨ **Returns success exit code** (0) to allow deployment

#### 5. Security Considerations

- **Use Sparingly**: Editor override should only be used for emergency deployments or testing
- **Audit Trail**: All override actions are logged with user identification
- **Post-Deployment**: Address critical vulnerabilities immediately after override deployment
- **Access Control**: Limit editor role assignment to authorized personnel only
- **Review Process**: Implement approval workflows for editor role assignments in production

### Step 8: Deploy Local PDP

1. **Pull PDP Docker Image**
   ```bash
   docker pull permitio/pdp-v2:latest
   ```

2. **Run PDP Container**
   ```bash
   docker run -p 7766:7766 \
     -e PDP_API_KEY="your_permit_api_key" \
     -e PDP_DEBUG=true \
     permitio/pdp-v2:latest
   ```

3. **Verify PDP is Running**
   ```bash
   curl http://localhost:7001/healthy
   # Should return: {"status":"healthy"}
   ```
   
   **If you get "Connection reset by peer" error:**
   
   **Step A: Check if container is running**
   ```bash
   docker ps
   # Look for permitio/pdp-v2 container
   ```
   
   **Step B: Check container logs**
   ```bash
   docker logs <container-name>
   # Look for any error messages
   ```
   
   **Step C: Common fixes:**
   
   **Fix 1: API Key Issue**
   ```bash
   # Stop the container
   docker stop <container-name>
   docker rm <container-name>
   
   # Verify your API key format (should start with "permit_key_")
   echo $PERMIT_API_KEY | head -c 20
   
   # Restart with correct API key
   docker run -d \
     --name permit-pdp-test \
     -p 7766:7766 \
     -e PDP_API_KEY="$PERMIT_API_KEY" \
     -e PDP_DEBUG=true \
     permitio/pdp-v2:latest
   ```
   
   **Fix 2: Port Conflict**
   ```bash
   # Check if port 7766 is already in use
   lsof -i :7766
   # or on Windows:
   netstat -ano | findstr :7766
   
   # If port is in use, try a different port
   docker run -d \
     --name permit-pdp-test \
     -p 7777:7766 \
     -e PDP_API_KEY="$PERMIT_API_KEY" \
     -e PDP_DEBUG=true \
     permitio/pdp-v2:latest
     
   # Then test with: curl http://localhost:7777/ready
   ```
   
   **Fix 3: Wait Longer for Startup**
   ```bash
   # PDP might take time to initialize
   sleep 30
   curl http://localhost:7001/healthy
   ```
   
   **Fix 4: Check Docker Network**
   ```bash
   # Restart Docker if networking issues
   docker restart <container-name>
   
   # Wait and try again
   sleep 10
   curl http://localhost:7001/healthy
   ```

---

## Part 3: Integration Setup

### Step 1: Configure Environment Variables

1. **Create .env File**
   ```bash
   cp .env.example .env || echo "Using existing .env file"
   ```

2. **Add Your Credentials**
   ```env
   # Permit.io Configuration
   PERMIT_API_KEY=permit_key_your_actual_key_here

   # Snyk Configuration  
   SNYK_TOKEN=snyk_api_token_your_actual_token_here
   SNYK_ORG_ID=12345678-1234-1234-1234-123456789012

   # Optional: Specific project ID if you imported to Snyk
   SNYK_PROJECT_ID=project-uuid-if-imported

   # Security Gates Configuration
   # User role for security gate evaluation (default: ci-pipeline, override: editor)
   USER_ROLE=ci-pipeline
   # User key for security gate evaluation (default: github-actions)
   USER_KEY=github-actions

   # Editor Override Configuration
   # Uncomment these lines to test with editor privileges that can override security gates
   # USER_ROLE=editor
   # USER_KEY=your_editor_user_key_from_permit_io
   ```

### Step 2: Configure GitHub Secrets (For CI/CD)

1. **Navigate to Repository Settings**
   - Go to your GitHub repository
   - Click "Settings" tab
   - Select "Secrets and variables" → "Actions"

2. **Add Required Secrets**
   
   **PERMIT_API_KEY:**
   - Click "New repository secret"
   - Name: `PERMIT_API_KEY`
   - Value: Your Permit.io API key
   - Click "Add secret"

   **SNYK_TOKEN:**
   - Click "New repository secret"
   - Name: `SNYK_TOKEN`
   - Value: Your Snyk API token
   - Click "Add secret"

   **SNYK_ORG_ID:**
   - Click "New repository secret"
   - Name: `SNYK_ORG_ID`
   - Value: Your Snyk Organization ID
   - Click "Add secret"

### Step 3: Configure Policy Sync

1. **Create Policy Repository (Optional)**
   ```bash
   mkdir policies-repo
   cd policies-repo
   git init
   ```

2. **Add Policy Files**
   - Copy `gating_policy.rego` to repo
   - Copy `permit_config.json` to repo
   - Commit and push to GitHub

3. **Configure Permit.io GitOps**
   - In Permit.io, go to "Settings" → "GitOps"
   - Add repository URL
   - Configure branch (main/master)
   - Set sync interval

---

## Part 4: Validation

### Step 1: Validate Snyk Configuration

1. **Create Validation Script**
   ```bash
   chmod +x snyk-scanning/scripts/validate-snyk.sh
   ./snyk-scanning/scripts/validate-snyk.sh
   ```

2. **Manual Test**
   ```bash
   # Test Snyk API connection
   curl -H "Authorization: token $SNYK_TOKEN" \
     https://api.snyk.io/v1/user/me

   # Test local scan
   cd microservice-moc-app
   snyk test
   ```

### Step 2: Validate Permit.io Configuration

1. **Run Validation Script**
   ```bash
   chmod +x permit-gating/scripts/validate-permit.sh
   ./permit-gating/scripts/validate-permit.sh
   ```

   **Note**: The validation script will:
   - Check Permit.io API connection
   - Verify PDP Docker image availability
   - Test PDP deployment
   - Validate policy files in `permit-gating/policies/`
   - Offer to install OPA CLI for policy syntax validation (optional)

2. **Manual PDP Test (Optional)**
   ```bash
   # Check PDP health
   curl http://localhost:7001/healthy

   # Test authorization check
   curl -X POST http://localhost:7766/allowed \
     -H "Authorization: Bearer $PERMIT_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "user": {"key": "test-user"},
       "action": "deploy",
       "resource": {
         "type": "deployment",
         "attributes": {
           "criticalCount": 0,
           "highCount": 0,
           "mediumCount": 0
         }
       }
     }'
   ```

### Step 3: Run Full Integration Test

1. **Start All Services**
   ```bash
   docker-compose up -d
   ```

2. **Run Test Script**
   ```bash
   ./scripts/test-gates-local.sh
   ```

3. **Expected Results**
   - Services should start successfully
   - Snyk scan should detect vulnerabilities
   - Gate evaluation should return appropriate decision
   - Hard gate should FAIL (critical vulnerabilities)
   - Soft gate should WARN (high vulnerabilities)

4. **Test Editor Override Functionality**
   
   **Step A: Test Normal Gate Behavior**
   ```bash
   # Ensure normal settings in .env
   # USER_ROLE=ci-pipeline
   # USER_KEY=github-actions
   
   ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
   # Expected: FAIL - Hard gate triggered (critical vulnerabilities)
   ```
   
   **Step B: Test Editor Override**
   ```bash
   # Enable editor override in .env
   # USER_ROLE=editor
   # USER_KEY=your_editor_user_key
   
   ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
   # Expected: EDITOR_OVERRIDE - Deployment allowed with editor privileges
   ```
   
   **Step C: Verify Override Output**
   The editor override should show:
   - ✅ Clear "EDITOR_OVERRIDE" decision message
   - 📋 User role and key information
   - 🔍 List of critical vulnerabilities being overridden
   - ⚠️ Warning about post-deployment remediation
   - ✅ Exit code 0 (success)

### Step 4: Verify GitHub Actions

1. **Push Code to Repository**
   ```bash
   git add .
   git commit -m "Configure security gating"
   git push origin main
   ```

2. **Monitor Pipeline**
   - Go to GitHub Actions tab
   - Watch pipeline execution
   - Verify gates are evaluated correctly

---

## Troubleshooting

### Common Snyk Issues

**Issue: "Authentication failed"**
```bash
# Solution: Verify token
echo $SNYK_TOKEN
snyk auth $SNYK_TOKEN
```

**Issue: "Organization not found"**
```bash
# Solution: List available orgs
snyk config set org=$SNYK_ORG_ID
snyk monitor
```

**Issue: "No vulnerable paths found"**
```bash
# Solution: Ensure you're scanning the right directory
cd microservice-moc-app
snyk test --all-projects
```

### Common Permit.io Issues

**Issue: "PDP not responding"**
```bash
# Solution: Check Docker logs
docker logs permit-pdp
docker-compose restart permit-pdp
```

**Issue: "Unauthorized API key"**
```bash
# Solution: Verify API key format and environment
echo $PERMIT_API_KEY | head -c 20
# Should start with "permit_key_"
```

**Issue: "Policy not found"**
```bash
# Solution: Sync policies
curl -X POST https://api.permit.io/v2/sync \
  -H "Authorization: Bearer $PERMIT_API_KEY"
```

**Issue: "OPA CLI not available for syntax check"**
```bash
# Solution 1: Run validation script and accept installation when prompted
./permit-gating/scripts/validate-permit.sh
# When prompted "Install OPA now? (y/N)", type 'y'

# Solution 2: Manual installation
curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.68.0/opa_linux_amd64_static
chmod +x opa
mkdir -p ~/.local/bin
mv opa ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"

# Add to ~/.bashrc for permanent access
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

**Issue: "Policy files not found in permit-gating/policies/"**
```bash
# Solution: Ensure policy files are in correct location
ls -la permit-gating/policies/
# Should show: gating_policy.rego and permit_config.json

# If missing, check if they're in a different location
find . -name "*.rego" -o -name "permit_config.json"
```

### Common Editor Override Issues

**Issue: "Editor override not working"**
```bash
# Solution: Verify user and role configuration
# 1. Check .env file has correct USER_ROLE and USER_KEY
grep USER_ROLE .env
grep USER_KEY .env

# 2. Verify user exists in Permit.io with editor role
# Login to Permit.io → User Management → verify user and role

# 3. Test with debug mode
DEBUG=true ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

**Issue: "User does not match any rule"**
```bash
# This means the user/role combination is not authorized in Permit.io
# Solution: 
# 1. Verify editor role has "deploy" permissions in Permit.io policy matrix
# 2. Ensure user is assigned the editor role
# 3. Check the USER_KEY matches exactly the user key in Permit.io
```

**Issue: "Still getting FAIL instead of EDITOR_OVERRIDE"**
```bash
# Solution: Check the decision logic
# 1. Verify USER_ROLE=editor in .env (not commented out)
# 2. Ensure Permit.io allows the editor user to deploy
# 3. Check that critical vulnerabilities are present (needed to trigger override logic)

# Debug steps:
echo "USER_ROLE: $USER_ROLE"
echo "USER_KEY: $USER_KEY"
./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
```

**Issue: "Editor override shows but exits with error code"**
```bash
# This shouldn't happen with correct implementation
# Solution: Check script logic
# The EDITOR_OVERRIDE case should return 0 (success)
# If this occurs, check the evaluate-gates.sh script logic
```

### Docker Compose Issues

**Issue: "Port already in use"**
```bash
# Solution: Stop conflicting services
docker-compose down
lsof -i :7766  # Check what's using the port
docker-compose up -d
```

**Issue: "Services not starting"**
```bash
# Solution: Check logs and rebuild
docker-compose logs
docker-compose build --no-cache
docker-compose up -d
```

---

## Security Best Practices

### Protecting API Keys

1. **Never Commit Secrets**
   ```bash
   # Ensure .env is in .gitignore
   echo ".env" >> .gitignore
   
   # Verify .env is not tracked
   git status --ignored
   ```

2. **Use Secret Management**
   - Use GitHub Secrets for CI/CD
   - Consider HashiCorp Vault for production
   - Rotate keys regularly (quarterly recommended)
   - Use separate keys for different environments

3. **Limit Key Permissions**
   - Create read-only keys where possible
   - Use environment-specific keys
   - Audit key usage regularly
   - Monitor API key access logs

### Role-Based Access Control & Security Gates

#### 1. Role Hierarchy and Permissions

**ci-pipeline Role (Default)**
- ✅ **Purpose**: Standard CI/CD pipeline execution
- ❌ **Cannot**: Override security gates
- 🔒 **Security**: Enforces all hard gates (critical vulnerabilities block deployment)
- 📊 **Use Case**: Normal automated deployments, production pipelines

**editor Role (Override)**
- ⚠️ **Purpose**: Emergency deployments, testing, authorized overrides
- ✅ **Can**: Bypass critical vulnerability gates
- 🔍 **Security**: Full audit trail, clear warnings, vulnerability visibility
- 👤 **Use Case**: Emergency fixes, security team overrides, testing scenarios

#### 2. Editor Override Security Model

**Audit Trail Components:**
- 📝 **User Identification**: Who performed the override (USER_KEY)
- 🏷️ **Role Verification**: Confirms editor role permissions
- 🕐 **Timestamp**: When the override occurred
- 📋 **Vulnerability List**: Exact vulnerabilities being overridden
- ⚠️ **Risk Assessment**: Clear warnings about security implications

**Security Controls:**
```bash
# All override actions are logged with:
# - User identity (santander.david.19)
# - Role (editor)
# - Vulnerability count and details
# - Timestamp and context
# - Recommendations for remediation
```

#### 3. Production Security Considerations

**Access Control:**
- 🔐 **Principle of Least Privilege**: Assign editor role only to authorized personnel
- 👥 **Limited Assignment**: Restrict editor role to security team, senior engineers
- 🕰️ **Temporary Access**: Consider time-bound editor permissions
- 📋 **Approval Process**: Require approval workflow for editor role assignments

**Monitoring and Compliance:**
- 📊 **Override Tracking**: Monitor frequency and justification of overrides
- 🚨 **Alert System**: Alert on editor override usage
- 📈 **Metrics Collection**: Track override patterns for security analysis
- 🔍 **Regular Audits**: Review editor role assignments quarterly

**Emergency Procedures:**
```bash
# Emergency Override Process:
# 1. Verify critical business need
# 2. Document security risk assessment  
# 3. Enable editor override temporarily
# 4. Deploy with full audit trail
# 5. Immediately address vulnerabilities post-deployment
# 6. Revert to normal security gates
# 7. Document incident and lessons learned
```

#### 4. Implementation Security

**Environment Separation:**
```bash
# Production Environment
USER_ROLE=ci-pipeline  # Default - no overrides
USER_KEY=production-pipeline

# Staging Environment  
USER_ROLE=editor       # Allow overrides for testing
USER_KEY=staging-editor

# Development Environment
USER_ROLE=editor       # Flexible for development
USER_KEY=dev-editor
```

**Configuration Security:**
- 🔒 **Secure Storage**: Store editor user keys in secure secret management
- 🔄 **Regular Rotation**: Rotate editor credentials regularly
- 📝 **Change Control**: Version control all role configuration changes
- 🔍 **Access Review**: Regular review of who has editor access

### Network Security

1. **Restrict PDP Access**
   ```yaml
   # In production, don't expose PDP publicly
   services:
     permit-pdp:
       ports:
         - "127.0.0.1:7766:7766"  # Local only
   ```

2. **Use TLS/HTTPS**
   - Configure TLS for production PDP
   - Use HTTPS for API communications
   - Validate certificates

### Compliance and Governance

#### Security Gate Override Policy

**When to Use Editor Override:**
- ✅ Critical security patches that require immediate deployment
- ✅ Zero-day vulnerability fixes where patching is more urgent than gate compliance
- ✅ Emergency business-critical deployments with security team approval
- ✅ Testing and validation of security gate configurations
- ❌ Regular deployments to avoid fixing vulnerabilities
- ❌ Convenience to bypass security processes
- ❌ Lack of time for proper vulnerability remediation

**Override Documentation Requirements:**
1. **Justification**: Document business/security need for override
2. **Risk Assessment**: Evaluate and document security risks
3. **Remediation Plan**: Define timeline for vulnerability fixes
4. **Approval**: Obtain appropriate authorization
5. **Post-Deployment**: Execute remediation plan immediately

**Audit and Reporting:**
```bash
# Generate override audit report
grep "EDITOR_OVERRIDE" pipeline-logs/*.log | \
  awk '{print $1, $2, $3}' > override-audit.csv

# Monitor override frequency
grep -c "EDITOR_OVERRIDE" pipeline-logs/*.log
```

---

## Next Steps

After successful configuration:

1. **Customize Policies**
   - Modify `gating_policy.rego` for your needs
   - Add additional security checks
   - Integrate with other tools

2. **Scale the Solution**
   - Deploy PDP to Kubernetes
   - Implement high availability
   - Add monitoring and alerting

3. **Extend Integrations**
   - Add SonarQube scanning
   - Integrate with JIRA for exceptions
   - Connect to security dashboards

---

## Support Resources

- **Snyk Documentation**: https://docs.snyk.io
- **Permit.io Documentation**: https://docs.permit.io
- **OPAL Documentation**: https://docs.opal.ac
- **GitHub Actions**: https://docs.github.com/actions

For specific issues with this PoC, refer to the main [README.md](README.md) or create an issue in the repository.