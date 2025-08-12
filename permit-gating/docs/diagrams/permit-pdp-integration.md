# Permit.io PDP Integration Flow - Sequence Diagrams

This document provides detailed sequence diagrams showing the Permit.io Policy Decision Point (PDP) integration and authorization flows.

## PDP Initialization and Policy Synchronization

```mermaid
sequenceDiagram
    participant Docker as Docker Compose
    participant PDP as Permit.io PDP
    participant Permit as Permit.io Cloud
    participant OPA as OPA Engine
    participant Policy as Policy Store
    participant RBAC as RBAC Store

    Note over Docker, RBAC: PDP Startup and Policy Synchronization

    Docker->>PDP: docker run permitio/pdp-v2:latest
    Note right of PDP: Environment:<br/>PDP_API_KEY=permit_key_xxx<br/>PDP_DEBUG=true<br/>PDP_LOG_LEVEL=DEBUG

    PDP->>PDP: Initialize PDP service
    PDP->>PDP: Validate API key format
    
    alt Invalid API Key
        PDP->>PDP: Log error and exit
    end
    
    PDP->>Permit: POST /api/v2/auth/validate
    Note right of PDP: Headers: Authorization: Bearer ${API_KEY}
    
    Permit->>Permit: Validate API key and permissions
    alt Authentication Failed
        Permit-->>PDP: 401 Unauthorized
        PDP->>PDP: Exit with authentication error
    else Authentication Successful
        Permit-->>PDP: 200 OK + workspace info
    end
    
    PDP->>Permit: GET /api/v2/projects/{project_id}/policies
    Permit-->>PDP: Policy definitions (Rego files)
    
    PDP->>Policy: Store policy definitions
    Policy-->>PDP: Policies cached locally
    
    PDP->>Permit: GET /api/v2/projects/{project_id}/roles
    Permit-->>PDP: Role definitions and permissions
    
    PDP->>RBAC: Store RBAC configuration
    RBAC-->>PDP: RBAC data cached locally
    
    PDP->>OPA: Initialize OPA engine
    PDP->>OPA: Load policies into OPA
    OPA-->>PDP: Policies compiled and ready
    
    PDP->>PDP: Start HTTP server on port 7766
    PDP->>PDP: Start health check endpoint on port 7001
    
    Note over PDP: PDP fully initialized and ready to serve requests
    
    loop Policy Sync (every 30 seconds)
        PDP->>Permit: Check for policy updates
        alt Policies Changed
            Permit-->>PDP: Updated policies
            PDP->>OPA: Reload policies
        else No Changes
            Permit-->>PDP: 304 Not Modified
        end
    end
```

## Authorization Request Processing

```mermaid
sequenceDiagram
    participant Client as evaluate-gates.sh
    participant PDP as Permit.io PDP
    participant OPA as OPA Engine
    participant Policy as gating_policy.rego
    participant RBAC as RBAC Engine
    participant Audit as Audit Log

    Note over Client, Audit: Authorization Request Processing

    Client->>PDP: POST /allowed
    Note right of Client: Content-Type: application/json<br/>Authorization: Bearer ${API_KEY}
    
    Note right of Client: Payload:<br/>{<br/>  "user": {"key": "github-actions", "attributes": {"role": "ci-pipeline"}},<br/>  "action": "deploy",<br/>  "resource": {"type": "deployment", "attributes": {...}}<br/>}
    
    PDP->>PDP: Validate request format
    alt Invalid Request
        PDP-->>Client: 400 Bad Request
    end
    
    PDP->>PDP: Extract user, action, resource from request
    
    PDP->>RBAC: Check user role and permissions
    RBAC->>RBAC: Lookup user "github-actions"
    RBAC->>RBAC: Get role "ci-pipeline" permissions
    RBAC-->>PDP: User has "deploy" permission on "deployment" resource
    
    PDP->>OPA: Evaluate authorization request
    Note right of PDP: Input data:<br/>- User attributes (role, key)<br/>- Action (deploy)<br/>- Resource attributes (vulnerability counts)<br/>- Context (environment, repository)
    
    OPA->>Policy: Execute gating_policy.rego
    
    Policy->>Policy: Check hard_gate_fail rule
    Note right of Policy: if input.resource.attributes.criticalCount > 0
    
    Policy->>Policy: Check soft_gate_warn rule
    Note right of Policy: if input.resource.attributes.highCount > 0
    
    Policy->>Policy: Check medium_warn rule
    Note right of Policy: if input.resource.attributes.mediumCount > 0
    
    Policy->>Policy: evaluate_gates function
    Policy->>Policy: Create violation messages for each gate type
    Policy->>Policy: determine_overall_result based on violations
    
    alt Critical Vulnerabilities (criticalCount > 0)
        Policy->>Policy: hard_gate_fail = true
        Policy->>Policy: Create CRITICAL_VULNERABILITY violation
        Policy->>Policy: Overall result: {allow: false, decision: "FAIL"}
    else High Vulnerabilities (highCount > 0, no critical)
        Policy->>Policy: soft_gate_warn = true
        Policy->>Policy: Create HIGH_VULNERABILITY violation
        Policy->>Policy: Overall result: {allow: true, decision: "PASS_WITH_WARNINGS"}
    else Medium Vulnerabilities (mediumCount > 0, no critical/high)
        Policy->>Policy: medium_warn = true
        Policy->>Policy: Create MEDIUM_VULNERABILITY violation
        Policy->>Policy: Overall result: {allow: true, decision: "PASS_WITH_INFO"}
    else No Vulnerabilities
        Policy->>Policy: Overall result: {allow: true, decision: "PASS"}
    end
    
    Policy->>Policy: get_recommendations based on decision
    Policy->>Policy: Build final response with violations and recommendations
    
    Policy-->>OPA: Structured response with allow/deny decision
    OPA-->>PDP: Policy evaluation result
    
    PDP->>Audit: Log authorization request and decision
    Note right of Audit: Timestamp, user, action, resource, decision, violations
    
    PDP-->>Client: JSON response
    Note right of PDP: {<br/>  "allow": boolean,<br/>  "decision": "PASS|FAIL|PASS_WITH_WARNINGS",<br/>  "violations": [...],<br/>  "recommendations": [...]<br/>}
```

