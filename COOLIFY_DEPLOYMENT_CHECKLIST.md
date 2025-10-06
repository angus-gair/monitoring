# Coolify Deployment Checklist

## Pre-Deployment Requirements

### 1. Domain Configuration
- [ ] Domain `mon.ajinsights.com.au` is registered and DNS is configured
- [ ] DNS A record points to Coolify server IP address
- [ ] DNS propagation is complete (check with `dig mon.ajinsights.com.au`)
- [ ] Coolify server is accessible and running

### 2. Environment Variables Setup
- [ ] Copy `.env.coolify.example` contents to Coolify environment variables
- [ ] Set `GRAFANA_ADMIN_USER` (must not be default 'admin')
- [ ] Set `GRAFANA_ADMIN_PASSWORD` (strong password, 20+ characters)
- [ ] Verify `GRAFANA_ROOT_URL=https://mon.ajinsights.com.au`
- [ ] Configure optional SMTP settings for email alerts
- [ ] Configure Alertmanager notification channels (Slack/PagerDuty/Email)

### 3. Repository Setup
- [ ] Repository is pushed to Git (GitHub/GitLab/Bitbucket)
- [ ] All configuration files are committed:
  - `docker-compose.coolify.yml`
  - `prometheus/prometheus.yml`
  - `prometheus/alerts.yml`
  - `prometheus/alertmanager.yml`
  - `grafana/provisioning/` directory
  - `grafana/dashboards/` directory
  - `exporters/npm-exporter/` directory

### 4. Server Prerequisites
- [ ] Coolify server has sufficient resources:
  - Minimum: 4 CPU cores, 4GB RAM, 50GB disk
  - Recommended: 8 CPU cores, 8GB RAM, 100GB disk
- [ ] Docker and Docker Compose are installed on Coolify server
- [ ] Server has access to pull required Docker images
- [ ] Required ports are available (or Coolify will handle port mapping):
  - 3000 (Grafana)
  - 9090 (Prometheus)
  - 9100 (Node Exporter)
  - 8080 (cAdvisor)
  - 9101 (NPM Exporter)
  - 9093 (Alertmanager)

## Coolify Configuration Steps

### 5. Create New Project in Coolify
- [ ] Log into Coolify dashboard
- [ ] Create new project named "Grafana Monitoring"
- [ ] Select "Docker Compose" as deployment type
- [ ] Connect to your Git repository
- [ ] Select branch (usually `main` or `master`)
- [ ] Set build pack to "Docker Compose"
- [ ] Specify docker-compose file: `docker-compose.coolify.yml`

### 6. Configure Coolify Settings

