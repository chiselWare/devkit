# ChiselWare Docker Environment

A fully containerized mirror of the ChiselWare Azure VM environment.
All tool versions are pinned to match the VM exactly.

The container is published to two registries:

| Registry                  | URL                                            | Audience             | Auth required  |
| ------------------------- | ---------------------------------------------- | -------------------- | -------------- |
| GitHub Container Registry | `ghcr.io/chiselware/dev-full:x.y.z`            | All users (public)   | None           |
| Azure Container Registry  | `chiselwareregistry.azurecr.io/dev-full:x.y.z` | Internal Azure teams | `az acr login` |

**GHCR is the default for all users.** ACR is available for teams already
working inside Azure, but not currently available.

> **Note on versioning:** the container (SSE) version may lag the
> infrastructure/DevKit release version. The SSE is only rebuilt and
> re-tagged when the toolchain itself changes. Major and minor versions
> are kept in sync across infrastructure, DevKit, and the container;
> patch versions may diverge. For example, infrastructure 0.8.2 may still
> ship the `dev-full:0.8.0` container if the SSE has not changed since
> 0.8.0.

---

## Directory Structure

```
docker/
├── Dockerfile                  # Full dev environment definition
├── .dockerignore
├── .devcontainer/
│   └── devcontainer.json       # VS Code Dev Container definition
├── run-chiselware-linux.sh     # Linux launch script
├── run-chiselware-mac.sh       # macOS Apple Silicon launch script
└── run-chiselware-wsl.sh       # Windows WSL2 launch script
```

This directory is synced to the public DevKit repository on each release,
so developers get the launch scripts, the Dev Container definition, and
this document without needing access to the infrastructure repository.

---

## Installed Toolchain

| Tool           | Version               |
| -------------- | --------------------- |
| Ubuntu         | 24.04                 |
| OpenJDK        | 21.x                  |
| sbt            | 1.11.7                |
| Scala CLI      | 1.10.1                |
| firtool        | 1.47.0                |
| Verilator      | 5.020-1               |
| Icarus Verilog | 12.0-2build2          |
| GTKWave        | 3.3.116-1build2       |
| Yosys          | 0.33-5build2          |
| CUDD           | 3.0.0                 |
| OpenSTA        | 2.7.0                 |
| sby            | v0.65 / v0.66         |
| Yices2         | 2.6.4                 |
| Z3             | Ubuntu 24.04 packaged |
| TeXLive        | Ubuntu 24.04 packaged |
| Firefox        | Mozilla APT repo      |
| VS Code CLI    | latest stable         |

Tool versions in this table must be kept in sync with `Dockerfile` and
`../tf/modules/chiselware-vm/cloud-init/apps.yaml.tmpl` on every release.

### Formal Verification Toolchain

`0.8.0` adds formal verification support via three tools:

- **sby (SymbiYosys) v0.65** — formal verification front-end; drives BMC
  and induction proofs against Verilog output from Yosys. Installed from
  source (not available in Ubuntu 24.04 apt).
- **Yices2 2.6.4** — SMT solver; installed from the official SRI binary
  tarball (not available in Ubuntu 24.04 apt).
- **Z3** — SMT solver; installed via apt. This is the default solver used
  by `chiseltest.formal` — no annotation needed in test code.

Yices2 is included alongside Z3 for users who prefer it or need it for
specific use cases. chiseltest 5.0.2 does not provide a Yices2 engine
annotation; Z3 is the only solver callable from `chiseltest.formal` directly.

> **sby version note:** the pinned sby commit
> `f57802a16613f013e84e024df50fc3f0ea74f88b` carries **both** the `v0.65`
> and `v0.66` tags — they point at the same commit. Depending on build
> timing, `sby --version` may report either. The Docker image reports
> v0.65; a fresh Azure VM build may report v0.66. They are identical
> code. Use the commit SHA, not the tag name, as the source of truth.

---

## VS Code Dev Container

The `.devcontainer/devcontainer.json` file provides the full SSE inside
VS Code with SSH keys, Git configuration, and Scala language support
(via Metals) configured automatically.

### Using it with a provisioned core repository

