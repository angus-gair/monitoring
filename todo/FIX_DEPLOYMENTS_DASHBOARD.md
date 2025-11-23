# Fix Plan: Deployments Dashboard Metrics

**Issue:** The Deployments Dashboard at https://mon.ajinsights.com.au/d/deployments/deployments-dashboard shows "No data" because the required deployment-tracking metrics are not being collected.

**Root Cause:** The dashboard expects custom deployment metrics that are not provided by the standard exporters (Node Exporter, cAdvisor, NPM Exporter).

**Status:** Planning Phase
**Priority:** Medium
**Complexity:** Medium-High
**Estimated Effort:** 4-8 hours

---

## Problem Analysis

### Missing Metrics

The deployments dashboard expects the following custom Prometheus metrics that do not currently exist:

| Metric Name | Type | Purpose | Example Labels |
|-------------|------|---------|----------------|
| `deployment_status` | Gauge | Current deployment status (0=failed, 1=success, 2=in_progress) | deployment, environment |
| `deployment_version` | Gauge | Current version number | deployment, environment |
| `deployment_timestamp` | Gauge | Unix timestamp of deployment | deployment, environment, version |
| `deployment_health_status` | Gauge | Health check status (0=unhealthy, 1=healthy) | deployment, environment |
| `deployment_info` | Info | General deployment metadata | deployment, environment, status, version |
| `deployment_cpu_usage_seconds` | Counter | CPU usage for deployment | deployment, environment |
| `deployment_memory_usage_bytes` | Gauge | Memory usage for deployment | deployment, environment |
| `deployment_rollback_count` | Counter | Number of rollbacks | deployment, environment |
| `deployment_health_check` | Gauge | Health check results by type | deployment, environment, check_type |
| `deployment_duration_seconds` | Histogram | Time taken to deploy | deployment, environment |
| `deployment_version_info` | Info | Version history with commit info | deployment, environment, version, commit_sha |

### Dashboard Queries

The dashboard uses these Prometheus queries:
```promql
# Status indicators
deployment_status{deployment=~"$deployment",environment=~"$environment"}
deployment_version{deployment=~"$deployment",environment=~"$environment"}
time() - deployment_timestamp{deployment=~"$deployment",environment=~"$environment"}
deployment_health_status{deployment=~"$deployment",environment=~"$environment"}

# Tables
deployment_info{deployment=~"$deployment",environment=~"$environment"}
deployment_health_check{deployment=~"$deployment",environment=~"$environment"}
deployment_version_info{deployment=~"$deployment",environment=~"$environment"}

# Time series
rate(deployment_cpu_usage_seconds{deployment=~"$deployment",environment=~"$environment"}[5m]) * 100
deployment_memory_usage_bytes{deployment=~"$deployment",environment=~"$environment"}
increase(deployment_rollback_count{deployment=~"$deployment",environment=~"$environment"}[1h])
deployment_duration_seconds{deployment=~"$deployment",environment=~"$environment"}

# Aggregations
count by (status) (deployment_status{deployment=~"$deployment",environment=~"$environment"})
```

---

## Solution Options

### Option 1: Create Deployment Tracker Exporter (Recommended)

**Approach:** Build a new custom Prometheus exporter that tracks deployments via:
- Docker container labels/annotations
- Git webhook integration
- CI/CD pipeline integration
- File-based state tracking

**Pros:**
- Purpose-built for deployment tracking
- Clean separation of concerns
- Can integrate with existing CI/CD systems
- Flexible data sources

**Cons:**
- Requires new exporter development
- Need to integrate with deployment process
- Additional service to maintain

**Implementation Complexity:** Medium-High

### Option 2: Extend NPM Exporter

**Approach:** Modify the existing NPM exporter to also track deployment metadata from:
- Docker container labels
- Environment variables
- Git information in containers

**Pros:**
- Leverages existing exporter
- Less overhead (one less service)
- Already has Docker socket access

**Cons:**
- Mixed responsibilities (NPM + deployments)
- May not capture all deployment events
- Limited to Docker-based deployments

**Implementation Complexity:** Medium

### Option 3: Use Pushgateway for Manual Tracking

**Approach:** Deploy Prometheus Pushgateway and push deployment metrics from deployment scripts/CI/CD

