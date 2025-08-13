# CI/CD Security Gating Flow - Sequence Diagram

This document provides comprehensive sequence diagrams showing the complete CI/CD security gating flow with Permit.io integration.

## Main CI/CD Pipeline Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant Maven as Maven Build
    participant Snyk as Snyk Scanner
    participant Docker as Docker Compose
    participant PDP as Permit.io PDP
    participant OPAL as OPAL Fetcher
    participant Redis as Redis
    participant App as Spring Boot App

    Note over Dev, App: Standard CI/CD Pipeline with Security Gating

    Dev->>GH: git push to main/develop branch
    GH->>GA: Trigger workflow (gating-pipeline.yml)
    
    Note over GA: Job 1: Build and Security Scan
    GA->>GA: Checkout code
    GA->>GA: Set up JDK 11
    GA->>GA: Cache Maven dependencies
    
    GA->>Maven: mvn clean compile
    Maven-->>GA: Build successful
    
    GA->>Snyk: Install and authenticate Snyk CLI
    GA->>Snyk: snyk test --json > snyk-results.json
    Snyk-->>GA: Vulnerability scan results
    
    GA->>GA: Parse vulnerability counts (critical/high/medium/low)
    GA->>GA: Upload Snyk results as artifact
    
    Note over GA: Job 2: Security Gate Evaluation
    GA->>GA: Download Snyk results artifact
    GA->>GA: Create .env with secrets (PERMIT_API_KEY, SNYK_TOKEN)
    
    GA->>Docker: docker-compose up -d permit-pdp redis opal-fetcher
    Docker->>PDP: Start PDP container (port 7766)
    Docker->>Redis: Start Redis container (port 6379)
    Docker->>OPAL: Start OPAL fetcher (port 8000)
    
    PDP->>PDP: Initialize with PERMIT_API_KEY
    PDP->>PDP: Sync policies from Permit.io cloud
    OPAL->>OPAL: Initialize Snyk data fetcher
    
    GA->>PDP: curl http://localhost:7001/healthy (health check)
    PDP-->>GA: 200 OK (ready)
    
    GA->>GA: chmod +x evaluate-gates.sh
    GA->>GA: ./evaluate-gates.sh snyk-results.json
    
    Note over GA, PDP: Gate Evaluation Process (see detailed diagram)
    GA->>PDP: POST /allowed with vulnerability data
    PDP->>PDP: Evaluate OPA/Rego policies
    PDP-->>GA: Authorization decision (allow/deny + details)
    
    alt Gates Pass (exit code 0)
        GA->>GA: ✅ All security gates passed
        GA->>GA: Continue to next job
    else Soft Gate Warning (exit code 1)
        GA->>GA: ⚠️ Soft gate warnings - proceeding with caution
        GA->>GA: Continue to next job
    else Hard Gate Failure (exit code 2)
        GA->>GA: ❌ Hard gate failed - deployment blocked
        alt Override enabled
            GA->>GA: ⚠️ Gates overridden by user
            GA->>GA: Continue to next job
        else No override
            GA->>GA: FAIL pipeline
        end
    end
    
    GA->>Docker: docker-compose down (cleanup)
    
    Note over GA: Job 3: Build Docker Image (if gates pass)
    GA->>GA: Set up Docker Buildx
    GA->>GA: docker build -t gating-poc-app:${GITHUB_SHA}
    GA->>GA: Upload Docker image artifact
    
    Note over GA: Job 4: Deploy (production only)
    alt Deploy to Production (main branch)
        GA->>GA: Download Docker image
        GA->>GA: docker load < gating-poc-app.tar
        GA->>App: docker run -d -p 8080:8080 gating-poc-app
        GA->>App: curl http://localhost:8080/actuator/health
        App-->>GA: 200 OK (healthy)
        GA->>GA: ✅ Deployment successful
    end
