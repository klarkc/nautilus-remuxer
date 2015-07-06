# Nautilus-remuxer
Remuxing scripts without re-encoding for nautilus-scripts

# Pre-requisites
* FFmpeg (or libav)
* Zenity
* Gnome
* Nautilus

# Install Instructions
1. Allow install.sh script: `chmod +x install.sh`
2. Execute install.sh script with: `./install.sh`

# How add another extension to Remuxer?
1. Create a executable file into Remuxer folder, with:
```
#!/bin/bash
bash ~/.local/share/nautilus/scripts/Remuxer/remux.sh avi #CHANGE THE EXTENSION (eg: avi, mp3, mp4, mkv)
```
2. Execute `./install.sh` file
