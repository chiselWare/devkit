#!/bin/bash
# =============================================================================
# run-chiselware-wsl.sh
#
# Launch the ChiselWare full development container on Windows via WSL2.
#
# Requirements:
#   - Windows 11 or Windows 10 (build 19041+)
#   - WSL2 with Ubuntu (recommended: Ubuntu 22.04 or 24.04)
#   - Docker Desktop with "Use the WSL 2 based engine" enabled
#     Settings → General → Use the WSL 2 based engine
#   - Docker Desktop WSL integration enabled for your distro:
#     Settings → Resources → WSL Integration → enable your distro
#
# X forwarding:
#   - Windows 11: WSLg provides X forwarding automatically — no setup needed
#   - Windows 10: Install VcXsrv (https://sourceforge.net/projects/vcxsrv/)
#     Launch with "Multiple windows", "Start no client", check "Disable access
#     control". Set DISPLAY in your ~/.bashrc: export DISPLAY=$(cat
#     /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
#
# Usage:
#   ./run-chiselware-wsl.sh                  # interactive shell
#   ./run-chiselware-wsl.sh sbt test         # run a single command and exit
#
# Examples:
#   cd ~/my-chisel-project && ./run-chiselware-wsl.sh
#   ./run-chiselware-wsl.sh sbt "testOnly org.chiselware.MySpec"
# =============================================================================

IMAGE="ghcr.io/chiselware/dev-full:0.7.1"

# ---------------------------------------------------------------------------
# Verify we are running inside WSL2
# ---------------------------------------------------------------------------
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "WARNING: This script is intended for WSL2. You may be running native Linux."
  echo "         Use run-chiselware-linux.sh instead if you are on native Linux."
fi

# ---------------------------------------------------------------------------
# X forwarding
# Windows 11 + WSLg: DISPLAY is set automatically, X11 socket is available
# Windows 10 + VcXsrv: DISPLAY must be set manually (see header comments)
# ---------------------------------------------------------------------------
DISPLAY_ARGS=()
if [ -n "$DISPLAY" ]; then
  if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
    # WSLg path — X11 socket available directly
    DISPLAY_ARGS=(
      -e DISPLAY="$DISPLAY"
      -v /tmp/.X11-unix:/tmp/.X11-unix
    )
  else
    # VcXsrv / Windows 10 path — use TCP display
    DISPLAY_ARGS=(
      -e DISPLAY="$DISPLAY"
    )
  fi
  echo "INFO: X forwarding enabled on DISPLAY=$DISPLAY"
else
  echo "INFO: No display found — GTKWave and Firefox will not be available."
  echo "      Windows 11: WSLg should set DISPLAY automatically."
  echo "      Windows 10: Install VcXsrv and set DISPLAY in ~/.bashrc"
  echo "      See script header for details."
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
  echo "         Your WSL2 home SSH keys should be at ~/.ssh/"
  echo "         Windows SSH keys at /mnt/c/Users/<username>/.ssh/ can be copied there."
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
# No --platform flag needed — WSL2 runs x86_64 natively
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
  -v "$(pwd):/workspace" \
  "${SSH_ARGS[@]}" \
  "${GIT_ARGS[@]}" \
  "${DISPLAY_ARGS[@]}" \
  "$IMAGE" \
  "${CONTAINER_CMD[@]}"