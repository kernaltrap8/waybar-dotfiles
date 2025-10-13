#!/bin/bash

# weather.sh Copyright (C) 2025 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

# bash setup
set -euo pipefail
RAND_STRING=$(tr -dc 'a-zA-Z0-9' <<< "$(echo $RANDOM$RANDOM)" | head -c5)
LOG_PREFIX="/tmp/.weather.sh-${RAND_STRING}"
ERROR_FILE="${LOG_PREFIX}/weather-error.log"

# constants
CITY="Wichita"
LAT=37.6872
LON=-97.3301
SLEEP_INTERVAL=3600
LOG_FILE="${LOG_PREFIX}/weather.log"

# bools
isLogEnabled=1

# logging setup
mkdir -p "${LOG_PREFIX}"
> "$LOG_FILE"
> "$ERROR_FILE"
exec 2>>"$ERROR_FILE"

# this is pretty cursed because now the
# calling convention is log my_var instead of
# log "$my_var"
function log_var() {
	if [[ $isLogEnabled -eq 0 ]]; then
		return
	fi
	local var_name=$1
	local var_value=${!var_name}
	printf '[%s] %s: %s\n' "$(date +"%Y/%m/%d-%H:%M:%S")" "$var_name" "$var_value" >> "$LOG_FILE"
}

function log_msg() {
	if [[ $isLogEnabled -eq 0 ]]; then
		return
	fi
	local var_value="$1"
	local caller="${FUNCNAME[1]}"
	printf '[%s] %s: %s\n' "$(date +"%Y/%m/%d-%H:%M:%S")" "$caller" "$var_value" >> "$LOG_FILE"
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
	    log_var POINT_DATA
	    STATIONS_URL=$(echo "$POINT_DATA" | jq -r '.properties.observationStations')
	    log_var STATIONS_URL
	    
	    # fallback if API fails
	    if [ -z "$STATIONS_URL" ] || [ "$STATIONS_URL" = "null" ]; then
	        echo "{\"text\": \"--\", \"tooltip\": \"Weather unavailable\"}"
	        sleep $SLEEP_INTERVAL
	        continue
	    fi
	    
	    # Get the nearest observation station
	    STATION_ID=$(curl -s --max-time 10 "$STATIONS_URL" | jq -r '.observationStations[0]')
	    log_var STATION_ID
	    
	    if [ -z "$STATION_ID" ] || [ "$STATION_ID" = "null" ]; then
	        echo "{\"text\": \"--\", \"tooltip\": \"Weather unavailable\"}"
	        sleep $SLEEP_INTERVAL
	        continue
	    fi
	    
	    # Fetch current observations
	    OBSERVATIONS=$(curl -s --max-time 10 "${STATION_ID}/observations/latest")
	    log_var OBSERVATIONS
	    
	    # Extract data
	    data=$(echo "$OBSERVATIONS" | jq '.properties')
	    log_var data
	    
	    cond=$(echo "$data" | jq -r '.textDescription // "Unknown"')
	    temp_c=$(echo "$data" | jq -r '.temperature.value // "null"')
	    
	    log_var cond
	    log_var temp_c
	        
	    # Temperature is in Celsius, convert to Fahrenheit
	    if [ "$temp_c" = "null" ] || [ -z "$temp_c" ]; then
	        temp="--"
	        unit="F"
	    else
	        temp=$(printf "%.0f" "$(echo "($temp_c * 9/5) + 32" | bc -l)")
	        unit="F"
	    fi
	    log_var temp
	    log_var unit
	    
	    # Determine if daytime (simple check: between 6 AM and 6 PM local time)
	    current_hour=$(date +"%H")
	    if [ "$current_hour" -ge 6 ] && [ "$current_hour" -lt 18 ]; then
	        is_daytime="true"
	    else
	        is_daytime="false"
	    fi
	    log_var is_daytime
	    
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
	    log_var emoji
	    
	    # Prefix + if non-negative number
	    if [[ "$temp" != "--" && "$temp" -ge 0 ]]; then
	        temp="+$temp"
	    fi
	    log_var temp
	    output="{\"text\": \"$emoji  $temp°$unit\", \"tooltip\": \"$cond - Weather in $CITY\"}"
	    # Output for Waybar
	    echo "$output"
	    log_var output
	    log_var SLEEP_INTERVAL
	    
	    # Check for empty/null values
	    empty_vars=()
	    vars_to_check=(
	    	POINT_DATA
	    	STATIONS_URL
	    	STATION_ID
	    	OBSERVATIONS
	    	data
				cond
				temp_c
				temp
				unit
				current_hour
				is_daytime
				emoji
				output
	    )
	    for var in "${vars_to_check[@]}"; do
	        [[ -z "${!var}" || "${!var}" = "null" ]] && empty_vars+=("$var")
	    done
	    if [ ${#empty_vars[@]} -gt 0 ]; then
	        log_msg "WARNING: some values were empty! API is likely experiencing issues. Empty: ${empty_vars[*]}"
	    fi
	  
	    sleep $SLEEP_INTERVAL
	done	
}

check_args "$@"
main
