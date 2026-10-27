#!/bin/sh
set -eu

CONFIG_DIR=${MEOWX_CONFIG_DIR:-/root/.config/mihomo}
mkdir -p "${CONFIG_DIR}"

# Keep command-line overrides usable, e.g.:
# docker run ... meowx-core -t -d /root/.config/mihomo
exec /usr/local/bin/meowx-core "${@}"
