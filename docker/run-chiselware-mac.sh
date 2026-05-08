#!/bin/bash
# =============================================================================
# run-chiselware-mac.sh
#
# Launch the ChiselWare full development container on macOS (Apple Silicon).
#
# Differences from run-chiselware-linux.sh (Linux):
#   - --platform linux/amd64 flag for Apple Silicon (M1/M2/M3)
#   - X forwarding uses XQuartz instead of built-in X11
#   - XQuartz must be installed separately: https://www.xquartz.org
#
# With your current directory mounted as /workspace:
#   - Host SSH keys mounted for GitHub access
#   - Host .gitconfig mounted for correct commit author
#   - X forwarding for GTKWave and Firefox (requires XQuartz)
#
# Usage:
#   ./run-chiselware-mac.sh                  # interactive shell
#   ./run-chiselware-mac.sh sbt test         # run a single command and exit
#
# Examples:
#   cd ~/my-chisel-project && ./run-chiselware-mac.sh
#   ./run-chiselware-mac.sh sbt "testOnly org.chiselware.MySpec"
# =============================================================================

IMAGE="ghcr.io/chiselware/dev-full:0.7.1"

# ---------------------------------------------------------------------------
# X forwarding — requires XQuartz on macOS
# Install from https://www.xquartz.org if you need GTKWave or Firefox
#
# Note: XQuartz needs to be manually restarted sometimes after software 
# updates. If you find errors, give that a try first. Also make sure to check
# the "Allow Network Connections" in Settings->Security.
# ---------------------------------------------------------------------------
DISPLAY_ARGS=()
if [ -n "$DISPLAY" ]; then
  # XQuartz sets DISPLAY to something like :0 or /private/tmp/com.apple.launchd.xxx/org.xquartz:0
  DISPLAY_ARGS=(
    -e DISPLAY="host.docker.internal:0"
    -v /tmp/.X11-unix:/tmp/.X11-unix
  )
  # Allow connections from Docker
  xhost +localhost > /dev/null 2>&1 || true
else
  echo "INFO: No display found — GTKWave and Firefox will not be available."
  echo "      Install XQuartz (https://www.xquartz.org) and restart your terminal for X forwarding."
fi

# ---------------------------------------------------------------------------
# SSH keys — copied into a staging path, chowned inside the container.
# SSH refuses keys not owned by the current user — chown runs inside
# the container where we are root.
# ---------------------------------------------------------------------------
SSH_ARGS=()
SSH_MOUNT_CMD=""
if [ -d "$HOME/.ssh" ]; then
  SSH_ARGS=(-v "$HOME/.ssh:/tmp/.ssh-host:ro")
  SSH_MOUNT_CMD="cp -r /tmp/.ssh-host/. /root/.ssh/ && \
    chown -R root:root /root/.ssh && \
    chmod 700 /root/.ssh && \
    find /root/.ssh -type f -exec chmod 600 {} \; && \
    find /root/.ssh -name '*.pub' -exec chmod 644 {} \; && \
    find /root/.ssh -name 'known_hosts' -exec chmod 644 {} \;"
else
  echo "WARNING: ~/.ssh not found — GitHub SSH access will not work inside the container."
fi

# ---------------------------------------------------------------------------
# Git config — attach if present
# ---------------------------------------------------------------------------
GIT_ARGS=()
if [ -f "$HOME/.gitconfig" ]; then
  GIT_ARGS=(-v "$HOME/.gitconfig:/root/.gitconfig:ro")
fi

# ---------------------------------------------------------------------------
# Run
# --platform linux/amd64 required for Apple Silicon (M1/M2/M3)
# Rosetta 2 handles the x86_64 emulation transparently
# ---------------------------------------------------------------------------
if [ -n "$SSH_MOUNT_CMD" ]; then
  if [ $# -eq 0 ]; then
    CONTAINER_CMD=("bash" "-c" "${SSH_MOUNT_CMD} && exec bash")
  else
    CONTAINER_CMD=("bash" "-c" "${SSH_MOUNT_CMD} && exec \"$@\"")
  fi
else
  if [ $# -eq 0 ]; then
    CONTAINER_CMD=("bash")
  else
    CONTAINER_CMD=("$@")
  fi
fi

exec docker run -it --rm \
  --platform linux/amd64 \
  -v "$(pwd):/workspace" \
  "${SSH_ARGS[@]}" \
  "${GIT_ARGS[@]}" \
  "${DISPLAY_ARGS[@]}" \
  "$IMAGE" \
  "${CONTAINER_CMD[@]}"
