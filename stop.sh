#!/bin/bash

# Stop script for monitoring stack
# Usage: ./stop.sh [--remove-volumes]

set -e

echo "======================================"
echo "Stopping Monitoring Stack"
echo "======================================"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "ERROR: docker-compose is not installed."
    exit 1
fi

# Parse arguments
REMOVE_VOLUMES=false
if [ "$1" == "--remove-volumes" ]; then
    REMOVE_VOLUMES=true
    echo "WARNING: This will remove all data volumes!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Stop services
echo "Stopping services..."
docker-compose down

# Remove volumes if requested
if [ "$REMOVE_VOLUMES" == true ]; then
    echo "Removing data volumes..."
    docker-compose down -v
fi

echo ""
echo "======================================"
echo "Monitoring stack stopped successfully"
echo "======================================"
echo ""
if [ "$REMOVE_VOLUMES" == true ]; then
    echo "All data has been removed."
else
    echo "Data volumes preserved."
    echo "To remove data: ./stop.sh --remove-volumes"
fi
echo ""
