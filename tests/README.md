# Monitoring Stack - Testing Documentation

This directory contains comprehensive test suites for validating the monitoring stack deployment and operation.

## Test Scripts Overview

### 1. deploy-test.sh
**Purpose**: Pre-deployment validation of configuration files and environment setup.

**What it tests**:
- Required files existence
- Docker Compose syntax validation
- Port availability
- Prometheus configuration validity
- Alert rules syntax
- Grafana provisioning files
- Dashboard JSON validity
- Directory structure
- Docker daemon accessibility

**When to run**: Before deploying the stack for the first time or after configuration changes.

```bash
cd /home/thunder/projects/monitoring
./tests/deploy-test.sh
```

**Expected output**: All tests should pass (green checkmarks) before deployment.

### 2. integration-test.sh
**Purpose**: Full integration testing of the deployed monitoring stack.

**What it tests**:
- Service startup and health
- Prometheus target discovery
- Metrics scraping and storage
- Grafana API functionality
- Datasource connectivity
- Dashboard provisioning
- Alert rules loading
- Metrics queries
- Container health
- End-to-end data flow

**When to run**: After deploying the stack to verify complete integration.

```bash
cd /home/thunder/projects/monitoring
./tests/integration-test.sh
```

**Duration**: ~60-90 seconds (includes service startup wait time)

**Expected output**: All services healthy, metrics flowing, dashboards accessible.

### 3. smoke-test.sh
**Purpose**: Quick validation that critical services are operational.

**What it tests**:
- Container running status
- Service endpoint availability
- Basic API responses
- Data flow verification
- Dashboard availability

**When to run**:
- Quick health checks after changes
- Before demonstrations
- In CI/CD pipelines
- After system restarts

```bash
cd /home/thunder/projects/monitoring
./tests/smoke-test.sh
```

**Duration**: ~10-15 seconds

**Expected output**: All critical checks pass with green checkmarks.

## Running the Tests

### Prerequisites
```bash
# Ensure scripts are executable
chmod +x tests/*.sh

# Required tools (for full validation)
sudo apt-get install -y curl netstat jq

# Optional: Install promtool for advanced validation
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvfz prometheus-2.45.0.linux-amd64.tar.gz
sudo cp prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/
```

### Test Execution Order

**First deployment**:
```bash
# 1. Pre-deployment validation
./tests/deploy-test.sh

# 2. Deploy if tests pass
docker-compose up -d

# 3. Integration testing
./tests/integration-test.sh

# 4. Quick smoke test
./tests/smoke-test.sh
```

**Regular health checks**:
```bash
./tests/smoke-test.sh
```

**After configuration changes**:
```bash
./tests/deploy-test.sh
docker-compose down
docker-compose up -d
./tests/integration-test.sh
```

## Test Results Interpretation

### Success Indicators
- **deploy-test.sh**: All file checks pass, configurations valid, ports available
- **integration-test.sh**: Services healthy, metrics flowing, queries returning data
- **smoke-test.sh**: All endpoints responding, dashboards accessible

### Common Failure Scenarios

#### Port Already in Use
```
✗ Port 9090 (Prometheus) is already in use
```
**Solution**:
```bash
# Find process using port
sudo netstat -tulpn | grep :9090
# Stop conflicting service or change port in docker-compose.yml
```

#### Configuration Syntax Error
```
✗ Prometheus config has errors
```
**Solution**:
```bash
# Validate manually
promtool check config prometheus/prometheus.yml
# Fix YAML syntax errors
```

#### Service Not Starting
```
✗ Prometheus health check failed
```
**Solution**:
```bash
# Check logs
docker-compose logs prometheus
# Common issues: permission problems, invalid config, port conflicts
```

#### No Metrics Flowing
```
✗ No data flowing to Prometheus
```
**Solution**:
```bash
# Check targets in Prometheus UI
firefox http://localhost:9090/targets
# Verify network connectivity between containers
docker-compose exec prometheus ping node-exporter
```

#### Dashboard Not Loading
```
✗ No dashboards found
```
**Solution**:
```bash
# Check Grafana logs
docker-compose logs grafana
# Verify provisioning directory is mounted
docker-compose exec grafana ls -la /etc/grafana/provisioning/dashboards
```

## Environment Variables

Tests support these environment variables:

