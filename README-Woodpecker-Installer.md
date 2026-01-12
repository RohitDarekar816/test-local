# Woodpecker Agent Installation Script

This script automatically installs and configures Woodpecker agent with local backend for running commands on the host machine.

## Quick Start

1. Download the script:
```bash
curl -O https://your-server.com/install-woodpecker-agent.sh
chmod +x install-woodpecker-agent.sh
```

2. Run the installer:
```bash
./install-woodpecker-agent.sh
```

## Features

- **Automatic Detection**: Detects OS (Linux/macOS) and architecture (x86_64/ARM64)
- **Interactive Setup**: Prompts for configuration (server URL, token, hostname, backend)
- **Local Backend**: Runs commands directly on host machine (your use case)
- **Git Plugin**: Installs git plugin automatically if Docker is available
- **Service Creation**: Optional systemd service for auto-start on boot
- **Management Scripts**: Creates `wp` command for easy agent management
- **Connectivity Testing**: Tests server connection before starting agent

## Configuration Options

- **Server URL**: Woodpecker server address (e.g., woodpecker.hivefinty.com:9000)
- **Agent Token**: Authentication token for the agent
- **Hostname**: Unique identifier for the agent
- **Backend**: `local` (host machine) or `docker` (containers)
- **Install Directory**: Where to install the agent binary

## Usage

After installation, you can manage the agent with:

```bash
# Start agent
wp start

# Check status  
wp status

# View logs
wp logs

# Stop agent
wp stop

# Restart agent
wp restart

# Run diagnostics
wp diagnose
```

## What Gets Installed

1. **Woodpecker Agent**: Latest binary for your OS/arch
2. **Git Plugin**: Pre-installed for faster pipeline execution
3. **Runner Script**: `woodpecker-agent-runner` with all configuration
4. **Management Command**: `wp` symlink for easy access
5. **Systemd Service** (optional): Auto-start on boot

## Pipeline Configuration for Local Backend

Your `.woodpecker.yml` should look like this:

```yaml
when:
  - event: push
    branch: master

skip_clone: true  # Skip automatic git clone for local backend

steps:
  - name: host-commands
    image: sh  # Use shell for local execution
    commands:
      - pwd
      - ls -la
      - echo "Running on host machine!"
```

## Security Note

Local backend runs commands directly on the host machine. Only use this for:
- Trusted repositories
- Private setups
- Controlled environments

Never use local backend for public CI/CD where anyone can submit code!