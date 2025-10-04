# Security Architecture

## Overview

Security considerations and implementation details for the monitoring stack.

---

## Threat Model

### Assets to Protect
1. **Metrics Data**: System and application performance data
2. **Credentials**: Grafana passwords, API keys
3. **Infrastructure**: Docker containers and host system
4. **Network**: Internal communication channels

### Threat Actors
- **External Attackers**: Unauthorized internet access
- **Insider Threats**: Unauthorized internal access
- **Malware**: Compromised containers
- **Misconfiguration**: Accidental exposure

### Attack Vectors
- Exposed ports to internet
- Weak authentication
- Container escape
- Data exfiltration
- Denial of service
- Man-in-the-middle attacks

---

## Security Layers

### 1. Network Security

#### Network Isolation
```yaml
# Dedicated bridge network for monitoring stack
networks:
  monitoring:
    driver: bridge
    internal: false  # Allow outbound, restrict inbound
    ipam:
      driver: default
      config:
        - subnet: 172.28.0.0/16
```

#### Port Exposure Strategy
| Service        | Port | Exposure                | Risk Level |
|----------------|------|-------------------------|------------|
| Grafana        | 3000 | Host (behind proxy)     | Medium     |
| Prometheus     | 9090 | Host (internal only)    | Low        |
| Node Exporter  | 9100 | Docker network only     | Low        |
| cAdvisor       | 8080 | Docker network only     | Low        |
| NPM Exporter   | 9101 | Docker network only     | Low        |

#### Firewall Rules (UFW)
```bash
# Allow only necessary ports from specific sources
ufw allow from 172.28.0.0/16 to any port 3000  # Grafana (internal)
ufw allow from 127.0.0.1 to any port 9090     # Prometheus (localhost)
ufw deny 9100  # Block external access to exporters
ufw deny 8080  # Block external access to cAdvisor
ufw deny 9101  # Block external access to NPM exporter
```

#### Reverse Proxy (Recommended)
```nginx
# Nginx configuration for Grafana
server {
    listen 443 ssl http2;
    server_name monitoring.example.com;

    ssl_certificate /etc/ssl/certs/monitoring.crt;
    ssl_certificate_key /etc/ssl/private/monitoring.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2. Authentication & Authorization

#### Grafana Authentication
```yaml
# Environment variables
GF_SECURITY_ADMIN_USER: admin
GF_SECURITY_ADMIN_PASSWORD_FILE: /run/secrets/grafana_admin_password
GF_AUTH_ANONYMOUS_ENABLED: false
GF_AUTH_BASIC_ENABLED: true
GF_AUTH_DISABLE_LOGIN_FORM: false
GF_AUTH_DISABLE_SIGNOUT_MENU: false
GF_USERS_ALLOW_SIGN_UP: false
GF_USERS_ALLOW_ORG_CREATE: false
GF_USERS_AUTO_ASSIGN_ORG: true
GF_USERS_AUTO_ASSIGN_ORG_ROLE: Viewer
```

#### Password Policy
- **Minimum Length**: 12 characters
- **Complexity**: Upper, lower, number, special char
- **Rotation**: Every 90 days
- **Storage**: Docker secrets (never in env vars)

#### Role-Based Access Control (RBAC)
```yaml
# Grafana roles
Admin: Full access (1-2 users)
Editor: Create/edit dashboards (dev team)
Viewer: Read-only access (all users)
```

#### API Key Management
- **Generation**: Via Grafana UI only
- **Scope**: Limit to specific operations
- **Expiration**: 90 days maximum
- **Storage**: Secure vault or secrets manager
- **Rotation**: Automated via CI/CD

#### Prometheus Authentication (Optional)
```yaml
# Basic auth via reverse proxy
# prometheus.yml
basic_auth_users:
  prometheus: $2y$10$... # bcrypt hash
```

### 3. Container Security

#### Docker Security Best Practices

##### Non-Root Users
```dockerfile
# Grafana (already uses UID 472)
USER grafana

# Prometheus (already uses UID 65534)
USER nobody

