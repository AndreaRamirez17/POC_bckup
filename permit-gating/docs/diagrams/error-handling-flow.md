# Error Handling and Recovery - Sequence Diagrams

This document provides comprehensive sequence diagrams showing error handling, recovery mechanisms, and failure scenarios in the Permit.io gating system.

## PDP Connection Failure and Recovery

```mermaid
sequenceDiagram
    participant Script as evaluate-gates.sh
    participant PDP as Permit.io PDP
    participant Docker as Docker Service
    participant Retry as Retry Logic
    participant Fallback as Fallback Handler
    participant Alert as Alert System

    Note over Script, Alert: PDP Connection Failure and Recovery

    Script->>PDP: curl http://localhost:7001/healthy (initial check)
    
    alt PDP Not Responding
        PDP-->>Script: Connection timeout/refused
        
        Script->>Retry: Initialize retry loop (max 30 attempts)
        
        loop Retry Logic (2-second intervals)
            Retry->>PDP: Health check attempt
            
            alt Still Not Ready
                PDP-->>Retry: Connection failed
                Retry->>Retry: Wait 2 seconds
                Retry->>Retry: Increment attempt counter
                
                alt Max Attempts Reached (30)
                    Retry->>Alert: PDP health check timeout
                    Retry->>Docker: Check container status
                    
                    Docker->>Docker: docker ps | grep permit-pdp
                    alt Container Not Running
                        Docker-->>Retry: Container stopped/missing
                        Retry->>Fallback: Container startup failed
                    else Container Running But Unhealthy
                        Docker-->>Retry: Container running
                        Retry->>Docker: docker logs permit-pdp
                        Retry->>Fallback: Service internal error
                    end
                    
                    Fallback->>Script: ✗ PDP failed to become ready
                    Script->>Script: Exit with code 2 (failure)
                end
            else PDP Ready
                PDP-->>Retry: 200 OK
                Retry->>Script: ✓ PDP is ready
            end
        end
    else PDP Responding
        PDP-->>Script: 200 OK (healthy)
        Script->>Script: Continue with gate evaluation
    end
```

## Authentication and Authorization Errors

```mermaid
sequenceDiagram
    participant Script as evaluate-gates.sh
    participant PDP as Permit.io PDP
    participant Permit as Permit.io Cloud
    participant Config as Configuration
    participant Recovery as Error Recovery

    Note over Script, Recovery: Authentication/Authorization Error Handling

    Script->>Script: Load PERMIT_API_KEY from environment
    
    alt API Key Missing
        Script->>Script: Check .env file
        alt .env File Not Found
            Script->>Recovery: API key configuration error
            Recovery->>Script: Error: PERMIT_API_KEY not set
            Script->>Script: Exit code 2 with instructions
        end
    end
    
    Script->>PDP: POST /allowed with Authorization header
    Note right of Script: Authorization: Bearer ${PERMIT_API_KEY}
    
    PDP->>Permit: Validate API key
    
    alt Invalid API Key Format
        Permit-->>PDP: Invalid key format
        PDP-->>Script: 400 Bad Request
        Script->>Recovery: API key format error
        Recovery->>Script: Check API key format (expect permit_key_...)
        Script->>Script: Exit code 2
        
    else Expired/Invalid API Key
        Permit-->>PDP: 401 Unauthorized
        PDP-->>Script: 401 Unauthorized
        Script->>Recovery: Authentication failed
        Recovery->>Script: ✗ Authentication failed. Please check your PERMIT_API_KEY
        Script->>Script: Display troubleshooting steps
        Script->>Script: Exit code 2
        
    else Insufficient Permissions
        Permit-->>PDP: 403 Forbidden
        PDP-->>Script: 403 Forbidden
        Script->>Recovery: Authorization failed
        Recovery->>Script: ✗ API key doesn't have sufficient permissions
        Script->>Script: Exit code 2
        
    else Rate Limited
        Permit-->>PDP: 429 Too Many Requests
        PDP-->>Script: 429 Rate Limited
        Script->>Recovery: Rate limit exceeded
        Recovery->>Script: Wait and retry with exponential backoff
        
        loop Retry with Backoff
            Recovery->>Recovery: Wait (backoff_time)
            Recovery->>PDP: Retry request
            alt Success
                PDP-->>Recovery: 200 OK
                Recovery->>Script: Continue processing
            else Still Rate Limited
                Recovery->>Recovery: Increase backoff time
                alt Max Retries Exceeded
                    Recovery->>Script: ✗ Rate limit persists - try again later
                    Script->>Script: Exit code 2
                end
            end
        end
        
    else Valid Authentication
        Permit-->>PDP: Authentication successful
        PDP->>Script: Process authorization request
    end
```

