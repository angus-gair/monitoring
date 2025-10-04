#!/bin/bash

# Integration Test Script
# Tests the complete monitoring stack integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Configuration
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"
NODE_EXPORTER_URL="http://localhost:9100"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"
MAX_WAIT_TIME=60
CHECK_INTERVAL=5

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

test_passed() {
    ((TESTS_PASSED++))
    log_info "✓ $1"
}

test_failed() {
    ((TESTS_FAILED++))
    log_error "✗ $1"
}

wait_for_service() {
    local url=$1
    local service_name=$2
    local elapsed=0

    log_info "Waiting for $service_name to be ready..."

    while [ $elapsed -lt $MAX_WAIT_TIME ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_info "$service_name is ready"
            return 0
        fi
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
        echo -n "."
    done

    echo ""
    log_error "$service_name failed to start within ${MAX_WAIT_TIME}s"
    return 1
}

# Change to project root
cd "$(dirname "$0")/.."

echo "=================================================="
echo "  Monitoring Stack - Integration Tests"
echo "=================================================="
echo ""

# Test 1: Start the stack
log_test "Test 1: Starting monitoring stack..."
if docker-compose up -d; then
    test_passed "Stack started successfully"
else
    test_failed "Failed to start stack"
    exit 1
fi
echo ""

# Test 2: Wait for services to be healthy
log_test "Test 2: Checking service health..."

# Wait for Prometheus
if wait_for_service "$PROMETHEUS_URL/-/healthy" "Prometheus"; then
    test_passed "Prometheus is healthy"
else
    test_failed "Prometheus health check failed"
fi

# Wait for Grafana
if wait_for_service "$GRAFANA_URL/api/health" "Grafana"; then
    test_passed "Grafana is healthy"
else
    test_failed "Grafana health check failed"
fi

# Wait for Node Exporter
if wait_for_service "$NODE_EXPORTER_URL/metrics" "Node Exporter"; then
    test_passed "Node Exporter is healthy"
else
    test_failed "Node Exporter health check failed"
fi
echo ""

# Test 3: Verify Prometheus targets
log_test "Test 3: Checking Prometheus targets..."
TARGETS_RESPONSE=$(curl -s "$PROMETHEUS_URL/api/v1/targets")

if echo "$TARGETS_RESPONSE" | grep -q '"status":"success"'; then
    test_passed "Prometheus API is accessible"

    # Check specific targets
    if echo "$TARGETS_RESPONSE" | grep -q '"job":"prometheus"'; then
        test_passed "Prometheus self-monitoring target found"
    else
        test_failed "Prometheus self-monitoring target not found"
    fi

    if echo "$TARGETS_RESPONSE" | grep -q '"job":"node"'; then
        test_passed "Node Exporter target found"
    else
        test_failed "Node Exporter target not found"
    fi

    # Check target health
    ACTIVE_TARGETS=$(echo "$TARGETS_RESPONSE" | grep -o '"health":"up"' | wc -l)
    log_info "Active targets: $ACTIVE_TARGETS"

    if [ "$ACTIVE_TARGETS" -ge 2 ]; then
        test_passed "All expected targets are up"
    else
        test_failed "Some targets are down"
    fi
else
    test_failed "Failed to query Prometheus targets"
fi
echo ""

# Test 4: Test Grafana API access
log_test "Test 4: Testing Grafana API..."
GRAFANA_HEALTH=$(curl -s "$GRAFANA_URL/api/health")

if echo "$GRAFANA_HEALTH" | grep -q '"database":"ok"'; then
    test_passed "Grafana database is healthy"
else
    test_failed "Grafana database check failed"
fi

# Test authentication
AUTH_RESPONSE=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/user")
if echo "$AUTH_RESPONSE" | grep -q '"login"'; then
    test_passed "Grafana authentication successful"
else
    test_failed "Grafana authentication failed"
fi
echo ""

# Test 5: Verify datasource connectivity
log_test "Test 5: Checking Grafana datasources..."
DATASOURCES=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/datasources")

if echo "$DATASOURCES" | grep -q '"type":"prometheus"'; then
    test_passed "Prometheus datasource configured in Grafana"

    # Test datasource connectivity
    DS_ID=$(echo "$DATASOURCES" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    if [ -n "$DS_ID" ]; then
        DS_TEST=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
            "$GRAFANA_URL/api/datasources/proxy/$DS_ID/api/v1/query?query=up")

        if echo "$DS_TEST" | grep -q '"status":"success"'; then
            test_passed "Datasource connectivity verified"
        else
            test_failed "Datasource connectivity test failed"
        fi
    fi
else
    test_failed "Prometheus datasource not found in Grafana"
fi
echo ""

# Test 6: Verify dashboards are loaded
log_test "Test 6: Checking Grafana dashboards..."
DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/search?type=dash-db")

if [ "$(echo "$DASHBOARDS" | grep -o '"type":"dash-db"' | wc -l)" -gt 0 ]; then
    DASHBOARD_COUNT=$(echo "$DASHBOARDS" | grep -o '"type":"dash-db"' | wc -l)
    test_passed "$DASHBOARD_COUNT dashboard(s) loaded"

    # Check for system metrics dashboard
    if echo "$DASHBOARDS" | grep -qi "system"; then
        test_passed "System metrics dashboard found"
    else
        log_warning "System metrics dashboard not found"
    fi
else
    test_failed "No dashboards found"
fi
echo ""

# Test 7: Query sample metrics
log_test "Test 7: Querying sample metrics..."

# Test CPU metrics
CPU_QUERY=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_cpu_seconds_total")
if echo "$CPU_QUERY" | grep -q '"status":"success"'; then
    test_passed "CPU metrics available"
else
    test_failed "CPU metrics query failed"
fi

# Test memory metrics
MEM_QUERY=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_memory_MemTotal_bytes")
if echo "$MEM_QUERY" | grep -q '"status":"success"'; then
    test_passed "Memory metrics available"
else
    test_failed "Memory metrics query failed"
fi

# Test disk metrics
DISK_QUERY=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_filesystem_size_bytes")
if echo "$DISK_QUERY" | grep -q '"status":"success"'; then
    test_passed "Disk metrics available"
else
    test_failed "Disk metrics query failed"
fi

# Test up metric
UP_QUERY=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up")
if echo "$UP_QUERY" | grep -q '"status":"success"'; then
    UP_COUNT=$(echo "$UP_QUERY" | grep -o '"value":\[.*,"1"\]' | wc -l)
    log_info "Targets reporting up: $UP_COUNT"
    test_passed "Service availability metrics working"
else
    test_failed "Service availability query failed"
fi
echo ""

# Test 8: Validate alert rules
log_test "Test 8: Checking Prometheus alert rules..."
ALERTS_RESPONSE=$(curl -s "$PROMETHEUS_URL/api/v1/rules")

if echo "$ALERTS_RESPONSE" | grep -q '"status":"success"'; then
    test_passed "Alert rules API accessible"

    ALERT_COUNT=$(echo "$ALERTS_RESPONSE" | grep -o '"type":"alerting"' | wc -l)
    if [ "$ALERT_COUNT" -gt 0 ]; then
        test_passed "$ALERT_COUNT alerting rule(s) configured"
    else
        log_warning "No alerting rules found"
    fi
else
    test_failed "Failed to query alert rules"
fi
echo ""

# Test 9: Check metrics retention and storage
log_test "Test 9: Checking Prometheus storage..."
TSDB_STATUS=$(curl -s "$PROMETHEUS_URL/api/v1/status/tsdb")

if echo "$TSDB_STATUS" | grep -q '"status":"success"'; then
    test_passed "TSDB status accessible"

    SERIES_COUNT=$(echo "$TSDB_STATUS" | grep -o '"seriesCountByMetricName":\[[^]]*\]' | grep -o '{"name":"[^"]*","value":[0-9]*}' | wc -l)
    log_info "Unique metrics tracked: $SERIES_COUNT"

    if [ "$SERIES_COUNT" -gt 0 ]; then
        test_passed "Metrics are being stored"
    else
        log_warning "No metrics stored yet (may be too early)"
    fi
else
    test_failed "Failed to query TSDB status"
fi
echo ""

# Test 10: Verify container health
log_test "Test 10: Checking container health..."
CONTAINERS=$(docker-compose ps -q)

for container in $CONTAINERS; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
    CONTAINER_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-health-check")

    if [ "$CONTAINER_HEALTH" = "healthy" ] || [ "$CONTAINER_HEALTH" = "no-health-check" ]; then
        CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$container")
        if [ "$CONTAINER_STATUS" = "running" ]; then
            test_passed "$CONTAINER_NAME is running"
        else
            test_failed "$CONTAINER_NAME is not running (status: $CONTAINER_STATUS)"
        fi
    else
        test_failed "$CONTAINER_NAME health check failed (status: $CONTAINER_HEALTH)"
    fi
done
echo ""

# Summary
echo "=================================================="
echo "  Integration Test Summary"
echo "=================================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    log_info "All integration tests passed!"
    echo ""
    log_info "Quick access URLs:"
    log_info "  - Prometheus: $PROMETHEUS_URL"
    log_info "  - Grafana: $GRAFANA_URL (admin/admin)"
    log_info "  - Node Exporter: $NODE_EXPORTER_URL/metrics"
    exit 0
else
    log_error "Some integration tests failed."
    echo ""
    log_info "Troubleshooting commands:"
    log_info "  - View logs: docker-compose logs"
    log_info "  - Check status: docker-compose ps"
    log_info "  - Restart: docker-compose restart"
    exit 1
fi
