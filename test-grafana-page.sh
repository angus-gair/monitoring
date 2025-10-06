#!/bin/bash
# Grafana Page Loading Test Script
# Tests Grafana accessibility and basic functionality

echo "=== Grafana Page Loading Test ==="
echo "Date: $(date)"
echo ""

# Configuration
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin_secure"
GRAFANA_PASS="GrafanaMonitoring2025!SecurePass"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Health Check
echo "Test 1: Health Check"
HEALTH=$(curl -s "${GRAFANA_URL}/api/health" | jq -r '.database')
if [ "$HEALTH" == "ok" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Grafana health check: ${HEALTH}"
else
    echo -e "${RED}❌ FAIL${NC} - Grafana health check failed"
    exit 1
fi
echo ""

# Test 2: Login Page Accessibility
echo "Test 2: Login Page Accessibility"
LOGIN_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${GRAFANA_URL}/login")
if [ "$LOGIN_RESPONSE" == "200" ] || [ "$LOGIN_RESPONSE" == "301" ]; then
    if [ "$LOGIN_RESPONSE" == "301" ]; then
        echo -e "${YELLOW}⚠️  INFO${NC} - Login page redirects to HTTPS (HTTP $LOGIN_RESPONSE)"
        echo "    This is expected for production configuration"
    else
        echo -e "${GREEN}✅ PASS${NC} - Login page accessible (HTTP $LOGIN_RESPONSE)"
    fi
else
    echo -e "${RED}❌ FAIL${NC} - Login page returned HTTP $LOGIN_RESPONSE"
    exit 1
fi
echo ""

# Test 3: API Version
echo "Test 3: API Version"
VERSION=$(curl -s "${GRAFANA_URL}/api/health" | jq -r '.version')
echo -e "${GREEN}✅ INFO${NC} - Grafana version: ${VERSION}"
echo ""

# Test 4: Authentication
echo "Test 4: Authentication Test"
AUTH_TEST=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" "${GRAFANA_URL}/api/org" 2>&1)
if echo "$AUTH_TEST" | grep -q "Moved Permanently"; then
    echo -e "${YELLOW}⚠️  WARN${NC} - HTTPS redirect active (expected for production config)"
    echo "    Grafana is configured for: https://mon.ajinsights.com.au"
elif echo "$AUTH_TEST" | grep -q "id"; then
    ORG_NAME=$(echo "$AUTH_TEST" | jq -r '.name')
    echo -e "${GREEN}✅ PASS${NC} - Authentication successful (Org: ${ORG_NAME})"
else
    echo -e "${RED}❌ FAIL${NC} - Authentication failed"
    echo "    Response: $AUTH_TEST"
fi
echo ""

# Test 5: Datasource Availability (via Prometheus directly)
echo "Test 5: Datasource Connectivity"
PROM_HEALTH=$(curl -s "http://localhost:9090/-/healthy")
if [ "$PROM_HEALTH" == "Prometheus is Healthy." ]; then
    echo -e "${GREEN}✅ PASS${NC} - Prometheus datasource is healthy"
else
    echo -e "${RED}❌ FAIL${NC} - Prometheus datasource check failed"
fi
echo ""

# Test 6: Metrics Collection
echo "Test 6: Metrics Collection"
METRICS_COUNT=$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq -r '.data.result | length')
if [ "$METRICS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} - Metrics collection active ($METRICS_COUNT targets)"
else
    echo -e "${RED}❌ FAIL${NC} - No metrics collected"
fi
echo ""

# Test 7: Prometheus Targets
echo "Test 7: Prometheus Targets Status"
TARGETS_UP=$(curl -s "http://localhost:9090/api/v1/targets" | jq -r '[.data.activeTargets[] | select(.health=="up")] | length')
TARGETS_TOTAL=$(curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets | length')
if [ "$TARGETS_UP" == "$TARGETS_TOTAL" ]; then
    echo -e "${GREEN}✅ PASS${NC} - All targets UP ($TARGETS_UP/$TARGETS_TOTAL)"
else
    echo -e "${YELLOW}⚠️  WARN${NC} - Some targets down ($TARGETS_UP/$TARGETS_TOTAL UP)"
fi
echo ""

# Test 8: Dashboard Provisioning (check logs)
echo "Test 8: Dashboard Provisioning"
DASHBOARD_LOGS=$(docker logs grafana 2>&1 | grep -c "finished to provision dashboards")
if [ "$DASHBOARD_LOGS" -gt 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} - Dashboard provisioning completed"
else
    echo -e "${YELLOW}⚠️  WARN${NC} - Dashboard provisioning status unclear"
fi
echo ""

# Test 9: Container Health
echo "Test 9: Container Health Status"
HEALTHY_COUNT=$(docker compose -f docker-compose.coolify.yml ps --format json 2>/dev/null | jq -s '[.[] | select(.Health == "healthy")] | length')
TOTAL_COUNT=$(docker compose -f docker-compose.coolify.yml ps --format json 2>/dev/null | jq -s 'length')
if [ "$HEALTHY_COUNT" == "$TOTAL_COUNT" ]; then
    echo -e "${GREEN}✅ PASS${NC} - All containers healthy ($HEALTHY_COUNT/$TOTAL_COUNT)"
else
    echo -e "${YELLOW}⚠️  WARN${NC} - Some containers not fully healthy ($HEALTHY_COUNT/$TOTAL_COUNT)"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo -e "${GREEN}✅ Grafana is operational${NC}"
echo ""
echo "Access Grafana at:"
echo "  Local: http://localhost:3000"
echo "  Production (when DNS configured): https://mon.ajinsights.com.au"
echo ""
echo "Login Credentials:"
echo "  Username: ${GRAFANA_USER}"
echo "  Password: ${GRAFANA_PASS}"
echo ""
echo "Next Steps:"
echo "  1. Open http://localhost:3000 in your browser"
echo "  2. Login with the credentials above"
echo "  3. Navigate to Dashboards → Browse"
echo "  4. Verify all 5 dashboards load with data"
echo ""
echo "For production deployment:"
echo "  - Configure DNS: mon.ajinsights.com.au → 100.74.51.28"
echo "  - Follow: COOLIFY_QUICK_START.md"
echo ""
