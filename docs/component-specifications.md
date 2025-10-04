# Component Specifications

## Overview

Detailed technical specifications for each component in the monitoring stack.

---

## 1. Grafana

### Version & Image
- **Image**: `grafana/grafana:11.3.0`
- **Base**: Alpine Linux
- **Architecture**: amd64/arm64

### Resource Requirements
- **CPU**: 1 core (limit), 0.5 core (request)
- **Memory**: 512MB (limit), 256MB (request)
- **Storage**: 1GB persistent volume

### Port Configuration
- **3000**: HTTP web interface
- Internal only (within Docker network)

### Environment Variables
```yaml
GF_SECURITY_ADMIN_USER: admin
GF_SECURITY_ADMIN_PASSWORD: <secure-password>
GF_USERS_ALLOW_SIGN_UP: false
GF_SERVER_ROOT_URL: http://localhost:3000
GF_ANALYTICS_REPORTING_ENABLED: false
GF_ANALYTICS_CHECK_FOR_UPDATES: true
GF_INSTALL_PLUGINS: <plugin-list>
```

### Volume Mounts
- `/var/lib/grafana`: Data directory (persistent)
- `/etc/grafana/provisioning`: Provisioning configs (read-only)
- `/etc/grafana/dashboards`: Dashboard JSON files (read-only)

### Provisioning Structure
```
provisioning/
├── datasources/
│   └── prometheus.yaml
├── dashboards/
│   └── dashboard-provider.yaml
└── notifiers/
    └── alertmanager.yaml (optional)
```

### Health Check
- **Endpoint**: `http://localhost:3000/api/health`
- **Interval**: 30s
- **Timeout**: 5s
- **Retries**: 3

### Dependencies
- Prometheus (data source)

### Pre-configured Dashboards
1. System Overview (Node Exporter)
2. Docker Containers (cAdvisor)
3. Node.js/NPM Monitoring
4. Prometheus Stats
5. Alert Overview

---

## 2. Prometheus

### Version & Image
- **Image**: `prom/prometheus:v2.54.0`
- **Base**: Alpine Linux
- **Architecture**: amd64/arm64

### Resource Requirements
- **CPU**: 2 cores (limit), 1 core (request)
- **Memory**: 2GB (limit), 1GB (request)
- **Storage**: 50GB persistent volume (expandable)

### Port Configuration
- **9090**: HTTP API and web UI
- Internal + host access

### Configuration File
- **Location**: `/etc/prometheus/prometheus.yml`
- **Reload**: SIGHUP or `/-/reload` endpoint

### Key Configuration Sections

#### Global Settings
```yaml
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 15s
  external_labels:
    cluster: 'monitoring-local'
    environment: 'production'
```

#### Scrape Configs
```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'npm-exporter'
    static_configs:
      - targets: ['npm-exporter:9101']
```

### Storage Configuration
- **Path**: `/prometheus`
- **Retention Time**: 30 days
- **Retention Size**: 45GB
- **TSDB Options**:
  - Block duration: 2h
  - Compaction enabled

### Volume Mounts
- `/prometheus`: Time-series data (persistent)
- `/etc/prometheus`: Configuration files (read-only)
- `/etc/prometheus/rules`: Alert rules (read-only)

### Health Check
- **Endpoint**: `http://localhost:9090/-/healthy`
- **Interval**: 30s
- **Timeout**: 5s
- **Retries**: 3

### Alert Rules
- Location: `/etc/prometheus/rules/*.yml`
- Auto-reload on change

### Dependencies
- All exporters (scrape targets)

---

## 3. Node Exporter

### Version & Image
- **Image**: `prom/node-exporter:v1.8.2`
- **Base**: Scratch (minimal)
- **Architecture**: amd64/arm64

### Resource Requirements
- **CPU**: 0.5 core (limit), 0.1 core (request)
- **Memory**: 128MB (limit), 64MB (request)
- **Storage**: None (stateless)

### Port Configuration
- **9100**: HTTP metrics endpoint

### Command Arguments
```bash
--path.rootfs=/host
--path.procfs=/host/proc
--path.sysfs=/host/sys
--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
--collector.netclass.ignored-devices=^(veth|docker|br-).*
--collector.systemd
--collector.processes
```

