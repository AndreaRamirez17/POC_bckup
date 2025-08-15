# Permit.io Cloud Configuration Fix Guide

## Issue Summary
The Safe Deployment Gate system is working correctly, but there are configuration mismatches between the local implementation and Permit.io cloud configuration that cause audit logs to show outdated resource set names.

## Configuration Mismatches Identified

### 1. Resource Set Name Mismatch
- **Current**: `Critical_5fVulnerability_5fGate`
- **Expected**: `Safe_Deployment_Gate`
- **Impact**: Audit logs show old naming, confusing implementation tracking

### 2. User Role Assignment
- **Current**: david-santander has "editor" role
- **Expected**: david-santander should have "Security Officer" role
- **Impact**: Role-based overrides work but audit trail shows incorrect role

### 3. Resource Set Condition Verification
- **Expected**: `criticalCount equals 0` for Safe Deployment Gate matching
- **Need to verify**: Condition is properly configured for inverted ABAC logic

## Manual Fix Steps

### Step 1: Update Resource Set Configuration

1. **Login to Permit.io Dashboard**
   - Navigate to: https://app.permit.io
   - Login with your account credentials

2. **Access Resource Sets**
   - Click on "Policy" in the left sidebar
   - Click on "Resource Sets" 
   - Look for existing resource set with critical vulnerability logic

3. **Option A: Rename Existing Resource Set**
   - Find: "Critical_5fVulnerability_5fGate" (or similar critical vulnerability resource set)
   - Click "Edit" or settings icon
   - Change name to: **"Safe_Deployment_Gate"**
   - Update condition to: **`criticalCount equals 0`**
   - Save changes

4. **Option B: Create New Resource Set (if needed)**
   - Click "Create Resource Set"
   - Name: **"Safe_Deployment_Gate"**
   - Description: "Matches safe deployments with zero critical vulnerabilities"
   - Condition: **`criticalCount equals 0`**
   - Save new resource set

### Step 2: Update User Role Assignment

1. **Access User Management**
   - Navigate to "Directory" or "Users" section
   - Search for user: **david-santander**

2. **Update User Role**
   - Find david-santander in user list
   - Current role should show: "editor"
   - Change role to: **"Security Officer"**
   - Save changes

3. **Verify Role Permissions**
   - Ensure "Security Officer" role has:
     - ✅ Deploy permission on base deployment resource
     - ✅ Override capabilities for critical vulnerabilities
     - ✅ Access to Safe Deployment Gate resource set

### Step 3: Verify Policy Matrix Configuration

1. **Access Policy Matrix**
   - Navigate to "Policy" section
   - Open policy matrix/permissions view

2. **Verify Safe Deployment Gate Access**
   - Resource Set: "Safe_Deployment_Gate"
   - Action: "deploy"
   - Roles with access:
     - ✅ ci-pipeline (SAFE_ONLY access)
     - ✅ developer (SAFE_ONLY access) 
     - ✅ editor (EMERGENCY_OVERRIDE access)
     - ✅ Security Officer (FULL_OVERRIDE access)

3. **Verify Base Deployment Override**
   - Resource: "deployment" (base resource)
   - Action: "deploy" 
   - Override roles:
     - ❌ ci-pipeline (NO access)
     - ❌ developer (NO access)
     - ✅ editor (EMERGENCY_OVERRIDE access)
     - ✅ Security Officer (FULL_OVERRIDE access)

## Verification Steps

### Automated Verification
Run the verification script to test configuration alignment:

```bash
# Run verification script
./permit-gating/scripts/verify-cloud-config.sh
```

This script will:
- ✅ Test safe deployment authorization (criticalCount = 0)
- ✅ Test override deployment authorization (criticalCount > 0)
- ✅ Verify correct Resource Set names in audit logs
- ✅ Report configuration mismatches

### Manual Testing
Run local gate testing to verify end-to-end functionality:

```bash
# Test with different user roles
export USER_ROLE="Security Officer"
export USER_KEY="david-santander" 
./permit-gating/scripts/test-gates-local.sh

# Test with developer role (should be blocked with critical vulnerabilities)
export USER_ROLE="developer"
export USER_KEY="test-developer"
./permit-gating/scripts/test-gates-local.sh
```

### GitHub Actions Testing
Trigger the pipeline to verify complete workflow:

```bash
# Commit a small change to trigger pipeline
git add .
git commit -m "Test Safe Deployment Gate configuration"
git push origin main
```

Monitor workflow logs for:
- ✅ Correct Resource Set names in audit logs
- ✅ Proper role assignment for david-santander
- ✅ Expected authorization decisions

## Expected Results After Fix

### ✅ Audit Log Improvements
- Resource Set will show: `"resource_set_key": "Safe_Deployment_Gate"`
- User role will show: `"role": "Security Officer"`
- Condition matching will be explicit: `criticalCount = 0`

### ✅ System Behavior (Unchanged)
- Safe deployments (criticalCount = 0): ✅ **ALLOWED** for all roles
- Critical vulnerabilities present: ❌ **BLOCKED** for developer/ci-pipeline
- Critical vulnerabilities present: ✅ **OVERRIDE** for editor/Security Officer

### ✅ Audit Trail Clarity
- Clear distinction between Safe Deployment Gate matches vs. overrides
- Proper role attribution in compliance logs
- Consistent naming across local implementation and cloud configuration

## Troubleshooting

### If Resource Set Changes Don't Appear
1. Allow 2-5 minutes for Permit.io cloud sync to PDP
2. Restart PDP container: `docker compose -f permit-gating/docker/docker-compose.gating.yml restart permit-pdp`
3. Check PDP logs for sync completion: `docker compose -f permit-gating/docker/docker-compose.gating.yml logs permit-pdp`

### If User Role Changes Don't Apply
1. Verify role change was saved in Permit.io UI
2. Check that "Security Officer" role exists and has proper permissions
3. Clear any cached user data by restarting PDP

### If Tests Still Show Old Configuration
1. Verify changes are saved and published in Permit.io
2. Check PDP container is using latest policy sync
3. Run verification script again after allowing sync time

## Support Resources

- **Permit.io Documentation**: https://docs.permit.io
- **Resource Sets Guide**: https://docs.permit.io/manage-your-account/policy-and-user-management/resource-sets/
- **ABAC Configuration**: https://docs.permit.io/concepts/abac-authorization/
- **Local Verification Script**: `./permit-gating/scripts/verify-cloud-config.sh`