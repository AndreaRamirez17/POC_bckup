Of course, here is the updated Business Requirements Document (BRD) including the microservices Spring Boot mock application.

# **Business Requirements Document: PoC for CI/CD Gating Platform**

Project: CI/CD Gating Platform Proof of Concept (PoC)  
Date: 2025-08-10  
Author: Gemini Assistant  
Status: Draft

---

### **1\. Introduction**

#### **1.1. Purpose**

This document outlines the business and functional requirements for a Proof of Concept (PoC) aimed at validating a new CI/CD gating platform. The primary objective is to evaluate the feasibility of using Permit.io as the core authorization engine, integrated with Snyk for security scanning and GitHub Actions for pipeline orchestration. This PoC serves as a foundational step in replacing the legacy GATR platform as part of Banamex's technology transition from Citi.

#### **1.2. Scope**

The scope of this PoC is to implement and test a select number of security gating policies based on Snyk vulnerability scans. It will demonstrate the end-to-end workflow from a code commit in GitHub, through a pipeline run in GitHub Actions, to a policy evaluation by Permit.io using data from Snyk, and finally, to a "pass" or "fail" decision that dictates the pipeline's outcome. The focus is on validating the core integration pattern and policy enforcement capabilities, not on migrating the full suite of gates from the existing GATR system.

---

### **2\. Business Problem & Opportunity**

As Banamex transitions from Citi, there is a critical need to replace the existing GATR (Gating and Automation for Technology Releases) platform. The current platform is deeply integrated with Citi's infrastructure, and its support teams have undergone significant changes, posing a potential risk to operational stability1111.

This transition presents an opportunity to adopt a modern, flexible, and decoupled architecture for policy enforcement. A platform based on Permit.io would leverage a high-performance local Policy Decision Point (PDP), ensuring that gate evaluations have minimal latency and are not dependent on the uptime of a central cloud service. Adopting a "policy-as-code" approach through Permit.io's GitOps integration would also improve auditability, version control, and developer-led governance. This PoC aims to prove that this modern stack can meet Banamex's immediate security gating needs while providing a scalable foundation for future requirements.

---

### **3\. PoC Objectives & Success Criteria**

#### **3.1. Objectives**

The primary objectives of this Proof of Concept are:

1. **Validate Data Integration:** Demonstrate that vulnerability data from Snyk can be successfully fetched and loaded into the Permit.io policy engine for evaluation. This involves creating a custom data fetcher as identified in the technical analysis.  
2. **Demonstrate Policy Enforcement:** Prove that policies defined in Permit.io can correctly evaluate the Snyk data and return a clear, actionable decision (e.g., PASS, FAIL, WARN).  
3. **Validate CI/CD Integration:** Show that a GitHub Actions pipeline can act as a Policy Enforcement Point (PEP), successfully calling the Permit.io PDP, interpreting its decision, and halting or proceeding with the build accordingly.  
4. **Differentiate Gate Strengths:** Implement both a "hard gate" (FAIL) and a "soft gate" (WARN) to prove the platform can support both enforcing and non-enforcing policies as required.

#### **3.2. Success Criteria**

The PoC will be deemed successful if the following criteria are met:

* A GitHub Actions pipeline build **fails** when the Snyk scan data contains vulnerabilities that violate the defined "hard gate" policy in Permit.io.  
* A GitHub Actions pipeline build **passes (with a warning)** when the Snyk scan data contains vulnerabilities that violate a "soft gate" policy.  
* The decision logic for the gates is managed entirely within the Permit.io platform (via its UI or policy-as-code in Git) and is not hard-coded in the GitHub Actions workflow script.  
* The GitHub Actions logs clearly display the outcome of the gate check, including the reason for any failure or warning, based on the detailed response from Permit.io.

---

### **4\. Functional Requirements**

The following requirements are scoped for this PoC to validate the platform's core capabilities.

