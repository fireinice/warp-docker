#!/bin/bash

# exit when any command fails
set -e

# create a tun device if not exist to ensure compatibility with Podman
if [ ! -e /dev/net/tun ]; then
    sudo mkdir -p /dev/net
    sudo mknod /dev/net/tun c 10 200
    sudo chmod 600 /dev/net/tun
fi

# start dbus
sudo mkdir -p /run/dbus
if [ -f /run/dbus/pid ]; then
    sudo rm /run/dbus/pid
fi
sudo dbus-daemon --config-file=/usr/share/dbus-1/system.conf

# Kill any existing instances of warp-svc before starting a new one
if pkill -x warp-svc -9; then
  echo "Existing warp-svc process killed."
fi

# Start warp-svc in the background and redirect output to exclude dbus messages
sudo warp-svc --accept-tos > >(grep -iv dns_owner) 2> >(grep -iv dns_owner >&2) &
WARP_PID=$!

# Trap SIGTERM and SIGINT, and forward those signals to the warp-svc process
trap "echo 'Stopping warp-svc...'; kill -TERM $WARP_PID; exit" SIGTERM SIGINT

# Maximum number of attempts to try the registration
MAX_ATTEMPTS=5
attempt_counter=0

echo "Attempting to start warp-svc and register..."

# Function to check service status and attempt registration
function attempt_registration {
  until warp-cli --accept-tos registration new &> /dev/null; do
    echo "Wait for warp-svc to start... Attempt $((++attempt_counter)) of $MAX_ATTEMPTS"
    sleep ${WARP_SLEEP}
    if [[ $attempt_counter -ge $MAX_ATTEMPTS ]]; then
      echo "Failed to register after $MAX_ATTEMPTS attempts. Exiting."
      return 1
    fi
  done
  echo "warp-svc has been started and registered successfully!"
}

# Call the registration function
if attempt_registration; then
  echo "Service started and registered successfully."
else
  echo "There was an issue starting the service or registering. Check logs for details."
  kill $WARP_PID
  exit 1
fi

GOST_SOCKS_PROXY=
if [ "$WARP_PROXY_PORT" -eq "$WARP_PROXY_PORT" ] 2>/dev/null; then
    echo "[entrypoint] Warp Proxy Only mode"
    warp-cli set-proxy-port ${WARP_PROXY_PORT}
    # Set the mode to proxy
    warp-cli --accept-tos mode proxy
    GOST_SOCKS_PROXY=" -F=socks://:${WARP_PROXY_PORT}"
fi

# Disable DNS log
warp-cli --accept-tos dns log disable

# Set the families mode based on the value of the FAMILIES_MODE variable
warp-cli --accept-tos dns families "${WARP_DNS_MODE}"

# Set the WARP_LICENSE if it is not empty
if [[ -n $WARP_LICENSE_KEY ]]; then
  warp-cli --accept-tos registration license "${WARP_LICENSE_KEY}"
fi

# Connect to the WARP service
warp-cli --accept-tos connect

while true; do
  # Check if warp-cli is connected
  if warp-cli --accept-tos status | grep -i connected > /dev/null; then
    echo "Connected successfully."
    break
  else
    echo "Not connected. Checking again..."
  fi
  # Wait for a specified time before checking again
  sleep "$WARP_SLEEP"
done

# Wait for warp-svc process to finish
# wait $WARP_PID

# start the proxy
gost $GOST_ARGS $GOST_SOCKS_PROXY
