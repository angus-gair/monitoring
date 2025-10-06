# Coolify Deployment Configuration Summary

**Date**: 2025-10-06
**Domain**: mon.ajinsights.com.au
**Deployment Platform**: Coolify
**Status**: Ready for Deployment

## Overview

This document summarizes the Coolify deployment configuration prepared for the Grafana monitoring stack. All necessary files have been created and validated.

## Files Created/Updated

### 1. docker-compose.coolify.yml
**Status**: UPDATED
**Location**: `/home/ghost/projects/grafana-monitoring/docker-compose.coolify.yml`

**Key Changes from Standard Configuration:**
- Added comprehensive health checks for all services
- Configured Coolify-specific labels for service management
- Added Traefik labels for automatic HTTPS/SSL routing
- Configured domain routing for mon.ajinsights.com.au
- Set Grafana as primary public-facing service
- Added security enhancements (user permissions, read-only volumes)
- Optimized for production deployment
- Added volume labels for Coolify management
- Configured external URLs for Alertmanager

**Services Configured:**
1. **Grafana** (Primary - Public via domain)
   - Port: 3000
   - Domain: mon.ajinsights.com.au
   - Health check: /api/health
   - Coolify labels: Enabled with domain routing
   - Traefik labels: HTTPS with Let's Encrypt

2. **Prometheus** (Backend - Internal)
   - Port: 9090
   - Health check: /-/healthy
   - WAL compression enabled
   - Admin API enabled

3. **Node Exporter** (Exporter - Internal)
   - Port: 9100
   - Health check: /metrics
   - Host metrics collection

4. **cAdvisor** (Exporter - Internal)
   - Port: 8080
   - Health check: /healthz
   - Container metrics collection
   - Privileged mode (required)

5. **NPM Exporter** (Custom Exporter - Internal)
   - Port: 9101
   - Health check: /health
   - Built from local Dockerfile
   - Node.js/NPM metrics

6. **Alertmanager** (Backend - Internal)
   - Port: 9093
   - Health check: /-/healthy
   - Alert routing and management

### 2. .env.coolify.example
**Status**: CREATED
**Location**: `/home/ghost/projects/grafana-monitoring/.env.coolify.example`

**Purpose**: Template for environment variables in Coolify

**Critical Variables:**
- `GRAFANA_ADMIN_USER` - Grafana admin username (REQUIRED)
- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password (REQUIRED)
- `GRAFANA_ROOT_URL` - Set to https://mon.ajinsights.com.au

**Optional Variables:**
- SMTP configuration for email alerts
- Database configuration (if using external DB)
- Alertmanager notification settings
- Timezone and logging settings

### 3. COOLIFY_DEPLOYMENT_CHECKLIST.md
**Status**: CREATED
**Location**: `/home/ghost/projects/grafana-monitoring/COOLIFY_DEPLOYMENT_CHECKLIST.md`

**Purpose**: Comprehensive step-by-step deployment guide

**Sections:**
1. Pre-Deployment Requirements (11 items)
2. Coolify Configuration Steps (7 sections)
3. Deployment Process (4 sections)
4. Post-Deployment Verification (detailed testing)
5. Security Hardening (10 items)
6. Monitoring and Maintenance Setup
7. Troubleshooting Guide
8. Rollback Procedure
9. Success Criteria
10. Post-Deployment Tasks

### 4. COOLIFY_QUICK_START.md
**Status**: CREATED
**Location**: `/home/ghost/projects/grafana-monitoring/COOLIFY_QUICK_START.md`

**Purpose**: Fast-track deployment guide (5-minute deployment)

**Contents:**
- Quick deployment steps (7 steps)
- Service architecture diagram
- Health check endpoints reference
- Default dashboards list
- Resource requirements
- Security checklist
- Common troubleshooting commands
- Maintenance commands

### 5. scripts/coolify-validate.sh
**Status**: CREATED
**Location**: `/home/ghost/projects/grafana-monitoring/scripts/coolify-validate.sh`
**Permissions**: Executable (755)

**Purpose**: Pre-deployment validation script

**Validation Checks (10 sections):**
1. Required files existence
2. Required directories existence
3. YAML syntax validation (if yamllint available)
4. Environment variables completeness
5. Docker Compose configuration validity
6. Required services presence
7. Health check configurations
8. Coolify labels verification
9. NPM Exporter build files
10. Volume and network configurations

**Validation Results:** ALL CHECKS PASSED ✓

## Environment Variables Required for Coolify

### Mandatory Variables
```bash
GRAFANA_ADMIN_USER=<your-admin-username>
GRAFANA_ADMIN_PASSWORD=<strong-password-20+chars>
GRAFANA_ROOT_URL=https://mon.ajinsights.com.au
```