| Req ID | Requirement Description | Category | Priority | Notes |
| :---- | :---- | :---- | :---- | :---- |
| **FR-POC-001** | The platform must evaluate Snyk security scan results for Critical, High, and Medium vulnerabilities based on their CVSS score. | Gate Evaluation | Critical | This requires a custom OPAL data fetcher to be developed to pull data from the Snyk API and load it into the Permit.io PDP. Coverage is **Partial** out-of-the-box due to this custom development need. |
| **FR-POC-002** | The platform must support both hard gates (ENFORCING) that fail a pipeline and soft gates (NON\_ENFORCING) that issue a warning but allow the pipeline to continue. | Gate Evaluation | Critical | This is **Fully Supported**. The Permit.io policy engine can return a detailed JSON object indicating a "FAIL" or "WARNING" status, which the CI/CD script can then interpret. |
| **FR-POC-003** | The API response for a gate evaluation must include an overall result (e.g., FAIL) and detailed findings that explain the reason for the decision222222222.  | Gate Evaluation | High | This is **Fully Supported**. A custom Rego policy can be authored to construct a detailed JSON response object containing all necessary details. |
| **FR-POC-004** | The gating service must be directly invocable from a GitHub Actions pipeline script. | Integration | Critical | This is **Fully Supported**. Permit.io provides SDKs and a REST API designed for this exact use case, where the GitHub Action is the client calling the PDP. |
| **FR-POC-005** | The platform must provide a mechanism for authorized users to define, view, and modify policies (rules). | Rule Management | High | This is **Fully Supported** through Permit.io's web UI, REST API, and GitOps integration. The PoC should validate the UI-based approach for simplicity. |
| **FR-POC-006** | The system must support a Maker-Checker workflow for rule changes to ensure proper governance3.  | Rule Management | Medium | This has **Partial** support. While Permit.io lacks a native maker-checker feature in its UI, this workflow can be implemented using the GitOps feature, where pull requests serve as the review and approval mechanism. This can be documented as the recommended approach post-PoC. |
| **FR-POC-007** | The platform must be able to query an external system (like Jira) for approved exceptions before failing a hard gate. | Exception Mgt. | Medium | This has **Partial** support and is likely **out of scope for the initial PoC**. It requires a custom data fetcher to be built to query the Jira API. The PoC should focus on the gating mechanism first, with this as a documented next step. |

---

### **5\. Non-Functional Requirements**

| Req ID | Requirement Description | Category | Priority | Notes |
| :---- | :---- | :---- | :---- | :---- |
| **NFR-POC-001** | Gate evaluation decisions must have low latency to avoid significantly slowing down CI/CD pipelines4.  | Performance | High | This is **Fully Supported**. The Permit.io PDP is a local microservice designed for sub-millisecond response times. |
| **NFR-POC-002** | The platform architecture must support horizontal scaling to handle future increases in build volumes5.  | Scalability | High | This is **Fully Supported**. The PDP is a stateless microservice that can be easily replicated to handle higher loads. |
| **NFR-POC-003** | The platform must provide Role-Based Access Control (RBAC) to manage who can define and modify policies6.  | Security | High | This is **Fully Supported** for controlling access to the Permit.io management dashboard and workspaces. |
| **NFR-POC-004** | All communication must be encrypted using TLS7.  | Security | Critical | This is **Fully Supported** for all communications between the client, the PDP, and the Permit.io cloud service. |

---

### **6\. Scope of Proof of Concept**

#### **6.1. In-Scope**

* **Mock Application:** A simple Spring Boot microservice application will be created to serve as the code base for the PoC.  
  * It will act as the source repository to trigger the GitHub Actions workflow.  
  * It will be a Java-based Spring Boot application to simulate a realistic development environment8888.
  * It will be containerized using Docker for consistent deployment across environments.
  * Docker Compose will orchestrate the local development environment, including the application and all required services.
  * It will contain a Maven (pom.xml) dependency file.  
  * It will intentionally include known vulnerable dependencies (e.g., an outdated version of  
    commons-collections or log4j) to test the 'FAIL' and 'WARN' gate scenarios999999999.

* **CI/CD and Gating:**  
  * Configuration of a single GitHub repository with a GitHub Actions pipeline.  
  * Development of one custom OPAL data fetcher to pull vulnerability data from the Snyk API.  
  * Setup of a Permit.io project with policies defined in the web UI.  
  * Implementation of one **hard gate** based on Snyk "Critical" vulnerabilities.  
  * Implementation of one **soft gate** based on Snyk "High" vulnerabilities.  
  * Demonstration of the pipeline failing on the hard gate and warning on the soft gate.

#### **6.2. Out-of-Scope**

* Migration of all existing gates from the GATR platform10.

* Integration with other data sources mentioned in the GATR documentation, such as SonarQube, BlackDuck, Jira, or Architecture Center11.

* The development of a reporting dashboard12. The PoC will rely on pipeline logs for results.

* A full implementation of the GitOps-based maker-checker workflow.  
* The implementation of the Jira integration for exception handling.

