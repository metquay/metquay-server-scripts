#!/bin/bash
set -e

# =====================================================
# Color codes for better output
# =====================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =====================================================
# Header
# =====================================================
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}   Docker Engine + Portainer Installation Script${NC}"
echo -e "${GREEN}   Supports: CentOS/RHEL 7/8/9 & Ubuntu/Debian${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""

# =====================================================
# Check for root/sudo privileges
# =====================================================
echo -e "${BLUE}🔍 Checking privileges...${NC}"
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run this script with sudo:${NC}"
    echo -e "   ${YELLOW}sudo $0${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Running with sufficient privileges${NC}"
fi
echo ""

# =====================================================
# Confirm with user before proceeding
# =====================================================
echo -e "${YELLOW}⚠️  This script will:${NC}"
echo -e "   • Install Docker Engine"
echo -e "   • Install Portainer CE 2.20.2"
echo -e "   • Configure Portainer to use ports ${CYAN}8000${NC} and ${CYAN}9000${NC}"
echo -e "   • Set read permissions for ${PURPLE}/sys/class/dmi/id/product_uuid${NC} (required for licensing)"
echo ""
echo -e "${YELLOW}📋 IMPORTANT NOTES:${NC}"
echo -e "   • Ports ${CYAN}8000${NC} and ${CYAN}9000${NC} will be used by Portainer container"
echo -e "   • This script does NOT open ports in your firewall"
echo -e "   • Configure firewall manually if external access is needed"
echo ""
read -p "$(echo -e ${YELLOW}"Do you want to continue? (y/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Installation cancelled by user.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Proceeding with installation...${NC}"
fi
echo ""

# =====================================================
# Detect OS
# =====================================================
echo -e "${BLUE}🔍 Detecting operating system...${NC}"
OS=""
if [ -f /etc/redhat-release ]; then
    OS="centos"
    OS_VERSION=$(cat /etc/redhat-release)
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    OS="ubuntu"
    OS_VERSION=$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/debian_version)
else
    echo -e "${RED}❌ Unsupported OS. Only CentOS/RHEL and Ubuntu/Debian are supported.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Detected OS: ${CYAN}$OS ($OS_VERSION)${NC}"
echo ""

# =====================================================
# Set read permission for product_uuid (required for licensing)
# This allows Docker containers to read system UUID for license validation
# =====================================================
echo -e "${BLUE}🔧 Configuring system for licensing...${NC}"
if [ -f /sys/class/dmi/id/product_uuid ]; then
    CURRENT_PERMS=$(stat -c %a /sys/class/dmi/id/product_uuid 2>/dev/null || echo "unknown")
    echo -e "   Current permissions: ${CYAN}$CURRENT_PERMS${NC}"
    
    if [ "$CURRENT_PERMS" != "644" ] && [ "$CURRENT_PERMS" != "444" ]; then
        echo -e "   ${YELLOW}Setting read permission for product_uuid (required for licensing)...${NC}"
        sudo chmod a+r /sys/class/dmi/id/product_uuid 2>/dev/null || \
            echo -e "${YELLOW}⚠️ Could not modify permissions. License validation may be affected.${NC}"
        
        # Verify the change
        NEW_PERMS=$(stat -c %a /sys/class/dmi/id/product_uuid 2>/dev/null)
        echo -e "   ${GREEN}✅ Permissions updated to: ${CYAN}$NEW_PERMS${NC}"
    else
        echo -e "   ${GREEN}✅ Permissions already correct${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ product_uuid file not found. License validation may be limited.${NC}"
fi
echo ""

###################################################
#                CENTOS / RHEL                    #
###################################################
if [ "$OS" = "centos" ]; then

    echo -e "${BLUE}📦 Installing Docker for CentOS/RHEL...${NC}"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}⚠️ Docker is already installed. Checking version...${NC}"
        docker --version
        echo -e "${YELLOW}⚠️ Skipping Docker installation.${NC}"
    else
        echo -e "   ${CYAN}Adding Docker repository...${NC}"
        sudo yum install -y yum-utils > /dev/null 2>&1
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
        
        echo -e "   ${CYAN}Installing Docker packages...${NC}"
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
        
        echo -e "   ${CYAN}Starting Docker service...${NC}"
        sudo systemctl enable docker > /dev/null 2>&1
        sudo systemctl start docker > /dev/null 2>&1
        
        echo -e "${GREEN}✅ Docker installed successfully on CentOS/RHEL.${NC}"
    fi
fi

###################################################
#                UBUNTU / DEBIAN                  #
###################################################
if [ "$OS" = "ubuntu" ]; then

    echo -e "${BLUE}📦 Installing Docker for Ubuntu/Debian...${NC}"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}⚠️ Docker is already installed. Checking version...${NC}"
        docker --version
        echo -e "${YELLOW}⚠️ Skipping Docker installation.${NC}"
    else
        echo -e "   ${CYAN}Updating package index...${NC}"
        sudo apt-get update -y > /dev/null 2>&1
        
        echo -e "   ${CYAN}Installing prerequisites...${NC}"
        sudo apt-get install -y ca-certificates curl gnupg lsb-release > /dev/null 2>&1
        
        echo -e "   ${CYAN}Adding Docker GPG key and repository...${NC}"
        sudo mkdir -m 0755 -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg > /dev/null 2>&1
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        echo -e "   ${CYAN}Installing Docker packages...${NC}"
        sudo apt-get update -y > /dev/null 2>&1
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
        
        echo -e "   ${CYAN}Starting Docker service...${NC}"
        sudo systemctl enable docker > /dev/null 2>&1
        sudo systemctl start docker > /dev/null 2>&1
        
        echo -e "${GREEN}✅ Docker installed successfully on Ubuntu/Debian.${NC}"
    fi