Every chiselWare Core repository provisioned by the IP Factory already
contains a `.devcontainer/` directory at its root. Open the repository
in VS Code and run **Dev Containers: Reopen in Container** from the
command palette. VS Code pulls the image and drops you inside the SSE
with your project mounted at `/workspace`. Nothing to copy or configure.

### Trying the SSE without a project

The DevKit ships this `.devcontainer/` directory as a reusable goody in
`docker/`. To try the SSE without an official chiselWare project:

```bash
# Create a scratch folder and copy the devcontainer into it
mkdir ~/sse-tryout
cp -r <devkit>/docker/.devcontainer ~/sse-tryout/
cd ~/sse-tryout
code .
# Then: Dev Containers: Reopen in Container
```

Your scratch folder becomes `/workspace` inside the container. This is a
pure evaluation environment — for real core development, use a
provisioned repository, which comes with its own identical
`.devcontainer/` at the root.

### The image version line

The `image` field in `devcontainer.json` pins the SSE container version:

```jsonc
// The "image" tag is the SSE container version, which may lag the
// infrastructure/DevKit release version. Bump it only when the SSE
// toolchain itself changes (a container rebuild).
"image": "ghcr.io/chiselware/dev-full:0.8.0"
```

The DevKit and `00-000-dff` template devcontainer files are intentionally
kept identical. If they ever differ, that is a deliberate choice, not
drift.

### Prerequisites

- Docker Desktop or Docker Engine
- VS Code with the **Dev Containers** extension
  (`ms-vscode-remote.remote-containers`)

### Browser-based access (code tunnel)

If you prefer not to install anything locally, launch the container and
start a tunnel — VS Code opens in your browser from any OS with no X
forwarding required:

```bash
run-chiselware-<platform>.sh
# Inside the container:
code tunnel
# Follow the GitHub auth prompt — opens VS Code in your browser
```

---

## User Setup

The launch scripts work out of the box and handle SSH key mounting, X
forwarding, and workspace binding. Rather than copying a script into each
project, add the DevKit `docker/` directory to your `PATH` so the scripts
are available from any project directory.

### Linux

```bash
# Pull (no authentication required)
docker pull ghcr.io/chiselware/dev-full:x.y.z

# Make script executable (first time only)
chmod +x run-chiselware-linux.sh

# Daily use — run from your project directory
cd ~/my-chisel-project
run-chiselware-linux.sh
```

### macOS (Apple Silicon)

```bash
# Install Docker Desktop from https://www.docker.com/products/docker-desktop/

# Pull with platform flag (image is x86_64, runs under Rosetta 2)
docker pull --platform linux/amd64 ghcr.io/chiselware/dev-full:x.y.z

# Make script executable (first time only)
chmod +x run-chiselware-mac.sh

# Daily use
cd ~/my-chisel-project
run-chiselware-mac.sh
```

**X forwarding on Mac (GTKWave, Firefox):**
Install XQuartz from https://www.xquartz.org, log out and back in, then
enable "Allow connections from network clients" in XQuartz Preferences →
Security. X forwarding activates automatically on next container launch.

### Windows (WSL2)

Requirements:
- Windows 11 or Windows 10 (build 19041+)
- WSL2 with Ubuntu (22.04 or 24.04 recommended)
- Docker Desktop with WSL2 backend enabled:
  Settings → General → Use the WSL 2 based engine
- Docker Desktop WSL integration enabled for your distro:
  Settings → Resources → WSL Integration → enable your distro

```bash
# Pull from inside WSL2 terminal (no authentication required)
docker pull ghcr.io/chiselware/dev-full:x.y.z

# Make script executable (first time only)
chmod +x run-chiselware-wsl.sh

# Daily use — run from your project directory inside WSL2
cd ~/my-chisel-project
run-chiselware-wsl.sh
```

**X forwarding on Windows:**
- Windows 11: WSLg provides X forwarding automatically — no setup needed
- Windows 10: Install VcXsrv from https://sourceforge.net/projects/vcxsrv/
  Launch with "Multiple windows", "Start no client", check "Disable access
  control". Add to your `~/.bashrc`:
  ```bash
  export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
  ```

