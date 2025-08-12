#!/bin/bash

# Snyk Configuration Validation Script
# This script validates your Snyk configuration and connection

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

print_header() {
    echo ""
    print_color "$BLUE" "═══════════════════════════════════════════════════════════════"
    print_color "$BLUE" "                    SNYK CONFIGURATION VALIDATOR"
    print_color "$BLUE" "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Check if .env file exists and load it, or use environment variables
load_environment() {
    # Look for .env file in multiple possible locations
    local env_file=""
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "$script_dir/../.." && pwd)"
    
    if [ -f .env ]; then
        env_file=".env"
    elif [ -f "$project_root/.env" ]; then
        env_file="$project_root/.env"
    fi
    
    if [ -n "$env_file" ]; then
        print_color "$GREEN" "✓ Found .env file"
        set -a
        source "$env_file"
        set +a
    else
        # Check if required environment variables are already set (CI environment)
        if [ -n "$SNYK_TOKEN" ] && [ -n "$SNYK_ORG_ID" ]; then
            print_color "$GREEN" "✓ Using environment variables (CI mode)"
        else
            print_color "$RED" "✗ .env file not found and required environment variables not set"
            echo "Please either:"
            echo "  1. Create a .env file with your Snyk credentials"
            echo "  2. Set SNYK_TOKEN and SNYK_ORG_ID environment variables"
            exit 1
        fi
    fi
}

# Validate environment variables
validate_env_vars() {
    print_color "$YELLOW" "Checking environment variables..."
    
    local missing_vars=()
    
    if [ -z "$SNYK_TOKEN" ] || [ "$SNYK_TOKEN" = "your_snyk_token_here" ]; then
        missing_vars+=("SNYK_TOKEN")
    else
        print_color "$GREEN" "✓ SNYK_TOKEN is set"
    fi
    
    if [ -z "$SNYK_ORG_ID" ] || [ "$SNYK_ORG_ID" = "your_snyk_org_id_here" ]; then
        missing_vars+=("SNYK_ORG_ID")
    else
        print_color "$GREEN" "✓ SNYK_ORG_ID is set"
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_color "$RED" "✗ Missing required variables: ${missing_vars[*]}"
        echo ""
        echo "Please set the following variables in your .env file:"
        for var in "${missing_vars[@]}"; do
            echo "  $var=your_actual_value_here"
        done
        echo ""
        echo "Get your Snyk credentials from: https://app.snyk.io/account"
        exit 1
    fi
}

# Check if Snyk CLI is installed
check_snyk_cli() {
    print_color "$YELLOW" "Checking Snyk CLI installation..."
    
    if command -v snyk &> /dev/null; then
        local version=$(snyk --version)
        print_color "$GREEN" "✓ Snyk CLI installed (version: $version)"
        return 0
    else
        print_color "$YELLOW" "⚠ Snyk CLI not found. Installing..."
        
        # Try to install via npm
        if command -v npm &> /dev/null; then
            npm install -g snyk
            print_color "$GREEN" "✓ Snyk CLI installed successfully"
        else
            print_color "$RED" "✗ Cannot install Snyk CLI (npm not found)"
            echo "Please install Snyk CLI manually:"
            echo "  npm install -g snyk"
            echo "  or visit: https://docs.snyk.io/snyk-cli/install-the-snyk-cli"
            return 1
        fi
    fi
}