### Volume Mounts
- `/host`: Host root filesystem (read-only)
- `/host/proc`: Host /proc (read-only)
- `/host/sys`: Host /sys (read-only)

### Network Mode
- **Mode**: Host network (for accurate network metrics)
- **Reason**: Access to host interfaces and stats

### Enabled Collectors
- arp, bcache, bonding, btrfs, conntrack
- cpu, cpufreq, diskstats, dmi, edac
- entropy, fibrechannel, filesystem, hwmon
- infiniband, ipvs, loadavg, mdadm, meminfo
- netclass, netdev, netstat, nfs, nfsd
- nvme, os, powersupplyclass, pressure
- rapl, schedstat, sockstat, softnet, stat
- systemd, tapestats, textfile, thermal_zone
- time, timex, udp_queues, uname, vmstat
- xfs, zfs

### Key Metrics Exposed
- `node_cpu_seconds_total`: CPU usage per core
- `node_memory_*`: Memory statistics
- `node_disk_*`: Disk I/O and space
- `node_network_*`: Network interface stats
- `node_filesystem_*`: Filesystem usage
- `node_load*`: System load averages
- `node_systemd_*`: Systemd unit status

### Health Check
- **Endpoint**: `http://localhost:9100/metrics`
- **Interval**: 30s
- **Timeout**: 5s

---

## 4. cAdvisor

### Version & Image
- **Image**: `gcr.io/cadvisor/cadvisor:v0.49.1`
- **Base**: Debian slim
- **Architecture**: amd64/arm64

### Resource Requirements
- **CPU**: 0.5 core (limit), 0.2 core (request)
- **Memory**: 256MB (limit), 128MB (request)
- **Storage**: None (stateless)

### Port Configuration
- **8080**: HTTP web UI and metrics endpoint

### Volume Mounts
```yaml
- /:/rootfs:ro
- /var/run:/var/run:ro
- /sys:/sys:ro
- /var/lib/docker/:/var/lib/docker:ro
- /dev/disk/:/dev/disk:ro
```

### Privileged Mode
- **Required**: Yes (for cgroup access)
- **Reason**: Read container statistics from cgroups

### Command Arguments
```bash
--housekeeping_interval=10s
--max_housekeeping_interval=15s
--event_storage_event_limit=default=0
--event_storage_age_limit=default=0
--disable_metrics=percpu,sched,tcp,udp,diskIO,accelerator,hugetlb,referenced_memory,cpu_topology,resctrl
--docker_only=false
--store_container_labels=true
--whitelisted_container_labels=com.docker.compose.project,com.docker.compose.service
```

### Key Metrics Exposed
- `container_cpu_usage_seconds_total`: CPU usage per container
- `container_memory_usage_bytes`: Memory usage
- `container_network_*`: Network I/O per container
- `container_fs_*`: Filesystem usage per container
- `container_spec_*`: Container specifications
- `container_last_seen`: Container lifecycle

### Label Preservation
- Docker Compose project name
- Docker Compose service name
- Container name
- Image name

### Health Check
- **Endpoint**: `http://localhost:8080/healthz`
- **Interval**: 30s
- **Timeout**: 5s

---

## 5. NPM/Node.js Exporter (Custom)

### Version & Image
- **Base Image**: `node:20-alpine`
- **Custom Build**: Required
- **Architecture**: amd64/arm64

### Resource Requirements
- **CPU**: 0.5 core (limit), 0.1 core (request)
- **Memory**: 256MB (limit), 128MB (request)
- **Storage**: None (stateless)

### Port Configuration
- **9101**: HTTP metrics endpoint

### Implementation Strategy

#### Option A: Node.js Process Exporter
- **Library**: `prom-client`
- **Features**:
  - Process-level metrics
  - Custom npm metrics
  - Event loop lag
  - GC statistics

#### Option B: Process Exporter + Script
- **Tool**: `process-exporter`
- **Config**: Monitor npm/node processes
- **Regex Patterns**: Match npm and node processes

### Metrics to Expose

#### Process Metrics
- `npm_processes_total`: Number of npm processes
- `npm_process_cpu_seconds`: CPU time per process
- `npm_process_memory_bytes`: Memory usage
- `npm_process_uptime_seconds`: Process uptime

