#!/bin/bash

# Script to stop all running Docker containers and remove them
# Author: Auto-generated script
# Date: $(date)

echo "🐳 Docker Container Cleanup Script"
echo "=================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running or not installed"
    exit 1
fi

# Get list of running containers
RUNNING_CONTAINERS=$(docker ps -q)

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "ℹ️  No running Docker containers found"
else
    echo "🔍 Found running containers:"
    docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}"
    
    echo ""
    echo "🛑 Stopping all running containers..."
    docker stop $RUNNING_CONTAINERS
    
    if [ $? -eq 0 ]; then
        echo "✅ All containers stopped successfully"
    else
        echo "❌ Error stopping some containers"
    fi
fi

# Get list of all containers (including stopped ones)
ALL_CONTAINERS=$(docker ps -aq)

if [ -z "$ALL_CONTAINERS" ]; then
    echo "ℹ️  No Docker containers to remove"
else
    echo ""
    echo "🗑️  Removing all containers..."
    docker rm $ALL_CONTAINERS
    
    if [ $? -eq 0 ]; then
        echo "✅ All containers removed successfully"
    else
        echo "❌ Error removing some containers"
    fi
fi

# Optional: Remove unused networks, volumes, and images
echo ""
read -p "🧹 Do you want to clean up unused Docker resources (networks, volumes, images)? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧹 Cleaning up unused Docker resources..."
    docker system prune -f
    echo "✅ Docker system cleanup completed"
fi

echo ""
echo "🎉 Docker cleanup completed!"
echo "📊 Current Docker status:"
docker ps -a
