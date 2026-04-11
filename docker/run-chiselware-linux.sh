#!/bin/bash
# =============================================================================
# run-chiselware-linux.sh
#
# Launch the ChiselWare full development container with:
#   - Current directory mounted as /workspace
#   - Host SSH keys mounted read-only (for GitHub access)
#   - Host .gitconfig mounted read-only (for correct commit author)
#   - X forwarding for GTKWave (if a display is available)
#
# Usage:
#   ./run-chiselware-linux.sh                  # interactive shell
#   ./run-chiselware-linux.sh sbt test         # run a single command and exit
#
# Examples:
#   cd ~/my-chisel-project && ~/run-chiselware-linux.sh
#   ./run-chiselware-linux.sh sbt "testOnly mypackage.MySpec"
# =============================================================================

IMAGE="chiselware/dev-full:0.7.1"

# ---------------------------------------------------------------------------
# X forwarding — attach if a display is available, skip silently if not
# ---------------------------------------------------------------------------
DISPLAY_ARGS=()
if [ -n "$DISPLAY" ] && [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
  xhost +local:docker > /dev/null 2>&1 || true
  DISPLAY_ARGS=(
    -e DISPLAY="$DISPLAY"
    -v /tmp/.X11-unix:/tmp/.X11-unix
  )
fi

# ---------------------------------------------------------------------------
# SSH keys — mounted read-only into a staging path, then copied and
# chowned inside the container at startup so root owns them correctly.
# SSH refuses keys not owned by the current user, and we cannot chown
# on the host as a non-root user.
# ---------------------------------------------------------------------------
SSH_ARGS=()
SSH_MOUNT_CMD=""
if [ -d "$HOME/.ssh" ]; then
  # Mount host keys to a staging path (not /root/.ssh directly)
  SSH_ARGS=(-v "$HOME/.ssh:/tmp/.ssh-host:ro")
  # Shell command run inside container before bash:
  # copy staging → /root/.ssh, fix ownership and permissions
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
# ---------------------------------------------------------------------------
# Build the startup command: fix SSH ownership then run user's command
if [ -n "$SSH_MOUNT_CMD" ]; then
  if [ $# -eq 0 ]; then
    # Interactive shell
    CONTAINER_CMD=("bash" "-c" "${SSH_MOUNT_CMD} && exec bash")
  else
    # Pass-through command
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
  -v "$(pwd):/workspace" \
  "${SSH_ARGS[@]}" \
  "${GIT_ARGS[@]}" \
  "${DISPLAY_ARGS[@]}" \
  "$IMAGE" \
  "${CONTAINER_CMD[@]}"
