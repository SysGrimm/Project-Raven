# 🚀 Add Project Raven's Tailscale to Existing LibreELEC

Want to add our Tailscale VPN integration to your existing LibreELEC installation? Here are the easiest ways:

## ⚡ Super Quick Install (One-liner)

SSH into your LibreELEC box and run:

```bash
curl -fsSL https://raw.githubusercontent.com/SysGrimm/Project-Raven/main/scripts/install-tailscale-addon.sh | bash
```

That's it! The script will:
- ✅ Detect your architecture automatically
- ✅ Download the correct Tailscale binary
- ✅ Install the addon with all dependencies
- ✅ Create default settings
- ✅ Offer to restart Kodi for you

## 🔧 Manual Installation

If you prefer to do it manually, see the [detailed guide](Add-Tailscale-to-Existing-LibreELEC.md).

## 🎯 What You Get

After installation, your LibreELEC will have:

- 🔐 **Secure VPN access** from anywhere
- 🌐 **Remote web interface** (no port forwarding needed)
- 📁 **File sharing** over secure tunnel
- 🎬 **Remote streaming** access to your media
- 🔑 **SSH access** via Tailscale network
- ⚙️ **Automatic startup** and reconnection

## 📱 Access Your LibreELEC Remotely

Once set up, you can access your LibreELEC from anywhere:

```bash
# SSH access (no local network needed)
ssh root@100.x.x.x

# Web interface
http://100.x.x.x:8080

# File shares
smb://100.x.x.x
```

## 🔄 Updates

To update Tailscale later, just run the installer again - it will update everything automatically.

## 📚 Need Help?

- 📖 [Full Installation Guide](Add-Tailscale-to-Existing-LibreELEC.md)
- 🐛 [Report Issues](https://github.com/SysGrimm/Project-Raven/issues)
- 💬 [Discussions](https://github.com/SysGrimm/Project-Raven/discussions)

---

*Project Raven makes LibreELEC better with optimizations, Tailscale VPN, and more!*
