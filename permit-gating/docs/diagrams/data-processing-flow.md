# Data Flow and Processing - Sequence Diagrams

This document provides detailed sequence diagrams showing data collection, transformation, and processing flows in the Permit.io gating system.

## Snyk Data Collection and Processing

```mermaid
sequenceDiagram
    participant GA as GitHub Actions
    participant Snyk as Snyk CLI
    participant SnykAPI as Snyk API
    participant Results as Snyk Results File
    participant Parser as Data Parser
    participant Transform as Data Transformer

    Note over GA, Transform: Snyk Vulnerability Data Collection and Processing

    GA->>Snyk: npm install -g snyk
    GA->>Snyk: snyk auth $SNYK_TOKEN
    Snyk->>SnykAPI: Authenticate with token
    SnykAPI-->>Snyk: Authentication successful
    
    GA->>Snyk: snyk test --json > snyk-results.json
    
    Snyk->>Snyk: Analyze Maven pom.xml dependencies
    Snyk->>SnykAPI: Query vulnerability database
    SnykAPI->>SnykAPI: Match dependencies against vulnerability database
    SnykAPI->>SnykAPI: Calculate CVSS scores and severity levels
    SnykAPI-->>Snyk: Vulnerability data with metadata
    
    Snyk->>Results: Write JSON results
    Note right of Results: Raw Snyk JSON format:<br/>{<br/>  "vulnerabilities": [...],<br/>  "summary": {...},<br/>  "metadata": {...}<br/>}
    
    GA->>Parser: Parse Snyk results with jq
    Parser->>Results: Read snyk-results.json
    
    Parser->>Parser: Extract vulnerability counts
    Note right of Parser: CRITICAL_COUNT = vulnerabilities[severity=="critical"].length<br/>HIGH_COUNT = vulnerabilities[severity=="high"].length<br/>MEDIUM_COUNT = vulnerabilities[severity=="medium"].length<br/>LOW_COUNT = vulnerabilities[severity=="low"].length
    
    Parser->>Parser: Extract vulnerability details (first 5 per severity)
    Note right of Parser: For each vulnerability:<br/>- id (CVE/Snyk ID)<br/>- title (description)<br/>- packageName<br/>- version<br/>- severity<br/>- cvssScore
    
    Parser->>Transform: Process and validate data
    Transform->>Transform: Validate JSON structure
    Transform->>Transform: Sanitize data for policy evaluation
    Transform->>Transform: Add metadata (timestamp, project info)
    
    Transform-->>GA: Structured vulnerability data ready for gates
```

## OPAL Data Fetcher Processing

```mermaid
sequenceDiagram
    participant Client as OPAL Client
    participant Fetcher as OPAL Fetcher Service
    participant SnykAPI as Snyk API
    participant Cache as Data Cache
    participant Mock as Mock Data Generator
    participant Format as Data Formatter

    Note over Client, Format: OPAL Data Fetcher Service Processing

    Client->>Fetcher: GET /snyk (fetch vulnerability data)
    
    Fetcher->>Fetcher: Check environment configuration
    Note right of Fetcher: SNYK_TOKEN, SNYK_ORG_ID, SNYK_PROJECT_ID
    
    alt Snyk Configuration Available
        Fetcher->>SnykAPI: GET /org/{orgId}/projects
        Note right of Fetcher: Headers: Authorization: token ${SNYK_TOKEN}
        
        SnykAPI-->>Fetcher: List of projects
        
        Fetcher->>Fetcher: Find project matching "gating-poc"
        alt Project Found
            Fetcher->>SnykAPI: POST /org/{orgId}/project/{projectId}/issues
            Note right of Fetcher: Filter: severities=[critical,high,medium,low]<br/>types=[vuln], ignored=false
            SnykAPI-->>Fetcher: Project vulnerability issues
        else No Project Found
            Fetcher->>Fetcher: Use first available project
        end
        
        Fetcher->>Format: Process Snyk API response
        Format->>Format: Categorize vulnerabilities by severity
        Format->>Format: Transform to standardized format
        Note right of Format: {<br/>  id, title, severity, cvssScore,<br/>  packageName, version, exploitMaturity<br/>}
        
    else Snyk Configuration Missing
        Fetcher->>Mock: Generate mock vulnerability data
        Mock->>Mock: Create realistic test vulnerabilities
        Note right of Mock: Mock data includes:<br/>- Log4j critical vulnerability<br/>- Commons-collections high<br/>- Jackson medium severity
        Mock-->>Fetcher: Mock vulnerability data
    end
    
    Fetcher->>Format: Create final response structure
    Format->>Format: Build vulnerability summary
    Note right of Format: summary: {<br/>  critical: count,<br/>  high: count,<br/>  medium: count,<br/>  low: count,<br/>  total: total_count<br/>}
    
    Format->>Format: Add gating decision metadata
    Note right of Format: gatingDecision: {<br/>  hardGate: critical > 0,<br/>  softGate: high > 0,<br/>  warnings: medium > 0<br/>}
    
    Format->>Cache: Store processed data (optional)
    Format-->>Fetcher: Formatted vulnerability data
    
    Fetcher-->>Client: JSON response with categorized vulnerabilities
```

