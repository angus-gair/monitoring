# Coolify Deployment Quick Start Guide

## Overview
This guide provides quick instructions for deploying the Grafana monitoring stack to Coolify at **mon.ajinsights.com.au**.

## Prerequisites
- Coolify instance is running and accessible
- Domain `mon.ajinsights.com.au` DNS is configured to point to Coolify server
- Git repository is set up and accessible from Coolify
- Docker Compose deployment type is available in Coolify

## 5-Minute Deployment

### Step 1: Validate Configuration (Local)
Before pushing to Git, validate your configuration:

```bash
cd /home/ghost/projects/grafana-monitoring
./scripts/coolify-validate.sh
```

If validation passes, proceed to Step 2.

### Step 2: Prepare Environment Variables
In Coolify dashboard, set these environment variables:

**Required:**
```
GRAFANA_ADMIN_USER=your-admin-username
GRAFANA_ADMIN_PASSWORD=your-secure-password-here
GRAFANA_ROOT_URL=https://mon.ajinsights.com.au
```

**Optional but recommended:**
```
TZ=Australia/Sydney
NODE_ENV=production
METRICS_PORT=9101
```

### Step 3: Create Coolify Project
1. Log into Coolify dashboard
2. Click **"New Project"**
3. Project name: `Grafana Monitoring`
4. Select **"Docker Compose"** deployment type

### Step 4: Connect Git Repository
1. Connect your Git repository (GitHub/GitLab/Bitbucket)
2. Select branch: `main`
3. Docker Compose file path: `docker-compose.coolify.yml`
4. Build directory: `.` (root)

