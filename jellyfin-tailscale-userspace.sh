#!/bin/bash

# Jellyfin Tailscale Sidecar - Userspace Mode
# This avoids conflicts with the host's Tailscale installation

echo "Starting Jellyfin Tailscale sidecar in userspace mode..."

# Stop any existing container
docker stop jellyfin-tailscale 2>/dev/null
docker rm jellyfin-tailscale 2>/dev/null

# Create the sidecar container in userspace mode
docker run -d \
  --name jellyfin-tailscale \
  --env TS_AUTHKEY='tskey-auth-kD8CZdc1Ns11CNTRL-hjSYZYQAMBL416mKhY2fBLqZdd1yaikk' \
  --env TS_STATE_DIR=/var/lib/tailscale \
  --env TS_USERSPACE=true \
  --env TS_EXTRA_ARGS='--advertise-tags=tag:container --hostname=jellyfin-nas' \
  --volume /mnt/user/appdata/jellyfin-tailscale:/var/lib/tailscale \
  --restart unless-stopped \
  --network container:Jellyfin \
  tailscale/tailscale:latest

echo "Container started. Checking logs..."
sleep 5
docker logs jellyfin-tailscale --tail 10
