#!/usr/bin/env bash

set -eou pipefail

while ! pgrep -x youtube-music >/dev/null; do
  printf "waiting...\n"

  sleep .1
done
printf "player detected, waiting to launch browser"
sleep 5
browser="$1"
shift
"$browser" "$@"