## Editor Override Authorization Flow

```mermaid
sequenceDiagram
    participant Admin as Security Admin
    participant Client as evaluate-gates.sh
    participant PDP as Permit.io PDP
    participant RBAC as RBAC Engine
    participant Policy as gating_policy.rego
    participant Audit as Audit Log

    Note over Admin, Audit: Editor Override Authorization

    Admin->>Client: Set USER_ROLE=editor, USER_KEY=admin_user
    
    Client->>PDP: POST /allowed
    Note right of Client: Payload includes:<br/>user.attributes.role = "editor"<br/>Critical vulnerabilities present
    
    PDP->>RBAC: Check user "admin_user" permissions
    RBAC->>RBAC: Lookup user in editor role
    RBAC->>RBAC: Verify editor role has "deploy" permission
    RBAC->>RBAC: Check if editor can override security gates
    RBAC-->>PDP: Editor has override permissions
    
    PDP->>Policy: Evaluate with editor context
    
    Policy->>Policy: Check hard_gate_fail (still true for critical vulns)
    Policy->>Policy: Check user role = "editor"
    
    alt User is Editor AND has override permission
        Policy->>Policy: Allow deployment despite critical vulnerabilities
        Policy->>Policy: Create EDITOR_OVERRIDE decision
        Policy->>Policy: Log critical vulnerabilities being overridden
        Policy->>Policy: Overall result: {allow: true, decision: "EDITOR_OVERRIDE"}
    else User is not Editor
        Policy->>Policy: Apply normal gate rules
        Policy->>Policy: Overall result: {allow: false, decision: "FAIL"}
    end
    
    Policy-->>PDP: Authorization decision
    
    PDP->>Audit: Log override event
    Note right of Audit: CRITICAL: Editor override used<br/>User: admin_user<br/>Critical vulns: count<br/>Timestamp: now<br/>Justification: required
    
    PDP-->>Client: Override approval response
    Note right of PDP: {<br/>  "allow": true,<br/>  "decision": "EDITOR_OVERRIDE",<br/>  "audit_trail": {...}<br/>}
    
    Client->>Client: Display override warnings
    Client->>Client: Require post-deployment remediation
```

## Role-Based Access Control (RBAC) Details

