#!/bin/bash
# Safe Docker data root change script
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

echo -e "${BLUE}  Current Docker data root:$(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')"
echo -e "${YELLOW}  New Docker data root:${NEW_DOCKER_ROOT}"
echo -e ""
read -p "Press Enter to continue: " dummy

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 1: Stop All Containers"
echo -e "${BLUE}========================================"

# Save list of containers to restart later
docker ps -a --format "{{.Names}}" > "$HOME/docker-containers-to-restart.txt"
CONTAINER_COUNT=$(wc -l < "$HOME/docker-containers-to-restart.txt" | awk '{print $1}')

if [ "$CONTAINER_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}  Stopping $CONTAINER_COUNT containers..."
    
    # Stop all containers gracefully (needs sudo)
    sudo docker stop $(docker ps -aq)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ All containers stopped"
    else
        echo -e "${RED}  ✗ Failed to stop some containers"
    fi
else
    echo -e "${GREEN}  ✓ No containers to stop"
fi

echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 2: Backup Current Docker Storage"
echo -e "${BLUE}========================================"

CURRENT_DOCKER_ROOT=$(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')
BACKUP_DIR="$HOME/docker-backup-$(date +%Y%m%d_%H%M%S)"

echo -e "${YELLOW}  Backing up from:${NC}"
echo -e "  $CURRENT_DOCKER_ROOT${NC}"
echo -e "  To:${NC}"
echo -e "  $BACKUP_DIR${NC}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup containers (needs sudo)
echo -e "  Backing up containers..."
docker ps -aq | xargs -I{} sudo docker export -o "$BACKUP_DIR/container-{}.tar" 2>/dev/null

# Backup images (needs sudo)
echo -e "  Backing up images..."
docker images -aq | xargs -I{} sudo docker save -o "$BACKUP_DIR/image-{}.tar" 2>/dev/null

# Backup volumes (needs sudo)
if [ -d "/var/lib/docker/volumes" ]; then
    echo -e "  Backing up volumes..."
    sudo cp -r "/var/lib/docker/volumes" "$BACKUP_DIR/volumes" 2>/dev/null
fi

echo -e "${GREEN}  ✓ Backup completed"
echo -e "  Backup location: $BACKUP_DIR"
echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 3: Stop Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Stopping Docker daemon..."

# Stop Docker daemon (needs sudo)
sudo systemctl stop docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Docker daemon stopped"
else
    echo -e "${RED}  ✗ Failed to stop Docker daemon"
    echo -e "  Try stopping Docker Desktop instead"
    exit 1
fi

echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 4: Create New Docker Data Root"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Creating new Docker data root..."
echo -e "  $NEW_DOCKER_ROOT${NC}"

# Create new Docker data root (needs sudo)
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

# Check if Docker Desktop is using config.json
DESKTOP_DOCKER_CONFIG="$HOME/.docker/daemon.json"

# Check if Docker Desktop is running
if pgrep -x "Docker Desktop" > /dev/null 2>&1; then
    echo -e "  Using Docker Desktop configuration"
    
    # Stop Docker Desktop cleanly
    pkill -f "Docker Desktop" 2>/dev/null
    sleep 2
fi

# Configure Docker daemon (needs sudo)
# Check if docker.json exists
if [ ! -f "/etc/docker/daemon.json" ]; then
    echo -e "  Creating new /etc/docker/daemon.json"
    sudo tee /etc/docker/daemon.json >/dev/null <<'DAEMON'
{
  "data-root": "$NEW_DOCKER_ROOT"
}
'DAEMON
    echo -e "  ${GREEN}  ✓ Created /etc/docker/daemon.json"
else
    echo -e "  Updating /etc/docker/daemon.json"
    
    # Read existing config
    CONFIG=$(cat "/etc/docker/daemon.json" 2>/dev/null)
    
    # Update data-root (check if jq is available)
    if command -v jq >/dev/null 2>&1; then
        NEW_CONFIG=$(echo "$CONFIG" | jq --arg newroot "$NEW_DOCKER_ROOT" '.data-root = $newroot' 2>/dev/null)
        echo "$NEW_CONFIG" | sudo tee "/etc/docker/daemon.json" > /dev/null
    else
        # Fallback: simple replacement using sed
        echo "$CONFIG" | sudo sed "s|\"data-root\":.*|\"data-root\": \"$NEW_DOCKER_ROOT\"|" "/etc/docker/daemon.json" > /dev/null
        echo -e "  ${GREEN}  ✓ Updated /etc/docker/daemon.json"
    fi
fi

echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 6: Start Docker Daemon"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Starting Docker daemon..."

# Start Docker daemon (needs sudo)
sudo systemctl start docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Docker daemon started"
else
    echo -e "${RED}  ✗ Failed to start Docker daemon"
    exit 1
fi

echo ""

echo -e "${BLUE}========================================"
echo -e "${BLUE}  Step 7: Verification"
echo -e "${BLUE}========================================"

echo -e "${YELLOW}  Verifying Docker data root..."

# Verify new Docker data root
VERIFY_ROOT=$(docker system info 2>/dev/null | grep 'Docker Root Dir' | awk '{print $4}')

if [ "$VERIFY_ROOT" = "$NEW_DOCKER_ROOT" ]; then
    echo -e "${GREEN}  ✓ Docker data root changed successfully"
    echo -e "  New location: $NEW_DOCKER_ROOT"
else
    echo -e "${RED}  ✗ Docker data root verification failed"
    echo -e "  Expected: $NEW_DOCKER_ROOT"
    echo -e "  Got: $VERIFY_ROOT"
    exit 1
fi

echo ""

echo -e "${GREEN}========================================"
echo -e "${GREEN}  Docker Data Root Successfully Changed!"
echo -e "${GREEN}========================================"
echo ""
echo -e "${BLUE}What happens next:"
echo -e "  • All Docker containers were stopped (see $HOME/docker-containers-to-restart.txt)"
echo -e "  • Old Docker storage is backed up to: $BACKUP_DIR"
echo -e "  • New Docker data root: $NEW_DOCKER_ROOT"
echo -e "  • Docker daemon was restarted"
echo ""
echo -e "${YELLOW}  To restart your stopped containers:"
echo -e "  docker start \$(cat $HOME/docker-containers-to-restart.txt | tr '\n' ' ')${NC}"
echo ""
echo -e "${RED}  IMPORTANT:"
echo -e "  • This change affects ALL Docker on your system"
echo -e "  • Only Scratchmark builds benefit from dedicated storage"
echo -e "  • Other Docker projects will also use this location"
echo ""
