#!/bin/bash

# SonarQube Cloud Configuration Validation Script
# This script validates that SonarQube Cloud is properly configured
# and all required environment variables are set

set -e

# Source .env file if it exists and environment variables are not already set
if [ -f ".env" ] && [ -z "$SONAR_TOKEN" ]; then
    echo "Loading environment variables from .env file..."
    source .env
    echo ""
fi

echo "========================================="
echo "  SonarQube Cloud Configuration Check"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation status
VALIDATION_PASSED=true

# Function to check if a variable is set
check_variable() {
    local var_name=$1
    local var_value=$2
    local is_required=$3
    
    if [ -z "$var_value" ]; then
        if [ "$is_required" = "true" ]; then
            echo -e "${RED}✗ $var_name is not set (REQUIRED)${NC}"
            VALIDATION_PASSED=false
        else
            echo -e "${YELLOW}⚠ $var_name is not set (OPTIONAL)${NC}"
        fi
        return 1
    else
        # Mask sensitive values in output
        if [[ "$var_name" == *"TOKEN"* ]] || [[ "$var_name" == *"KEY"* ]]; then
            echo -e "${GREEN}✓ $var_name is set [***hidden***]${NC}"
        else
            echo -e "${GREEN}✓ $var_name is set: $var_value${NC}"
        fi
        return 0
    fi
}

# Function to test SonarQube Cloud API connectivity
test_sonarcloud_api() {
    echo ""
    echo "Testing SonarQube Cloud API connectivity..."
    
    if [ -z "$SONAR_TOKEN" ]; then
        echo -e "${RED}✗ Cannot test API - SONAR_TOKEN not set${NC}"
        return 1
    fi
    
    # Test connection to SonarQube Cloud API
    API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "$SONAR_TOKEN:" \
        "https://sonarcloud.io/api/authentication/validate" 2>/dev/null || echo "000")
    
    if [ "$API_RESPONSE" = "200" ]; then
        echo -e "${GREEN}✓ Successfully connected to SonarQube Cloud API${NC}"
        
        # Get user information
        USER_INFO=$(curl -s -u "$SONAR_TOKEN:" \
            "https://sonarcloud.io/api/users/current" 2>/dev/null || echo "{}")
        
        USER_LOGIN=$(echo "$USER_INFO" | grep -o '"login":"[^"]*' | cut -d'"' -f4 || echo "unknown")
        USER_NAME=$(echo "$USER_INFO" | grep -o '"name":"[^"]*' | cut -d'"' -f4 || echo "unknown")
        
        if [ "$USER_LOGIN" != "unknown" ]; then
            echo -e "${GREEN}  Authenticated as: $USER_NAME ($USER_LOGIN)${NC}"
        fi
        
        return 0
    elif [ "$API_RESPONSE" = "401" ]; then
        echo -e "${RED}✗ Authentication failed - Invalid SONAR_TOKEN${NC}"
        VALIDATION_PASSED=false
        return 1
    elif [ "$API_RESPONSE" = "000" ]; then
        echo -e "${RED}✗ Cannot connect to SonarQube Cloud - Network error${NC}"
        VALIDATION_PASSED=false
        return 1
    else
        echo -e "${YELLOW}⚠ Unexpected response from SonarQube Cloud API (HTTP $API_RESPONSE)${NC}"
        return 1
    fi
}

# Function to validate organization exists
validate_organization() {
    echo ""
    echo "Validating SonarQube Cloud organization..."
    
    if [ -z "$SONAR_TOKEN" ] || [ -z "$SONAR_ORGANIZATION" ]; then
        echo -e "${YELLOW}⚠ Cannot validate organization - missing credentials${NC}"
        return 1
    fi
    
    # Check if organization exists and user has access
    ORG_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "$SONAR_TOKEN:" \
        "https://sonarcloud.io/api/organizations/search?organizations=$SONAR_ORGANIZATION" 2>/dev/null || echo "000")
    
    if [ "$ORG_RESPONSE" = "200" ]; then
        echo -e "${GREEN}✓ Organization '$SONAR_ORGANIZATION' is accessible${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Cannot verify organization '$SONAR_ORGANIZATION' (HTTP $ORG_RESPONSE)${NC}"
        echo "  Please ensure the organization key is correct and you have access"
        return 1
    fi
}

