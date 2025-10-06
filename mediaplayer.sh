#!/bin/bash

# waybar-dotfiles Copyright (C) 2025 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

set -euo pipefail

# kill previous instances of the same mode
if [[ "${1-}" == "controlinfo" || "${1-}" == "mediainfo" ]]; then
    pgrep -f "$0 ${1-}" | grep -v "^$$\$" | xargs -r kill || true
fi

ytmn=$(playerctl -l 2>/dev/null | grep 'chromium' || true)
pause=""
play=""

sanitize() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

check_spotify() {
    pgrep -x "youtube-music" > /dev/null
}

dbg() {
    echo "called : ${FUNCNAME[0]}"
    echo "${ytmn-}"
}

# Fallback when no player is found
no_player_output() {
    echo '{"class": "", "text": "", "tooltip": ""}'
    pkill -RTMIN+5 waybar || true
}

mediainfo() {
    dbg
    if ! check_spotify; then
        no_player_output
        exit 0
    fi

    prev_status_media=""
    prev_text=""
    prev_tooltip=""

    playerctl -p "$ytmn" metadata --format '{{status}}|{{xesam:artist}}|{{xesam:title}}|{{xesam:album}}' --follow | \
    while IFS='|' read -r status artist title album; do
        artist=$(sanitize "${artist-}")
        title=$(sanitize "${title-}")
        album=$(sanitize "${album-}")

        [[ -z $status || -z $artist || -z $title ]] && continue

        new_class=""
        [[ $status == "Playing" ]] && new_class="playing"
        [[ $status == "Paused" ]] && new_class="paused"

        new_text="$artist - $title"
        new_tooltip="$artist - $title - $album"

        if [[ "$prev_status_media" != "$status" || "$prev_text" != "$new_text" || "$prev_tooltip" != "$new_tooltip" ]]; then
            echo "{\"class\": \"$new_class\", \"text\": \"$new_text\", \"tooltip\": \"$new_tooltip\"}"
            pkill -RTMIN+5 waybar || true
            prev_status_media="$status"
            prev_text="$new_text"
            prev_tooltip="$new_tooltip"
        fi
    done
}

controlinfo() {
    dbg
    if ! check_spotify; then
        echo "{\"text\": \"$play\"}"
        pkill -RTMIN+5 waybar || true
        exit 0
    fi

    prev_status_playpause=""

    playerctl -p "$ytmn" status --follow | while read -r status; do
        status=$(sanitize "${status-}")
        [[ -z "$status" ]] && continue

        if [[ "$status" == "Playing" ]]; then
            new_status="$pause"
        else
            new_status="$play"
        fi

        if [[ "$prev_status_playpause" != "$new_status" ]]; then
            echo "{\"text\": \"$new_status\"}"
            pkill -RTMIN+5 waybar || true
            prev_status_playpause="$new_status"
        fi
    done
}

control() {
    case "${1-}" in
        playpause) playerctl -p "$ytmn" play-pause ;;
        next)      playerctl -p "$ytmn" next ;;
        previous)  playerctl -p "$ytmn" previous ;;
        *)         echo "Unknown command: $1"; exit 1 ;;
    esac
}

case "${1-}" in
    control)
        shift
        control "$@"
        ;;
    controlinfo)
        shift
        controlinfo "$@"
        ;;
    mediainfo)
        shift
        mediainfo "$@"
        ;;
    *)
        echo "Invalid command: ${1-}"
        exit 1
        ;;
esac
