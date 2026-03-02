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
echo -e "${GREEN}   Certbot SSL + Keystore Update Script${NC}"
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
# Interactive Configuration Collection
# =====================================================
echo -e "${YELLOW}📋 Please provide the following configuration information:${NC}"
echo ""

# Domain (required)
while true; do
    read -p "$(echo -e ${BLUE}"Enter your domain name (e.g., example.com): ${NC}")" DOMAIN < /dev/tty
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}❌ Domain cannot be empty. Please try again.${NC}"
    elif [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ Invalid domain format. Please enter a valid domain.${NC}"
    else
        echo -e "${GREEN}✅ Domain set to: $DOMAIN${NC}"
        break
    fi
done
echo ""

# Email for Let's Encrypt (required)
while true; do
    read -p "$(echo -e ${BLUE}"Enter your email address (for Let's Encrypt notifications): ${NC}")" EMAIL < /dev/tty
    if [ -z "$EMAIL" ]; then
        echo -e "${RED}❌ Email cannot be empty. Let's Encrypt requires a valid email.${NC}"
    elif [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ Invalid email format. Please enter a valid email.${NC}"
    else
        echo -e "${GREEN}✅ Email set to: $EMAIL${NC}"
        break
    fi
done
echo ""

# Keystore password (required - will be masked)
while true; do
    read -sp "$(echo -e ${BLUE}"Enter keystore/PKCS12 password: ${NC}")" P12_PASSWORD < /dev/tty
    echo ""
    read -sp "$(echo -e ${BLUE}"Confirm keystore/PKCS12 password: ${NC}")" P12_PASSWORD_CONFIRM < /dev/tty
    echo ""
    
    if [ -z "$P12_PASSWORD" ]; then
        echo -e "${RED}❌ Password cannot be empty. Please try again.${NC}"
    elif [ "$P12_PASSWORD" != "$P12_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}❌ Passwords do not match. Please try again.${NC}"
    else
        echo -e "${GREEN}✅ Password confirmed.${NC}"
        break
    fi
done
echo ""

# Keystore path (with default)
DEFAULT_KEYSTORE="/var/lib/docker/volumes/metquay-tomcat-conf/_data/keystore"
read -p "$(echo -e ${BLUE}"Enter keystore path [default: $DEFAULT_KEYSTORE]: ${NC}")" KEYSTORE_PATH < /dev/tty
if [ -z "$KEYSTORE_PATH" ]; then
    KEYSTORE_PATH="$DEFAULT_KEYSTORE"
fi
echo -e "${GREEN}✅ Keystore path set to: $KEYSTORE_PATH${NC}"
echo ""

# Alias name (with default)
DEFAULT_ALIAS="$DOMAIN"
read -p "$(echo -e ${BLUE}"Enter certificate alias name [default: $DEFAULT_ALIAS]: ${NC}")" ALIAS_NAME < /dev/tty
if [ -z "$ALIAS_NAME" ]; then
    ALIAS_NAME="$DEFAULT_ALIAS"
fi
echo -e "${GREEN}✅ Alias set to: $ALIAS_NAME${NC}"
echo ""

# =====================================================
# Confirm with user before proceeding
# =====================================================
echo -e "${YELLOW}⚠️  This script will:${NC}"
echo -e "   • Install/verify OpenJDK 8"
echo -e "   • Install/verify snapd (for Certbot)"
echo -e "   • Install/update Certbot via snap"
echo -e "   • Obtain/renew SSL certificate for ${CYAN}$DOMAIN${NC}"
echo -e "   • Convert certificate to PKCS12 format"
echo -e "   • Import certificate into keystore at: ${CYAN}$KEYSTORE_PATH${NC}"
echo ""
echo -e "${YELLOW}📋 IMPORTANT NOTES:${NC}"
echo -e "   • Port 80 must be available for certificate issuance/renewal"
echo -e "   • Existing keystore will be backed up"
echo -e "   • The password you entered will be used for PKCS12 and keystore"
echo ""
read -p "$(echo -e ${YELLOW}"Do you want to continue? (y/N): ${NC}")" -n 1 -r < /dev/tty
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Installation cancelled by user.${NC}"
    exit 1
fi
echo ""

# =====================================================
# Backup existing keystore if it exists
# =====================================================
backup_keystore() {
    if [ -f "$KEYSTORE_PATH" ]; then
        BACKUP_PATH="${KEYSTORE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${BLUE}📦 Backing up existing keystore to: ${CYAN}$BACKUP_PATH${NC}"
        cp "$KEYSTORE_PATH" "$BACKUP_PATH"
        echo -e "${GREEN}✅ Keystore backed up${NC}"
    fi
}

# =====================================================
# Detect OS
# =====================================================
echo -e "${BLUE}🔍 Detecting operating system...${NC}"
OS=""
VERSION=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
elif [ -f /etc/centos-release ]; then
    OS="centos"
    VERSION=$(cat /etc/centos-release | grep -oP '[0-9]+' | head -1)
else
    echo -e "${RED}❌ Unsupported OS.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Detected OS: ${CYAN}$OS ($VERSION)${NC}"
echo ""

# =====================================================
# Install OpenJDK 8
# =====================================================
install_openjdk8_ubuntu() {
    echo -e "${BLUE}🔍 Checking for OpenJDK 8...${NC}"
    
    if java -version 2>&1 | grep -q "1.8.0"; then
        echo -e "${GREEN}✅ OpenJDK 8 already installed.${NC}"
        return
    fi
    
    echo -e "${BLUE}📦 Installing OpenJDK 8 on Ubuntu...${NC}"
    sudo apt-get update -y > /dev/null 2>&1
    sudo apt-get install -y openjdk-8-jdk > /dev/null 2>&1
    echo -e "${GREEN}✅ OpenJDK 8 installed successfully${NC}"
}

install_openjdk8_centos() {
    echo -e "${BLUE}🔍 Checking for OpenJDK 8...${NC}"
    
    if java -version 2>&1 | grep -q "1.8.0"; then
        echo -e "${GREEN}✅ OpenJDK 8 already installed.${NC}"
        return
    fi
    
    echo -e "${BLUE}📦 Installing OpenJDK 8 on CentOS...${NC}"
    
    if [[ $VERSION == 7* ]]; then
        sudo yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel > /dev/null 2>&1
    elif [[ $VERSION == 8* || $VERSION == 9* ]]; then
        sudo dnf install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel > /dev/null 2>&1
    else
        echo -e "${RED}❌ Unsupported CentOS version: $VERSION${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ OpenJDK 8 installed successfully${NC}"
}

# =====================================================
# Install snapd
# =====================================================
install_snapd_ubuntu() {
    echo -e "${BLUE}🔍 Checking for snapd...${NC}"
    if command -v snap >/dev/null 2>&1; then
        echo -e "${GREEN}✅ snapd is already installed.${NC}"
        return
    fi
    echo -e "${BLUE}📦 Installing snapd on Ubuntu...${NC}"
    sudo apt update -y > /dev/null 2>&1
    sudo apt install -y snapd > /dev/null 2>&1
    echo -e "${GREEN}✅ snapd installed successfully${NC}"
}

install_snapd_centos() {
    echo -e "${BLUE}🔍 Checking for snapd...${NC}"
    if command -v snap >/dev/null 2>&1; then
        echo -e "${GREEN}✅ snapd is already installed.${NC}"
        return
    fi
    echo -e "${BLUE}📦 Installing snapd on CentOS...${NC}"
    
    if [[ $VERSION == 7* ]]; then
        sudo yum install -y epel-release > /dev/null 2>&1
        sudo yum update -y > /dev/null 2>&1
        sudo yum install -y snapd > /dev/null 2>&1
    elif [[ $VERSION == 8* || $VERSION == 9* ]]; then
        sudo dnf install -y epel-release > /dev/null 2>&1
        sudo dnf upgrade -y > /dev/null 2>&1
        sudo dnf install -y snapd > /dev/null 2>&1
    else
        echo -e "${RED}❌ Unsupported CentOS version: $VERSION${NC}"
        exit 1
    fi
    
    sudo systemctl enable --now snapd.socket > /dev/null 2>&1
    [[ -d /snap ]] || sudo ln -sf /var/lib/snapd/snap /snap
    echo -e "${GREEN}✅ snapd installed successfully${NC}"
}

# =====================================================
# Remove old Certbot
# =====================================================
remove_old_certbot() {
    if command -v certbot >/dev/null 2>&1 && ! snap list | grep -q certbot; then
        echo -e "${YELLOW}⚠️ Removing non-snap certbot...${NC}"
        if [[ "$OS" == "ubuntu" ]]; then
            sudo apt-get remove -y certbot > /dev/null 2>&1
        elif [[ "$OS" == "centos" ]]; then
            [[ $VERSION == 7* ]] && sudo yum remove -y certbot > /dev/null 2>&1 || sudo dnf remove -y certbot > /dev/null 2>&1
        fi
        echo -e "${GREEN}✅ Old certbot removed${NC}"
    fi
}

# =====================================================
# Install certbot (snap)
# =====================================================
install_certbot() {
    echo -e "${BLUE}🔍 Checking for certbot...${NC}"
    if command -v certbot >/dev/null 2>&1 && snap list | grep -q certbot; then
        echo -e "${GREEN}✅ Certbot (snap) is already installed.${NC}"
        return
    fi
    echo -e "${BLUE}📦 Installing Certbot via snap...${NC}"
    sudo snap install --classic certbot > /dev/null 2>&1
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    echo -e "${GREEN}✅ Certbot installed successfully${NC}"
}

# =====================================================
# Check if port 80 is available (required for certbot)
# =====================================================
check_port_80() {
    echo -e "${BLUE}🔍 Checking if port 80 is available...${NC}"
    
    PORT_80_IN_USE=false
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":80 "; then
            PORT_80_IN_USE=true
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":80 "; then
            PORT_80_IN_USE=true
        fi
    fi
    
    if [ "$PORT_80_IN_USE" = true ]; then
        echo -e "${YELLOW}⚠️ Port 80 is in use. Certbot's standalone mode requires port 80.${NC}"
        echo -e "   You have options:"
        echo -e "   1. Stop the service using port 80 temporarily"
        echo -e "   2. Use webroot mode instead (requires web server configuration)"
        echo ""
        read -p "$(echo -e ${YELLOW}"Continue anyway? (certbot may fail) (y/N): ${NC}")" -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}❌ Installation cancelled.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Port 80 is available${NC}"
    fi
    echo ""
}

# =====================================================
# Issue or Renew SSL Certificate
# =====================================================
obtain_certificate() {
    CERTBOT_DIR="/etc/letsencrypt/live/$DOMAIN"
    
    echo -e "${BLUE}🔐 Processing SSL certificate for ${CYAN}$DOMAIN${NC}..."
    
    if [ -d "$CERTBOT_DIR" ]; then
        echo -e "${YELLOW}🔁 Certificate exists — attempting renewal...${NC}"
        sudo certbot renew --non-interactive --quiet --deploy-hook "echo 'Renewal complete'"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Certificate renewed successfully${NC}"
        else
            echo -e "${RED}❌ Certificate renewal failed${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}📥 Issuing certificate for first time...${NC}"
        sudo certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Certificate issued successfully${NC}"
        else
            echo -e "${RED}❌ Certificate issuance failed${NC}"
            exit 1
        fi
    fi
    echo ""
}

# =====================================================
# Convert to PKCS12 & Import to Keystore
# =====================================================
update_keystore() {
    CERTBOT_DIR="/etc/letsencrypt/live/$DOMAIN"
    
    echo -e "${BLUE}🔧 Updating keystore...${NC}"
    
    # Verify certificate directory exists
    if [ ! -d "$CERTBOT_DIR" ]; then
        echo -e "${RED}❌ Certificate directory $CERTBOT_DIR not found!${NC}"
        exit 1
    fi
    
    cd "$CERTBOT_DIR" || { echo -e "${RED}❌ Cannot access $CERTBOT_DIR${NC}"; exit 1; }
    
    # Verify required certificate files exist
    for file in fullchain.pem privkey.pem; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}❌ Required file $file not found in $CERTBOT_DIR${NC}"
            exit 1
        fi
    done
    
    # Create temporary PKCS12 file (with restrictive permissions)
    TEMP_P12=$(mktemp)
    chmod 600 "$TEMP_P12"
    
    echo -e "   ${CYAN}Converting certificate to PKCS12 format...${NC}"
    # Use heredoc to avoid password in process list
    openssl pkcs12 -export \
        -in fullchain.pem \
        -inkey privkey.pem \
        -out "$TEMP_P12" \
        -name "$ALIAS_NAME" \
        -passout pass:"$P12_PASSWORD" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to create PKCS12 file${NC}"
        rm -f "$TEMP_P12"
        exit 1
    fi
    echo -e "${GREEN}✅ PKCS12 file created securely${NC}"
    
    # Verify keystore directory exists
    KEYSTORE_DIR=$(dirname "$KEYSTORE_PATH")
    if [ ! -d "$KEYSTORE_DIR" ]; then
        echo -e "${YELLOW}⚠️ Keystore directory does not exist. Creating: $KEYSTORE_DIR${NC}"
        mkdir -p "$KEYSTORE_DIR"
    fi
    
    # Backup existing keystore
    backup_keystore
    
    # Delete existing alias if present
    if [ -f "$KEYSTORE_PATH" ]; then
        echo -e "   ${CYAN}Checking for existing alias in keystore...${NC}"
        if keytool -keystore "$KEYSTORE_PATH" -list -storepass "$P12_PASSWORD" 2>/dev/null | grep -q "$ALIAS_NAME"; then
            echo -e "   ${YELLOW}Removing existing alias: $ALIAS_NAME${NC}"
            keytool -keystore "$KEYSTORE_PATH" \
                -delete -alias "$ALIAS_NAME" \
                -storepass "$P12_PASSWORD" 2>/dev/null || {
                echo -e "${YELLOW}⚠️ Could not delete existing alias${NC}"
            }
        fi
    fi
    
    # Import new certificate
    echo -e "   ${CYAN}Importing certificate into keystore...${NC}"
    keytool -importkeystore \
        -deststorepass "$P12_PASSWORD" \
        -destkeystore "$KEYSTORE_PATH" \
        -srckeystore "$TEMP_P12" \
        -srcstoretype PKCS12 \
        -srcstorepass "$P12_PASSWORD" \
        -alias "$ALIAS_NAME" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Certificate imported successfully into keystore${NC}"
    else
        echo -e "${RED}❌ Failed to import certificate into keystore${NC}"
        rm -f "$TEMP_P12"
        exit 1
    fi
    
    # Secure the keystore file
    chmod 600 "$KEYSTORE_PATH" 2>/dev/null || true
    
    # Clean up temporary file securely
    echo -e "   ${CYAN}Cleaning up temporary files...${NC}"
    shred -u "$TEMP_P12" 2>/dev/null || rm -f "$TEMP_P12"
    echo -e "${GREEN}✅ Temporary files securely deleted${NC}"
    
    echo -e "${GREEN}✅ Keystore update completed for $DOMAIN${NC}"
}

# =====================================================
# Verify final setup
# =====================================================
verify_installation() {
    echo -e "${BLUE}🔍 Verifying installation...${NC}"
    
    # Check if keystore exists
    if [ -f "$KEYSTORE_PATH" ]; then
        echo -e "${GREEN}✅ Keystore exists at: $KEYSTORE_PATH${NC}"
    else
        echo -e "${RED}❌ Keystore not found at: $KEYSTORE_PATH${NC}"
        exit 1
    fi
    
    # Check if certificate is in keystore
    if keytool -keystore "$KEYSTORE_PATH" -list -storepass "$P12_PASSWORD" 2>/dev/null | grep -q "$ALIAS_NAME"; then
        echo -e "${GREEN}✅ Certificate alias '$ALIAS_NAME' found in keystore${NC}"
    else
        echo -e "${RED}❌ Certificate alias '$ALIAS_NAME' not found in keystore${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All verifications passed${NC}"
    echo ""
}

# =====================================================
# MAIN EXECUTION
# =====================================================

# Run OS-specific installations
case "$OS" in
    ubuntu|debian)
        install_openjdk8_ubuntu
        install_snapd_ubuntu
        ;;
    centos|rhel|fedora)
        install_openjdk8_centos
        install_snapd_centos
        ;;
    *)
        echo -e "${RED}❌ Unsupported OS: $OS${NC}"
        exit 1
        ;;