## Data Processing Errors

```mermaid
sequenceDiagram
    participant Script as evaluate-gates.sh
    participant FileSystem as File System
    participant JSON as JSON Parser
    participant Validator as Data Validator
    participant Recovery as Error Recovery
    participant Mock as Mock Data

    Note over Script, Mock: Data Processing Error Handling

    Script->>FileSystem: Read snyk-results.json
    
    alt File Not Found
        FileSystem-->>Script: File not found error
        Script->>Recovery: Snyk results file missing
        Recovery->>Script: Error: Snyk results file not found
        Recovery->>Script: Check file path: snyk-results.json
        Script->>Script: Exit code 2
        
    else File Permission Error
        FileSystem-->>Script: Permission denied
        Script->>Recovery: File access error
        Recovery->>Script: Error: Cannot read snyk-results.json
        Script->>Script: Exit code 2
    end
    
    Script->>JSON: Parse JSON content with jq
    
    alt JSON Syntax Error
        JSON-->>Script: jq parse error
        Script->>Recovery: Invalid JSON format
        Recovery->>Script: Error: Invalid JSON in snyk-results.json
        Recovery->>Recovery: Validate file is proper JSON
        
        alt Attempt JSON Repair
            Recovery->>JSON: Try alternative parsing
            alt Repair Successful
                JSON-->>Recovery: Parsed data
                Recovery->>Script: Continue with warning
            else Repair Failed
                Recovery->>Mock: Use mock data for testing
                Mock-->>Recovery: Sample vulnerability data
                Recovery->>Script: Warning: Using mock data due to JSON error
            end
        end
        
    else JSON Missing Required Fields
        JSON-->>Script: Partial/incomplete data
        Script->>Validator: Validate data structure
        
        Validator->>Validator: Check for required fields
        alt Critical Fields Missing
            Validator->>Recovery: Missing vulnerabilities array
            Recovery->>Recovery: Check if this is empty scan result
            
            alt Empty Scan (No Vulnerabilities)
                Recovery->>Script: Set all counts to 0
                Script->>Script: Continue with empty vulnerability data
            else Malformed Data
                Recovery->>Script: Error: Malformed Snyk results
                Script->>Script: Exit code 2
            end
        end
        
    else Timeout During Processing
        JSON-->>Script: jq timeout (5 seconds exceeded)
        Script->>Recovery: Data processing timeout
        Recovery->>Recovery: Simplify data extraction
        Recovery->>JSON: Extract basic counts only
        
        alt Simplified Processing Success
            JSON-->>Recovery: Basic vulnerability counts
            Recovery->>Script: Continue with limited data
        else Still Timeout
            Recovery->>Script: Error: Data too large to process
            Script->>Script: Exit code 2
        end
    end
```

## Service Dependency Failures

