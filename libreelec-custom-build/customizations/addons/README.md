# Popular Add-ons for LibreELEC Custom Build
# Place .zip files of add-ons in this directory to include them in the build

## Streaming Services
- plugin.video.youtube.zip
- plugin.video.netflix.zip  
- plugin.video.amazon-prime.zip
- plugin.video.disney.plus.zip
- plugin.video.hulu.zip

## Media Servers
- plugin.video.emby.zip
- plugin.video.jellyfin.zip
- plugin.video.plex.zip

## Live TV & Sports
- plugin.video.iptv.simple.zip
- script.tvguide.fullscreen.zip
- plugin.video.espn3.zip

## Useful Tools
- plugin.program.chrome.launcher.zip
- plugin.video.elementum.zip (BitTorrent)
- script.metadata.artwork.downloader.zip
- script.library.data.provider.zip

## Skins/Themes
- skin.aeon.nox.silvo.zip (Modern, clean interface)
- skin.arctic.fuse.2.zip (Material design inspired)
- skin.titan.bingie.mod.zip (Netflix-style interface)

## Repositories (for auto-updates)
- repository.kodinerds.zip
- repository.castagnait.zip  
- repository.matthuisman.zip

## Gaming (Optional)
- plugin.program.moonlight.zip (Game streaming)
- plugin.program.steam.link.zip
- game.retroplayer.zip

## Instructions:
1. Download the .zip files for desired add-ons
2. Place them in this directory
3. They will be automatically installed during image build
4. Add-ons will be available immediately after first boot

## Theme Customization:
- Edit customizations/settings/guisettings.xml to set default skin
- Place custom skin files in customizations/themes/
- Modify post-build.sh to apply additional theme customizations

## Note:
Some add-ons may require additional configuration after first boot.
Repository add-ons will enable automatic updates for included plugins.