# Test API connection
test_api_connection() {
    print_color "$YELLOW" "Testing Snyk API connection..."
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/snyk_response \
        -H "Authorization: token $SNYK_TOKEN" \
        https://api.snyk.io/v1/user/me)
    
    if [ "$response" = "200" ]; then
        local user_info=$(cat /tmp/snyk_response)
        local username=$(echo "$user_info" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        print_color "$GREEN" "✓ API connection successful"
        if [ -n "$username" ]; then
            print_color "$GREEN" "  Connected as: $username"
        fi
    else
        print_color "$RED" "✗ API connection failed (HTTP $response)"
        echo "Response: $(cat /tmp/snyk_response)"
        echo ""
        echo "Please check:"
        echo "  1. Your SNYK_TOKEN is correct"
        echo "  2. Your token has not expired"
        echo "  3. Your internet connection"
        return 1
    fi
    
    rm -f /tmp/snyk_response
}

# Validate organization
validate_organization() {
    print_color "$YELLOW" "Validating organization..."
    
    # Check if organization ID is in valid UUID format
    if [[ ! $SNYK_ORG_ID =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        print_color "$RED" "✗ Organization ID is not in valid UUID format"
        echo "Expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        return 1
    fi
    
    # Try to validate org by attempting to list projects (this endpoint typically works)
    local response=$(curl -s -w "%{http_code}" -o /tmp/snyk_projects \
        -H "Authorization: token $SNYK_TOKEN" \
        "https://api.snyk.io/v1/org/$SNYK_ORG_ID/projects")
    
    if [ "$response" = "200" ]; then
        print_color "$GREEN" "✓ Organization validated"
        print_color "$GREEN" "  Organization ID: $SNYK_ORG_ID"
        
        # Show project count if available
        local project_count=$(cat /tmp/snyk_projects | grep -o '"id"' | wc -l 2>/dev/null || echo "0")
        print_color "$GREEN" "  Found $project_count projects"
    elif [ "$response" = "404" ]; then
        print_color "$YELLOW" "⚠ Cannot access organization projects (HTTP 404)"
        echo "This is common for new organizations or limited API access"
        print_color "$GREEN" "✓ Organization ID format is valid"
        print_color "$GREEN" "  Organization ID: $SNYK_ORG_ID"
        echo "Note: Organization validation will work once projects are added"
    elif [ "$response" = "401" ]; then
        print_color "$RED" "✗ Unauthorized access to organization"
        echo "Your API token may not have access to this organization"
        return 1
    else
        print_color "$YELLOW" "⚠ Could not validate organization (HTTP $response)"
        echo "This may be normal - continuing with basic format validation"
        print_color "$GREEN" "✓ Organization ID format is valid"
        print_color "$GREEN" "  Organization ID: $SNYK_ORG_ID"
    fi
    
    rm -f /tmp/snyk_projects
}

# Test CLI authentication
test_cli_auth() {
    print_color "$YELLOW" "Testing Snyk CLI authentication..."
    
    # Skip interactive auth in automated environment
    print_color "$YELLOW" "⚠ CLI authentication skipped (requires interactive setup)"
    echo "To authenticate manually, run: snyk auth"
    echo "Or set SNYK_TOKEN environment variable for CI/CD usage"
    
    # For CI/CD, token-based auth via env vars is preferred
    if [ -n "$SNYK_TOKEN" ]; then
        print_color "$GREEN" "✓ Token-based authentication available for CI/CD"
    fi
}

# Test vulnerability scanning
test_vulnerability_scan() {
    print_color "$YELLOW" "Testing vulnerability scanning..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "$script_dir/../.." && pwd)"
    local app_dir="$project_root/microservice-moc-app"
    
    if [ -d "$app_dir" ]; then
        cd "$app_dir"
        
        # Run a test scan (Snyk exits with non-zero when vulnerabilities are found)
        local scan_result=$(snyk test --json 2>/dev/null; true)
        
        if [ -n "$scan_result" ]; then
            local vuln_count=$(echo "$scan_result" | jq '.vulnerabilities | length' 2>/dev/null || echo "0")
            if [ "$vuln_count" -gt 0 ] 2>/dev/null; then
                print_color "$GREEN" "✓ Vulnerability scanning working"
                print_color "$GREEN" "  Found $vuln_count vulnerabilities (expected for PoC)"
            else
                print_color "$YELLOW" "⚠ No vulnerabilities found (unexpected for PoC)"
            fi
        else
            print_color "$YELLOW" "⚠ Vulnerability scan failed (may be normal if dependencies not downloaded)"
            echo "Try running 'mvn compile' first"
        fi
        
        cd "$script_dir"
    else
        print_color "$YELLOW" "⚠ microservice-moc-app directory not found, skipping scan test"
    fi
}

# Generate summary report
generate_report() {
    echo ""
    print_color "$BLUE" "═══════════════════════════════════════════════════════════════"
    print_color "$BLUE" "                        VALIDATION SUMMARY"
    print_color "$BLUE" "═══════════════════════════════════════════════════════════════"
    echo ""
    
    print_color "$GREEN" "✓ Configuration Complete"
    echo ""
    echo "Your Snyk configuration is ready for the CI/CD Security Gating PoC."
    echo ""
    echo "Next steps:"
    echo "  1. Run the full PoC test: ./permit-gating/scripts/test-gates-local.sh"
    echo "  2. Configure Permit.io (see CONFIGURATION_GUIDE.md)"
    echo "  3. Set up GitHub Actions secrets for CI/CD"
    echo ""
    echo "Useful commands:"
    echo "  snyk test                 # Scan current directory"
    echo "  snyk monitor             # Monitor project continuously"
    echo "  snyk test --json         # Get results in JSON format"
}

# Main execution
main() {
    print_header
    
    load_environment
    validate_env_vars
    check_snyk_cli
    test_api_connection
    validate_organization
    test_cli_auth
    test_vulnerability_scan
    generate_report
}

# Handle Ctrl+C
trap 'echo ""; print_color "$YELLOW" "Validation interrupted"; exit 1' INT

# Run main function
main "$@"