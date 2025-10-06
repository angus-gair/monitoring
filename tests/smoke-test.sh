#!/bin/bash

# Smoke Test Script
# Quick health checks for monitoring stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
# Allow overriding URLs via environment variables. Defaults match docker-compose host
# port mappings (Prometheus -> 9091, Grafana -> 3001).
if [ -f "$(dirname "$0")/../.env" ]; then
    # shellcheck disable=SC1090
    source "$(dirname "$0")/../.env"
fi

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9091}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3001}"
NODE_EXPORTER_URL="http://localhost:9100"
TIMEOUT=5
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin123}"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_service() {
    local url=$1
    local name=$2

    if curl -s -f -m $TIMEOUT "$url" > /dev/null 2>&1; then
        log_ok "$name is responding"
        return 0
    else
        log_fail "$name is not responding"
        return 1
    fi
}

# Change to project root
cd "$(dirname "$0")/.."

echo "=================================================="
echo "  Monitoring Stack - Smoke Test"
echo "=================================================="
echo ""

EXIT_CODE=0

# Check Docker containers
log_info "Checking containers..."
if docker-compose ps | grep -q "Up"; then
    RUNNING=$(docker-compose ps | grep -c "Up" || true)
    log_ok "$RUNNING container(s) running"
else
    log_fail "No containers running"
    EXIT_CODE=1
fi
echo ""

# Check Prometheus
log_info "Checking Prometheus..."
if check_service "$PROMETHEUS_URL/-/healthy" "Prometheus health endpoint"; then
    # Quick metric query
    if curl -s -f -m $TIMEOUT "$PROMETHEUS_URL/api/v1/query?query=up" | grep -q '"status":"success"'; then
        log_ok "Prometheus query API working"
    else
        log_fail "Prometheus query API not responding"
        EXIT_CODE=1
    fi
else
    EXIT_CODE=1
fi
echo ""

# Check Grafana
log_info "Checking Grafana..."
if check_service "$GRAFANA_URL/api/health" "Grafana health endpoint"; then
    # Check if datasource is configured (authenticated API)
    if curl -s -f -m $TIMEOUT -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/datasources" | grep -qi "prometheus"; then
        log_ok "Grafana datasource configured"
    else
        log_fail "Grafana datasource not configured"
        EXIT_CODE=1
    fi
else
    EXIT_CODE=1
fi
echo ""

# Check Node Exporter
log_info "Checking Node Exporter..."
if check_service "$NODE_EXPORTER_URL/metrics" "Node Exporter metrics endpoint"; then
    # Verify we're getting actual metrics
    METRICS_COUNT=$(curl -s -m $TIMEOUT "$NODE_EXPORTER_URL/metrics" | grep -c "^node_" || true)
    if [ "$METRICS_COUNT" -gt 0 ]; then
        log_ok "Node Exporter reporting $METRICS_COUNT metrics"
    else
        log_fail "Node Exporter not reporting metrics"
        EXIT_CODE=1
    fi
else
    EXIT_CODE=1
fi
echo ""

# Check data flow
log_info "Checking data flow..."
UP_METRIC=$(curl -s -m $TIMEOUT "$PROMETHEUS_URL/api/v1/query?query=up" 2>/dev/null | grep -o '"value":\[.*,"1"\]' | wc -l || true)
if [ "$UP_METRIC" -gt 0 ]; then
    log_ok "Data is flowing ($UP_METRIC target(s) up)"
else
    log_fail "No data flowing to Prometheus"
    EXIT_CODE=1
fi
echo ""

# Check dashboard rendering (basic check)
log_info "Checking dashboard availability..."
DASHBOARDS=$(curl -s -m $TIMEOUT -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/search?type=dash-db" 2>/dev/null | grep -c "dash-db" || true)
if [ "$DASHBOARDS" -gt 0 ]; then
    log_ok "$DASHBOARDS dashboard(s) available"
else
    log_fail "No dashboards found"
    EXIT_CODE=1
fi
echo ""

# Final summary
echo "=================================================="
if [ $EXIT_CODE -eq 0 ]; then
    log_info "Smoke test PASSED - All critical services operational"
    echo ""
    log_info "Access points:"
    log_info "  Prometheus: $PROMETHEUS_URL"
    log_info "  Grafana: $GRAFANA_URL"
    log_info "  Node Exporter: $NODE_EXPORTER_URL"
else
    log_error "Smoke test FAILED - Some services are not operational"
    echo ""
    log_info "Troubleshooting:"
    log_info "  1. Check container status: docker-compose ps"
    log_info "  2. View logs: docker-compose logs [service]"
    log_info "  3. Restart services: docker-compose restart"
fi
echo "=================================================="

exit $EXIT_CODE