```mermaid
sequenceDiagram
    participant Pipeline as CI/CD Pipeline
    participant Docker as Docker Compose
    participant PDP as Permit.io PDP
    participant Redis as Redis Cache
    participant OPAL as OPAL Fetcher
    participant Recovery as Recovery Handler

    Note over Pipeline, Recovery: Service Dependency Failure Management

    Pipeline->>Docker: docker-compose up -d
    
    Docker->>Redis: Start Redis container
    alt Redis Startup Failed
        Redis-->>Docker: Container failed to start
        Docker->>Recovery: Redis dependency failure
        Recovery->>Docker: Check port conflicts (6379)
        Recovery->>Docker: Check available memory
        Recovery->>Docker: Restart with different configuration
        
        alt Recovery Successful
            Redis-->>Recovery: Container started
        else Recovery Failed
            Recovery->>Pipeline: ✗ Redis startup failed
            Pipeline->>Pipeline: Exit pipeline with error
        end
    end
    
    Docker->>PDP: Start PDP container (depends on Redis)
    alt PDP Startup Failed
        PDP-->>Docker: Container failed to start
        Docker->>Recovery: PDP dependency failure
        
        Recovery->>Redis: Check Redis connectivity
        alt Redis Not Available
            Recovery->>Docker: Restart Redis first
            Recovery->>Docker: Wait for Redis health
            Recovery->>PDP: Retry PDP startup
        else Redis Available
            Recovery->>Recovery: Check PDP configuration
            Recovery->>Recovery: Validate PERMIT_API_KEY
            Recovery->>Recovery: Check port conflicts (7766)
            
            alt Configuration Valid
                Recovery->>PDP: Restart with corrected config
            else Invalid Configuration
                Recovery->>Pipeline: ✗ PDP configuration error
                Pipeline->>Pipeline: Exit with configuration guidance
            end
        end
    end
    
    Docker->>OPAL: Start OPAL Fetcher
    alt OPAL Startup Failed
        OPAL-->>Docker: Container failed to start
        Docker->>Recovery: OPAL dependency failure
        
        Recovery->>Recovery: Check if OPAL is required for current test
        alt OPAL Required
            Recovery->>OPAL: Diagnose startup failure
            Recovery->>Recovery: Check SNYK_TOKEN availability
            Recovery->>Recovery: Validate Dockerfile
            Recovery->>OPAL: Restart with debugging
        else OPAL Optional
            Recovery->>Pipeline: Continue without OPAL (use mock data)
        end
    end
    
    Pipeline->>Docker: Check overall service health
    Docker->>Docker: Verify all required services running
    
    alt Critical Services Down
        Docker->>Recovery: Multiple service failures
        Recovery->>Recovery: Assess cascade failure
        Recovery->>Docker: Attempt full restart
        
        alt Full Restart Successful
            Docker-->>Recovery: All services healthy
            Recovery->>Pipeline: Continue with services
        else Full Restart Failed
            Recovery->>Pipeline: ✗ Infrastructure failure
            Pipeline->>Pipeline: Exit with infrastructure error
        end
    end
```

## Network and Connectivity Issues

