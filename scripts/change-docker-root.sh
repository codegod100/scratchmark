#!/bin/bash
# Safe Docker data root change script (NO INTERACTIVE INPUT)
# WARNING: This affects ALL Docker containers on your system

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NEW_DOCKER_ROOT="/extra/docker-root"
BACKUP_DIR="$HOME/docker-backup-$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Safe Docker Data Root Change"
echo -e "${BLUE}========================================"
echo -e ""
echo -e "${RED}  This will affect ALL Docker containers on your system!"
echo -e "${RED}  All running containers will be stopped"
echo -e "${RED}  Uncommitted changes will be lost"
echo -e ""

echo -e "${BLUE}  Current Docker data root:"
echo -e "${NC}  $(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')"
echo -e ""
echo -e "${YELLOW}  New Docker data root:"
echo -e "${NC}  $NEW_DOCKER_ROOT"
echo -e ""
read -p "Press Enter to continue (or Ctrl+C to cancel): " dummy

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 1: Stop All Containers"
echo -e "${BLUE}========================================"

# Save list of containers to restart later
docker ps -a --format "{{.Names}}" > "$HOME/docker-containers-to-restart.txt"
CONTAINER_COUNT=$(wc -l < "$HOME/docker-containers-to-restart.txt" | awk '{print $1}')

if [ "$CONTAINER_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}  Stopping $CONTAINER_COUNT containers..."
    
    # Stop all containers gracefully
    docker stop $(docker ps -aq)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ All containers stopped"
    else
        echo -e "${RED}  Some containers failed to stop"
    fi
else
    echo -e "${GREEN}  ✓ No containers running"
fi
echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 2: Backup Current Docker Storage"
echo -e "${BLUE}========================================"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup containers
echo -e "${YELLOW}  Backing up containers..."
docker ps -aq | xargs -I{} docker export -o "$BACKUP_DIR/container-{}.tar" 2>/dev/null

# Backup images
echo -e "${YELLOW}  Backing up images..."
docker images -aq | xargs -I{} docker save -o "$BACKUP_DIR/image-{}.tar" 2>/dev/null

# Backup volumes (only if they exist)
if [ -d "/var/lib/docker/volumes" ]; then
    echo -e "${YELLOW}  Backing up volumes..."
    sudo cp -r /var/lib/docker/volumes "$BACKUP_DIR/volumes" 2>/dev/null
fi

echo -e "${GREEN}  ✓ Backup completed"
echo -e "  Backup location: $BACKUP_DIR"
echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 3: Stop Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Stopping Docker daemon..."

# Stop Docker daemon using systemctl
sudo systemctl stop docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Docker daemon stopped"
else
    echo -e "${RED}  Some services failed to stop"
fi
echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 4: Create New Docker Data Root"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Creating new Docker data root..."
echo -e "  $NEW_DOCKER_ROOT"

sudo mkdir -p "$NEW_DOCKER_ROOT"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ New Docker data root created"
else
    echo -e "${RED}  Failed to create new Docker data root"
    exit 1
fi
echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 5: Configure Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Creating Docker daemon configuration..."

# Create new daemon.json if it doesn't exist
if [ ! -f /etc/docker/daemon.json ]; then
    echo -e "  Creating new /etc/docker/daemon.json"
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "$NEW_DOCKER_ROOT"
}
EOF
    echo -e "${GREEN}  ✓ Created /etc/docker/daemon.json"
else
    echo -e "  Updating /etc/docker/daemon.json"
    
    # Backup existing daemon.json
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
    
    # Update data-root
    sudo jq ".data-root = \"$NEW_DOCKER_ROOT\"" /etc/docker/daemon.json
    
    echo -e "${GREEN}  ✓ Updated /etc/docker/daemon.json"
    echo -e "  Backup saved to: /etc/docker/daemon.json.backup"
fi
echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 6: Start Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Starting Docker daemon..."

# Start Docker daemon using systemctl
sudo systemctl start docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Docker daemon started"
else
    echo -e "${RED}  Failed to start Docker daemon"
    exit 1
fi
echo ""

# Wait for daemon to be ready
echo -e "${YELLOW}  Waiting for Docker daemon to initialize..."
sleep 5

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 7: Verification"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Verifying Docker data root..."

# Verify new data root
VERIFY_ROOT=$(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')

if [ "$VERIFY_ROOT" = "$NEW_DOCKER_ROOT" ]; then
    echo -e "${GREEN}  ✓ Docker data root changed successfully"
    echo -e "  New location: $NEW_DOCKER_ROOT"
else
    echo -e "${RED}  Failed to change Docker data root"
    echo -e "  Expected: $NEW_DOCKER_ROOT"
    echo -e "  Got: $VERIFY_ROOT"
    exit 1
fi
echo ""

echo -e "${BLUE}========================================"
echo -e "${GREEN} Docker Data Root Successfully Changed!"
echo -e "${GREEN}========================================"
echo ""
echo -e "${BLUE}  What happens next:"
echo -e "  • All Docker containers are stopped (see $HOME/docker-containers-to-restart.txt)"
echo -e "  • Old Docker storage is backed up to: $BACKUP_DIR"
echo -e "  • Scratchmark Docker builds will use: $NEW_DOCKER_ROOT"
echo -e "  • Other Docker projects will also use this location"
echo ""
echo -e "${YELLOW}  To restart your stopped containers:"
echo -e "  docker start \$(cat $HOME/docker-containers-to-restart.txt | tr '\n' ' ')"
echo ""
echo -e "${RED}  IMPORTANT:"
echo -e "  • This change affects ALL Docker on your system"
echo -e "  • Only Scratchmark builds benefit from dedicated storage"
echo ""