**SSH keys on Windows:**
WSL2 uses `~/.ssh/` inside the WSL2 filesystem. If your keys are in
`C:\Users\username\.ssh\`, copy them into WSL2:
```bash
cp /mnt/c/Users/username/.ssh/id_rsa ~/.ssh/
cp /mnt/c/Users/username/.ssh/id_rsa.pub ~/.ssh/
chmod 600 ~/.ssh/id_rsa
```

### Internal Azure Teams (ACR)

```bash
az acr login --name chiselwareregistry
docker pull chiselwareregistry.azurecr.io/dev-full:x.y.z
```

Then update the `IMAGE` line in your run script to point to the ACR URL.

---

## GitHub Access

The run scripts mount your host SSH keys into the container. Use SSH URLs
for all git operations inside the container:

```bash
# Correct — uses your SSH key:
git clone git@github.com:chiselware/my-repo.git

# Wrong — always prompts for password:
git clone https://github.com/chiselware/my-repo.git
```

Your `~/.ssh/config` must reference key filenames that actually exist.
Verify before launching:

```bash
grep IdentityFile ~/.ssh/config
ls ~/.ssh/
```

SSH file permissions must be correct:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config ~/.ssh/*.pem
chmod 644 ~/.ssh/*.pub ~/.ssh/known_hosts
```

---

## Persisting Work

Containers are ephemeral — always work within `/workspace` which maps to
the directory you launched the script from on your host:

```bash
cd ~/my-chisel-project   # this directory becomes /workspace inside container
run-chiselware-<platform>.sh
```

Files written outside `/workspace` are lost when the container exits.
Always launch the script from your project root so all generated files
are accessible on your host after the container exits.

---

## Report Output Files

The regression harness generates HTML reports (coverage, documentation)
under `/workspace`. The `make` targets open them automatically in the
container's Firefox via X forwarding. Because `/workspace` is mounted
from your host, you can also open the same files in your host browser
after the container exits — they persist on disk either way.

---

## Building the Image

Maintainers only — users pull from GHCR and never build locally.

```bash
cd modules/docker
docker build -t chiselware/dev-full:x.y.z .
```

First build takes 30–45 minutes. Layer order is optimized so subsequent
rebuilds only re-run changed layers.

### Layer Order (slowest → fastest to change)

| Layer | Contents                           | Approx time |
| ----- | ---------------------------------- | ----------- |
| 1     | Base apt tools + EDA packages + Z3 | 3–5 min     |
| 2     | CUDD 3.0.0 (source build)          | 3–5 min     |
| 3     | OpenSTA 2.7.0 (source build)       | 8–12 min    |
| 4     | Yices2 2.6.4 (binary tarball)      | <1 min      |
| 5     | sby (source build)                 | 1–2 min     |
| 6     | LaTeX                              | 10–20 min   |
| 7     | sbt 1.11.7                         | 1–2 min     |
| 8     | firtool 1.47.0                     | <1 min      |
| 9     | Scala CLI 1.10.1                   | <1 min      |
| 10    | VS Code CLI                        | <1 min      |
| 11    | Firefox                            | 2–3 min     |
| 12    | ENV, WORKDIR, verification         | <1 min      |

### Forcing a Layer Rebuild

Docker caches layers aggressively. To force a specific layer to rebuild
without rebuilding everything, add a comment change to that layer's `RUN`
block — Docker treats any change as a cache miss. To rebuild everything:

```bash
docker build --no-cache -t chiselware/dev-full:x.y.z .
```

### Pinning the sby Commit SHA

sby is installed from source and pinned to commit
`f57802a16613f013e84e024df50fc3f0ea74f88b` (tags v0.65 and v0.66 both
point here). The Dockerfile uses the short form `f57802a`.

When updating sby in a future release, get the new commit SHA and verify
the version inside the running container:

```bash
# Inside the container, after building:
cd /opt/src/sby && git log --oneline -1
sby --version
# Copy the full SHA into Dockerfile Layer 5 and apps.yaml.tmpl
```

Always use the commit SHA verified against the running container, not a
tag name — tags can point at multiple commits or move between releases.

---

## Release Checklist

When releasing ChiselWare `x.y.z`:

**1. Decide whether the SSE changed this release**

- **If the SSE toolchain changed** (any tool added, removed, or version
  bumped): rebuild and re-tag the container at the new version, update
  the toolchain table above, update the `image` line in
  `.devcontainer/devcontainer.json`, and keep `Dockerfile` and
  `../tf/modules/chiselware-vm/cloud-init/apps.yaml.tmpl` in sync.
