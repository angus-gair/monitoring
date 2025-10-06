#!/bin/bash

# Coolify Deployment Validation Script
# This script validates the Coolify configuration before deployment
# Run this locally before pushing to Git

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Coolify Deployment Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if file exists
check_file() {
    local file=$1
    local description=$2

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description exists"
        return 0
    else
        echo -e "${RED}✗${NC} $description missing: $file"
        return 1
    fi
}

# Function to check directory
check_directory() {
    local dir=$1
    local description=$2

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description exists"
        return 0
    else
        echo -e "${RED}✗${NC} $description missing: $dir"
        return 1
    fi
}

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    local description=$2

    if command -v yamllint &> /dev/null; then
        if yamllint -d relaxed "$file" &> /dev/null; then
            echo -e "${GREEN}✓${NC} $description is valid YAML"
            return 0
        else
            echo -e "${RED}✗${NC} $description has YAML syntax errors"
            yamllint -d relaxed "$file"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} yamllint not installed, skipping YAML validation for $description"
        echo -e "   Install with: pip install yamllint"
        return 0
    fi
}

# Function to check for required environment variables in example file
check_env_vars() {
    local env_file="$PROJECT_ROOT/.env.coolify.example"

    if [ -f "$env_file" ]; then
        echo -e "${GREEN}✓${NC} Environment example file exists"

        # Check for critical variables
        local required_vars=("GRAFANA_ADMIN_USER" "GRAFANA_ADMIN_PASSWORD" "GRAFANA_ROOT_URL")
        local missing=0

        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" "$env_file"; then
                echo -e "${GREEN}  ✓${NC} $var is defined"
            else
                echo -e "${RED}  ✗${NC} $var is missing"
                missing=$((missing + 1))
            fi
        done

        return $missing
    else
        echo -e "${RED}✗${NC} Environment example file missing"
        return 1
    fi
}

# Counter for errors
ERRORS=0

echo -e "${BLUE}1. Checking required files...${NC}"
echo ""

check_file "$PROJECT_ROOT/docker-compose.coolify.yml" "Coolify docker-compose file" || ERRORS=$((ERRORS + 1))
check_file "$PROJECT_ROOT/prometheus/prometheus.yml" "Prometheus configuration" || ERRORS=$((ERRORS + 1))
check_file "$PROJECT_ROOT/prometheus/alerts.yml" "Prometheus alerts" || ERRORS=$((ERRORS + 1))
check_file "$PROJECT_ROOT/prometheus/alertmanager.yml" "Alertmanager configuration" || ERRORS=$((ERRORS + 1))
check_file "$PROJECT_ROOT/.env.coolify.example" "Environment variables example" || ERRORS=$((ERRORS + 1))
check_file "$PROJECT_ROOT/COOLIFY_DEPLOYMENT_CHECKLIST.md" "Deployment checklist" || ERRORS=$((ERRORS + 1))

echo ""
echo -e "${BLUE}2. Checking required directories...${NC}"
echo ""

check_directory "$PROJECT_ROOT/grafana/provisioning" "Grafana provisioning directory" || ERRORS=$((ERRORS + 1))
check_directory "$PROJECT_ROOT/grafana/dashboards" "Grafana dashboards directory" || ERRORS=$((ERRORS + 1))
check_directory "$PROJECT_ROOT/exporters/npm-exporter" "NPM exporter directory" || ERRORS=$((ERRORS + 1))

echo ""
echo -e "${BLUE}3. Validating YAML syntax...${NC}"
echo ""

validate_yaml "$PROJECT_ROOT/docker-compose.coolify.yml" "Coolify docker-compose" || ERRORS=$((ERRORS + 1))
validate_yaml "$PROJECT_ROOT/prometheus/prometheus.yml" "Prometheus config" || ERRORS=$((ERRORS + 1))
validate_yaml "$PROJECT_ROOT/prometheus/alerts.yml" "Prometheus alerts" || ERRORS=$((ERRORS + 1))
validate_yaml "$PROJECT_ROOT/prometheus/alertmanager.yml" "Alertmanager config" || ERRORS=$((ERRORS + 1))

echo ""
echo -e "${BLUE}4. Checking environment variables...${NC}"
echo ""

check_env_vars || ERRORS=$((ERRORS + 1))

