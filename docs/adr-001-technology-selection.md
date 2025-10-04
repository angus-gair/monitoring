# ADR-001: Technology Selection for Monitoring Stack

**Status**: Accepted
**Date**: 2025-10-03
**Deciders**: System Architect
**Context**: Monitoring system for Ubuntu 24.04 machine with Docker workloads

## Decision

We will use Grafana + Prometheus + specialized exporters as the monitoring stack.

## Context

We need to monitor:
- Host machine metrics (Ubuntu 24.04, i7-9750H, 64GB RAM)
- Docker containers and services
- Node.js/npm applications
- System services and deployments

## Considered Options

### Option 1: ELK Stack (Elasticsearch, Logstash, Kibana)
**Pros**:
- Excellent for log aggregation
- Powerful search capabilities
- Rich visualization options

**Cons**:
- Heavy resource consumption (requires 4-8GB RAM minimum)
- Complex setup and maintenance
- Overkill for metrics-focused monitoring
- Higher learning curve

**Resource Impact**: ~8GB RAM, ~2 cores

### Option 2: Prometheus + Grafana (SELECTED)
**Pros**:
- Purpose-built for metrics collection
- Lightweight and efficient
- Pull-based model (easier networking)
- Excellent ecosystem of exporters
- Rich query language (PromQL)
- Industry standard for cloud-native monitoring
- Pre-built dashboards available
- Active community support

**Cons**:
- Limited log aggregation (metrics-focused)
- Single point of failure without HA setup
- Local storage limitations (needs external TSDB for long-term)

**Resource Impact**: ~3-4GB RAM, ~3-4 cores

### Option 3: Datadog/New Relic (SaaS)
**Pros**:
- Fully managed service
- No maintenance overhead
- Advanced features out-of-box

**Cons**:
- Recurring costs
- Data privacy concerns (external hosting)
- Limited customization
- Requires internet connectivity

**Cost Impact**: $15-100+/month

### Option 4: Zabbix
**Pros**:
- Comprehensive monitoring solution
- Supports agents and agentless monitoring
- Built-in alerting

**Cons**:
- Complex configuration
- Dated UI/UX
- Heavier resource usage
- Steep learning curve

**Resource Impact**: ~4GB RAM, ~2 cores

## Decision Rationale

**Selected Option 2: Prometheus + Grafana**

### Key Decision Factors

1. **Resource Efficiency**
   - Host has 64GB RAM and 12 cores available
   - Prometheus + Grafana uses only ~3.5GB RAM and ~4.5 cores
   - Leaves ample resources for monitored workloads
   - Efficient time-series storage

2. **Purpose-Fit**
   - Primary need is metrics monitoring (not log aggregation)
   - Prometheus designed specifically for metrics
   - Pull-based scraping aligns with container architecture
   - Native support for Docker and Node.js metrics

3. **Ecosystem & Extensibility**
   - Node Exporter: Battle-tested for Linux metrics
   - cAdvisor: Official Docker/container monitoring
   - Extensive exporter ecosystem for custom metrics
   - Easy to add new exporters as needs grow

4. **Operational Simplicity**
   - Single docker-compose deployment
   - No complex clustering required for single-host
   - Self-contained persistent storage
   - Easy backup and restore

5. **Visualization & Alerting**
   - Grafana provides superior dashboard capabilities
   - Pre-built dashboards available from community
   - Flexible alerting with multiple notification channels
   - Intuitive UI for ad-hoc exploration

6. **Cost & Privacy**
   - Open-source and free
   - Data stays local (no external dependencies)
   - No ongoing subscription costs
   - Full control over data retention

7. **Industry Adoption**
   - CNCF graduated project (Prometheus)
   - Industry standard for Kubernetes monitoring
   - Large community for support
   - Extensive documentation

## Technology Versions Rationale

### Grafana 11.x (Latest Stable)
- **Why**:
  - Improved performance over 10.x
  - Enhanced dashboard features
  - Better plugin system
  - Active security updates
- **Risk**: Minimal (stable release)

### Prometheus 2.x LTS
- **Why**:
  - Long-term support guarantees
  - Proven stability
  - Feature-complete for our needs
  - Extensive production usage
- **Risk**: None (mature project)

### Node Exporter 1.8.x
- **Why**:
  - Latest kernel compatibility (6.14.x)
  - Full support for Ubuntu 24.04
  - All necessary collectors included
- **Risk**: Minimal (lightweight process)

### cAdvisor 0.49.x
- **Why**:
  - Latest Docker runtime support
  - Improved container detection
  - Better cgroup v2 support
- **Risk**: Low (read-only operations)

## Deployment Architecture Decision

### Docker Compose vs. Kubernetes
**Selected**: Docker Compose

**Rationale**:
- Single-host deployment (no multi-node complexity)
- Simpler operations and maintenance
- Faster deployment and iteration
- Adequate for monitoring needs
- No Kubernetes overhead

### Storage Strategy
**Selected**: Local Docker volumes with bind mounts

**Rationale**:
- Persistent storage survives container restarts
- Easy to backup via host filesystem
- No need for distributed storage
- Adequate performance for single-host

### Network Strategy
**Selected**: Dedicated bridge network

**Rationale**:
- Isolation from other Docker workloads
- Service discovery via DNS
- Controlled port exposure
- Security through network segmentation

## Consequences

### Positive
✅ Lightweight resource footprint
✅ Fast deployment and iteration
✅ Extensive customization options
✅ Strong community support
✅ Future-proof architecture
✅ No vendor lock-in
✅ Local data control

### Negative
❌ Limited built-in log aggregation (metrics only)
❌ Requires manual HA setup for redundancy
❌ Long-term storage requires additional solutions
❌ Some assembly required (not turnkey SaaS)

### Mitigations
- For logs: Add Loki or Promtail if needed later
- For HA: Federation pattern available if needed
- For long-term: Thanos or Cortex can be added
- For ease: Pre-built dashboards and configs

## Compliance & Security

### Data Privacy
- All metrics stored locally
- No external data transmission
- Full GDPR compliance (local processing)

### Security Posture
- Regular security updates via official images
- Network isolation via Docker
- Authentication on all UIs
- TLS optional (can add reverse proxy)

## Future Considerations

### Potential Additions
1. **Loki**: For log aggregation (if needed)
2. **Thanos**: For long-term metrics storage
3. **Alertmanager**: For advanced alert routing
4. **Tempo**: For distributed tracing

### Migration Path
- Easy to add new exporters
- Can federate to central Prometheus later
- Grafana supports multiple data sources
- Dashboards portable via JSON

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [CNCF Landscape](https://landscape.cncf.io/)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [cAdvisor](https://github.com/google/cadvisor)

## Approval

**Approved By**: System Architect
**Date**: 2025-10-03
**Review Date**: 2026-04-03 (6 months)