```mermaid
sequenceDiagram
    participant Local as Local Service
    participant Network as Network Layer
    participant External as External Service
    participant Monitor as Network Monitor
    participant Retry as Retry Handler
    participant Circuit as Circuit Breaker

    Note over Local, Circuit: Network Connectivity Error Handling

    Local->>Network: Request to external service
    Network->>External: Forward request
    
    alt Network Timeout
        External-->>Network: Request timeout
        Network-->>Local: Connection timeout error
        
        Local->>Monitor: Report network timeout
        Monitor->>Monitor: Check network connectivity
        Monitor->>Monitor: Ping external service
        
        alt Network Available
            Monitor->>Retry: Network OK, retry request
            Retry->>Retry: Implement exponential backoff
            
            loop Retry Attempts (max 3)
                Retry->>External: Retry request with backoff
                alt Success
                    External-->>Retry: Successful response
                    Retry->>Circuit: Reset failure counter
                    Retry->>Local: Return successful response
                else Still Timeout
                    Retry->>Retry: Increase backoff delay
                end
            end
            
            alt Max Retries Exceeded
                Retry->>Circuit: Record failure
                Circuit->>Circuit: Check failure threshold
                
                alt Threshold Exceeded
                    Circuit->>Circuit: Open circuit breaker
                    Circuit->>Local: Service unavailable (circuit open)
                else Threshold Not Exceeded
                    Circuit->>Local: Retry later or use fallback
                end
            end
            
        else Network Unavailable
            Monitor->>Local: Network connectivity issue
            Local->>Local: Use cached data or fallback
        end
        
    else DNS Resolution Failure
        Network-->>Local: DNS resolution failed
        Local->>Monitor: DNS lookup failure
        Monitor->>Monitor: Try alternative DNS servers
        Monitor->>Monitor: Check /etc/hosts entries
        
        alt DNS Resolution Fixed
            Monitor->>Retry: DNS resolved, retry
        else DNS Still Failing
            Monitor->>Local: Use IP address if available
            Local->>Local: Fallback to offline mode
        end
        
    else SSL/TLS Certificate Error
        External-->>Network: Certificate verification failed
        Network-->>Local: SSL error
        
        Local->>Monitor: SSL certificate issue
        Monitor->>Monitor: Check certificate validity
        Monitor->>Monitor: Verify certificate chain
        
        alt Certificate Valid
            Monitor->>Retry: Retry with updated CA bundle
        else Certificate Invalid
            Monitor->>Local: Security error - cannot proceed
            Local->>Local: Exit with security error
        end
        
    else Service Unavailable (503)
        External-->>Network: 503 Service Unavailable
        Network-->>Local: Service temporarily unavailable
        
        Local->>Monitor: Service unavailable
        Monitor->>Circuit: Check circuit breaker state
        
        alt Circuit Closed
            Circuit->>Retry: Allow retry with backoff
            Retry->>Retry: Wait (service_backoff_time)
            Retry->>External: Retry request
        else Circuit Open
            Circuit->>Local: Service marked as down
            Local->>Local: Use fallback/cached data
        end
    end
```

## Graceful Degradation Scenarios

```mermaid
sequenceDiagram
    participant System as Gating System
    participant Primary as Primary Service
    participant Secondary as Secondary Service
    participant Cache as Cache Layer
    participant Fallback as Fallback Logic
    participant User as End User

    Note over System, User: Graceful Degradation Strategies

    System->>Primary: Request primary functionality
    
    alt Primary Service Healthy
        Primary-->>System: Normal operation
        System->>User: Full functionality available
        
    else Primary Service Degraded
        Primary-->>System: Partial functionality/slow response
        System->>Fallback: Assess degradation level
        
        Fallback->>Cache: Check cache for recent data
        alt Fresh Cache Available
            Cache-->>Fallback: Cached data within TTL
            Fallback->>System: Use cached data with warning
            System->>User: ⚠️ Using cached data (degraded mode)
        else Cache Stale/Empty
            Fallback->>Secondary: Try secondary service
            alt Secondary Available
                Secondary-->>Fallback: Alternative data source
                Fallback->>System: Use secondary with limitations
                System->>User: ⚠️ Limited functionality available
            else Secondary Also Degraded
                Fallback->>Fallback: Evaluate criticality
                
                alt Critical Path
                    Fallback->>System: Use minimal safe defaults
                    System->>User: ⚠️ Operating in safe mode
                else Non-Critical Path
                    Fallback->>System: Disable non-essential features
                    System->>User: ⚠️ Some features temporarily disabled
                end
            end
        end
        
    else Primary Service Down
        Primary-->>System: Service unavailable
        System->>Fallback: Primary service failure
        
        Fallback->>Cache: Check emergency cache
        alt Emergency Cache Available
            Cache-->>Fallback: Last known good state
            Fallback->>System: Emergency operation mode
            System->>User: 🚨 Emergency mode - limited safety checks
        else No Cache Available
            Fallback->>Fallback: Evaluate safety requirements
            
            alt Safety-Critical Operation
                Fallback->>System: FAIL-SAFE: Block all operations
                System->>User: 🛑 Service unavailable - safety first
            else Non-Safety-Critical
                Fallback->>System: Allow with manual review required
                System->>User: ⚠️ Manual review required
            end
        end
    end
```

## Error Recovery Procedures

