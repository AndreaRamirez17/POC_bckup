# Security Gating Policies

This directory contains the security policies used by the CI/CD Security Gating Platform to evaluate vulnerabilities and make deployment decisions.

## Files

### gating_policy.rego
The main Open Policy Agent (OPA) Rego policy file that defines the security gating logic:

- **Hard Gates**: Block deployment on critical vulnerabilities (CVSS >= 9.0)
- **Soft Gates**: Warn on high severity vulnerabilities (CVSS 7.0-8.9)
- **Info Gates**: Provide information on medium severity issues (CVSS 4.0-6.9)
- **Editor Override**: Allows authorized users with `editor` role to bypass gates

**Policy Decisions:**
- `PASS`: No critical or high vulnerabilities found
- `FAIL`: Critical vulnerabilities detected (hard gate)
- `PASS_WITH_WARNINGS`: High severity vulnerabilities present (soft gate)
- `PASS_WITH_INFO`: Medium severity vulnerabilities present
- `EDITOR_OVERRIDE`: Editor user bypassing security gates

### permit_config.json
Configuration file for Permit.io integration that defines:
- Resources and actions for the security gating system
- Role definitions (ci-pipeline, editor)
- Permission mappings

## Policy Validation

The policies in this directory are validated using OPA CLI during the validation process. The `validate-permit.sh` script will:

1. Check that both policy files exist
2. Validate the Rego syntax using OPA (if installed)
3. Validate the JSON configuration structure

### Installing OPA for Local Validation

OPA CLI is optional but recommended for local policy development. The validation script will offer to install it automatically, or you can install it manually:

```bash
# Linux/WSL
curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.68.0/opa_linux_amd64_static
chmod +x opa
sudo mv opa /usr/local/bin/

# macOS
curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.68.0/opa_darwin_amd64
chmod +x opa
sudo mv opa /usr/local/bin/

# Verify installation
opa version
```

### Testing Policies Locally

To test the Rego policy locally with OPA:

```bash
# Format check
opa fmt gating_policy.rego

# Syntax validation
opa test gating_policy.rego

# Evaluate with sample data
opa eval -d gating_policy.rego -i sample_input.json "data.gating.decision"
```

## Policy Updates

When modifying policies:

1. Update the `.rego` file with your changes
2. Run `validate-permit.sh` to ensure syntax is valid
3. Test locally with sample vulnerability data
4. Deploy to Permit.io PDP for production use

## Integration with Permit.io

These policies are loaded into the Permit.io Policy Decision Point (PDP) container at runtime. The PDP evaluates incoming requests against these policies to make gate decisions.

The evaluation flow:
1. Snyk scan results are parsed by `evaluate-gates.sh`
2. Vulnerability data is sent to Permit.io PDP
3. PDP evaluates against `gating_policy.rego`
4. Decision is returned and enforced in the pipeline

## Role-Based Access Control

The policies support different user roles:

- **ci-pipeline**: Default role for automated CI/CD pipelines
  - Subject to all security gates
  - Cannot override critical vulnerability blocks

- **editor**: Elevated role for authorized users
  - Can override security gates when necessary
  - All overrides are logged with full audit trail
  - Should be used sparingly and with proper justification

To use editor override, configure the following in your `.env` file:
```bash
USER_ROLE=editor
USER_KEY=your_editor_key
```