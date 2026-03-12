#!/bin/sh

# configureopnsense-v2.sh
# Improvements over v1:
#   - Named variables for all positional parameters (readability)
#   - Input validation with usage message and role check
#   - Timestamp-based logging via log() helper
#   - Dynamic Python binary detection (no hardcoded python3.11)
#   - python3 used for get_nic_gw.py before the symlink exists
#   - Shared fetch_gw_helper() eliminates duplicated code across branches
#   - All variables properly quoted to prevent word-splitting
#   - Heredocs use quoted delimiter ('EOL') to prevent unintended expansion
#   - Removed stale commented-out dead code
#   - tar without -v flag to reduce cloud-init log noise
#   - WebGUI hook written via heredoc instead of fragile echo chains
#   - Static ARP rc.conf entries written as a single block

# ── Parameters ────────────────────────────────────────────────────────────────
# $1 = OPNScriptURI      Base URI for fetching config/scripts
# $2 = OpnVersion        OPNsense version to install
# $3 = WALinuxVersion    WALinuxAgent version to install
# $4 = Role              VM role: Primary | Secondary | TwoNics
# $5 = TrustedSubnet     Trusted NIC subnet prefix (for GW resolution)
# $6 = WindowsVMSubnet   Windows Management VM subnet prefix (for routing)
# $7 = ELBVip            External Load Balancer VIP (Primary only)
# $8 = SecondaryIP       Private IP of Secondary OPNsense server (Primary only)

OPN_SCRIPT_URI="$1"
OPN_VERSION="$2"
WA_LINUX_VERSION="$3"
ROLE="$4"
TRUSTED_SUBNET="${5:-}"
WINDOWS_VM_SUBNET="${6:-}"
ELB_VIP="${7:-}"
SECONDARY_IP="${8:-}"

# ── Logging ───────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ── Input Validation ──────────────────────────────────────────────────────────
if [ -z "$OPN_SCRIPT_URI" ] || [ -z "$OPN_VERSION" ] || [ -z "$WA_LINUX_VERSION" ] || [ -z "$ROLE" ]; then
    echo "ERROR: Missing required parameters."
    echo "Usage: $0 <OPNScriptURI> <OpnVersion> <WALinuxVersion> <Primary|Secondary|TwoNics> <TrustedSubnet> <WindowsVMSubnet> [ELBVip] [SecondaryIP]"
    exit 1
fi

case "$ROLE" in
    Primary|Secondary|TwoNics) ;;
    *)
        echo "ERROR: Invalid role '${ROLE}'. Must be Primary, Secondary, or TwoNics."
        exit 1
        ;;
esac

# ── Helper: Resolve trusted NIC gateway IP ────────────────────────────────────
# Uses python3 directly since the python symlink is created later in this script
fetch_gw_ip() {
    fetch -q "${OPN_SCRIPT_URI}get_nic_gw.py"
    PYTHON_BIN=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "")
    if [ -z "$PYTHON_BIN" ]; then
        echo "ERROR: No Python interpreter found to run get_nic_gw.py." >&2
        exit 1
    fi
    "$PYTHON_BIN" get_nic_gw.py "$TRUSTED_SUBNET"
}

# ── Apply OPNsense Configuration XML ─────────────────────────────────────────
log "Configuring OPNsense role: ${ROLE}"

if [ "$ROLE" = "Primary" ]; then
    fetch -q "${OPN_SCRIPT_URI}config-active-active-primary.xml"
    GWIP=$(fetch_gw_ip)
    sed -i "" "s/yyy.yyy.yyy.yyy/${GWIP}/" config-active-active-primary.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_${WINDOWS_VM_SUBNET}_" config-active-active-primary.xml
    sed -i "" "s/www.www.www.www/${ELB_VIP}/" config-active-active-primary.xml
    sed -i "" "s/xxx.xxx.xxx.xxx/${SECONDARY_IP}/" config-active-active-primary.xml
    sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Primary<\/hostname>/" config-active-active-primary.xml
    cp config-active-active-primary.xml /usr/local/etc/config.xml

elif [ "$ROLE" = "Secondary" ]; then
    fetch -q "${OPN_SCRIPT_URI}config-active-active-secondary.xml"
    GWIP=$(fetch_gw_ip)
    sed -i "" "s/yyy.yyy.yyy.yyy/${GWIP}/" config-active-active-secondary.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_${WINDOWS_VM_SUBNET}_" config-active-active-secondary.xml
    sed -i "" "s/www.www.www.www/${ELB_VIP}/" config-active-active-secondary.xml
    sed -i "" "s/<hostname>OPNsense<\/hostname>/<hostname>OPNsense-Secondary<\/hostname>/" config-active-active-secondary.xml
    cp config-active-active-secondary.xml /usr/local/etc/config.xml

