#!/bin/bash

# Cryptun GCloud Helper Scripts
# Collection of useful commands for managing Cryptun on Google Cloud

set -e

INSTANCE_NAME=${1:-"cryptun-server"}
ZONE=${2:-"asia-southeast1-b"}
PROJECT=${3:-$(gcloud config get-value project)}

show_help() {
    echo "Cryptun GCloud Helper Commands"
    echo "Usage: ./gcloud-helpers.sh [command] [instance-name] [zone] [project]"
    echo ""
    echo "Commands:"
    echo "  create     - Create a new VM instance for Cryptun"
    echo "  deploy     - Deploy Cryptun to existing instance"
    echo "  status     - Check Cryptun service status"
    echo "  logs       - View Cryptun logs"
    echo "  ssh        - SSH into the instance"
    echo "  stop       - Stop Cryptun service"
    echo "  start      - Start Cryptun service"
    echo "  restart    - Restart Cryptun service"
    echo "  firewall   - Create firewall rules"
    echo "  ip         - Get instance external IP"
    echo "  delete     - Delete the instance"
    echo ""
    echo "Examples:"
    echo "  ./gcloud-helpers.sh create my-cryptun-vm us-west1-a my-project"
    echo "  ./gcloud-helpers.sh deploy my-cryptun-vm"
    echo "  ./gcloud-helpers.sh status"
}

create_instance() {
    echo "🏗️  Creating GCloud instance: $INSTANCE_NAME"
    
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --project=$PROJECT \
        --machine-type=e2-micro \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --service-account=$(gcloud iam service-accounts list --format="value(email)" --filter="displayName:Compute Engine default service account" --project=$PROJECT) \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
        --tags=cryptun-server \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20231213,mode=rw,size=10,type=projects/$PROJECT/zones/$ZONE/diskTypes/pd-balanced \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --labels=app=cryptun \
        --reservation-affinity=any
    
    echo "✅ Instance created successfully!"
    echo "⏳ Waiting for instance to be ready..."
    sleep 30
    
    echo "🔧 Installing basic dependencies..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command="
        sudo apt-get update
        sudo apt-get install -y curl openssl
        echo 'Instance ready for Cryptun deployment!'
    "
    
    echo "🎉 Instance $INSTANCE_NAME is ready!"
    echo "Next step: ./deploy-gcloud.sh $INSTANCE_NAME $ZONE $PROJECT"
}

deploy_cryptun() {
    echo "🚀 Deploying Cryptun..."
    ./deploy-gcloud.sh $INSTANCE_NAME $ZONE $PROJECT
}

check_status() {
    echo "📊 Checking Cryptun status on $INSTANCE_NAME..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command="
        echo '=== Instance Status ==='
        uptime
        echo ''
        echo '=== Cryptun Service Status ==='
        sudo systemctl status cryptun --no-pager -l || echo 'Service not found'
        echo ''
        echo '=== Port Status ==='
        sudo netstat -tlnp | grep -E ':(4000|4001)' || echo 'Ports not listening'
    "
}

view_logs() {
    echo "📋 Viewing Cryptun logs on $INSTANCE_NAME..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command="
        sudo journalctl -u cryptun -f
    "
}

ssh_instance() {
    echo "🔗 Connecting to $INSTANCE_NAME..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT
}

stop_service() {
    echo "⏹️  Stopping Cryptun service..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command="
        sudo systemctl stop cryptun
        echo 'Cryptun service stopped'
    "
}

start_service() {
    echo "▶️  Starting Cryptun service..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command="
        sudo systemctl start cryptun
        sleep 2
        sudo systemctl status cryptun --no-pager -l
    "
}

restart_service() {
    echo "🔄 Restarting Cryptun service..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --command="
        sudo systemctl restart cryptun
        sleep 2
        sudo systemctl status cryptun --no-pager -l
    "
}

create_firewall_rules() {
    echo "🔥 Creating firewall rules for Cryptun..."
    
    # Check if rules already exist
    if gcloud compute firewall-rules describe allow-cryptun-dashboard --project=$PROJECT >/dev/null 2>&1; then
        echo "Dashboard firewall rule already exists"
    else
        gcloud compute firewall-rules create allow-cryptun-dashboard \
            --allow tcp:4000 \
            --source-ranges 0.0.0.0/0 \
            --target-tags cryptun-server \
            --project=$PROJECT
        echo "✅ Dashboard firewall rule created"
    fi
    
    if gcloud compute firewall-rules describe allow-cryptun-gateway --project=$PROJECT >/dev/null 2>&1; then
        echo "Gateway firewall rule already exists"
    else
        gcloud compute firewall-rules create allow-cryptun-gateway \
            --allow tcp:4001 \
            --source-ranges 0.0.0.0/0 \
            --target-tags cryptun-server \
            --project=$PROJECT
        echo "✅ Gateway firewall rule created"
    fi
    
    echo "🎉 Firewall rules configured!"
}

get_ip() {
    EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    echo "🌐 External IP: $EXTERNAL_IP"
    echo "📊 Dashboard: http://$EXTERNAL_IP:4000"
    echo "🚇 Gateway: http://$EXTERNAL_IP:4001"
}

delete_instance() {
    echo "⚠️  This will permanently delete instance $INSTANCE_NAME"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting instance..."
        gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --quiet
        echo "✅ Instance deleted"
    else
        echo "❌ Deletion cancelled"
    fi
}

# Main command dispatcher
case "${1:-help}" in
    create)
        create_instance
        ;;
    deploy)
        deploy_cryptun
        ;;
    status)
        check_status
        ;;
    logs)
        view_logs
        ;;
    ssh)
        ssh_instance
        ;;
    stop)
        stop_service
        ;;
    start)
        start_service
        ;;
    restart)
        restart_service
        ;;
    firewall)
        create_firewall_rules
        ;;
    ip)
        get_ip
        ;;
    delete)
        delete_instance
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
