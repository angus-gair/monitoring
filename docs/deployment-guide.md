# Deployment Guide

## Overview

Step-by-step guide for deploying the monitoring stack with docker-compose.

---

## Prerequisites

### System Requirements
- **OS**: Ubuntu 24.04 LTS (verified)
- **CPU**: 4+ cores (6 cores available: i7-9750H)
- **RAM**: 8GB minimum (64GB available)
- **Disk**: 60GB free space (361GB available)
- **Docker**: 24.0+ with compose plugin
- **Ports**: 3000, 8080, 9090, 9100, 9101 available

### Software Dependencies
```bash
# Check Docker installation
docker --version  # >= 24.0
docker compose version  # >= 2.20

# Check available ports
sudo ss -tulpn | grep -E ':(3000|8080|9090|9100|9101)'
# Should return empty if ports are free

# Check disk space
df -h /var/lib/docker
# Should show at least 60GB free
```

---

## Project Structure

```
monitoring/
├── docker-compose.yml
├── prometheus/
│   ├── prometheus.yml
│   ├── rules/
│   │   ├── node-exporter.yml
│   │   ├── cadvisor.yml
│   │   └── npm-exporter.yml
│   └── alerts/
│       └── alerting-rules.yml
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── prometheus.yml
│   │   ├── dashboards/
│   │   │   └── dashboard-provider.yml
│   │   └── notifiers/
│   │       └── alertmanager.yml
│   └── dashboards/
│       ├── system-overview.json
│       ├── docker-containers.json
│       ├── nodejs-npm.json
│       ├── prometheus-stats.json
│       └── alerts-overview.json
├── npm-exporter/
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
├── .env
├── .env.example
└── docs/
    ├── architecture-overview.md
    ├── component-specifications.md
    ├── dashboard-requirements.md
    ├── security-architecture.md
    └── deployment-guide.md
```

---

## Installation Steps

### Step 1: Clone/Setup Project
```bash
cd /home/thunder/projects/monitoring

# Verify structure
ls -la
```

### Step 2: Configure Environment
```bash
# Copy example env file
cp .env.example .env

# Edit environment variables
nano .env
```

**Required Variables**:
```bash
# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<strong-password-here>

# Prometheus
PROMETHEUS_RETENTION_DAYS=30
PROMETHEUS_RETENTION_SIZE=45GB

# Monitoring Network
MONITORING_SUBNET=172.28.0.0/16

# Resource Limits
GRAFANA_MEMORY_LIMIT=512m
PROMETHEUS_MEMORY_LIMIT=2g
NODE_EXPORTER_MEMORY_LIMIT=128m
CADVISOR_MEMORY_LIMIT=256m
NPM_EXPORTER_MEMORY_LIMIT=256m
```

### Step 3: Create Directories
```bash
# Create necessary directories
mkdir -p prometheus/{rules,alerts}
mkdir -p grafana/{provisioning/{datasources,dashboards,notifiers},dashboards}
mkdir -p npm-exporter

# Set permissions
chmod 755 prometheus grafana npm-exporter
```

### Step 4: Build Custom Exporters (if any)
```bash
# Build NPM exporter (if custom)
cd npm-exporter
docker build -t npm-exporter:latest .
cd ..
```

### Step 5: Validate Configuration
```bash
# Validate docker-compose file
docker compose config

# Validate Prometheus config
docker run --rm -v $(pwd)/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:v2.54.0 \
  promtool check config /etc/prometheus/prometheus.yml

# Validate alert rules
docker run --rm -v $(pwd)/prometheus/rules:/etc/prometheus/rules \
  prom/prometheus:v2.54.0 \
  promtool check rules /etc/prometheus/rules/*.yml
```

### Step 6: Deploy Stack
```bash
# Pull images
docker compose pull

# Start services
docker compose up -d

# Verify containers are running
docker compose ps

# Expected output:
# NAME                    STATUS              PORTS
# monitoring-grafana      Up 10 seconds       0.0.0.0:3000->3000/tcp
# monitoring-prometheus   Up 10 seconds       0.0.0.0:9090->9090/tcp
# monitoring-node-exp     Up 10 seconds       9100/tcp
# monitoring-cadvisor     Up 10 seconds       8080/tcp
# monitoring-npm-exp      Up 10 seconds       9101/tcp
```

### Step 7: Verify Services

#### Check Prometheus Targets
```bash
# Access Prometheus UI
curl http://localhost:9090/-/healthy
# Expected: Prometheus is Healthy.

# Check targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Expected output:
# {"job":"prometheus","health":"up"}
# {"job":"node-exporter","health":"up"}
# {"job":"cadvisor","health":"up"}
# {"job":"npm-exporter","health":"up"}
```

#### Check Grafana
```bash
# Health check
curl http://localhost:3000/api/health
# Expected: {"commit":"...","database":"ok","version":"11.3.0"}

# Login
# Navigate to: http://localhost:3000
# Username: admin
# Password: <from .env file>
```

#### Check Exporters
```bash
# Node Exporter
curl http://localhost:9100/metrics | grep node_cpu_seconds_total | head -5

# cAdvisor
curl http://localhost:8080/metrics | grep container_cpu_usage_seconds_total | head -5

# NPM Exporter
curl http://localhost:9101/metrics | grep npm_processes_total
```

