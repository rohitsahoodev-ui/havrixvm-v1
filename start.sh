#!/bin/bash

# ============================================
# Havrix VM - One Click Installation Script
# Version: 1.0.0
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║   ██╗  ██╗ █████╗ ██╗   ██╗██████╗ ██╗██╗  ██╗        ║"
echo "║   ██║  ██║██╔══██╗██║   ██║██╔══██╗██║╚██╗██╔╝        ║"
echo "║   ███████║███████║██║   ██║██████╔╝██║ ╚███╔╝         ║"
echo "║   ██╔══██║██╔══██║╚██╗ ██╔╝██╔══██╗██║ ██╔██╗         ║"
echo "║   ██║  ██║██║  ██║ ╚████╔╝ ██║  ██║██║██╔╝ ██╗        ║"
echo "║   ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝        ║"
echo "║                                                          ║"
echo "║   ██╗   ██╗███╗   ███╗                                   ║"
echo "║   ██║   ██║████╗ ████║                                   ║"
echo "║   ██║   ██║██╔████╔██║                                   ║"
echo "║   ╚██╗ ██╔╝██║╚██╔╝██║                                   ║"
echo "║    ╚████╔╝ ██║ ╚═╝ ██║                                   ║"
echo "║     ╚═══╝  ╚═╝     ╚═╝                                   ║"
echo "║                                                          ║"
echo "║             VPS Management Panel v1.0.0                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_warning "This script is not running as root. Some features may not work."
   print_warning "It's recommended to run as root: sudo ./install.sh"
   echo ""
   read -p "Continue anyway? (y/n): " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

# Detect OS
print_info "Detecting operating system..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    print_error "Cannot detect OS"
    exit 1
fi
print_success "Detected: $OS $VER"

# Check Python version
print_info "Checking Python version..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d ' ' -f 2)
    print_success "Python $PYTHON_VERSION found"
    
    # Check if Python version >= 3.8
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d '.' -f 1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d '.' -f 2)
    if [ $PYTHON_MAJOR -lt 3 ] || [ $PYTHON_MAJOR -eq 3 -a $PYTHON_MINOR -lt 8 ]; then
        print_error "Python 3.8+ required. Found $PYTHON_VERSION"
        exit 1
    fi
else
    print_error "Python 3 not found. Installing..."
    apt update
    apt install python3 python3-pip -y
fi

# Install required packages
print_info "Installing required packages..."
apt update
apt install -y \
    python3-dev \
    python3-venv \
    python3-pip \
    git \
    unzip \
    curl \
    wget \
    nginx \
    supervisor

print_success "Packages installed successfully"

# Clone or download project
print_info "Downloading Havrix VM..."
cd /tmp
if [ -d "/tmp/havrixvm-v1" ]; then
    rm -rf /tmp/havrixvm-v1
fi

# Try git clone first
if command -v git &> /dev/null; then
    git clone https://github.com/rohitsahoodev-ui/havrixvm-v1.git 2>/dev/null
    if [ $? -eq 0 ]; then
        print_success "Project cloned successfully"
    else
        print_warning "Git clone failed, trying alternative..."
        # Try wget
        wget -q https://github.com/rohitsahoodev-ui/havrixvm-v1/archive/main.zip -O havrixvm-v1.zip
        if [ -f "havrixvm-v1.zip" ]; then
            unzip -q havrixvm-v1.zip
            mv havrixvm-v1-main havrixvm-v1
        else
            print_error "Download failed"
            exit 1
        fi
    fi
else
    print_warning "Git not found, using wget..."
    wget -q https://github.com/rohitsahoodev-ui/havrixvm-v1/archive/main.zip -O havrixvm-v1.zip
    unzip -q havrixvm-v1.zip
    mv havrixvm-v1-main havrixvm-v1
fi

# Move to install directory
INSTALL_DIR="/opt/havrix-vm"
if [ -d "$INSTALL_DIR" ]; then
    print_warning "$INSTALL_DIR already exists. Removing..."
    rm -rf "$INSTALL_DIR"
fi

mv /tmp/havrixvm-v1 "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Create virtual environment
print_info "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
print_info "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

