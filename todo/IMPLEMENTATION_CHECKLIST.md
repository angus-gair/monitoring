# Deployments Dashboard Fix - Implementation Checklist

**Issue:** No metrics showing on deployments dashboard
**Plan:** See `FIX_DEPLOYMENTS_DASHBOARD.md` for detailed plan
**Quick Start:** Follow this checklist step-by-step

---

## Choose Your Path

### 🚀 Path A: Quick Mock Data (15 min)
Get the dashboard working with sample data immediately.

- [ ] Create mock exporter directory
- [ ] Copy mock exporter code (see plan)
- [ ] Add to docker-compose
- [ ] Add Prometheus scrape config
- [ ] Restart stack
- [ ] Verify dashboard shows data

**Next:** Build real exporter while dashboard displays mock data

### 🏗️ Path B: Real Exporter (6-8 hours)
Build the complete deployment tracking solution.

Continue with Phase 1 below.

---

## Phase 1: Research & Design ✏️

- [ ] Read full plan document (`FIX_DEPLOYMENTS_DASHBOARD.md`)
- [ ] Review dashboard requirements
- [ ] Decide on deployment tracking approach
- [ ] Define metric specification
- [ ] Design exporter architecture
- [ ] Create data source integration plan

**Decision Point:** Which metrics to implement first?
- [ ] Core metrics only (status, version, timestamp, info)
- [ ] Full metrics (includes CPU, memory, rollbacks, health checks)

---

## Phase 2: Core Exporter Development 💻

### 2.1 Setup

- [ ] Create directory structure
  ```bash
  mkdir -p exporters/deployment-exporter/{collectors,config,data}
  cd exporters/deployment-exporter
  npm init -y
  ```

- [ ] Install dependencies
  ```bash
  npm install express prom-client dockerode simple-git
  npm install --save-dev jest supertest
  ```

- [ ] Create basic project files
  - [ ] `index.js` - Main exporter
  - [ ] `package.json` - Dependencies
  - [ ] `Dockerfile` - Container image
  - [ ] `.dockerignore` - Build exclusions
  - [ ] `README.md` - Documentation

### 2.2 Core Metrics Implementation

- [ ] Create Express server
- [ ] Setup Prometheus client
- [ ] Implement `/metrics` endpoint
- [ ] Implement `/health` endpoint

**Minimum Viable Metrics:**
- [ ] `deployment_status` - Gauge
- [ ] `deployment_version` - Gauge
- [ ] `deployment_timestamp` - Gauge
- [ ] `deployment_info` - Info gauge

### 2.3 Docker Integration

- [ ] Create `collectors/docker-collector.js`
- [ ] Connect to Docker API
- [ ] Read container labels
- [ ] Extract deployment metadata
- [ ] Update metrics from container data

**Expected Labels:**
```yaml
deployment.name: "service-name"
deployment.version: "1.2.3"
deployment.environment: "production"
deployment.timestamp: "1700000000"
deployment.status: "success"
```

### 2.4 Testing

- [ ] Test locally with `npm start`
- [ ] Verify `/metrics` endpoint returns data
- [ ] Test with Docker containers
- [ ] Validate metric format

---

## Phase 3: Docker Integration 🐳

### 3.1 Docker Image

- [ ] Create Dockerfile
- [ ] Build image: `docker build -t deployment-exporter .`
- [ ] Test image: `docker run -p 9102:9102 deployment-exporter`
- [ ] Verify metrics accessible

### 3.2 Docker Compose

- [ ] Add service to `docker-compose.production.yml`
  ```yaml
  deployment-exporter:
    build: ./exporters/deployment-exporter
    container_name: monitoring-deployment-exporter
    restart: unless-stopped
    networks:
      - monitoring
    ports:
      - "9102:9102"  # For testing, remove in production
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./exporters/deployment-exporter/data:/app/data
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9102/health"]
  ```

- [ ] Start service: `docker compose -f docker-compose.production.yml up -d deployment-exporter`
- [ ] Check logs: `docker logs monitoring-deployment-exporter`
- [ ] Test endpoint: `curl http://localhost:9102/metrics`

### 3.3 Prometheus Configuration

- [ ] Edit `prometheus/prometheus.yml`
- [ ] Add scrape config:
  ```yaml
  - job_name: 'deployment-exporter'
    static_configs:
      - targets: ['deployment-exporter:9102']
    scrape_interval: 30s
  ```