# Custom exporters
RUN addgroup -g 1000 exporter && \
    adduser -D -u 1000 -G exporter exporter
USER exporter
```

##### Read-Only Filesystems
```yaml
# docker-compose.yml
services:
  prometheus:
    read_only: true
    tmpfs:
      - /tmp:size=100M
    volumes:
      - prometheus_data:/prometheus:rw
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
```

##### Resource Limits
```yaml
services:
  grafana:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    security_opt:
      - no-new-privileges:true
```

##### Security Options
```yaml
security_opt:
  - no-new-privileges:true  # Prevent privilege escalation
  - apparmor:docker-default  # AppArmor profile
  - seccomp:default.json     # Seccomp filter
```

##### Capabilities
```yaml
# Drop all, add only necessary
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # Only if binding to <1024
  - CHOWN             # Only if changing ownership
```

##### Privileged Mode Justification
```yaml
# cAdvisor requires privileged mode
cadvisor:
  privileged: true  # Required for cgroup access
  # Risk mitigation:
  # - Internal network only
  # - No sensitive data access
  # - Read-only operations
  # - Regular security updates
```

#### Image Security

##### Official Images Only
```yaml
# Use official, verified images
services:
  grafana:
    image: grafana/grafana:11.3.0  # Official
  prometheus:
    image: prom/prometheus:v2.54.0  # Official
```

##### Image Scanning
```bash
# Scan images before deployment
docker scan grafana/grafana:11.3.0
trivy image prom/prometheus:v2.54.0
```

##### Image Signing
```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1
docker pull grafana/grafana:11.3.0
```

##### Regular Updates
```bash
# Update images weekly
docker-compose pull
docker-compose up -d
```

### 4. Data Security

#### Data at Rest

##### Volume Encryption
```bash
# LUKS encryption for Docker volumes
cryptsetup luksFormat /dev/sdX
cryptsetup open /dev/sdX monitoring_data
mkfs.ext4 /dev/mapper/monitoring_data
```

##### Filesystem Permissions
```bash
# Restrict access to volume directories
chmod 700 /var/lib/docker/volumes/prometheus_data
chown 65534:65534 /var/lib/docker/volumes/prometheus_data

chmod 700 /var/lib/docker/volumes/grafana_data
chown 472:472 /var/lib/docker/volumes/grafana_data
```

##### Backup Encryption
```bash
# Encrypt backups
tar czf - prometheus_data | gpg --encrypt --recipient admin@example.com > backup.tar.gz.gpg
```

#### Data in Transit

##### TLS for Grafana
```yaml
# grafana.ini
[server]
protocol = https
cert_file = /etc/grafana/ssl/grafana.crt
cert_key = /etc/grafana/ssl/grafana.key
```

##### TLS for Prometheus
```yaml
# prometheus.yml
global:
  external_labels:
    cluster: 'production'

# Scrape over HTTPS (if exporters support it)
scrape_configs:
  - job_name: 'secure-exporter'
    scheme: https
    tls_config:
      ca_file: /etc/prometheus/ca.crt
      cert_file: /etc/prometheus/client.crt
      key_file: /etc/prometheus/client.key
```

#### Secrets Management

##### Docker Secrets
```bash
# Create secrets
echo "admin_password_here" | docker secret create grafana_admin_password -

# Use in compose
services:
  grafana:
    secrets:
      - grafana_admin_password
    environment:
      GF_SECURITY_ADMIN_PASSWORD_FILE: /run/secrets/grafana_admin_password

secrets:
  grafana_admin_password:
    external: true
```

##### Environment File Security
```bash
# .env file permissions
chmod 600 .env
chown root:root .env

# .gitignore
echo ".env" >> .gitignore
```

### 5. Logging & Audit

#### Audit Logging

##### Grafana Audit Log
```yaml
# grafana.ini
[log]
mode = console file
level = info
filters = alerting.notifier:debug

[auth]
oauth_auto_login = false

[auth.anonymous]
enabled = false

[log.console]
level = info

