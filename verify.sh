#!/bin/bash

# Verification script for monitoring stack
# Usage: ./verify.sh

echo "======================================"
echo "Monitoring Stack Verification"
echo "======================================"
echo ""

# Function to check URL
check_url() {
    local url=$1
    local name=$2
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
        echo "✓ $name is accessible"
    else
        echo "✗ $name is NOT accessible"
    fi
}

# Check if services are running
echo "Checking Docker services..."
if docker-compose ps | grep -q "Up"; then
    echo "✓ Docker services are running"
else
    echo "✗ Docker services are NOT running"
    echo "  Run: docker-compose up -d"
    exit 1
fi

echo ""
echo "Checking service endpoints..."

# Check each service
check_url "http://localhost:3001" "Grafana"
check_url "http://localhost:9091" "Prometheus"
check_url "http://localhost:9093" "Alertmanager"
check_url "http://localhost:9100/metrics" "Node Exporter"
check_url "http://localhost:8080" "cAdvisor"
check_url "http://localhost:9101/metrics" "NPM Exporter"

echo ""
echo "Checking Prometheus targets..."
if curl -s "http://localhost:9090/api/v1/targets" | grep -q "\"health\":\"up\""; then
    echo "✓ Prometheus targets are healthy"
else
    echo "⚠ Some Prometheus targets may be down"
    echo "  Check: http://localhost:9090/targets"
fi

echo ""
echo "Checking Grafana datasource..."
if curl -s "http://localhost:3000/api/datasources" | grep -q "Prometheus"; then
    echo "✓ Grafana datasource configured"
else
    echo "⚠ Grafana datasource may need configuration"
fi

echo ""
echo "======================================"
echo "Verification Complete"
echo "======================================"
echo ""
echo "Access URLs:"
echo "  Grafana:      http://localhost:3001"
echo "  Prometheus:   http://localhost:9091"
echo "  Alertmanager: http://localhost:9093"
echo ""
