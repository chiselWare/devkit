# =============================================================================
# ChiselWare Full Development Environment
# Mirrors Azure VM cloud-init exactly — all versions pinned.
#
# Installed tools:
#   - OpenJDK 21.0.9
#   - sbt 1.11.7
#   - Scala CLI 1.10.1
#   - firtool 1.47.0
#   - Verilator 5.020-1
#   - Icarus Verilog 12.0-2build2
#   - GTKWave 3.3.116-1build2
#   - Yosys 0.33-5build2
#   - CUDD 3.0.0 (built from source)
#   - OpenSTA 2.7.0 @ aa3088885f1efa3150cdd8c962bebf0599b5ecf1
#   - TeXLive (latex-base, fonts-recommended, fonts-extra, latex-extra)
#   - VS Code CLI (code tunnel)
#   - X11 apps (GTKWave X forwarding support)
#
# Build:
#   docker build -t chiselware/dev-full:1.0.0 .
#
# Run (interactive shell):
#   docker run -it --rm -v $(pwd):/workspace chiselware/dev-full:1.0.0
#
# Run with X forwarding (GTKWave etc.):
#   docker run -it --rm \
#     -v $(pwd):/workspace \
#     -e DISPLAY=$DISPLAY \
#     -v /tmp/.X11-unix:/tmp/.X11-unix \
#     chiselware/dev-full:1.0.0
# =============================================================================

FROM ubuntu:24.04

# Prevent interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =============================================================================
# LAYER 1 — Base system + apt build tools + EDA packages (pinned versions)
# This layer changes only if Ubuntu package versions change.
# =============================================================================
RUN apt-get update && apt-get install -y \
    # --- Base dev + utilities ---
    curl \
    wget \
    git \
    build-essential \
    make \
    g++ \
    clang \
    gcc \
    cmake \
    bison \
    flex \
    bc \
    swig \
    zlib1g-dev \
    libeigen3-dev \
    # --- X11 (GTKWave X forwarding) ---
    x11-apps \
    # --- Tcl ---
    tcl \
    tcl-dev \
    # --- Java (JDK 21 — active runtime used by sbt) ---
    # Note: exact VM version string (21.0.9+10-1~24.04) is not available in
    # the Docker base image apt index. Installing by major version; the JDK
    # variant is used as the JRE-only packages are unavailable in this context.
    openjdk-21-jdk \
    # --- EDA tools (pinned to VM versions) ---
    verilator=5.020-1 \
    iverilog=12.0-2build2 \
    gtkwave=3.3.116-1build2 \
    yosys=0.33-5build2 \
    yosys-abc=0.33-5build2 \
    # --- Misc ---
    ca-certificates \
    gnupg \
    autoconf \
    automake \
    libtool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME explicitly to JDK 21
# openjdk-21-jdk installs to the same path as the jre variant on amd64
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# =============================================================================
# LAYER 2 — CUDD 3.0.0 (built from source)
# Pinned to exactly 3.0.0 via versioned tarball URL.
# This layer rarely changes.
# =============================================================================
RUN mkdir -p /opt/src \
    && cd /opt/src \
    && wget -O cudd-3.0.0.tar.gz \
       https://sourceforge.net/projects/cudd-mirror/files/cudd-3.0.0.tar.gz/download \
    && tar xvf cudd-3.0.0.tar.gz \
    && cd cudd-3.0.0 \
    && autoreconf -i \
    && mkdir -p build \
    && cd build \
    && ../configure --prefix=/opt/cudd \
    && make -j"$(nproc)" \
    && make install \
    # Clean up source to reduce layer size
    && cd / \
    && rm -rf /opt/src/cudd-3.0.0 /opt/src/cudd-3.0.0.tar.gz

# =============================================================================
# LAYER 3 — OpenSTA 2.7.0 (built from source, pinned to exact commit SHA)
# Commit: aa3088885f1efa3150cdd8c962bebf0599b5ecf1
# This layer rarely changes.
# =============================================================================
RUN git clone https://github.com/parallaxsw/OpenSTA.git /opt/OpenSTA-parallax \
    && cd /opt/OpenSTA-parallax \
    # Pin to exact commit — no floating HEAD
    && git checkout aa3088885f1efa3150cdd8c962bebf0599b5ecf1 \
    # Fix tcl.h include path for Ubuntu layout
    && grep -rl "#include <tcl.h>" . \
       | xargs -r sed -i "s|#include <tcl.h>|#include </usr/include/tcl/tcl.h>|g" \
    && cmake -S . -B build -DCUDD_DIR=/opt/cudd \
    && cd build \
    && make -j"$(nproc)" \
    && cp sta /usr/local/bin/sta \
    && chmod +x /usr/local/bin/sta \
    # Clean build artifacts but keep source for reference
    && rm -rf /opt/OpenSTA-parallax/build