echo ""
echo -e "${BLUE}5. Checking Docker Compose configuration...${NC}"
echo ""

cd "$PROJECT_ROOT"

# Validate docker-compose file structure
if docker-compose -f docker-compose.coolify.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker Compose configuration is valid"
else
    echo -e "${RED}✗${NC} Docker Compose configuration has errors"
    docker-compose -f docker-compose.coolify.yml config
    ERRORS=$((ERRORS + 1))
fi

# Check for required services
required_services=("grafana" "prometheus" "node-exporter" "cadvisor" "npm-exporter" "alertmanager")
for service in "${required_services[@]}"; do
    if docker-compose -f docker-compose.coolify.yml config | grep -q "^  $service:"; then
        echo -e "${GREEN}  ✓${NC} Service '$service' is defined"
    else
        echo -e "${RED}  ✗${NC} Service '$service' is missing"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo -e "${BLUE}6. Checking health check configurations...${NC}"
echo ""

# Check if health checks are defined for critical services
for service in grafana prometheus node-exporter cadvisor npm-exporter alertmanager; do
    if docker-compose -f docker-compose.coolify.yml config | grep -A 20 "^  $service:" | grep -q "healthcheck:"; then
        echo -e "${GREEN}  ✓${NC} Health check defined for '$service'"
    else
        echo -e "${YELLOW}  ⚠${NC} Health check missing for '$service'"
    fi
done

echo ""
echo -e "${BLUE}7. Checking Coolify labels...${NC}"
echo ""

# Check for Coolify labels on Grafana (main service)
if docker-compose -f docker-compose.coolify.yml config | grep -A 50 "^  grafana:" | grep -q "coolify.managed"; then
    echo -e "${GREEN}✓${NC} Coolify labels are present on Grafana"
else
    echo -e "${YELLOW}⚠${NC} Coolify labels missing on Grafana"
fi

# Check for domain configuration
if docker-compose -f docker-compose.coolify.yml config | grep -A 50 "^  grafana:" | grep -q "coolify.domain"; then
    echo -e "${GREEN}✓${NC} Domain configuration is present"
    domain=$(docker-compose -f docker-compose.coolify.yml config | grep "coolify.domain" | head -1 | cut -d'=' -f2)
    echo -e "   Domain: $domain"
else
    echo -e "${YELLOW}⚠${NC} Domain configuration missing"
fi

echo ""
echo -e "${BLUE}8. Checking NPM Exporter build configuration...${NC}"
echo ""

check_file "$PROJECT_ROOT/exporters/npm-exporter/Dockerfile" "NPM Exporter Dockerfile" || ERRORS=$((ERRORS + 1))
check_file "$PROJECT_ROOT/exporters/npm-exporter/package.json" "NPM Exporter package.json" || ERRORS=$((ERRORS + 1))
check_file "$PROJECT_ROOT/exporters/npm-exporter/index.js" "NPM Exporter source code" || ERRORS=$((ERRORS + 1))

echo ""
echo -e "${BLUE}9. Checking volume configurations...${NC}"
echo ""

required_volumes=("prometheus_data" "grafana_data" "alertmanager_data")
for volume in "${required_volumes[@]}"; do
    if docker-compose -f docker-compose.coolify.yml config | grep -q "^  $volume:"; then
        echo -e "${GREEN}  ✓${NC} Volume '$volume' is defined"
    else
        echo -e "${RED}  ✗${NC} Volume '$volume' is missing"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo -e "${BLUE}10. Checking network configuration...${NC}"
echo ""

if docker-compose -f docker-compose.coolify.yml config | grep -q "^  monitoring:"; then
    echo -e "${GREEN}✓${NC} Monitoring network is defined"
else
    echo -e "${RED}✗${NC} Monitoring network is missing"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    echo -e "${GREEN}Configuration is ready for Coolify deployment.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Review .env.coolify.example and prepare your environment variables"
    echo -e "  2. Commit and push to your Git repository"
    echo -e "  3. Configure Coolify with your repository"
    echo -e "  4. Follow the COOLIFY_DEPLOYMENT_CHECKLIST.md"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s)${NC}"
    echo ""
    echo -e "${YELLOW}Please fix the errors above before deploying to Coolify.${NC}"
    echo ""
    exit 1
fi
