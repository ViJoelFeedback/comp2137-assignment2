#!/usr/bin/env bash
# COMP2137 – Assignment 2 automation script
# This script configures server1 to the exact required state.
# Idempotent: safe to run repeatedly.

set -e

GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
RED="$(printf '\033[31m')"
BLUE="$(printf '\033[34m')"
RESET="$(printf '\033[0m')"

info(){ echo -e "${BLUE}[INFO]${RESET} $*"; }
ok(){ echo -e "${GREEN}[OK]${RESET} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET} $*"; }
err(){ echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

TARGET_IP="192.168.16.21"
TARGET_CIDR="192.168.16.21/24"
TARGET_GW="192.168.16.2"
HOSTNAME="server1"

USERS=(dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda)
DENNIS_EXTRA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

###############################################################################
# 1) Detect the correct interface for 192.168.16.x network
###############################################################################

info "Detecting target network interface…"

TARGET_IF=$(ip -4 -o addr show | awk '/192\.168\.16\./ {print $2; exit}')

if [ -z "$TARGET_IF" ]; then
    warn "No interface currently has a 192.168.16.x IP. Selecting interface manually."
    TARGET_IF=$(ip link show | awk -F: '/^[0-9]+: e/{print $2; exit}' | tr -d ' ')
fi

ok "Target interface: $TARGET_IF"

###############################################################################
# 2) Configure netplan for static IP
###############################################################################

NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

info "Updating netplan config…"

cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $TARGET_IF:
      dhcp4: no
      addresses: [$TARGET_CIDR]
      routes:
        - to: 0.0.0.0/0
          via: $TARGET_GW
      nameservers:
        addresses: [1.1.1.1,8.8.8.8]
EOF

netplan apply || warn "Netplan apply may require a reboot."

ok "Netplan configured."

###############################################################################
# 3) Fix /etc/hosts entry for server1
###############################################################################

info "Updating /etc/hosts…"

sed -i "/$HOSTNAME/d" /etc/hosts
echo "$TARGET_IP $HOSTNAME" >> /etc/hosts

ok "/etc/hosts updated."

###############################################################################
# 4) Install required packages
###############################################################################

info "Installing apache2 & squid…"

apt update -y
apt install -y apache2 squid

systemctl enable apache2 --now
systemctl enable squid --now

ok "apache2 and squid installed and running."

###############################################################################
# 5) User accounts + SSH keys
###############################################################################

info "Creating users and SSH keys…"

for user in "${USERS[@]}"; do

    if ! id "$user" >/dev/null 2>&1; then
        info "Creating user $user…"
        useradd -m -s /bin/bash "$user"
    else
        ok "$user already exists."
    fi

    HOME_DIR="/home/$user"
    SSH_DIR="$HOME_DIR/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    chown -R "$user:$user" "$SSH_DIR"

    # Generate RSA key pair if missing
    if [ ! -f "$SSH_DIR/id_rsa" ]; then
        sudo -u "$user" ssh-keygen -t rsa -b 3072 -N "" -f "$SSH_DIR/id_rsa" >/dev/null
    fi

    # Generate ED25519 key pair if missing
    if [ ! -f "$SSH_DIR/id_ed25519" ]; then
        sudo -u "$user" ssh-keygen -t ed25519 -N "" -f "$SSH_DIR/id_ed25519" >/dev/null
    fi

    # Ensure both public keys are in authorized_keys
    for pubkey in "$SSH_DIR/id_rsa.pub" "$SSH_DIR/id_ed25519.pub"; do
        if ! grep -qF "$(cat "$pubkey")" "$AUTH_KEYS"; then
            cat "$pubkey" >> "$AUTH_KEYS"
        fi
    done

done

ok "All users created and SSH keys installed."

###############################################################################
# 6) Dennis: add sudo + extra provided SSH key
###############################################################################

info "Applying special rules for dennis…"

usermod -aG sudo dennis

DENNIS_AUTH="/home/dennis/.ssh/authorized_keys"
if ! grep -qF "$DENNIS_EXTRA_KEY" "$DENNIS_AUTH"; then
    echo "$DENNIS_EXTRA_KEY" >> "$DENNIS_AUTH"
fi

ok "Dennis configured."

###############################################################################
# FINAL SUMMARY
###############################################################################

echo
echo "==========================================="
echo " Assignment 2 configuration complete"
echo " Static IP: $TARGET_CIDR"
echo " Gateway:   $TARGET_GW"
echo " Services: apache2, squid"
echo " Users: ${USERS[*]}"
echo "==========================================="
echo

exit 0