fi

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN} Docker installation completed.${NC}"
echo -e "${GREEN} Now installing Portainer...${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

###################################################
#               PRE-PORTAINER CHECKS              #
###################################################

# =====================================================
# Check if port 9000 is already in use
# =====================================================
echo -e "${BLUE}🔍 Checking port availability...${NC}"

PORT_9000_IN_USE=false
PORT_8000_IN_USE=false

if command -v ss &> /dev/null; then
    if ss -tuln | grep -q ":9000 "; then
        PORT_9000_IN_USE=true
    fi
    if ss -tuln | grep -q ":8000 "; then
        PORT_8000_IN_USE=true
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":9000 "; then
        PORT_9000_IN_USE=true
    fi
    if netstat -tuln | grep -q ":8000 "; then
        PORT_8000_IN_USE=true
    fi
else
    echo -e "${YELLOW}⚠️ Could not check port availability (neither ss nor netstat found)${NC}"
fi

# Check port 9000 (main Portainer UI)
if [ "$PORT_9000_IN_USE" = true ]; then
    echo -e "${RED}❌ Port 9000 is already in use. Portainer requires this port for its web interface.${NC}"
    echo -e "   Please free port 9000 and try again."
    exit 1
else
    echo -e "${GREEN}✅ Port 9000 is available${NC}"
fi

# Check port 8000 (Portainer tunnel server)
if [ "$PORT_8000_IN_USE" = true ]; then
    echo -e "${YELLOW}⚠️ Port 8000 is already in use. This port is used for Portainer's tunnel server.${NC}"
    echo -e "   Portainer may still function but some features might be limited."
    read -p "$(echo -e ${YELLOW}"Continue anyway? (y/N): ${NC}")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Installation cancelled.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Port 8000 is available${NC}"
fi
echo ""

# =====================================================
# Check if Portainer container already exists
# =====================================================
if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
    echo -e "${YELLOW}⚠️ Portainer container already exists.${NC}"
    read -p "$(echo -e ${YELLOW}"Remove existing container and reinstall? (y/N): ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "   ${CYAN}Removing existing Portainer container...${NC}"
        docker rm -f portainer > /dev/null 2>&1
        echo -e "${GREEN}✅ Existing container removed${NC}"
    else
        echo -e "${RED}❌ Installation cancelled.${NC}"
        exit 1
    fi
fi

###################################################
#               INSTALL PORTAINER                  #
###################################################

# =====================================================
# Create Docker volume
# =====================================================
echo -e "${BLUE}📁 Creating Portainer volume...${NC}"
if docker volume inspect portainer_data &> /dev/null; then
    echo -e "   ${YELLOW}Volume 'portainer_data' already exists. Using existing volume.${NC}"
else
    sudo docker volume create portainer_data > /dev/null 2>&1
    echo -e "${GREEN}✅ Volume created successfully${NC}"
fi

# =====================================================
# Install Portainer CE 2.20.2
# =====================================================
echo -e "${BLUE}🚀 Launching Portainer container...${NC}"
echo -e "   ${CYAN}Using image: portainer/portainer-ce:2.20.2${NC}"
echo -e "   ${CYAN}Ports: 8000 (tunnel) and 9000 (web UI)${NC}"

sudo docker run -d \
    -p 8000:8000 \
    -p 9000:9000 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:2.20.2 > /dev/null 2>&1

# =====================================================
# Wait for container to start and verify
# =====================================================
echo -e "   ${CYAN}Waiting for container to start...${NC}"
sleep 5

if docker ps | grep -q portainer; then
    echo -e "${GREEN}✅ Portainer container is running${NC}"
else
    echo -e "${RED}❌ Portainer failed to start. Checking logs...${NC}"
    docker logs portainer --tail 20
    exit 1
fi
echo ""

###################################################
#               COMPLETION MESSAGE                 #
###################################################
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "YOUR_SERVER_IP")

echo -e "${CYAN}📊 INSTALLATION SUMMARY:${NC}"
echo -e "   • Docker: ${GREEN}Installed${NC}"
echo -e "   • Portainer: ${GREEN}Running${NC}"
echo -e "   • Portainer Version: ${PURPLE}2.20.2${NC}"
echo -e "   • Web UI Port: ${CYAN}9000${NC}"
echo -e "   • Tunnel Port: ${CYAN}8000${NC}"
echo ""

echo -e "${GREEN}🌐 ACCESS PORTAINER:${NC}"
echo -e "   👉 ${BLUE}http://$SERVER_IP:9000${NC}"
echo ""

echo -e "${YELLOW}📋 IMPORTANT NOTES:${NC}"
echo -e "   • First visit will prompt you to create an admin user"
echo -e "   • Ports ${CYAN}8000${NC} and ${CYAN}9000${NC} are used by Portainer container"
echo -e "   • This script did NOT modify your firewall settings"
echo -e "   • If accessing remotely, open ports in your firewall:"
echo -e "     ${PURPLE}  - Ubuntu: sudo ufw allow 9000/tcp${NC}"
echo -e "     ${PURPLE}  - CentOS: sudo firewall-cmd --add-port=9000/tcp --permanent${NC}"
echo ""

echo -e "${YELLOW}🔍 VERIFICATION COMMANDS:${NC}"
echo -e "   • Check container: ${CYAN}docker ps | grep portainer${NC}"
echo -e "   • View logs: ${CYAN}docker logs portainer${NC}"
echo ""

echo -e "${GREEN}=====================================================${NC}"
