# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based monitoring stack using Grafana, Prometheus, and specialized exporters to monitor system metrics, Docker containers, and Node.js/NPM processes. All services are containerized and orchestrated via Docker Compose.

## Common Commands

### Starting the Stack
```bash
./start.sh                    # Start all services with status checks
docker-compose up -d          # Start services directly
docker-compose up -d --build  # Rebuild and start (after exporter changes)
```

### Stopping the Stack
```bash
./stop.sh                     # Stop all services
docker-compose down           # Stop and remove containers
docker-compose down -v        # Stop and remove containers + volumes (DESTRUCTIVE)
```

### Verification and Testing
```bash
./verify.sh                        # Quick health check of all services
./tests/deploy-test.sh             # Pre-deployment configuration validation
./tests/integration-test.sh        # Full integration testing
./tests/smoke-test.sh              # Quick operational validation
```

### Viewing Logs
```bash
docker-compose logs -f                    # All services
docker-compose logs -f [service-name]     # Specific service
docker-compose logs -f prometheus grafana # Multiple services
```

### Restarting Services
```bash
docker-compose restart [service-name]  # Restart specific service
docker-compose restart                 # Restart all services
```

### Rebuilding Custom Exporters
```bash
docker-compose build npm-exporter      # Rebuild NPM exporter
docker-compose up -d --no-deps --build npm-exporter  # Rebuild and restart only npm-exporter
```

## Architecture

### Service Communication
All services run on a Docker bridge network named `monitoring`. Services communicate using their container names:
- `prometheus` scrapes metrics from `node-exporter:9100`, `cadvisor:8080`, `npm-exporter:9101`
- `grafana` queries data from `prometheus:9090`
- Internal container names include `monitoring-` prefix (e.g., `monitoring-prometheus`, `monitoring-grafana`)