### Recommended Variables
```bash
TZ=Australia/Sydney
NODE_ENV=production
METRICS_PORT=9101
```

### Optional Advanced Configuration
See `.env.coolify.example` for:
- SMTP/Email configuration
- Database configuration
- Alertmanager notification channels
- Additional Grafana settings

## Configuration Highlights

### Health Checks
All services configured with proper health checks:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3 attempts
- **Start period**: 20-60 seconds (service-dependent)

### Domain Configuration
- **Primary Domain**: mon.ajinsights.com.au
- **Protocol**: HTTPS (forced)
- **SSL**: Let's Encrypt (automatic)
- **Renewal**: Automatic
- **Public Access**: Grafana only (port 3000)

### Security Enhancements
1. Configuration files mounted read-only (`:ro`)
2. User permissions set for Prometheus/Alertmanager (65534:65534)
3. Grafana analytics and external features disabled
4. Sign-up disabled by default
5. Domain enforcement enabled
6. Gravatar and snapshots disabled

### Production Optimizations
1. WAL compression enabled for Prometheus
2. Admin API enabled for Prometheus
3. Lifecycle reload enabled
4. Proper logging configuration
5. Resource-appropriate retention (30 days)
6. Efficient health check intervals

### Coolify Labels
Services tagged with:
- `coolify.managed=true` - Coolify management
- `coolify.name` - Service identification
- `coolify.service` - Service type (main/backend/exporter)
- `coolify.domain` - Domain routing (Grafana only)
- `coolify.port` - Service port

### Traefik Labels (Grafana)
- Automatic HTTPS routing
- Let's Encrypt certificate resolver
- WebSecure entrypoint
- Host-based routing rule
- Load balancer configuration

## Persistent Volumes

Three volumes configured for data persistence:

1. **prometheus_data**
   - Purpose: Metrics storage
   - Retention: 30 days
   - Expected size: ~20-50GB (depends on cardinality)
   - Backup: CRITICAL

2. **grafana_data**
   - Purpose: Dashboards, users, settings
   - Expected size: ~1-5GB
   - Backup: CRITICAL

3. **alertmanager_data**
   - Purpose: Alert state, silences
   - Expected size: <1GB
   - Backup: RECOMMENDED

All volumes labeled for Coolify management.

## Network Configuration

**Network Name**: monitoring
**Driver**: bridge
**Managed**: By Coolify

**Internal Service Communication:**
- Services communicate using container names
- No external network access required (except Grafana)
- Prometheus scrapes all exporters via internal network
- Grafana queries Prometheus via internal network

## Port Mapping

| Service        | Internal Port | External Port | Public Access |
|----------------|---------------|---------------|---------------|
| Grafana        | 3000          | 3000          | Yes (via domain) |
| Prometheus     | 9090          | 9090          | No (internal)    |
| Node Exporter  | 9100          | 9100          | No (internal)    |
| cAdvisor       | 8080          | 8080          | No (internal)    |
| NPM Exporter   | 9101          | 9101          | No (internal)    |
| Alertmanager   | 9093          | 9093          | No (internal)    |

**Note**: Only Grafana is exposed via domain. All other services are internal-only.

## Resource Requirements

### Minimum Configuration
- **CPU**: 4 cores
- **RAM**: 4GB
- **Disk**: 50GB (with 30-day retention)

### Recommended Configuration
- **CPU**: 8 cores
- **RAM**: 8GB
- **Disk**: 100GB (for growth)

### Per-Service Allocation (Estimated)
- Prometheus: 2 cores, 2GB RAM
- Grafana: 1 core, 1GB RAM
- Node Exporter: 0.5 cores, 256MB RAM
- cAdvisor: 0.5 cores, 512MB RAM
- NPM Exporter: 0.5 cores, 256MB RAM
- Alertmanager: 0.5 cores, 256MB RAM

## Pre-Deployment Checklist

Before deploying to Coolify:

- [x] docker-compose.coolify.yml created and validated
- [x] Environment variables template created
- [x] Deployment checklist created
- [x] Quick start guide created
- [x] Validation script created and tested
- [x] All health checks configured
- [x] Domain configuration set
- [x] Coolify labels added
- [x] Traefik labels configured
- [x] Security settings applied
- [x] Volume configurations verified
- [x] Network configuration verified
- [ ] DNS configured for mon.ajinsights.com.au
- [ ] Git repository pushed
- [ ] Environment variables prepared
- [ ] Coolify project created

## Deployment Steps (High-Level)

1. **Pre-Deployment**
   - Run validation: `./scripts/coolify-validate.sh`
   - Commit and push to Git
   - Verify DNS configuration

2. **Coolify Setup**
   - Create new project in Coolify
   - Connect Git repository
   - Set environment variables
   - Configure domain settings

