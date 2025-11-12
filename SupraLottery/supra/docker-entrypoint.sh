#!/usr/bin/env bash
set -euo pipefail

if [ -f /supra/supra ]; then
  chmod +x /supra/supra || true
fi

echo 'supra() { /supra/supra "$@"; }' >> ~/.profile
echo "alias supra='/supra/supra'" >> ~/.bashrc

if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec bash
fi
