# Monitoring System Architecture

## Executive Summary

This document defines the architecture for a comprehensive monitoring solution built on Grafana, Prometheus, and specialized exporters. The system monitors host machine metrics, Docker containers, Node.js applications, and system services on Ubuntu 24.04.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         VISUALIZATION LAYER                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      Grafana (Port 3000)                       │  │
│  │  - Pre-configured Dashboards                                  │  │
│  │  - Alerting Engine                                            │  │
│  │  - User Management                                            │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │ HTTP/API Queries
                                  │
┌─────────────────────────────────────────────────────────────────────┐
│                        METRICS AGGREGATION LAYER                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Prometheus (Port 9090)                       │  │
│  │  - Time Series Database                                       │  │
│  │  - Scrape Orchestration                                       │  │
│  │  - Data Retention (30 days default)                           │  │
│  │  - Alert Rule Engine                                          │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
          ▲               ▲               ▲               ▲
          │               │               │               │
    Scrape Endpoints (15s interval)      │               │
          │               │               │               │
┌─────────────────────────────────────────────────────────────────────┐
│                         EXPORTERS LAYER                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │Node Exporter│  │  cAdvisor   │  │NPM Exporter │  │  Custom   │  │
│  │ Port 9100   │  │ Port 8080   │  │ Port 9101   │  │ Exporters │  │
│  │             │  │             │  │             │  │           │  │
│  │ • CPU       │  │ • Container │  │ • Process   │  │ • Service │  │
│  │ • Memory    │  │   Metrics   │  │   Metrics   │  │   Health  │  │
│  │ • Disk I/O  │  │ • Resource  │  │ • Node.js   │  │ • Custom  │  │
│  │ • Network   │  │   Usage     │  │   Runtime   │  │   Apps    │  │
│  │ • Filesystem│  │ • Docker    │  │ • NPM Stats │  │           │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │
└─────────────────────────────────────────────────────────────────────┘
          │               │               │               │
          ▼               ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         TARGET SYSTEMS                               │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     Host Machine                             │   │
│  │  Ubuntu 24.04 LTS | i7-9750H | 64GB RAM | NVMe Storage      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   Docker Runtime                             │   │
│  │  Containers | Volumes | Networks | Images                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                 Application Services                         │   │
│  │  Node.js Apps | NPM Processes | System Services             │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## System Components

### 1. Grafana (Visualization Layer)
- **Version**: Latest stable (11.x)
- **Port**: 3000
- **Purpose**: Visualization, dashboarding, and alerting
- **Data Sources**: Prometheus
- **Storage**: SQLite (default) or PostgreSQL for production

### 2. Prometheus (Metrics Aggregation)
- **Version**: Latest LTS (2.x)
- **Port**: 9090
- **Purpose**: Time-series database and metrics aggregation
- **Scrape Interval**: 15 seconds
- **Retention**: 30 days (configurable)
- **Storage**: Local persistent volume

### 3. Node Exporter (System Metrics)
- **Version**: Latest (1.8.x)
- **Port**: 9100
- **Purpose**: Host machine metrics
- **Metrics Collected**:
  - CPU usage, load average
  - Memory utilization
  - Disk I/O and space
  - Network interfaces
  - Filesystem statistics
  - System uptime

### 4. cAdvisor (Container Metrics)
- **Version**: Latest (0.49.x)
- **Port**: 8080
- **Purpose**: Docker container monitoring
- **Metrics Collected**:
  - Container CPU usage
  - Memory consumption
  - Network I/O per container
  - Disk I/O per container
  - Container lifecycle events

### 5. NPM/Node.js Exporter (Custom)
- **Version**: Custom build
- **Port**: 9101
- **Purpose**: Monitor npm processes and Node.js applications
- **Metrics Collected**:
  - Process count and status
  - Node.js event loop lag
  - Memory heap usage
  - Active handles/requests
  - NPM registry operations

### 6. Custom Service Exporter (Optional)
- **Version**: Custom build
- **Port**: 9102+
- **Purpose**: Application-specific metrics
- **Extensible**: For future monitoring needs

## Network Architecture

### Port Allocation Strategy

| Component          | Internal Port | External Port | Protocol | Purpose                    |
|-------------------|---------------|---------------|----------|----------------------------|
| Grafana           | 3000          | 3000          | HTTP     | Web UI                     |
| Prometheus        | 9090          | 9090          | HTTP     | Metrics API & UI           |
| Node Exporter     | 9100          | 9100          | HTTP     | Metrics endpoint           |
| NPM Exporter      | 9101          | 9101          | HTTP     | Metrics endpoint           |
| Custom Exporter   | 9102          | 9102          | HTTP     | Metrics endpoint           |
| cAdvisor          | 8080          | 8080          | HTTP     | Metrics endpoint & UI      |

### Network Topology

```
Docker Network: monitoring_network (bridge)
├── grafana (monitoring-grafana)
├── prometheus (monitoring-prometheus)
├── node-exporter (monitoring-node-exporter)
├── cadvisor (monitoring-cadvisor)
└── npm-exporter (monitoring-npm-exporter)

Host Network Access:
├── Node Exporter (host network mode for accurate metrics)
└── cAdvisor (privileged access to Docker socket)
```

## Data Flow Design

### 1. Metrics Collection Flow

```
Host System → Node Exporter → Prometheus → Grafana → User
Docker → cAdvisor → Prometheus → Grafana → User
NPM Processes → NPM Exporter → Prometheus → Grafana → User
```

### 2. Scrape Configuration

**Prometheus Scrape Jobs**:
1. **prometheus** (self-monitoring): 15s interval
2. **node-exporter**: 15s interval
3. **cadvisor**: 15s interval
4. **npm-exporter**: 30s interval
5. **custom-exporters**: 30s interval