- **If the SSE did not change**: leave the container tag and the
  `devcontainer.json` image line as they are. The container version is
  allowed to lag the infrastructure version on patch releases.

Run `make version-check` and confirm the reported container image tag
matches your intent — the report shows the container tag alongside the
infrastructure version so an intentional lag is visible and a mistaken
one is caught.

**2. Build and test locally (only if the SSE changed)**

```bash
docker build -t chiselware/dev-full:x.y.z .
run-chiselware-<platform>.sh   # verify tools, run a regression
```

**3. Push to GHCR (public)**

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker tag chiselware/dev-full:x.y.z ghcr.io/chiselware/dev-full:x.y.z
docker push ghcr.io/chiselware/dev-full:x.y.z
```

After pushing, ensure the package is set to **Public** in GitHub:
Settings → Packages → dev-full → Change visibility → Public

**4. Push to ACR (internal)**

```bash
az acr login --name chiselwareregistry
docker tag chiselware/dev-full:x.y.z chiselwareregistry.azurecr.io/dev-full:x.y.z
docker push chiselwareregistry.azurecr.io/dev-full:x.y.z
```

**5. Commit**

```bash
git add Dockerfile .devcontainer/devcontainer.json DOCKER.md \
        run-chiselware-linux.sh run-chiselware-mac.sh run-chiselware-wsl.sh
git commit -m "Release ChiselWare x.y.z Docker environment"
```

The `docker/` directory — including `.devcontainer/` and this document —
is synced to the public DevKit repository automatically when the
infrastructure release is tagged.

---

## Version Retention

Old image versions are retained indefinitely in both registries. Do not
delete old tags without a formal deprecation decision — users may maintain
projects on older versions for years.

**Check available versions:**
```bash
# GHCR
docker buildx imagetools inspect ghcr.io/chiselware/dev-full --raw | grep tag

# ACR
az acr repository show-tags --name chiselwareregistry --repository dev-full --output table
```

**Retire a version after formal deprecation:**
```bash
# GHCR — via GitHub web UI:
# Settings → Packages → dev-full → select version → Delete

# ACR
az acr repository delete --name chiselwareregistry --image dev-full:x.y.z --yes
```

---

## Troubleshooting

**`Bad owner or permissions on /root/.ssh/config`**
```bash
chmod 600 ~/.ssh/config
```

**`no such identity: /root/.ssh/somefile.pem`**
Your `~/.ssh/config` references a key that doesn't exist. Check:
```bash
grep IdentityFile ~/.ssh/config && ls ~/.ssh/
```

**GTKWave or Firefox shows no window**
Run `xhost +local:docker` (Linux) or enable XQuartz network connections
(Mac), then relaunch the container. On Windows 11 WSLg handles this
automatically.

**Mac: container runs slowly**
Expected — Apple Silicon runs x86_64 images via Rosetta 2 emulation.
Performance is adequate for development but slower than native Linux.

**Windows: `docker: command not found` inside WSL2**
Docker Desktop WSL integration is not enabled for your distro. Go to
Docker Desktop → Settings → Resources → WSL Integration and enable it.

**HTML files not visible on host after regression**
Ensure you launched the run script from your project root directory.
Only files written under `/workspace` are accessible on your host.

**Dev Container: "Reopen in Container" not appearing**
Install the Dev Containers extension
(`ms-vscode-remote.remote-containers`) and ensure Docker is running.

**`sby: command not found`**
sby is installed from source to `/usr/local/bin`. Verify it is on PATH:
```bash
which sby && sby --version
```
If missing, the sby source build layer may have failed silently — rebuild
with `--no-cache` and check the Layer 5 build output.

**`z3: command not found`**
Z3 is installed via apt in Layer 1. If missing, apt may have failed:
```bash
apt-get install -y z3
```

**Formal tests not running**
Verify Z3 is on PATH — it is the default solver for `chiseltest.formal`:
```bash
which z3 && z3 --version
```
To run only formal tests:
```bash
sbt "testOnly * -- -n FormalTest"
```
To exclude formal tests from a full regression:
```bash
sbt "testOnly * -- -l FormalTest"
```
