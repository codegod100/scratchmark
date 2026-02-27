#!/bin/bash
# Simple Docker data root change script for Scratchmark builds
# Changes Docker data root to /extra/docker-root (for this project only)

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
echo -e "${BLUE}  Simple Docker Data Root Change"
echo -e "${BLUE}========================================"
echo ""
echo -e "${GREEN}  What will happen:${NC}"
echo -e "  • Docker data root: $(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')"
echo -e "  • New data root: ${NEW_DOCKER_ROOT}"
echo -e "  • All containers will be stopped"
echo -e "  • Docker daemon will be restarted"
echo -e "  • Current storage will be backed up to: ${BACKUP_DIR}"
echo ""
read -p "Continue? (yes/no): " -n 1 -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}  Cancelled by user"
    exit 0
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 1: Stop All Containers"
echo -e "${BLUE}========================================"

# Stop all containers gracefully
RUNNING_CONTAINERS=$(docker ps -aq)
if [ -n "$RUNNING_CONTAINERS" ]; then
    echo -e "${YELLOW}  Stopping $RUNNING_CONTAINERS containers..."
    docker stop $RUNNING_CONTAINERS
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ All containers stopped"
    else
        echo -e "${RED}  ✗ Failed to stop some containers"
        echo -e "  Run 'docker ps -a' to see what's still running"
        exit 1
    fi
else
    echo -e "${GREEN}  ✓ No containers running (safe to proceed)"
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 2: Backup Current Docker Storage"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Backing up from:$(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup containers (running ones)
echo -e "  Backing up containers..."
docker ps -aq | xargs -I{} docker export -o "$BACKUP_DIR/container-{}.tar" 2>/dev/null

# Backup images
echo -e "  Backing up images..."
docker images -aq | xargs -I{} docker save -o "$BACKUP_DIR/image-{}.tar" 2>/dev/null

# Backup volumes
if [ -d "/var/lib/docker/volumes" ]; then
    echo -e "  Backing up volumes..."
    sudo cp -r /var/lib/docker/volumes "$BACKUP_DIR/volumes" 2>/dev/null
fi

echo -e "${GREEN}  ✓ Backup completed"
echo -e "  Backup location: ${BACKUP_DIR}"
echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 3: Stop Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Stopping Docker daemon..."

# Stop Docker daemon
sudo systemctl stop docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Docker daemon stopped"
else
    echo -e "${RED}  ✗ Failed to stop Docker daemon"
    echo -e "  Check status with: systemctl status docker"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 4: Create New Docker Data Root"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Creating new Docker data root: ${NEW_DOCKER_ROOT}"

# Create new data root directory
sudo mkdir -p "$NEW_DOCKER_ROOT"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ New Docker data root created"
else
    echo -e "${RED}  ✗ Failed to create new Docker data root"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 5: Configure Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Configuring Docker daemon..."

# Create or update daemon.json
if [ ! -f /etc/docker/daemon.json ]; then
    # Create new daemon.json with simple echo
    echo '{"data-root": "'"$NEW_DOCKER_ROOT"'"}' | sudo tee /etc/docker/daemon.json
    echo -e "${GREEN}  ✓ Created /etc/docker/daemon.json"
else
    # Update existing daemon.json with jq if available, or sed if not
    if command -v jq > /dev/null 2>&1; then
        # Use jq for proper JSON manipulation
        sudo jq --arg newroot "$NEW_DOCKER_ROOT" '.data-root = $newroot' /etc/docker/daemon.json
        echo -e "${GREEN}  ✓ Updated /etc/docker/daemon.json"
    else
        # Fallback: use sed for simple string replacement
        sudo sed -i 's|"data-root":.*|"data-root": "'"$NEW_DOCKER_ROOT"'"' /etc/docker/daemon.json
        echo -e "${GREEN}  ✓ Updated /etc/docker/daemon.json"
    fi
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 6: Start Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Starting Docker daemon..."

# Start Docker daemon
sudo systemctl start docker

# Wait for daemon to initialize
sleep 5

# Verify Docker is running
if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Docker daemon is running"
else
    echo -e "${RED}  ✗ Docker daemon failed to start"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 7: Verification"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Verifying Docker data root..."

# Verify new data root (try multiple methods)
VERIFY_ROOT=""
if command -v jq > /dev/null 2>&1; then
    # Method 1: Parse daemon.json with jq
    VERIFY_ROOT=$(sudo cat /etc/docker/daemon.json 2>/dev/null | jq -r '.data-root' 2>/dev/null)
elif command -v systemctl > /dev/null 2>&1; then
    # Method 2: Try systemctl inspect
    VERIFY_ROOT=$(systemctl show docker 2>/dev/null | grep 'ExecStart=' | sed 's/.*--config-file=\([^ ]*\)/.*/\1/' | xargs -0 systemctl show docker | grep 'ExecStart=' | sed 's/.*--data-root=\([^ ]*\)/.*/\1/' | head -1)
else
    # Method 3: Use docker system info (original fallback)
    VERIFY_ROOT=$(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')
fi

if [ "$VERIFY_ROOT" = "$NEW_DOCKER_ROOT" ]; then
    echo -e "${GREEN}  ✓ Docker data root changed successfully"
    echo -e "  New location: ${NEW_DOCKER_ROOT}"
else
    echo -e "${RED}  ✗ Docker data root verification failed"
    echo -e "  Expected: ${NEW_DOCKER_ROOT}"
    echo -e "  Got: ${VERIFY_ROOT}"
    # Don't exit, let user decide
fi

echo ""
echo -e "${GREEN}========================================"
echo -e "${GREEN}  Docker Data Root Successfully Changed!"
echo -e "${GREEN}========================================"
echo ""
echo -e "${BLUE}What happens next:"
echo -e "  • Docker daemon is using: ${NEW_DOCKER_ROOT}"
echo -e "  • Scratchmark Docker builds will use: ${NEW_DOCKER_ROOT}"
echo -e "  • Docker builds for other projects will also use this location"
echo ""
echo -e "${YELLOW}  To restart your stopped containers:"
echo -e "  docker ps -a"
echo -e "  And restart manually: docker start <container_name>"
echo ""
echo -e "${RED}  IMPORTANT:"
echo -e "  • All Docker containers were stopped"
echo -e "  • Old Docker storage is backed up to: ${BACKUP_DIR}"
echo -e "  • Docker storage has been moved"
echo -e "  • This change affects ALL Docker on your system"
echo -e "  • Only Scratchmark builds benefit from dedicated storage"
echo ""