### Step 8: Import Dashboards

#### Automatic (via provisioning)
Dashboards are auto-imported on startup if placed in `grafana/dashboards/`

#### Manual Import
```bash
# Via Grafana UI:
# 1. Navigate to Dashboards > Import
# 2. Upload JSON file or paste JSON
# 3. Select Prometheus as data source
# 4. Click Import

# Via API:
for dashboard in grafana/dashboards/*.json; do
  curl -X POST \
    -H "Content-Type: application/json" \
    -u admin:${GRAFANA_ADMIN_PASSWORD} \
    -d @${dashboard} \
    http://localhost:3000/api/dashboards/db
done
```

### Step 9: Configure Alerts

#### Prometheus Alert Rules
```bash
# Verify rules are loaded
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].name'

# Expected: List of rule group names
```

#### Grafana Alerts
```bash
# Configure notification channels via UI:
# 1. Navigate to Alerting > Notification channels
# 2. Add channel (Email, Slack, PagerDuty, etc.)
# 3. Test notification
```

### Step 10: Security Hardening

#### Change Default Password
```bash
# First login, Grafana will prompt to change password
# Or via CLI:
docker exec monitoring-grafana grafana-cli admin reset-admin-password <new-password>
```

#### Configure Firewall
```bash
# Allow Grafana from localhost only
sudo ufw allow from 127.0.0.1 to any port 3000

# Allow Prometheus from localhost only
sudo ufw allow from 127.0.0.1 to any port 9090

# Deny external access to exporters (already in Docker network)
sudo ufw deny 9100
sudo ufw deny 8080
sudo ufw deny 9101

# Reload firewall
sudo ufw reload
```

#### Enable TLS (Optional)
See security-architecture.md for reverse proxy setup

---

## Post-Deployment Checks

