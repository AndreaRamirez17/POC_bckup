#!/bin/bash

# SonarQube Cloud Local Testing Script
# This script helps test SonarQube Cloud integration locally before committing

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Source .env file if it exists and environment variables are not already set
if [ -f ".env" ] && [ -z "$SONAR_TOKEN" ]; then
    echo "Loading environment variables from .env file..."
    source .env
    echo ""
fi

echo "========================================="
echo "    SonarQube Cloud Local Test"
echo "========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "microservice-moc-app/pom.xml" ]; then
    echo -e "${RED}Error: Not in project root directory${NC}"
    echo "Please run this script from the project root"
    exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    local prereq_met=true
    
    # Check Java
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ Java installed${NC}"
    else
        echo -e "${RED}✗ Java not installed${NC}"
        prereq_met=false
    fi
    
    # Check Maven
    if command -v mvn &> /dev/null; then
        MVN_VERSION=$(mvn -version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ Maven installed${NC}"
    else
        echo -e "${RED}✗ Maven not installed${NC}"
        prereq_met=false
    fi
    
    # Check environment variables
    if [ -z "$SONAR_TOKEN" ]; then
        echo -e "${RED}✗ SONAR_TOKEN not set${NC}"
        prereq_met=false
    else
        echo -e "${GREEN}✓ SONAR_TOKEN is set${NC}"
    fi
    
    if [ -z "$SONAR_ORGANIZATION" ]; then
        echo -e "${YELLOW}⚠ SONAR_ORGANIZATION not set (will use default from config)${NC}"
    else
        echo -e "${GREEN}✓ SONAR_ORGANIZATION is set: $SONAR_ORGANIZATION${NC}"
    fi
    
    if [ "$prereq_met" = false ]; then
        echo ""
        echo -e "${RED}Prerequisites not met. Please install missing tools and set environment variables.${NC}"
        exit 1
    fi
    
    echo ""
}

# Function to build the project
build_project() {
    echo -e "${BLUE}Building Maven project...${NC}"
    cd microservice-moc-app
    
    # Clean and compile
    echo "Running: mvn clean compile"
    mvn clean compile -q
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Build successful${NC}"
    else
        echo -e "${RED}✗ Build failed${NC}"
        exit 1
    fi
    
    echo ""
}

# Function to run tests with coverage
run_tests() {
    echo -e "${BLUE}Running tests with coverage...${NC}"
    
    # Check if JaCoCo is configured
    if ! grep -q "jacoco-maven-plugin" pom.xml; then
        echo -e "${YELLOW}⚠ JaCoCo plugin not configured - coverage will not be available${NC}"
        echo "  Consider adding JaCoCo plugin to your pom.xml for coverage reports"
    fi
    
    # Run tests
    echo "Running: mvn test"
    mvn test -q
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Tests completed${NC}"
        
        # Check if coverage report was generated
        if [ -f "target/site/jacoco/jacoco.xml" ]; then
            echo -e "${GREEN}✓ Coverage report generated${NC}"
        else
            echo -e "${YELLOW}⚠ No coverage report found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Some tests failed (continuing anyway)${NC}"
    fi
    
    echo ""
}

# Function to run SonarQube analysis
run_sonarqube_analysis() {
    echo -e "${BLUE}Running SonarQube Cloud analysis...${NC}"
    echo ""
    
    # Set organization if provided
    SONAR_OPTS=""
    if [ -n "$SONAR_ORGANIZATION" ]; then
        SONAR_OPTS="-Dsonar.organization=$SONAR_ORGANIZATION"
    fi
    
    # Set project key if provided
    if [ -n "$SONAR_PROJECT_KEY" ]; then
        SONAR_OPTS="$SONAR_OPTS -Dsonar.projectKey=$SONAR_PROJECT_KEY"
    else
        SONAR_OPTS="$SONAR_OPTS -Dsonar.projectKey=cicd-pipeline-poc"
    fi
    
    # Run SonarQube analysis
    echo "Running: mvn sonar:sonar -Dsonar.host.url=https://sonarcloud.io $SONAR_OPTS"
    echo ""
    
    mvn sonar:sonar \
        -Dsonar.host.url=https://sonarcloud.io \
        -Dsonar.token=$SONAR_TOKEN \
        $SONAR_OPTS \
        -Dsonar.projectName="CI/CD Pipeline Security POC" \
        -Dsonar.projectVersion=1.0.0 \
        -Dsonar.sources=src/main/java \
        -Dsonar.tests=src/test/java \
        -Dsonar.java.binaries=target/classes \
        -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ SonarQube analysis completed successfully${NC}"
        
        # Extract the dashboard URL from the output
        echo ""
        echo -e "${MAGENTA}View results at:${NC}"
        echo "https://sonarcloud.io/dashboard?id=${SONAR_PROJECT_KEY:-cicd-pipeline-poc}"
    else
        echo ""
        echo -e "${RED}✗ SonarQube analysis failed${NC}"
        exit 1
    fi
    
    cd ..
    echo ""
}

# Function to check quality gate
check_quality_gate() {
    echo -e "${BLUE}Checking quality gate status...${NC}"
    
    # Wait a moment for the analysis to be processed
    echo "Waiting for analysis to be processed..."
    sleep 10
    
    # Run quality gate check
    ./sonarqube-cloud-scanning/scripts/analyze-quality-gates.sh \
        -k "${SONAR_PROJECT_KEY:-cicd-pipeline-poc}" \
        -o sonarqube-cloud-scanning/results/quality-gate-result.json
    
    GATE_STATUS=$?
    
    echo ""
    case $GATE_STATUS in
        0)
            echo -e "${GREEN}✓ Quality gate PASSED${NC}"
            ;;
        1)
            echo -e "${YELLOW}⚠ Quality gate has WARNINGS${NC}"
            ;;
        2)
            echo -e "${RED}✗ Quality gate FAILED${NC}"
            ;;
        *)
            echo -e "${YELLOW}? Unable to determine quality gate status${NC}"
            ;;
    esac
    
    # Display results file location
    if [ -f "sonarqube-cloud-scanning/results/quality-gate-result.json" ]; then
        echo ""
        echo "Detailed results saved to: sonarqube-cloud-scanning/results/quality-gate-result.json"
    fi
}

# Function to generate summary
generate_summary() {
    echo ""
    echo "========================================="
    echo "           Test Summary"
    echo "========================================="
    echo ""
    echo -e "${GREEN}Local SonarQube Cloud test completed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the analysis results in SonarQube Cloud dashboard"
    echo "2. Fix any issues identified by the quality gate"
    echo "3. Commit your changes and push to trigger the CI/CD pipeline"
    echo ""
    echo "Dashboard URL:"
    echo "https://sonarcloud.io/dashboard?id=${SONAR_PROJECT_KEY:-cicd-pipeline-poc}"
    echo ""
    echo "To run this test again:"
    echo "  ./sonarqube-cloud-scanning/scripts/test-sonarqube-local.sh"
}

# Main execution flow
main() {
    # Check prerequisites
    check_prerequisites
    
    # Validate SonarQube configuration
    echo -e "${BLUE}Validating SonarQube configuration...${NC}"
    ./sonarqube-cloud-scanning/scripts/validate-sonarqube.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Configuration validation failed. Please fix the issues above.${NC}"
        exit 1
    fi
    echo ""
    
    # Build project
    build_project
    
    # Run tests
    run_tests
    
    # Run SonarQube analysis
    run_sonarqube_analysis
    
    # Check quality gate
    check_quality_gate
    
    # Generate summary
    generate_summary
}

# Run main function
main