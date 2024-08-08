#!/bin/bash

server_user = "pzuser"
server_folder = "pzserver"
pz_config_url = ""

JAVA_URL="https://corretto.aws/downloads/latest/amazon-corretto-22-x64-linux-jdk.tar.gz"
RCON_URL="https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz"

# Function to install a package if not already installed
install_package() {
    local pkg=$1
    if ! command -v $pkg &>/dev/null; then
        echo "$pkg is not installed. Installing $pkg..."
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y $pkg
        elif command -v yum &> /dev/null; then
            yum install -y $pkg
        else
            echo "Neither apt-get nor yum found. Please install $pkg manually."
            exit 1
        fi
    else
        echo "$pkg is already installed."
    fi
}

# Function to install Java if not already installed
check_and_install_java() {
    local DOWNLOAD_DIR="/opt/java"

    if command -v java &>/dev/null; then
        echo "Java is already installed."
        java -version
    else
        echo "Installing Java..."
        mkdir -p "$DOWNLOAD_DIR"
        wget -O "$DOWNLOAD_DIR/java.tar.gz" "$JAVA_URL"
        tar -xzvf "$DOWNLOAD_DIR/java.tar.gz" -C "$DOWNLOAD_DIR"
        
        # Assuming the extracted directory name starts with "amazon-corretto-22"
        JAVA_DIR=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type d -name "amazon-corretto-22*")
        if [ -d "$JAVA_DIR" ]; then
            update-alternatives --install /usr/bin/java java "$JAVA_DIR/bin/java" 1
            update-alternatives --install /usr/bin/javac javac "$JAVA_DIR/bin/javac" 1
            update-alternatives --set java "$JAVA_DIR/bin/java"
            update-alternatives --set javac "$JAVA_DIR/bin/javac"
            echo "Java installed successfully."
        else
            echo "Java installation failed: extracted directory not found."
            exit 1
        fi

        # Clean up
        rm -rf "$DOWNLOAD_DIR/java.tar.gz"
    fi
}

# Function to install RCON if not already installed
check_and_install_rcon() {
    if ! command -v rcon &>/dev/null; then
        echo "Installing rcon..."
        wget -O "$DOWNLOAD_DIR/rcon.tar.gz" "$RCON_URL"
        tar -xzvf "$DOWNLOAD_DIR/rcon.tar.gz" -C "$DOWNLOAD_DIR"
        mv "$DOWNLOAD_DIR/rcon-0.10.3-amd64_linux/rcon" /usr/local/bin/rcon
        chmod +x /usr/local/bin/rcon
        rm -rf "$DOWNLOAD_DIR/rcon.tar.gz" "$DOWNLOAD_DIR/rcon-0.10.3-amd64_linux"
    else
        echo "rcon is already installed."
    fi
}

# Install packages
install_package firewalld
install_package steamcmd
check_and_install_java
check_and_install_rcon

# Create user '$server_user' if it does not exist
if ! id -u $server_user >/dev/null 2>&1; then
    useradd -m $server_user
    echo "$server_user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$server_user
    usermod -aG wheel $server_user
fi

# Create server folder
sudo mkdir /opt/$server_folder
sudo chown $server_user:$server_user /opt/$server_folder

# Login as server user
sudo -u $server_user -i

# Download configuration file
curl $pz_config_url -o $HOME/$server_user/update_zomboid.txt

# Install Project Zomboid Server
export PATH=$PATH:/usr/games
steamcmd +runscript $HOME/update_zomboid.txt

# Firewall configuration
firewall-cmd --zone=public --add-port=16261/udp --permanent
firewall-cmd --zone=public --add-port=16262/udp --permanent
firewall-cmd --reload