elif [ "$ROLE" = "TwoNics" ]; then
    fetch -q "${OPN_SCRIPT_URI}config.xml"
    GWIP=$(fetch_gw_ip)
    sed -i "" "s/yyy.yyy.yyy.yyy/${GWIP}/" config.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_${WINDOWS_VM_SUBNET}_" config.xml
    cp config.xml /usr/local/etc/config.xml
fi

# ── OPNsense Bootstrap ────────────────────────────────────────────────────────
log "Downloading OPNsense bootstrap script..."
fetch -q https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in

log "Enabling root SSH login..."
sed -i "" 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

# Patch bootstrap:
#   - Disable set -e because pkg commands (unlock -a, delete -fa) return non-zero
#   - Delay reboot by 1 minute so the rest of this script can finish
log "Patching bootstrap script..."
sed -i "" "s/set -e/#set -e/g" opnsense-bootstrap.sh.in
sed -i "" "s/reboot/shutdown -r +1/g" opnsense-bootstrap.sh.in

log "Running OPNsense bootstrap (version: ${OPN_VERSION})..."
sh ./opnsense-bootstrap.sh.in -y -r "$OPN_VERSION"

# ── Azure WALinuxAgent ────────────────────────────────────────────────────────
log "Installing WALinuxAgent v${WA_LINUX_VERSION}..."
fetch -q "https://github.com/Azure/WALinuxAgent/archive/refs/tags/v${WA_LINUX_VERSION}.tar.gz"
tar -xzf "v${WA_LINUX_VERSION}.tar.gz"
cd "WALinuxAgent-${WA_LINUX_VERSION}/"
python3 setup.py install --register-service --lnx-distro=freebsd --force
cd ..

# Create /usr/local/bin/python symlink pointing at the installed python3 binary.
# Detected dynamically so it remains correct if the python3 minor version changes.
log "Configuring python symlink for waagent..."
PYTHON3_BIN=$(ls /usr/local/bin/python3.* 2>/dev/null | grep -v '\.py$' | sort -V | tail -1)
if [ -n "$PYTHON3_BIN" ] && [ ! -e /usr/local/bin/python ]; then
    ln -s "$PYTHON3_BIN" /usr/local/bin/python
    log "Symlink created: /usr/local/bin/python -> ${PYTHON3_BIN}"
fi

sed -i "" 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/' /etc/waagent.conf

log "Installing waagent actions configuration..."
fetch -q "${OPN_SCRIPT_URI}actions_waagent.conf"
cp actions_waagent.conf /usr/local/opnsense/service/conf/actions.d

# ── Additional Packages ───────────────────────────────────────────────────────
# bash  : required for Azure Custom Script Extension
# os-frr: FRRouting for dynamic routing support
log "Installing additional packages (bash, os-frr)..."
pkg install -y bash
pkg install -y os-frr

# ── Azure Route Fix ───────────────────────────────────────────────────────────
# Delete the 168.63.129.16 host route that Azure injects at boot; OPNsense
# uses a static ARP entry instead (see below) so the route is not needed and
# can interfere with traffic.
log "Adding startup hook to remove spurious Azure route..."
cat > /usr/local/etc/rc.syshook.d/start/22-remoteroute <<'EOL'
#!/bin/sh
route delete 168.63.129.16
EOL
chmod +x /usr/local/etc/rc.syshook.d/start/22-remoteroute

# ── Azure Load Balancer Probe / Internal VIP ──────────────────────────────────
# OPNsense must respond to ARP requests for 168.63.129.16 so that:
#   1. Azure health probes from the load balancer reach the VM
#   2. Azure platform services (IMDS, waagent) remain reachable
log "Configuring static ARP entry for Azure Internal VIP (168.63.129.16)..."
{
    echo "# Azure Internal VIP - required for LB health probes and platform services"
    echo 'static_arp_pairs="azvip"'
    echo 'static_arp_azvip="168.63.129.16 12:34:56:78:9a:bc"'
} >> /etc/rc.conf

service static_arp start
echo 'service static_arp start' >> /usr/local/etc/rc.syshook.d/start/20-freebsd

# ── WebGUI Certificate Renewal ────────────────────────────────────────────────
# One-time boot hook: renews the self-signed WebGUI certificate after OPNsense
# first boots, then removes itself so it does not run on subsequent reboots.
log "Setting up one-time WebGUI certificate renewal hook..."
cat > /usr/local/etc/rc.syshook.d/start/94-restartwebgui <<'EOL'
#!/bin/sh
configctl webgui restart renew
rm /usr/local/etc/rc.syshook.d/start/94-restartwebgui
EOL
chmod +x /usr/local/etc/rc.syshook.d/start/94-restartwebgui

log "OPNsense provisioning complete. System will reboot in approximately 1 minute."