print_success "Dependencies installed successfully"

# Create necessary directories
print_info "Creating necessary directories..."
mkdir -p static/images
mkdir -p logs
mkdir -p database

# Set permissions
print_info "Setting permissions..."
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

# Create default logo if not exists
print_info "Creating default logo..."
if [ ! -f "$INSTALL_DIR/static/images/logo.png" ]; then
    # Create a simple default logo using PIL
    cat > create_logo.py << 'EOF'
from PIL import Image, ImageDraw, ImageFont
import os

# Create a simple logo
img = Image.new('RGB', (200, 60), color='#2563EB')
d = ImageDraw.Draw(img)
d.text((10, 15), "Havrix VM", fill=(255, 255, 255))
img.save('static/images/logo.png')
print("Default logo created")
EOF
    pip install pillow
    python create_logo.py
    rm create_logo.py
fi

# Create .env file
print_info "Creating environment configuration..."
cat > .env << 'EOF'
FLASK_ENV=production
SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
DEFAULT_ADMIN_USERNAME=admin
DEFAULT_ADMIN_EMAIL=admin@havrix.com
DEFAULT_ADMIN_PASSWORD=admin123
DATABASE_URL=sqlite:///database/database.db
SSHX_BASE_URL=https://sshx.example.com
TMATE_BASE_URL=https://tmate.io
EOF

# Create supervisord configuration
print_info "Creating supervisor configuration..."
cat > /etc/supervisor/conf.d/havrix.conf << EOF
[program:havrix]
command=$INSTALL_DIR/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 --access-logfile $INSTALL_DIR/logs/access.log --error-logfile $INSTALL_DIR/logs/error.log app:app
directory=$INSTALL_DIR
user=www-data
autostart=true
autorestart=true
stopsignal=TERM
environment=PATH="$INSTALL_DIR/venv/bin"
EOF

# Create systemd service
print_info "Creating systemd service..."
cat > /etc/systemd/system/havrix.service << EOF
[Unit]
Description=Havrix VM - VPS Management Panel
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
Environment="FLASK_ENV=production"
ExecStart=$INSTALL_DIR/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 --access-logfile $INSTALL_DIR/logs/access.log --error-logfile $INSTALL_DIR/logs/error.log app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create nginx configuration
print_info "Creating Nginx configuration..."
cat > /etc/nginx/sites-available/havrix << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static {
        alias $INSTALL_DIR/static;
        expires 30d;
    }
}
EOF

# Enable nginx site
ln -sf /etc/nginx/sites-available/havrix /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Start services
print_info "Starting services..."
systemctl daemon-reload
systemctl enable havrix
systemctl restart havrix
systemctl restart supervisor
systemctl restart nginx

# Check status
print_info "Checking service status..."
sleep 3
if systemctl is-active --quiet havrix; then
    print_success "Havrix VM service is running"
else
    print_warning "Havrix VM service is not running. Check logs: journalctl -u havrix"
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

# Print completion message
echo ""
echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}        Havrix VM Installation Complete! 🚀${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "${BLUE}Access Information:${NC}"
echo -e "  URL: http://$SERVER_IP"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}admin123${NC}"
echo ""
echo -e "${BLUE}Installation Directory:${NC}"
echo -e "  $INSTALL_DIR"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo -e "  Start:   systemctl start havrix"
echo -e "  Stop:    systemctl stop havrix"
echo -e "  Restart: systemctl restart havrix"
echo -e "  Status:  systemctl status havrix"
echo -e "  Logs:    journalctl -u havrix -f"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo -e "  Please change the default admin password after first login!"
echo -e "  For production, use HTTPS with Let's Encrypt"
echo ""
echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}        Thank you for using Havrix VM!${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""

# Ask if user wants to open firewall
read -p "Open firewall port 80? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        print_success "Firewall updated"
    elif command -v iptables &> /dev/null; then
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT
        iptables -I INPUT -p tcp --dport 443 -j ACCEPT
        print_success "Firewall updated"
    else
        print_warning "No firewall found, skipping..."
    fi
fi

exit 0
