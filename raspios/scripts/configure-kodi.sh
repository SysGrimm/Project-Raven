#!/bin/bash

# Project Raven - Kodi Configuration Script
# Sets up Kodi with optimal settings for Jellyfin and CEC

set -e

KODI_USER="kodi"
KODI_HOME="/home/$KODI_USER"
KODI_DATA="$KODI_HOME/.kodi/userdata"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Function to create Kodi advanced settings
create_advanced_settings() {
    log "Creating Kodi advanced settings with LibreELEC optimizations..."
    
    cat > "$KODI_DATA/advancedsettings.xml" << 'EOF'
<advancedsettings>
    <!-- LibreELEC-based CEC Configuration -->
    <cec>
        <enabled>true</enabled>
        <ceclogaddresses>true</ceclogaddresses>
        <poweroffshutdown>true</poweroffshutdown>
        <poweroninit>true</poweroninit>
        <usececcec>true</usececcec>
        <cecactivatesource>true</cecactivatesource>
        <cecstandbydeactivate>true</cecstandbydeactivate>
        <builtinlibc>false</builtinlibc>
    </cec>
    
    <!-- LibreELEC Video Playback Optimizations -->
    <videoplayer>
        <!-- Hardware acceleration optimizations from LibreELEC -->
        <usevaapi>true</usevaapi>
        <usevdpau>false</usevdpau>
        <useomxplayer>false</useomxplayer>
        <adjustrefreshrate>2</adjustrefreshrate>
        <usedisplayasclock>false</usedisplayasclock>
        <synctype>1</synctype>
        
        <!-- LibreELEC memory optimizations for Pi -->
        <cachemembuffersize>20971520</cachemembuffersize>
        <readbufferfactor>4.0</readbufferfactor>
        
        <!-- Hardware video decoding -->
        <allowhwaccel>true</allowhwaccel>
        <usehwaccel>true</usehwaccel>
    </videoplayer>
    
    <!-- LibreELEC Audio Optimizations -->
    <audiooutput>
        <audiodevice>ALSA:hdmi:CARD=b1,DEV=0</audiodevice>
        <channels>2</channels>
        <config>2</config>
        <samplerate>48000</samplerate>
        <normalizelevels>false</normalizelevels>
        <guisoundmode>1</guisoundmode>
        <!-- LibreELEC audio buffer optimizations -->
        <streamsilence>1</streamsilence>
        <ac3transcode>false</ac3transcode>
        <dtspassthrough>true</dtspassthrough>
    </audiooutput>
    
    <!-- LibreELEC Network Optimizations -->
    <network>
        <curlclienttimeout>30</curlclienttimeout>
        <curllowspeedtime>20</curllowspeedtime>
        <curlretries>2</curlretries>
        <!-- LibreELEC buffer optimizations -->
        <buffermode>1</buffermode>
        <cachemembuffersize>20971520</cachemembuffersize>
        <readbufferfactor>4.0</readbufferfactor>
    </network>
    
    <!-- LibreELEC Performance Optimizations -->
    <videodatabase>
        <type>sqlite3</type>
        <host></host>
        <port></port>
        <user></user>
        <pass></pass>
    </videodatabase>
    
    <!-- LibreELEC Memory Management -->
    <cache>
        <!-- Optimized for Pi hardware -->
        <harddisk>
            <size>20971520</size>
        </harddisk>
        <dvd>
            <size>20971520</size>
        </dvd>
        <lan>
            <size>20971520</size>
        </lan>
        <internet>
            <size>20971520</size>
        </internet>
    </cache>
    
    <!-- Reduce logging for performance -->
    <loglevel>1</loglevel>
    <logging>
        <logtosyslog>false</logtosyslog>
    </logging>
    
    <!-- LibreELEC GUI Performance -->
    <gui>
        <algorithmdirtyregions>3</algorithmdirtyregions>
        <visualizedirtyregions>false</visualizedirtyregions>
    </gui>
    
    <!-- LibreELEC system optimizations -->
    <system>
        <!-- ARM-specific optimizations -->
        <playlistretries>10</playlistretries>
        <playlisttimeout>20</playlisttimeout>
    </system>
</advancedsettings>
EOF
    
    success "Advanced settings created with LibreELEC optimizations"
}

