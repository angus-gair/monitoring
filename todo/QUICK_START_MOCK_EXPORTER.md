# Quick Start: Mock Deployment Exporter

**Purpose:** Get the deployments dashboard working immediately with sample data while you build the real solution.

**Time Required:** 15 minutes

---

## What This Does

Creates a simple mock exporter that returns sample deployment metrics. The dashboard will display this data, allowing you to:
- Verify the dashboard works correctly
- Understand what the dashboard shows
- Build the real exporter without time pressure
- Have working dashboards during development

---

## Step 1: Create Mock Exporter (5 min)

### 1.1 Create Directory

```bash
cd /home/ghost/projects/monitoring
mkdir -p exporters/mock-deployment-exporter
cd exporters/mock-deployment-exporter
```

### 1.2 Create package.json

```bash
cat > package.json << 'EOF'
{
  "name": "mock-deployment-exporter",
  "version": "1.0.0",
  "description": "Mock deployment metrics for testing",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF
```

### 1.3 Create index.js

```bash
cat > index.js << 'EOF'
const express = require('express');
const app = express();
const PORT = 9102;

// Generate timestamp for realistic "time since deployment"
const now = Math.floor(Date.now() / 1000);
const hour = 3600;
const day = 86400;

app.get('/metrics', (req, res) => {
  const metrics = `# HELP deployment_status Deployment status (0=failed, 1=success, 2=in_progress)
# TYPE deployment_status gauge
deployment_status{deployment="monitoring-stack",environment="production"} 1
deployment_status{deployment="api-gateway",environment="production"} 1
deployment_status{deployment="frontend",environment="production"} 1
deployment_status{deployment="database",environment="production"} 1
deployment_status{deployment="redis-cache",environment="staging"} 2
deployment_status{deployment="worker-service",environment="staging"} 1

# HELP deployment_version Current deployment version
# TYPE deployment_version gauge
deployment_version{deployment="monitoring-stack",environment="production"} 1.2.3
deployment_version{deployment="api-gateway",environment="production"} 2.5.0
deployment_version{deployment="frontend",environment="production"} 3.1.4
deployment_version{deployment="database",environment="production"} 5.7.0
deployment_version{deployment="redis-cache",environment="staging"} 7.0.0
deployment_version{deployment="worker-service",environment="staging"} 1.0.5

# HELP deployment_timestamp Unix timestamp when deployment occurred
# TYPE deployment_timestamp gauge
deployment_timestamp{deployment="monitoring-stack",environment="production",version="1.2.3"} ${now - 2 * hour}
deployment_timestamp{deployment="api-gateway",environment="production",version="2.5.0"} ${now - 5 * hour}
deployment_timestamp{deployment="frontend",environment="production",version="3.1.4"} ${now - 1 * day}
deployment_timestamp{deployment="database",environment="production",version="5.7.0"} ${now - 7 * day}
deployment_timestamp{deployment="redis-cache",environment="staging",version="7.0.0"} ${now - 30 * 60}
deployment_timestamp{deployment="worker-service",environment="staging",version="1.0.5"} ${now - 3 * day}

# HELP deployment_health_status Health check status (0=unhealthy, 1=healthy)
# TYPE deployment_health_status gauge
deployment_health_status{deployment="monitoring-stack",environment="production"} 1
deployment_health_status{deployment="api-gateway",environment="production"} 1
deployment_health_status{deployment="frontend",environment="production"} 1
deployment_health_status{deployment="database",environment="production"} 1
deployment_health_status{deployment="redis-cache",environment="staging"} 1
deployment_health_status{deployment="worker-service",environment="staging"} 1

# HELP deployment_info Deployment information
# TYPE deployment_info gauge
deployment_info{deployment="monitoring-stack",environment="production",status="success",version="1.2.3"} 1
deployment_info{deployment="api-gateway",environment="production",status="success",version="2.5.0"} 1
deployment_info{deployment="frontend",environment="production",status="success",version="3.1.4"} 1
deployment_info{deployment="database",environment="production",status="success",version="5.7.0"} 1
deployment_info{deployment="redis-cache",environment="staging",status="in_progress",version="7.0.0"} 1
deployment_info{deployment="worker-service",environment="staging",status="success",version="1.0.5"} 1