```

## Gate Evaluation Detail Flow

```mermaid
sequenceDiagram
    participant Script as evaluate-gates.sh
    participant ENV as Environment
    participant Snyk as Snyk Results
    participant PDP as Permit.io PDP
    participant OPA as OPA Engine
    participant Policy as Rego Policy

    Note over Script, Policy: Detailed Gate Evaluation Process

    Script->>ENV: Load .env file if PERMIT_API_KEY not set
    Script->>ENV: Check PERMIT_API_KEY availability
    alt API Key Missing
        Script->>Script: Exit with error code 2
    end
    
    Script->>PDP: curl http://localhost:7001/healthy (readiness check)
    loop Max 30 attempts, 2s interval
        PDP-->>Script: Health status
        alt PDP Ready
            Script->>Script: ✓ PDP is ready
        else PDP Not Ready
            Script->>Script: Wait 2 seconds, retry
        end
    end
    
    Script->>Snyk: Read snyk-results.json
    Script->>Script: Extract vulnerability counts with jq
    Note right of Script: CRITICAL_COUNT = critical vulnerabilities<br/>HIGH_COUNT = high vulnerabilities<br/>MEDIUM_COUNT = medium vulnerabilities<br/>LOW_COUNT = low vulnerabilities
    
    Script->>Script: Create Permit.io payload
    Note right of Script: Include user role (ci-pipeline/editor)<br/>vulnerability data, context info
    
    Script->>PDP: POST /allowed with authorization payload
    Note right of Script: Headers: Authorization: Bearer ${PERMIT_API_KEY}<br/>Content-Type: application/json
    
    PDP->>OPA: Evaluate request against policies
    OPA->>Policy: Execute gating_policy.rego
    
    Policy->>Policy: Check hard_gate_fail (critical > 0)
    Policy->>Policy: Check soft_gate_warn (high > 0)
    Policy->>Policy: Check medium_warn (medium > 0)
    
    alt Critical Vulnerabilities Found
        Policy->>Policy: hard_gate_fail = true
        Policy->>OPA: Return FAIL decision
    else High Vulnerabilities Found (no critical)
        Policy->>Policy: soft_gate_warn = true
        Policy->>OPA: Return PASS_WITH_WARNINGS
    else Medium Vulnerabilities Found (no critical/high)
        Policy->>Policy: medium_warn = true
        Policy->>OPA: Return PASS_WITH_INFO
    else No Vulnerabilities
        Policy->>OPA: Return PASS
    end
    
    OPA->>PDP: Policy evaluation result
    PDP-->>Script: JSON response {allow: boolean, decision: string, violations: []}
    
    Script->>Script: Parse PDP response
    Script->>Script: Determine decision based on allow field and counts
    
    alt Decision: PASS
        Script->>Script: ✅ DECISION: PASS - All security gates passed
        Script->>Script: Exit code 0
    else Decision: EDITOR_OVERRIDE
        Script->>Script: 🔓 DECISION: EDITOR OVERRIDE - Deployment allowed with editor privileges
        Script->>Script: Log audit trail (user, vulnerabilities, justification)
        Script->>Script: Exit code 0
    else Decision: PASS_WITH_WARNINGS
        Script->>Script: ⚠️ DECISION: PASS WITH WARNINGS - Soft gate triggered
        Script->>Script: Display high severity vulnerabilities
        Script->>Script: Exit code 1 (warning)
    else Decision: PASS_WITH_INFO
        Script->>Script: ℹ️ DECISION: PASS WITH INFO - Informational findings
        Script->>Script: Display medium severity vulnerabilities
        Script->>Script: Exit code 1 (warning)
    else Decision: FAIL
        Script->>Script: ❌ DECISION: FAIL - Hard gate triggered
        Script->>Script: Display critical vulnerabilities and recommendations
        Script->>Script: Exit code 2 (failure)
    end