esac

# Check port availability
check_port_80

# Remove old certbot and install new one
remove_old_certbot
install_certbot

# Obtain/renew certificate
obtain_certificate

# Update keystore
update_keystore

# Verify everything worked
verify_installation

# =====================================================
# Completion Message
# =====================================================
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}✅ SSL CERTIFICATE SETUP COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""

echo -e "${CYAN}📊 INSTALLATION SUMMARY:${NC}"
echo -e "   • Domain: ${GREEN}$DOMAIN${NC}"
echo -e "   • Email: ${GREEN}$EMAIL${NC}"
echo -e "   • Keystore: ${GREEN}$KEYSTORE_PATH${NC}"
echo -e "   • Certificate Alias: ${GREEN}$ALIAS_NAME${NC}"
echo ""

echo -e "${YELLOW}🔍 VERIFICATION COMMANDS:${NC}"
echo -e "   • Check certificate: ${CYAN}sudo certbot certificates${NC}"
echo -e "   • Check keystore: ${CYAN}keytool -list -keystore $KEYSTORE_PATH -storepass [your_password]${NC}"
echo ""

echo -e "${YELLOW}📋 NEXT STEPS:${NC}"
echo -e "   • Restart your Tomcat/application to use the new certificate"
echo -e "   • Set up auto-renewal (Certbot does this automatically)"
echo -e "   • Test your SSL at: ${CYAN}https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN${NC}"
echo ""

echo -e "${GREEN}=====================================================${NC}"
