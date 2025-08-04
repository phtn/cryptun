#!/bin/bash

# All Secure Everything
# Cryptun GCloud Deployment Script
# Usage: ./deploy-gcloud.sh [instance-name] [zone] [project]

set -e

INSTANCE_NAME=${1:-"cryptun-server"}
ZONE=${2:-"asia-southeast1-b"}
PROJECT=${3:-$(gcloud config get-value project)}
APP_NAME="ctunsv"
RELEASE_VERSION="0.1.1"

echo "❬/❭ Building Cryptun release..."

# Build the release
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix release

echo "❬/❭ Release built successfully!"

# Create deployment package
RELEASE_TAR="_build/prod/rel/${APP_NAME}/releases/${RELEASE_VERSION}/${APP_NAME}-${RELEASE_VERSION}.tar.gz"

if [ ! -f "$RELEASE_TAR" ]; then
    echo "⊂|⊃ Release tar not found at $RELEASE_TAR"
    echo "Building tar manually..."
    cd _build/prod/rel/${APP_NAME}
    tar -czf "${APP_NAME}-${RELEASE_VERSION}.tar.gz" .
    mv "${APP_NAME}-${RELEASE_VERSION}.tar.gz" "releases/${RELEASE_VERSION}/"
    cd - > /dev/null
fi

echo "⦦⦧⦦⦧⦦⦧⦦ Deploying to GCloud instance: $INSTANCE_NAME (zone: $ZONE, project: $PROJECT)..."

# Check if instance exists and is running
echo "🔍 Checking instance status..."
INSTANCE_STATUS=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --format="value(status)" 2>/dev/null || echo "NOT_FOUND")

if [ "$INSTANCE_STATUS" = "NOT_FOUND" ]; then
    echo "⊂|⊃ Instance $INSTANCE_NAME not found in zone $ZONE"
    echo "Create it with: gcloud compute instances create $INSTANCE_NAME --zone=$ZONE"
    exit 1
fi

if [ "$INSTANCE_STATUS" != "RUNNING" ]; then
    echo "﫭  Instance is $INSTANCE_STATUS. Starting it..."
    gcloud compute instances start $INSTANCE_NAME --zone=$ZONE --project=$PROJECT
    echo "⛭  Waiting for instance to start..."
    sleep 10
fi

# Upload files using gcloud compute scp
echo "⟢  Uploading files..."
gcloud compute scp "$RELEASE_TAR" $INSTANCE_NAME:/tmp/ --zone=$ZONE --project=$PROJECT
gcloud compute scp cryptun.service $INSTANCE_NAME:/tmp/ --zone=$ZONE --project=$PROJECT

# Deploy using gcloud compute ssh
echo "⛭  Setting up Cryptun on server..."
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command="
    set -e
    
    echo '⛭  Setting up Cryptun on server...'
    
    # Create user and directories
    sudo useradd -r -s /bin/false cryptun 2>/dev/null || true
    sudo mkdir -p /opt/cryptun
    sudo chown cryptun:cryptun /opt/cryptun
    
    # Stop existing service
    sudo systemctl stop cryptun 2>/dev/null || true
    
    # Extract release
    cd /opt/cryptun
    sudo rm -rf ./*
    sudo tar -xzf /tmp/${APP_NAME}-${RELEASE_VERSION}.tar.gz
    sudo chown -R cryptun:cryptun /opt/cryptun
    
    # Install systemd service
    sudo cp /tmp/cryptun.service /etc/systemd/system/
    sudo systemctl daemon-reload
    
    # Generate secret key
    SECRET_KEY=\$(openssl rand -base64 64 | tr -d '\n')
    sudo sed -i \"s/SECRET_KEY_BASE=CHANGE_ME_IN_PRODUCTION/SECRET_KEY_BASE=\$SECRET_KEY/\" /etc/systemd/system/cryptun.service
    
    # Configure firewall (if ufw is available)
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 4000/tcp 2>/dev/null || true
        sudo ufw allow 4001/tcp 2>/dev/null || true
    fi
    
    # Start service
    sudo systemctl enable cryptun
    sudo systemctl start cryptun
    
    # Wait a moment for startup
    sleep 3
    
    echo '⮑  Cryptun deployed successfully!'
    echo '⮑  Dashboard: http://'\$(curl -s ifconfig.me)':4000'
    echo '⮑  Gateway: http://'\$(curl -s ifconfig.me)':4001'
    echo ''
    echo '⊂⊃ Service status:'
    sudo systemctl status cryptun --no-pager -l
"

# Get the external IP for easy access
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

echo ""
echo "⬡  Deployment complete!"
echo ""
echo "⛭  Instance Details:"
echo "   Name: $INSTANCE_NAME"
echo "   Zone: $ZONE"
echo "   Project: $PROJECT"
echo "   External IP: $EXTERNAL_IP"
echo ""
echo "⛭  Access URLs:"
echo "   Dashboard: http://$EXTERNAL_IP:4000"
echo "   Gateway: http://$EXTERNAL_IP:4001"
echo ""
echo "⛭  Management Commands:"
echo "   SSH to instance: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT"
echo "   Check status: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command='sudo systemctl status cryptun'"
echo "   View logs: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command='sudo journalctl -u cryptun -f'"
echo "   Stop service: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command='sudo systemctl stop cryptun'"
echo ""
echo "⛭  Firewall Rules (if needed):"
echo "   gcloud compute firewall-rules create allow-cryptun-dashboard --allow tcp:4000 --source-ranges 0.0.0.0/0"
echo "   gcloud compute firewall-rules create allow-cryptun-gateway --allow tcp:4001 --source-ranges 0.0.0.0/0"
