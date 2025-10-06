# Coolify Deployment Testing Strategy
## Comprehensive Test Plan for mon.ajinsights.com.au

**Target Environment**: Coolify-managed deployment
**Domain**: mon.ajinsights.com.au
**Date**: October 6, 2025
**Test Strategy Version**: 1.0

---

## Table of Contents

1. [Pre-Deployment Validation](#1-pre-deployment-validation)
2. [Coolify-Specific Tests](#2-coolify-specific-tests)
3. [Playwright Page Loading Tests](#3-playwright-page-loading-tests)
4. [Chrome DevTools Debugging Strategy](#4-chrome-devtools-debugging-strategy)
5. [Dashboard Metrics Validation](#5-dashboard-metrics-validation)
6. [Service Health Checks](#6-service-health-checks)
7. [Integration Testing](#7-integration-testing)
8. [Performance Validation](#8-performance-validation)
9. [Security Testing](#9-security-testing)
10. [Rollback Procedures](#10-rollback-procedures)

---

## 1. Pre-Deployment Validation

### 1.1 Configuration Validation

**Objective**: Verify all configuration files are valid before Coolify deployment.

#### Test Cases:

| Test ID | Test Case | Command | Expected Result | Priority |
|---------|-----------|---------|----------------|----------|
| PDV-001 | Validate docker-compose.coolify.yml syntax | `docker-compose -f docker-compose.coolify.yml config` | No errors, valid output | Critical |
| PDV-002 | Validate Prometheus config | `promtool check config prometheus/prometheus.yml` | SUCCESS | Critical |
| PDV-003 | Validate alert rules | `promtool check rules prometheus/alerts.yml` | SUCCESS | Critical |
| PDV-004 | Validate Grafana datasource YAML | `yamllint grafana/provisioning/datasources/datasource.yml` | No errors | High |
| PDV-005 | Validate dashboard JSON files | `jq empty grafana/dashboards/*.json` | No parsing errors | High |
| PDV-006 | Check for required directories | `test -d prometheus && test -d grafana/dashboards` | Directories exist | Critical |
| PDV-007 | Verify alertmanager config exists | `test -f prometheus/alertmanager.yml` | File exists | Medium |
| PDV-008 | Check npm-exporter Dockerfile | `test -f exporters/npm-exporter/Dockerfile` | File exists | High |

#### Automated Test Script:

```bash
#!/bin/bash
# Pre-deployment validation for Coolify

echo "=== Pre-Deployment Validation ==="

# Use existing deploy-test.sh as base
cd /home/ghost/projects/grafana-monitoring
./tests/deploy-test.sh

# Additional Coolify-specific checks
echo ""
echo "=== Coolify-Specific Checks ==="

# Check for Coolify compose file
if [ -f "docker-compose.coolify.yml" ]; then
    echo "✓ docker-compose.coolify.yml exists"
    docker-compose -f docker-compose.coolify.yml config > /dev/null 2>&1 && \
        echo "✓ Coolify compose file is valid" || \
        echo "✗ Coolify compose file has errors"
else
    echo "✗ docker-compose.coolify.yml missing"
    exit 1
fi

# Check for environment variables documentation
if grep -q "GRAFANA_ADMIN_PASSWORD" docker-compose.coolify.yml; then
    echo "✓ Environment variables documented"
fi

# Verify network configuration
if grep -q "monitoring:" docker-compose.coolify.yml; then
    echo "✓ Monitoring network defined"
fi

echo ""
echo "Pre-deployment validation complete"
```

### 1.2 Environment Requirements

**Checklist**:
- [ ] Coolify instance accessible
- [ ] Domain mon.ajinsights.com.au configured in Coolify
- [ ] SSL certificate provisioned (Let's Encrypt)
- [ ] Required ports available (3001, 9091, 9100, 8080, 9101, 9093)
- [ ] Docker network configured
- [ ] Persistent volumes configured in Coolify
- [ ] Environment variables set in Coolify:
  - `GRAFANA_ADMIN_USER`
  - `GRAFANA_ADMIN_PASSWORD`
  - `GRAFANA_ROOT_URL=https://mon.ajinsights.com.au`

---

## 2. Coolify-Specific Tests

### 2.1 Coolify Platform Integration

**Objective**: Verify deployment integrates correctly with Coolify platform.

#### Test Cases:

| Test ID | Test Case | Validation Method | Expected Result | Priority |
|---------|-----------|-------------------|----------------|----------|
| CF-001 | Coolify service detection | Check Coolify dashboard | All 6 services visible | Critical |
| CF-002 | Container naming | Verify container names | Follow Coolify naming convention | High |
| CF-003 | Network isolation | Check network assignment | All services on same network | Critical |
| CF-004 | Volume persistence | Restart containers | Data persists after restart | Critical |
| CF-005 | Environment variable injection | Check container env vars | All vars present | High |
| CF-006 | Reverse proxy configuration | Access via domain | Grafana accessible at mon.ajinsights.com.au | Critical |
| CF-007 | SSL/TLS termination | Check certificate | Valid SSL certificate | Critical |
| CF-008 | Log aggregation | Check Coolify logs | Logs visible in Coolify UI | Medium |
| CF-009 | Health checks | Coolify dashboard | All services showing healthy | Critical |
| CF-010 | Auto-restart policy | Kill container | Container auto-restarts | High |

#### Validation Commands:

```bash
# CF-001: Check services in Coolify
curl -H "Authorization: Bearer $COOLIFY_TOKEN" \
  https://coolify.ajinsights.com.au/api/v1/deployments

# CF-003: Verify network
docker network inspect monitoring

# CF-004: Test volume persistence
docker exec -it prometheus-container ls -la /prometheus
docker restart prometheus-container
docker exec -it prometheus-container ls -la /prometheus

# CF-005: Check environment variables
docker exec -it grafana-container env | grep GRAFANA_

# CF-006: Test reverse proxy
curl -I https://mon.ajinsights.com.au

# CF-007: Validate SSL
openssl s_client -connect mon.ajinsights.com.au:443 -servername mon.ajinsights.com.au
```

### 2.2 Coolify Deployment Modes

**Test Scenario**: Verify different deployment configurations.

- [ ] **Initial Deployment**: Fresh deployment to Coolify
- [ ] **Update Deployment**: Config changes pushed to existing deployment
- [ ] **Rebuild Deployment**: Force rebuild of custom exporters
- [ ] **Rollback Deployment**: Revert to previous version

---

## 3. Playwright Page Loading Tests

### 3.1 Playwright Test Script Outline

**Objective**: Automated browser testing for mon.ajinsights.com.au

#### Test Coverage:

```javascript
// playwright-deployment-tests.js
const { chromium } = require('playwright');

async function runDeploymentTests() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: false, // Validate SSL
    viewport: { width: 1920, height: 1080 }
  });
  const page = await context.newPage();

  const results = {
    passed: 0,
    failed: 0,
    tests: []
  };

  // Test Suite
  const tests = [
    {
      id: 'PW-001',
      name: 'Grafana Landing Page Loads',
      priority: 'Critical',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au', {
          waitUntil: 'networkidle',
          timeout: 30000
        });
        const title = await page.title();
        return title.includes('Grafana');
      }
    },
    {
      id: 'PW-002',
      name: 'SSL Certificate Valid',
      priority: 'Critical',
      test: async () => {
        const response = await page.goto('https://mon.ajinsights.com.au');
        return response.ok() && response.securityDetails() !== null;
      }
    },
    {
      id: 'PW-003',
      name: 'Login Form Present',
      priority: 'Critical',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au');
        const loginForm = await page.locator('form').count();
        return loginForm > 0;
      }
    },
    {
      id: 'PW-004',
      name: 'User Authentication Works',
      priority: 'Critical',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au/login');
        await page.fill('input[name="user"]', process.env.GRAFANA_ADMIN_USER || 'admin');
        await page.fill('input[name="password"]', process.env.GRAFANA_ADMIN_PASSWORD || 'admin');
        await page.click('button[type="submit"]');
        await page.waitForNavigation({ waitUntil: 'networkidle' });
        const url = page.url();
        return !url.includes('/login');
      }
    },
    {
      id: 'PW-005',
      name: 'Dashboard List Loads',
      priority: 'High',
      test: async () => {
        // Assumes already authenticated from PW-004
        await page.goto('https://mon.ajinsights.com.au/dashboards');
        await page.waitForSelector('[data-testid="dashboard-card"]', { timeout: 10000 });
        const dashboards = await page.locator('[data-testid="dashboard-card"]').count();
        return dashboards >= 5; // We have 5 dashboards
      }
    },
    {
      id: 'PW-006',
      name: 'System Overview Dashboard Loads',
      priority: 'Critical',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au/d/system-overview');
        await page.waitForSelector('.panel-container', { timeout: 15000 });
        const panels = await page.locator('.panel-container').count();
        return panels > 0;
      }
    },
    {
      id: 'PW-007',
      name: 'Dashboard Panels Render Data',
      priority: 'Critical',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au/d/system-overview');
        await page.waitForTimeout(5000); // Wait for metrics to load
        const noDataPanels = await page.locator('.panel-empty-state').count();
        return noDataPanels === 0; // No "No Data" panels
      }
    },
    {
      id: 'PW-008',
      name: 'Prometheus Datasource Accessible',
      priority: 'Critical',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au/datasources');
        const prometheusDS = await page.locator('text=Prometheus').count();
        return prometheusDS > 0;
      }
    },
    {
      id: 'PW-009',
      name: 'Time Range Selector Works',
      priority: 'High',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au/d/system-overview');
        await page.click('[data-testid="time-range-picker"]');
        await page.click('text=Last 6 hours');
        await page.waitForTimeout(2000);
        return true; // No errors means success
      }
    },
    {
      id: 'PW-010',
      name: 'Dashboard Refresh Works',
      priority: 'Medium',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au/d/system-overview');
        const initialContent = await page.content();
        await page.click('[data-testid="refresh-button"]');
        await page.waitForTimeout(2000);
        const refreshedContent = await page.content();
        return initialContent !== refreshedContent;
      }
    },
    {
      id: 'PW-011',
      name: 'Docker Containers Dashboard Loads',
      priority: 'High',
      test: async () => {
        await page.goto('https://mon.ajinsights.com.au/d/docker-containers');
        await page.waitForSelector('.panel-container', { timeout: 15000 });
        return true;
      }
    },
    {
      id: 'PW-012',
      name: 'Page Load Performance',
      priority: 'Medium',
      test: async () => {
        const startTime = Date.now();
        await page.goto('https://mon.ajinsights.com.au/d/system-overview', {
          waitUntil: 'networkidle'
        });
        const loadTime = Date.now() - startTime;
        console.log(`Page load time: ${loadTime}ms`);
        return loadTime < 5000; // Should load in under 5 seconds
      }
    },
    {
      id: 'PW-013',
      name: 'No Console Errors',
      priority: 'High',
      test: async () => {
        const errors = [];
        page.on('console', msg => {
          if (msg.type() === 'error') {
            errors.push(msg.text());
          }
        });
        await page.goto('https://mon.ajinsights.com.au/d/system-overview');
        await page.waitForTimeout(3000);
        console.log(`Console errors found: ${errors.length}`);
        return errors.length === 0;
      }
    },
    {
      id: 'PW-014',
      name: 'Mobile Responsive Design',
      priority: 'Low',
      test: async () => {
        await context.setViewportSize({ width: 375, height: 667 }); // iPhone size
        await page.goto('https://mon.ajinsights.com.au/d/system-overview');
        const mobileMenu = await page.locator('[data-testid="mobile-menu"]').count();
        return mobileMenu >= 0; // Just check it doesn't crash
      }
    },
    {
      id: 'PW-015',
      name: 'API Health Endpoint',
      priority: 'Critical',
      test: async () => {
        const response = await page.goto('https://mon.ajinsights.com.au/api/health');
        const body = await response.json();
        return body.database === 'ok';
      }
    }
  ];

  // Execute tests
  for (const test of tests) {
    try {
      console.log(`Running ${test.id}: ${test.name}...`);
      const passed = await test.test();
      if (passed) {
        results.passed++;
        console.log(`✓ ${test.id} PASSED`);
      } else {
        results.failed++;
        console.log(`✗ ${test.id} FAILED`);
      }
      results.tests.push({ ...test, passed });
    } catch (error) {
      results.failed++;
      console.log(`✗ ${test.id} ERROR: ${error.message}`);
      results.tests.push({ ...test, passed: false, error: error.message });
    }
  }

  await browser.close();

  // Print summary
  console.log('\n=== Test Summary ===');
  console.log(`Total: ${results.tests.length}`);
  console.log(`Passed: ${results.passed}`);
  console.log(`Failed: ${results.failed}`);

  return results;
}

// Run tests
runDeploymentTests().then(results => {
  process.exit(results.failed > 0 ? 1 : 0);
});
```

#### Running Playwright Tests:

```bash
# Install Playwright
npm install -D playwright

# Run tests
GRAFANA_ADMIN_USER=admin GRAFANA_ADMIN_PASSWORD=yourpassword node playwright-deployment-tests.js

# Run with headed browser (for debugging)
HEADLESS=false node playwright-deployment-tests.js

# Run specific test
node -e "require('./playwright-deployment-tests.js').runTest('PW-006')"
```

### 3.2 Visual Regression Testing

```javascript
// Screenshot comparison tests
{
  id: 'PW-VRT-001',
  name: 'System Overview Dashboard Visual Regression',
  test: async () => {
    await page.goto('https://mon.ajinsights.com.au/d/system-overview');
    await page.waitForTimeout(5000); // Wait for all panels to load
    await page.screenshot({
      path: 'screenshots/system-overview.png',
      fullPage: true
    });
    // Compare with baseline screenshot
    return true;
  }
}
```

---

## 4. Chrome DevTools Debugging Strategy

### 4.1 Chrome DevTools Debugging Checklist

**Objective**: Use Chrome DevTools to identify and debug deployment issues.

#### Network Tab Analysis

**Checklist**:
- [ ] **DNS Resolution**: Verify mon.ajinsights.com.au resolves correctly
- [ ] **SSL/TLS Handshake**: Check certificate validity and chain
- [ ] **HTTP Status Codes**: All requests return 200 (except expected redirects)
- [ ] **Response Times**: Measure API endpoint latency
- [ ] **Failed Requests**: Identify 404s, 500s, or CORS errors
- [ ] **WebSocket Connections**: Verify Grafana live updates working
- [ ] **Static Asset Loading**: All CSS, JS, fonts load successfully
- [ ] **API Calls**: `/api/datasources`, `/api/dashboards` returning data
- [ ] **Metrics Queries**: Prometheus query API responding
- [ ] **Resource Size**: Check for oversized responses

**Debugging Commands**:

```javascript
// In Chrome DevTools Console

// 1. Check all network requests
performance.getEntriesByType('resource').forEach(r => {
  console.log(`${r.name}: ${r.duration.toFixed(2)}ms`);
});

// 2. Identify slow requests
performance.getEntriesByType('resource')
  .filter(r => r.duration > 1000)
  .forEach(r => console.log(`SLOW: ${r.name} - ${r.duration}ms`));

// 3. Check failed requests
performance.getEntriesByType('resource')
  .filter(r => r.responseStatus >= 400)
  .forEach(r => console.log(`FAILED: ${r.name} - ${r.responseStatus}`));

// 4. Measure page load time
window.performance.timing.loadEventEnd - window.performance.timing.navigationStart;

// 5. Check WebSocket status
window.grafanaBootData?.datasources?.forEach(ds => {
  console.log(`Datasource: ${ds.name}, Type: ${ds.type}, URL: ${ds.url}`);
});
```

#### Console Tab Analysis

**Checklist**:
- [ ] **No JavaScript Errors**: Check for red error messages
- [ ] **No Warning Messages**: Investigate yellow warnings
- [ ] **API Response Validation**: Check for failed API calls
- [ ] **CORS Errors**: Ensure cross-origin requests allowed
- [ ] **Authentication Errors**: Verify session tokens valid
- [ ] **Grafana Plugin Errors**: Check plugin loading
- [ ] **React Errors**: Check for component rendering issues

**Debugging Queries**:

```javascript
// Check Grafana boot data
console.log(window.grafanaBootData);

// Check datasource configuration
console.log(window.grafanaBootData.datasources);

// Check current user
console.log(window.grafanaBootData.user);

// Test API endpoint
fetch('/api/health')
  .then(r => r.json())
  .then(data => console.log('Health:', data))
  .catch(err => console.error('Health check failed:', err));

// Test Prometheus datasource
fetch('/api/datasources/proxy/1/api/v1/query?query=up')
  .then(r => r.json())
  .then(data => console.log('Prometheus up metric:', data))
  .catch(err => console.error('Prometheus query failed:', err));
```

#### Performance Tab Analysis

**Checklist**:
- [ ] **First Contentful Paint (FCP)**: < 1.5s
- [ ] **Largest Contentful Paint (LCP)**: < 2.5s
- [ ] **Time to Interactive (TTI)**: < 3.5s
- [ ] **Total Blocking Time (TBT)**: < 300ms
- [ ] **Cumulative Layout Shift (CLS)**: < 0.1
- [ ] **Memory Leaks**: Check heap snapshots
- [ ] **CPU Usage**: Identify heavy JavaScript execution

**Recording Script**:

```javascript
// Start performance recording
const perfObserver = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log(`${entry.name}: ${entry.duration}ms`);
  }
});
perfObserver.observe({ entryTypes: ['measure', 'navigation'] });

// Navigate and measure
performance.mark('start-navigation');
window.location.href = '/d/system-overview';
performance.mark('end-navigation');
performance.measure('navigation-time', 'start-navigation', 'end-navigation');
```

#### Application Tab Analysis

**Checklist**:
- [ ] **Local Storage**: Check for Grafana preferences
- [ ] **Session Storage**: Verify authentication tokens
- [ ] **Cookies**: Check session cookies present
- [ ] **Service Workers**: Verify caching strategy
- [ ] **IndexedDB**: Check for offline data storage

**Debugging Commands**:

```javascript
// Check Local Storage
Object.keys(localStorage).forEach(key => {
  console.log(`${key}: ${localStorage.getItem(key)}`);
});

// Check Session Storage
Object.keys(sessionStorage).forEach(key => {
  console.log(`${key}: ${sessionStorage.getItem(key)}`);
});

// Check Cookies
document.cookie.split(';').forEach(c => console.log(c.trim()));
```

#### Sources Tab Debugging

**Checklist**:
- [ ] **Source Maps Working**: Can debug minified code
- [ ] **Breakpoints**: Set breakpoints in Grafana code
- [ ] **Call Stack**: Trace function execution
- [ ] **Scope Variables**: Inspect runtime values
- [ ] **XHR Breakpoints**: Debug API calls

### 4.2 Network Waterfall Analysis

**Key Metrics to Track**:

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| DNS Lookup | < 50ms | > 200ms |
| TCP Connection | < 100ms | > 500ms |
| SSL Handshake | < 200ms | > 1000ms |
| TTFB (Time to First Byte) | < 500ms | > 2000ms |
| Content Download | < 1s | > 5s |
| DOM Content Loaded | < 2s | > 5s |
| Page Load Complete | < 3s | > 10s |

### 4.3 DevTools Protocol Automation

```javascript
// Automated DevTools data collection
const CDP = require('chrome-remote-interface');

async function collectDevToolsMetrics() {
  const client = await CDP();
  const { Network, Page, Runtime } = client;

  await Network.enable();
  await Page.enable();

  const metrics = {
    requests: [],
    console: [],
    coverage: []
  };

  Network.requestWillBeSent((params) => {
    metrics.requests.push({
      url: params.request.url,
      method: params.request.method,
      timestamp: params.timestamp
    });
  });

  Runtime.consoleAPICalled((params) => {
    metrics.console.push({
      type: params.type,
      args: params.args,
      timestamp: params.timestamp
    });
  });

  await Page.navigate({ url: 'https://mon.ajinsights.com.au' });
  await Page.loadEventFired();

  await client.close();
  return metrics;
}
```

---

## 5. Dashboard Metrics Validation

### 5.1 System Overview Dashboard

**Dashboard ID**: `system-overview.json`
**Expected Panels**: 12+

#### Metrics Validation Checklist:

| Panel | Metric Query | Expected Result | Validation Method |
|-------|--------------|----------------|-------------------|
| CPU Usage | `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | 0-100% | Visual + Query |
| Memory Usage | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` | 0-100% | Visual + Query |
| Disk Usage | `(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100` | 0-100% | Visual + Query |
| Load Average | `node_load1, node_load5, node_load15` | Positive numbers | Visual + Query |
| Network Traffic | `rate(node_network_receive_bytes_total[5m])` | Bytes/sec | Visual + Query |
| Disk I/O | `rate(node_disk_read_bytes_total[5m])` | Bytes/sec | Visual + Query |
| System Uptime | `node_time_seconds - node_boot_time_seconds` | Seconds | Visual + Query |

#### Automated Validation Script:

```bash
#!/bin/bash
# Dashboard metrics validation for System Overview

GRAFANA_URL="https://mon.ajinsights.com.au"
GRAFANA_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_PASS="${GRAFANA_ADMIN_PASSWORD:-admin}"

echo "=== System Overview Dashboard Validation ==="

# Get dashboard UID
DASHBOARD_UID=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/search?query=system-overview" | \
  jq -r '.[0].uid')

echo "Dashboard UID: $DASHBOARD_UID"

# Get dashboard JSON
DASHBOARD_JSON=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID")

# Count panels
PANEL_COUNT=$(echo "$DASHBOARD_JSON" | jq '.dashboard.panels | length')
echo "Panel count: $PANEL_COUNT"

# Validate each critical metric via Prometheus
METRICS=(
  "node_cpu_seconds_total"
  "node_memory_MemTotal_bytes"
  "node_filesystem_size_bytes"
  "node_load1"
  "node_network_receive_bytes_total"
)

for metric in "${METRICS[@]}"; do
  RESULT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
    "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=$metric" | \
    jq -r '.status')

  if [ "$RESULT" == "success" ]; then
    echo "✓ $metric: OK"
  else
    echo "✗ $metric: FAILED"
  fi
done
```

### 5.2 Docker Containers Dashboard

**Dashboard ID**: `docker-containers.json`
**Expected Panels**: 8+

#### Metrics Validation:

| Panel | Metric Query | Expected Result |
|-------|--------------|----------------|
| Container CPU | `rate(container_cpu_usage_seconds_total[5m])` | Per-container % |
| Container Memory | `container_memory_usage_bytes` | Bytes per container |
| Container Network | `rate(container_network_receive_bytes_total[5m])` | Bytes/sec |
| Container Count | `count(container_last_seen)` | Number of containers |

### 5.3 Docker Monitoring Dashboard

**Dashboard ID**: `docker-monitoring.json`

### 5.4 Deployments Dashboard

**Dashboard ID**: `deployments.json`

### 5.5 App Services Dashboard

**Dashboard ID**: `app-services.json`

### 5.6 Generic Dashboard Validation

**Automated Test for All Dashboards**:

```bash
#!/bin/bash
# Validate all dashboards load and have data

GRAFANA_URL="https://mon.ajinsights.com.au"
DASHBOARDS=(
  "system-overview"
  "docker-containers"
  "docker-monitoring"
  "deployments"
  "app-services"
)

for dashboard in "${DASHBOARDS[@]}"; do
  echo "Testing: $dashboard"

  # Get dashboard UID
  UID=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
    "$GRAFANA_URL/api/search?query=$dashboard" | jq -r '.[0].uid')

  # Get dashboard
  RESPONSE=$(curl -s -w "\n%{http_code}" -u "$GRAFANA_USER:$GRAFANA_PASS" \
    "$GRAFANA_URL/api/dashboards/uid/$UID")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

  if [ "$HTTP_CODE" == "200" ]; then
    PANEL_COUNT=$(echo "$RESPONSE" | head -n-1 | jq '.dashboard.panels | length')
    echo "✓ $dashboard: $PANEL_COUNT panels"
  else
    echo "✗ $dashboard: HTTP $HTTP_CODE"
  fi
done
```

---

## 6. Service Health Checks

### 6.1 Service Endpoint Validation

**Objective**: Verify all monitoring stack services are accessible and healthy.

#### Service Health Check Matrix:

| Service | Health Endpoint | Expected Response | Test Command | Priority |
|---------|----------------|-------------------|--------------|----------|
| Grafana | `/api/health` | `{"database":"ok"}` | `curl https://mon.ajinsights.com.au/api/health` | Critical |
| Prometheus | `/-/healthy` | `Prometheus is Healthy.` | `curl http://prometheus:9090/-/healthy` | Critical |
| Prometheus | `/-/ready` | `Prometheus is Ready.` | `curl http://prometheus:9090/-/ready` | Critical |
| Node Exporter | `/metrics` | Metrics output | `curl http://node-exporter:9100/metrics` | Critical |
| cAdvisor | `/healthz` | `ok` | `curl http://cadvisor:8080/healthz` | Critical |
| NPM Exporter | `/metrics` | Metrics output | `curl http://npm-exporter:9101/metrics` | High |
| Alertmanager | `/-/healthy` | `OK` | `curl http://alertmanager:9093/-/healthy` | Medium |

#### Automated Health Check Script:

```bash
#!/bin/bash
# Service health check script for Coolify deployment

SERVICES=(
  "grafana|https://mon.ajinsights.com.au/api/health|database"
  "prometheus|http://prometheus:9090/-/healthy|Healthy"
  "node-exporter|http://node-exporter:9100/metrics|node_"
  "cadvisor|http://cadvisor:8080/healthz|ok"
  "npm-exporter|http://npm-exporter:9101/metrics|npm_"
)

echo "=== Service Health Checks ==="
echo ""

PASSED=0
FAILED=0

for service_info in "${SERVICES[@]}"; do
  IFS='|' read -r SERVICE URL PATTERN <<< "$service_info"

  echo "Checking $SERVICE..."
  RESPONSE=$(curl -s -m 5 "$URL" 2>/dev/null)

  if echo "$RESPONSE" | grep -q "$PATTERN"; then
    echo "✓ $SERVICE: HEALTHY"
    ((PASSED++))
  else
    echo "✗ $SERVICE: UNHEALTHY or UNREACHABLE"
    ((FAILED++))
  fi
done

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

exit $FAILED
```

### 6.2 Prometheus Targets Health

**Test**: Verify all Prometheus scrape targets are UP.

```bash
#!/bin/bash
# Check Prometheus targets

PROMETHEUS_URL="http://prometheus:9090"

echo "=== Prometheus Target Health ==="

TARGETS=$(curl -s "$PROMETHEUS_URL/api/v1/targets" | jq -r '
  .data.activeTargets[] |
  "\(.labels.job)|\(.health)|\(.lastScrape)"
')

echo "$TARGETS" | while IFS='|' read -r JOB HEALTH LAST_SCRAPE; do
  if [ "$HEALTH" == "up" ]; then
    echo "✓ $JOB: $HEALTH (last: $LAST_SCRAPE)"
  else
    echo "✗ $JOB: $HEALTH"
  fi
done
```

### 6.3 Data Flow Validation

**Test**: Verify metrics are flowing from exporters to Prometheus to Grafana.

```bash
#!/bin/bash
# Validate end-to-end data flow

echo "=== Data Flow Validation ==="

# 1. Check Node Exporter is producing metrics
NODE_METRICS=$(curl -s http://node-exporter:9100/metrics | grep -c "^node_")
echo "Node Exporter metrics: $NODE_METRICS"
[ $NODE_METRICS -gt 0 ] && echo "✓ Node Exporter producing metrics" || echo "✗ No metrics from Node Exporter"

# 2. Check Prometheus is scraping metrics
PROM_SERIES=$(curl -s "http://prometheus:9090/api/v1/query?query=up" | jq -r '.data.result | length')
echo "Prometheus series count: $PROM_SERIES"
[ $PROM_SERIES -gt 0 ] && echo "✓ Prometheus scraping metrics" || echo "✗ Prometheus not scraping"

# 3. Check Grafana can query Prometheus
GRAFANA_QUERY=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "https://mon.ajinsights.com.au/api/datasources/proxy/1/api/v1/query?query=up" | \
  jq -r '.status')
[ "$GRAFANA_QUERY" == "success" ] && echo "✓ Grafana querying Prometheus" || echo "✗ Grafana cannot query Prometheus"

echo ""
echo "Data flow validation complete"
```

---

## 7. Integration Testing

### 7.1 End-to-End Integration Tests

**Objective**: Validate complete monitoring pipeline from metric collection to visualization.

#### Integration Test Suite:

```bash
#!/bin/bash
# Comprehensive integration test suite

set -e

echo "=================================================="
echo "  Coolify Deployment - Integration Tests"
echo "=================================================="
echo ""

GRAFANA_URL="https://mon.ajinsights.com.au"
GRAFANA_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_PASS="${GRAFANA_ADMIN_PASSWORD:-admin}"

TEST_PASSED=0
TEST_FAILED=0

test_pass() {
  echo "✓ $1"
  ((TEST_PASSED++))
}

test_fail() {
  echo "✗ $1"
  ((TEST_FAILED++))
}

# Test 1: Grafana accessible via HTTPS
echo "Test 1: Grafana HTTPS accessibility..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL")
[ "$RESPONSE" == "200" ] && test_pass "Grafana accessible" || test_fail "Grafana not accessible (HTTP $RESPONSE)"

# Test 2: SSL certificate valid
echo "Test 2: SSL certificate validation..."
SSL_EXPIRY=$(echo | openssl s_client -servername mon.ajinsights.com.au -connect mon.ajinsights.com.au:443 2>/dev/null | \
  openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
[ -n "$SSL_EXPIRY" ] && test_pass "SSL certificate valid (expires: $SSL_EXPIRY)" || test_fail "SSL certificate invalid"

# Test 3: Authentication works
echo "Test 3: Grafana authentication..."
AUTH_RESPONSE=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/user" | jq -r '.login')
[ "$AUTH_RESPONSE" == "$GRAFANA_USER" ] && test_pass "Authentication successful" || test_fail "Authentication failed"

# Test 4: Datasource configured
echo "Test 4: Prometheus datasource..."
DS_COUNT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources" | \
  jq '[.[] | select(.type=="prometheus")] | length')
[ "$DS_COUNT" -gt 0 ] && test_pass "Prometheus datasource configured" || test_fail "No Prometheus datasource"

# Test 5: Datasource connectivity
echo "Test 5: Datasource connectivity..."
DS_TEST=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=up" | jq -r '.status')
[ "$DS_TEST" == "success" ] && test_pass "Datasource connectivity OK" || test_fail "Datasource connectivity failed"

# Test 6: Dashboards loaded
echo "Test 6: Dashboard provisioning..."
DASHBOARD_COUNT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/search?type=dash-db" | jq 'length')
[ "$DASHBOARD_COUNT" -ge 5 ] && test_pass "$DASHBOARD_COUNT dashboards loaded" || test_fail "Expected 5+ dashboards, found $DASHBOARD_COUNT"

# Test 7: Prometheus targets healthy
echo "Test 7: Prometheus targets..."
# Access Prometheus via internal network (requires exec into container or port forwarding)
# For external access, would need to expose Prometheus or use Grafana proxy
TARGET_UP=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=up" | \
  jq '[.data.result[] | select(.value[1]=="1")] | length')
[ "$TARGET_UP" -ge 4 ] && test_pass "$TARGET_UP targets UP" || test_fail "Only $TARGET_UP targets UP (expected 4+)"

# Test 8: Metrics being collected
echo "Test 8: Metrics collection..."
CPU_METRICS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=node_cpu_seconds_total" | \
  jq '.data.result | length')
[ "$CPU_METRICS" -gt 0 ] && test_pass "CPU metrics collected" || test_fail "No CPU metrics"

# Test 9: Container metrics available
echo "Test 9: Container metrics..."
CONTAINER_METRICS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=container_cpu_usage_seconds_total" | \
  jq '.data.result | length')
[ "$CONTAINER_METRICS" -gt 0 ] && test_pass "Container metrics collected" || test_fail "No container metrics"

# Test 10: Alert rules loaded
echo "Test 10: Alert rules..."
ALERT_COUNT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/rules" | \
  jq '[.data.groups[].rules[] | select(.type=="alerting")] | length')
[ "$ALERT_COUNT" -ge 9 ] && test_pass "$ALERT_COUNT alert rules loaded" || test_fail "Expected 9+ alerts, found $ALERT_COUNT"

# Test 11: Time-series data exists
echo "Test 11: Time-series data retention..."
SERIES_COUNT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/status/tsdb" | \
  jq '.data.seriesCountByMetricName | length')
[ "$SERIES_COUNT" -gt 0 ] && test_pass "$SERIES_COUNT unique metrics stored" || test_fail "No metrics stored"

# Test 12: Dashboard query test (System Overview)
echo "Test 12: Dashboard query execution..."
DASHBOARD_UID=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/search?query=system-overview" | jq -r '.[0].uid')
DASHBOARD_PANELS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID" | jq '.dashboard.panels | length')
[ "$DASHBOARD_PANELS" -gt 0 ] && test_pass "Dashboard has $DASHBOARD_PANELS panels" || test_fail "Dashboard has no panels"

echo ""
echo "=================================================="
echo "  Integration Test Summary"
echo "=================================================="
echo "Tests Passed: $TEST_PASSED"
echo "Tests Failed: $TEST_FAILED"
echo ""

if [ $TEST_FAILED -eq 0 ]; then
  echo "✓ All integration tests PASSED"
  exit 0
else
  echo "✗ Some integration tests FAILED"
  exit 1
fi
```

### 7.2 Alert Rule Testing

**Test**: Trigger alerts and verify they fire correctly.

```bash
#!/bin/bash
# Alert rule validation

echo "=== Alert Rule Testing ==="

# Get all alert rules
ALERTS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/rules" | \
  jq -r '.data.groups[].rules[] | select(.type=="alerting") | .name')

echo "Configured alerts:"
echo "$ALERTS"

# Check for firing alerts
FIRING=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources/proxy/1/api/v1/alerts" | \
  jq '[.data.alerts[] | select(.state=="firing")] | length')

echo ""
echo "Firing alerts: $FIRING"
```

---

## 8. Performance Validation

### 8.1 Response Time Benchmarks

**Objective**: Ensure acceptable performance for all endpoints.

#### Performance Test Matrix:

| Endpoint | Target Response Time | Critical Threshold | Test Tool |
|----------|---------------------|-------------------|-----------|
| Grafana home | < 500ms | > 2s | curl, ab |
| Dashboard load | < 2s | > 5s | Playwright |
| API /api/health | < 100ms | > 500ms | curl |
| Prometheus query | < 500ms | > 2s | curl |
| Metrics endpoint | < 200ms | > 1s | curl |
| Dashboard refresh | < 1s | > 3s | Playwright |

#### Automated Performance Tests:

```bash
#!/bin/bash
# Performance benchmark script

echo "=== Performance Benchmarks ==="

# Test 1: Grafana home page
echo "Test: Grafana home page"
GRAFANA_TIME=$(curl -o /dev/null -s -w '%{time_total}\n' https://mon.ajinsights.com.au)
echo "Response time: ${GRAFANA_TIME}s"
[ $(echo "$GRAFANA_TIME < 2" | bc) -eq 1 ] && echo "✓ PASS" || echo "✗ FAIL"

# Test 2: Health endpoint
echo ""
echo "Test: Health endpoint"
HEALTH_TIME=$(curl -o /dev/null -s -w '%{time_total}\n' https://mon.ajinsights.com.au/api/health)
echo "Response time: ${HEALTH_TIME}s"
[ $(echo "$HEALTH_TIME < 0.5" | bc) -eq 1 ] && echo "✓ PASS" || echo "✗ FAIL"

# Test 3: Prometheus query
echo ""
echo "Test: Prometheus query"
QUERY_TIME=$(curl -o /dev/null -s -w '%{time_total}\n' -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "https://mon.ajinsights.com.au/api/datasources/proxy/1/api/v1/query?query=up")
echo "Response time: ${QUERY_TIME}s"
[ $(echo "$QUERY_TIME < 1" | bc) -eq 1 ] && echo "✓ PASS" || echo "✗ FAIL"

# Test 4: Load testing with Apache Bench
echo ""
echo "Test: Load testing (100 requests, concurrency 10)"
ab -n 100 -c 10 -q https://mon.ajinsights.com.au/api/health 2>&1 | \
  grep -E "Requests per second|Time per request|Failed requests"
```

### 8.2 Load Testing

```bash
#!/bin/bash
# Load testing script

echo "=== Load Testing ==="

# Install dependencies
# apt-get install -y apache2-utils wrk

# Test with ab (Apache Bench)
echo "Running Apache Bench load test..."
ab -n 1000 -c 50 -t 30 https://mon.ajinsights.com.au/api/health

# Test with wrk
echo ""
echo "Running wrk load test..."
wrk -t4 -c100 -d30s https://mon.ajinsights.com.au/api/health

# Test Prometheus query endpoint
echo ""
echo "Testing Prometheus query under load..."
ab -n 500 -c 25 -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "https://mon.ajinsights.com.au/api/datasources/proxy/1/api/v1/query?query=up"
```

### 8.3 Resource Utilization Monitoring

**Objective**: Ensure deployment doesn't exceed resource limits.

```bash
#!/bin/bash
# Monitor resource usage during testing

echo "=== Resource Utilization ==="

# Get container stats
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Check Prometheus TSDB size
TSDB_SIZE=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "https://mon.ajinsights.com.au/api/datasources/proxy/1/api/v1/status/tsdb" | \
  jq -r '.data.dataSize')
echo ""
echo "Prometheus TSDB size: $TSDB_SIZE"

# Check memory usage
FREE_MEM=$(free -h | grep Mem | awk '{print $7}')
echo "Free memory: $FREE_MEM"
```

---

## 9. Security Testing

### 9.1 Security Validation Checklist

**Objective**: Ensure deployment follows security best practices.

#### Security Test Matrix:

| Test ID | Security Check | Test Method | Priority |
|---------|---------------|-------------|----------|
| SEC-001 | HTTPS enforced | Try HTTP access | Critical |
| SEC-002 | SSL certificate valid | OpenSSL check | Critical |
| SEC-003 | Default passwords changed | Login test | Critical |
| SEC-004 | Unauthenticated access blocked | curl without auth | Critical |
| SEC-005 | CORS properly configured | Browser DevTools | High |
| SEC-006 | Security headers present | curl -I | High |
| SEC-007 | No sensitive data in logs | docker logs | High |
| SEC-008 | Container running as non-root | docker inspect | Medium |
| SEC-009 | Secrets not in environment vars | docker inspect | High |
| SEC-010 | Network isolation | docker network inspect | Medium |

#### Automated Security Tests:

```bash
#!/bin/bash
# Security validation script

echo "=== Security Validation ==="

PASSED=0
FAILED=0

# SEC-001: HTTPS enforced
echo "Test: HTTPS enforcement"
HTTP_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" http://mon.ajinsights.com.au)
if [ "$HTTP_REDIRECT" == "301" ] || [ "$HTTP_REDIRECT" == "302" ]; then
  echo "✓ HTTP redirects to HTTPS"
  ((PASSED++))
else
  echo "✗ HTTP does not redirect (code: $HTTP_REDIRECT)"
  ((FAILED++))
fi

# SEC-002: SSL certificate valid
echo ""
echo "Test: SSL certificate validity"
SSL_VALID=$(echo | openssl s_client -servername mon.ajinsights.com.au \
  -connect mon.ajinsights.com.au:443 2>/dev/null | \
  openssl x509 -noout -checkend 0)
if echo "$SSL_VALID" | grep -q "will not expire"; then
  echo "✓ SSL certificate is valid"
  ((PASSED++))
else
  echo "✗ SSL certificate invalid or expired"
  ((FAILED++))
fi

# SEC-003: Authentication required
echo ""
echo "Test: Authentication enforcement"
UNAUTH_ACCESS=$(curl -s -o /dev/null -w "%{http_code}" \
  https://mon.ajinsights.com.au/api/dashboards/home)
if [ "$UNAUTH_ACCESS" == "401" ] || [ "$UNAUTH_ACCESS" == "302" ]; then
  echo "✓ Unauthenticated access blocked"
  ((PASSED++))
else
  echo "✗ Unauthenticated access allowed (code: $UNAUTH_ACCESS)"
  ((FAILED++))
fi

# SEC-004: Security headers
echo ""
echo "Test: Security headers"
HEADERS=$(curl -sI https://mon.ajinsights.com.au)

# Check for important security headers
if echo "$HEADERS" | grep -qi "X-Content-Type-Options"; then
  echo "✓ X-Content-Type-Options header present"
  ((PASSED++))
else
  echo "⚠ X-Content-Type-Options header missing"
fi

if echo "$HEADERS" | grep -qi "X-Frame-Options"; then
  echo "✓ X-Frame-Options header present"
  ((PASSED++))
else
  echo "⚠ X-Frame-Options header missing"
fi

if echo "$HEADERS" | grep -qi "Strict-Transport-Security"; then
  echo "✓ HSTS header present"
  ((PASSED++))
else
  echo "⚠ HSTS header missing"
fi

# SEC-005: Check for default passwords (if possible)
echo ""
echo "Test: Default password check"
DEFAULT_LOGIN=$(curl -s -u "admin:admin" \
  https://mon.ajinsights.com.au/api/user | jq -r '.login')
if [ "$DEFAULT_LOGIN" == "admin" ]; then
  echo "⚠ Default password may still be in use"
  ((FAILED++))
else
  echo "✓ Default password not accepted"
  ((PASSED++))
fi

# SEC-006: Container security
echo ""
echo "Test: Container security settings"
# This requires access to Docker on the host
if command -v docker &> /dev/null; then
  PRIVILEGED=$(docker inspect grafana 2>/dev/null | jq -r '.[0].HostConfig.Privileged')
  if [ "$PRIVILEGED" == "false" ]; then
    echo "✓ Grafana not running privileged"
    ((PASSED++))
  else
    echo "⚠ Grafana running privileged"
  fi
fi

echo ""
echo "=== Security Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
```

### 9.2 Vulnerability Scanning

```bash
#!/bin/bash
# Container vulnerability scanning

echo "=== Vulnerability Scanning ==="

# Scan with Trivy
echo "Scanning container images with Trivy..."
trivy image grafana/grafana:latest
trivy image prom/prometheus:latest
trivy image prom/node-exporter:latest

# Scan with Docker Scout (if available)
echo ""
echo "Scanning with Docker Scout..."
docker scout cves grafana/grafana:latest
```

---

## 10. Rollback Procedures

### 10.1 Rollback Strategy

**Objective**: Quick recovery if deployment fails.

#### Rollback Decision Tree:

```
Deployment Issue Detected
    |
    ├─> Critical services down?
    |   ├─> YES: Immediate rollback
    |   └─> NO: Continue to diagnostic
    |
    ├─> Data corruption?
    |   ├─> YES: Restore from backup + rollback
    |   └─> NO: Continue to diagnostic
    |
    ├─> Configuration issue?
    |   ├─> YES: Fix config and redeploy
    |   └─> NO: Continue to diagnostic
    |
    └─> Performance degradation?
        ├─> YES: Monitor and decide
        └─> NO: No action needed
```

### 10.2 Rollback Procedures

#### Procedure 1: Coolify UI Rollback

1. Log into Coolify dashboard
2. Navigate to mon.ajinsights.com.au application
3. Go to Deployments tab
4. Find previous successful deployment
5. Click "Redeploy" on previous version
6. Wait for deployment to complete
7. Run smoke tests to verify

#### Procedure 2: Manual Docker Rollback

```bash
#!/bin/bash
# Manual rollback procedure

echo "=== Starting Rollback Procedure ==="

# 1. Stop current deployment
echo "Step 1: Stopping current deployment..."
docker-compose -f docker-compose.coolify.yml down

# 2. Backup current configuration (just in case)
echo "Step 2: Backing up current config..."
BACKUP_DIR="/tmp/monitoring-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r prometheus grafana "$BACKUP_DIR/"
echo "Backup saved to: $BACKUP_DIR"

# 3. Restore previous configuration from git
echo "Step 3: Restoring previous configuration..."
git log --oneline -10  # Show recent commits
read -p "Enter commit hash to rollback to: " COMMIT_HASH
git checkout "$COMMIT_HASH" -- docker-compose.coolify.yml prometheus/ grafana/

# 4. Restart services
echo "Step 4: Restarting services..."
docker-compose -f docker-compose.coolify.yml up -d

# 5. Wait for services to stabilize
echo "Step 5: Waiting for services to stabilize..."
sleep 30

# 6. Run health checks
echo "Step 6: Running health checks..."
./tests/smoke-test.sh

echo ""
echo "Rollback procedure complete"
echo "Check service status with: docker-compose ps"
```

#### Procedure 3: Volume Restoration

```bash
#!/bin/bash
# Restore from volume backup

echo "=== Volume Restoration ==="

# List available backups
echo "Available backups:"
ls -lh /backup/monitoring/

read -p "Enter backup directory name: " BACKUP_NAME

# Stop services
docker-compose -f docker-compose.coolify.yml down

# Restore volumes
echo "Restoring Prometheus data..."
docker run --rm -v prometheus_data:/data -v /backup/monitoring/$BACKUP_NAME:/backup \
  alpine sh -c "cd /data && tar xzvf /backup/prometheus_data.tar.gz"

echo "Restoring Grafana data..."
docker run --rm -v grafana_data:/data -v /backup/monitoring/$BACKUP_NAME:/backup \
  alpine sh -c "cd /data && tar xzvf /backup/grafana_data.tar.gz"

# Restart services
docker-compose -f docker-compose.coolify.yml up -d

echo "Volume restoration complete"
```

### 10.3 Pre-Rollback Checklist

Before executing rollback:

- [ ] **Document the issue**: What went wrong?
- [ ] **Capture logs**: `docker-compose logs > failure-logs.txt`
- [ ] **Screenshot errors**: Save error messages
- [ ] **Export current config**: Backup before rollback
- [ ] **Notify stakeholders**: Inform team of rollback
- [ ] **Identify root cause**: Prevent recurrence
- [ ] **Test rollback in staging**: If possible

### 10.4 Post-Rollback Verification

```bash
#!/bin/bash
# Post-rollback verification

echo "=== Post-Rollback Verification ==="

# 1. Check all services running
echo "1. Checking service status..."
docker-compose ps

# 2. Run smoke test
echo ""
echo "2. Running smoke test..."
./tests/smoke-test.sh

# 3. Verify Grafana accessible
echo ""
echo "3. Verifying Grafana..."
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://mon.ajinsights.com.au)
[ "$GRAFANA_STATUS" == "200" ] && echo "✓ Grafana accessible" || echo "✗ Grafana not accessible"

# 4. Check data integrity
echo ""
echo "4. Checking data integrity..."
METRIC_COUNT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "https://mon.ajinsights.com.au/api/datasources/proxy/1/api/v1/label/__name__/values" | \
  jq '.data | length')
echo "Unique metrics: $METRIC_COUNT"

# 5. Verify dashboards
echo ""
echo "5. Verifying dashboards..."
DASHBOARD_COUNT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "https://mon.ajinsights.com.au/api/search?type=dash-db" | jq 'length')
echo "Dashboards loaded: $DASHBOARD_COUNT"

echo ""
echo "Post-rollback verification complete"
```

### 10.5 Rollback Decision Matrix

| Issue Severity | Symptoms | Action | Rollback Time |
|---------------|----------|--------|---------------|
| **Critical** | All services down, data loss, security breach | Immediate rollback | < 5 minutes |
| **High** | Major service down, no metrics, authentication broken | Quick rollback | < 15 minutes |
| **Medium** | Single service degraded, some dashboards broken | Fix or rollback | < 30 minutes |
| **Low** | Minor UI issues, cosmetic problems | Fix forward | No rollback |

---

## 11. Testing Execution Plan

### 11.1 Testing Timeline

**Pre-Deployment** (30 minutes):
1. Run deploy-test.sh (5 min)
2. Validate configurations (10 min)
3. Check Coolify prerequisites (5 min)
4. Backup current state (10 min)

**Deployment** (15 minutes):
1. Deploy via Coolify (10 min)
2. Monitor deployment logs (5 min)

**Post-Deployment** (60 minutes):
1. Run smoke-test.sh (5 min)
2. Run integration-test.sh (10 min)
3. Run Playwright tests (15 min)
4. Validate dashboards (15 min)
5. Performance testing (10 min)
6. Security validation (5 min)

**Total Estimated Time**: 105 minutes (1 hour 45 minutes)

### 11.2 Test Execution Order

```
1. Pre-Deployment Validation
   ├─ deploy-test.sh
   ├─ Configuration validation
   └─ Environment check

2. Coolify Deployment
   ├─ Deploy via Coolify UI
   └─ Monitor deployment progress

3. Initial Health Checks
   ├─ smoke-test.sh
   └─ Service endpoint validation

4. Integration Testing
   ├─ integration-test.sh
   ├─ Prometheus targets
   └─ Data flow validation

5. Browser Testing
   ├─ Playwright tests
   ├─ Chrome DevTools analysis
   └─ Visual regression

6. Metrics Validation
   ├─ Dashboard metrics
   ├─ Query validation
   └─ Alert rule testing

7. Performance Testing
   ├─ Response time benchmarks
   ├─ Load testing
   └─ Resource utilization

8. Security Testing
   ├─ HTTPS/SSL validation
   ├─ Authentication testing
   └─ Security headers

9. Final Verification
   ├─ All dashboards accessible
   ├─ All metrics flowing
   └─ No errors in logs

10. Sign-off
    ├─ Document results
    ├─ Create deployment report
    └─ Mark deployment successful
```

### 11.3 Test Reporting

**Template for Test Report**:

```markdown
# Coolify Deployment Test Report
## mon.ajinsights.com.au

**Date**: [Date]
**Tester**: [Name]
**Deployment Version**: [Version/Commit]

### Pre-Deployment Tests
- [ ] deploy-test.sh: PASS/FAIL
- [ ] Configuration validation: PASS/FAIL
- [ ] Environment ready: PASS/FAIL

### Deployment
- [ ] Coolify deployment: SUCCESS/FAIL
- [ ] Deployment time: [X] minutes
- [ ] Issues encountered: [None/Description]

### Smoke Tests
- [ ] All services running: PASS/FAIL
- [ ] Grafana accessible: PASS/FAIL
- [ ] Basic functionality: PASS/FAIL

### Integration Tests
- [ ] integration-test.sh: X/Y tests passed
- [ ] Prometheus targets: X/Y UP
- [ ] Data flow: PASS/FAIL

### Browser Tests
- [ ] Playwright tests: X/Y passed
- [ ] Page load times: Within limits/Exceeded
- [ ] Console errors: None/X errors

### Dashboard Validation
- [ ] System Overview: PASS/FAIL
- [ ] Docker Containers: PASS/FAIL
- [ ] Docker Monitoring: PASS/FAIL
- [ ] Deployments: PASS/FAIL
- [ ] App Services: PASS/FAIL

### Performance
- [ ] Response times: Within limits
- [ ] Load testing: PASS/FAIL
- [ ] Resource usage: Normal/High

### Security
- [ ] HTTPS enforced: PASS/FAIL
- [ ] SSL valid: PASS/FAIL
- [ ] Authentication: PASS/FAIL
- [ ] Security headers: PASS/FAIL

### Overall Result
**Status**: PASS/FAIL
**Ready for production**: YES/NO
**Issues to address**: [List]

### Recommendations
[Any recommendations for improvement]

### Sign-off
- [ ] All critical tests passed
- [ ] Documentation updated
- [ ] Stakeholders notified
```

---

## 12. Contact and Escalation

### 12.1 Issue Escalation Path

**Level 1** - Self-service debugging:
- Review logs: `docker-compose logs`
- Check this testing strategy document
- Run diagnostic scripts

**Level 2** - Team support:
- Contact DevOps team
- Share test results and logs
- Provide error screenshots

**Level 3** - Vendor support:
- Coolify support (if platform issue)
- Grafana community forums
- Prometheus mailing list

### 12.2 Emergency Contacts

**Deployment Team**:
- Primary: [Contact]
- Secondary: [Contact]
- On-call: [Contact]

**Stakeholders**:
- Product Owner: [Contact]
- Operations Lead: [Contact]

---

## 13. Appendix

### 13.1 Useful Commands Reference

```bash
# View all containers
docker ps -a | grep monitoring

# Follow logs
docker-compose logs -f

# Restart specific service
docker-compose restart grafana

# Check Prometheus config
curl -s http://prometheus:9090/api/v1/status/config | jq .

# Query Prometheus
curl -s "http://prometheus:9090/api/v1/query?query=up" | jq .

# Test Grafana API
curl -s -u admin:password https://mon.ajinsights.com.au/api/health | jq .

# Check SSL certificate
openssl s_client -connect mon.ajinsights.com.au:443 -servername mon.ajinsights.com.au

# View Docker networks
docker network ls
docker network inspect monitoring

# View volumes
docker volume ls
docker volume inspect prometheus_data
```

### 13.2 Troubleshooting Common Issues

**Issue**: Grafana shows "Bad Gateway"
- **Cause**: Grafana container not started or crashed
- **Solution**: `docker-compose restart grafana && docker-compose logs grafana`

**Issue**: "No data" in all dashboards
- **Cause**: Prometheus not scraping, datasource misconfigured
- **Solution**: Check Prometheus targets, verify datasource URL

**Issue**: SSL certificate error
- **Cause**: Let's Encrypt provisioning failed, domain not pointing to server
- **Solution**: Verify DNS, check Coolify SSL settings

**Issue**: Authentication loop
- **Cause**: Incorrect admin password, cookie issues
- **Solution**: Clear browser cache, verify environment variables

**Issue**: High memory usage
- **Cause**: Too many metrics, retention too long
- **Solution**: Reduce retention period, limit scrape targets

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-06 | Tester Agent | Initial comprehensive testing strategy |

---

**End of Testing Strategy Document**
