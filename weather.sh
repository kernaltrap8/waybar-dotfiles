#!/bin/bash

# weather.sh Copyright (C) 2025 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

# bash setup
set -euo pipefail
ERROR_FILE="$HOME/scripts/weather-error.log"
#exec 2>>"$ERROR_FILE"

# constants
CITY="Wichita"
LAT=37.6872
LON=-97.3301
SLEEP_INTERVAL=3600
LOG_FILE="$HOME/scripts/weather.log"

# bools
isLogEnabled=1

# logging setup
mkdir -p "$HOME/scripts"
> "$LOG_FILE"
> "$ERROR_FILE"

# this is pretty cursed because now the
# calling convention is log my_var instead of
# log "$my_var"
function log() {
	if [[ $isLogEnabled -eq 0 ]]; then
		return
	fi
    local var_name=$1
    local var_value=${!var_name}
    printf '[%s] %s: %s\n' "$(date +"%Y/%m/%d-%H:%M:%S")" "$var_name" "$var_value" >> "$LOG_FILE"
}

function check_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-v|--version)
				echo -e "weather.sh Copyright (C) 2025 kernaltrap8\nThis program is licensed under the BSD-3-Clause license.\nThe license document can be viewed here: https://opensource.org/license/bsd-3-clause"
				exit 0
				;;
			--disable-logging)
				isLogEnabled=0
				shift
				;;
			--)
				shift
				break
				;;
			-*)
				echo "Invalid option: $1" >&2
				exit 1
				;;
			*)
				break
				;;
		esac
	done
}

# main script functionality
function main() {
	while true; do
	    echo "{\"text\": \"Getting weather...\", \"tooltip\": \"Weather in $CITY\"}"
	    
	    # Get observation station
	    POINT_DATA=$(curl -s --max-time 10 "https://api.weather.gov/points/${LAT},${LON}")
	    STATIONS_URL=$(echo "$POINT_DATA" | jq -r '.properties.observationStations')
	    
	    # fallback if API fails
	    if [ -z "$STATIONS_URL" ] || [ "$STATIONS_URL" = "null" ]; then
	        echo "{\"text\": \"--\", \"tooltip\": \"Weather unavailable\"}"
	        sleep $SLEEP_INTERVAL
	        continue
	    fi
	    
	    # Get the nearest observation station
	    STATION_ID=$(curl -s --max-time 10 "$STATIONS_URL" | jq -r '.observationStations[0]')
	    
	    if [ -z "$STATION_ID" ] || [ "$STATION_ID" = "null" ]; then
	        echo "{\"text\": \"--\", \"tooltip\": \"Weather unavailable\"}"
	        sleep $SLEEP_INTERVAL
	        continue
	    fi
	    
	    # Fetch current observations
	    OBSERVATIONS=$(curl -s --max-time 10 "${STATION_ID}/observations/latest")
	    log OBSERVATIONS
	    
	    # Extract data
	    data=$(echo "$OBSERVATIONS" | jq '.properties')
	    log data
	    
	    cond=$(echo "$data" | jq -r '.textDescription // "Unknown"')
	    log cond
	    
	    # Temperature is in Celsius, convert to Fahrenheit
	    temp_c=$(echo "$data" | jq -r '.temperature.value // "null"')
	    if [ "$temp_c" = "null" ] || [ -z "$temp_c" ]; then
	        temp="--"
	        unit="F"
	    else
	        temp=$(printf "%.0f" "$(echo "($temp_c * 9/5) + 32" | bc -l)")
	        unit="F"
	    fi
	    log temp
	    log unit
	    
	    # Determine if daytime (simple check: between 6 AM and 6 PM local time)
	    current_hour=$(date +"%H")
	    if [ "$current_hour" -ge 6 ] && [ "$current_hour" -lt 18 ]; then
	        is_daytime="true"
	    else
	        is_daytime="false"
	    fi
	    log is_daytime
	    
	    # Emoji mapping
	    emoji="❓"
	    if [ "$is_daytime" = "false" ]; then
	        # Night emojis
	        case "$cond" in
	            *Clear*|*Sunny*|*Fair*) emoji="🌙" ;;
	            *Cloudy*|*Overcast*) emoji="🌃" ;;
	            *"Partly Cloudy"*|*"Mostly Cloudy"*|*"Mostly Clear"*) emoji="🌃" ;;
	            *Showers*|*Rain*|*Drizzle*) emoji="🌧️" ;;
	            *Thunder*|*Storm*) emoji="⛈️" ;;
	            *Snow*|*Flurries*) emoji="❄️" ;;
	            *Fog*|*Mist*|*Haze*) emoji="🌫️" ;;
	        esac
	    else
	        # Day emojis
	        case "$cond" in
	            *Clear*|*Sunny*|*Fair*) emoji="☀️" ;;
	            *Cloudy*|*Overcast*) emoji="☁️" ;;
	            *"Partly Cloudy"*|*"Mostly Cloudy"*) emoji="⛅" ;;
	            *Showers*|*Rain*|*Drizzle*) emoji="🌧️" ;;
	            *Thunder*|*Storm*) emoji="⛈️" ;;
	            *Snow*|*Flurries*) emoji="❄️" ;;
	            *Fog*|*Mist*|*Haze*) emoji="🌫️" ;;
	        esac
	    fi
	    log emoji
	    
	    # Prefix + if non-negative number
	    if [[ "$temp" != "--" && "$temp" -ge 0 ]]; then
	        temp="+$temp"
	    fi
	    log temp
	    output="{\"text\": \"$emoji  $temp°$unit\", \"tooltip\": \"$cond - Weather in $CITY\"}"
	    # Output for Waybar
	    echo "$output"
	    log output
	    log SLEEP_INTERVAL
	    sleep $SLEEP_INTERVAL
	done	
}

check_args "$@"
main
