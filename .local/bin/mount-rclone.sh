#!/bin/bash
rclone nfsmount Dropbox:Obsidian ~/mnt/dropbox/Obsidian \
  --vfs-cache-mode full \
  --vfs-cache-max-age 24h \
  --vfs-cache-max-size 10G \
  --daemon "$@"
 
