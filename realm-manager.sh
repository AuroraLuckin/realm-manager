#!/bin/bash

# Configuration directory where we'll store all our endpoint configurations
REALM_CONFIG_DIR="/etc/realm/endpoints"
REALM_BASE_CONFIG="/etc/realm/config.toml"
REALM_SERVICE_FILE="/etc/systemd/system/realm.service"
REALM_BINARY="/usr/local/bin/realm"

# Function to set up the initial directory structure and base configuration
setup_realm_environment() {
    echo "Setting up Realm environment..."
    
    # Create necessary directories
    sudo mkdir -p "$REALM_CONFIG_DIR"
    
    # Download and install Realm binary if it doesn't exist
    if [ ! -f "$REALM_BINARY" ]; then
        wget -O realm.tar.gz https://github.com/zhboner/realm/releases/download/v2.4.5/realm-x86_64-unknown-linux-gnu.tar.gz
        tar -xvf realm.tar.gz
        sudo mv realm "$REALM_BINARY"
        sudo chmod +x "$REALM_BINARY"
        rm realm.tar.gz
    fi
    
    # Create base config if it doesn't exist
    if [ ! -f "$REALM_BASE_CONFIG" ]; then
        cat > "$REALM_BASE_CONFIG" << EOL
[network]
no_tcp = false
use_udp = true

# Endpoint configurations will be included from the endpoints directory
EOL
    fi
    
    # Create service file
    cat > "$REALM_SERVICE_FILE" << EOL
[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
ExecStart=$REALM_BINARY -c $REALM_BASE_CONFIG

[Install]
WantedBy=multi-user.target
EOL

    # Set proper permissions
    sudo chmod 644 "$REALM_SERVICE_FILE"
    
    # Reload systemd
    sudo systemctl daemon-reload
}

# Function to add a new endpoint configuration
add_endpoint() {
    local listen_port="$1"
    local remote_host="$2"
    local remote_port="$3"
    local transport="${4:-tcp}"  # Default to TCP if not specified
    
    # Create config file name based on ports
    local config_file="$REALM_CONFIG_DIR/${listen_port}_to_${remote_port}.toml"
    
    # Create endpoint configuration
    cat > "$config_file" << EOL
[[endpoints]]
listen = "[::]:${listen_port}"
remote = "${remote_host}:${remote_port}"
transport = "${transport}"
EOL

    echo "Added new endpoint configuration: $config_file"
}

# Function to remove an endpoint configuration
remove_endpoint() {
    local config_file="$1"
    if [ -f "$REALM_CONFIG_DIR/$config_file" ]; then
        rm "$REALM_CONFIG_DIR/$config_file"
        echo "Removed endpoint configuration: $config_file"
    else
        echo "Configuration file not found: $config_file"
    fi
}

# Function to list all endpoint configurations
list_endpoints() {
    echo "Current endpoint configurations:"
    for config in "$REALM_CONFIG_DIR"/*.toml; do
        if [ -f "$config" ]; then
            echo "---"
            echo "Configuration file: $(basename "$config")"
            cat "$config"
        fi
    done
}

# Function to reload Realm service
reload_realm() {
    echo "Reloading Realm service..."
    sudo systemctl restart realm
    sudo systemctl status realm
}

# Main menu function
show_menu() {
    while true; do
        echo ""
        echo "Realm Configuration Manager"
        echo "1. Setup Realm environment"
        echo "2. Add new endpoint"
        echo "3. Remove endpoint"
        echo "4. List endpoints"
        echo "5. Reload Realm service"
        echo "6. Exit"
        read -p "Select an option: " choice
        
        case $choice in
            1) setup_realm_environment ;;
            2)
                read -p "Enter listen port: " listen_port
                read -p "Enter remote host: " remote_host
                read -p "Enter remote port: " remote_port
                read -p "Enter transport type (tcp/udp/ws) [tcp]: " transport
                transport=${transport:-tcp}
                add_endpoint "$listen_port" "$remote_host" "$remote_port" "$transport"
                ;;
            3)
                read -p "Enter configuration file to remove: " config_file
                remove_endpoint "$config_file"
                ;;
            4) list_endpoints ;;
            5) reload_realm ;;
            6) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Start the script
show_menu