# =============================================================================
# LAYER 4 — LaTeX
# texlive-fonts-extra is large (~1.5GB) and slow — isolated in its own layer
# so it only rebuilds if LaTeX packages change.
# =============================================================================
RUN apt-get update && apt-get install -y \
    texlive-latex-base \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-latex-extra \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# LAYER 5 — sbt 1.11.7
# Uses official sbt apt repository, pinned to 1.11.7.
# =============================================================================
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" \
      > /etc/apt/sources.list.d/sbt.list \
    && echo "deb https://repo.scala-sbt.org/scalasbt/debian /" \
      > /etc/apt/sources.list.d/sbt_old.list \
    && curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" \
       > /etc/apt/trusted.gpg.d/sbt.asc \
    && apt-get update \
    && apt-get install -y sbt=1.11.7 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# LAYER 6 — firtool 1.47.0
# Pinned via versioned GitHub release URL.
# =============================================================================
RUN curl -fLo /tmp/firrtl-bin-linux-x64.tar.gz \
      https://github.com/llvm/circt/releases/download/firtool-1.47.0/firrtl-bin-linux-x64.tar.gz \
    && tar -xvf /tmp/firrtl-bin-linux-x64.tar.gz -C /tmp \
    && cp /tmp/firtool-1.47.0/bin/firtool /usr/local/bin/firtool \
    && chmod +x /usr/local/bin/firtool \
    && rm -rf /tmp/firtool-1.47.0 /tmp/firrtl-bin-linux-x64.tar.gz

# =============================================================================
# LAYER 7 — Scala CLI 1.10.1
# Pinned to 1.10.1 via versioned release URL (NOT /latest/).
# VM had 1.10.1 installed; deliberately not upgrading to 1.12.4.
# =============================================================================
RUN curl -fLo /tmp/scala-cli.deb \
      https://github.com/Virtuslab/scala-cli/releases/download/v1.10.1/scala-cli-x86_64-pc-linux.deb \
    && dpkg -i /tmp/scala-cli.deb \
    || apt-get install -f -y \
    && rm -f /tmp/scala-cli.deb

# =============================================================================
# LAYER 8 — VS Code CLI (code tunnel)
# No version pin available from Microsoft's stable endpoint.
# Isolated in its own layer for easy rebuild if needed.
# =============================================================================
RUN mkdir -p /opt/vscode-cli \
    && cd /opt/vscode-cli \
    && curl -L "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" \
       -o vscode-cli.tar.gz \
    && tar -xzf vscode-cli.tar.gz \
    && rm -f vscode-cli.tar.gz \
    && ln -sf /opt/vscode-cli/code /usr/local/bin/code

# =============================================================================
# LAYER 9 — Firefox (Mozilla APT repo — avoids Ubuntu snap redirect)
# Isolated in its own layer so it never triggers rebuilds of EDA/LaTeX layers.
# Requires X forwarding at runtime (same as GTKWave).
# =============================================================================
RUN apt-get update && apt-get install -y wget gpg && \
    wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg \
        | gpg --dearmor > /usr/share/keyrings/mozilla-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mozilla-archive-keyring.gpg arch=amd64] https://packages.mozilla.org/apt mozilla main" \
        > /etc/apt/sources.list.d/mozilla-firefox.list && \
    echo "Package: firefox\nPin: origin packages.mozilla.org\nPin-Priority: 1000" \
        > /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update && apt-get install -y firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# LAYER 10 — Environment, workspace, entrypoint
# This layer is the cheapest to rebuild — put all ENV/config here.
# Always keep this as the final layer.
# =============================================================================

# Ensure all installed binaries are on PATH
ENV PATH="/usr/local/bin:${PATH}"

# Default working directory — mount your project here
WORKDIR /workspace

# Verify all tools are present and log versions at build time.
# gtkwave requires a display even for --version; we check binary existence instead.
RUN echo "=== ChiselWare Dev Environment ===" \
    && java -version \
    && sbt --version \
    && scala-cli version \
    && firtool --version \
    && yosys -V \
    && sta --version \
    && { which gtkwave > /dev/null 2>&1 && echo "gtkwave: OK (display required at runtime)"; } || echo "WARNING: gtkwave not found" \
    && { which firefox > /dev/null 2>&1 && firefox --version; } || echo "WARNING: firefox not found" \
    && iverilog -V 2>&1 | head -1 \
    && verilator --version \
    && pdflatex --version | head -1 \
    && code --version \
    && echo "=== All tools verified ==="

# Drop into bash by default
CMD ["/bin/bash"]
