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
#   ./run-chiselware-wsl.sh                  # interactive shell (default version)
#   ./run-chiselware-wsl.sh -v 0.7.1         # specific version
#   ./run-chiselware-wsl.sh -v 0.7.1 sbt test  # specific version + command
#   ./run-chiselware-wsl.sh sbt test         # run a single command and exit
#
# Examples:
#   cd ~/my-chisel-project && ./run-chiselware-wsl.sh
#   ./run-chiselware-wsl.sh sbt "testOnly org.chiselware.MySpec"
# =============================================================================

REGISTRY="ghcr.io/chiselware/dev-full"
# ---------------------------------------------------------------------------
# -v <version> flag — required, must be valid semver x.y.z
# Usage: ./run-chiselware.sh -v <x.y.z> [command...]
# Example: ./run-chiselware.sh -v 0.7.1
#          ./run-chiselware.sh -v 0.7.1 sbt test
# ---------------------------------------------------------------------------
VERSION=""
while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION="$OPTARG"
      ;;
    \?)
      echo "Error: unknown option -$OPTARG"
      echo "Usage: $0 -v <x.y.z> [command...]"
      exit 1
      ;;
    :)
      echo "Error: -v requires a version argument"
      echo "Usage: $0 -v <x.y.z> [command...]"
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))  # remove parsed flags, leaving any command args

if [ -z "$VERSION" ]; then
  echo "Error: -v <version> is required."
  echo "Usage: $0 -v <x.y.z> [command...]"
  echo "Example: $0 -v 0.7.1"
  exit 1
fi

SEMVER_REGEX="^[0-9]+\.[0-9]+\.[0-9]+$"
if [[ ! $VERSION =~ $SEMVER_REGEX ]]; then
  echo "Error: '$VERSION' is not valid semver format (expected x.y.z e.g. 0.7.1)"
  exit 1
fi

IMAGE="$REGISTRY:$VERSION"
echo "Using ChiselWare dev-full:$VERSION"

# ---------------------------------------------------------------------------
# Verify we are running inside WSL2
# ---------------------------------------------------------------------------
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "WARNING: This script is intended for WSL2. You may be running native Linux."
  echo "         Use run-chiselware.sh instead if you are on native Linux."
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
    # Interactive shell — run SSH setup then drop into bash
    CONTAINER_CMD=("bash" "-c" "${SSH_MOUNT_CMD} && exec bash")
  else
    # Pass-through command — run SSH setup then exec the command array
    # Using printf '%q' safely quotes each argument to avoid word splitting
    QUOTED_CMD=$(printf '%q ' "$@")
    CONTAINER_CMD=("bash" "-c" "${SSH_MOUNT_CMD} && exec ${QUOTED_CMD}")
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
