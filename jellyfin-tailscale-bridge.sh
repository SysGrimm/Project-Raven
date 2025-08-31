#!/bin/bash

# Jellyfin Tailscale Sidecar - Bridge Mode
# This creates a separate network and bridges it to Jellyfin

echo "Setting up Jellyfin Tailscale bridge..."

# Create a custom network for Jellyfin + Tailscale
docker network create jellyfin-network 2>/dev/null || echo "Network already exists"

# Stop existing containers
docker stop jellyfin-tailscale 2>/dev/null
docker rm jellyfin-tailscale 2>/dev/null

# Create Tailscale container with full privileges
docker run -d \
  --name jellyfin-tailscale \
  --env TS_AUTHKEY='tskey-auth-kD8CZdc1Ns11CNTRL-hjSYZYQAMBL416mKhY2fBLqZdd1yaikk' \
  --env TS_STATE_DIR=/var/lib/tailscale \
  --env TS_USERSPACE=false \
  --env TS_EXTRA_ARGS='--advertise-tags=tag:container --hostname=jellyfin-nas' \
  --volume /mnt/user/appdata/jellyfin-tailscale:/var/lib/tailscale \
  --volume /dev/net/tun:/dev/net/tun \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --restart unless-stopped \
  --network jellyfin-network \
  --ip 172.20.0.10 \
  tailscale/tailscale:latest

# Note: You would also need to connect the Jellyfin container to this network
echo "To complete setup, connect Jellyfin to the network:"
echo "docker network connect jellyfin-network Jellyfin --ip 172.20.0.11"
