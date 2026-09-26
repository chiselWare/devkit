#!/bin/bash
# =============================================================================
# run-chiselware.sh
#
# Launch the ChiselWare full development container with:
#   - Current directory mounted as /workspace
#   - Host SSH keys mounted read-only (for GitHub access)
#   - Host .gitconfig mounted read-only (for correct commit author)
#   - X forwarding for GTKWave (if a display is available)
#
# Usage:
#   ./run-chiselware-linux.sh [-v <version>] [shell command] 
#
#   or set version by environment variable (takes precedent over -v)
#
#   CHISELWARE_DEV_VERSION=<version>
#   ./run-chiselware-linux.sh [shell command] 
#
# Examples:
#   ./run-chiselware-linux.sh -v 0.7.1 # Interactive mode
#   ./run-chiselware-linux.sh -v 0.7.1 sbt test # Run command in container
#    CHISELWARE_DEV_VERSION=0.7.1 && ./run-chiselware-linux.sh sbt test
# =============================================================================

REGISTRY="ghcr.io/chiselware/dev-full"

VERSION=""
while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION="$OPTARG"
      ;;
    \?)
      echo "Error: unknown option -$OPTARG"
      echo "Usage: run-chiselware-linux.sh -v <x.y.z> [command...]"
      exit 1
      ;;
    :)
      echo "Error: -v requires a version argument"
      echo "Usage: run-chiselware-linux.sh -v <x.y.z> [command...]"
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))  # remove parsed flags, leaving any command args

if [ -z "$VERSION" ]; then
  if [ -z "$CHISELWARE_DEV_VERSION" ]; then
    echo "Error: No version argument or environmental variable found. Try either approach below:"
    echo "  run-chiselware-linux.sh -v <x.y.z> [command...]"
    echo "  CHISELWARE_DEV_VERSION=<x.y.z> && run_chiselware-linux.sh [command...]"
    exit 1
  else
    VERSION=$CHISELWARE_DEV_VERSION
  fi 
fi

SEMVER_REGEX="^[0-9]+\.[0-9]+\.[0-9]+$"
if [[ ! $VERSION =~ $SEMVER_REGEX ]]; then
  echo "Error: '$VERSION' is not valid semver format (expected x.y.z e.g. 0.7.1)"
  exit 1
fi

IMAGE="$REGISTRY:$VERSION"
echo "Using chiselware/dev-full:$VERSION"

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

# Create a name for the container based on where it started
cw() {
  basename "$PWD"
}

exec docker run -it --rm \
  --name $(cw) \
  -v "$(pwd):/workspace" \
  "${SSH_ARGS[@]}" \
  "${GIT_ARGS[@]}" \
  "${DISPLAY_ARGS[@]}" \
  "$IMAGE" \
  "${CONTAINER_CMD[@]}"