```

## Editor Override Flow

```mermaid
sequenceDiagram
    participant Admin as Security Admin
    participant ENV as Environment Config
    participant Script as evaluate-gates.sh
    participant PDP as Permit.io PDP
    participant Audit as Audit Log

    Note over Admin, Audit: Emergency Override Scenario

    Admin->>ENV: Set USER_ROLE=editor
    Admin->>ENV: Set USER_KEY=admin_user_key
    Admin->>ENV: Document override justification
    
    Script->>ENV: Load environment variables
    Script->>Script: Detect USER_ROLE=editor
    Script->>Script: 🔑 Running with editor role privileges
    
    Script->>PDP: POST /allowed with editor user role
    Note right of Script: Payload includes:<br/>user.attributes.role = "editor"<br/>Critical vulnerabilities present
    
    PDP->>PDP: Evaluate editor permissions
    PDP->>PDP: Check if editor role has deploy permission
    PDP-->>Script: {allow: true} (editor override)
    
    Script->>Script: Detect is_editor_override = true
    Script->>Script: 🔓 DECISION: EDITOR OVERRIDE
    
    Script->>Audit: Log override event
    Note right of Audit: Timestamp: when<br/>User: admin_user_key<br/>Vulnerabilities: critical count<br/>Justification: required
    
    Script->>Script: ⚡ DEPLOYMENT PROCEEDING: Editor has overridden security gates
    Script->>Script: Display critical vulnerabilities (transparency)
    Script->>Script: Exit code 0 (proceed)
    
    Note over Admin: Post-deployment actions required:
    Note over Admin: 1. Address critical vulnerabilities immediately
    Note over Admin: 2. Document incident
    Note over Admin: 3. Revert to normal gates
    Note over Admin: 4. Security review
```

## Configuration and Environment Setup

```mermaid
sequenceDiagram
    participant CI as CI Environment
    participant Secrets as GitHub Secrets
    participant Docker as Docker Compose
    participant PDP as Permit.io PDP
    participant Permit as Permit.io Cloud

    Note over CI, Permit: Service Configuration and Startup

    CI->>Secrets: Retrieve PERMIT_API_KEY
    CI->>Secrets: Retrieve SNYK_TOKEN
    CI->>Secrets: Retrieve SNYK_ORG_ID
    
    CI->>CI: Create .env file from secrets
    Note right of CI: PERMIT_API_KEY=permit_key_xxx<br/>SNYK_TOKEN=xxx<br/>SNYK_ORG_ID=xxx
    
    CI->>Docker: docker-compose up -d permit-pdp redis opal-fetcher
    
    Docker->>PDP: Start container with environment variables
    Note right of PDP: Port 7766 (API)<br/>Port 7001 (Health)<br/>PDP_DEBUG=true
    
    PDP->>Permit: Authenticate with API key
    Permit-->>PDP: Authentication successful
    
    PDP->>Permit: Sync policies and RBAC configuration
    Permit-->>PDP: Policy data downloaded
    
    PDP->>PDP: Initialize OPA engine with policies
    PDP->>PDP: Start HTTP server on port 7766
    
    Docker->>Docker: Start Redis for OPAL pub/sub
    Docker->>Docker: Start OPAL fetcher service
    
    CI->>PDP: Health check loop (curl /ready)
    PDP-->>CI: Service ready for requests
    
    Note over CI: Services initialized and ready for gate evaluation
```

## Key Components

### Exit Codes
- **0**: All gates passed (or editor override active)
- **1**: Soft gate warning (non-blocking)
- **2**: Hard gate failure (blocking)

### User Roles
- **ci-pipeline**: Standard CI/CD role with normal gate enforcement
- **editor**: Override role for emergency deployments with audit trail

### Gate Types
- **Hard Gate**: Critical vulnerabilities block deployment
- **Soft Gate**: High vulnerabilities warn but allow deployment
- **Info Gate**: Medium vulnerabilities provide informational warnings

### Security Considerations
- All override actions are logged with user identification
- Critical vulnerabilities must be addressed post-deployment
- Role-based access control enforced through Permit.io
- API keys secured through GitHub Secrets