#### Node.js Runtime Metrics (if instrumented)
- `nodejs_eventloop_lag_seconds`: Event loop lag
- `nodejs_heap_size_total_bytes`: Heap size
- `nodejs_heap_size_used_bytes`: Used heap
- `nodejs_external_memory_bytes`: External memory
- `nodejs_gc_duration_seconds`: GC pause time
- `nodejs_active_handles_total`: Active handles
- `nodejs_active_requests_total`: Active requests

### Volume Mounts
- `/proc:/host/proc:ro`: Access to host processes

### Health Check
- **Endpoint**: `http://localhost:9101/metrics`
- **Interval**: 30s
- **Timeout**: 5s

### Discovery Method
- Process scanning via /proc
- Socket/port scanning
- PID file monitoring
- Systemd integration (if applicable)

---

## 6. Custom Service Exporter (Future)

### Purpose
Monitor application-specific services and custom metrics

### Specifications
- **Port Range**: 9102-9199
- **Format**: Prometheus exposition format
- **Library**: Language-specific Prometheus client
- **Auto-discovery**: Service registration in Prometheus config

### Example Use Cases
- Database connection pools
- Message queue depths
- Cache hit rates
- Business metrics (transactions, users, etc.)

---

## Docker Compose Service Definitions

### Network
```yaml
networks:
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

### Volumes
```yaml
volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
```

### Restart Policies
- All services: `restart: unless-stopped`
- Ensures automatic recovery after host reboot

### Logging
```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

---

## Security Specifications

### Container User Permissions
- Grafana: UID 472 (grafana)
- Prometheus: UID 65534 (nobody)
- Node Exporter: Root required (host metrics)
- cAdvisor: Root required (cgroup access)

### Secrets Management
- Grafana admin password: Docker secret or env file
- API keys: Volume-mounted config files
- TLS certificates: Bind-mounted from host

### Network Policies
- Internal services: No external exposure
- Public services: Only Grafana (behind reverse proxy recommended)
- Exporters: Internal network only

---

## Backup Specifications

### Prometheus Data
- **Method**: Volume snapshot or rsync
- **Frequency**: Daily
- **Retention**: 7 daily, 4 weekly

### Grafana Configuration
- **Method**: Database dump (SQLite) or file copy
- **Frequency**: On change (CI/CD) + daily
- **Retention**: Git repository + 30 days backup

### Dashboard Definitions
- **Method**: JSON export via API or provisioning files
- **Storage**: Git repository
- **Versioning**: Semantic versioning

---

## Monitoring & Observability

### Self-Monitoring
- Prometheus monitors itself
- Grafana has datasource health dashboard
- Exporter up/down status tracked

### Alerts for Infrastructure
- Prometheus down
- Grafana datasource unavailable
- Exporter scrape failures
- Disk space low (< 10% free)
- Memory pressure (> 90% used)

---

## Upgrade Strategy

### Grafana
1. Backup database
2. Pull new image
3. Stop container
4. Start with new image
5. Verify dashboards
6. Test datasource connectivity

### Prometheus
1. Snapshot data volume
2. Pull new image
3. Test config with `--config.check`
4. Restart with new image
5. Verify scrape targets
6. Check query performance

### Exporters
- Blue/green deployment (start new, stop old)
- Minimal downtime (metrics may have gaps)
- Verify metric compatibility

---

## Performance Tuning

### Prometheus Optimizations
- Limit cardinality (label values)
- Use recording rules for expensive queries
- Adjust scrape intervals based on metric volatility
- Enable compression for remote storage

### Grafana Optimizations
- Use query result caching
- Limit dashboard auto-refresh intervals
- Use variables for dynamic filters
- Pre-compute aggregations

### Exporter Optimizations
- Disable unnecessary collectors
- Increase scrape timeout if needed
- Use separate exporters per concern
- Batch metric collection

---

## Compliance & Standards

### Metric Naming
- Follow Prometheus naming conventions
- Use consistent label names
- Avoid reserved labels (`__name__`, `job`, `instance`)

### Dashboard Standards
- Consistent color schemes
- Meaningful panel titles
- Include descriptions
- Use template variables
- Set appropriate refresh rates

### Alert Standards
- Severity levels (critical, warning, info)
- Actionable descriptions
- Runbook links
- Meaningful labels for routing
