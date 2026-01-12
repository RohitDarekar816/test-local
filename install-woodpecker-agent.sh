#!/bin/bash

# Woodpecker Agent Installation Script
# Installs Woodpecker agent with local backend for host machine execution

set -e

# Configuration variables
WOODPECKER_SERVER="${WOODPECKER_SERVER:-woodpecker.hivefinty.com:9000}"
WOODPECKER_TOKEN="${WOODPECKER_TOKEN:-}"
WOODPECKER_HOSTNAME="${WOODPECKER_HOSTNAME:-$(hostname)}"
WOODPECKER_USER="${WOODPECKER_USER:-$(whoami)}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/woodpecker}"
LOG_FILE="${LOG_FILE:-$HOME/woodpecker-agent.log}"
PID_FILE="${PID_FILE:-$HOME/woodpecker-agent.pid}"
PLUGINS_DIR="${PLUGINS_DIR:-$HOME/.woodpecker-plugins}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Helper function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check requirements
check_requirements() {
    print_info "Checking system requirements..."
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_success "Linux detected"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_success "macOS detected"
    else
        print_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        AGENT_ARCH="amd64"
        print_success "x86_64 architecture detected"
    elif [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
        AGENT_ARCH="arm64"
        print_success "ARM64 architecture detected"
    else
        print_error "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("curl" "tar" "git")
    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            print_success "$cmd is installed"
        else
            print_error "$cmd is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check for Docker (optional)
    if command_exists "docker"; then
        DOCKER_AVAILABLE=true
        print_success "Docker is available"
    else
        DOCKER_AVAILABLE=false
        print_warning "Docker is not installed (optional for local backend)"
    fi
}

# Get user input for configuration
get_config() {
    echo ""
    print_info "=== Woodpecker Agent Configuration ==="
    echo ""
    
    # Server URL
    read -p "Enter Woodpecker server URL [$WOODPECKER_SERVER]: " input_server
    if [[ -n "$input_server" ]]; then
        WOODPECKER_SERVER="$input_server"
    fi
    
    # Agent Token
    read -p "Enter Woodpecker agent token: " input_token
    if [[ -n "$input_token" ]]; then
        WOODPECKER_TOKEN="$input_token"
    else
        print_error "Agent token is required!"
        exit 1
    fi
    
    # Hostname
    read -p "Enter agent hostname [$WOODPECKER_HOSTNAME]: " input_hostname
    if [[ -n "$input_hostname" ]]; then
        WOODPECKER_HOSTNAME="$input_hostname"
    fi
    
    # Install directory
    read -p "Enter installation directory [$INSTALL_DIR]: " input_install_dir
    if [[ -n "$input_install_dir" ]]; then
        INSTALL_DIR="$input_install_dir"
    fi
    
    # Backend choice
    echo ""
    print_info "Choose backend:"
    echo "1) local  (run commands directly on host machine)"
    echo "2) docker  (run commands in Docker containers)"
    read -p "Choose backend [1]: " backend_choice
    
    case "$backend_choice" in
        2|docker)
            BACKEND="docker"
            ;;
        *)
            BACKEND="local"
            ;;
    esac
    
    echo ""
    print_info "Configuration Summary:"
    echo "  Server: $WOODPECKER_SERVER"
    echo "  Hostname: $WOODPECKER_HOSTNAME"
    echo "  Backend: $BACKEND"
    echo "  Install Dir: $INSTALL_DIR"
    echo "  Config Dir: $CONFIG_DIR"
    echo ""
}

# Download Woodpecker agent
download_agent() {
    print_info "Downloading Woodpecker agent..."
    
    # Use latest version (you can change this to specific version)
    VERSION="latest"
    
    # Determine download URL
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        DOWNLOAD_URL="https://github.com/woodpecker-ci/woodpecker/releases/download/${VERSION}/woodpecker-agent-linux-${AGENT_ARCH}.tar.gz"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        DOWNLOAD_URL="https://github.com/woodpecker-ci/woodpecker/releases/download/${VERSION}/woodpecker-agent-darwin-${AGENT_ARCH}.tar.gz"
    fi
    
    print_info "Downloading from: $DOWNLOAD_URL"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download agent
    if curl -L -o woodpecker-agent.tar.gz "$DOWNLOAD_URL"; then
        print_success "Download completed"
    else
        print_error "Failed to download Woodpecker agent"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Extract
    print_info "Extracting agent..."
    tar -xzf woodpecker-agent.tar.gz
    
    # Make executable
    chmod +x woodpecker-agent
    
    # Move to install directory
    mkdir -p "$INSTALL_DIR"
    mv woodpecker-agent "$INSTALL_DIR/"
    
    # Clean up
    cd /
    rm -rf "$TEMP_DIR"
    
    print_success "Agent installed to $INSTALL_DIR/woodpecker-agent"
}