**Pros:**
- Simple to implement
- No custom exporter needed
- Works with any deployment method

**Cons:**
- Requires modifying deployment scripts
- Manual instrumentation needed
- Metrics may go stale if not updated

**Implementation Complexity:** Low-Medium

### Option 4: Modify Dashboard to Use Existing Metrics

**Approach:** Rewrite the dashboard to use metrics from cAdvisor, Node Exporter, or NPM Exporter

**Pros:**
- No new services required
- Uses existing data

**Cons:**
- Dashboard will be less deployment-focused
- Won't have deployment-specific context
- Loses original dashboard intent

**Implementation Complexity:** Low

---

## Recommended Approach: Option 1 (Deployment Tracker Exporter)

This provides the most accurate and purpose-built solution for deployment tracking.

---

## Implementation Plan

### Phase 1: Research & Design (1-2 hours)

**Tasks:**
1. ✅ Analyze dashboard requirements (COMPLETE - see above)
2. Research deployment tracking best practices
3. Design exporter architecture
4. Define data sources for metrics
5. Create metric specification document

**Deliverables:**
- Metric specification with exact format
- Architecture diagram
- Data source integration plan

### Phase 2: Core Exporter Development (2-3 hours)

**Tasks:**
1. Create new exporter directory structure
   ```
   exporters/deployment-exporter/
   ├── index.js
   ├── package.json
   ├── Dockerfile
   ├── collectors/
   │   ├── docker-collector.js
   │   ├── git-collector.js
   │   └── state-collector.js
   ├── config/
   │   └── default.json
   └── README.md
   ```

2. Implement metric collectors:
   - Docker label-based tracking
   - Container lifecycle monitoring
   - Git metadata extraction
   - State file management

3. Create Prometheus exporter endpoint
   - Express server on port 9102
   - `/metrics` endpoint
   - Health check endpoint `/health`

4. Build Docker image
   - Node.js base image
   - Volume mounts for Docker socket
   - Configuration management

**Technologies:**
- Node.js with Express
- prom-client (Prometheus client library)
- dockerode (Docker API client)
- simple-git (Git operations)

**Key Code Structure:**
```javascript
// index.js
const express = require('express');
const client = require('prom-client');
const DockerCollector = require('./collectors/docker-collector');
const GitCollector = require('./collectors/git-collector');

const app = express();
const register = new client.Registry();

// Define metrics
const deploymentStatus = new client.Gauge({
  name: 'deployment_status',
  help: 'Deployment status (0=failed, 1=success, 2=in_progress)',
  labelNames: ['deployment', 'environment']
});

// ... other metrics

// Collectors
const dockerCollector = new DockerCollector(register);
const gitCollector = new GitCollector(register);

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(9102, () => {
  console.log('Deployment exporter listening on port 9102');
});
```

**Deliverables:**
- Working exporter exposing metrics on port 9102
- Docker image
- Configuration files

### Phase 3: Docker Integration (1 hour)

**Tasks:**
1. Add deployment-exporter to docker-compose.production.yml
   ```yaml
   deployment-exporter:
     build: ./exporters/deployment-exporter
     container_name: monitoring-deployment-exporter
     restart: unless-stopped
     networks:
       - monitoring
     volumes:
       - /var/run/docker.sock:/var/run/docker.sock:ro
       - ./exporters/deployment-exporter/data:/app/data
     environment:
       - NODE_ENV=production
     healthcheck:
       test: ["CMD", "wget", "-q", "--spider", "http://localhost:9102/health"]
       interval: 30s
       timeout: 10s
       retries: 3
   ```

2. Add Prometheus scrape config
   ```yaml
   - job_name: 'deployment-exporter'
     static_configs:
       - targets: ['deployment-exporter:9102']
     scrape_interval: 30s
   ```

3. Rebuild and redeploy stack

**Deliverables:**
- Updated docker-compose.production.yml
- Updated prometheus.yml
- Service running and scraped

### Phase 4: Deployment Integration (1-2 hours)

**Tasks:**
1. Define deployment labeling standard
   ```yaml
   # Example Docker labels for deployments
   labels:
     deployment.name: "monitoring-stack"
     deployment.version: "1.2.3"
     deployment.environment: "production"
     deployment.timestamp: "1700000000"
     deployment.commit: "abc123def"
     deployment.status: "success"
   ```