## Policy Data Transformation for Permit.io

```mermaid
sequenceDiagram
    participant Script as evaluate-gates.sh
    participant Parser as JSON Parser
    participant Builder as Payload Builder
    participant Validator as Data Validator
    participant PDP as Permit.io PDP

    Note over Script, PDP: Data Transformation for Policy Evaluation

    Script->>Parser: Read snyk-results.json
    Parser->>Parser: Parse JSON with error handling
    
    alt JSON Parse Error
        Parser-->>Script: Exit with error code 2
    end
    
    Parser->>Parser: Extract vulnerability counts safely
    Note right of Parser: Use jq with null fallback:<br/>jq '.vulnerabilities | map(select(.severity == "critical")) | length // 0'
    
    Parser->>Parser: Extract vulnerability details (limited to 5 per type)
    Note right of Parser: Timeout protection (5 seconds)<br/>Include: id, title, packageName, version
    
    Parser-->>Script: Parsed vulnerability data
    
    Script->>Builder: Create Permit.io authorization payload
    
    Builder->>Builder: Build user context
    Note right of Builder: user: {<br/>  key: USER_KEY || "github-actions",<br/>  attributes: {<br/>    role: USER_ROLE || "ci-pipeline"<br/>  }<br/>}
    
    Builder->>Builder: Build resource context
    Note right of Builder: resource: {<br/>  type: "deployment",<br/>  key: UUID,<br/>  tenant: "default",<br/>  attributes: {...}<br/>}
    
    Builder->>Builder: Add vulnerability attributes
    Note right of Builder: attributes: {<br/>  criticalCount, highCount, mediumCount, lowCount,<br/>  vulnerabilities: {critical: [...], high: [...], medium: [...]},<br/>  summary: {total, critical, high, medium, low},<br/>  scanTimestamp: ISO8601<br/>}
    
    Builder->>Builder: Add context metadata
    Note right of Builder: context: {<br/>  environment: GITHUB_REF_NAME,<br/>  repository: GITHUB_REPOSITORY,<br/>  commit: GITHUB_SHA,<br/>  workflow: GITHUB_WORKFLOW<br/>}
    
    Builder->>Validator: Validate payload structure
    Validator->>Validator: Check required fields present
    Validator->>Validator: Validate data types and ranges
    Validator->>Validator: Ensure payload size within limits
    
    alt Validation Failed
        Validator-->>Script: Validation error
        Script->>Script: Exit with error code 2
    end
    
    Validator-->>Builder: Payload validated
    Builder-->>Script: Complete authorization payload
    
    Script->>PDP: POST /allowed with JSON payload
    Note right of Script: Content-Type: application/json<br/>Authorization: Bearer ${PERMIT_API_KEY}
```

## Real-time Data Processing and Caching

```mermaid
sequenceDiagram
    participant Source as Data Source
    participant Fetcher as Data Fetcher
    participant Cache as Redis Cache
    participant Transform as Data Transformer
    participant Consumer as Data Consumer
    participant Monitor as Cache Monitor

    Note over Source, Monitor: Real-time Data Processing with Caching

    Source->>Fetcher: New vulnerability data available
    
    Fetcher->>Cache: Check cache for existing data
    Note right of Cache: Cache key: snyk:{org_id}:{project_id}
    
    Cache-->>Fetcher: Cache status (hit/miss/expired)
    
    alt Cache Miss or Expired
        Fetcher->>Source: Fetch fresh vulnerability data
        Source-->>Fetcher: Raw vulnerability data
        
        Fetcher->>Transform: Process raw data
        Transform->>Transform: Validate and clean data
        Transform->>Transform: Apply data transformations
        Transform->>Transform: Add metadata and timestamps
        Transform-->>Fetcher: Processed data
        
        Fetcher->>Cache: Store processed data
        Note right of Cache: TTL: 300 seconds (5 minutes)<br/>Include: processed data + metadata
        
    else Cache Hit
        Cache-->>Fetcher: Cached processed data
        Fetcher->>Fetcher: Verify data freshness
        
        alt Data Still Fresh
            Fetcher->>Fetcher: Use cached data
        else Data Stale
            Fetcher->>Source: Refresh data
        end
    end
    
    Fetcher-->>Consumer: Deliver processed data
    
    Monitor->>Cache: Monitor cache performance
    Monitor->>Monitor: Track hit/miss ratios
    Monitor->>Monitor: Monitor memory usage
    Monitor->>Monitor: Check TTL effectiveness
    
    alt Cache Performance Issues
        Monitor->>Monitor: Alert on high miss rate
        Monitor->>Monitor: Adjust TTL values
        Monitor->>Monitor: Optimize cache keys
    end
```