3. **Deploy**
   - Click Deploy button
   - Monitor build logs
   - Wait for services to start

4. **Post-Deployment**
   - Verify Grafana access
   - Check all health checks
   - Test dashboard functionality
   - Configure alerts and notifications

## Testing and Verification

### Automated Testing
Run validation script before deployment:
```bash
./scripts/coolify-validate.sh
```

Expected result: All checks pass ✓

### Manual Verification After Deployment
1. Access https://mon.ajinsights.com.au
2. Login with configured credentials
3. Check Prometheus datasource connection
4. Verify all dashboards load
5. Confirm metrics are being collected
6. Test alert rules
7. Verify health checks are passing

### Health Check Commands
See COOLIFY_QUICK_START.md for detailed health check commands.

## Rollback Plan

If deployment fails:

**Via Coolify UI:**
1. Access deployment history
2. Select previous working version
3. Click "Rollback"

**Manual Rollback:**
```bash
docker-compose -f docker-compose.coolify.yml down
git checkout <previous-commit>
docker-compose -f docker-compose.coolify.yml up -d
```

## Security Considerations

### Critical Security Tasks
1. ✓ Change Grafana admin password (via environment variable)
2. ✓ Disable Grafana sign-up
3. ✓ Enable HTTPS/SSL
4. ✓ Restrict public access to Grafana only
5. ⚠ Update alertmanager.yml with production credentials
6. ⚠ Configure SMTP with secure credentials
7. ⚠ Review and set user permissions in Grafana
8. ⚠ Enable audit logging

### Default Security Settings Applied
- Grafana analytics disabled
- Gravatar disabled
- External snapshots disabled
- Domain enforcement enabled
- HTTPS forced
- Configuration files read-only
- Proper user permissions (non-root)

## Maintenance and Operations

### Backup Strategy
- **Frequency**: Daily (recommended)
- **Volumes to backup**: All three (prometheus_data, grafana_data, alertmanager_data)
- **Retention**: 30 days minimum
- **Testing**: Monthly restore test

### Monitoring the Monitoring Stack
Set up alerts for:
- Disk space usage
- Service health status
- Failed health checks
- Memory/CPU usage
- SSL certificate expiration

### Update Strategy
- **Images**: Update monthly or as needed
- **Configuration**: Update via Git push (Coolify auto-deploys)
- **Dashboards**: Export, commit, redeploy
- **Alerts**: Update alerts.yml, reload Prometheus

## Known Limitations

1. **cAdvisor Privileged Mode**: Required for container metrics, granted in config
2. **NPM Exporter Build**: Requires Docker socket access, configured
3. **SSL Provisioning**: May take 2-5 minutes on first deployment
4. **Volume Permissions**: May need adjustment on first run (see troubleshooting)

## Support and Documentation

### Primary Documentation
- **Quick Start**: `COOLIFY_QUICK_START.md`
- **Full Checklist**: `COOLIFY_DEPLOYMENT_CHECKLIST.md`
- **Environment Template**: `.env.coolify.example`
- **Validation Script**: `scripts/coolify-validate.sh`

### Additional Resources
- Project README: `README.md`
- Architecture Overview: `docs/architecture-overview.md`
- CLAUDE.md: Project guidance for Claude Code

### External Documentation
- Grafana: https://grafana.com/docs/
- Prometheus: https://prometheus.io/docs/
- Coolify: https://coolify.io/docs/

## Next Steps

1. **Immediate Actions**
   - Review all created documentation
   - Prepare environment variable values
   - Verify DNS configuration
   - Push to Git repository

2. **Before Deployment**
   - Run validation script
   - Review security checklist
   - Prepare strong admin password
   - Review COOLIFY_DEPLOYMENT_CHECKLIST.md

3. **During Deployment**
   - Follow COOLIFY_QUICK_START.md
   - Monitor build logs
   - Check service health

4. **After Deployment**
   - Complete post-deployment verification
   - Configure alerts and notifications
   - Set up backups
   - Document any customizations

## Conclusion

The Grafana monitoring stack is now fully configured and ready for Coolify deployment. All necessary files have been created, validated, and documented. The configuration includes:

- Production-ready docker-compose configuration
- Comprehensive health checks for all services
- Proper domain and SSL configuration
- Security hardening
- Detailed deployment documentation
- Validation tooling
- Troubleshooting guides

**Status**: READY FOR DEPLOYMENT ✓

**Validation**: ALL CHECKS PASSED ✓

**Next Action**: Follow COOLIFY_QUICK_START.md to deploy

---

**Configuration Version**: 1.0
**Prepared By**: Hive Mind Coder Agent
**Date**: 2025-10-06
**Domain**: mon.ajinsights.com.au
