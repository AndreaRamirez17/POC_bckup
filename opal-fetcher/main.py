"""
Custom OPAL Data Fetcher for Snyk Integration
This fetcher pulls vulnerability data from Snyk API and formats it for Permit.io policy evaluation
"""

import os
import logging
import requests
from typing import Dict, List, Any, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
import json

# Configure logging
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

app = FastAPI(title="Snyk Data Fetcher for OPAL", version="1.0.0")

# Environment variables
SNYK_TOKEN = os.getenv("SNYK_TOKEN")
SNYK_ORG_ID = os.getenv("SNYK_ORG_ID")
SNYK_PROJECT_ID = os.getenv("SNYK_PROJECT_ID")
SNYK_API_BASE = "https://api.snyk.io/v1"

class VulnerabilityData(BaseModel):
    """Model for vulnerability data"""
    id: str
    title: str
    severity: str
    cvssScore: Optional[float]
    packageName: str
    version: str
    exploitMaturity: Optional[str]
    publicationTime: Optional[str]

class SnykFetcherResponse(BaseModel):
    """Response model for the fetcher"""
    timestamp: str
    projectId: str
    vulnerabilities: Dict[str, List[VulnerabilityData]]
    summary: Dict[str, int]

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/snyk")
async def fetch_snyk_data() -> Dict[str, Any]:
    """
    Fetch vulnerability data from Snyk API and format for OPAL/Permit.io
    Returns data categorized by severity levels
    """
    if not all([SNYK_TOKEN, SNYK_ORG_ID]):
        logger.error("Missing Snyk configuration")
        raise HTTPException(status_code=500, detail="Snyk configuration missing")
    
    try:
        # Headers for Snyk API
        headers = {
            "Authorization": f"token {SNYK_TOKEN}",
            "Content-Type": "application/json"
        }
        
        # If no specific project ID, get all projects
        if not SNYK_PROJECT_ID:
            projects_url = f"{SNYK_API_BASE}/org/{SNYK_ORG_ID}/projects"
            projects_response = requests.get(projects_url, headers=headers)
            projects_response.raise_for_status()
            projects = projects_response.json().get("projects", [])
            
            # Find our mock app project
            project_id = None
            for project in projects:
                if "gating-poc" in project.get("name", "").lower():
                    project_id = project["id"]
                    break
            
            if not project_id and projects:
                project_id = projects[0]["id"]  # Use first project as fallback
        else:
            project_id = SNYK_PROJECT_ID
        
        if not project_id:
            logger.warning("No Snyk project found, returning mock data")
            return generate_mock_data()
        
        # Fetch issues for the project
        issues_url = f"{SNYK_API_BASE}/org/{SNYK_ORG_ID}/project/{project_id}/issues"
        response = requests.post(
            issues_url,
            headers=headers,
            json={
                "filters": {
                    "severities": ["critical", "high", "medium", "low"],
                    "types": ["vuln"],
                    "ignored": False
                }
            }
        )
        response.raise_for_status()
        
        issues_data = response.json()
        
        # Process and categorize vulnerabilities
        vulnerabilities = {
            "critical": [],
            "high": [],
            "medium": [],
            "low": []
        }
        
        for issue in issues_data.get("issues", {}).get("vulnerabilities", []):
            severity = issue.get("severity", "unknown").lower()
            if severity in vulnerabilities:
                vuln = {
                    "id": issue.get("id"),
                    "title": issue.get("title"),
                    "severity": severity,
                    "cvssScore": issue.get("cvssScore"),
                    "packageName": issue.get("package"),
                    "version": issue.get("version"),
                    "exploitMaturity": issue.get("exploitMaturity"),
                    "publicationTime": issue.get("publicationTime")
                }
                vulnerabilities[severity].append(vuln)
        
        # Create summary
        summary = {
            "critical": len(vulnerabilities["critical"]),
            "high": len(vulnerabilities["high"]),
            "medium": len(vulnerabilities["medium"]),
            "low": len(vulnerabilities["low"]),
            "total": sum(len(v) for v in vulnerabilities.values())
        }
        
        # Format response for OPAL/Permit.io
        response_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "projectId": project_id,
            "vulnerabilities": vulnerabilities,
            "summary": summary,
            "gatingDecision": {
                "hardGate": len(vulnerabilities["critical"]) > 0,
                "softGate": len(vulnerabilities["high"]) > 0,
                "warnings": len(vulnerabilities["medium"]) > 0
            }
        }
        
        logger.info(f"Successfully fetched Snyk data: {summary}")
        return response_data
        
    except requests.RequestException as e:
        logger.error(f"Error fetching Snyk data: {str(e)}")
        # Return mock data on error for PoC
        return generate_mock_data()
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

def generate_mock_data() -> Dict[str, Any]:
    """
    Generate mock vulnerability data for testing when Snyk API is not available
    This simulates the vulnerable dependencies in our pom.xml
    """
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "projectId": "mock-project-id",
        "vulnerabilities": {
            "critical": [
                {
                    "id": "SNYK-JAVA-ORGAPACHELOGGINGLOG4J-2314720",
                    "title": "Remote Code Execution (RCE)",
                    "severity": "critical",
                    "cvssScore": 10.0,
                    "packageName": "org.apache.logging.log4j:log4j-core",
                    "version": "2.14.1",
                    "exploitMaturity": "mature",
                    "publicationTime": "2021-12-10T00:00:00Z",
                    "cve": "CVE-2021-44228"
                }
            ],
            "high": [
                {
                    "id": "SNYK-JAVA-COMMONSCOLLECTIONS-30078",
                    "title": "Deserialization of Untrusted Data",
                    "severity": "high",
                    "cvssScore": 7.5,
                    "packageName": "commons-collections:commons-collections",
                    "version": "3.2.1",
                    "exploitMaturity": "proof-of-concept",
                    "publicationTime": "2015-11-18T00:00:00Z",
                    "cve": "CVE-2015-6420"
                }
            ],
            "medium": [
                {
                    "id": "SNYK-JAVA-COMFASTERXMLJACKSONCORE-72448",
                    "title": "Deserialization of Untrusted Data",
                    "severity": "medium",
                    "cvssScore": 5.9,
                    "packageName": "com.fasterxml.jackson.core:jackson-databind",
                    "version": "2.9.10.1",
                    "exploitMaturity": "no-known-exploit",
                    "publicationTime": "2019-10-01T00:00:00Z"
                }
            ],
            "low": []
        },
        "summary": {
            "critical": 1,
            "high": 1,
            "medium": 1,
            "low": 0,
            "total": 3
        },
        "gatingDecision": {
            "hardGate": True,  # Critical vulnerabilities present
            "softGate": True,   # High vulnerabilities present
            "warnings": True    # Medium vulnerabilities present
        }
    }

@app.get("/fetch-and-format")
async def fetch_and_format_for_permit():
    """
    Fetch Snyk data and format specifically for Permit.io policy evaluation
    """
    snyk_data = await fetch_snyk_data()
    
    # Format for Permit.io resource attributes
    permit_format = {
        "resource": {
            "type": "deployment",
            "id": snyk_data.get("projectId"),
            "attributes": {
                "vulnerabilities": snyk_data.get("vulnerabilities"),
                "summary": snyk_data.get("summary"),
                "scanTimestamp": snyk_data.get("timestamp"),
                "criticalCount": snyk_data.get("summary", {}).get("critical", 0),
                "highCount": snyk_data.get("summary", {}).get("high", 0),
                "mediumCount": snyk_data.get("summary", {}).get("medium", 0)
            }
        },
        "gatingDecision": snyk_data.get("gatingDecision")
    }
    
    return permit_format

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)