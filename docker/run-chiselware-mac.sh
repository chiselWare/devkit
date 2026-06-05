#!/bin/bash
# =============================================================================
# run-chiselware-mac.sh
#
# Launch the ChiselWare full development container on macOS (Apple Silicon).
#
# Differences from run-chiselware.sh (Linux):
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
#   ./run-chiselware-mac.sh                  # interactive shell (default version)
#   ./run-chiselware-mac.sh -v 0.7.1         # specific version
#   ./run-chiselware-mac.sh -v 0.7.1 sbt test  # specific version + command
#   ./run-chiselware-mac.sh sbt test         # run a single command and exit
#
# Examples:
#   cd ~/my-chisel-project && ./run-chiselware-mac.sh
#   ./run-chiselware-mac.sh sbt "testOnly org.chiselware.MySpec"
# =============================================================================

REGISTRY="chiselwareregistry.azurecr.io/dev-full"
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
# X forwarding — requires XQuartz on macOS
# Install from https://www.xquartz.org if you need GTKWave or Firefox
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
  --platform linux/amd64 \
  -v "$(pwd):/workspace" \
  "${SSH_ARGS[@]}" \
  "${GIT_ARGS[@]}" \
  "${DISPLAY_ARGS[@]}" \
  "$IMAGE" \
  "${CONTAINER_CMD[@]}"
