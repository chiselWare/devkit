<a href="https://chiselware.org">
  <img src="./images/chiselWare_Logo_RGB_300.png" width="300" alt="chiselWare logo">
</a>

# chiselWare Developers Kit

Welcome to the **chiselWare Developers Kit** (DevKit). This repository is a sitemap of the resources available to help new and experienced Chisel developers build chiselWare-compliant semiconductor IP cores.

Everything here is reference material and tooling. Start with the two documents below, then set up your environment and request a core project.

---

## Documents

- **[chiselWare Developers Guide](./chiselWareDevGuide.pdf)** (CWDG) — the practical, tutorial-style guide to building a chiselWare core from first clone through certification. **Start here.** It walks you through setting up your environment, customizing the template, verifying, documenting, and getting certified.

- **[chiselWare Standard](./chiselWareStandard.pdf)** (CWS) — the normative specification. Only cores that conform to this standard can be certified and listed in the IP Factory. The CWDG explains how to meet its requirements; the CWS defines what those requirements are.
---

## Development Environment

The `docker/` directory contains everything needed to run the chiselWare Standard Software Environment (SSE) — the pinned toolchain that all cores are developed and certified against.

| File                      | Purpose                                                                                                                                                                                                  |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DOCKER.md`               | **Full documentation** for the containerized environment — setup on Linux, macOS, and Windows; VS Code Dev Containers; `code` tunnels; troubleshooting. **Read this to get started with the container.** |
| `Dockerfile`              | The container definition, if you wish to build the image locally rather than pulling the pre-built one.                                                                                                  |
| `.devcontainer/`          | VS Code Dev Container definition. Copy this into a folder to open the SSE directly in VS Code. See `DOCKER.md`.                                                                                          |
| `run-chiselware-linux.sh` | Launch script for Linux.                                                                                                                                                                                 |
| `run-chiselware-mac.sh`   | Launch script for macOS (Apple Silicon).                                                                                                                                                                 |
| `run-chiselware-wsl.sh`   | Launch script for Windows (WSL2).                                                                                                                                                                        |

The container is published publicly to the GitHub Container Registry at `ghcr.io/chiselware/dev-full`. See `DOCKER.md` for pull and launch instructions.

### Installed Toolchain

| Tool           | Description            | Version             |
| -------------- | ---------------------- | ------------------- |
| Ubuntu         | Linux server           | 24.04 LTS Server    |
| OpenJDK        | Java platform          | 21.x                |
| sbt            | Scala build tool       | 1.11                |
| Scala CLI      | Command line tool      | 1.10.1              |
| firtool        | Verilog generator      | 1.47                |
| Verilator      | Compiled simulator     | 5.020-1             |
| Icarus Verilog | Interpreted simulator  | 12.0-2build2        |
| GTKWave        | Waveform viewer        | 3.3.116-1build2     |
| Yosys          | Synthesis tool         | 0.33-5build2        |
| CUDD           | BDD pkg used by Yosys  | 3.0.0               |
| OpenSTA        | Static timing tool     | 2.7.0               |
| sby            | Yosys formal front-end | v0.65 / v0.66       |
| Yices2         | SMT solver             | 2.6.4               |
| Z3             | SMT solver             | Uses Ubuntu version |
| TeXLive        | LaTeX tools            | Uses Ubuntu version |
| Firefox        | Web browser            | latest stable       |
| VS Code CLI    | IDE                    | latest stable       |

The Azure Marketplace also offers a native (non-Docker) VM image with the
same pinned toolchain, for developers who prefer their own cloud VM:
[chiselWare on the Azure Marketplace](https://marketplace.microsoft.com/en-us/product/rocksavagetechnologyinc1713893864282.chiselware-ubuntu_24_04?tab=Overview).

---

## Starting a Core

The starting point for every new chiselWare core is the template repository:

- **[00-000-dff](https://github.com/chiselWare/00-000-dff)** — a complete, fully compliant chiselWare core implementing a D flip-flop, the simplest possible design. This is the **required starting point** for all new cores, not merely an example. When the IP Factory provisions your core repository it is pre-populated from this template.

> **WARNING:** Building your core without starting from this template will almost certainly result in your core failing automated regressions.

The CWDG walks through customizing the template for your own design in detail.

---

## Citing chiselWare

If you use chiselWare in academic work, please cite it. See [CITATION.md](CITATION.md) for BibTeX, IEEE, ACM, and plain-text formats.

---

## Learn More

- Website and Core Registry: [chiselware.org](https://chiselware.org)
- GitHub organization: [github.com/chiselware](https://github.com/chiselWare)