```mermaid
sequenceDiagram
    participant Config as Permit.io Dashboard
    participant API as Permit.io API
    participant PDP as PDP RBAC Cache
    participant Request as Authorization Request

    Note over Config, Request: RBAC Configuration and Evaluation

    Config->>API: Define roles and permissions
    Note right of Config: Roles:<br/>- ci-pipeline: standard deployment<br/>- editor: override permissions<br/>- viewer: read-only access
    
    Config->>API: Assign users to roles
    Note right of Config: Users:<br/>- github-actions → ci-pipeline<br/>- admin_user → editor<br/>- security_team → viewer
    
    Config->>API: Define resource permissions
    Note right of Config: Resources:<br/>- deployment: deploy, view<br/>- policy: read, write (editor only)
    
    API->>PDP: Sync RBAC configuration
    PDP->>PDP: Cache user-role mappings
    PDP->>PDP: Cache role-permission mappings
    PDP->>PDP: Cache resource definitions
    
    Request->>PDP: Authorization request for user "github-actions"
    
    PDP->>PDP: Lookup user "github-actions"
    PDP->>PDP: Find role "ci-pipeline"
    PDP->>PDP: Check "ci-pipeline" permissions on "deployment"
    PDP->>PDP: Verify "deploy" action is allowed
    
    alt Standard Deployment (ci-pipeline)
        PDP->>PDP: Apply security gate policies
        PDP->>PDP: Return policy-based decision
    else Editor Override (editor role)
        PDP->>PDP: Check override permissions
        PDP->>PDP: Allow deployment with audit trail
    else Insufficient Permissions
        PDP->>PDP: Deny request - unauthorized
    end
    
    PDP-->>Request: RBAC decision + policy evaluation
```

## Health Check and Monitoring

```mermaid
sequenceDiagram
    participant Monitor as Health Monitor
    participant PDP as Permit.io PDP
    participant OPA as OPA Engine
    participant Permit as Permit.io Cloud
    participant Metrics as Metrics Collector

    Note over Monitor, Metrics: PDP Health Monitoring

    loop Every 15 seconds
        Monitor->>PDP: GET /healthy
        
        PDP->>PDP: Check internal services status
        PDP->>OPA: Ping OPA engine
        OPA-->>PDP: Engine status
        
        PDP->>Permit: Check API connectivity
        Permit-->>PDP: Connection status
        
        alt All Services Healthy
            PDP-->>Monitor: 200 OK {"status": "healthy"}
        else Service Issues
            PDP-->>Monitor: 503 Service Unavailable
        end
    end
    
    loop Every 30 seconds
        Monitor->>PDP: GET /ready
        
        PDP->>PDP: Check if ready to serve requests
        PDP->>PDP: Verify policies are loaded
        PDP->>PDP: Verify RBAC data is current
        
        alt Ready for Requests
            PDP-->>Monitor: 200 OK {"ready": true}
        else Not Ready
            PDP-->>Monitor: 503 Service Unavailable
        end
    end
    
    PDP->>Metrics: Report performance metrics
    Note right of Metrics: - Request latency<br/>- Authorization decisions/sec<br/>- Policy evaluation time<br/>- Cache hit rates
    
    alt Performance Degradation
        Metrics->>Metrics: Alert on high latency
        Metrics->>Metrics: Alert on error rates
    end
```

## API Response Formats

### Standard Authorization Response
```json
{
  "allow": true,
  "decision": "PASS_WITH_WARNINGS",
  "timestamp": 1693840800000,
  "project_id": "deployment-001",
  "summary": {
    "critical_count": 0,
    "high_count": 2,
    "medium_count": 5,
    "total_vulnerabilities": 7
  },
  "violations": [
    {
      "type": "HIGH_VULNERABILITY",
      "severity": "HIGH",
      "action": "WARN",
      "message": "Found 2 high severity vulnerabilities - Review recommended",
      "vulnerabilities": [...]
    }
  ],
  "recommendations": [
    "High severity vulnerabilities detected - review recommended",
    "Plan remediation for high severity issues"
  ]
}
```

### Editor Override Response
```json
{
  "allow": true,
  "decision": "EDITOR_OVERRIDE",
  "timestamp": 1693840800000,
  "audit_trail": {
    "user": "admin_user",
    "role": "editor",
    "overridden_gates": ["hard_gate_critical"],
    "justification_required": true,
    "critical_vulnerabilities": 1
  },
  "violations": [
    {
      "type": "CRITICAL_VULNERABILITY",
      "severity": "CRITICAL",
      "action": "OVERRIDE",
      "message": "Critical vulnerabilities overridden by editor"
    }
  ]
}
```

## Security Considerations

### Authentication & Authorization
- API key validation on every request
- Role-based access control enforcement
- Permission checking before policy evaluation
- Audit logging for all decisions

### Policy Security
- Policies signed and verified from Permit.io
- Secure policy synchronization over HTTPS
- Local policy caching for performance and resilience
- Policy version control and rollback capability

### Data Protection
- Vulnerability data encrypted in transit
- Sensitive information masked in logs
- API keys stored securely in GitHub Secrets
- Audit trails tamper-evident and immutable