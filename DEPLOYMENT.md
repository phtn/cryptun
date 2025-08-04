# Cryptun Deployment Guide

## Quick Deployment

### 1. Google Cloud Platform (Recommended)
```bash
# Create a new GCloud instance
./gcloud-helpers.sh create my-cryptun-server us-central1-a

# Deploy Cryptun to the instance
./deploy-gcloud.sh my-cryptun-server us-central1-a

# Create firewall rules
./gcloud-helpers.sh firewall my-cryptun-server us-central1-a

# Get access URLs
./gcloud-helpers.sh ip my-cryptun-server us-central1-a
```

### 2. Traditional SSH Deployment
```bash
# Deploy to your VM
./deploy.sh YOUR_VM_IP root

# Or with custom user
./deploy.sh YOUR_VM_IP ubuntu
```

### 2. Manual Deployment

**Build the release:**
```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
```

**Copy to server:**
```bash
scp _build/prod/rel/cryptun/releases/0.1.0/cryptun-0.1.0.tar.gz user@server:/opt/cryptun/
scp cryptun.service user@server:/tmp/
```

**Setup on server:**
```bash
# Create user and extract
sudo useradd -r -s /bin/false cryptun
sudo mkdir -p /opt/cryptun
cd /opt/cryptun
sudo tar -xzf cryptun-0.1.0.tar.gz
sudo chown -R cryptun:cryptun /opt/cryptun

# Install systemd service
sudo cp /tmp/cryptun.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cryptun
sudo systemctl start cryptun
```

## Configuration

### Environment Variables
```bash
# Required
SECRET_KEY_BASE=your_64_character_secret_key

# Optional (defaults shown)
CRYPTUN_DASHBOARD_PORT=4000
CRYPTUN_GATEWAY_PORT=4001
```

### Generate Secret Key
```bash
# Generate a secure secret key
openssl rand -base64 64 | tr -d '\n'
```

## Service Management

### Systemd Commands
```bash
# Check status
sudo systemctl status cryptun

# View logs
sudo journalctl -u cryptun -f

# Restart service
sudo systemctl restart cryptun

# Stop service
sudo systemctl stop cryptun
```

### Manual Control
```bash
# Start manually
/opt/cryptun/bin/cryptun start

# Stop manually
/opt/cryptun/bin/cryptun stop

# Get status
/opt/cryptun/bin/cryptun pid
```

## Firewall Setup

### Open Required Ports
```bash
# Ubuntu/Debian
sudo ufw allow 4000/tcp  # Dashboard
sudo ufw allow 4001/tcp  # Gateway

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=4000/tcp
sudo firewall-cmd --permanent --add-port=4001/tcp
sudo firewall-cmd --reload
```

## Access Your Deployment

### URLs
- **Dashboard**: `http://YOUR_SERVER_IP:4000`
- **Gateway**: `http://YOUR_SERVER_IP:4001`
- **API**: `http://YOUR_SERVER_IP:4000/api/`

### First Steps
1. Open the dashboard in your browser
2. Go to "API Keys" tab
3. Create your first API key
4. Test tunnel creation

## Monitoring

### Health Check
```bash
# Check if services are running
curl http://YOUR_SERVER_IP:4000/api/tunnels
```

### Log Locations
- **Systemd logs**: `journalctl -u cryptun`
- **Application logs**: Console output via systemd

## Troubleshooting

### Common Issues

**Service won't start:**
```bash
# Check logs
sudo journalctl -u cryptun -n 50

# Check permissions
ls -la /opt/cryptun/
```

**Port conflicts:**
```bash
# Check what's using ports
sudo netstat -tlnp | grep :4000
sudo netstat -tlnp | grep :4001
```

**Permission issues:**
```bash
# Fix ownership
sudo chown -R cryptun:cryptun /opt/cryptun
```

### Debug Mode
```bash
# Run manually for debugging
sudo -u cryptun /opt/cryptun/bin/cryptun console
```

## Updating

### Deploy New Version
```bash
# Build new release
MIX_ENV=prod mix release

# Stop service
sudo systemctl stop cryptun

# Replace files
cd /opt/cryptun
sudo rm -rf ./*
sudo tar -xzf /path/to/new/cryptun-0.1.0.tar.gz
sudo chown -R cryptun:cryptun /opt/cryptun

# Start service
sudo systemctl start cryptun
```

## Security Considerations

### Production Checklist
- [ ] Change default SECRET_KEY_BASE
- [ ] Run as non-root user (cryptun)
- [ ] Configure firewall rules
- [ ] Use HTTPS proxy (nginx/caddy) for production
- [ ] Set up log rotation
- [ ] Monitor resource usage

### Reverse Proxy (Optional)
```nginx
# nginx configuration
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Performance Tuning

### VM Requirements
- **Minimum**: 1 CPU, 512MB RAM
- **Recommended**: 2 CPU, 1GB RAM
- **Storage**: 1GB for application + logs

### Erlang VM Tuning
Edit `/etc/systemd/system/cryptun.service`:
```ini
Environment=ERL_OPTS="+sbwt none +sbwtdcpu none +sbwtdio none"
Environment=ERL_MAX_PORTS=65536
```

## Backup

### What to Backup
- Configuration: `/etc/systemd/system/cryptun.service`
- Application: `/opt/cryptun/` (optional, can rebuild)
- Logs: `journalctl -u cryptun` (if needed)

### Backup Script
```bash
#!/bin/bash
tar -czf cryptun-backup-$(date +%Y%m%d).tar.gz \
  /etc/systemd/system/cryptun.service \
  /opt/cryptun/
```