<a href="https://chiselware.org">
  <img src="./images/chiselWare_Logo_RGB_300.png" width="300" alt="chiselWare logo">
</a>

# chiselWare Developers Kit

Welcome to the `chiselWare Developers Kit`. This will help new and experienced Chisel developers come up to speed on what is involved in developing a chiselWare-compliant semiconductor IP core.  

Included in this repository are a number of useful things:

- `chiselWare Standard` (under development) provides the specification for a chiselWare core. Only cores compliant to this standard will be considered certified and eligible for placement in the IP Factory storefront.
- `chiselWare Developers Guide` is a companion to the chiselWare Standard and contains information about the reasons behind the methodology and hints and advice that are useful for developers. (Note: This currently includes the beginnings of the chiselWare standard)
- `Containerized chiselWare Design Environment` is the complete environment for developing a chiselWare core that includes the pinned version of all required tools. Included in the container are the following tools:

    | Tool           | Description           | Version             |
    | -------------- | --------------------- | ------------------- |
    | Ubuntu         | Linux server          | 24.04 LTS Server    |
    | OpenJDL        | Java platform         | 21.x                |
    | sbt            | Scala build tool      | 1.11                |
    | Scala CLI      | Command line tool     | 1.10.1              |
    | firtool        | Verilog generator     | 1.47                |
    | Verilator      | Compiled simulator    | 5.020-1             |
    | Icarus Verilog | Interpreted simulator | 12.0-2build2        |
    | GTKWave        | Waveform viewer       | 3.3.116-1build2     |
    | Yosys          | Synthesis tool        | 0.33-5build2        |
    | CUDD           | BDD pkg used by Yosys | 3.0.0               |
    | OpenSTA        | Static timing tool    | 2.7.0               |
    | TeXLive        | LateX tools           | Uses Ubuntu version |
    | Firefox        | Web browser           | latest stable       |
    | VS Code CLI    | IDE                   | latest stable       |

  Also included in the docker directory is the `DockerFile` if you wish to build you own local container as well as three scripts that can be used for setting up your environment.
  ```bash
  run-chiselware-linux.sh # For Linux environments
  run-chiselware-mac.sh   # For MacOS
  run-chiselware-wsl.sh   # For Window PC with wsl
  ```

Not included here are several other important resources for the chiselWare developer:
  - The [Microsoft Azure Marketplace](https://marketplace.microsoft.com/en-us/product/rocksavagetechnologyinc1713893864282.chiselware-ubuntu_24_04?tab=Overview) contains a VM image that contains all the pinned versions of the required tools (native, not Docker) for developers that would like to have their own VM of any size to develop the code on.

  - An [example repository of a complete chiselWare-compliant core](https://github.com/chiselWare/00-000-dff) using a D-flip-flop as the most simplest example possible. This template should be the starting point for all new designs. See the README.md in that core for instructions on how to customize this repo for your own core. 

  <mark> **WARNING:** Failure to build your repo with this template will almost certainly result in your core failing automated regressions. </mark> 

  # Using the Docker Container

  The easiest way to use the chiselWare environment is pull the pre-built container from the `GitHub Container Registry`. This is highly recommended over building your own container with the provided `Dockerfile` to insure that your development is compatible with the officially supported chiselWare versions. 

| Registry                  | URL                                 | Audience           | Auth required |
| ------------------------- | ----------------------------------- | ------------------ | ------------- |
| GitHub Container Registry | `ghcr.io/chiselware/dev-full:0.7.1` | All users (public) | None          |


## Running on Linux

```bash
# Pull the desired version 
docker pull ghcr.io/chiselware/dev-full:X.Y.Z

# Copy the run script into a executable path or add this location to your path
chmod +x run-chiselware-linux.sh

# Daily use — run from your project directory
cd ~/my-chisel-project
./run-chiselware-linux.sh
```

## Running on macOS (Apple Silicon — M1/M2/M3)

```bash
# Install Docker Desktop from https://www.docker.com/products/docker-desktop/
# Choose the Apple Silicon version

# Pull the desired version 
docker pull --platform linux/amd64 ghcr.io/chiselware/dev-full:X.Y.Z

# Copy the run script into a executable path or add this location to your path
chmod +x run-chiselware-mac.sh

# Daily use
cd ~/my-chisel-project
./run-chiselware-mac.sh
```

**X forwarding on Mac (GTKWave, Firefox):**
Install XQuartz from https://www.xquartz.org, log out and back in, then
enable "Allow connections from network clients" in XQuartz Preferences →
Security. X forwarding activates automatically on next container launch.

## Running on Windows (WSL2)

Requirements:
- Windows 11 or Windows 10 (build 19041+)
- WSL2 with Ubuntu (22.04 or 24.04 recommended)
- Docker Desktop with WSL2 backend enabled:
  Settings → General → Use the WSL 2 based engine
- Docker Desktop WSL integration enabled for your distro:
  Settings → Resources → WSL Integration → enable your distro

```bash
# Pull the desired version  (from within the WSL window)
docker pull ghcr.io/chiselware/dev-full:X.Y.Z

# Copy the run script into a executable path or add this location to your path
chmod +x run-chiselware-wsl.sh

# Daily use — run from your project directory inside WSL2
cd ~/my-chisel-project
./run-chiselware-wsl.sh
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
./run-chiselware-<platform>.sh
```

Files written outside `/workspace` are lost when the container exits.
Always launch the script from your project root so all generated files
are accessible on your host after the container exits.

---

## Running VS Code with the container 

There are two main ways to use VS Code with the container:
- From a browser
- From the desktop App
   
### VS Code through a browser 

This opens VS Code from within a browser window.

```bash
./run-chiselware-<platform>.sh
# Inside the container:
code tunnel
```
Follow the GitHub auth prompt, provide a name for tunnel (default is container name) and then use the provided link to bring up a VS Code in a browser window.

## Local VS Code through code tunnel

This allows VS Code to open your repo from the desktop VS Code app.

```bash
./run-chiselware-<platform>.sh
# Inside the container:
code tunnel
```
Follow the GitHub auth prompt, provide a name for tunnel (default is container name) , then open the desktop VS code application.  Within VS Code window, click on the `><` symbol at the bottom left of the screen and select "Connect to tunnel" and select the name of the tunnel.