- [ ] Reload Prometheus: `curl -X POST http://localhost:9091/-/reload`
- [ ] Or restart: `docker compose -f docker-compose.production.yml restart prometheus`
- [ ] Verify target: Check http://localhost:9091/targets
- [ ] Test query: `deployment_status` in Prometheus

---

## Phase 4: Deployment Integration 🏷️

### 4.1 Labeling Standard

- [ ] Document deployment label schema
- [ ] Create example deployment with labels
- [ ] Test metric collection from labeled containers

**Test Deployment:**
```bash
docker run -d \
  --label deployment.name=test-app \
  --label deployment.version=1.0.0 \
  --label deployment.environment=production \
  --label deployment.timestamp=$(date +%s) \
  --label deployment.status=success \
  nginx:latest
```

### 4.2 Helper Scripts

- [ ] Create `scripts/deploy-with-tracking.sh`
- [ ] Add deployment labeling to existing deployment scripts
- [ ] Test helper script with sample deployment

### 4.3 Update Production Deployment

- [ ] Modify production docker-compose to include labels
- [ ] Update monitoring stack deployment with labels
- [ ] Redeploy with labels

---

## Phase 5: Testing & Validation ✅

### 5.1 Metric Verification

- [ ] Verify metrics exposed: `curl http://localhost:9102/metrics | grep deployment_`
- [ ] Check Prometheus scraping: `curl http://localhost:9091/api/v1/targets`
- [ ] Query metrics in Prometheus:
  ```bash
  curl 'http://localhost:9091/api/v1/query?query=deployment_status'
  curl 'http://localhost:9091/api/v1/query?query=deployment_info'
  ```

### 5.2 Dashboard Testing

- [ ] Open dashboard: https://mon.ajinsights.com.au/d/deployments/deployments-dashboard
- [ ] Verify deployment dropdown populates
- [ ] Verify environment dropdown populates
- [ ] Check all panels for data:
  - [ ] Deployment Status (top left)
  - [ ] Current Version (top middle-left)
  - [ ] Time Since Deployment (top middle-right)
  - [ ] Health Status (top right)
  - [ ] Deployment List (table)
  - [ ] CPU Usage by Deployment (graph)
  - [ ] Memory Usage by Deployment (graph)
  - [ ] Deployment Status Distribution (pie chart)
  - [ ] Deployment Timeline (bar chart)
  - [ ] Deployment Rollbacks (graph)
  - [ ] Health Check Status (table)
  - [ ] Deployment Duration (graph)
  - [ ] Version History (table)

### 5.3 Integration Testing

- [ ] Deploy test service with labels
- [ ] Verify metrics update
- [ ] Check dashboard reflects new deployment
- [ ] Test filtering by deployment name
- [ ] Test filtering by environment

### 5.4 Edge Cases

- [ ] Test with no deployments
- [ ] Test with multiple deployments
- [ ] Test with mixed environments
- [ ] Test metric persistence across exporter restarts
- [ ] Test with containers without deployment labels

---

## Phase 6: Documentation 📚

- [ ] Update `README.md` with deployment exporter info
- [ ] Create `exporters/deployment-exporter/README.md`
- [ ] Document deployment labeling standard
- [ ] Add troubleshooting section
- [ ] Update `CLAUDE.md` with new component
- [ ] Create deployment tracking workflow guide
- [ ] Add examples and screenshots

**Documentation Checklist:**
- [ ] How to deploy with tracking labels
- [ ] Metric descriptions and examples
- [ ] Dashboard usage guide
- [ ] Troubleshooting common issues
- [ ] Integration with CI/CD

---

## Phase 7: Production Deployment 🚀

### 7.1 Pre-Deployment

- [ ] Run tests: `npm test`
- [ ] Check all services healthy
- [ ] Backup current configuration
- [ ] Review changes

### 7.2 Deployment

- [ ] Build production image
- [ ] Update docker-compose.production.yml
- [ ] Deploy: `docker compose -f docker-compose.production.yml up -d`
- [ ] Verify all services start
- [ ] Check exporter logs
- [ ] Verify Prometheus scraping

### 7.3 Post-Deployment

- [ ] Verify dashboard functional
- [ ] Check metrics collection
- [ ] Monitor for errors
- [ ] Update documentation
- [ ] Notify users

