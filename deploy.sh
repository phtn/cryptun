#!/bin/bash

# Cryptun Deployment Script
# Usage: ./deploy.sh [server_ip] [user]

set -e

SERVER_IP=${1:-"your-server-ip"}
USER=${2:-"root"}
APP_NAME="cryptun"
RELEASE_VERSION="0.1.0"

echo "🚀 Building Cryptun release..."

# Build the release
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix release

echo "📦 Release built successfully!"

# Create deployment package
RELEASE_TAR="_build/prod/rel/${APP_NAME}/releases/${RELEASE_VERSION}/${APP_NAME}-${RELEASE_VERSION}.tar.gz"

if [ ! -f "$RELEASE_TAR" ]; then
    echo "❌ Release tar not found at $RELEASE_TAR"
    echo "Building tar manually..."
    cd _build/prod/rel/${APP_NAME}
    tar -czf "${APP_NAME}-${RELEASE_VERSION}.tar.gz" .
    mv "${APP_NAME}-${RELEASE_VERSION}.tar.gz" "releases/${RELEASE_VERSION}/"
    cd - > /dev/null
fi

echo "📤 Deploying to $SERVER_IP..."

# Upload and deploy
scp "$RELEASE_TAR" "${USER}@${SERVER_IP}:/tmp/"
scp cryptun.service "${USER}@${SERVER_IP}:/tmp/"

ssh "${USER}@${SERVER_IP}" << EOF
    set -e
    
    echo "🔧 Setting up Cryptun on server..."
    
    # Create user and directories
    useradd -r -s /bin/false cryptun || true
    mkdir -p /opt/cryptun
    chown cryptun:cryptun /opt/cryptun
    
    # Stop existing service
    systemctl stop cryptun || true
    
    # Extract release
    cd /opt/cryptun
    rm -rf ./*
    tar -xzf /tmp/${APP_NAME}-${RELEASE_VERSION}.tar.gz
    chown -R cryptun:cryptun /opt/cryptun
    
    # Install systemd service
    cp /tmp/cryptun.service /etc/systemd/system/
    systemctl daemon-reload
    
    # Generate secret key
    SECRET_KEY=\$(openssl rand -base64 64 | tr -d '\n')
    sed -i "s/SECRET_KEY_BASE=CHANGE_ME_IN_PRODUCTION/SECRET_KEY_BASE=\$SECRET_KEY/" /etc/systemd/system/cryptun.service
    
    # Start service
    systemctl enable cryptun
    systemctl start cryptun
    
    echo "✅ Cryptun deployed successfully!"
    echo "📊 Dashboard: http://$(curl -s ifconfig.me):4000"
    echo "🚇 Gateway: http://$(curl -s ifconfig.me):4001"
    echo ""
    echo "Check status with: systemctl status cryptun"
    echo "View logs with: journalctl -u cryptun -f"
EOF

echo "🎉 Deployment complete!"
echo ""
echo "Next steps:"
echo "1. SSH to your server: ssh ${USER}@${SERVER_IP}"
echo "2. Check service status: systemctl status cryptun"
echo "3. View logs: journalctl -u cryptun -f"
echo "4. Access dashboard: http://${SERVER_IP}:4000"