# Function to create Kodi GUI settings
create_gui_settings() {
    log "Creating Kodi GUI settings..."
    
    cat > "$KODI_DATA/guisettings.xml" << 'EOF'
<settings version="1">
    <!-- System Settings -->
    <category id="system">
        <setting id="powermanagement.wakeonaccess" default="true">true</setting>
        <setting id="powermanagement.shutdowntime" default="true">0</setting>
        <setting id="powermanagement.displaysoff" default="true">0</setting>
        <setting id="locale.timezone" default="true">US/Eastern</setting>
        <setting id="locale.use24hclock" default="true">false</setting>
    </category>
    
    <!-- Input Settings -->
    <category id="input">
        <setting id="input.peripherals" default="true">true</setting>
        <setting id="input.enablemouse" default="true">false</setting>
        <setting id="input.enablejoystick" default="true">true</setting>
        <setting id="input.joystickmaptype" default="true">1</setting>
    </category>
    
    <!-- Video Settings -->
    <category id="videoplayer">
        <setting id="videoplayer.usevaapi" default="true">true</setting>
        <setting id="videoplayer.usevdpau" default="true">false</setting>
        <setting id="videoplayer.adjustrefreshrate" default="true">2</setting>
        <setting id="videoplayer.usedisplayasclock" default="true">false</setting>
    </category>
    
    <!-- Audio Settings -->
    <category id="audiooutput">
        <setting id="audiooutput.audiodevice" default="false">ALSA:hdmi:CARD=b1,DEV=0</setting>
        <setting id="audiooutput.channels" default="true">2</setting>
        <setting id="audiooutput.config" default="true">2</setting>
        <setting id="audiooutput.samplerate" default="true">48000</setting>
    </category>
    
    <!-- Interface Settings -->
    <category id="lookandfeel">
        <setting id="lookandfeel.skin" default="false">skin.estuary</setting>
        <setting id="lookandfeel.skinsettings" default="true"></setting>
        <setting id="lookandfeel.font" default="true">Default</setting>
        <setting id="lookandfeel.skinzoom" default="true">0</setting>
        <setting id="lookandfeel.startupaction" default="true">0</setting>
        <setting id="lookandfeel.soundskin" default="true">SKINDEFAULT</setting>
    </category>
    
    <!-- Services -->
    <category id="services">
        <setting id="services.webserver" default="true">false</setting>
        <setting id="services.webserverport" default="true">8080</setting>
        <setting id="services.webserverusername" default="true">kodi</setting>
        <setting id="services.webserverpassword" default="true"></setting>
        <setting id="services.zeroconf" default="true">true</setting>
        <setting id="services.airplay" default="true">false</setting>
        <setting id="services.upnp" default="true">true</setting>
        <setting id="services.upnpserver" default="true">true</setting>
    </category>
</settings>
EOF
    
    success "GUI settings created"
}

# Function to create Jellyfin addon settings
create_jellyfin_settings() {
    log "Creating Jellyfin addon settings..."
    
    mkdir -p "$KODI_DATA/addon_data/plugin.video.jellyfin"
    
    cat > "$KODI_DATA/addon_data/plugin.video.jellyfin/settings.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<settings version="1">
    <!-- Connection Settings -->
    <setting id="server" default="true">http://localhost:8096</setting>
    <setting id="username" default="true">kodi</setting>
    <setting id="password" default="true"></setting>
    <setting id="verify_ssl" default="true">false</setting>
    <setting id="auth_check" default="true">30</setting>
    
    <!-- Sync Settings -->
    <setting id="sync_installed" default="true">true</setting>
    <setting id="sync_empty_shows" default="true">false</setting>
    <setting id="sync_artwork" default="true">true</setting>
    <setting id="force_sync" default="true">false</setting>
    
    <!-- Playback Settings -->
    <setting id="transcode" default="true">false</setting>
    <setting id="transcode_h265" default="true">false</setting>
    <setting id="transcode_hi10p" default="true">false</setting>
    <setting id="direct_play" default="true">true</setting>
    <setting id="direct_stream" default="true">true</setting>
    
    <!-- Advanced -->
    <setting id="log_level" default="true">1</setting>
    <setting id="replace_file_manager" default="true">false</setting>
    <setting id="cinema_mode" default="true">false</setting>
</settings>
EOF
    
    success "Jellyfin settings created"
}

