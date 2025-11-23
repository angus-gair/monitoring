# Coolify Deployment - README

## Quick Links

- **Quick Start**: [COOLIFY_QUICK_START.md](COOLIFY_QUICK_START.md) - Deploy in 5 minutes
- **Full Checklist**: [COOLIFY_DEPLOYMENT_CHECKLIST.md](COOLIFY_DEPLOYMENT_CHECKLIST.md) - Comprehensive guide
- **Configuration Summary**: [COOLIFY_DEPLOYMENT_SUMMARY.md](COOLIFY_DEPLOYMENT_SUMMARY.md) - Overview of all changes
- **Environment Variables**: [.env.coolify.example](.env.coolify.example) - Template for Coolify
- **Validation Script**: [scripts/coolify-validate.sh](scripts/coolify-validate.sh) - Pre-deployment validation

## Domain
**mon.ajinsights.com.au**

## What's Been Configured

This Grafana monitoring stack is ready for Coolify deployment with:

- ✓ Production-ready docker-compose configuration
- ✓ Automatic HTTPS/SSL via Let's Encrypt
- ✓ Health checks for all 6 services
- ✓ Coolify management labels
- ✓ Domain routing configured
- ✓ Security hardening applied
- ✓ Complete documentation

## Services

1. **Grafana** - Main monitoring UI (Public via domain)
2. **Prometheus** - Metrics storage (Internal)
3. **Node Exporter** - Host system metrics (Internal)
4. **cAdvisor** - Container metrics (Internal)
5. **NPM Exporter** - Custom Node.js metrics (Internal)
6. **Alertmanager** - Alert management (Internal)

## Quick Start

### 1. Validate Configuration
```bash
./scripts/coolify-validate.sh
```

### 2. Set Environment Variables in Coolify
Required variables:
- `GRAFANA_ADMIN_USER` - Your admin username
- `GRAFANA_ADMIN_PASSWORD` - Strong password (20+ chars)
- `GRAFANA_ROOT_URL` - https://mon.ajinsights.com.au

### 3. Deploy
1. Create Docker Compose project in Coolify
2. Point to this repository
3. Use `docker-compose.coolify.yml`
4. Set domain to `mon.ajinsights.com.au`
5. Enable HTTPS/SSL
6. Deploy

### 4. Verify
Access: https://mon.ajinsights.com.au

## Environment Variables

See [.env.coolify.example](.env.coolify.example) for complete list.

**Mandatory:**
```
GRAFANA_ADMIN_USER=your-username
GRAFANA_ADMIN_PASSWORD=your-secure-password
GRAFANA_ROOT_URL=https://mon.ajinsights.com.au
```

**Recommended:**
```
TZ=Australia/Sydney
NODE_ENV=production
```

## Resource Requirements

**Minimum:**
- 4 CPU cores
- 4GB RAM
- 50GB disk

**Recommended:**
- 8 CPU cores
- 8GB RAM
- 100GB disk

## Files Overview

| File | Purpose |
|------|---------|
| `docker-compose.coolify.yml` | Coolify-optimized configuration |
| `.env.coolify.example` | Environment variables template |
| `COOLIFY_QUICK_START.md` | 5-minute deployment guide |
| `COOLIFY_DEPLOYMENT_CHECKLIST.md` | Comprehensive deployment steps |
| `COOLIFY_DEPLOYMENT_SUMMARY.md` | Configuration details |
| `scripts/coolify-validate.sh` | Pre-deployment validation |

## Health Checks

All services have health checks:

- Grafana: `http://grafana:3000/api/health`
- Prometheus: `http://prometheus:9090/-/healthy`
- Node Exporter: `http://node-exporter:9100/metrics`
- cAdvisor: `http://cadvisor:8080/healthz`
- NPM Exporter: `http://npm-exporter:9101/health`
- Alertmanager: `http://alertmanager:9093/-/healthy`

## Security

- Only Grafana exposed publicly (via HTTPS)
- All other services internal-only
- SSL/TLS automatic via Let's Encrypt
- Configuration files read-only
- Non-root users configured
- Sign-up disabled
- Analytics disabled

## Support

For detailed information, troubleshooting, and maintenance:

1. Start with [COOLIFY_QUICK_START.md](COOLIFY_QUICK_START.md)
2. Review [COOLIFY_DEPLOYMENT_CHECKLIST.md](COOLIFY_DEPLOYMENT_CHECKLIST.md)
3. Check [COOLIFY_DEPLOYMENT_SUMMARY.md](COOLIFY_DEPLOYMENT_SUMMARY.md)

## Validation Status

✓ ALL CHECKS PASSED

Run `./scripts/coolify-validate.sh` to verify configuration.

## Next Steps

1. Run validation script
2. Review quick start guide
3. Prepare environment variables
4. Deploy to Coolify
5. Follow post-deployment checklist

---

**Status**: Ready for Deployment ✓
**Domain**: mon.ajinsights.com.au
**Platform**: Coolify
**Last Updated**: 2025-10-06