#### **6.3. Infrastructure Setup with Docker Compose**

The PoC will leverage Docker Compose to simplify the local development environment and ensure consistency across different deployment scenarios. This containerized approach provides:

##### **Docker Compose Services**

The PoC infrastructure will consist of the following containerized services:

* **Permit.io PDP (Policy Decision Point):**
  * Container image: `permitio/pdp-v2:latest`
  * API endpoint on port 7766 for policy decision requests
  * Health endpoint on port 7001 for status checks
  * Environment variables:
    * `PDP_API_KEY`: API key for connecting to Permit.io cloud
    * `PDP_DEBUG`: Set to `true` for verbose logging during development
  * Health check endpoint: `/healthy` on port 7001

* **Spring Boot Mock Application:**
  * Custom Docker image built from the PoC application
  * Exposed on port 8080
  * Environment variables for Snyk integration:
    * `SNYK_TOKEN`: API token for Snyk vulnerability scanning
    * `SNYK_ORG_ID`: Organization ID in Snyk
  * Volume mount for application logs: `./logs:/app/logs`

* **OPAL Server (Optional for advanced scenarios):**
  * Container image: `permitio/opal-server:latest`
  * Required only if implementing custom data fetchers
  * Port 7002 for OPAL API
  * Environment configuration for Snyk data fetcher integration

##### **Docker Compose Configuration**

```yaml
version: '3.8'

services:
  permit-pdp:
    image: permitio/pdp-v2:latest
    ports:
      - "7766:7766"
    environment:
      - PDP_API_KEY=${PERMIT_API_KEY}
      - PDP_DEBUG=true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7001/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - gating-network

  spring-app:
    build:
      context: ./microservice-moc-app
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - SNYK_TOKEN=${SNYK_TOKEN}
      - SNYK_ORG_ID=${SNYK_ORG_ID}
      - PDP_URL=http://permit-pdp:7766
    depends_on:
      permit-pdp:
        condition: service_healthy
    volumes:
      - ./logs:/app/logs
    networks:
      - gating-network

networks:
  gating-network:
    driver: bridge
```

##### **Local Development Workflow**

1. **Environment Setup:**
   * Create a `.env` file with required API keys and tokens
   * Ensure Docker and Docker Compose are installed (minimum Docker 20.10.0)

2. **Starting the Environment:**
   ```bash
   docker-compose up -d
   ```

3. **Verifying Services:**
   ```bash
   # Check PDP health
   curl http://localhost:7001/healthy
   
   # Check Spring Boot app
   curl http://localhost:8080/actuator/health
   ```

4. **Running Gate Checks:**
   * The GitHub Actions workflow will interact with the containerized PDP
   * Local testing can be performed using the Permit.io SDK or REST API calls

##### **CI/CD Integration**

The GitHub Actions workflow will utilize Docker Compose for consistent gate evaluation:

```yaml
- name: Start Gating Infrastructure
  run: docker-compose up -d
  
- name: Wait for Services
  run: |
    until curl -f http://localhost:7001/healthy; do
      sleep 2
    done
    
- name: Run Gate Evaluation
  run: |
    # Gate evaluation logic using the PDP endpoint
    ./scripts/evaluate-gates.sh
```

##### **Benefits of Docker Compose Approach**

* **Consistency:** Same environment across local development, CI/CD, and production
* **Isolation:** Each service runs in its own container with defined boundaries
* **Scalability:** Easy to add additional PDPs for load balancing
* **Portability:** Can be deployed to any Docker-compatible platform
* **Version Control:** Infrastructure configuration is stored as code alongside the application

---

### **7\. Stakeholders**

The key stakeholders for this PoC are aligned with the GATR replacement project13:

* **Project Sponsor:** Zavala, Werner Alexander (Engineering & Automation)  
* **DevSecOps Lead:** Barcenas, Martin (Engineering & Automation \- DevSecOps)  
* **Tooling Services Lead:** Cruz, Alfredo (Engineering & Automation \- DevSecOps)  
* **Safety and Soundness Lead:** Kuri Parra, Ricardo (Safety and Soundness)  
* **Business Owner:** Corona, Guillermo (Safety and Soundness)  
* **Product Owner:** Santander, David (Engineering & Automation \- DevSecOps)  
* **Additional Stakeholders:** Murillo Serrato, Sonia; Soto, Flor Ivett; Flores, Ricardo1; Avina, Monica