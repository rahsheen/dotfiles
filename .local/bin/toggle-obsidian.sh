#!/bin/bash

OSASCRIPT="/usr/bin/osascript"
OPEN_APP="/usr/bin/open"

OBSIDIAN_PID=$(pgrep -f -i Obsidian)

if [[ -z "$OBSIDIAN_PID" ]]; then
  "$OPEN_APP" -a Obsidian
else
  IS_MINIMIZED=$("$OSASCRIPT" -e 'tell application "System Events" to get value of attribute "AXMinimized" of window 1 of process "Obsidian"' 2>/dev/null)

  if [[ "$IS_MINIMIZED" == "true" ]]; then
    "$OSASCRIPT" -e 'tell application "System Events" to set value of attribute "AXMinimized" of window 1 of process "Obsidian" to false' 2>/dev/null
    "$OSASCRIPT" -e 'tell application "Obsidian" to activate'
  else
    "$OSASCRIPT" -e 'tell application "Obsidian" to activate'
    "$OSASCRIPT" -e 'tell application "System Events" to set value of attribute "AXMinimized" of window 1 of process "Obsidian" to true' 2>/dev/null
  fi
fi