# HELP deployment_cpu_usage_seconds Total CPU usage for deployment
# TYPE deployment_cpu_usage_seconds counter
deployment_cpu_usage_seconds{deployment="monitoring-stack",environment="production"} ${Math.random() * 100 + 50}
deployment_cpu_usage_seconds{deployment="api-gateway",environment="production"} ${Math.random() * 200 + 100}
deployment_cpu_usage_seconds{deployment="frontend",environment="production"} ${Math.random() * 150 + 75}
deployment_cpu_usage_seconds{deployment="database",environment="production"} ${Math.random() * 300 + 200}
deployment_cpu_usage_seconds{deployment="redis-cache",environment="staging"} ${Math.random() * 50 + 25}
deployment_cpu_usage_seconds{deployment="worker-service",environment="staging"} ${Math.random() * 180 + 90}

# HELP deployment_memory_usage_bytes Memory usage in bytes
# TYPE deployment_memory_usage_bytes gauge
deployment_memory_usage_bytes{deployment="monitoring-stack",environment="production"} ${Math.floor(Math.random() * 500000000 + 300000000)}
deployment_memory_usage_bytes{deployment="api-gateway",environment="production"} ${Math.floor(Math.random() * 800000000 + 400000000)}
deployment_memory_usage_bytes{deployment="frontend",environment="production"} ${Math.floor(Math.random() * 400000000 + 200000000)}
deployment_memory_usage_bytes{deployment="database",environment="production"} ${Math.floor(Math.random() * 2000000000 + 1000000000)}
deployment_memory_usage_bytes{deployment="redis-cache",environment="staging"} ${Math.floor(Math.random() * 300000000 + 150000000)}
deployment_memory_usage_bytes{deployment="worker-service",environment="staging"} ${Math.floor(Math.random() * 600000000 + 300000000)}

# HELP deployment_rollback_count Number of rollbacks
# TYPE deployment_rollback_count counter
deployment_rollback_count{deployment="monitoring-stack",environment="production"} 0
deployment_rollback_count{deployment="api-gateway",environment="production"} 1
deployment_rollback_count{deployment="frontend",environment="production"} 0
deployment_rollback_count{deployment="database",environment="production"} 0
deployment_rollback_count{deployment="redis-cache",environment="staging"} 0
deployment_rollback_count{deployment="worker-service",environment="staging"} 2

# HELP deployment_health_check Health check results
# TYPE deployment_health_check gauge
deployment_health_check{deployment="monitoring-stack",environment="production",check_type="http"} 1
deployment_health_check{deployment="monitoring-stack",environment="production",check_type="tcp"} 1
deployment_health_check{deployment="api-gateway",environment="production",check_type="http"} 1
deployment_health_check{deployment="api-gateway",environment="production",check_type="tcp"} 1
deployment_health_check{deployment="frontend",environment="production",check_type="http"} 1
deployment_health_check{deployment="database",environment="production",check_type="tcp"} 1
deployment_health_check{deployment="redis-cache",environment="staging",check_type="tcp"} 1
deployment_health_check{deployment="worker-service",environment="staging",check_type="http"} 1

# HELP deployment_duration_seconds Time taken to deploy
# TYPE deployment_duration_seconds gauge
deployment_duration_seconds{deployment="monitoring-stack",environment="production"} ${Math.random() * 300 + 60}
deployment_duration_seconds{deployment="api-gateway",environment="production"} ${Math.random() * 180 + 45}
deployment_duration_seconds{deployment="frontend",environment="production"} ${Math.random() * 240 + 90}
deployment_duration_seconds{deployment="database",environment="production"} ${Math.random() * 600 + 300}
deployment_duration_seconds{deployment="redis-cache",environment="staging"} ${Math.random() * 120 + 30}
deployment_duration_seconds{deployment="worker-service",environment="staging"} ${Math.random() * 200 + 60}

