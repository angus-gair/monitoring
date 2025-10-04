# Docker Monitoring Stack

Complete monitoring solution using Prometheus, Grafana, Node Exporter, cAdvisor, and custom NPM exporter.

## Architecture

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Node Exporter**: System-level metrics (CPU, memory, disk, network)
- **cAdvisor**: Docker container metrics
- **NPM Exporter**: Custom exporter for NPM/Node.js processes
- **Alertmanager**: Alert routing and management

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- 10GB disk space

### Installation

1. Clone or navigate to the monitoring directory:
```bash
cd /home/thunder/projects/monitoring
```

2. Configure environment variables (optional):
```bash
cp .env.example .env
# Edit .env with your settings
```

3. Start the stack:
```bash
docker-compose up -d
```

4. Verify services are running:
```bash
docker-compose ps
```

## Accessing Services

- **Grafana**: http://localhost:3000
  - Default credentials: admin/admin123
  - Change password on first login

- **Prometheus**: http://localhost:9090
  - Query interface and target status

- **Alertmanager**: http://localhost:9093
  - Alert management interface

- **Node Exporter**: http://localhost:9100/metrics
  - System metrics endpoint

- **cAdvisor**: http://localhost:8080
  - Container metrics UI

- **NPM Exporter**: http://localhost:9101/metrics
  - Custom NPM/Node.js metrics

## Pre-configured Dashboards

1. **System Overview** - CPU, memory, disk, network metrics
2. **Docker Containers** - Container resource usage and health

Access dashboards in Grafana at: http://localhost:3000/dashboards

## Metrics Collected

### System Metrics (Node Exporter)
- CPU usage and load
- Memory usage and swap
- Disk space and I/O
- Network traffic
- System uptime

### Container Metrics (cAdvisor)
- Container CPU usage
- Container memory usage
- Container network I/O
- Container filesystem usage
- Container count and status

### NPM/Node.js Metrics (Custom Exporter)
- Number of running NPM processes
- Number of running Node.js processes
- Process memory usage
- Process CPU usage
- Docker container count
- Package.json file count

## Alerting

Alerts are pre-configured for:
- High CPU usage (>80% for 5 minutes)
- High memory usage (>85% for 5 minutes)
- Low disk space (<15% available)
- Container down
- Service unavailable

Configure alerting channels in:
- `prometheus/alertmanager.yml` - Email, Slack, etc.

## Data Retention

- **Prometheus**: 30 days (configurable in docker-compose.yml)
- **Grafana**: Persistent storage via Docker volumes

## Management Commands

### Start services
```bash
docker-compose up -d
```

### Stop services
```bash
docker-compose down
```

### View logs
```bash
docker-compose logs -f [service-name]
```

### Restart a service
```bash
docker-compose restart [service-name]
```

### Rebuild services
```bash
docker-compose up -d --build
```

### Remove all data (WARNING: destructive)
```bash
docker-compose down -v
```

## Configuration Files

### Prometheus
- `prometheus/prometheus.yml` - Main configuration
- `prometheus/alerts.yml` - Alert rules
- `prometheus/alertmanager.yml` - Alert routing

### Grafana
- `grafana/provisioning/datasources/` - Data source configs
- `grafana/provisioning/dashboards/` - Dashboard provisioning
- `grafana/dashboards/` - Dashboard JSON files

### Exporters
- `exporters/npm-exporter/` - Custom NPM exporter source

## Troubleshooting

### Service won't start
```bash
# Check logs
docker-compose logs [service-name]

# Check service status
docker-compose ps
```

### Metrics not appearing
```bash
# Check Prometheus targets
# Visit: http://localhost:9090/targets

# Verify exporter endpoints
curl http://localhost:9100/metrics  # Node Exporter
curl http://localhost:8080/metrics  # cAdvisor
curl http://localhost:9101/metrics  # NPM Exporter
```

### Grafana dashboard not loading
```bash
# Restart Grafana
docker-compose restart grafana

# Check provisioning logs
docker-compose logs grafana | grep provisioning
```

### High resource usage
```bash
# Reduce Prometheus retention
# Edit docker-compose.yml, change --storage.tsdb.retention.time

# Reduce scrape frequency
# Edit prometheus/prometheus.yml, increase scrape_interval
```

## Customization

### Add new scrape targets

Edit `prometheus/prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:port']
```

### Create custom dashboards

1. Create dashboard in Grafana UI
2. Export JSON
3. Save to `grafana/dashboards/`
4. Restart Grafana to auto-import

### Add custom alerts

Edit `prometheus/alerts.yml`:
```yaml
groups:
  - name: my_alerts
    rules:
      - alert: MyAlert
        expr: my_metric > threshold
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alert description"
```

## Security Considerations

1. **Change default passwords** in `.env`
2. **Configure firewall** to restrict access
3. **Use HTTPS** in production (add reverse proxy)
4. **Secure Alertmanager** credentials
5. **Review alert recipients** before production use

## Performance Tuning

### For high-load systems:
- Increase Prometheus memory in docker-compose.yml
- Adjust scrape intervals based on needs
- Use recording rules for complex queries
- Enable metric relabeling to reduce cardinality

### For resource-constrained systems:
- Reduce retention time
- Increase scrape intervals
- Disable unused exporters
- Limit dashboard refresh rates

## Backup and Recovery

### Backup Prometheus data
```bash
docker-compose exec prometheus tar czf /tmp/prometheus-backup.tar.gz /prometheus
docker cp prometheus:/tmp/prometheus-backup.tar.gz ./backups/
```

### Backup Grafana data
```bash
docker-compose exec grafana tar czf /tmp/grafana-backup.tar.gz /var/lib/grafana
docker cp grafana:/tmp/grafana-backup.tar.gz ./backups/
```

## Monitoring Best Practices

1. **Set appropriate alert thresholds** based on baseline metrics
2. **Use labels** to organize metrics and alerts
3. **Create dashboards** for different audiences (dev, ops, business)
4. **Document runbooks** for alert responses
5. **Regular review** of metrics and alerts
6. **Test alerting** regularly

## Support

For issues and questions:
- Check logs: `docker-compose logs`
- Verify configuration files
- Review Prometheus targets: http://localhost:9090/targets
- Check Grafana provisioning: http://localhost:3000

## License

MIT