2. Create deployment helper script
   ```bash
   #!/bin/bash
   # scripts/deploy-with-tracking.sh
   # Wraps docker-compose up with deployment labels
   ```

3. Update existing deployment scripts to add labels

4. Create webhook receiver (optional)
   - For GitHub/GitLab integration
   - Automatic deployment tracking

**Deliverables:**
- Deployment labeling standard documentation
- Helper scripts
- Integration guide

### Phase 5: Testing & Validation (1 hour)

**Tasks:**
1. Test metric collection
   ```bash
   curl http://localhost:9102/metrics | grep deployment_
   ```

2. Verify Prometheus scraping
   ```bash
   # Check Prometheus targets
   curl http://localhost:9091/api/v1/targets | jq

   # Query metrics
   curl 'http://localhost:9091/api/v1/query?query=deployment_status'
   ```

3. Test dashboard with sample data
   - Create test deployments with labels
   - Verify dashboard populates
   - Test filtering by deployment/environment

4. Create test suite
   - Unit tests for collectors
   - Integration tests with Docker
   - E2E dashboard tests

**Deliverables:**
- Test results
- Test suite
- Validation report

### Phase 6: Documentation (30 minutes)

**Tasks:**
1. Update main README.md
2. Create deployment-exporter README
3. Document deployment tracking workflow
4. Add troubleshooting guide
5. Update CLAUDE.md with new component

**Deliverables:**
- Complete documentation
- Usage examples
- Integration guide

---

## Alternative Quick Wins

If you want to see *something* on the dashboard quickly while building the full solution:

### Quick Win 1: Mock Data (15 minutes)

Create a simple mock exporter that returns sample deployment metrics:

```javascript
// exporters/mock-deployment-exporter/index.js
const express = require('express');
const app = express();

app.get('/metrics', (req, res) => {
  const metrics = `
# HELP deployment_status Deployment status
# TYPE deployment_status gauge
deployment_status{deployment="monitoring",environment="production"} 1
deployment_status{deployment="api",environment="production"} 1
deployment_status{deployment="frontend",environment="staging"} 2

# HELP deployment_version Current version
# TYPE deployment_version gauge
deployment_version{deployment="monitoring",environment="production"} 1.0.0
deployment_version{deployment="api",environment="production"} 2.3.1
deployment_version{deployment="frontend",environment="staging"} 3.0.0-beta

# HELP deployment_timestamp Deployment timestamp
# TYPE deployment_timestamp gauge
deployment_timestamp{deployment="monitoring",environment="production",version="1.0.0"} ${Math.floor(Date.now() / 1000) - 3600}
deployment_timestamp{deployment="api",environment="production",version="2.3.1"} ${Math.floor(Date.now() / 1000) - 7200}

# HELP deployment_info Deployment information
# TYPE deployment_info gauge
deployment_info{deployment="monitoring",environment="production",status="success",version="1.0.0"} 1
deployment_info{deployment="api",environment="production",status="success",version="2.3.1"} 1
deployment_info{deployment="frontend",environment="staging",status="in_progress",version="3.0.0-beta"} 1
`;
  res.set('Content-Type', 'text/plain');
  res.send(metrics);
});

app.listen(9102, () => console.log('Mock deployment exporter on 9102'));
```

This will populate the dashboard with sample data while you build the real solution.

### Quick Win 2: Use Container Labels (30 minutes)

Modify the NPM exporter to also expose deployment metadata from Docker container labels:

```javascript
// In exporters/npm-exporter/index.js
const deploymentInfo = new client.Gauge({
  name: 'deployment_info',
  help: 'Deployment information from container labels',
  labelNames: ['deployment', 'environment', 'version', 'status']
});

// In container inspection loop
if (container.Labels['deployment.name']) {
  deploymentInfo.set({
    deployment: container.Labels['deployment.name'],
    environment: container.Labels['deployment.environment'] || 'unknown',
    version: container.Labels['deployment.version'] || 'unknown',
    status: container.Labels['deployment.status'] || 'unknown'
  }, 1);
}
```

---

## Dependencies & Prerequisites

**Required Tools:**
- Node.js 18+ (for exporter development)
- Docker & Docker Compose (already installed)
- Git (already installed)

