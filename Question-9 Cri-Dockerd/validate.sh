#!/bin/bash

SERVICE="cri-docker"
SOCKET="/var/run/cri-dockerd.sock"

echo "Validating cri-dockerd setup..."
echo "--------------------------------"

# Check package installation
if ! dpkg -l | grep -q cri-dockerd; then
  echo "FAIL: cri-dockerd package is not installed"
  exit 1
fi
echo "PASS: cri-dockerd package is installed"

# Check service enabled
if ! systemctl is-enabled "$SERVICE" &>/dev/null; then
  echo "FAIL: cri-docker service is not enabled"
  exit 1
fi
echo "PASS: cri-docker service is enabled"

# Check service running
if ! systemctl is-active "$SERVICE" &>/dev/null; then
  echo "FAIL: cri-docker service is not running"
  exit 1
fi
echo "PASS: cri-docker service is running"

# Check socket exists
if [[ ! -S "$SOCKET" ]]; then
  echo "FAIL: cri-dockerd socket not found at $SOCKET"
  exit 1
fi
echo "PASS: cri-dockerd socket exists"

echo "--------------------------------"
echo "SUCCESS: cri-dockerd is correctly installed and running"
exit 0
