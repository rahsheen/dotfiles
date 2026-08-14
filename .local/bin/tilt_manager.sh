#!/bin/bash

# Default action is 'disable'
ACTION="disable"
# Default targets if none are provided
DEFAULT_TARGETS="Cetus"

# --- Argument Parsing ---
# Check for the '--enable' flag
if [[ "$1" == "--enable" ]]; then
    ACTION="enable"
    # Shift to discard the '--enable' flag from the argument list
    shift
fi

# Set TARGETS. If arguments remain, use them. Otherwise, use the default.
if [[ "$#" -gt 0 ]]; then
    TARGETS="$@"
else
    TARGETS="$DEFAULT_TARGETS"
fi

TILT_APPS=$(jq -r \
  --arg targets "$TARGETS" \
  '
    .projects[] |
    ( $targets | split(" ") | map({(.): true}) | add ) as $target_map |

    select(
      .labels? | 
      type == "array" and 
      any(
        .[] ; 
        $target_map[.]
      )
    ) | 
    .name
    ' projects.json)

for item in $TILT_APPS; do
    echo "\"$ACTION\" -- \"$item\""
    /usr/local/bin/tilt ${ACTION} "$item"
done

