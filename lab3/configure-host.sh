#!/bin/bash

# Ignore termination signals
trap "" TERM HUP INT

VERBOSE=false
HOSTNAME_CHANGE=""
IP_CHANGE=""
HOSTENTRY_NAME=""
HOSTENTRY_IP=""

# --- Function to print verbose ---
vprint() {
    if $VERBOSE; then
        echo "$1"
    fi
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -verbose)
            VERBOSE=true
            ;;
        -name)
            HOSTNAME_CHANGE="$2"
            shift
            ;;
        -ip)
            IP_CHANGE="$2"
            shift
            ;;
        -hostentry)
            HOSTENTRY_NAME="$2"
            HOSTENTRY_IP="$3"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# --- Apply hostname change ---
if [[ -n "$HOSTNAME_CHANGE" ]]; then
    CURRENT_HOSTNAME=$(hostname)

    if [[ "$CURRENT_HOSTNAME" != "$HOSTNAME_CHANGE" ]]; then
        echo "$HOSTNAME_CHANGE" > /etc/hostname
        hostnamectl set-hostname "$HOSTNAME_CHANGE"
        vprint "Hostname updated to $HOSTNAME_CHANGE"
        logger "configure-host.sh: hostname changed from $CURRENT_HOSTNAME to $HOSTNAME_CHANGE"

        # Update /etc/hosts entry for hostname
        sed -i "/127.0.1.1/d" /etc/hosts
        echo "127.0.1.1   $HOSTNAME_CHANGE" >> /etc/hosts
    else
        vprint "Hostname already set to $HOSTNAME_CHANGE"
    fi
fi

# --- Apply IP change ---
if [[ -n "$IP_CHANGE" ]]; then
    NETPLAN_FILE=$(ls /etc/netplan/*.yaml | head -n 1)

    CURRENT_IP=$(grep -oP '(?<=addresses:\s*\[)[0-9\.]+' "$NETPLAN_FILE")

    if [[ "$CURRENT_IP" != "$IP_CHANGE" ]]; then
        # Update netplan file
        sed -i "s/$CURRENT_IP/$IP_CHANGE/" "$NETPLAN_FILE"
        vprint "Netplan updated with IP $IP_CHANGE"
        logger "configure-host.sh: IP changed from $CURRENT_IP to $IP_CHANGE"

        netplan apply
    else
        vprint "IP already set to $IP_CHANGE"
    fi

    # Update /etc/hosts for own hostname
    if [[ -n "$HOSTNAME_CHANGE" ]]; then
        sed -i "/$HOSTNAME_CHANGE/d" /etc/hosts
        echo "$IP_CHANGE   $HOSTNAME_CHANGE" >> /etc/hosts
    fi
fi

# --- Add/update host entry ---
if [[ -n "$HOSTENTRY_NAME" ]] && [[ -n "$HOSTENTRY_IP" ]]; then
    if grep -q "$HOSTENTRY_NAME" /etc/hosts; then
        CURRENT_ENTRY_IP=$(grep "$HOSTENTRY_NAME" /etc/hosts | awk '{print $1}')

        if [[ "$CURRENT_ENTRY_IP" != "$HOSTENTRY_IP" ]]; then
            sed -i "/$HOSTENTRY_NAME/d" /etc/hosts
            echo "$HOSTENTRY_IP   $HOSTENTRY_NAME" >> /etc/hosts
            vprint "Updated hosts entry: $HOSTENTRY_NAME → $HOSTENTRY_IP"
            logger "configure-host.sh: hostentry updated for $HOSTENTRY_NAME to $HOSTENTRY_IP"
        else
            vprint "Host entry already correct for $HOSTENTRY_NAME"
        fi
    else
        echo "$HOSTENTRY_IP   $HOSTENTRY_NAME" >> /etc/hosts
        vprint "Added new hosts entry: $HOSTENTRY_NAME → $HOSTENTRY_IP"
        logger "configure-host.sh: new hostentry added for $HOSTENTRY_NAME ($HOSTENTRY_IP)"
    fi
fi

exit 0