# Function to check project configuration
check_project_config() {
    echo ""
    echo "Checking project configuration..."
    
    # Check if sonar-project.properties exists
    CONFIG_FILE="sonarqube-cloud-scanning/config/sonar-project.properties"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓ Configuration file exists: $CONFIG_FILE${NC}"
        
        # Extract key configuration from properties file
        if [ -f "$CONFIG_FILE" ]; then
            PROJECT_KEY=$(grep "^sonar.projectKey=" "$CONFIG_FILE" | cut -d'=' -f2 || echo "")
            PROJECT_NAME=$(grep "^sonar.projectName=" "$CONFIG_FILE" | cut -d'=' -f2 || echo "")
            
            if [ -n "$PROJECT_KEY" ]; then
                echo -e "${GREEN}  Project Key: $PROJECT_KEY${NC}"
            fi
            if [ -n "$PROJECT_NAME" ]; then
                echo -e "${GREEN}  Project Name: $PROJECT_NAME${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Configuration file not found: $CONFIG_FILE${NC}"
        echo "  This file will be needed for Maven-based analysis"
    fi
    
    # Check if we're in a Maven project
    if [ -f "microservice-moc-app/pom.xml" ]; then
        echo -e "${GREEN}✓ Maven project detected (pom.xml found)${NC}"
        
        # Check if SonarQube plugin is configured
        if grep -q "sonar-maven-plugin" "microservice-moc-app/pom.xml" 2>/dev/null; then
            echo -e "${GREEN}✓ SonarQube Maven plugin is configured${NC}"
        else
            echo -e "${YELLOW}⚠ SonarQube Maven plugin not found in pom.xml${NC}"
            echo "  You may need to add the plugin configuration"
        fi
    fi
}

# Function to check Java and Maven installation
check_build_tools() {
    echo ""
    echo "Checking build tools..."
    
    # Check Java
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
        echo -e "${GREEN}✓ Java installed: $JAVA_VERSION${NC}"
    else
        echo -e "${YELLOW}⚠ Java not found - required for local analysis${NC}"
    fi
    
    # Check Maven
    if command -v mvn &> /dev/null; then
        MVN_VERSION=$(mvn -version 2>&1 | head -n 1 | awk '{print $3}')
        echo -e "${GREEN}✓ Maven installed: $MVN_VERSION${NC}"
    else
        echo -e "${YELLOW}⚠ Maven not found - required for local analysis${NC}"
    fi
}

# Main validation flow
echo "1. Checking Required Environment Variables"
echo "==========================================="
check_variable "SONAR_TOKEN" "$SONAR_TOKEN" "true"
check_variable "SONAR_ORGANIZATION" "$SONAR_ORGANIZATION" "true"
check_variable "SONAR_PROJECT_KEY" "$SONAR_PROJECT_KEY" "false"

echo ""
echo "2. Checking Optional Environment Variables"
echo "==========================================="
check_variable "SONAR_HOST_URL" "$SONAR_HOST_URL" "false" || true
check_variable "SONAR_QUALITY_GATE" "$SONAR_QUALITY_GATE" "false" || true

# Test API connectivity
echo ""
echo "3. API Connectivity Test"
echo "==========================================="
test_sonarcloud_api

# Validate organization
echo ""
echo "4. Organization Validation"
echo "==========================================="
validate_organization

# Check project configuration
echo ""
echo "5. Project Configuration"
echo "==========================================="
check_project_config

# Check build tools
echo ""
echo "6. Build Tools Check"
echo "==========================================="
check_build_tools

# Summary
echo ""
echo "========================================="
echo "           Validation Summary"
echo "========================================="

if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}✓ SonarQube Cloud validation PASSED${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Ensure your project is configured in SonarQube Cloud"
    echo "2. Update sonar-project.properties with your organization and project keys"
    echo "3. Configure the SonarQube Maven plugin in your pom.xml"
    echo "4. Run the analysis using: mvn sonar:sonar"
    exit 0
else
    echo -e "${RED}✗ SonarQube Cloud validation FAILED${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    echo ""
    echo "Required actions:"
    echo "1. Set SONAR_TOKEN environment variable with your SonarQube Cloud token"
    echo "2. Set SONAR_ORGANIZATION environment variable with your organization key"
    echo "3. Ensure you have access to SonarQube Cloud (https://sonarcloud.io)"
    exit 1
fi