#!/bin/bash
###############################################################################
# Script Name: telemetry.sh
# Description:
# 	This script monitors hardware data, including CPU load, temperature, 
#  	RAM usage, and optionally GPU usage. Data temporarily stored and 
#	privately shared via a Telegram bot running in Docker (Python).
#
# Usage:
# 	./telemetry.sh [OPTIONS]
#
# Options:
# 	-t, --timestep <seconds> Set the sampling period (default: 30)
# 	--nogpu                  Disable GPU monitoring
#
# Dependencies:
#	- bash, awk, grep
# 	- nvidia-smi (if GPU monitoring enabled)
#	- Docker image built with ./build.sh
#
# Configuration:
# 	- Hardware specs in `.config`:
# 		Line 1: CPU thermal zone number
#	- Telegram API in `secrets.json`
#		Template: {
#				"chatID": "-12345",
#				"token": "-12345:ABCDE"
#			  }
#
# Author: Simone Roncallo
# Date: [2025-12-26]
###############################################################################

set -e

OPTS=$(getopt -o t: --long timestep:,nogpu -n 'telemetry.sh' -- "$@") # Get options
if [ $? -ne 0 ]; then
  echo "Error"
  exit 1
fi

eval set -- "$OPTS"

timestep=30 # Sampling period (seconds)
readgpu=true # Get GPU usage with nvidia-smi
while true; do
  case "$1" in
    --nogpu)
      readgpu=false
      shift 1
      ;;
    -t | --timestep)
      timestep="$2"
      shift 2
      ;;
    --) # End sequence
      shift
      break
      ;;
    *) # Match errors
      echo "Error"
      exit 1
      ;;
  esac
done

function sharedata() {
	# Send data using Telegram API (running in Docker)
	printf "\r\033[KSample #$1 -> Completed\n"
	echo "Starting Docker..."
	sudo docker run --rm --cap-drop=ALL --security-opt=no-new-privileges \
	--user=puppet -v $2:/home/puppet/work/data:ro \
	-v ./secrets.json:/home/puppet/work/secrets.json:ro \
	telegram-bot # Run Docker
	rm -rf $2 # Remove temporary data
	echo "Completed"
}

mapfile -t config < .config # Read configuration file
tzone=${config[0]} # CPU thermal zone number

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TMP="./${TIMESTAMP}.tmp" # Output temporary directory
mkdir -p ./$TMP
> ./$TMP/memFree.txt # Free RAM (kB)
> ./$TMP/cpuLoad.txt # Average CPU load (1 minute)
> ./$TMP/cpuTemp.txt # Temperature (mC)
if $readgpu; then
	> ./$TMP/gpuUsed.txt # Used VRAM (MB)
	> ./$TMP/gpuTotal.txt # Total VRAM (MB)
fi

counter=1
hostnamectl | grep "Static hostname:" | awk '{print $3}' > ./$TMP/hostName.txt # Device
hostnamectl | grep "Operating System:" | awk '{print $3, $4, $5}' > ./$TMP/distroName.txt # Distribution
nproc > ./$TMP/numCores.txt
grep MemTotal: /proc/meminfo | awk '{print $2}' > ./$TMP/memTotal.txt # Total RAM (kB)
echo "Getting data..."
while true; do
	printf "\r\033[KSample #${counter}"
	grep MemFree: /proc/meminfo | awk '{print $2}' >> ./$TMP/memFree.txt
	cat /proc/loadavg | awk '{print $1}' >> ./$TMP/cpuLoad.txt
	cat /sys/class/thermal/thermal_zone${tzone}/temp >> ./$TMP/cpuTemp.txt
	if $readgpu; then
		nvidia-smi | grep W | awk '{print substr($9, 1, length($9) - 3)}' >> ./$TMP/gpuUsed.txt
		nvidia-smi | grep W | awk '{print substr($11, 1, length($11) - 3)}' >> ./$TMP/gpuTotal.txt
	fi

	counter=$(($counter + 1))
	sleep $timestep
	trap "sharedata $counter $TMP" SIGINT
done