# Install git plugin
install_plugin() {
    print_info "Installing git plugin..."
    
    mkdir -p "$PLUGINS_DIR"
    
    # Extract plugin from Docker image
    if command_exists "docker"; then
        print_info "Extracting git plugin from Docker image..."
        if docker run --rm -v "$PLUGINS_DIR":/plugins woodpeckerci/plugin-git:2.7.0 sh -c "cp /bin/woodpecker-plugin-git /plugins/ 2>/dev/null || cp /bin/plugin-git /plugins/ 2>/dev/null"; then
            chmod +x "$PLUGINS_DIR/plugin-git"
            print_success "Git plugin installed to $PLUGINS_DIR/"
        else
            print_warning "Failed to extract git plugin automatically"
        fi
    else
        print_warning "Docker not available, skipping git plugin installation"
    fi
}

# Create configuration
create_config() {
    print_info "Creating configuration..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Create agent runner script
    cat > "$INSTALL_DIR/woodpecker-agent-runner" << 'EOF'
#!/bin/bash

# Woodpecker Agent Runner Script
# Runs Woodpecker agent with local backend

AGENT_BIN="$INSTALL_DIR/woodpecker-agent"
CONFIG_FILE="$CONFIG_DIR/agent.conf"
LOG_FILE="$LOG_FILE"
PID_FILE="$PID_FILE"
PLUGINS_DIR="$PLUGINS_DIR"

# Server configuration
SERVER="$WOODPECKER_SERVER"
TOKEN="$WOODPECKER_TOKEN"
HOSTNAME="$WOODPECKER_HOSTNAME"
BACKEND="$BACKEND"

# Function to test connectivity
test_connectivity() {
    echo "Testing connectivity to Woodpecker server..."
    # Extract IP from server if hostname provided
    if [[ "$SERVER" == *":"* ]]; then
        SERVER_HOST=$(echo "$SERVER" | cut -d: -f1)
        SERVER_PORT=$(echo "$SERVER" | cut -d: -f2)
    else
        SERVER_HOST="$SERVER"
        SERVER_PORT="9000"
    fi
    
    if command_exists nc; then
        if nc -z -w5 "$SERVER_HOST" "$SERVER_PORT" 2>/dev/null; then
            echo "✓ Server is reachable on port $SERVER_PORT"
            return 0
        else
            echo "✗ Server is not reachable on port $SERVER_PORT"
            return 1
        fi
    else
        echo "⚠ Cannot test connectivity (nc command not available)"
        return 0
    fi
}

# Function to start agent
start_agent() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Woodpecker agent is already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi

    # Test connectivity first
    if ! test_connectivity; then
        echo "Error: Cannot connect to Woodpecker server. Please check your network."
        return 1
    fi

    echo "Starting Woodpecker agent in background with $BACKEND backend..."
    echo "Server: $SERVER"
    echo "Hostname: $HOSTNAME"
    echo "Backend: $BACKEND"

    # Set plugin path environment variable
    export WOODPECKER_PLUGIN_PATH="$PLUGINS_DIR"

    # Start agent
    nohup "$AGENT_BIN" \
        --server "$SERVER" \
        --grpc-token "$TOKEN" \
        --backend-engine "$BACKEND" \
        --hostname "$HOSTNAME" \
        --max-workflows 1 \
        --agent-config "$CONFIG_FILE" \
        --healthcheck \
        --healthcheck-addr ":3001" \
        --log-level info \
        --keepalive-time 30s \
        --keepalive-timeout 10s \
        --connect-retry-count 10 \
        --connect-retry-delay 5s \
        > "$LOG_FILE" 2>&1 &
    
    local PID=$!
    echo $PID > "$PID_FILE"
    
    # Wait a moment and check if agent started successfully
    sleep 3
    if kill -0 "$PID" 2>/dev/null; then
        echo "✓ Woodpecker agent started successfully (PID: $PID)"
        echo "Logs: $LOG_FILE"
        echo "Health check: http://localhost:3001/healthz"
    else
        echo "✗ Woodpecker agent failed to start. Check logs: $LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Function to stop agent
stop_agent() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "Stopping Woodpecker agent (PID: $PID)..."
            kill -TERM "$PID"
            
            # Wait for graceful shutdown
            local count=0
            while kill -0 "$PID" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$PID" 2>/dev/null; then
                echo "Force killing agent..."
                kill -KILL "$PID"
            fi
            
            rm -f "$PID_FILE"
            echo "✓ Woodpecker agent stopped"
        else
            echo "Woodpecker agent is not running"
            rm -f "$PID_FILE"
        fi
    else
        echo "PID file not found. Agent may not be running."
    fi
}

# Function to check status
status_agent() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local PID=$(cat "$PID_FILE")
        echo "✓ Woodpecker agent is running (PID: $PID)"
        
        # Check if health endpoint is accessible
        if command_exists curl; then
            if curl -s http://localhost:3001/healthz >/dev/null 2>&1; then
                echo "✓ Health check: OK"
            else
                echo "⚠ Health check: Not accessible"
            fi
        fi
        return 0
    else
        echo "✗ Woodpecker agent is not running"
        return 1
    fi
}