#### Domain Configuration
- [ ] Set primary domain: `mon.ajinsights.com.au`
- [ ] Enable HTTPS/SSL (Let's Encrypt automatic)
- [ ] Set SSL certificate provider to Let's Encrypt
- [ ] Enable automatic SSL renewal
- [ ] Enable force HTTPS redirect

#### Build Configuration
- [ ] Set build command: `docker-compose -f docker-compose.coolify.yml build`
- [ ] Enable build cache for faster rebuilds
- [ ] Set NPM exporter to rebuild on every deployment

#### Environment Variables
- [ ] Import all variables from `.env.coolify.example`
- [ ] Mark sensitive variables as "hidden" in Coolify UI:
  - `GRAFANA_ADMIN_PASSWORD`
  - Any SMTP passwords
  - Webhook URLs
  - API keys

#### Health Checks
- [ ] Verify Coolify recognizes health check endpoints:
  - Grafana: `http://grafana:3000/api/health`
  - Prometheus: `http://prometheus:9090/-/healthy`
  - Node Exporter: `http://node-exporter:9100/metrics`
  - cAdvisor: `http://cadvisor:8080/healthz`
  - NPM Exporter: `http://npm-exporter:9101/health`
  - Alertmanager: `http://alertmanager:9093/-/healthy`

#### Volume Configuration
- [ ] Verify persistent volumes are configured:
  - `prometheus_data` - for metrics storage
  - `grafana_data` - for dashboards and settings
  - `alertmanager_data` - for alert state
- [ ] Set backup policy for volumes (recommended: daily)
- [ ] Configure volume retention policy

### 7. Network Configuration
- [ ] Ensure monitoring network is created
- [ ] Verify all services are on the same network
- [ ] Check that Coolify proxy/Traefik is properly configured
- [ ] Test internal service communication

## Deployment Process

### 8. Initial Deployment
- [ ] Click "Deploy" in Coolify dashboard
- [ ] Monitor build logs for errors
- [ ] Wait for all services to start (check health checks)
- [ ] Verify all containers are running: `docker ps`
- [ ] Check container logs: `docker-compose -f docker-compose.coolify.yml logs`

### 9. Post-Deployment Verification

#### Service Health
- [ ] Grafana is accessible at https://mon.ajinsights.com.au
- [ ] Login with configured admin credentials works
- [ ] Prometheus datasource is connected (check in Grafana)
- [ ] All exporters are showing "UP" in Prometheus targets
- [ ] Dashboards are loading correctly
- [ ] Metrics are being collected (check dashboard graphs)

#### Endpoint Testing
Run these commands on the Coolify server:
```bash
# Grafana health
curl -k https://mon.ajinsights.com.au/api/health

# Prometheus health (internal)
docker exec prometheus wget -qO- http://localhost:9090/-/healthy

# Node Exporter metrics
docker exec node-exporter wget -qO- http://localhost:9100/metrics | head

# cAdvisor health
docker exec cadvisor wget -qO- http://localhost:8080/healthz

# NPM Exporter health
docker exec npm-exporter wget -qO- http://localhost:9101/health

# Alertmanager health
docker exec alertmanager wget -qO- http://localhost:9093/-/healthy
```

#### Dashboard Verification
- [ ] System Overview dashboard shows host metrics
- [ ] Docker Containers dashboard shows container metrics
- [ ] NPM/Node.js metrics are appearing
- [ ] All panels are displaying data (no "No Data" errors)
- [ ] Time series data is being recorded

#### Alert Verification
- [ ] Access Prometheus alerts: http://localhost:9090/alerts (via port forwarding or proxy)
- [ ] Verify alert rules are loaded
- [ ] Test an alert by triggering a condition
- [ ] Verify Alertmanager receives alerts
- [ ] Check alert notifications are sent to configured channels

### 10. Security Hardening
- [ ] Change default Grafana admin password (if not done already)
- [ ] Disable Grafana sign-up (already configured in docker-compose)
- [ ] Review Grafana user permissions and roles
- [ ] Configure Grafana authentication (LDAP/OAuth/SAML if needed)
- [ ] Review Prometheus access controls
- [ ] Ensure sensitive ports are not exposed publicly (only Grafana)
- [ ] Enable firewall rules on Coolify server
- [ ] Set up monitoring alerts for security events
- [ ] Review and update alertmanager.yml with production credentials
- [ ] Enable audit logging in Grafana

### 11. Monitoring and Maintenance Setup
- [ ] Configure backup schedule for volumes
- [ ] Set up log rotation
- [ ] Configure Prometheus data retention policy
- [ ] Set up monitoring alerts for the monitoring stack itself:
  - Disk space alerts
  - Service down alerts
  - High memory usage alerts
  - Failed health checks
- [ ] Document rollback procedure
- [ ] Set up monitoring for SSL certificate expiration
- [ ] Configure Coolify auto-deployment on Git push (if desired)

## Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check container status
docker ps -a

# Check logs
docker-compose -f docker-compose.coolify.yml logs [service-name]

# Check health status
docker inspect [container-name] | grep -A 10 Health
```

#### SSL Certificate Issues
- Wait 2-5 minutes for Let's Encrypt provisioning
- Check DNS propagation: `dig mon.ajinsights.com.au`
- Verify port 80/443 are accessible from internet
- Check Coolify/Traefik logs for SSL errors

#### Metrics Not Appearing
- Verify Prometheus targets are UP: http://localhost:9090/targets
- Check service logs for errors
- Test exporter endpoints directly
- Verify network connectivity between services

#### Volume Permission Issues
```bash
# Fix Grafana volume permissions
docker exec grafana chown -R 472:472 /var/lib/grafana

# Fix Prometheus volume permissions
docker exec prometheus chown -R 65534:65534 /prometheus

# Fix Alertmanager volume permissions
docker exec alertmanager chown -R 65534:65534 /alertmanager
```

#### Dashboard Not Loading
- Check Grafana logs: `docker-compose logs grafana`
- Verify provisioning directory is mounted
- Restart Grafana: `docker-compose restart grafana`
- Check dashboard JSON syntax

## Rollback Procedure

If deployment fails:
1. Access Coolify dashboard
2. Navigate to deployments history
3. Select previous successful deployment
4. Click "Rollback"
5. Monitor rollback process
6. Verify services are healthy

Or manually:
```bash
# Stop all services
docker-compose -f docker-compose.coolify.yml down

# Checkout previous commit
git checkout [previous-commit-hash]

# Redeploy
docker-compose -f docker-compose.coolify.yml up -d
```

## Success Criteria

Deployment is successful when:
- [ ] All containers are running and healthy
- [ ] Grafana is accessible via HTTPS at mon.ajinsights.com.au
- [ ] SSL certificate is valid and auto-renews
- [ ] All health checks are passing
- [ ] Metrics are being collected and stored
- [ ] Dashboards display current data
- [ ] Alerts are configured and functional
- [ ] No errors in any service logs
- [ ] Volumes are persisting data correctly
- [ ] Backup system is operational

## Post-Deployment Tasks

After successful deployment:
- [ ] Document any configuration changes
- [ ] Update team with login credentials (via secure channel)
- [ ] Schedule regular maintenance windows
- [ ] Set up monitoring notifications for the team
- [ ] Create runbook for common operations
- [ ] Test disaster recovery procedure
- [ ] Schedule first backup verification
- [ ] Monitor resource usage for 24-48 hours
- [ ] Fine-tune alert thresholds based on baseline metrics

## Support and Documentation

- Grafana Documentation: https://grafana.com/docs/
- Prometheus Documentation: https://prometheus.io/docs/
- Coolify Documentation: https://coolify.io/docs/
- Project README: `/home/ghost/projects/grafana-monitoring/README.md`
- Architecture Overview: `/home/ghost/projects/grafana-monitoring/docs/architecture-overview.md`

## Maintenance Schedule

- **Daily**: Check dashboard for anomalies
- **Weekly**: Review alert history and adjust thresholds
- **Monthly**:
  - Review and rotate logs
  - Check disk space usage
  - Verify backups are working
  - Update Docker images if needed
- **Quarterly**:
  - Review and update alert rules
  - Audit user access
  - Performance optimization
  - Update documentation
