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
    
    # Use the correct gating-specific docker-compose file
    docker compose -f permit-gating/docker/docker-compose.gating.yml down 2>/dev/null || true
    docker compose -f permit-gating/docker/docker-compose.gating.yml up -d --build
    
    # Wait for services to be ready
    print_color "$YELLOW" "Waiting for services to start..."
    sleep 20
    
    # Check service health - updated for gating services
    local services=("permit-pdp:7001" "permit-pdp:7766")
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        if curl -sf "http://localhost:$port/healthy" > /dev/null 2>&1; then
            print_color "$GREEN" "✓ $name is ready on port $port"
        else
            print_color "$YELLOW" "⚠ $name might not be fully ready on port $port"
        fi
    done
    
    # Check if PDP container is running
    if docker ps | grep -q "permit-pdp"; then
        print_color "$GREEN" "✓ Permit PDP container is running"
    else
        print_color "$RED" "✗ Permit PDP container is not running"
        print_color "$YELLOW" "Checking container logs..."
        docker compose -f permit-gating/docker/docker-compose.gating.yml logs permit-pdp --tail=10
    fi
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
    
    snyk test --json > ../snyk-scanning/results/snyk-results.json 2>/dev/null || {
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
    chmod +x permit-gating/scripts/evaluate-gates.sh
    
    # Run gate evaluation with current user role settings
    ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
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

# Test with different roles
test_roles() {
    print_color "$BLUE" "Testing different user roles with ABAC policies..."
    echo ""
    
    # Backup current .env settings
    local original_role="$USER_ROLE"
    local original_key="$USER_KEY"
    
    # Test scenarios for Safe Deployment Gate
    local test_scenarios=(
        "developer:test-developer-user:Should FAIL with critical vulnerabilities"
        "editor:david-santander:Should PASS with override for critical vulnerabilities"
        "ci-pipeline:github-actions:Default pipeline behavior"
    )
    
    for scenario in "${test_scenarios[@]}"; do
        IFS=':' read -r role key description <<< "$scenario"
        
        print_color "$YELLOW" "Testing: $description"
        print_color "$BLUE" "Role: $role, User: $key"
        
        # Temporarily update .env file
        sed -i "s/USER_ROLE=.*/USER_ROLE=$role/" .env
        sed -i "s/USER_KEY=.*/USER_KEY=$key/" .env
        
        # Run test
        ./permit-gating/scripts/evaluate-gates.sh snyk-scanning/results/snyk-results.json
        local exit_code=$?
        
        echo ""
        print_color "$BLUE" "Result for $role: Exit code $exit_code"
        echo ""
        echo "----------------------------------------"
        echo ""
    done
    
    # Restore original settings
    sed -i "s/USER_ROLE=.*/USER_ROLE=$original_role/" .env
    sed -i "s/USER_KEY=.*/USER_KEY=$original_key/" .env
    
    print_color "$GREEN" "Role-based testing completed"
}

# View logs
view_logs() {
    print_color "$BLUE" "Service Logs (last 20 lines each):"
    echo ""
    
    # Updated for gating services
    for service in permit-pdp redis opal-fetcher opal-server; do
        if docker compose -f permit-gating/docker/docker-compose.gating.yml ps | grep -q $service; then
            print_color "$YELLOW" "=== $service ==="
            docker compose -f permit-gating/docker/docker-compose.gating.yml logs --tail=20 $service 2>/dev/null || echo "No logs available"
            echo ""
        fi
    done
}

# Cleanup
cleanup() {
    print_color "$BLUE" "Cleaning up..."
    docker compose -f permit-gating/docker/docker-compose.gating.yml down
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
    echo "5) Test different user roles with ABAC"
    echo "6) View service logs"
    echo "7) Stop all services"
    echo "8) Exit"
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
            check_requirements
            check_env_file
            test_roles
            ;;
        6)
            view_logs
            ;;
        7)
            cleanup
            ;;
        8)
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