# Function to set up autostart configuration
setup_autostart() {
    log "Setting up Kodi autostart configuration..."
    
    # Create autostart directory
    mkdir -p "$KODI_DATA/autoexec.py"
    
    # Create autoexec.py for startup actions
    cat > "$KODI_DATA/autoexec.py" << 'EOF'
# Project Raven Kodi Autoexec
import xbmc

# Wait for Kodi to fully load
xbmc.Monitor().waitForAbort(5)

# Log startup
xbmc.log("Project Raven: Kodi startup complete", xbmc.LOGINFO)

# Enable CEC on startup
xbmc.executebuiltin('CECActivateSource')

# Optional: Show a welcome notification
# xbmc.executebuiltin('Notification(Project Raven, Welcome to your media center!, 3000)')
EOF
    
    success "Autostart configuration created"
}

# Function to set proper permissions
set_permissions() {
    log "Setting proper file permissions..."
    
    chown -R $KODI_USER:$KODI_USER "$KODI_HOME/.kodi"
    chmod -R 755 "$KODI_HOME/.kodi"
    chmod 644 "$KODI_DATA"/*.xml
    
    success "Permissions set"
}

# Apply LibreELEC-style video optimizations
apply_video_optimizations() {
    log "Setting up LibreELEC-style video optimizations"
    
    # Copy video optimization script to system
    if [[ -f "${SCRIPT_DIR}/optimize-video.sh" ]]; then
        cp "${SCRIPT_DIR}/optimize-video.sh" "/usr/local/bin/"
        chmod +x "/usr/local/bin/optimize-video.sh"
        
        # Create systemd service to run optimizations
        cat > /etc/systemd/system/video-optimizations.service << 'EOF'
[Unit]
Description=Apply LibreELEC Video Optimizations
After=multi-user.target
Before=kodi.service
ConditionPathExists=/usr/local/bin/optimize-video.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/optimize-video.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable the service
        systemctl enable video-optimizations.service
        
        success "Video optimization service configured"
    else
        warn "optimize-video.sh not found, skipping video optimizations"
    fi
}

# Apply Jellyfin-specific optimizations
apply_jellyfin_optimizations() {
    log "Applying Jellyfin-specific optimizations"
    
    # Create Jellyfin service configuration
    mkdir -p "/etc/systemd/system/kodi.service.d"
    cat > "/etc/systemd/system/kodi.service.d/jellyfin-optimizations.conf" << 'EOF'
[Service]
# Jellyfin client optimizations
Environment="KODI_JELLYFINAUTH_TIMEOUT=30"
Environment="KODI_JELLYFIN_CACHE_SIZE=100"

# Memory optimizations for Jellyfin streaming
LimitNOFILE=8192
LimitNPROC=4096
EOF

    success "Jellyfin optimizations applied"
}

# Main function
main() {
    log "[LAUNCH] Configuring Kodi for Project Raven"
    echo "======================================"
    
    # Ensure Kodi user directories exist
    mkdir -p "$KODI_DATA"
    mkdir -p "$KODI_DATA/addon_data"
    
    # Create configuration files
    create_advanced_settings
    create_gui_settings
    create_jellyfin_settings
    setup_autostart
    set_permissions
    
    # Apply optimizations if running as root
    if [[ $EUID -eq 0 ]]; then
        apply_video_optimizations
        apply_jellyfin_optimizations
    fi
    
    success "Kodi configuration completed!"
    echo "=================================="
    echo "[INFO]  Configuration highlights:"
    echo "   [MEDIA] CEC enabled for TV remote control"
    echo "   [VIDEO] Hardware acceleration enabled"
    echo "   [AUDIO] Audio optimized for HDMI output"
    echo "   Jellyfin addon pre-configured"
    echo "   [PERFORMANCE] Performance optimizations applied"
}

# Check if running as root or kodi user
if [[ $EUID -eq 0 ]]; then
    # Running as root, execute main function
    main
elif [[ $(whoami) == "$KODI_USER" ]]; then
    # Running as kodi user, execute main function
    main
else
    echo "[ERROR] This script should be run as root or the kodi user"
    exit 1
fi