```bash
# Grafana credentials (for integration tests)
export GRAFANA_USER=admin
export GRAFANA_PASSWORD=admin

# Custom service URLs (if not using defaults)
export PROMETHEUS_URL=http://localhost:9090
export GRAFANA_URL=http://localhost:3000
export NODE_EXPORTER_URL=http://localhost:9100

# Test timeouts
export MAX_WAIT_TIME=60  # seconds
export CHECK_INTERVAL=5  # seconds
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Monitoring Stack Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Pre-deployment tests
        run: ./tests/deploy-test.sh

      - name: Deploy stack
        run: docker-compose up -d

      - name: Integration tests
        run: ./tests/integration-test.sh

      - name: Cleanup
        if: always()
        run: docker-compose down -v
```

### Jenkins Pipeline Example
```groovy
pipeline {
    agent any
    stages {
        stage('Validate') {
            steps {
                sh './tests/deploy-test.sh'
            }
        }
        stage('Deploy') {
            steps {
                sh 'docker-compose up -d'
            }
        }
        stage('Test') {
            steps {
                sh './tests/integration-test.sh'
            }
        }
        stage('Smoke Test') {
            steps {
                sh './tests/smoke-test.sh'
            }
        }
    }
    post {
        always {
            sh 'docker-compose down -v'
        }
    }
}
```

## Troubleshooting Guide

### Test Script Fails to Execute
```bash
# Problem: Permission denied
# Solution:
chmod +x tests/*.sh
```

### Docker Commands Fail
```bash
# Problem: Permission denied
# Solution:
sudo usermod -aG docker $USER
newgrp docker
```

### Services Timeout During Tests
```bash
# Problem: Services take too long to start
# Solution: Increase timeout
export MAX_WAIT_TIME=120
./tests/integration-test.sh
```

### Tests Pass But Manual Access Fails
```bash
# Problem: Firewall blocking access
# Solution: Check and configure firewall
sudo ufw status
sudo ufw allow 9090/tcp
sudo ufw allow 3000/tcp
```

## Advanced Testing

### Custom Test Queries
```bash
# Test specific metric
curl "http://localhost:9090/api/v1/query?query=node_cpu_seconds_total"

# Test metric range
curl "http://localhost:9090/api/v1/query_range?query=up&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s"

# Test alert evaluation
curl "http://localhost:9090/api/v1/rules"
```

### Performance Testing
```bash
# Generate load on metrics endpoint
ab -n 1000 -c 10 http://localhost:9100/metrics

# Monitor Prometheus performance
curl "http://localhost:9090/api/v1/status/tsdb"
```

### Security Testing
```bash
# Test authentication (should fail without credentials)
curl -f http://localhost:3000/api/dashboards/home

# Test with credentials
curl -u admin:admin http://localhost:3000/api/dashboards/home
```

## Test Maintenance

### Updating Tests
When modifying the monitoring stack configuration:

1. Update relevant test assertions in test scripts
2. Run deployment tests to verify changes
3. Update expected values in integration tests
4. Document new test scenarios in this README

### Adding New Tests
Template for adding new test cases:

```bash
# In appropriate test script:
log_test "Test N: Description of what is being tested..."

if [test_condition]; then
    test_passed "Success message"
else
    test_failed "Failure message"
fi
echo ""
```

## Support and Debugging

### Verbose Mode
```bash
# Run tests with debugging output
set -x
./tests/integration-test.sh
set +x
```

### Capture Test Output
```bash
# Save test results
./tests/integration-test.sh 2>&1 | tee test-results.log
```

### Generate Test Report
```bash
# Create summary report
./tests/deploy-test.sh > deploy-report.txt
./tests/integration-test.sh > integration-report.txt
./tests/smoke-test.sh > smoke-report.txt
```

## Best Practices

1. **Run deployment tests before every deployment**
2. **Run integration tests after deployment changes**
3. **Include smoke tests in monitoring/alerting**
4. **Keep test scripts updated with infrastructure changes**
5. **Document test failures and resolutions**
6. **Use version control for test scripts**
7. **Automate tests in CI/CD pipelines**

## Contributing

When adding new monitoring components:

1. Add validation to `deploy-test.sh`
2. Add integration checks to `integration-test.sh`
3. Add health check to `smoke-test.sh`
4. Document in this README
5. Update troubleshooting guide

## License

These test scripts are part of the monitoring stack project and follow the same license.
