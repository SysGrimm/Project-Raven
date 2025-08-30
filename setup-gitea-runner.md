# Setting up Gitea Actions Runner

## Step 1: Generate Registration Token in Gitea

1. **Access your Gitea admin panel**:
   - Go to: http://192.168.176.113:3000
   - Login as admin user (`reaper`)

2. **Navigate to Actions settings**:
   - Go to **Site Administration** → **Actions** → **Runners**
   - OR directly: http://192.168.176.113:3000/admin/actions/runners

3. **Create a new runner**:
   - Click **"Add New Runner"** or **"Create Runner"**
   - You'll get a registration token (looks like: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)
   - Copy this token - you'll need it for registration

## Step 2: Register the Runner (Run this after getting the token)

```bash
# Replace YOUR_TOKEN_HERE with the actual token from Gitea
sudo act_runner register \
  --instance http://192.168.176.113:3000 \
  --token YOUR_TOKEN_HERE \
  --no-interactive \
  --name "unraid-builder" \
  --labels "ubuntu-latest:docker://node:16-bullseye,ubuntu-22.04:docker://node:16-bullseye"
```

## Step 3: Configure and Start the Runner

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

# Enable and start the service
sudo systemctl enable act_runner
sudo systemctl start act_runner

# Check status
sudo systemctl status act_runner
```

## Step 4: Test the Setup

After the runner is registered and running:

1. **Push a change** to your repository (any change to trigger the workflow)
2. **Check Actions tab** in Gitea: http://192.168.176.113:3000/reaper/soulbox/actions
3. **Monitor the build** - you should see workflow runs appearing

## Troubleshooting

### Check runner logs:
```bash
sudo journalctl -u act_runner -f
```

### Check runner status:
```bash  
sudo systemctl status act_runner
```

### Verify registration:
```bash
sudo cat /var/lib/act_runner/.runner
```

### Re-register if needed:
```bash
sudo rm /var/lib/act_runner/.runner
# Then run the register command again
```

## Current Status

✅ act_runner binary installed to `/usr/local/bin/act_runner`  
✅ Configuration generated at `/var/lib/act_runner/config.yaml`  
⏳ **Next: Get registration token from Gitea admin panel**  
⏳ **Then: Run registration and start service**  

---

Once this is complete, every push to main will automatically trigger SD card image builds!
