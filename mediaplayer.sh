#!/bin/bash

# waybar-dotfiles Copyright (C) 2025 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

# kill previous instances of the script, prevents zombie processes when waybar is killed or restarted.
if [[ "$1" == "controlinfo" || "$1" == "mediainfo" ]]; then
    pgrep -f "$0 $1" | grep -v "^$$\$" | xargs -r kill
fi

ytmn=$(playerctl -l | grep 'chromium')
#ytmn=$(
#playerctl -l | grep 'chromium' | while read p; do
#    album=$(playerctl -p "$p" metadata xesam:album 2>/dev/null)
#    if [[ -n "$album" ]]; then
#        echo "$p"
#        break
#    fi
#done
#)
sleep_interval=1
prev_status_media=""
prev_status_playpause=""
prev_text=""
prev_tooltip=""
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
	echo $ytmn
}

mediainfo() {
	dbg
    while true; do
        if ! check_spotify; then
            new_text=""
            new_tooltip=""
            pkill -RTMIN+5 waybar
            if [[ "$prev_text" != "$new_text" || "$prev_tooltip" != "$new_tooltip" ]]; then
                echo "{\"class\": \"\", \"text\": \"$new_text\", \"tooltip\": \"$new_tooltip\"}"
                prev_text="$new_text"
                prev_tooltip="$new_tooltip"
            fi
            sleep $sleep_interval
            continue
        fi
        status=$(playerctl -p "$ytmn" status 2>/dev/null)
        artist=$(playerctl -p "$ytmn" metadata xesam:artist 2>/dev/null)
        title=$(playerctl -p "$ytmn" metadata xesam:title 2>/dev/null)
        album=$(playerctl -p "$ytmn" metadata xesam:album 2>/dev/null)

        artist=$(sanitize "$artist")
        title=$(sanitize "$title")
        album=$(sanitize "$album")

        if [[ -z $status || -z $artist || -z $title ]]; then
            sleep $sleep_interval
            continue
        fi

        new_class=""
        if [[ $status == "Playing" ]]; then
            new_class="playing"
        elif [[ $status == "Paused" ]]; then
            new_class="paused"
        fi
        new_text="$artist - $title"
        new_tooltip="$artist - $title - $album"

        if [[ "$prev_status_media" != "$status" || "$prev_text" != "$new_text" || "$prev_tooltip" != "$new_tooltip" ]]; then
            echo "{\"class\": \"$new_class\", \"text\": \"$new_text\", \"tooltip\": \"$new_tooltip\"}"
            pkill -RTMIN+5 waybar
            prev_status_media="$status"
            prev_text="$new_text"
            prev_tooltip="$new_tooltip"
        fi
        sleep $sleep_interval
    done
}

controlinfo() {
	dbg
    while true; do
        # Check if Spotify is running
        if ! check_spotify; then
            new_status="$play"
            if [[ "$prev_status_playpause" != "$new_status" ]]; then
                echo "{\"text\": \"$play\"}"
                pkill -RTMIN+5 waybar
                prev_status_playpause="$new_status"
            fi
            sleep $sleep_interval
            continue
        fi

        # Get player status and sanitize it
        status=$(playerctl -p "$ytmn" status 2>/dev/null)
        status=$(sanitize "$status")

        # Skip iteration if status is empty
        if [[ -z "$status" ]]; then
            sleep $sleep_interval
            continue
        fi

        # Determine the new status based on the player status
        if [[ "$status" == "Playing" ]]; then
            new_status="$pause"
        elif [[ "$status" == "Paused" ]]; then
            new_status="$play"
        else
            # Fallback to a default value if status is unexpected
            new_status="$play"
        fi

        # Update Waybar if the status has changed
        if [[ "$prev_status_playpause" != "$new_status" ]]; then
            echo "{\"text\": \"$new_status\"}"
            pkill -RTMIN+5 waybar
            prev_status_playpause="$new_status"
        fi

        sleep $sleep_interval
    done
}

control() {
	case "$1" in
		playpause)
			playerctl -p "$ytmn" play-pause
			;;
		next)
			playerctl -p "$ytmn" next
			;;
		previous)
			playerctl -p "$ytmn" previous
			;;
		*)
			echo "Unknown command: $1"
			exit 1
			;;
	esac
}

case "$1" in
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
        echo "Invalid command: $1"
        exit 1
        ;;
esac
