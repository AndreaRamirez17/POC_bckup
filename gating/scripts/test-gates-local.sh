#!/bin/bash

# Local testing script for security gates
# This script helps test the gate evaluation locally without GitHub Actions

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check for required tools
check_requirements() {
    print_color "$BLUE" "Checking requirements..."
    
    local missing_tools=()
    
    for tool in docker docker-compose jq curl mvn; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_color "$RED" "Error: Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    print_color "$GREEN" "✓ All required tools are installed"
}

# Check for .env file
check_env_file() {
    if [ ! -f .env ]; then
        print_color "$YELLOW" "Warning: .env file not found"
        echo "Creating .env file from template..."
        
        if [ -f .env.example ]; then
            cp .env.example .env
            print_color "$YELLOW" "Please edit .env file with your API keys:"
            echo "  - PERMIT_API_KEY: Get from https://app.permit.io"
            echo "  - SNYK_TOKEN: Get from https://app.snyk.io/account"
            echo "  - SNYK_ORG_ID: Your Snyk organization ID"
            exit 1
        else
            print_color "$RED" "Error: .env.example file not found"
            exit 1
        fi
    fi
    
    # Source .env file
    set -a
    source .env
    set +a
    
    # Check for required variables
    if [ -z "$PERMIT_API_KEY" ] || [ "$PERMIT_API_KEY" = "your_permit_api_key_here" ]; then
        print_color "$RED" "Error: PERMIT_API_KEY not configured in .env file"
        exit 1
    fi
    
    print_color "$GREEN" "✓ Environment variables loaded"
}

# Build the Spring Boot application
build_application() {
    print_color "$BLUE" "Building Spring Boot application..."
    
    cd microservice-moc-app
    mvn clean package -DskipTests
    cd ..
    
    print_color "$GREEN" "✓ Application built successfully"
}

# Start Docker Compose services
start_services() {
    print_color "$BLUE" "Starting Docker Compose services..."
    
    docker-compose down 2>/dev/null || true
    docker-compose up -d --build
    
    # Wait for services to be ready
    print_color "$YELLOW" "Waiting for services to start..."
    sleep 15
    
    # Check service health
    local services=("permit-pdp:7766" "spring-app:7777" "opal-fetcher:8000")
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        if curl -sf "http://localhost:$port/health" > /dev/null 2>&1 || \
           curl -sf "http://localhost:$port/healthy" > /dev/null 2>&1 || \
           curl -sf "http://localhost:$port/actuator/health" > /dev/null 2>&1; then
            print_color "$GREEN" "✓ $name is ready"
        else
            print_color "$YELLOW" "⚠ $name might not be fully ready"
        fi
    done
}

# Run Snyk scan
run_snyk_scan() {
    print_color "$BLUE" "Running Snyk security scan..."
    
    # Install Snyk if not present
    if ! command -v snyk &> /dev/null; then
        print_color "$YELLOW" "Installing Snyk CLI..."
        npm install -g snyk
    fi
    
    # Authenticate with Snyk if token is available
    if [ -n "$SNYK_TOKEN" ] && [ "$SNYK_TOKEN" != "your_snyk_token_here" ]; then
        snyk auth "$SNYK_TOKEN" 2>/dev/null || true
    fi
    
    # Run real Snyk scan (no mock data fallback)
    cd microservice-moc-app
    if [ -z "$SNYK_TOKEN" ] || [ "$SNYK_TOKEN" = "your_snyk_token_here" ]; then
        print_color "$RED" "Error: SNYK_TOKEN not configured. Real vulnerability scanning required."
        print_color "$RED" "Please set SNYK_TOKEN in .env file to use real Snyk scanning."
        exit 1
    fi
    
    snyk test --json > ../snyk-results.json 2>/dev/null || {
        print_color "$YELLOW" "Snyk scan completed with vulnerabilities found (exit code ignored)"
    }
    cd ..
    
    print_color "$GREEN" "✓ Snyk scan completed"
}

# Test gate evaluation
test_gates() {
    print_color "$BLUE" "Testing security gate evaluation..."
    echo ""
    
    # Make the script executable
    chmod +x gating/scripts/evaluate-gates.sh
    
    # Run gate evaluation
    ./gating/scripts/evaluate-gates.sh snyk-results.json
    local exit_code=$?
    
    echo ""
    case $exit_code in
        0)
            print_color "$GREEN" "Test Result: All gates passed (exit code: 0)"
            ;;
        1)
            print_color "$YELLOW" "Test Result: Soft gate warnings (exit code: 1)"
            ;;
        2)
            print_color "$RED" "Test Result: Hard gate failure (exit code: 2)"
            ;;
        *)
            print_color "$RED" "Test Result: Unexpected exit code: $exit_code"
            ;;
    esac
    
    return $exit_code
}

# View logs
view_logs() {
    print_color "$BLUE" "Service Logs (last 20 lines each):"
    echo ""
    
    for service in permit-pdp spring-app opal-fetcher redis; do
        if docker-compose ps | grep -q $service; then
            print_color "$YELLOW" "=== $service ==="
            docker-compose logs --tail=20 $service 2>/dev/null || echo "No logs available"
            echo ""
        fi
    done
}

# Cleanup
cleanup() {
    print_color "$BLUE" "Cleaning up..."
    docker-compose down
    print_color "$GREEN" "✓ Services stopped"
}

# Main menu
show_menu() {
    echo ""
    print_color "$BLUE" "════════════════════════════════════════════════════════════════"
    print_color "$BLUE" "           CI/CD Security Gating PoC - Local Testing"
    print_color "$BLUE" "════════════════════════════════════════════════════════════════"
    echo ""
    echo "1) Run full test (build, scan, evaluate gates)"
    echo "2) Start services only"
    echo "3) Run Snyk scan only"
    echo "4) Test gate evaluation only"
    echo "5) View service logs"
    echo "6) Stop all services"
    echo "7) Exit"
    echo ""
    read -p "Select option: " option
    
    case $option in
        1)
            check_requirements
            check_env_file
            build_application
            start_services
            run_snyk_scan
            test_gates
            ;;
        2)
            check_requirements
            check_env_file
            start_services
            ;;
        3)
            check_requirements
            check_env_file
            run_snyk_scan
            ;;
        4)
            check_requirements
            check_env_file
            test_gates
            ;;
        5)
            view_logs
            ;;
        6)
            cleanup
            ;;
        7)
            exit 0
            ;;
        *)
            print_color "$RED" "Invalid option"
            ;;
    esac
}

# Handle Ctrl+C
trap cleanup INT

# Main execution
if [ "$1" = "--auto" ]; then
    # Automated mode for CI/CD
    check_requirements
    check_env_file
    build_application
    start_services
    run_snyk_scan
    test_gates
    EXIT_CODE=$?
    cleanup
    exit $EXIT_CODE
else
    # Interactive mode
    while true; do
        show_menu
    done
fi