```mermaid
sequenceDiagram
    participant Error as Error Handler
    participant Diagnosis as Error Diagnosis
    participant Auto as Auto Recovery
    participant Manual as Manual Recovery
    participant Monitor as Monitoring
    participant Admin as Administrator

    Note over Error, Admin: Error Recovery Procedures

    Error->>Diagnosis: Error detected and categorized
    
    Diagnosis->>Diagnosis: Classify error type and severity
    Note right of Diagnosis: Categories:<br/>- Configuration errors<br/>- Network issues<br/>- Service failures<br/>- Data corruption<br/>- Security issues
    
    alt Configuration Error
        Diagnosis->>Auto: Attempt automatic config repair
        Auto->>Auto: Validate configuration files
        Auto->>Auto: Apply known fixes
        
        alt Auto Fix Successful
            Auto->>Monitor: Configuration repaired
            Monitor->>Error: Resume normal operation
        else Auto Fix Failed
            Auto->>Manual: Escalate to manual intervention
            Manual->>Admin: Alert: Configuration requires attention
        end
        
    else Network Issue
        Diagnosis->>Auto: Network recovery procedures
        Auto->>Auto: Test connectivity
        Auto->>Auto: Reset network connections
        Auto->>Auto: Try alternative endpoints
        
        alt Network Restored
            Auto->>Monitor: Network connectivity restored
        else Network Still Down
            Auto->>Manual: Network intervention required
            Manual->>Admin: Alert: Network infrastructure issue
        end
        
    else Service Failure
        Diagnosis->>Auto: Service restart procedures
        Auto->>Auto: Graceful service restart
        Auto->>Auto: Health check validation
        
        alt Service Recovered
            Auto->>Monitor: Service restored to health
        else Service Still Failing
            Auto->>Manual: Service requires investigation
            Manual->>Admin: Alert: Service failure analysis needed
            Manual->>Admin: Include: logs, metrics, recent changes
        end
        
    else Data Corruption
        Diagnosis->>Manual: Data integrity issue (manual only)
        Manual->>Admin: Critical Alert: Data corruption detected
        Manual->>Admin: Recommend: Stop processing, assess damage
        
    else Security Issue
        Diagnosis->>Manual: Security incident (immediate escalation)
        Manual->>Admin: Security Alert: Immediate attention required
        Manual->>Manual: Isolate affected systems
        Manual->>Manual: Preserve evidence
    end
    
    Monitor->>Monitor: Track recovery success rate
    Monitor->>Monitor: Log all recovery actions
    Monitor->>Admin: Recovery summary report
```

## Error Response Formats and Exit Codes

### Exit Code Definitions
- **0**: Success - All gates passed or valid override
- **1**: Warning - Soft gates triggered, deployment allowed with warnings
- **2**: Failure - Hard gates failed, configuration errors, or system failures

### Error Response Examples

#### Configuration Error Response
```bash
Error: PERMIT_API_KEY environment variable is not set
Please set it by running: export PERMIT_API_KEY=your_api_key
Or create a .env file in the project root with: PERMIT_API_KEY=your_api_key

Exit code: 2
```

#### PDP Connection Error Response
```bash
✗ PDP failed to become ready after 30 attempts
Check:
1. Docker container status: docker ps | grep permit-pdp
2. Container logs: docker logs permit-pdp  
3. Network connectivity: curl http://localhost:7766/healthy
4. API key validity in Permit.io dashboard

Exit code: 2
```

#### Authentication Error Response
```bash
✗ API authentication failed (401 Unauthorized)
Please check your PERMIT_API_KEY
Make sure it's a valid API key from https://app.permit.io

Exit code: 2
```

### Recovery Recommendations

#### Immediate Actions
1. **Check Configuration**: Verify all environment variables are set
2. **Validate Connectivity**: Test network connections to external services
3. **Review Logs**: Examine container and service logs for specific errors
4. **Health Checks**: Verify all dependent services are running

#### Escalation Procedures
1. **Level 1**: Automatic retry with exponential backoff
2. **Level 2**: Fallback to cached data or alternative services
3. **Level 3**: Manual intervention with detailed error reporting
4. **Level 4**: Security team involvement for security-related issues