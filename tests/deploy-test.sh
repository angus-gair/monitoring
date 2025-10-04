#!/bin/bash

# Deployment Test Script
# Validates configuration files and deployment readiness

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

test_passed() {
    ((TESTS_PASSED++))
    log_info "✓ $1"
}

test_failed() {
    ((TESTS_FAILED++))
    log_error "✗ $1"
}

# Change to project root
cd "$(dirname "$0")/.."

echo "=================================================="
echo "  Monitoring Stack - Deployment Validation Tests"
echo "=================================================="
echo ""

# Test 1: Check if required files exist
log_info "Test 1: Checking required files..."
REQUIRED_FILES=(
    "docker-compose.yml"
    "prometheus/prometheus.yml"
    "prometheus/alerts.yml"
    "grafana/provisioning/datasources/datasource.yml"
    "grafana/provisioning/dashboards/dashboard.yml"
    "grafana/dashboards/system-metrics.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        test_passed "File exists: $file"
    else
        test_failed "File missing: $file"
    fi
done
echo ""

# Test 2: Validate docker-compose.yml syntax
log_info "Test 2: Validating docker-compose.yml syntax..."
if command -v docker-compose &> /dev/null; then
    if docker-compose config > /dev/null 2>&1; then
        test_passed "docker-compose.yml syntax is valid"
    else
        test_failed "docker-compose.yml has syntax errors"
        docker-compose config
    fi
else
    log_warning "docker-compose not found, skipping syntax validation"
fi
echo ""

# Test 3: Check port availability
log_info "Test 3: Checking port availability..."
REQUIRED_PORTS=(9090 3000 9100)
PORT_NAMES=("Prometheus" "Grafana" "Node Exporter")

for i in "${!REQUIRED_PORTS[@]}"; do
    port="${REQUIRED_PORTS[$i]}"
    name="${PORT_NAMES[$i]}"

    if ! netstat -tuln 2>/dev/null | grep -q ":$port " && ! ss -tuln 2>/dev/null | grep -q ":$port "; then
        test_passed "Port $port ($name) is available"
    else
        test_failed "Port $port ($name) is already in use"
    fi
done
echo ""

# Test 4: Validate Prometheus configuration
log_info "Test 4: Validating Prometheus configuration..."
if [ -f "prometheus/prometheus.yml" ]; then
    if command -v promtool &> /dev/null; then
        if promtool check config prometheus/prometheus.yml > /dev/null 2>&1; then
            test_passed "Prometheus config is valid"
        else
            test_failed "Prometheus config has errors"
            promtool check config prometheus/prometheus.yml
        fi
    else
        log_warning "promtool not found, using basic YAML validation"
        if grep -q "global:" prometheus/prometheus.yml && grep -q "scrape_configs:" prometheus/prometheus.yml; then
            test_passed "Prometheus config has required sections"
        else
            test_failed "Prometheus config missing required sections"
        fi
    fi
else
    test_failed "prometheus/prometheus.yml not found"
fi
echo ""

# Test 5: Validate Prometheus alert rules
log_info "Test 5: Validating Prometheus alert rules..."
if [ -f "prometheus/alerts.yml" ]; then
    if command -v promtool &> /dev/null; then
        if promtool check rules prometheus/alerts.yml > /dev/null 2>&1; then
            test_passed "Alert rules are valid"
        else
            test_failed "Alert rules have errors"
            promtool check rules prometheus/alerts.yml
        fi
    else
        log_warning "promtool not found, using basic YAML validation"
        if grep -q "groups:" prometheus/alerts.yml; then
            test_passed "Alert rules file has required structure"
        else
            test_failed "Alert rules file missing 'groups' section"
        fi
    fi
else
    test_failed "prometheus/alerts.yml not found"
fi
echo ""

# Test 6: Validate Grafana datasource configuration
log_info "Test 6: Validating Grafana datasource configuration..."
if [ -f "grafana/provisioning/datasources/datasource.yml" ]; then
    if grep -q "type: prometheus" grafana/provisioning/datasources/datasource.yml; then
        test_passed "Grafana datasource configured for Prometheus"
    else
        test_failed "Grafana datasource not configured for Prometheus"
    fi
else
    test_failed "grafana/provisioning/datasources/datasource.yml not found"
fi
echo ""

# Test 7: Validate Grafana dashboard configuration
log_info "Test 7: Validating Grafana dashboard configuration..."
if [ -f "grafana/provisioning/dashboards/dashboard.yml" ]; then
    test_passed "Grafana dashboard provisioning file exists"
else
    test_failed "grafana/provisioning/dashboards/dashboard.yml not found"
fi
echo ""

# Test 8: Validate Grafana dashboard JSON
log_info "Test 8: Validating Grafana dashboard JSON..."
if [ -f "grafana/dashboards/system-metrics.json" ]; then
    if command -v jq &> /dev/null; then
        if jq empty grafana/dashboards/system-metrics.json 2>/dev/null; then
            test_passed "Dashboard JSON is valid"
        else
            test_failed "Dashboard JSON is invalid"
        fi
    else
        log_warning "jq not found, skipping JSON validation"
    fi
else
    test_failed "grafana/dashboards/system-metrics.json not found"
fi
echo ""

# Test 9: Check Docker daemon
log_info "Test 9: Checking Docker daemon..."
if command -v docker &> /dev/null; then
    if docker info > /dev/null 2>&1; then
        test_passed "Docker daemon is running"
    else
        test_failed "Docker daemon is not accessible"
    fi
else
    test_failed "Docker is not installed"
fi
echo ""

# Test 10: Validate directory structure
log_info "Test 10: Validating directory structure..."
REQUIRED_DIRS=(
    "prometheus"
    "grafana/provisioning/datasources"
    "grafana/provisioning/dashboards"
    "grafana/dashboards"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        test_passed "Directory exists: $dir"
    else
        test_failed "Directory missing: $dir"
    fi
done
echo ""

# Test 11: Check for .env file (optional but recommended)
log_info "Test 11: Checking for environment configuration..."
if [ -f ".env" ]; then
    test_passed ".env file exists"
    if grep -q "GF_SECURITY_ADMIN_PASSWORD" .env; then
        test_passed "Grafana admin password is configured"
    else
        log_warning "Grafana admin password not set in .env"
    fi
else
    log_warning ".env file not found (using defaults)"
fi
echo ""

# Test 12: Dry-run docker-compose
log_info "Test 12: Testing docker-compose configuration..."
if command -v docker-compose &> /dev/null; then
    if docker-compose config --quiet; then
        test_passed "docker-compose configuration is valid"
    else
        test_failed "docker-compose configuration has errors"
    fi
else
    log_warning "docker-compose not found, skipping"
fi
echo ""

# Summary
echo "=================================================="
echo "  Test Summary"
echo "=================================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    log_info "All tests passed! Ready for deployment."
    exit 0
else
    log_error "Some tests failed. Please fix the issues before deployment."
    exit 1
fi
