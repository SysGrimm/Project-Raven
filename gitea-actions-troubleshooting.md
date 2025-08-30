# Gitea Actions Troubleshooting Guide

## Check 1: Is Gitea Actions Enabled?

### In Gitea Web UI:
1. **Go to your Gitea**: http://192.168.176.113:3000
2. **Admin Panel**: Site Administration → Configuration
3. **Look for Actions settings** - Actions should be enabled

### Alternative Check:
```bash
# Check if Actions API endpoint exists
curl -s "http://192.168.176.113:3000/api/v1/repos/reaper/soulbox/actions/runs" 
# If you get "404 page not found" - Actions might not be enabled
```

## Check 2: Is act-runner Installed and Running?

### Check if act-runner service exists:
```bash
sudo systemctl status act_runner
```

### Check if runner is registered:
```bash
sudo cat /var/lib/act_runner/.runner 2>/dev/null || echo "No runner registered"
```

### Check runner logs:
```bash
sudo journalctl -u act_runner -n 50
```

## Check 3: Enable Gitea Actions (if not enabled)

### Method 1: Via app.ini config file
```bash
# Find Gitea config file (usually in /data/gitea/conf/app.ini)
# Add or modify these settings:

[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://gitea.com
```

### Method 2: Via Environment Variables (for Docker)
If Gitea runs in Docker:
```bash
# Add these environment variables to your Gitea container:
GITEA__ACTIONS__ENABLED=true
GITEA__ACTIONS__DEFAULT_ACTIONS_URL=https://gitea.com
```

## Check 4: Register the act-runner (if not done)

### Get Registration Token:
1. **Gitea Admin Panel**: http://192.168.176.113:3000/admin/actions/runners  
2. **Create new runner** and get the token
3. **Register the runner**:

```bash
sudo act_runner register \
  --instance http://192.168.176.113:3000 \
  --token YOUR_REGISTRATION_TOKEN \
  --no-interactive \
  --name "unraid-builder" \
  --labels "ubuntu-latest:docker://node:16-bullseye,ubuntu-22.04:docker://node:16-bullseye"
```

### Start the runner service:
```bash
# Create systemd service
sudo tee /etc/systemd/system/act_runner.service << 'SERVICE_EOF'
[Unit]
Description=Gitea Actions runner
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/lib/act_runner
ExecStart=/usr/local/bin/act_runner daemon --config config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable act_runner
sudo systemctl start act_runner
```

## Check 5: Verify Workflow File

### Check if workflow exists:
```bash
ls -la .github/workflows/
cat .github/workflows/build-release.yml | head -10
```

### Validate workflow syntax:
The workflow should start with:
```yaml
name: Build SoulBox SD Card Image
on:
  push:
    branches: [ main ]
```

## Check 6: Test Workflow Trigger

### Manual trigger via web UI:
1. **Go to**: http://192.168.176.113:3000/reaper/soulbox/actions
2. **Look for**: "Build SoulBox SD Card Image" workflow  
3. **Click**: "Run workflow" button (if available)

### Trigger via push:
```bash
# Make a small change and push
echo "# Test trigger" >> README.md
git add README.md
git commit -m "test: Trigger workflow"
git push origin main
```

## Expected Results When Working:

### 1. Actions Tab Should Show:
- **URL**: http://192.168.176.113:3000/reaper/soulbox/actions
- **Content**: List of workflow runs
- **Status**: Running/Completed/Failed workflows

### 2. Runner Should Show as Online:
- **URL**: http://192.168.176.113:3000/admin/actions/runners
- **Status**: "unraid-builder" should show as active/online

### 3. Workflow Logs Should Show:
- Build process starting
- Docker commands executing
- Image creation process
- Artifact uploads

## Common Issues & Solutions:

### Issue: "404 page not found" for Actions API
**Solution**: Enable Gitea Actions in configuration

### Issue: No workflows visible in Actions tab  
**Solution**: Check workflow file location and syntax

### Issue: Workflows queued but not running
**Solution**: Register and start act-runner service

### Issue: Runner shows offline
**Solution**: Check runner service status and logs

### Issue: Build fails with permission errors
**Solution**: Ensure runner has Docker access and privileged mode

---

## Current Status Check Commands:

Run these commands to diagnose:

```bash
# 1. Check if act-runner binary exists
which act_runner

# 2. Check if runner is registered  
sudo cat /var/lib/act_runner/.runner

# 3. Check service status
sudo systemctl status act_runner

# 4. Check recent logs
sudo journalctl -u act_runner -n 20

# 5. Test Gitea Actions API
curl -s "http://192.168.176.113:3000/api/v1/repos/reaper/soulbox/actions/runs"
```

Let me know what these commands show!