# HELP deployment_version_info Version history with commit info
# TYPE deployment_version_info gauge
deployment_version_info{deployment="monitoring-stack",environment="production",version="1.2.3",commit_sha="abc123def"} 1
deployment_version_info{deployment="api-gateway",environment="production",version="2.5.0",commit_sha="def456ghi"} 1
deployment_version_info{deployment="frontend",environment="production",version="3.1.4",commit_sha="ghi789jkl"} 1
deployment_version_info{deployment="database",environment="production",version="5.7.0",commit_sha="jkl012mno"} 1
deployment_version_info{deployment="redis-cache",environment="staging",version="7.0.0",commit_sha="mno345pqr"} 1
deployment_version_info{deployment="worker-service",environment="staging",version="1.0.5",commit_sha="pqr678stu"} 1
`;

  res.set('Content-Type', 'text/plain; version=0.0.4');
  res.send(metrics);
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Mock deployment exporter is running' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Mock deployment exporter listening on port ${PORT}`);
  console.log(`Metrics: http://localhost:${PORT}/metrics`);
  console.log(`Health: http://localhost:${PORT}/health`);
});
EOF
```

### 1.4 Create Dockerfile

```bash
cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY index.js ./

EXPOSE 9102

CMD ["npm", "start"]
EOF
```

### 1.5 Create .dockerignore

```bash
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
EOF
```

---

## Step 2: Add to Docker Compose (3 min)

### 2.1 Edit docker-compose.production.yml

Add this service to your `docker-compose.production.yml`:

```bash
cd /home/ghost/projects/monitoring
```

Add this to the services section:

```yaml
  mock-deployment-exporter:
    build: ./exporters/mock-deployment-exporter
    container_name: monitoring-mock-deployment-exporter
    restart: unless-stopped
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9102/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Note:** You can use a text editor or add it with this command:

```bash
# This is just FYI - you'll need to edit the file manually
vim docker-compose.production.yml
# or
nano docker-compose.production.yml
```

---

## Step 3: Update Prometheus Config (2 min)

### 3.1 Edit prometheus/prometheus.yml

Add this scrape config:

```yaml
  - job_name: 'deployment-exporter'
    static_configs:
      - targets: ['mock-deployment-exporter:9102']
    scrape_interval: 30s
```

Add it after the existing exporters (npm-exporter, cadvisor, etc.)

---

## Step 4: Deploy (5 min)

### 4.1 Build and Start

```bash
cd /home/ghost/projects/monitoring

# Build the mock exporter
docker compose -f docker-compose.production.yml build mock-deployment-exporter

# Start the service
docker compose -f docker-compose.production.yml up -d mock-deployment-exporter

# Restart Prometheus to pick up new scrape config
docker compose -f docker-compose.production.yml restart prometheus
```

### 4.2 Verify Running

```bash
# Check service status
docker compose -f docker-compose.production.yml ps | grep mock

# Check logs
docker logs monitoring-mock-deployment-exporter

# Test metrics endpoint
curl http://localhost:9102/metrics | head -20
```

You should see deployment metrics output.

---

## Step 5: Verify in Prometheus (2 min)

### 5.1 Check Target

```bash
# Via curl
curl http://localhost:9091/api/v1/targets | jq '.data.activeTargets[] | select(.job=="deployment-exporter")'

# Or open in browser
# http://localhost:9091/targets
# Look for "deployment-exporter" job
```

Should show status "UP"

### 5.2 Query Metrics

```bash
# Test query
curl 'http://localhost:9091/api/v1/query?query=deployment_status' | jq

# Or use Prometheus web UI
# http://localhost:9091
# Query: deployment_status
```

Should return sample deployment data.

---

## Step 6: Check Dashboard (3 min)

### 6.1 Open Dashboard

