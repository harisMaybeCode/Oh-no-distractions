#!/bin/bash
# SiteBlocker daemon script. Runs as root via launchd every minute and whenever
# the config changes. Adds/removes a marked block in /etc/hosts.
# Optional args (for testing): $1 = config file, $2 = hosts file, $3 = "HHMM DOW" override
CONFIG="${1:-/Library/Application Support/SiteBlocker/config.txt}"
HOSTS="${2:-/etc/hosts}"
BEGIN="# >>> SiteBlocker >>>"
END="# <<< SiteBlocker <<<"

get() { grep -E "^$1=" "$CONFIG" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'; }

ENABLED=$(get ENABLED); DAYS=$(get DAYS); SITES=$(get SITES); ALWAYS=$(get ALWAYS)
SLOTS=$(get SLOTS)
# Older configs only have a single START/END
[[ -z "$SLOTS" ]] && SLOTS="$(get START)-$(get END)"

[[ "$DAYS" =~ ^[1-7]*$ ]] || DAYS=""

if [[ -n "$3" ]]; then NOW=${3% *}; DOW=${3#* }; else NOW=$(date +%H%M); DOW=$(date +%u); fi
NOW=$((10#$NOW))

active=0
if [[ "$ENABLED" == "1" && "$DAYS" == *"$DOW"* ]]; then
  for slot in ${SLOTS//,/ }; do
    # Validate each slot (config is user-writable; never trust it)
    [[ "$slot" =~ ^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$ ]] || continue
    S=${slot%-*}; E=${slot#*-}; S=$((10#${S/:/})); E=$((10#${E/:/}))
    if (( S < E )); then (( NOW >= S && NOW < E )) && active=1
    elif (( S > E )); then (( NOW >= S || NOW < E )) && active=1   # overnight, e.g. 22:00-06:00
    fi
  done
fi

# Build the desired block: permanent sites always, scheduled sites only when active
list="$ALWAYS"
(( active )) && list="$list $SITES"
block=""
seen=" "
for site in $list; do
    [[ "$site" =~ ^[A-Za-z0-9.-]+$ ]] || continue
    site=${site#www.}
    [[ "$seen" == *" $site "* ]] && continue
    seen+="$site "
    for h in "$site" "www.$site"; do
      block+="127.0.0.1 $h"$'\n'"::1 $h"$'\n'
    done
done

# Current hosts without our block
base=$(sed "/^$BEGIN\$/,/^$END\$/d" "$HOSTS")
if [[ -n "$block" ]]; then
  new="$base"$'\n'"$BEGIN"$'\n'"$block$END"
else
  new="$base"
fi

if [[ "$new" != "$(cat "$HOSTS")" ]]; then
  printf '%s\n' "$new" > "$HOSTS"
  if [[ "$HOSTS" == "/etc/hosts" ]]; then
    dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null
  fi
fi
echo "active=$active"