## Data Quality and Validation Pipeline

```mermaid
sequenceDiagram
    participant Input as Data Input
    participant Schema as Schema Validator
    participant Quality as Quality Checker
    participant Sanitizer as Data Sanitizer
    participant Store as Data Store
    participant Alert as Alert System

    Note over Input, Alert: Data Quality and Validation Pipeline

    Input->>Schema: Raw vulnerability data
    
    Schema->>Schema: Validate against JSON schema
    Note right of Schema: Required fields:<br/>- vulnerabilities (array)<br/>- severity (enum)<br/>- id, title (strings)
    
    alt Schema Validation Failed
        Schema->>Alert: Schema validation error
        Schema-->>Input: Reject data with error details
    end
    
    Schema->>Quality: Schema-valid data
    
    Quality->>Quality: Check data completeness
    Note right of Quality: - All severity levels present<br/>- Vulnerability IDs unique<br/>- CVSS scores in valid range
    
    Quality->>Quality: Validate vulnerability metadata
    Note right of Quality: - Package names format<br/>- Version numbers valid<br/>- CVE IDs properly formatted
    
    Quality->>Quality: Check for data anomalies
    Note right of Quality: - Unusual vulnerability counts<br/>- Duplicate entries<br/>- Missing critical fields
    
    alt Quality Check Failed
        Quality->>Alert: Data quality issue detected
        Quality->>Quality: Log quality metrics
        alt Critical Quality Issue
            Quality-->>Input: Reject data
        else Minor Quality Issue
            Quality->>Sanitizer: Proceed with warnings
        end
    end
    
    Quality->>Sanitizer: Quality-checked data
    
    Sanitizer->>Sanitizer: Remove potentially harmful content
    Note right of Sanitizer: - Strip HTML/script tags<br/>- Limit string lengths<br/>- Encode special characters
    
    Sanitizer->>Sanitizer: Normalize data formats
    Note right of Sanitizer: - Standardize severity levels<br/>- Format timestamps<br/>- Normalize package names
    
    Sanitizer->>Store: Clean, validated data
    Store->>Store: Persist with metadata
    Note right of Store: Include:<br/>- Processing timestamp<br/>- Data quality score<br/>- Validation results
    
    Store-->>Input: Data successfully processed
    
    Alert->>Alert: Generate quality reports
    Note right of Alert: - Daily quality metrics<br/>- Trend analysis<br/>- Exception reports
```

## Data Flow Summary

### Data Sources
1. **Snyk API**: Real-time vulnerability scanning results
2. **Mock Data**: Testing and development scenarios
3. **GitHub Context**: Repository and workflow metadata

### Data Transformations
1. **Extraction**: Parse JSON vulnerability data with jq
2. **Categorization**: Group by severity (critical/high/medium/low)
3. **Sanitization**: Remove sensitive data, limit payload size
4. **Formatting**: Convert to Permit.io policy evaluation format

### Data Validation
1. **Schema Validation**: Ensure required fields and data types
2. **Quality Checks**: Verify data completeness and consistency
3. **Security Sanitization**: Remove potentially harmful content
4. **Size Limits**: Prevent payload overflow attacks

### Caching Strategy
1. **Redis Caching**: Store processed vulnerability data
2. **TTL Management**: 5-minute cache lifetime for fresh data
3. **Cache Keys**: Organized by organization and project
4. **Performance Monitoring**: Track hit rates and optimization

### Error Handling
1. **Graceful Degradation**: Fall back to mock data on API failures
2. **Retry Logic**: Automatic retry with exponential backoff
3. **Validation Errors**: Clear error messages and exit codes
4. **Monitoring**: Real-time alerts on data quality issues