### 7.4 Remove Test Artifacts

- [ ] Remove port 9102 from docker-compose (keep internal only)
- [ ] Remove test containers
- [ ] Clean up mock exporter (if used)

---

## Optional Enhancements 🌟

**Advanced Features (if time permits):**

- [ ] Git metadata collection
  - [ ] Extract commit SHA from containers
  - [ ] Add branch information
  - [ ] Link to repository

- [ ] Health check integration
  - [ ] Ping deployment health endpoints
  - [ ] Track health check results
  - [ ] Alert on health failures

- [ ] Rollback detection
  - [ ] Detect version downgrades
  - [ ] Increment rollback counter
  - [ ] Track rollback reasons

- [ ] Deployment duration tracking
  - [ ] Record deployment start time
  - [ ] Calculate deployment duration
  - [ ] Histogram of deployment times

- [ ] CI/CD webhook integration
  - [ ] Receive deployment notifications
  - [ ] GitHub Actions integration
  - [ ] GitLab CI integration

- [ ] State persistence
  - [ ] Save deployment history to file
  - [ ] Restore state on restart
  - [ ] Clean up old entries

---

## Troubleshooting Common Issues 🔧

### Metrics Not Appearing

- [ ] Check exporter is running: `docker ps | grep deployment-exporter`
- [ ] Check exporter logs: `docker logs monitoring-deployment-exporter`
- [ ] Test metrics endpoint: `curl http://localhost:9102/metrics`
- [ ] Verify Prometheus target: http://localhost:9091/targets
- [ ] Check network connectivity: `docker exec monitoring-prometheus ping deployment-exporter`

### Dashboard Shows "No Data"

- [ ] Verify metrics in Prometheus: `deployment_status`
- [ ] Check time range (should have recent data)
- [ ] Verify variable queries work
- [ ] Check dashboard datasource configuration
- [ ] Refresh dashboard

### Docker Socket Permission Issues

```bash
# Fix permissions
sudo chmod 666 /var/run/docker.sock

# Or run exporter with proper user
docker compose -f docker-compose.production.yml exec deployment-exporter id
```

### High Cardinality Issues

- [ ] Limit number of tracked deployments
- [ ] Implement label filtering
- [ ] Add TTL for old metrics
- [ ] Use relabeling in Prometheus

---

## Success Verification ✓

**Final Checklist:**

- [ ] All core metrics implemented
- [ ] Exporter running in production
- [ ] Prometheus scraping successfully
- [ ] Dashboard displays data in all panels
- [ ] Variables (deployment, environment) work
- [ ] Filtering works correctly
- [ ] Deployment labeling standard documented
- [ ] Helper scripts created
- [ ] Documentation complete
- [ ] Tests passing
- [ ] Production deployment successful

**Dashboard Health Check:**
- [ ] Open https://mon.ajinsights.com.au/d/deployments/deployments-dashboard
- [ ] Select a deployment from dropdown (should have options)
- [ ] Select an environment from dropdown (should have options)
- [ ] All 13 panels should show data (not "No data")
- [ ] Time series graphs should show trends
- [ ] Tables should have rows

---

## Rollback Plan 🔄

If issues occur:

1. [ ] Stop deployment-exporter service
   ```bash
   docker compose -f docker-compose.production.yml stop deployment-exporter
   ```

2. [ ] Remove from Prometheus scrape config
   ```bash
   # Comment out deployment-exporter job in prometheus.yml
   docker compose -f docker-compose.production.yml restart prometheus
   ```

3. [ ] Dashboard will show "No data" but won't error

4. [ ] Fix issues and redeploy

---

## Timeline Estimates ⏱️

**Quick Win (Mock Data):** 15-30 minutes
**Minimum Viable:** 2-3 hours (core metrics only)
**Standard Implementation:** 6-8 hours (full featured)
**Complete with Enhancements:** 12-16 hours

---

## Current Status

**Status:** Planning Complete ✅
**Next Action:** Choose implementation path (Mock vs Real)
**Assigned To:** [Your Name]
**Started:** [Date]
**Target Completion:** [Date]

---

## Notes & Comments

[Add implementation notes, issues encountered, decisions made, etc.]

---

**Last Updated:** 2025-11-22
**Created By:** Claude Code