Navigate to: https://mon.ajinsights.com.au/d/deployments/deployments-dashboard

(Or use internal IP if external access not working)

### 6.2 Verify Data Appears

You should now see:

**Top Row:**
- ✅ Deployment Status (showing "Success" or "In Progress")
- ✅ Current Version (showing version numbers)
- ✅ Time Since Deployment (showing elapsed time)
- ✅ Health Status (showing "Healthy")

**Deployment List Table:**
- ✅ Shows 6 sample deployments
- ✅ Different environments (production, staging)
- ✅ Different statuses

**Graphs:**
- ✅ CPU Usage by Deployment - should show lines
- ✅ Memory Usage by Deployment - should show lines
- ✅ Deployment Timeline - should show bars
- ✅ Other graphs populated

**Dropdowns:**
- ✅ Deployment filter - should have options
- ✅ Environment filter - should have options

### 6.3 Test Filtering

1. Select specific deployment from dropdown
2. Dashboard should update to show only that deployment
3. Select specific environment
4. Dashboard should filter further

---

## Success Criteria

✅ Mock exporter running
✅ Prometheus scraping successfully
✅ Metrics queryable in Prometheus
✅ Dashboard shows data in all panels
✅ Dropdowns populated with values
✅ Filtering works

---

## What's Next?

Now that you have a working dashboard with mock data:

1. **Understand the Dashboard** - Explore all panels and see what data is expected
2. **Build Real Exporter** - Follow `IMPLEMENTATION_CHECKLIST.md` to build the real solution
3. **Incremental Migration** - Replace mock data with real data panel by panel
4. **Remove Mock** - Once real exporter is complete, remove mock exporter

---

## Removing Mock Exporter Later

When ready to switch to real exporter:

```bash
# Stop mock exporter
docker compose -f docker-compose.production.yml stop mock-deployment-exporter

# Remove from docker-compose.production.yml
# (comment out or delete the mock-deployment-exporter service)

# Update Prometheus config to point to real exporter
# Change target from 'mock-deployment-exporter:9102' to 'deployment-exporter:9102'

# Restart
docker compose -f docker-compose.production.yml restart prometheus
```

---

## Troubleshooting

### Metrics Endpoint Not Responding

```bash
# Check if container is running
docker ps | grep mock-deployment

# Check logs for errors
docker logs monitoring-mock-deployment-exporter

# Test from inside network
docker exec monitoring-prometheus wget -qO- http://mock-deployment-exporter:9102/metrics
```

### Prometheus Not Scraping

```bash
# Check Prometheus config syntax
docker exec monitoring-prometheus promtool check config /etc/prometheus/prometheus.yml

# View Prometheus logs
docker logs monitoring-prometheus | grep deployment

# Restart Prometheus
docker compose -f docker-compose.production.yml restart prometheus
```

### Dashboard Still Shows "No Data"

1. Wait 30-60 seconds for scrape to occur
2. Refresh dashboard (F5)
3. Check time range (should be "Last 24h")
4. Verify metrics in Prometheus: `deployment_status`
5. Check datasource in Grafana settings

---

## Limitations of Mock Exporter

**This is temporary test data:**
- ❌ Metrics are static/random, not real
- ❌ Doesn't reflect actual deployments
- ❌ CPU/memory values are randomized
- ❌ Won't update when you deploy services
- ❌ Limited to 6 hardcoded deployments

**Use only for:**
- ✅ Testing dashboard functionality
- ✅ Understanding metric format
- ✅ Developing real exporter
- ✅ Demonstrating to stakeholders

---

## Summary

You now have:
- ✅ Working deployments dashboard
- ✅ Sample data showing all panels
- ✅ Understanding of expected metrics
- ✅ Time to build real solution without pressure

**Total Time:** ~15 minutes

**Next Step:** Review `FIX_DEPLOYMENTS_DASHBOARD.md` for full implementation plan

---

**Created:** 2025-11-22
**Purpose:** Quick dashboard demonstration
**Status:** Ready to use