### Port Mapping (Host → Container)
- Grafana: `3001:3000` (access at http://localhost:3001)
- Prometheus: `9091:9090` (access at http://localhost:9091)
- Node Exporter: `9100:9100`
- cAdvisor: `8080:8080`
- NPM Exporter: `9101:9101`
- Alertmanager: `9093:9093`

**Note**: External ports differ from internal ports in some cases. When editing Prometheus scrape configs, use internal container names and ports (e.g., `monitoring-node-exporter:9100`), not localhost ports.

### Data Persistence
Three Docker volumes store persistent data:
- `prometheus_data`: Time-series metrics (30-day retention)
- `grafana_data`: Dashboards, users, settings
- `alertmanager_data`: Alert state and silences

### Component Responsibilities
- **Prometheus**: Scrapes and stores metrics every 15 seconds, evaluates alert rules
- **Grafana**: Visualization layer with pre-provisioned dashboards
- **Node Exporter**: Exposes host system metrics (CPU, memory, disk, network)
- **cAdvisor**: Exposes Docker container metrics (requires privileged mode for cgroup access)
- **NPM Exporter**: Custom exporter for Node.js/NPM process metrics (built from `exporters/npm-exporter/`)
- **Alertmanager**: Routes and manages alerts from Prometheus

## Configuration Structure

### Prometheus Configuration
- **Main config**: `prometheus/prometheus.yml` - scrape targets, intervals, labels
- **Alert rules**: `prometheus/alerts.yml` - alert definitions (CPU, memory, disk, container health)
- **Alertmanager**: `prometheus/alertmanager.yml` - notification routing
- **Reload config**: `curl -X POST http://localhost:9091/-/reload` (requires `--web.enable-lifecycle` flag, already enabled)

### Grafana Configuration
- **Provisioning**: `grafana/provisioning/` - auto-configured datasources and dashboard providers
- **Dashboards**: `grafana/dashboards/*.json` - dashboard definitions
  - `system-overview.json`: Node Exporter metrics
  - `docker-containers.json`: Container metrics from cAdvisor
  - `docker-monitoring.json`: Docker-specific views
  - `deployments.json`: Deployment tracking
  - `app-services.json`: Application service monitoring
- **Credentials**: Default is `admin/admin`, configurable via `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD` env vars

### NPM Exporter (Custom Component)
- **Location**: `exporters/npm-exporter/`
- **Language**: Node.js with Express and prom-client
- **Entry point**: `index.js`
- **Dependencies**: Managed via `package.json`
- **Build**: Uses `Dockerfile` in the same directory
- **After changes**: Must rebuild with `docker-compose build npm-exporter && docker-compose up -d npm-exporter`

## Development Workflow

### Modifying Dashboards
1. Edit dashboards in Grafana UI
2. Export JSON via "Share" → "Export" → "Save to file"
3. Save to `grafana/dashboards/[dashboard-name].json`
4. Restart Grafana: `docker-compose restart grafana`
5. Dashboards auto-provision on startup

### Adding Prometheus Scrape Targets
1. Edit `prometheus/prometheus.yml`
2. Add new job under `scrape_configs`:
   ```yaml
   - job_name: 'my-service'
     static_configs:
       - targets: ['service-name:port']
   ```
3. Reload config: `curl -X POST http://localhost:9091/-/reload` OR restart Prometheus

### Adding Alert Rules
1. Edit `prometheus/alerts.yml`
2. Add rule to appropriate group
3. Validate syntax: `promtool check rules prometheus/alerts.yml` (requires promtool installed locally)
4. Reload: `curl -X POST http://localhost:9091/-/reload` OR restart Prometheus
5. Check rules: http://localhost:9091/rules

### Modifying NPM Exporter
1. Edit code in `exporters/npm-exporter/`
2. Test locally: `cd exporters/npm-exporter && npm install && npm start`
3. Rebuild Docker image: `docker-compose build npm-exporter`
4. Restart: `docker-compose up -d npm-exporter`
5. Verify metrics: `curl http://localhost:9101/metrics`

## Testing Strategy

The codebase includes three test scripts with distinct purposes:

1. **deploy-test.sh**: Pre-flight checks before deployment
   - Validates YAML syntax, file existence, port availability
   - Run before first deployment or after config changes

2. **integration-test.sh**: End-to-end validation after deployment
   - Tests service health, metric flow, datasource connectivity
   - Takes 60-90 seconds including service startup waits

3. **smoke-test.sh**: Quick operational verification
   - Fast health checks for critical endpoints
   - Takes 10-15 seconds, suitable for CI/CD and regular monitoring

**Recommended test order**: deploy-test → deploy → integration-test → smoke-test

## Troubleshooting

### Services Not Starting
```bash
docker-compose ps                    # Check container status
docker-compose logs [service-name]   # Check logs for errors
```

Common issues:
- Port conflicts: Check with `netstat -tulpn | grep [port]` or modify `docker-compose.yml` port mappings
- Permission errors: Ensure volumes have correct ownership
- Config syntax errors: Use `promtool check config prometheus/prometheus.yml` for Prometheus

### Metrics Not Appearing
1. Check Prometheus targets: http://localhost:9091/targets
2. Verify target status is "UP"
3. If DOWN, check network connectivity: `docker-compose exec prometheus ping [target-service]`
4. Test exporter endpoint: `curl http://localhost:[exporter-port]/metrics`

### Dashboards Not Loading
1. Check Grafana logs: `docker-compose logs grafana | grep provisioning`
2. Verify datasource: http://localhost:3001/datasources
3. Verify dashboard files in `grafana/dashboards/` are valid JSON
4. Restart Grafana: `docker-compose restart grafana`

### Prometheus Config Errors
- Container name mismatches: Use `monitoring-[service]` format in targets (e.g., `monitoring-node-exporter:9100`)
- Invalid YAML: Check indentation and structure
- Missing files: Ensure `alerts.yml` exists if referenced in `rule_files`

## Key Design Decisions

From `docs/adr-001-technology-selection.md`:
- Ubuntu 24.04 LTS host system
- Docker Compose for orchestration (simpler than Kubernetes for single-host setup)
- Prometheus for metrics (native support, efficient time-series storage)
- Grafana for visualization (rich ecosystem, flexible dashboards)
- cAdvisor for container metrics (official Google tool, comprehensive)
- Custom exporters for specialized needs (NPM/Node.js monitoring)

## Security Considerations

- Change default Grafana password before production use
- Alertmanager config contains placeholder credentials - update before enabling notifications
- Services exposed on localhost only by default
- For production: Add reverse proxy (nginx/Traefik) with TLS
- cAdvisor runs privileged for cgroup access - required for container metrics
- Volume permissions: Grafana runs as UID 472, Prometheus as UID 65534

## Performance Tuning

### Resource Allocation
Default limits (see `docker-compose.yml` for current settings):
- Prometheus: 2 cores, 2GB RAM, 50GB storage
- Grafana: 1 core, 512MB RAM
- Total stack: ~4.5 cores, ~3.5GB RAM

### Optimization Strategies
- Reduce retention: Modify `--storage.tsdb.retention.time` in Prometheus command args
- Increase scrape intervals: Edit `scrape_interval` in `prometheus/prometheus.yml`
- Disable unused collectors: Add `--no-collector.[name]` to Node Exporter command
- Limit cardinality: Avoid high-cardinality labels in custom exporters

## Documentation Structure

- `README.md`: User-facing quick start and reference
- `docs/architecture-overview.md`: System design and component relationships
- `docs/component-specifications.md`: Detailed technical specs for each service
- `docs/dashboard-requirements.md`: Dashboard design and metrics requirements
- `docs/security-architecture.md`: Security model and best practices
- `docs/deployment-guide.md`: Deployment procedures and considerations
- `tests/README.md`: Testing strategy and procedures
- `DEPLOYMENT_REPORT.md`: Deployment outcomes and verification results

## Important Notes

- The repository uses a `monitoring` Docker network - ensure services are on this network for inter-service communication
- Prometheus scrape config uses container names (e.g., `monitoring-grafana:3000`), not `localhost` or host ports
- Dashboard provisioning is automatic on Grafana startup - changes to JSON files require Grafana restart
- Alert rules evaluate every 15 seconds (matches `evaluation_interval`)
- Data retention is 30 days by default - plan storage accordingly
- NPM exporter requires access to Docker socket (`/var/run/docker.sock`) for container discovery