### Health Checks Checklist
- [ ] All containers running (`docker compose ps`)
- [ ] Prometheus targets all "up" (http://localhost:9090/targets)
- [ ] Grafana accessible (http://localhost:3000)
- [ ] Dashboards loaded in Grafana
- [ ] Data source connected (Grafana > Configuration > Data Sources)
- [ ] Metrics flowing (check dashboard graphs)
- [ ] Alert rules loaded (Prometheus UI > Alerts)
- [ ] Disk space adequate (`df -h`)
- [ ] No errors in logs (`docker compose logs`)

### Verification Commands
```bash
# Container health
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Resource usage
docker stats --no-stream

# Logs (check for errors)
docker compose logs --tail=50 | grep -i error

# Network connectivity
docker compose exec grafana curl http://prometheus:9090/-/healthy
docker compose exec prometheus curl http://node-exporter:9100/metrics | head

# Data persistence
docker volume ls | grep monitoring
docker volume inspect monitoring_prometheus_data
```

---

## Operational Procedures

### Starting Services
```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d grafana
```

### Stopping Services
```bash
# Stop all services (data persists)
docker compose down

# Stop specific service
docker compose stop prometheus
```

### Restarting Services
```bash
# Restart all services
docker compose restart

# Restart specific service
docker compose restart grafana
```

### Updating Services
```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate

# Verify versions
docker compose images
```

### Viewing Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f grafana

# Last N lines
docker compose logs --tail=100 prometheus

# Since timestamp
docker compose logs --since=1h cadvisor
```

### Backup Procedures

#### Prometheus Data
```bash
# Create snapshot
docker exec monitoring-prometheus promtool tsdb snapshot /prometheus

# Backup snapshot
BACKUP_DIR=/home/thunder/backups/monitoring/prometheus/$(date +%F)
mkdir -p $BACKUP_DIR
sudo cp -r /var/lib/docker/volumes/monitoring_prometheus_data/_data/snapshots/latest $BACKUP_DIR/

# Compress
tar czf prometheus-backup-$(date +%F).tar.gz -C $BACKUP_DIR .
```

#### Grafana Configuration
```bash
# Backup SQLite database
BACKUP_DIR=/home/thunder/backups/monitoring/grafana/$(date +%F)
mkdir -p $BACKUP_DIR
docker exec monitoring-grafana sqlite3 /var/lib/grafana/grafana.db ".backup /tmp/grafana-backup.db"
docker cp monitoring-grafana:/tmp/grafana-backup.db $BACKUP_DIR/

# Backup dashboards (JSON)
cp -r grafana/dashboards $BACKUP_DIR/

# Compress
tar czf grafana-backup-$(date +%F).tar.gz -C $BACKUP_DIR .
```

#### Automated Backup Script
```bash
#!/bin/bash
# /home/thunder/scripts/backup-monitoring.sh

BACKUP_ROOT=/home/thunder/backups/monitoring
DATE=$(date +%F)

# Prometheus
mkdir -p $BACKUP_ROOT/prometheus/$DATE
docker exec monitoring-prometheus promtool tsdb snapshot /prometheus
sudo cp -r /var/lib/docker/volumes/monitoring_prometheus_data/_data/snapshots/latest \
  $BACKUP_ROOT/prometheus/$DATE/
tar czf $BACKUP_ROOT/prometheus-$DATE.tar.gz -C $BACKUP_ROOT/prometheus/$DATE .

# Grafana
mkdir -p $BACKUP_ROOT/grafana/$DATE
docker exec monitoring-grafana sqlite3 /var/lib/grafana/grafana.db ".backup /tmp/grafana-backup.db"
docker cp monitoring-grafana:/tmp/grafana-backup.db $BACKUP_ROOT/grafana/$DATE/
tar czf $BACKUP_ROOT/grafana-$DATE.tar.gz -C $BACKUP_ROOT/grafana/$DATE .

# Cleanup old backups (keep 30 days)
find $BACKUP_ROOT -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
```

### Restore Procedures

#### Prometheus Data
```bash
# Stop Prometheus
docker compose stop prometheus

# Restore data
sudo rm -rf /var/lib/docker/volumes/monitoring_prometheus_data/_data/*
sudo tar xzf prometheus-backup-YYYY-MM-DD.tar.gz \
  -C /var/lib/docker/volumes/monitoring_prometheus_data/_data/

# Fix permissions
sudo chown -R 65534:65534 /var/lib/docker/volumes/monitoring_prometheus_data/_data

# Start Prometheus
docker compose start prometheus
```

#### Grafana Configuration
```bash
# Stop Grafana
docker compose stop grafana

# Restore database
tar xzf grafana-backup-YYYY-MM-DD.tar.gz -C /tmp/
docker cp /tmp/grafana-backup.db monitoring-grafana:/var/lib/grafana/grafana.db

# Fix permissions
docker exec monitoring-grafana chown grafana:grafana /var/lib/grafana/grafana.db

# Start Grafana
docker compose start grafana
```

---

## Monitoring Operations

### Adding New Exporters

1. **Update Prometheus Config**
```yaml
# prometheus/prometheus.yml
scrape_configs:
  - job_name: 'new-exporter'
    static_configs:
      - targets: ['new-exporter:9102']
```

2. **Reload Prometheus**
```bash
# Hot reload
docker compose exec prometheus kill -HUP 1

# Or restart
docker compose restart prometheus
```

3. **Add to docker-compose.yml**
```yaml
services:
  new-exporter:
    image: exporter:latest
    networks:
      - monitoring
    ports:
      - "9102:9102"
```

### Creating Custom Dashboards

1. Design in Grafana UI
2. Export JSON
3. Save to `grafana/dashboards/`
4. Commit to Git

### Scaling Considerations

#### Vertical Scaling
```yaml
# Increase resources in docker-compose.yml
services:
  prometheus:
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 4g
```

#### Horizontal Scaling
- Prometheus Federation (multiple Prometheus instances)
- Grafana HA (multiple Grafana instances with shared DB)

---

## Troubleshooting

### Common Issues

#### Containers Not Starting
```bash
# Check logs
docker compose logs <service-name>

# Check resources
docker stats

# Check disk space
df -h /var/lib/docker
```

#### Metrics Not Appearing
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check exporter accessibility
docker compose exec prometheus curl http://node-exporter:9100/metrics

# Check network
docker network inspect monitoring_monitoring
```

#### Grafana Dashboards Blank
```bash
# Check data source
curl -u admin:password http://localhost:3000/api/datasources

# Test query
docker compose exec grafana curl http://prometheus:9090/api/v1/query?query=up

# Check time range (clock sync)
timedatectl
```

#### High Resource Usage
```bash
# Check container stats
docker stats

# Check Prometheus cardinality
curl http://localhost:9090/api/v1/status/tsdb

# Optimize scrape intervals
# Reduce retention period
# Disable unnecessary collectors
```

### Debug Mode

#### Enable Prometheus Debug Logging
```yaml
# docker-compose.yml
services:
  prometheus:
    command:
      - '--log.level=debug'
```

#### Enable Grafana Debug Logging
```yaml
# grafana.ini or env var
GF_LOG_LEVEL=debug
```

---

## Maintenance Schedule

### Daily
- [ ] Check container health
- [ ] Review critical alerts
- [ ] Monitor disk usage

### Weekly
- [ ] Update Docker images
- [ ] Review dashboard performance
- [ ] Check backup integrity
- [ ] Review security logs

### Monthly
- [ ] Audit user access
- [ ] Review alert rules
- [ ] Optimize queries
- [ ] Test disaster recovery
- [ ] Security scan

### Quarterly
- [ ] Review architecture
- [ ] Update documentation
- [ ] Performance tuning
- [ ] Capacity planning

---

## Support & Resources

### Documentation
- Project docs: `/home/thunder/projects/monitoring/docs/`
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
- Docker: https://docs.docker.com/

### Community
- Prometheus Users: https://groups.google.com/forum/#!forum/prometheus-users
- Grafana Community: https://community.grafana.com/
- Stack Overflow: Tags `prometheus`, `grafana`, `docker-compose`

### Issue Tracking
- Internal: Git repository issues
- Grafana: https://github.com/grafana/grafana/issues
- Prometheus: https://github.com/prometheus/prometheus/issues
