#!/bin/bash

# Start script for monitoring stack
# Usage: ./start.sh

set -e

echo "======================================"
echo "Starting Monitoring Stack"
echo "======================================"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "ERROR: docker-compose is not installed."
    exit 1
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p prometheus grafana/provisioning grafana/dashboards exporters/npm-exporter

# Check if .env file exists
if [ ! -f .env ]; then
    echo "WARNING: .env file not found. Using default values."
fi

# Pull latest images
echo "Pulling latest images..."
docker-compose pull

# Build custom exporters
echo "Building custom exporters..."
docker-compose build npm-exporter

# Start services
echo "Starting services..."
docker-compose up -d

# Wait for services to be healthy
echo ""
echo "Waiting for services to start..."
sleep 10

# Check service status
echo ""
echo "======================================"
echo "Service Status"
echo "======================================"
docker-compose ps

# Display access information
echo ""
echo "======================================"
echo "Access Information"
echo "======================================"
echo "Grafana:       http://localhost:3000"
echo "  Username:    admin"
echo "  Password:    Check .env file or use default: admin123"
echo ""
echo "Prometheus:    http://localhost:9090"
echo "Alertmanager:  http://localhost:9093"
echo "Node Exporter: http://localhost:9100/metrics"
echo "cAdvisor:      http://localhost:8080"
echo "NPM Exporter:  http://localhost:9101/metrics"
echo ""
echo "======================================"
echo "Next Steps"
echo "======================================"
echo "1. Access Grafana at http://localhost:3000"
echo "2. Login with admin credentials"
echo "3. Check pre-configured dashboards"
echo "4. Verify Prometheus targets: http://localhost:9090/targets"
echo ""
echo "To view logs: docker-compose logs -f [service-name]"
echo "To stop: docker-compose down"
echo ""