**Required Libraries:**
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^15.0.0",
    "dockerode": "^4.0.0",
    "simple-git": "^3.20.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^6.3.3"
  }
}
```

**Port Allocation:**
- 9102 - Deployment exporter metrics (internal only, no external exposure)

---

## Success Criteria

The deployment dashboard fix will be considered complete when:

1. ✅ All 11 metric types are being collected
2. ✅ Metrics are visible in Prometheus (`deployment_*` queries return data)
3. ✅ Dashboard displays data in all 13 panels
4. ✅ Variables (deployment, environment) populate from metrics
5. ✅ Filtering by deployment/environment works
6. ✅ Metrics update when deployments occur
7. ✅ Documentation is complete
8. ✅ Tests pass

---

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Docker socket access issues | High | Low | Test permissions early, use read-only mount |
| Metric cardinality explosion | Medium | Medium | Limit label values, use label whitelisting |
| Performance impact | Low | Low | Optimize collection intervals, cache data |
| Integration with CI/CD | Medium | Medium | Start with manual labels, add automation later |
| Stale metrics | Low | Medium | Implement TTL, clean up old deployments |

---

## Timeline

**Fast Track (Minimal):** 2-3 hours
- Mock exporter with sample data
- Basic metric exposure
- Dashboard functional with fake data

**Standard Track (Recommended):** 6-8 hours
- Full deployment exporter
- Docker label integration
- Real-time tracking
- Documentation

**Complete Track (Full Featured):** 12-16 hours
- Full exporter with all features
- CI/CD webhook integration
- Git metadata extraction
- Comprehensive testing
- Advanced features (rollback tracking, duration histograms)

---

## Next Steps

**Immediate Actions:**
1. Review this plan and approve approach
2. Decide between fast track (mock data) or standard track (real exporter)
3. Allocate development time

**First Development Steps:**
1. Create `exporters/deployment-exporter/` directory
2. Initialize Node.js project with dependencies
3. Implement basic metric exposure
4. Add to Docker Compose
5. Verify metrics in Prometheus
6. Test dashboard

**Questions to Answer:**
- What deployment systems are you currently using? (Docker Compose, GitHub Actions, etc.)
- Do you want automatic tracking or manual deployment labeling?
- Should the exporter integrate with existing CI/CD pipelines?
- What level of deployment history do you need? (last 10 deployments, 30 days, etc.)

---

## Files to Create/Modify

**New Files:**
```
exporters/deployment-exporter/
├── index.js
├── package.json
├── Dockerfile
├── .dockerignore
├── collectors/
│   ├── docker-collector.js
│   ├── git-collector.js
│   └── state-collector.js
├── config/
│   └── default.json
├── data/
│   └── .gitkeep
└── README.md

scripts/
└── deploy-with-tracking.sh

todo/
├── FIX_DEPLOYMENTS_DASHBOARD.md (this file)
└── DEPLOYMENT_EXPORTER_SPEC.md
```

**Modified Files:**
```
docker-compose.production.yml   - Add deployment-exporter service
prometheus/prometheus.yml       - Add scrape config
grafana/provisioning/           - May need datasource refresh
README.md                       - Document new exporter
CLAUDE.md                       - Add component info
```

---

## Cost-Benefit Analysis

**Costs:**
- Development time: 6-8 hours
- Ongoing maintenance: ~1 hour/month
- Resources: ~100MB RAM, negligible CPU

**Benefits:**
- Deployment visibility and tracking
- Historical deployment data
- Integration with monitoring stack
- Health check correlation
- Rollback detection
- CI/CD pipeline insights

**ROI:** High - deployment tracking is valuable for production systems

---

## References

**Documentation:**
- [Prometheus Exporters Guide](https://prometheus.io/docs/instrumenting/writing_exporters/)
- [prom-client Documentation](https://github.com/siimon/prom-client)
- [Docker API Documentation](https://docs.docker.com/engine/api/)

**Similar Projects:**
- [prometheus-deployment-exporter](https://github.com/RichiH/deployment_exporter)
- [kubernetes-deployment-exporter](https://github.com/giantswarm/deployment-exporter)

---

**Last Updated:** 2025-11-22
**Author:** Claude Code (deployment-head agent)
**Status:** Ready for Implementation