### 3. Data Retention Strategy

- **Short-term**: 15 days @ 15s resolution
- **Medium-term**: 30 days @ 1m resolution (downsampled)
- **Alerting data**: Real-time + 7 days history

## Dashboard Requirements

### 1. System Overview Dashboard
**Metrics**:
- Overall system health score
- CPU utilization (6 cores)
- Memory usage (64GB total)
- Disk I/O and capacity
- Network throughput
- System uptime

**Panels**:
- CPU usage heatmap
- Memory usage gauge
- Disk space bar charts
- Network traffic graphs
- Top processes table

### 2. Docker Container Dashboard
**Metrics**:
- Container count and status
- Per-container CPU usage
- Per-container memory usage
- Container network I/O
- Container lifecycle events

**Panels**:
- Container status grid
- Resource usage comparison
- Container logs integration
- Restart count history

### 3. Node.js/NPM Dashboard
**Metrics**:
- Active npm processes
- Node.js event loop lag
- Heap memory usage
- Garbage collection stats
- Active connections

**Panels**:
- Process status table
- Memory heap visualization
- Event loop lag graph
- GC pause time histogram

### 4. Services Health Dashboard
**Metrics**:
- Service availability
- Response times
- Error rates
- Dependency health

**Panels**:
- Service status matrix
- SLA compliance gauges
- Error rate trends
- Latency percentiles

### 5. Alerts Dashboard
**Metrics**:
- Active alerts
- Alert history
- Firing rate trends
- Silence status

**Panels**:
- Alert severity breakdown
- Recent alerts timeline
- Alert acknowledgment status

## Security Considerations

### 1. Authentication & Authorization
- **Grafana**:
  - Default admin password changed on first boot
  - Role-based access control (RBAC)
  - OAuth/LDAP integration capability
- **Prometheus**:
  - Internal network only (no external exposure)
  - Basic auth for external access (if needed)

### 2. Network Security
- **Docker Network Isolation**: Dedicated bridge network
- **Firewall Rules**: Only necessary ports exposed
- **TLS/SSL**: Optional for production (reverse proxy recommended)

### 3. Data Security
- **Sensitive Metrics**: Scrub credentials from labels
- **Volume Permissions**: Proper file ownership (UID/GID mapping)
- **Secrets Management**: Docker secrets or environment files

### 4. Container Security
- **Non-root Users**: Run containers as non-root when possible
- **Read-only Filesystems**: Where applicable
- **Resource Limits**: CPU/memory constraints defined
- **Image Scanning**: Use official images, scan for vulnerabilities

## Deployment Strategy

### 1. Infrastructure as Code
- **Docker Compose**: Primary deployment method
- **Version Control**: All configs in Git
- **Environment Files**: Separate configs from code

### 2. Initialization Sequence
1. Create Docker network
2. Start Prometheus (with config)
3. Start exporters (node, cadvisor, npm)
4. Start Grafana (with provisioning)
5. Verify connectivity
6. Import dashboards

### 3. Health Checks
- **Prometheus**: `/-/healthy` endpoint
- **Grafana**: `/api/health` endpoint
- **Exporters**: `/metrics` endpoint availability

### 4. Backup & Recovery
- **Prometheus Data**: Volume snapshots
- **Grafana Config**: Database backup
- **Dashboard Definitions**: JSON exports in Git

## Performance Considerations

### 1. Resource Allocation

| Component       | CPU Limit | Memory Limit | Storage        |
|----------------|-----------|--------------|----------------|
| Grafana        | 1 core    | 512MB        | 1GB (config)   |
| Prometheus     | 2 cores   | 2GB          | 50GB (metrics) |
| Node Exporter  | 0.5 core  | 128MB        | None           |
| cAdvisor       | 0.5 core  | 256MB        | None           |
| NPM Exporter   | 0.5 core  | 256MB        | None           |

**Total**: ~4.5 cores, ~3.5GB RAM (out of 12 cores, 64GB available)

### 2. Optimization Strategies
- **Cardinality Control**: Limit label values
- **Scrape Interval Tuning**: Balance freshness vs. load
- **Query Optimization**: Use recording rules for complex queries
- **Data Retention**: Adjust based on storage capacity

## Scalability & Extensibility

### 1. Horizontal Scaling
- **Federation**: Connect multiple Prometheus instances
- **HA Setup**: Duplicate Prometheus for redundancy
- **Load Balancing**: Multiple Grafana instances

### 2. Extensibility Points
- **Custom Exporters**: Add new metrics sources
- **Alert Receivers**: Integrate with PagerDuty, Slack, etc.
- **Dashboard Templates**: Create reusable panels
- **Plugin System**: Grafana apps and datasources

## Maintenance & Operations

### 1. Monitoring the Monitor
- Prometheus self-monitoring metrics
- Grafana health checks
- Exporter availability alerts

### 2. Upgrade Strategy
- Rolling updates with minimal downtime
- Version pinning in docker-compose
- Test upgrades in staging first

### 3. Troubleshooting
- Container logs via `docker logs`
- Prometheus targets page for scrape status
- Grafana explore for ad-hoc queries

## Technology Versions

- **Grafana**: 11.3.0 or latest stable
- **Prometheus**: 2.54.0 or latest LTS
- **Node Exporter**: 1.8.2
- **cAdvisor**: 0.49.1
- **Docker Compose**: 3.8+ specification

## Conclusion

This architecture provides:
✅ Comprehensive monitoring coverage
✅ Production-ready configuration
✅ Scalable and extensible design
✅ Security-focused implementation
✅ Easy deployment via Docker Compose
✅ Pre-configured dashboards for immediate value