### Step 5: Configure Domain
1. Set primary domain: `mon.ajinsights.com.au`
2. Enable **HTTPS/SSL** (Let's Encrypt)
3. Enable **Force HTTPS redirect**
4. Enable **Automatic SSL renewal**

### Step 6: Deploy
1. Click **"Deploy"** button
2. Monitor build logs
3. Wait for all services to start (2-5 minutes)
4. Check health status of all containers

### Step 7: Verify Deployment
Access Grafana at: **https://mon.ajinsights.com.au**

Login with credentials set in environment variables.

Check that:
- [ ] Login works
- [ ] Prometheus datasource is connected
- [ ] Dashboards are loading
- [ ] Metrics are being collected

## Service Architecture

```
mon.ajinsights.com.au (HTTPS)
           │
           ├─ Grafana:3000 (Main UI - Public)
           │
           └─ Prometheus:9090 (Internal)
                    │
                    ├─ Node Exporter:9100 (Host metrics)
                    ├─ cAdvisor:8080 (Container metrics)
                    ├─ NPM Exporter:9101 (Node.js metrics)
                    └─ Alertmanager:9093 (Alert routing)
```

## Health Check Endpoints

All services have health checks configured:

- **Grafana**: `http://grafana:3000/api/health`
- **Prometheus**: `http://prometheus:9090/-/healthy`
- **Node Exporter**: `http://node-exporter:9100/metrics`
- **cAdvisor**: `http://cadvisor:8080/healthz`
- **NPM Exporter**: `http://npm-exporter:9101/health`
- **Alertmanager**: `http://alertmanager:9093/-/healthy`

## Default Dashboards

After deployment, these dashboards will be available:

1. **System Overview** - Host system metrics (CPU, memory, disk, network)
2. **Docker Containers** - Container performance and resource usage
3. **Docker Monitoring** - Docker-specific views
4. **Deployments** - Deployment tracking
5. **App Services** - Application service monitoring

## Resource Requirements

**Minimum:**
- 4 CPU cores
- 4GB RAM
- 50GB disk space

**Recommended:**
- 8 CPU cores
- 8GB RAM
- 100GB disk space

## Persistent Volumes

Three volumes store persistent data:

- `prometheus_data` - Metrics storage (30-day retention)
- `grafana_data` - Dashboards, users, settings
- `alertmanager_data` - Alert state and silences

**Important:** Configure volume backups in Coolify settings!

## Port Mapping

Services are accessible internally on these ports:

| Service        | Internal Port | External Access        |
|----------------|---------------|------------------------|
| Grafana        | 3000          | via domain (HTTPS)     |
| Prometheus     | 9090          | Internal only          |
| Node Exporter  | 9100          | Internal only          |
| cAdvisor       | 8080          | Internal only          |
| NPM Exporter   | 9101          | Internal only          |
| Alertmanager   | 9093          | Internal only          |

Only Grafana is exposed publicly via the domain. All other services are internal.

## Security Checklist

- [ ] Changed Grafana admin password from default
- [ ] Enabled HTTPS/SSL
- [ ] Verified only Grafana is exposed publicly
- [ ] Set strong passwords (20+ characters)
- [ ] Configured Grafana to disable sign-up
- [ ] Reviewed Grafana user permissions
- [ ] Updated alertmanager.yml with production credentials
- [ ] Enabled automatic backups

## Troubleshooting

### Services Won't Start
```bash
# Check container status
docker ps -a

# View logs
docker-compose -f docker-compose.coolify.yml logs [service-name]

# Restart specific service
docker-compose -f docker-compose.coolify.yml restart [service-name]
```

### SSL Certificate Issues
- Wait 2-5 minutes for Let's Encrypt provisioning
- Verify DNS: `dig mon.ajinsights.com.au`
- Check Coolify/Traefik logs for SSL errors
- Ensure ports 80/443 are accessible from internet

### Metrics Not Appearing
1. Go to Prometheus targets: (access via Coolify proxy or port forward)
   ```bash
   docker exec prometheus wget -qO- http://localhost:9090/targets
   ```
2. Check if targets are "UP"
3. If DOWN, check service logs
4. Verify network connectivity between services

### Can't Login to Grafana
1. Verify environment variables are set correctly in Coolify
2. Check Grafana logs:
   ```bash
   docker-compose -f docker-compose.coolify.yml logs grafana
   ```
3. Reset password using Grafana CLI:
   ```bash
   docker exec grafana grafana-cli admin reset-admin-password newpassword
   ```

### Dashboard Not Loading
1. Check dashboard JSON files are valid
2. Verify provisioning directory is mounted
3. Restart Grafana:
   ```bash
   docker-compose -f docker-compose.coolify.yml restart grafana
   ```

## Maintenance Commands

### View All Logs
```bash
docker-compose -f docker-compose.coolify.yml logs -f
```

### Restart All Services
```bash
docker-compose -f docker-compose.coolify.yml restart
```

### Rebuild NPM Exporter
```bash
docker-compose -f docker-compose.coolify.yml build npm-exporter
docker-compose -f docker-compose.coolify.yml up -d npm-exporter
```

### Reload Prometheus Configuration
```bash
curl -X POST http://localhost:9090/-/reload
```
(Requires port forwarding or access from Coolify server)

### Check Service Health
```bash
# All services
docker ps --format "table {{.Names}}\t{{.Status}}"

# Specific service health
docker inspect [container-name] | grep -A 10 Health
```

### Backup Volumes
```bash
# Backup Grafana data
docker run --rm -v grafana_data:/data -v $(pwd):/backup ubuntu tar czf /backup/grafana_backup.tar.gz /data

# Backup Prometheus data
docker run --rm -v prometheus_data:/data -v $(pwd):/backup ubuntu tar czf /backup/prometheus_backup.tar.gz /data

# Backup Alertmanager data
docker run --rm -v alertmanager_data:/data -v $(pwd):/backup ubuntu tar czf /backup/alertmanager_backup.tar.gz /data
```

## Post-Deployment Tasks

After successful deployment:

1. **Configure Alerts**
   - Review `prometheus/alerts.yml`
   - Update thresholds for your environment
   - Test alert notifications

2. **Set Up Notifications**
   - Update `prometheus/alertmanager.yml` with real webhook URLs
   - Configure Slack/PagerDuty/Email integrations
   - Test notification delivery

3. **Customize Dashboards**
   - Adjust dashboard panels for your needs
   - Add custom metrics if needed
   - Export and save updated dashboards

4. **Schedule Backups**
   - Configure automatic volume backups in Coolify
   - Test restore procedure
   - Document backup locations

5. **Monitor Resource Usage**
   - Watch CPU/memory usage for 24-48 hours
   - Adjust resource limits if needed
   - Optimize retention policies if storage is constrained

## Support Resources

- **Project Documentation**: See `README.md` in repository
- **Full Deployment Checklist**: `COOLIFY_DEPLOYMENT_CHECKLIST.md`
- **Architecture Overview**: `docs/architecture-overview.md`
- **Configuration Guide**: `CLAUDE.md`

## Emergency Contacts

If you encounter critical issues:

1. Check Coolify dashboard for service status
2. Review container logs for errors
3. Consult the full deployment checklist
4. Check Grafana/Prometheus documentation
5. Review GitHub issues for similar problems

## Rollback Procedure

If deployment fails:

1. Access Coolify dashboard
2. Go to deployment history
3. Select previous working deployment
4. Click "Rollback"
5. Wait for rollback to complete
6. Verify services are healthy

## Success Criteria

Your deployment is successful when:

- [x] Grafana accessible at https://mon.ajinsights.com.au
- [x] SSL certificate valid and working
- [x] Login with admin credentials works
- [x] All containers are running and healthy
- [x] Metrics are being collected
- [x] Dashboards display data
- [x] No errors in service logs
- [x] All health checks passing

## Next Steps

After deployment:

1. Change default admin password (if not done)
2. Add additional users if needed
3. Configure SMTP for email alerts
4. Set up notification channels in Alertmanager
5. Customize dashboards for your use case
6. Schedule regular backups
7. Document any custom configurations
8. Set up monitoring for the monitoring stack itself

---

**Deployment Version**: 1.0
**Domain**: mon.ajinsights.com.au
**Last Updated**: 2025-10-06
