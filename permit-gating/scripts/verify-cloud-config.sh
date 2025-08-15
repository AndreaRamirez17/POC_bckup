#!/bin/bash

# Safe Deployment Gate Cloud Configuration Verification Script
# This script helps verify that Permit.io cloud configuration matches local implementation

set -e

echo "🔍 Safe Deployment Gate Cloud Configuration Verification"
echo "========================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default test parameters
CRITICAL_COUNT_SAFE=0     # Should match Safe Deployment Gate
CRITICAL_COUNT_UNSAFE=7   # Should NOT match Safe Deployment Gate
USER_ROLE="Security Officer"
USER_KEY="david-santander"

echo "📋 Testing Configuration Alignment:"
echo "   • Expected Resource Set: Safe_Deployment_Gate"
echo "   • Expected User Role: Security Officer" 
echo "   • Expected Condition: criticalCount equals 0"
echo ""

# Function to test PDP authorization with specific parameters
test_authorization() {
    local critical_count=$1
    local test_name="$2"
    local expected_result="$3"
    
    echo "🧪 Testing: $test_name"
    echo "   Critical Count: $critical_count"
    
    # Create temporary test payload
    cat > /tmp/test-payload.json << EOF
{
    "user": {
        "key": "$USER_KEY",
        "role": "$USER_ROLE"
    },
    "action": "deploy",
    "resource": {
        "type": "deployment",
        "attributes": {
            "criticalCount": $critical_count,
            "highCount": 25,
            "mediumCount": 19,
            "lowCount": 9,
            "environment": "production"
        }
    }
}
EOF
    
    # Make PDP call and capture response
    response=$(curl -s -X POST http://localhost:7766/allowed \
        -H "Content-Type: application/json" \
        -d @/tmp/test-payload.json)
    
    # Parse response
    allow_decision=$(echo "$response" | jq -r '.allow // false')
    resource_set_key=$(echo "$response" | jq -r '.debug.resource_set_key // "none"')
    
    echo "   Response:"
    echo "     • Allow: $allow_decision"
    echo "     • Resource Set: $resource_set_key"
    
    # Verify results
    if [[ "$allow_decision" == "$expected_result" ]]; then
        echo -e "   ${GREEN}✅ Authorization result matches expectation${NC}"
    else
        echo -e "   ${RED}❌ Authorization result mismatch (expected: $expected_result, got: $allow_decision)${NC}"
    fi
    
    # Check Resource Set name
    if [[ "$resource_set_key" == "Safe_Deployment_Gate" ]]; then
        echo -e "   ${GREEN}✅ Resource Set name correct${NC}"
    elif [[ "$resource_set_key" == "Critical_5fVulnerability_5fGate" ]]; then
        echo -e "   ${RED}❌ Still using old Resource Set name${NC}"
        echo -e "   ${YELLOW}💡 Need to rename in Permit.io: Critical_5fVulnerability_5fGate → Safe_Deployment_Gate${NC}"
    else
        echo -e "   ${YELLOW}⚠️ Unknown Resource Set: $resource_set_key${NC}"
    fi
    
    echo ""
    rm -f /tmp/test-payload.json
}

# Start PDP if not running
echo "🚀 Ensuring PDP is running..."
if ! curl -s http://localhost:7766/healthy > /dev/null 2>&1; then
    echo "   Starting PDP container..."
    docker compose -f permit-gating/docker/docker-compose.gating.yml up -d permit-pdp
    echo "   Waiting for PDP to be ready..."
    sleep 10
fi

# Wait for PDP readiness with exponential backoff
echo "⏳ Checking PDP readiness..."
retry_count=0
max_retries=6
while ! curl -s http://localhost:7766/healthy > /dev/null 2>&1; do
    if [ $retry_count -ge $max_retries ]; then
        echo -e "${RED}❌ PDP failed to become ready after $max_retries attempts${NC}"
        exit 1
    fi
    
    wait_time=$((2 ** retry_count))
    echo "   Attempt $((retry_count + 1))/$((max_retries + 1)): Waiting ${wait_time}s..."
    sleep $wait_time
    ((retry_count++))
done

echo -e "${GREEN}✅ PDP is ready${NC}"
echo ""

# Test scenarios
echo "🧪 Running Verification Tests:"
echo "================================"

# Test 1: Safe deployment (criticalCount = 0) - should be allowed via Safe Deployment Gate
test_authorization $CRITICAL_COUNT_SAFE "Safe Deployment (criticalCount = 0)" "true"

# Test 2: Unsafe deployment (criticalCount > 0) - should be allowed via Security Officer override
test_authorization $CRITICAL_COUNT_UNSAFE "Override Deployment (criticalCount = 7)" "true"

# Summary
echo "📊 Verification Summary:"
echo "========================="
echo ""

# Check if we can determine the current configuration state
echo "🔍 Current Configuration Analysis:"

# Make a test call to get the current resource set name
test_response=$(curl -s -X POST http://localhost:7766/allowed \
    -H "Content-Type: application/json" \
    -d "{\"user\":{\"key\":\"$USER_KEY\",\"role\":\"$USER_ROLE\"},\"action\":\"deploy\",\"resource\":{\"type\":\"deployment\",\"attributes\":{\"criticalCount\":$CRITICAL_COUNT_SAFE}}}")

current_resource_set=$(echo "$test_response" | jq -r '.debug.resource_set_key // "unknown"')

if [[ "$current_resource_set" == "Safe_Deployment_Gate" ]]; then
    echo -e "${GREEN}✅ Resource Set configuration is CORRECT${NC}"
    echo "   Using: Safe_Deployment_Gate"
elif [[ "$current_resource_set" == "Critical_5fVulnerability_5fGate" ]]; then
    echo -e "${RED}❌ Resource Set configuration needs UPDATE${NC}"
    echo "   Currently using: Critical_5fVulnerability_5fGate"
    echo "   Should be using: Safe_Deployment_Gate"
    echo ""
    echo -e "${YELLOW}📋 Required Permit.io Cloud Changes:${NC}"
    echo "   1. Navigate to Policy > Resource Sets"
    echo "   2. Find: Critical_5fVulnerability_5fGate" 
    echo "   3. Rename to: Safe_Deployment_Gate"
    echo "   4. Ensure condition: criticalCount equals 0"
else
    echo -e "${YELLOW}⚠️ Unknown Resource Set configuration${NC}"
    echo "   Current: $current_resource_set"
fi

echo ""
echo "🎯 Next Steps:"
echo "  If configuration mismatches found:"
echo "  1. Log into Permit.io Dashboard"
echo "  2. Update Resource Set name and condition" 
echo "  3. Verify user roles are correctly assigned"
echo "  4. Run this script again to verify changes"
echo ""
echo "  If all configurations correct:"
echo "  ✅ Safe Deployment Gate is properly configured!"

# Cleanup
echo "🧹 Cleaning up..."
docker compose -f permit-gating/docker/docker-compose.gating.yml down > /dev/null 2>&1 || true

echo "✅ Verification complete!"