# Function to show logs
logs_agent() {
    if [ -f "$LOG_FILE" ]; then
        echo "Following logs from: $LOG_FILE"
        tail -f "$LOG_FILE"
    else
        echo "Log file not found: $LOG_FILE"
    fi
}

# Function to restart agent
restart_agent() {
    echo "Restarting Woodpecker agent..."
    stop_agent
    sleep 2
    start_agent
}

# Main script logic
case "$1" in
    start)
        start_agent
        ;;
    stop)
        stop_agent
        ;;
    restart)
        restart_agent
        ;;
    status)
        status_agent
        ;;
    logs)
        logs_agent
        ;;
    diagnose)
        echo "=== Woodpecker Agent Diagnosis ==="
        echo ""
        status_agent
        echo ""
        if command_exists curl; then
            echo "3. Server connectivity:"
            test_connectivity
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|diagnose}"
        echo ""
        echo "Commands:"
        echo "  start    - Start Woodpecker agent in background"
        echo "  stop     - Stop running Woodpecker agent"
        echo "  restart  - Restart Woodpecker agent"
        echo "  status   - Check if agent is running and healthy"
        echo "  logs     - Follow agent logs in real-time"
        echo "  diagnose - Run diagnostic check"
        exit 1
        ;;
esac
EOF

    # Make runner script executable
    chmod +x "$INSTALL_DIR/woodpecker-agent-runner"
    
    # Create symlink for easy access
    if [[ -d "$HOME/bin" ]]; then
        ln -sf "$INSTALL_DIR/woodpecker-agent-runner" "$HOME/bin/wp"
    fi
    
    print_success "Agent runner script created"
}

# Update PATH in shell
update_path() {
    print_info "Updating PATH..."
    
    # Add to .bashrc if not already present
    if ! grep -q "$INSTALL_DIR" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Woodpecker agent path" >> "$HOME/.bashrc"
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
        print_success "Added $INSTALL_DIR to PATH in .bashrc"
    fi
    
    # Export to current session
    export PATH="$INSTALL_DIR:$PATH"
}

# Create systemd service (optional)
create_service() {
    if command_exists "systemctl"; then
        read -p "Create systemd service for auto-start on boot? [y/N]: " create_service
        if [[ "$create_service" =~ ^[Yy]$ ]]; then
            print_info "Creating systemd service..."
            
            sudo tee /etc/systemd/system/woodpecker-agent.service > /dev/null << EOF
[Unit]
Description=Woodpecker Agent
After=network.target

[Service]
Type=simple
User=$WOODPECKER_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/woodpecker-agent-runner start
ExecStop=$INSTALL_DIR/woodpecker-agent-runner stop
ExecReload=$INSTALL_DIR/woodpecker-agent-runner restart
Restart=always
RestartSec=10
Environment=PATH=$INSTALL_DIR:/usr/local/bin:/usr/bin:/bin
Environment=WOODPECKER_SERVER=$WOODPECKER_SERVER
Environment=WOODPECKER_TOKEN=$WOODPECKER_TOKEN
Environment=WOODPECKER_HOSTNAME=$WOODPECKER_HOSTNAME
Environment=BACKEND=$BACKEND

[Install]
WantedBy=multi-user.target
EOF
            
            sudo systemctl daemon-reload
            sudo systemctl enable woodpecker-agent.service
            print_success "Systemd service created and enabled"
        fi
    fi
}

# Print final instructions
print_instructions() {
    echo ""
    print_success "=== Installation Complete! ==="
    echo ""
    echo "To use Woodpecker agent:"
    echo ""
    echo "1. Start agent:"
    echo "   $INSTALL_DIR/woodpecker-agent-runner start"
    echo "   or"
    echo "   wp start"
    echo ""
    echo "2. Check status:"
    echo "   wp status"
    echo ""
    echo "3. View logs:"
    echo "   wp logs"
    echo ""
    echo "4. Stop agent:"
    echo "   wp stop"
    echo ""
    echo "5. Restart agent:"
    echo "   wp restart"
    echo ""
    echo "Configuration file: $CONFIG_DIR/agent.conf"
    echo "Log file: $LOG_FILE"
    echo ""
    
    if [[ "$BACKEND" == "local" ]]; then
        print_info "Local backend will run commands directly on the host machine."
        print_warning "Only use this for trusted repositories!"
    fi
    
    print_info "Don't forget to source ~/.bashrc or restart your shell to update PATH."
}

# Main installation flow
main() {
    echo ""
    echo "==============================================="
    echo "    Woodpecker Agent Installer"
    echo "==============================================="
    echo ""
    
    check_requirements
    get_config
    download_agent
    install_plugin
    create_config
    update_path
    create_service
    print_instructions
}

# Run main function
main "$@"