[log.file]
level = info
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7
```

##### Prometheus Query Log
```yaml
# Command argument
--query.log-file=/prometheus/query.log
```

##### Container Logs
```yaml
# docker-compose.yml
services:
  grafana:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,env"
        tag: "{{.Name}}/{{.ID}}"
```

##### Centralized Logging (Optional)
```yaml
# Forward logs to syslog
logging:
  driver: syslog
  options:
    syslog-address: "tcp://syslog.example.com:514"
    tag: "monitoring/{{.Name}}"
```

#### Security Event Monitoring

##### Failed Login Attempts
```promql
# Prometheus alert
- alert: GrafanaFailedLogins
  expr: rate(grafana_api_login_post_total{status="failed"}[5m]) > 5
  for: 5m
  annotations:
    summary: "High rate of failed Grafana logins"
```

##### Unauthorized Access Attempts
```promql
- alert: UnauthorizedScrapeAttempts
  expr: prometheus_target_scrapes_exceeded_sample_limit_total > 0
  annotations:
    summary: "Unauthorized scrape attempts detected"
```

### 6. Vulnerability Management

#### Scanning Schedule
- **Images**: Weekly scan
- **Containers**: Daily runtime scan
- **Dependencies**: On build

#### Patch Management
- **Critical**: Within 24 hours
- **High**: Within 1 week
- **Medium**: Within 1 month
- **Low**: Next release cycle

#### CVE Monitoring
```bash
# Subscribe to security advisories
# - Grafana: https://grafana.com/security
# - Prometheus: https://prometheus.io/security
# - Docker: https://www.docker.com/security
```

### 7. Compliance & Standards

#### Data Privacy (GDPR)
- **Personal Data**: Metrics do not contain PII
- **Data Retention**: 30 days (configurable)
- **Data Access**: Role-based access control
- **Data Deletion**: Automated via retention policy

#### Security Standards
- **CIS Docker Benchmark**: Follow hardening guidelines
- **NIST Cybersecurity Framework**: Align practices
- **OWASP Top 10**: Address web application risks

---

## Incident Response

### Detection
1. **Monitoring**: Alerts for security events
2. **Logging**: Centralized log aggregation
3. **Anomaly Detection**: Unusual patterns

### Response Procedures
1. **Isolate**: Disconnect compromised containers
2. **Investigate**: Review logs and metrics
3. **Remediate**: Patch vulnerabilities
4. **Recover**: Restore from backups
5. **Document**: Post-incident report

### Backup & Recovery
```bash
# Backup strategy
# Daily: Incremental
# Weekly: Full backup
# Monthly: Offsite backup

# Prometheus backup
docker exec prometheus promtool tsdb snapshot /prometheus
tar czf prometheus-backup-$(date +%F).tar.gz /var/lib/docker/volumes/prometheus_data

# Grafana backup
docker exec grafana grafana-cli admin reset-admin-password newpassword
sqlite3 /var/lib/docker/volumes/grafana_data/_data/grafana.db ".backup grafana-backup-$(date +%F).db"
```

---

## Security Checklist

### Pre-Deployment
- [ ] Change default passwords
- [ ] Enable authentication on all services
- [ ] Configure firewall rules
- [ ] Set up TLS/SSL certificates
- [ ] Scan images for vulnerabilities
- [ ] Configure resource limits
- [ ] Enable audit logging
- [ ] Test backup/restore procedures

### Post-Deployment
- [ ] Verify network isolation
- [ ] Test authentication
- [ ] Review access logs
- [ ] Validate encryption
- [ ] Check for exposed ports
- [ ] Monitor security alerts
- [ ] Schedule regular security reviews

### Ongoing
- [ ] Weekly image updates
- [ ] Monthly security audits
- [ ] Quarterly penetration testing
- [ ] Annual security training

---

## Security Contacts

### Escalation Path
1. **L1**: DevOps team (monitoring issues)
2. **L2**: Security team (incidents)
3. **L3**: CISO (critical breaches)

### Reporting
- **Internal**: security@example.com
- **Grafana**: security@grafana.com
- **Prometheus**: prometheus-developers@googlegroups.com
