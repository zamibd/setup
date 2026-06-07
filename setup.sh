#!/usr/bin/env bash
# ================================================================
#  RAHMAT — DNS SaaS Server Setup Script
#  Supports : Ubuntu 22.04+ (LTS & interim) | Debian (all) | AlmaLinux (all)
#             Rocky · RHEL · CentOS Stream · Fedora (latest) | Alpine Linux 3.x+
#  Author   : RAHMAT
#  GitHub   : https://github.com/zamibd/setup/setup.sh
#  Version  : 2.8.4
# ================================================================

# Re-exec with bash when invoked via ash/sh (Alpine: `sh setup.sh` after download)
if [ -z "${BASH_VERSION:-}" ]; then
    _rahmat_sh="$0"
    if [ -r /etc/alpine-release ] && command -v apk >/dev/null 2>&1; then
        apk add --no-cache bash >/dev/null 2>&1 || apk add bash >/dev/null 2>&1 || true
    fi
    if [ -x /bin/bash ] && [ -f "$_rahmat_sh" ]; then
        exec /bin/bash "$_rahmat_sh" "$@"
    fi
    printf '%s\n' \
        'ERROR: bash is required to run this installer.' \
        'Alpine:  apk add bash && bash setup.sh' \
        'Others:  bash setup.sh   (or: sudo bash setup.sh)' >&2
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

load_dotenv() {
    local _file="$1"
    [[ -f "$_file" ]] || return 1
    set -a
    # shellcheck disable=SC1090
    source "$_file"
    set +a
    return 0
}

apply_config_defaults() {
    : "${GITHUB_URL:=https://github.com/zamibd/setup/setup.sh}"
    : "${TIMEZONE:=Asia/Dhaka}"
    : "${INTERACTIVE_PROMPTS:=true}"
    : "${DNS_NAMESERVER_1:=8.8.8.8}"
    : "${DNS_NAMESERVER_2:=1.1.1.1}"
    : "${DNS_NAMESERVER_3:=8.8.4.4}"
    : "${SWAP_ENABLED:=true}"
    : "${SWAP_SIZE_GB:=2}"
    : "${SWAP_FILE:=/swapfile}"
    : "${LIMIT_NOFILE:=1048576}"
    : "${LIMIT_NPROC:=65535}"
    : "${SYSCTL_NETDEV_MAX_BACKLOG:=250000}"
    : "${SYSCTL_SOMAXCONN:=65535}"
    : "${SYSCTL_CONNTRACK_MAX:=2097152}"
    : "${SYSCTL_CONNTRACK_TCP_ESTABLISHED:=7200}"
    : "${SYSCTL_SWAPPINESS:=10}"
    : "${SYSCTL_FILE_MAX:=2097152}"
    : "${SYSCTL_UDP_RMEM_MIN:=16384}"
    : "${DOCKER_LOG_MAX_SIZE:=10m}"
    : "${DOCKER_LOG_MAX_FILE:=3}"
    : "${DOCKER_STORAGE_DRIVER:=overlay2}"
    : "${DOCKER_CGROUP_DRIVER:=systemd}"
    : "${DNS_UDP_RATE:=300/sec}"
    : "${DNS_UDP_BURST:=600}"
    : "${DNS_TCP_RATE:=50/sec}"
    : "${DNS_TCP_BURST:=100}"
    : "${DNS_TCP_CONN_MAX:=30}"
    : "${DNS_UDP_MAX_PACKET:=1232}"
    : "${DOT_RATE:=200/sec}"
    : "${DOT_BURST:=400}"
    : "${DOT_CONN_MAX:=500}"
    : "${DOH_RATE:=80/sec}"
    : "${DOH_BURST:=160}"
    : "${SYN_RATE:=2000/sec}"
    : "${SYN_BURST:=4000}"
    : "${SSH_PORT:=22}"
    : "${SSH_USER:=root}"
    : "${SSH_PUBLIC_KEY:=}"
    : "${SSH_WHITELIST_IPS:=}"
    : "${SSH_DISABLE_PASSWORD:=auto}"
    : "${SSH_MAX_AUTH_TRIES:=3}"
    : "${SSH_LOGIN_GRACE_TIME:=30}"
    : "${SSH_CLIENT_ALIVE_INTERVAL:=300}"
    : "${SSH_CLIENT_ALIVE_COUNT_MAX:=2}"
    : "${F2B_DEFAULT_BANTIME:=3600}"
    : "${F2B_DEFAULT_FINDTIME:=600}"
    : "${F2B_DEFAULT_MAXRETRY:=3}"
    : "${F2B_SSHD_MAXRETRY:=2}"
    : "${F2B_SSHD_BANTIME:=86400}"
    : "${F2B_SSHD_FINDTIME:=300}"
    : "${F2B_SSHD_MODE:=aggressive}"
    : "${F2B_RECIDIVE_BANTIME:=604800}"
    : "${F2B_RECIDIVE_FINDTIME:=86400}"
    : "${F2B_RECIDIVE_MAXRETRY:=2}"
}

# Load config: .env beside script → /etc/rahmat/.env → defaults
if [[ ! -f "$ENV_FILE" ]] && [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
    cp "${SCRIPT_DIR}/.env.example" "$ENV_FILE"
fi
load_dotenv "$ENV_FILE" || true
load_dotenv "/etc/rahmat/.env" || true
apply_config_defaults

TOTAL_STEPS=14

# ── Colors & Styles (hacker / matrix theme) ─────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

RED='\033[0;31m';     GREEN='\033[0;32m'
YELLOW='\033[0;33m';  CYAN='\033[0;36m'
WHITE='\033[0;37m'

BRED='\033[1;31m';    BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'; BBLUE='\033[1;34m'
BMAGENTA='\033[1;35m';BCYAN='\033[1;36m'
BWHITE='\033[1;37m'

HACK="${BGREEN}"           # primary matrix green
HACK_DIM="${DIM}${GREEN}"  # muted terminal green
HACK_MUTED="${DIM}${GREEN}"
HACK_WARN="${BYELLOW}"     # amber alerts
HACK_ERR="${BRED}"
BG_HACK='\033[40m\033[1;32m'

# ── Log Helpers ──────────────────────────────────────────────────
info()   { echo -e "  ${HACK}[*]${RESET}  $*"; }
ok()     { echo -e "  ${HACK}[+]${RESET}  $*"; }
warn()   { echo -e "  ${HACK_WARN}[!]${RESET}  ${HACK_WARN}$*${RESET}"; }
skip()   { echo -e "  ${HACK_MUTED}[-]${RESET}  ${HACK_DIM}$* — skipped (exists)${RESET}"; }
fail()   { echo -e "\n  ${HACK_ERR}[x] FATAL:${RESET} ${RED}$*${RESET}\n" >&2; exit 1; }
detail() { echo -e "      ${HACK_DIM}$*${RESET}"; }

step() {
    local num="$1" total="$2" title="$3"
    local phase
    phase=$(printf '%02d' "$num")
    echo ""
    echo -e "  ${HACK}[PHASE ${phase}/${total}]${RESET}  ${BOLD}${HACK}>> ${title}${RESET}"
    echo -e "  ${HACK_MUTED}$(printf '%.0s-' {1..50})${RESET}"
}

GITHUB_URL="${GITHUB_URL}"

# ── Interactive / validation helpers ─────────────────────────────
is_interactive() {
    [[ "${INTERACTIVE_PROMPTS}" == "true" ]] && [[ -t 0 ]]
}

ask_line() {
    local prompt="$1" __var="$2" _reply
    if is_interactive; then
        echo -e "  ${HACK}[?]${RESET}  $prompt"
        read -r _reply
        printf -v "$__var" '%s' "$_reply"
    else
        warn "non-interactive — skipped: $prompt"
        printf -v "$__var" ''
    fi
}

valid_ip_or_cidr() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$ ]]
}

valid_ssh_pubkey() {
    local key="$1"
    [[ "$key" =~ ^(ssh-(rsa|ed25519|ecdsa)|ecdsa-sha2-nistp256)[[:space:]]+[A-Za-z0-9+/=]+ ]]
}

sshd_test_and_reload() {
    if sshd -t 2>/dev/null; then
        svc_reload_sshd
        ok "sshd config validated & reloaded"
    else
        warn "sshd config test failed — fix manually before reload"
    fi
}

port_is_bound() {
    local port="$1" proto="${2:-tcp}"
    if command -v ss &>/dev/null; then
        ss -Hln "$proto" 2>/dev/null | grep -qE "[:.]${port}([^0-9]|$)" && return 0
    fi
    return 1
}

extract_semver() {
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

extract_version_short() {
    grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

has_systemd() {
    [[ -d /run/systemd/system ]] && command -v systemctl &>/dev/null
}

svc_daemon_reload() {
    has_systemd && systemctl daemon-reload 2>/dev/null || true
}

svc_enable_now() {
    local svc="$1"
    if has_systemd; then
        systemctl enable --now "$svc" 2>/dev/null || true
    elif command -v rc-update &>/dev/null; then
        rc-update add "$svc" boot 2>/dev/null || true
        rc-service "$svc" start 2>/dev/null || service "$svc" start 2>/dev/null || true
    fi
}

svc_is_active() {
    local svc="$1"
    if has_systemd; then
        systemctl is-active --quiet "$svc" 2>/dev/null
    elif command -v rc-service &>/dev/null; then
        rc-service "$svc" status 2>/dev/null | grep -qiE 'started|running'
    else
        return 1
    fi
}

svc_disable_now() {
    local svc="$1"
    if has_systemd; then
        systemctl disable --now "$svc" 2>/dev/null || true
    elif command -v rc-service &>/dev/null; then
        rc-service "$svc" stop 2>/dev/null || true
        rc-update del "$svc" boot 2>/dev/null || true
    fi
}

svc_restart() {
    local svc="$1"
    if has_systemd; then
        systemctl restart "$svc" 2>/dev/null || true
    else
        rc-service "$svc" restart 2>/dev/null || service "$svc" restart 2>/dev/null || true
    fi
}

svc_reload_sshd() {
    if has_systemd; then
        systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
    else
        rc-service sshd reload 2>/dev/null || rc-service ssh reload 2>/dev/null || \
            kill -HUP "$(pidof sshd 2>/dev/null | awk '{print $1}')" 2>/dev/null || true
    fi
}

get_timezone() {
    if command -v timedatectl &>/dev/null; then
        timedatectl show -p Timezone --value 2>/dev/null || echo "unknown"
    elif [[ -L /etc/localtime ]]; then
        readlink /etc/localtime | sed 's|.*/zoneinfo/||'
    else
        echo "unknown"
    fi
}

set_system_timezone() {
    if command -v timedatectl &>/dev/null; then
        timedatectl set-timezone "$TIMEZONE"
    else
        command -v apk &>/dev/null && apk add --no-cache tzdata >/dev/null 2>&1 || true
        ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
        echo "$TIMEZONE" > /etc/timezone 2>/dev/null || true
    fi
}

enable_apk_community_repo() {
    [[ -f /etc/apk/repositories ]] || return 0
    if grep -qE '^[^#].*/community' /etc/apk/repositories; then
        return 0
    fi
    sed -i 's|^#\(.*/community\)|\1|' /etc/apk/repositories 2>/dev/null || \
        sed -i '' 's|^#\(.*/community\)|\1|' /etc/apk/repositories 2>/dev/null || true
}

ALPINE_IPT="${ALPINE_IPT:-iptables-legacy}"
ALPINE_IP6T="${ALPINE_IP6T:-ip6tables-legacy}"

prepare_alpine_netfilter() {
    [[ "${OS_FAMILY:-}" == "alpine" ]] || return 0

    apk add --no-cache iptables-legacy iptables-legacy-openrc 2>/dev/null || \
        apk add --no-cache iptables-legacy 2>/dev/null || true

    for _m in nf_tables nf_nat nf_conntrack ip_tables ip_conntrack \
        xt_conntrack xt_recent xt_hashlimit xt_connlimit br_netfilter overlay; do
        modprobe "$_m" 2>/dev/null || true
    done

    if command -v iptables-legacy &>/dev/null && iptables-legacy -L -n &>/dev/null 2>&1; then
        ALPINE_IPT="iptables-legacy"
        ALPINE_IP6T="ip6tables-legacy"
    elif command -v iptables &>/dev/null; then
        ALPINE_IPT="iptables"
        ALPINE_IP6T="ip6tables"
    fi

    mkdir -p /etc/conf.d
    if [[ ! -f /etc/conf.d/docker ]] || ! grep -q 'RAHMAT.*IPTABLES' /etc/conf.d/docker 2>/dev/null; then
        {
            echo "# RAHMAT — legacy iptables on Alpine virt/minimal kernels (nft may be unavailable)"
            echo "export IPTABLES=${ALPINE_IPT}"
            echo "export IP6TABLES=${ALPINE_IP6T}"
        } >> /etc/conf.d/docker
    fi

    ok "Alpine netfilter ready (${ALPINE_IPT})"
}

alpine_iptables_save() {
    mkdir -p /etc/iptables
    if command -v iptables-legacy-save &>/dev/null; then
        iptables-legacy-save > /etc/iptables/rules-save 2>/dev/null || true
    else
        iptables-save > /etc/iptables/rules-save 2>/dev/null || true
    fi
}

wait_for_docker() {
    local _i
    for _i in $(seq 1 15); do
        docker info &>/dev/null 2>&1 && return 0
        sleep 2
    done
    return 1
}

apply_ddos_kernel() {
    local ddos_sysctl="/etc/sysctl.d/99-rahmat-ddos.conf"
    cat > "$ddos_sysctl" << 'EOF'
# RAHMAT — DDoS / flood mitigation (kernel)

# SYN flood protection
net.ipv4.tcp_syncookies              = 1
net.ipv4.tcp_synack_retries          = 2
net.ipv4.tcp_syn_retries             = 2

# Reverse-path filtering (anti-spoof)
net.ipv4.conf.all.rp_filter          = 1
net.ipv4.conf.default.rp_filter      = 1

# ICMP rate limit (ping/smurf mitigation)
net.ipv4.icmp_ratelimit              = 100
net.ipv4.icmp_ratemask               = 6168

# Ignore bogus ICMP redirects
net.ipv4.conf.all.accept_redirects   = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects     = 0
net.ipv4.conf.default.send_redirects = 0

# Martians / invalid source
net.ipv4.conf.all.log_martians       = 1
net.ipv4.conf.default.log_martians   = 1
EOF
    sysctl -p "$ddos_sysctl" > /dev/null 2>&1 || true
    ok "DDoS kernel hardening → ${ddos_sysctl}"
}

install_ddos_script() {
    DDOS_DIR="/etc/rahmat"
    DDOS_CONF="${DDOS_DIR}/ddos.conf"
    DDOS_SCRIPT="${DDOS_DIR}/apply-ddos-rules.sh"
    mkdir -p "$DDOS_DIR"

    cat > "$DDOS_CONF" << EOF
# RAHMAT DDoS rate limits — generated from .env (systemctl restart rahmat-ddos)

# DNS plain (53)
DNS_UDP_RATE='${DNS_UDP_RATE}'
DNS_UDP_BURST='${DNS_UDP_BURST}'
DNS_TCP_RATE='${DNS_TCP_RATE}'
DNS_TCP_BURST='${DNS_TCP_BURST}'
DNS_TCP_CONN_MAX='${DNS_TCP_CONN_MAX}'
DNS_UDP_MAX_PACKET='${DNS_UDP_MAX_PACKET}'

# DoT (853)
DOT_RATE='${DOT_RATE}'
DOT_BURST='${DOT_BURST}'
DOT_CONN_MAX='${DOT_CONN_MAX}'

# DoH (443)
DOH_RATE='${DOH_RATE}'
DOH_BURST='${DOH_BURST}'

# Global SYN flood ceiling
SYN_RATE='${SYN_RATE}'
SYN_BURST='${SYN_BURST}'
EOF

    cat > "$DDOS_SCRIPT" << 'EOFSCRIPT'
#!/usr/bin/env bash
# RAHMAT — iptables/nft DDoS rate limits (DNS 53, DoT 853, DoH 443)
set -euo pipefail

CONF="/etc/rahmat/ddos.conf"
[[ -f "$CONF" ]] && source "$CONF"

DNS_UDP_RATE="${DNS_UDP_RATE:-300/sec}"
DNS_UDP_BURST="${DNS_UDP_BURST:-600}"
DNS_TCP_RATE="${DNS_TCP_RATE:-50/sec}"
DNS_TCP_BURST="${DNS_TCP_BURST:-100}"
DNS_TCP_CONN_MAX="${DNS_TCP_CONN_MAX:-30}"
DOT_RATE="${DOT_RATE:-200/sec}"
DOT_BURST="${DOT_BURST:-400}"
DOT_CONN_MAX="${DOT_CONN_MAX:-500}"
DOH_RATE="${DOH_RATE:-80/sec}"
DOH_BURST="${DOH_BURST:-160}"
SYN_RATE="${SYN_RATE:-2000/sec}"
SYN_BURST="${SYN_BURST:-4000}"

CHAIN="RAHMAT-DDoS"
if [[ -z "${IPTABLES:-}" ]] && command -v iptables-legacy &>/dev/null; then
    IPT="iptables-legacy"
else
    IPT="${IPTABLES:-iptables}"
fi

modprobe xt_hashlimit 2>/dev/null || true
modprobe xt_connlimit 2>/dev/null || true
modprobe xt_recent   2>/dev/null || true
modprobe nf_conntrack 2>/dev/null || true

$IPT -N "$CHAIN" 2>/dev/null || $IPT -F "$CHAIN"
$IPT -C INPUT -j "$CHAIN" 2>/dev/null || $IPT -I INPUT 1 -j "$CHAIN"

$IPT -A "$CHAIN" -m conntrack --ctstate INVALID -j DROP
$IPT -A "$CHAIN" -p tcp -m conntrack --ctstate NEW ! --syn -j DROP
$IPT -A "$CHAIN" -f -j DROP

# DNS UDP 53
$IPT -A "$CHAIN" -p udp --dport 53 \
    -m hashlimit --hashlimit-name dns_udp --hashlimit-mode srcip \
    --hashlimit-above "${DNS_UDP_RATE}" --hashlimit-burst "${DNS_UDP_BURST}" -j DROP
DNS_UDP_MAX_PACKET="${DNS_UDP_MAX_PACKET:-1232}"
DNS_UDP_DROP_MIN=$((DNS_UDP_MAX_PACKET + 1))
$IPT -A "$CHAIN" -p udp --dport 53 -m length --length ${DNS_UDP_DROP_MIN}:65535 -j DROP

# DNS TCP 53
$IPT -A "$CHAIN" -p tcp --dport 53 -m conntrack --ctstate NEW \
    -m hashlimit --hashlimit-name dns_tcp --hashlimit-mode srcip \
    --hashlimit-above "${DNS_TCP_RATE}" --hashlimit-burst "${DNS_TCP_BURST}" -j DROP
$IPT -A "$CHAIN" -p tcp --dport 53 \
    -m connlimit --connlimit-above "${DNS_TCP_CONN_MAX}" --connlimit-mask 32 --connlimit-saddr -j DROP

# DoT 853 — mobile TLS (CGNAT-tolerant limits from ddos.conf)
$IPT -A "$CHAIN" -p tcp --dport 853 -m conntrack --ctstate NEW \
    -m hashlimit --hashlimit-name dot_new --hashlimit-mode srcip \
    --hashlimit-above "${DOT_RATE}" --hashlimit-burst "${DOT_BURST}" -j DROP
$IPT -A "$CHAIN" -p tcp --dport 853 \
    -m connlimit --connlimit-above "${DOT_CONN_MAX}" --connlimit-mask 32 --connlimit-saddr -j DROP

# DoH 443
$IPT -A "$CHAIN" -p tcp --dport 443 -m conntrack --ctstate NEW \
    -m hashlimit --hashlimit-name doh_new --hashlimit-mode srcip \
    --hashlimit-above "${DOH_RATE}" --hashlimit-burst "${DOH_BURST}" -j DROP

# SYN flood — global ceiling
$IPT -A "$CHAIN" -p tcp --syn \
    -m limit --limit "${SYN_RATE}" --limit-burst "${SYN_BURST}" -j RETURN
$IPT -A "$CHAIN" -p tcp --syn -j DROP

$IPT -A "$CHAIN" -j RETURN
EOFSCRIPT
    chmod +x "$DDOS_SCRIPT"

    if has_systemd; then
        cat > /etc/systemd/system/rahmat-ddos.service << EOF
[Unit]
Description=RAHMAT DDoS mitigation iptables rules
After=network-online.target ufw.service firewalld.service docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${DDOS_SCRIPT}

[Install]
WantedBy=multi-user.target
EOF
        svc_daemon_reload
        systemctl enable rahmat-ddos.service > /dev/null 2>&1
        systemctl restart rahmat-ddos.service > /dev/null 2>&1 || bash "$DDOS_SCRIPT" || true
    else
        mkdir -p /etc/local.d /etc/iptables
        cat > /etc/local.d/rahmat-network.start << EOF
#!/bin/sh
# RAHMAT — Alpine/OpenRC firewall + DDoS rules at boot
export IPTABLES=${ALPINE_IPT:-iptables-legacy}
export IP6TABLES=${ALPINE_IP6T:-ip6tables-legacy}
[ -x /etc/rahmat/apply-alpine-firewall.sh ] && /etc/rahmat/apply-alpine-firewall.sh
${DDOS_SCRIPT}
iptables-legacy-save > /etc/iptables/rules-save 2>/dev/null || iptables-save > /etc/iptables/rules-save 2>/dev/null || true
EOF
        chmod +x /etc/local.d/rahmat-network.start
        IPTABLES="${ALPINE_IPT:-iptables-legacy}" bash "$DDOS_SCRIPT" || true
        ok "OpenRC boot script → /etc/local.d/rahmat-network.start"
    fi
}

apply_ddos_firewalld() {
    info "Applying firewalld DDoS direct rules..."
    # shellcheck disable=SC1091
    source "${DDOS_DIR}/ddos.conf"
    local _passthrough=(
        "-I INPUT -p udp --dport 53 -m hashlimit --hashlimit-name dns_udp --hashlimit-mode srcip --hashlimit-above ${DNS_UDP_RATE} --hashlimit-burst ${DNS_UDP_BURST} -j DROP"
        "-I INPUT -p udp --dport 53 -m length --length $((DNS_UDP_MAX_PACKET + 1)):65535 -j DROP"
        "-I INPUT -p tcp --dport 53 -m conntrack --ctstate NEW -m hashlimit --hashlimit-name dns_tcp --hashlimit-mode srcip --hashlimit-above ${DNS_TCP_RATE} --hashlimit-burst ${DNS_TCP_BURST} -j DROP"
        "-I INPUT -p tcp --dport 53 -m connlimit --connlimit-above ${DNS_TCP_CONN_MAX} --connlimit-mask 32 --connlimit-saddr -j DROP"
        "-I INPUT -p tcp --dport 853 -m conntrack --ctstate NEW -m hashlimit --hashlimit-name dot_new --hashlimit-mode srcip --hashlimit-above ${DOT_RATE} --hashlimit-burst ${DOT_BURST} -j DROP"
        "-I INPUT -p tcp --dport 853 -m connlimit --connlimit-above ${DOT_CONN_MAX} --connlimit-mask 32 --connlimit-saddr -j DROP"
        "-I INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m hashlimit --hashlimit-name doh_new --hashlimit-mode srcip --hashlimit-above ${DOH_RATE} --hashlimit-burst ${DOH_BURST} -j DROP"
        "-I INPUT -p tcp --syn -m limit --limit ${SYN_RATE} --limit-burst ${SYN_BURST} -j RETURN"
        "-I INPUT -p tcp --syn -j DROP"
        "-I INPUT -m conntrack --ctstate INVALID -j DROP"
    )
    firewall-cmd --permanent --direct --remove-chain ipv4 filter RAHMAT-DDoS 2>/dev/null || true
    for _pt in "${_passthrough[@]}"; do
        firewall-cmd --permanent --direct --passthrough ipv4 "$_pt" 2>/dev/null || true
    done
    firewall-cmd --reload > /dev/null 2>&1
}

SSH_PUBKEY="${SSH_PUBLIC_KEY:-}"
SSH_WHITELIST=()
CURRENT_SSH_IP=""
[[ -n "${SSH_CONNECTION:-}" ]] && CURRENT_SSH_IP="${SSH_CONNECTION%% *}"

banner() {
    clear
    echo ""
    echo -e "${HACK_DIM}[!] initialising payload...${RESET}"
    echo -e "${HACK}${BOLD}"
    echo '  ┌──────────────────────────────────────────────────────────┐'
    echo '  │ 0x5241484D4154 :: RAHMAT :: DNS-INFRA :: v2.8.4          │'
    echo '  ├──────────────────────────────────────────────────────────┤'
    echo '  │                                                          │'
    echo '  │   ####    ###   #   #  ## ##   ###   #####              │'
    echo '  │   #   #  #   #  #   #  # # #  #   #    #                │'
    echo '  │   ####   #####  #####  # # #  #####    #                │'
    echo '  │   #  #   #   #  #   #  #   #  #   #    #                │'
    echo '  │   #   #  #   #  #   #  #   #  #   #    #                │'
    echo '  │                                                          │'
    echo '  │  >> PRIV_ESC: [OK]  |  SHELL: root  |  TARGET: DNS-NODE │'
    echo '  └──────────────────────────────────────────────────────────┘'
    echo -e "${RESET}"
    echo -e "  ${HACK}[root@rahmat:~#]${RESET} ${HACK_DIM}./setup.sh --deploy-dns${RESET}"
    echo -e "  ${HACK_MUTED}[$]${RESET} ${GREEN}${GITHUB_URL}${RESET}"
    echo -e "  ${HACK_MUTED}[#]${RESET} ${HACK_DIM}ubuntu | debian | almalinux | rocky | rhel | fedora${RESET}"
    echo ""
    echo -e "  ${HACK_MUTED}$(printf '%.0s=' {1..58})${RESET}"
    echo ""
}

# ── Root Check ───────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && {
    echo -e "\n  ${HACK_ERR}[x] ACCESS DENIED${RESET}  ${HACK_DIM}root privileges required${RESET}"
    echo -e "  ${HACK}[>]${RESET}  ${HACK_WARN}sudo bash $0${RESET}\n"
    exit 1
}

banner

# Sync .env to system path
install -d -m 750 /etc/rahmat
if [[ -f "$ENV_FILE" ]]; then
    install -m 640 "$ENV_FILE" /etc/rahmat/.env
    ok "Config loaded → ${ENV_FILE}"
    detail "System copy : /etc/rahmat/.env"
fi

# ────────────────────────────────────────────────────────────────
# STEP 1 — OS Detection
# ────────────────────────────────────────────────────────────────
step 1 "$TOTAL_STEPS" "OS Detection"

[[ -f /etc/os-release ]] || fail "/etc/os-release not found"
# shellcheck disable=SC1091
source /etc/os-release

OS_ID="${ID,,}"
OS_VERSION="${VERSION_ID:-}"
ID_LIKE="${ID_LIKE:-}"
PKG_MANAGER=""
OS_FAMILY=""
OS_DISPLAY=""
DOCKER_APT_ID=""
DOCKER_APT_SUITE=""
DOCKER_DNF_REPO=""
NEEDS_EPEL=true

resolve_codename() {
    local codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-${DEBIAN_CODENAME:-}}}"
    if [[ -z "$codename" && -n "${VERSION:-}" ]]; then
        codename=$(echo "$VERSION" | grep -oP '\(\K[a-z]+(?=\))' | head -1 || true)
    fi
    [[ -n "$codename" ]] || fail "Could not detect release codename for $PRETTY_NAME"
    echo "$codename"
}

# Map bleeding-edge Debian/Ubuntu codenames to a Docker-supported suite when needed
resolve_docker_apt_suite() {
    local codename="$1"
    local family="$2"
    local -a known_debian=(forky trixie bookworm bullseye buster stretch)
    local -a known_ubuntu=(
        questing plucky oracular noble mantic lunar kinetic jammy impish hirsute focal
    )
    local known suite
    if [[ "$family" == "debian" ]]; then
        for suite in "${known_debian[@]}"; do
            [[ "$codename" == "$suite" ]] && { echo "$codename"; return; }
        done
        case "$codename" in
            sid|unstable|testing|rc-buggy) echo "trixie" ;;
            *) echo "$codename" ;;
        esac
    else
        for suite in "${known_ubuntu[@]}"; do
            [[ "$codename" == "$suite" ]] && { echo "$codename"; return; }
        done
        # Future interim/LTS codenames not yet in Docker repos → latest known LTS
        echo "noble"
    fi
}

ubuntu_version_ok() {
    local ver="$1"
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)
    minor=${minor:-0}
    [[ $major -gt 22 ]] || [[ $major -eq 22 && $minor -ge 4 ]]
}

ubuntu_codename_supported() {
    local codename="$1"
    case "$codename" in
        warty|hoary|breezy|dapper|edgy|feisty|gutsy|hardy|intrepid|jaunty|karmic|lucid|maverick|natty|oneiric|precise|quantal|raring|ringtail|saucy|trusty|utopic|vivid|wily|xenial|yakkety|zesty|artful|bionic|cosmic|disco|eoan|focal|groovy|hirsute|impish|kinetic|lunar|mantic)
            return 1 ;;
        *) return 0 ;;
    esac
}

configure_apt_os() {
    local label="$1"
    local docker_id="$2"
    CODENAME=$(resolve_codename)
    DOCKER_APT_SUITE=$(resolve_docker_apt_suite "$CODENAME" "$docker_id")
    DOCKER_APT_ID="$docker_id"
    PKG_MANAGER="apt"
    OS_FAMILY="debian"
    OS_DISPLAY="$label"
    ok "${BGREEN}${label}${RESET} (${CODENAME}) — supported"
    detail "Codename    : $CODENAME"
    if [[ "$DOCKER_APT_SUITE" != "$CODENAME" ]]; then
        detail "Docker suite: $DOCKER_APT_SUITE (mapped from $CODENAME)"
    else
        detail "Docker suite: $DOCKER_APT_SUITE"
    fi
    detail "Arch        : $(dpkg --print-architecture)"
}

configure_dnf_os() {
    local label="$1"
    local epel="${2:-true}"
    DOCKER_DNF_REPO=$(resolve_docker_dnf_repo)
    NEEDS_EPEL="$epel"
    PKG_MANAGER="dnf"
    OS_FAMILY="rhel"
    OS_DISPLAY="$label"
    ok "${BGREEN}${label}${RESET} — supported"
    detail "Version     : ${OS_VERSION:-rolling}"
    detail "Arch        : $(uname -m)"
    detail "Docker repo : ${DOCKER_DNF_REPO##*/}"
    is_rhel_el10_plus && detail "EL10+ notes  : iptables-nft + kernel-modules-extra"
    [[ "$NEEDS_EPEL" == "true" ]] && detail "EPEL        : enabled"
}

rhel_major_version() {
    echo "${OS_VERSION:-0}" | cut -d. -f1
}

is_rhel_el10_plus() {
    local major
    major=$(rhel_major_version)
    [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -ge 10 ]]
}

resolve_docker_dnf_repo() {
    case "$OS_ID" in
        rhel|redhat)
            echo "https://download.docker.com/linux/rhel/docker-ce.repo"
            ;;
        fedora)
            echo "https://download.docker.com/linux/fedora/docker-ce.repo"
            ;;
        *)
            if is_rhel_el10_plus; then
                echo "https://download.docker.com/linux/rhel/docker-ce.repo"
            else
                echo "https://download.docker.com/linux/centos/docker-ce.repo"
            fi
            ;;
    esac
}

alpine_version_ok() {
    local ver="$1"
    local major
    major=$(echo "$ver" | cut -d. -f1)
    [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -ge 3 ]]
}

configure_apk_os() {
    local label="$1"
    PKG_MANAGER="apk"
    OS_FAMILY="alpine"
    OS_DISPLAY="$label"
    ok "${BGREEN}${label}${RESET} — supported"
    detail "Version     : ${OS_VERSION:-unknown}"
    detail "Arch        : $(uname -m)"
    detail "Init        : $(has_systemd && echo systemd || echo openrc)"
    detail "Firewall    : iptables (Alpine)"
}

case "$OS_ID" in
    ubuntu)
        [[ -n "$OS_VERSION" ]] || fail "Could not detect Ubuntu version"
        ubuntu_version_ok "$OS_VERSION" || \
            fail "Ubuntu 22.04+ required. Found: $OS_VERSION (supported: 22.04, 24.04, 24.10, 25.04, 25.10, 26.04+)"
        configure_apt_os "Ubuntu ${OS_VERSION}" "ubuntu"
        ;;
    debian)
        configure_apt_os "Debian ${OS_VERSION:-}" "debian"
        ;;
    # Ubuntu-based derivatives (22.04+ base detected via codename)
    linuxmint|pop|pop-os|elementary|zorin|peppermint|linuxlite|kubuntu|lubuntu|xubuntu|ubuntu-mate|ubuntustudio)
        deriv_codename=$(resolve_codename)
        ubuntu_codename_supported "$deriv_codename" || \
            fail "$PRETTY_NAME requires Ubuntu 22.04+ base (codename: $deriv_codename)"
        configure_apt_os "${PRETTY_NAME}" "ubuntu"
        ;;
    # Debian-based derivatives
    kali|parrot|devuan|mx-linux|antiX)
        configure_apt_os "${PRETTY_NAME}" "debian"
        ;;
    almalinux)
        configure_dnf_os "AlmaLinux ${OS_VERSION:-}"
        ;;
    rocky|rockylinux)
        configure_dnf_os "Rocky Linux ${OS_VERSION:-}"
        ;;
    centos|centos_stream)
        configure_dnf_os "CentOS ${OS_VERSION:-}"
        ;;
    rhel|redhat)
        configure_dnf_os "RHEL ${OS_VERSION:-}"
        ;;
    ol|oraclelinux|oracle)
        configure_dnf_os "Oracle Linux ${OS_VERSION:-}"
        ;;
    fedora)
        configure_dnf_os "Fedora ${OS_VERSION:-}" "false"
        ;;
    alpine)
        [[ -n "$OS_VERSION" ]] || fail "Could not detect Alpine version"
        alpine_version_ok "$OS_VERSION" || \
            fail "Alpine Linux 3.x+ required. Found: $OS_VERSION"
        configure_apk_os "Alpine Linux ${OS_VERSION}"
        ;;
    *)
        # Fallback: detect via ID_LIKE for unknown derivatives
        if [[ "$ID_LIKE" == *ubuntu* ]]; then
            like_codename=$(resolve_codename)
            ubuntu_codename_supported "$like_codename" || \
                fail "Unsupported derivative '$OS_ID'. Ubuntu 22.04+ base required (codename: $like_codename)."
            configure_apt_os "${PRETTY_NAME}" "ubuntu"
        elif [[ "$ID_LIKE" == *debian* ]]; then
            configure_apt_os "${PRETTY_NAME}" "debian"
        elif [[ "$ID_LIKE" == *rhel* ]] || [[ "$ID_LIKE" == *fedora* ]]; then
            configure_dnf_os "${PRETTY_NAME}"
        elif [[ "$ID_LIKE" == *alpine* ]] || [[ "$OS_ID" == *alpine* ]]; then
            alpine_version_ok "${OS_VERSION:-3}" || fail "Alpine Linux 3.x+ required."
            configure_apk_os "${PRETTY_NAME:-Alpine Linux ${OS_VERSION:-}}"
        else
            fail "Unsupported OS: '$OS_ID'. Supported: Ubuntu 22+, Debian, Alpine 3.x+, AlmaLinux, Rocky, RHEL, CentOS, Fedora"
        fi
        ;;
esac

[[ "$OS_FAMILY" == "alpine" ]] && DOCKER_CGROUP_DRIVER="cgroupfs"

detail "Package mgr : $PKG_MANAGER"
detail "OS family   : $OS_FAMILY"

# ────────────────────────────────────────────────────────────────
# STEP 2 — System Update & Upgrade
# ────────────────────────────────────────────────────────────────
step 2 "$TOTAL_STEPS" "System Update & Upgrade"

if [[ "$PKG_MANAGER" == "apt" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    info "Running apt update..."
    apt-get update -qq
    ok "Package lists refreshed"
    info "Running apt upgrade (this may take a while)..."
    apt-get upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"
    ok "System packages upgraded successfully"

elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    info "Running dnf update (this may take a while)..."
    dnf update -y -q
    ok "System packages upgraded successfully"

    if [[ "$NEEDS_EPEL" == "true" ]]; then
        if ! dnf repolist 2>/dev/null | grep -qi "epel"; then
            info "Enabling EPEL repository..."
            dnf install -y -q epel-release
            ok "EPEL repository enabled"
        else
            skip "EPEL repository"
        fi
    else
        skip "EPEL (not required on $OS_DISPLAY)"
    fi

elif [[ "$PKG_MANAGER" == "apk" ]]; then
    enable_apk_community_repo
    info "Running apk update..."
    apk update
    ok "Package index refreshed"
    info "Running apk upgrade (this may take a while)..."
    apk upgrade -a
    ok "System packages upgraded successfully"
fi

# ────────────────────────────────────────────────────────────────
# STEP 3 — Essential Packages
# ────────────────────────────────────────────────────────────────
step 3 "$TOTAL_STEPS" "Essential Packages"

if [[ "$PKG_MANAGER" == "apt" ]]; then
    PKGS=(
        curl wget git ufw fail2ban iptables ipset
        unattended-upgrades
        ca-certificates gnupg lsb-release
        htop net-tools make build-essential
    )
    TO_INSTALL=()
    for pkg in "${PKGS[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            skip "${GREEN}${pkg}${RESET}"
        else
            info "queued: ${HACK_WARN}${pkg}${RESET}"
            TO_INSTALL+=("$pkg")
        fi
    done
    if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
        echo ""
        info "installing ${HACK_WARN}${#TO_INSTALL[@]}${RESET} package(s)..."
        apt-get install -y -qq "${TO_INSTALL[@]}"
        ok "All packages installed"
    else
        ok "All essential packages already present"
    fi

elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    PKGS=(
        curl wget git fail2ban dnf-automatic iptables ipset
        ca-certificates gnupg2
        htop net-tools make gcc gcc-c++
        firewalld dnf-plugins-core
        policycoreutils-python-utils
    )
    TO_INSTALL=()
    for pkg in "${PKGS[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            skip "${GREEN}${pkg}${RESET}"
        else
            info "queued: ${HACK_WARN}${pkg}${RESET}"
            TO_INSTALL+=("$pkg")
        fi
    done
    if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
        echo ""
        info "installing ${HACK_WARN}${#TO_INSTALL[@]}${RESET} package(s)..."
        dnf install -y -q "${TO_INSTALL[@]}"
        ok "All packages installed"
    else
        ok "All essential packages already present"
    fi

elif [[ "$PKG_MANAGER" == "apk" ]]; then
    PKGS=(
        bash curl wget git fail2ban iptables ipset linux-pam
        iptables-legacy
        ca-certificates htop net-tools make gcc musl-dev linux-headers
        grep tzdata openssh openssl dcron
    )
    TO_INSTALL=()
    for pkg in "${PKGS[@]}"; do
        if apk info -e "$pkg" &>/dev/null; then
            skip "${GREEN}${pkg}${RESET}"
        else
            info "queued: ${HACK_WARN}${pkg}${RESET}"
            TO_INSTALL+=("$pkg")
        fi
    done
    if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
        echo ""
        info "installing ${HACK_WARN}${#TO_INSTALL[@]}${RESET} package(s)..."
        apk add --no-cache "${TO_INSTALL[@]}"
        ok "All packages installed"
    else
        ok "All essential packages already present"
    fi
fi

# ────────────────────────────────────────────────────────────────
# STEP 4 — Docker & Docker Compose
# ────────────────────────────────────────────────────────────────
step 4 "$TOTAL_STEPS" "Docker Engine & Docker Compose"

rhel_docker_journal_tail() {
    journalctl -u docker.service -n 20 --no-pager 2>/dev/null | tail -10 || true
}

# Required netfilter modules for the Docker bridge/NAT driver (EL family)
DOCKER_NF_MODULES=(overlay br_netfilter nf_conntrack nf_nat xt_addrtype xt_conntrack xt_nat)
DOCKER_NEEDS_REBOOT="${DOCKER_NEEDS_REBOOT:-false}"

prepare_docker_dnf_host() {
    info "Preparing RHEL-family host for Docker..."
    local kver
    kver=$(uname -r)

    rpm -q iptables-nft &>/dev/null || dnf install -y -q iptables-nft 2>/dev/null || true

    # xt_addrtype / xt_conntrack live in kernel-modules-extra and MUST match the
    # running kernel. A prior `dnf update` may have installed a newer kernel, so
    # pin the package to $(uname -r); otherwise modprobe fails until reboot.
    if ! rpm -q "kernel-modules-extra-${kver}" &>/dev/null; then
        info "Installing kernel-modules-extra for running kernel ${kver}..."
        dnf install -y -q "kernel-modules-extra-${kver}" 2>/dev/null \
            || dnf install -y -q kernel-modules-extra 2>/dev/null \
            || warn "Could not install kernel-modules-extra for ${kver}"
    fi

    for _m in "${DOCKER_NF_MODULES[@]}"; do
        modprobe "$_m" 2>/dev/null || true
    done

    # Verify the critical module is actually loadable on the running kernel.
    if ! lsmod | grep -q '^xt_addrtype' && ! modprobe xt_addrtype 2>/dev/null; then
        DOCKER_NEEDS_REBOOT=true
        warn "xt_addrtype not available for running kernel ${kver}"
        if rpm -q kernel 2>/dev/null | grep -qv "$kver"; then
            warn "A newer kernel is installed — REBOOT required before Docker can start"
        fi
    fi

    {
        printf '%s\n' "${DOCKER_NF_MODULES[@]}"
    } > /etc/modules-load.d/rahmat-docker.conf
    cat > /etc/sysctl.d/99-rahmat-docker-bridge.conf << 'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl -p /etc/sysctl.d/99-rahmat-docker-bridge.conf > /dev/null 2>&1 || true

    systemctl enable containerd > /dev/null 2>&1 || true
    systemctl start containerd > /dev/null 2>&1 || true
    ok "Docker host prerequisites applied (containerd, iptables, kernel modules)"
}

ensure_docker_running() {
    svc_daemon_reload
    systemctl enable docker > /dev/null 2>&1 || true
    systemctl start containerd > /dev/null 2>&1 || true

    if systemctl start docker 2>/dev/null && systemctl is-active --quiet docker; then
        ok "Docker service enabled & started"
        return 0
    fi

    warn "Docker failed to start — running AlmaLinux/RHEL recovery..."
    prepare_docker_dnf_host
    systemctl restart containerd 2>/dev/null || true
    sleep 1
    systemctl restart docker 2>/dev/null || true
    sleep 3

    if systemctl is-active --quiet docker; then
        ok "Docker service started after recovery"
        return 0
    fi

    if [[ "$DOCKER_NEEDS_REBOOT" == "true" ]]; then
        echo ""
        warn "Docker cannot start until the host reboots into the updated kernel."
        warn "Required netfilter modules (xt_addrtype/xt_conntrack) are missing for"
        warn "the running kernel ($(uname -r)) but present for the installed kernel."
        detail "Fix: ${BOLD}reboot${RESET} → Docker will start automatically (enabled)"
        return 1
    fi

    echo ""
    warn "docker.service still failing — recent journal:"
    rhel_docker_journal_tail | while read -r _line; do
        [[ -n "$_line" ]] && detail "  $_line"
    done
    warn "Full log: journalctl -xeu docker.service"
    return 1
}

# cgroupv2 + overlay2 — AlmaLinux and Ubuntu 22+ compatible
apply_docker_daemon_config() {
    info "Writing /etc/docker/daemon.json..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=${DOCKER_CGROUP_DRIVER}"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "${DOCKER_LOG_MAX_SIZE}",
    "max-file": "${DOCKER_LOG_MAX_FILE}"
  },
  "storage-driver": "${DOCKER_STORAGE_DRIVER}"
}
EOF
    ok "daemon.json written (${DOCKER_CGROUP_DRIVER}, log ${DOCKER_LOG_MAX_SIZE}×${DOCKER_LOG_MAX_FILE})"
}

install_docker_apt() {
    info "Adding Docker official GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${DOCKER_APT_ID}/gpg" \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    ok "GPG key saved"

    info "Adding Docker apt repository (${DOCKER_APT_ID}/${DOCKER_APT_SUITE})..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/${DOCKER_APT_ID} ${DOCKER_APT_SUITE} stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    ok "Repository configured"

    info "Installing Docker CE + plugins..."
    if ! apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin; then
        warn "Install failed for suite '${DOCKER_APT_SUITE}' — retrying with fallback..."
        local fallback
        fallback=$([[ "$DOCKER_APT_ID" == "ubuntu" ]] && echo "noble" || echo "bookworm")
        [[ "$fallback" == "$DOCKER_APT_SUITE" ]] && fail "Docker packages unavailable for ${PRETTY_NAME}"
        sed -i "s/ ${DOCKER_APT_SUITE} / ${fallback} /" /etc/apt/sources.list.d/docker.list
        DOCKER_APT_SUITE="$fallback"
        apt-get update -qq
        apt-get install -y -qq \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        ok "Docker packages installed (fallback suite: ${fallback})"
    else
        ok "Docker packages installed"
    fi

    apply_docker_daemon_config

    systemctl daemon-reload
    systemctl enable --now docker
    ok "Docker service enabled & started"
}

install_docker_dnf() {
    info "Adding Docker official DNF repository..."
    dnf config-manager --add-repo "$DOCKER_DNF_REPO" -q
    ok "Repository configured"

    prepare_docker_dnf_host

    info "Installing Docker CE + plugins..."
    dnf install -y -q \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    ok "Docker packages installed"

    apply_docker_daemon_config
    ensure_docker_running || true
}

install_docker_apk() {
    enable_apk_community_repo
    prepare_alpine_netfilter
    info "Installing Docker from Alpine repositories..."
    apk add --no-cache docker docker-cli docker-cli-compose containerd
    ok "Docker packages installed"

    apply_docker_daemon_config

    svc_enable_now containerd
    svc_enable_now docker
    sleep 2
    if ! svc_is_active docker; then
        warn "Docker not active after first start, restarting..."
        svc_restart docker
        sleep 3
    fi

    if wait_for_docker; then
        ok "Docker service enabled & started"
    elif svc_is_active docker; then
        warn "Docker service running but API not ready — check: tail /var/log/docker.log"
    else
        warn "Docker service may have issues — check: rc-service docker status; tail /var/log/docker.log"
    fi
}

upgrade_docker_apt() {
    apt-get install -y -qq --only-upgrade \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
}

upgrade_docker_dnf() {
    dnf upgrade -y -q \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
}

upgrade_docker_apk() {
    apk upgrade --available docker docker-cli docker-cli-compose containerd 2>/dev/null || true
}

if command -v docker &>/dev/null; then
    OLD_VER=$(docker --version | extract_semver)
    info "docker found (${HACK_WARN}v${OLD_VER}${RESET}) — checking for upgrades..."
    case "$PKG_MANAGER" in
        apt) upgrade_docker_apt ;;
        apk) upgrade_docker_apk ;;
        *)   upgrade_docker_dnf ;;
    esac
    NEW_VER=$(docker --version | extract_semver)
    if [[ "$OLD_VER" != "$NEW_VER" ]]; then
        ok "docker upgraded: ${HACK_WARN}v${OLD_VER}${RESET} → ${HACK}v${NEW_VER}${RESET}"
    else
        ok "Docker is up-to-date: ${BGREEN}v${NEW_VER}${RESET}"
    fi

    if [[ ! -f /etc/docker/daemon.json ]]; then
        apply_docker_daemon_config
        svc_daemon_reload
        svc_restart docker
        sleep 2
        ok "daemon.json applied & Docker restarted"
    else
        skip "daemon.json already exists"
    fi

    if ! docker info &>/dev/null 2>&1; then
        case "$PKG_MANAGER" in
            dnf)
                warn "Docker daemon not responding — retrying with EL host recovery..."
                prepare_docker_dnf_host
                svc_daemon_reload
                ensure_docker_running || true
                ;;
            apk)
                warn "Docker daemon not responding — retrying with Alpine netfilter recovery..."
                prepare_alpine_netfilter
                svc_enable_now containerd
                svc_restart docker
                wait_for_docker || warn "Docker still not responding — check /var/log/docker.log"
                ;;
        esac
    fi
else
    case "$PKG_MANAGER" in
        apt) install_docker_apt ;;
        apk) install_docker_apk ;;
        *)   install_docker_dnf ;;
    esac
fi

if docker compose version &>/dev/null 2>&1; then
    DC_VER=$(docker compose version --short 2>/dev/null || echo "installed")
    ok "Docker Compose plugin: ${BGREEN}v${DC_VER}${RESET}"
else
    warn "Docker Compose plugin not available"
fi

if docker info &>/dev/null 2>&1; then
    detail "Storage driver  : $(docker info --format '{{.Driver}}')"
    detail "Cgroup driver   : $(docker info --format '{{.CgroupDriver}}')"
    detail "Docker root     : $(docker info --format '{{.DockerRootDir}}')"
else
    warn "Docker info not available — service may still be starting"
fi

# ────────────────────────────────────────────────────────────────
# STEP 5 — Timezone
# ────────────────────────────────────────────────────────────────
step 5 "$TOTAL_STEPS" "Timezone Configuration"

CURRENT_TZ=$(get_timezone)
if [[ "$CURRENT_TZ" == "$TIMEZONE" ]]; then
    ok "Timezone already ${BGREEN}${TIMEZONE}${RESET}"
else
    info "changing tz: ${HACK_WARN}${CURRENT_TZ}${RESET} → ${HACK}${TIMEZONE}${RESET}"
    set_system_timezone
    ok "Timezone set to ${BGREEN}${TIMEZONE}${RESET}"
fi
detail "Local time : $(date '+%A, %d %B %Y  %H:%M:%S %Z')"

# ────────────────────────────────────────────────────────────────
# STEP 6 — Swap & File Descriptor Limits
# ────────────────────────────────────────────────────────────────
step 6 "$TOTAL_STEPS" "Swap & File Descriptor Limits"

LIMITS_FILE="/etc/security/limits.d/99-rahmat-dns.conf"
cat > "$LIMITS_FILE" << EOF
# RAHMAT — DNS / DoT workload limits (from .env)
*               soft    nofile          ${LIMIT_NOFILE}
*               hard    nofile          ${LIMIT_NOFILE}
root            soft    nofile          ${LIMIT_NOFILE}
root            hard    nofile          ${LIMIT_NOFILE}
*               soft    nproc           ${LIMIT_NPROC}
*               hard    nproc           ${LIMIT_NPROC}
EOF
ok "limits.conf → ${LIMITS_FILE}"
detail "nofile max : ${LIMIT_NOFILE} (DNS/DoT sockets)"

SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
if [[ "$SWAP_TOTAL" -gt 0 ]]; then
    ok "Swap already configured ($(numfmt --to=iec $((SWAP_TOTAL * 1024)) 2>/dev/null || echo "${SWAP_TOTAL}KB"))"
else
    SWAP_GB="${SWAP_SIZE_GB}"
    if [[ "$SWAP_ENABLED" != "true" ]]; then
        warn "Swap disabled in .env (SWAP_ENABLED=false)"
        SWAP_GB=""
    elif is_interactive; then
        ask_line "No swap detected. Create ${SWAP_SIZE_GB}GB swapfile at ${SWAP_FILE}? [Y/n] (or enter size GB):" SWAP_ANS
        if [[ -z "$SWAP_ANS" || "$SWAP_ANS" =~ ^[Yy]$ ]]; then
            SWAP_GB="${SWAP_SIZE_GB}"
        elif [[ "$SWAP_ANS" =~ ^[0-9]+$ ]]; then
            SWAP_GB="$SWAP_ANS"
        elif [[ "$SWAP_ANS" =~ ^[Nn] ]]; then
            warn "Swap creation skipped"
            SWAP_GB=""
        fi
    fi
    if [[ -n "$SWAP_GB" ]]; then
        info "Creating ${SWAP_GB}G swapfile at ${SWAP_FILE}..."
        fallocate -l "${SWAP_GB}G" "$SWAP_FILE" 2>/dev/null || \
            dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_GB * 1024)) status=progress
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE" > /dev/null
        swapon "$SWAP_FILE"
        grep -q "$SWAP_FILE" /etc/fstab || echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab
        ok "Swapfile ${SWAP_GB}G active → ${SWAP_FILE}"
    fi
fi

# ────────────────────────────────────────────────────────────────
# STEP 7 — Kernel Tuning (DNS 53 / DoT 853)
# ────────────────────────────────────────────────────────────────
step 7 "$TOTAL_STEPS" "Kernel Tuning — DNS 53 udp/tcp · DoT 853"

SYSCTL_FILE="/etc/sysctl.d/99-rahmat-dns.conf"
SYSTEMD_DNS="/etc/systemd/system.conf.d/99-rahmat-dns.conf"

cat > "$SYSCTL_FILE" << EOF
# RAHMAT — DNS (53 udp/tcp) + DoT (853 tcp) — from .env

net.core.rmem_max            = 33554432
net.core.wmem_max            = 33554432
net.core.rmem_default        = 1048576
net.core.wmem_default        = 1048576
net.core.optmem_max          = 65536
net.core.netdev_max_backlog  = ${SYSCTL_NETDEV_MAX_BACKLOG}
net.core.netdev_budget       = 600
net.core.netdev_budget_usecs = 8000
net.core.somaxconn           = ${SYSCTL_SOMAXCONN}

net.ipv4.udp_mem             = 65536 131072 262144
net.ipv4.udp_rmem_min        = ${SYSCTL_UDP_RMEM_MIN}
net.ipv4.udp_wmem_min        = ${SYSCTL_UDP_RMEM_MIN}

net.ipv4.tcp_rmem            = 4096 1048576 33554432
net.ipv4.tcp_wmem            = 4096 1048576 33554432
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_max_tw_buckets  = 2000000
net.ipv4.tcp_fin_timeout     = 10
net.ipv4.tcp_tw_reuse        = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fastopen        = 3
net.ipv4.tcp_keepalive_time  = 120
net.ipv4.tcp_keepalive_probes= 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_mtu_probing     = 1
net.ipv4.ip_local_port_range = 1024 65535

net.netfilter.nf_conntrack_max       = ${SYSCTL_CONNTRACK_MAX}
net.netfilter.nf_conntrack_udp_timeout         = 30
net.netfilter.nf_conntrack_udp_timeout_stream  = 60
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 30
net.netfilter.nf_conntrack_tcp_timeout_established = ${SYSCTL_CONNTRACK_TCP_ESTABLISHED}

net.ipv4.ip_forward          = 1
net.ipv4.icmp_echo_ignore_all        = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
vm.swappiness                = ${SYSCTL_SWAPPINESS}
fs.file-max                  = ${SYSCTL_FILE_MAX}
fs.nr_open                   = ${SYSCTL_FILE_MAX}
EOF

modprobe nf_conntrack 2>/dev/null || true
cat > /etc/modules-load.d/rahmat-dns.conf << 'EOF'
nf_conntrack
xt_hashlimit
xt_connlimit
xt_recent
EOF

info "Applying DNS/DoT sysctl parameters..."
while IFS= read -r _line; do
    [[ "$_line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${_line// }" ]] && continue
    sysctl -w "$_line" > /dev/null 2>&1 || true
done < "$SYSCTL_FILE"
sysctl -p "$SYSCTL_FILE" > /dev/null 2>&1 || true
ok "Kernel tuned for DNS 53 (udp/tcp) + DoT 853"

mkdir -p /etc/systemd/system.conf.d
if has_systemd; then
    cat > "$SYSTEMD_DNS" << EOF
# RAHMAT — systemd global limits (from .env)
[Manager]
DefaultLimitNOFILE=${LIMIT_NOFILE}:${LIMIT_NOFILE}
DefaultLimitNPROC=${LIMIT_NPROC}:${LIMIT_NPROC}
EOF
    svc_daemon_reload
    ok "systemd limits → ${SYSTEMD_DNS}"
else
    skip "systemd limits not applicable (OpenRC / non-systemd)"
fi

detail "Config file    : $SYSCTL_FILE"
detail "UDP rmem_min   : $(sysctl -n net.ipv4.udp_rmem_min 2>/dev/null || echo n/a)"
detail "TCP syn_backlog: $(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo n/a)"
detail "netdev_backlog : $(sysctl -n net.core.netdev_max_backlog 2>/dev/null || echo n/a)"
detail "conntrack_max  : $(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo n/a)"
detail "fs.file-max    : $(sysctl -n fs.file-max 2>/dev/null || echo n/a)"
detail "Port targets   : 53/udp 53/tcp 853/tcp"

# ────────────────────────────────────────────────────────────────
# STEP 8 — Firewall
# ────────────────────────────────────────────────────────────────
step 8 "$TOTAL_STEPS" "Firewall Rules"

open_port_ufw() {
    local port="$1" label="$2"
    ufw allow "$port" > /dev/null
    local proto num
    proto=$(echo "$port" | cut -d/ -f2 | tr '[:lower:]' '[:upper:]')
    num=$(echo "$port" | cut -d/ -f1)
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}${num}${RESET}/${HACK}${proto}${RESET}   ${HACK_DIM}::${RESET} ${WHITE}${label}${RESET}"
}

open_port_firewalld() {
    local port="$1" label="$2"
    firewall-cmd --permanent --add-port="${port}" > /dev/null 2>&1
    local proto num
    proto=$(echo "$port" | cut -d/ -f2 | tr '[:lower:]' '[:upper:]')
    num=$(echo "$port" | cut -d/ -f1)
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}${num}${RESET}/${HACK}${proto}${RESET}   ${HACK_DIM}::${RESET} ${WHITE}${label}${RESET}"
}

if [[ "$PKG_MANAGER" == "apt" ]]; then
    info "Configuring UFW..."
    command -v ufw &>/dev/null || apt-get install -y -qq ufw
    ufw --force reset > /dev/null 2>&1
    ufw default deny incoming  > /dev/null
    ufw default allow outgoing > /dev/null
    ok "Default policy → ${BRED}DENY${RESET} incoming / ${BGREEN}ALLOW${RESET} outgoing"
    echo ""
    open_port_ufw "53/udp"  "DNS — Plain UDP (primary)"
    open_port_ufw "53/tcp"  "DNS — Plain TCP (fallback)"
    open_port_ufw "853/tcp" "DoT — DNS-over-TLS"
    ufw limit 22/tcp > /dev/null 2>&1 || ufw allow 22/tcp > /dev/null
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}22${RESET}/${HACK}TCP${RESET}   ${HACK_DIM}::${RESET} ${WHITE}SSH — rate limited (DDoS)${RESET}"
    open_port_ufw "80/tcp"  "HTTP — ACME / Certificate Renewal"
    open_port_ufw "443/tcp" "HTTPS — DoH (DNS-over-HTTPS)"
    ufw deny in proto icmp > /dev/null 2>&1 || true
    ok "ICMP ping blocked (UFW + sysctl)"
    echo ""
    ufw --force enable > /dev/null
    ok "UFW firewall ${BGREEN}enabled${RESET}"

elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    info "Configuring firewalld..."
    systemctl enable --now firewalld > /dev/null 2>&1
    ok "Default policy → ${BRED}DENY${RESET} incoming / ${BGREEN}ALLOW${RESET} outgoing"
    echo ""
    open_port_firewalld "53/udp"  "DNS — Plain UDP (primary)"
    open_port_firewalld "53/tcp"  "DNS — Plain TCP (fallback)"
    open_port_firewalld "853/tcp" "DoT — DNS-over-TLS"
    open_port_firewalld "22/tcp"  "SSH — Admin Access (restricted in phase 09)"
    open_port_firewalld "80/tcp"  "HTTP — ACME / Certificate Renewal"
    open_port_firewalld "443/tcp" "HTTPS — DoH (DNS-over-HTTPS)"
    firewall-cmd --permanent --add-icmp-block=echo-request > /dev/null 2>&1 || true
    ok "ICMP ping blocked (firewalld + sysctl)"
    echo ""
    firewall-cmd --reload > /dev/null 2>&1
    ok "firewalld ${BGREEN}reloaded & active${RESET}"

elif [[ "$PKG_MANAGER" == "apk" ]]; then
    ALPINE_FW="/etc/rahmat/apply-alpine-firewall.sh"
    info "Configuring Alpine iptables firewall..."
    prepare_alpine_netfilter
    mkdir -p /etc/rahmat /etc/iptables

    cat > "$ALPINE_FW" << 'EOFALPINE'
#!/bin/sh
# RAHMAT — Alpine base iptables (DDoS chain applied separately)
IPT="${IPTABLES:-iptables-legacy}"
command -v "$IPT" >/dev/null 2>&1 || IPT=iptables

$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

$IPT -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    $IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPT -C INPUT -i lo -j ACCEPT 2>/dev/null || $IPT -A INPUT -i lo -j ACCEPT

for _spec in "53 udp" "53 tcp" "853 tcp" "80 tcp" "443 tcp"; do
    _p="${_spec%% *}"
    _pr="${_spec##* }"
    $IPT -C INPUT -p "$_pr" --dport "$_p" -j ACCEPT 2>/dev/null || \
        $IPT -A INPUT -p "$_pr" --dport "$_p" -j ACCEPT
done

$IPT -C INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --name SSH --set 2>/dev/null || \
    $IPT -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --name SSH --set
$IPT -C INPUT -p tcp --dport 22 -m recent --name SSH --update --seconds 60 --hitcount 4 -j DROP 2>/dev/null || \
    $IPT -A INPUT -p tcp --dport 22 -m recent --name SSH --update --seconds 60 --hitcount 4 -j DROP
$IPT -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
    $IPT -A INPUT -p tcp --dport 22 -j ACCEPT

$IPT -C INPUT -p icmp --icmp-type echo-request -j DROP 2>/dev/null || \
    $IPT -A INPUT -p icmp --icmp-type echo-request -j DROP
EOFALPINE
    chmod +x "$ALPINE_FW"
    if ! IPTABLES="${ALPINE_IPT}" sh "$ALPINE_FW"; then
        warn "Alpine firewall rules failed — check ${ALPINE_IPT} and kernel modules"
    fi
    alpine_iptables_save
    rc-update add iptables-legacy boot 2>/dev/null || rc-update add iptables boot 2>/dev/null || true

    ok "Default policy → ${BRED}DENY${RESET} incoming / ${BGREEN}ALLOW${RESET} outgoing"
    echo ""
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}53${RESET}/${HACK}UDP${RESET}   ${HACK_DIM}::${RESET} ${WHITE}DNS — Plain UDP (primary)${RESET}"
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}53${RESET}/${HACK}TCP${RESET}   ${HACK_DIM}::${RESET} ${WHITE}DNS — Plain TCP (fallback)${RESET}"
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}853${RESET}/${HACK}TCP${RESET}   ${HACK_DIM}::${RESET} ${WHITE}DoT — DNS-over-TLS${RESET}"
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}22${RESET}/${HACK}TCP${RESET}   ${HACK_DIM}::${RESET} ${WHITE}SSH — rate limited (DDoS)${RESET}"
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}80${RESET}/${HACK}TCP${RESET}   ${HACK_DIM}::${RESET} ${WHITE}HTTP — ACME / Certificate Renewal${RESET}"
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}443${RESET}/${HACK}TCP${RESET}   ${HACK_DIM}::${RESET} ${WHITE}HTTPS — DoH (DNS-over-HTTPS)${RESET}"
    ok "ICMP ping blocked (iptables + sysctl)"
    echo ""
    ok "Alpine iptables firewall ${BGREEN}active${RESET}"
fi

# ────────────────────────────────────────────────────────────────
# STEP 9 — DDoS Protection
# ────────────────────────────────────────────────────────────────
step 9 "$TOTAL_STEPS" "DDoS Protection (DNS / DoT / SYN flood)"

DDOS_SCRIPT="/etc/rahmat/apply-ddos-rules.sh"
DDOS_CONF="/etc/rahmat/ddos.conf"

info "Loading DDoS kernel modules..."
[[ "$OS_FAMILY" == "alpine" ]] && prepare_alpine_netfilter
modprobe xt_hashlimit 2>/dev/null || true
modprobe xt_connlimit 2>/dev/null || true
modprobe xt_recent   2>/dev/null || true

apply_ddos_kernel

info "Installing per-IP rate limits (53 udp/tcp · 853 · 443)..."
install_ddos_script

if [[ "$PKG_MANAGER" == "dnf" ]]; then
    apply_ddos_firewalld
    ok "firewalld DDoS passthrough rules applied"
fi

ok "DDoS protection active"
detail "Config        : ${DDOS_CONF}"
detail "Script        : ${DDOS_SCRIPT}"
detail "Service       : rahmat-ddos.service"
detail "DNS UDP limit : 300 qps/IP (burst 600)"
detail "DNS TCP limit : 50 conn/sec/IP (max 30 concurrent)"
detail "DoT 853 limit : ${DOT_RATE}/IP (burst ${DOT_BURST}, max ${DOT_CONN_MAX} concurrent)"
detail "DoT profile   : from .env (mobile / CGNAT)"
detail "DoH 443 limit : ${DOH_RATE}/IP"
detail "SYN global    : ${SYN_RATE} (burst ${SYN_BURST})"
detail "SYN cookies   : $(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo 1)"
detail "Tune all      : edit ${ENV_FILE} or /etc/rahmat/.env → re-run setup.sh"
detail "DDoS reload   : $(has_systemd && echo 'systemctl restart rahmat-ddos' || echo '/etc/rahmat/apply-ddos-rules.sh')"

# ────────────────────────────────────────────────────────────────
# STEP 10 — SSH Hardening, Keys & IP Whitelist
# ────────────────────────────────────────────────────────────────
step 10 "$TOTAL_STEPS" "SSH Hardening, Keys & IP Whitelist"

SSHD_DROPIN="/etc/ssh/sshd_config.d/99-rahmat.conf"
SSH_USER="${SSH_USER:-root}"
SSH_PUBKEY="${SSH_PUBLIC_KEY:-}"

if is_interactive; then
    ask_line "SSH user for key auth [${SSH_USER}]:" SSH_USER_INPUT
    [[ -n "$SSH_USER_INPUT" ]] && SSH_USER="$SSH_USER_INPUT"
fi
SSH_HOME=$(getent passwd "$SSH_USER" | cut -d: -f6)
[[ -n "$SSH_HOME" ]] || fail "SSH user '$SSH_USER' not found"

if [[ -z "$SSH_PUBKEY" ]] && is_interactive; then
    ask_line "Paste SSH public key (Enter to skip):" SSH_PUBKEY
fi
if [[ -n "$SSH_PUBKEY" ]]; then
    if valid_ssh_pubkey "$SSH_PUBKEY"; then
        install -d -m 700 -o "$SSH_USER" -g "$SSH_USER" "${SSH_HOME}/.ssh"
        AUTH_KEYS="${SSH_HOME}/.ssh/authorized_keys"
        touch "$AUTH_KEYS"
        chown "$SSH_USER:$SSH_USER" "$AUTH_KEYS"
        chmod 600 "$AUTH_KEYS"
        if grep -qF "${SSH_PUBKEY%% *}" "$AUTH_KEYS" 2>/dev/null; then
            skip "SSH public key already in authorized_keys"
        else
            echo "$SSH_PUBKEY" >> "$AUTH_KEYS"
            ok "SSH public key installed for ${SSH_USER}"
        fi
    else
        warn "Invalid SSH public key format — skipped"
        SSH_PUBKEY=""
    fi
else
    warn "No SSH key provided — password auth will remain enabled"
fi

WHITELIST_INPUT="${SSH_WHITELIST_IPS:-}"
if [[ -z "$WHITELIST_INPUT" ]] && is_interactive; then
    ask_line "SSH allowed IPs/CIDRs, comma-separated (Enter = any):" WHITELIST_INPUT
fi
if [[ -n "$WHITELIST_INPUT" ]]; then
    IFS=',' read -ra _wl_parts <<< "$WHITELIST_INPUT"
    for ip in "${_wl_parts[@]}"; do
        ip="${ip// /}"
        [[ -z "$ip" ]] && continue
        if valid_ip_or_cidr "$ip"; then
            SSH_WHITELIST+=("$ip")
        else
            warn "Invalid IP/CIDR skipped: $ip"
        fi
    done
fi

if [[ ${#SSH_WHITELIST[@]} -gt 0 ]]; then
    detail "SSH whitelist: ${SSH_WHITELIST[*]}"
    if [[ -n "$CURRENT_SSH_IP" ]]; then
        _wl_ok=false
        for ip in "${SSH_WHITELIST[@]}"; do
            [[ "$ip" == "$CURRENT_SSH_IP" || "$ip" == "${CURRENT_SSH_IP}/32" ]] && _wl_ok=true
        done
        $_wl_ok || warn "Current session IP ${CURRENT_SSH_IP} NOT in whitelist — verify before disconnect!"
    fi
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        ufw delete allow 22/tcp > /dev/null 2>&1 || true
        for ip in "${SSH_WHITELIST[@]}"; do
            ufw allow from "$ip" to any port 22 proto tcp > /dev/null
            detail "UFW allow SSH from $ip"
        done
    elif [[ "$PKG_MANAGER" == "apk" ]]; then
        _alpine_ipt="${ALPINE_IPT:-iptables-legacy}"
        $_alpine_ipt -D INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
        $_alpine_ipt -D INPUT -p tcp --dport 22 -m recent --name SSH --update --seconds 60 --hitcount 4 -j DROP 2>/dev/null || true
        $_alpine_ipt -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --name SSH --set 2>/dev/null || true
        for ip in "${SSH_WHITELIST[@]}"; do
            $_alpine_ipt -I INPUT -p tcp -s "$ip" --dport 22 -j ACCEPT
            detail "iptables allow SSH from $ip"
        done
        alpine_iptables_save
    else
        firewall-cmd --permanent --remove-port=22/tcp > /dev/null 2>&1 || true
        for ip in "${SSH_WHITELIST[@]}"; do
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${ip}' port port='22' protocol='tcp' accept" > /dev/null 2>&1
            detail "firewalld allow SSH from $ip"
        done
        firewall-cmd --reload > /dev/null 2>&1
    fi
    ok "SSH restricted to ${#SSH_WHITELIST[@]} IP/CIDR rule(s)"
else
    ok "SSH open on port 22 (no whitelist configured)"
fi

DISABLE_PASSWORD="no"
if [[ "$SSH_DISABLE_PASSWORD" == "yes" ]]; then
    DISABLE_PASSWORD="yes"
elif [[ "$SSH_DISABLE_PASSWORD" == "no" ]]; then
    DISABLE_PASSWORD="no"
elif [[ -n "$SSH_PUBKEY" ]]; then
    DISABLE_PASSWORD="yes"
fi

if [[ "$SSH_USER" == "root" ]]; then
    ROOT_LOGIN="prohibit-password"
else
    ROOT_LOGIN="no"
fi

cat > "$SSHD_DROPIN" << EOF
# RAHMAT — SSH hardening (from .env)
Port ${SSH_PORT}
PermitRootLogin ${ROOT_LOGIN}
PubkeyAuthentication yes
PasswordAuthentication ${DISABLE_PASSWORD}
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
MaxAuthTries ${SSH_MAX_AUTH_TRIES}
LoginGraceTime ${SSH_LOGIN_GRACE_TIME}
ClientAliveInterval ${SSH_CLIENT_ALIVE_INTERVAL}
ClientAliveCountMax ${SSH_CLIENT_ALIVE_COUNT_MAX}
AllowUsers ${SSH_USER}
EOF

sshd_test_and_reload
ok "SSH hardening applied → ${SSHD_DROPIN}"
detail "Password auth : ${DISABLE_PASSWORD}"
detail "AllowUsers    : ${SSH_USER}"

# ────────────────────────────────────────────────────────────────
# STEP 11 — Fail2Ban Jails
# ────────────────────────────────────────────────────────────────
step 11 "$TOTAL_STEPS" "Fail2Ban Jail Configuration"

F2B_JAIL="/etc/fail2ban/jail.d/rahmat.local"
mkdir -p /etc/fail2ban/jail.d

if [[ "$PKG_MANAGER" == "apt" ]]; then
    F2B_BANACTION="ufw"
    F2B_BACKEND="systemd"
elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    F2B_BANACTION="firewallcmd-rich-rules"
    F2B_BACKEND="systemd"
else
    F2B_BANACTION="iptables-multiport"
    F2B_BACKEND="auto"
fi

cat > "$F2B_JAIL" << EOF
# RAHMAT — Fail2Ban jails (from .env)
[DEFAULT]
bantime  = ${F2B_DEFAULT_BANTIME}
findtime = ${F2B_DEFAULT_FINDTIME}
maxretry = ${F2B_DEFAULT_MAXRETRY}
banaction = ${F2B_BANACTION}
backend = ${F2B_BACKEND}

[sshd]
enabled  = true
port     = ssh
filter   = sshd
mode     = ${F2B_SSHD_MODE}
maxretry = ${F2B_SSHD_MAXRETRY}
bantime  = ${F2B_SSHD_BANTIME}
findtime = ${F2B_SSHD_FINDTIME}

[recidive]
enabled  = true
logpath  = /var/log/fail2ban.log
filter   = recidive
maxretry = ${F2B_RECIDIVE_MAXRETRY}
bantime  = ${F2B_RECIDIVE_BANTIME}
findtime = ${F2B_RECIDIVE_FINDTIME}
EOF

svc_enable_now fail2ban
svc_restart fail2ban
ok "Fail2Ban jails configured → ${F2B_JAIL}"
detail "sshd bantime  : 24h (86400s)"
detail "recidive      : 7d ban on repeat offenders"

# ────────────────────────────────────────────────────────────────
# STEP 12 — SELinux Tuning (RHEL family)
# ────────────────────────────────────────────────────────────────
step 12 "$TOTAL_STEPS" "SELinux Tuning"

if [[ "$OS_FAMILY" == "rhel" ]] && command -v getenforce &>/dev/null; then
    SEL_MODE=$(getenforce 2>/dev/null || echo "Disabled")
    detail "Current mode : ${SEL_MODE}"

    if [[ "$SEL_MODE" != "Disabled" ]]; then
        info "Applying SELinux booleans & port contexts..."
        setsebool -P container_manage_cgroup on 2>/dev/null || true
        setsebool -P domain_can_tcp_connect_dnsport on 2>/dev/null || true
        setsebool -P nis_enabled off 2>/dev/null || true

        for _port_spec in "tcp 53" "udp 53" "tcp 853"; do
            _proto="${_port_spec%% *}"
            _port="${_port_spec##* }"
            semanage port -a -t dns_port_t -p "$_proto" "$_port" 2>/dev/null || \
            semanage port -m -t dns_port_t -p "$_proto" "$_port" 2>/dev/null || true
        done

        if command -v docker &>/dev/null; then
            setsebool -P container_use_cephfs off 2>/dev/null || true
        fi

        ok "SELinux tuned for DNS + Docker workloads"
        detail "dns_port_t    : 53/tcp, 53/udp, 853/tcp"
        detail "booleans      : container_manage_cgroup, domain_can_tcp_connect_dnsport"
    else
        skip "SELinux disabled on this system"
    fi
else
    skip "SELinux tuning not applicable (${OS_FAMILY})"
fi

# ────────────────────────────────────────────────────────────────
# STEP 13 — Automatic Security Updates
# ────────────────────────────────────────────────────────────────
step 13 "$TOTAL_STEPS" "Automatic Security Updates"

if [[ "$PKG_MANAGER" == "apt" ]]; then
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]]; then
        sed -i 's|^//\s*"${distro_id}:${distro_codename}-security";|"${distro_id}:${distro_codename}-security";|' \
            /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true
    fi
    systemctl enable unattended-upgrades > /dev/null 2>&1 || true
    systemctl restart unattended-upgrades > /dev/null 2>&1 || true
    ok "unattended-upgrades enabled (Debian/Ubuntu)"
    detail "Config : /etc/apt/apt.conf.d/20auto-upgrades"

elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    command -v dnf-automatic &>/dev/null || dnf install -y -q dnf-automatic
    if [[ -f /etc/dnf/automatic.conf ]]; then
        sed -i 's/^apply_updates\s*=.*/apply_updates = yes/' /etc/dnf/automatic.conf
        sed -i 's/^upgrade_type\s*=.*/upgrade_type = security/' /etc/dnf/automatic.conf
        grep -q '^apply_updates' /etc/dnf/automatic.conf || echo 'apply_updates = yes' >> /etc/dnf/automatic.conf
        grep -q '^upgrade_type' /etc/dnf/automatic.conf || echo 'upgrade_type = security' >> /etc/dnf/automatic.conf
    fi
    systemctl enable --now dnf-automatic.timer > /dev/null 2>&1
    ok "dnf-automatic timer enabled (AlmaLinux/RHEL)"
    detail "Config : /etc/dnf/automatic.conf"
    detail "Type   : security updates only"

elif [[ "$PKG_MANAGER" == "apk" ]]; then
    command -v crond &>/dev/null || apk add --no-cache dcron
    cat > /etc/cron.d/rahmat-apk-upgrade << 'EOF'
# RAHMAT — daily Alpine security updates
0 3 * * * root /sbin/apk update && /sbin/apk upgrade --available
EOF
    chmod 644 /etc/cron.d/rahmat-apk-upgrade
    svc_enable_now crond
    ok "apk daily upgrade cron enabled (Alpine)"
    detail "Config : /etc/cron.d/rahmat-apk-upgrade"
    detail "Schedule: 03:00 daily"
fi

# ────────────────────────────────────────────────────────────────
# STEP 14 — Free Port 53
# ────────────────────────────────────────────────────────────────
step 14 "$TOTAL_STEPS" "Free Port 53"

if [[ "$PKG_MANAGER" == "apt" ]]; then
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        info "Stopping systemd-resolved..."
        systemctl disable --now systemd-resolved
        ok "systemd-resolved ${BRED}stopped & disabled${RESET}"
    else
        ok "systemd-resolved was already inactive"
    fi

    for svc in bind9 named; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            info "Stopping $svc..."
            systemctl disable --now "$svc"
            ok "$svc ${BRED}stopped & disabled${RESET}"
        fi
    done

elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    for svc in named dnsmasq; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            info "Stopping $svc..."
            systemctl disable --now "$svc"
            ok "$svc ${BRED}stopped & disabled${RESET}"
        else
            ok "$svc — already inactive"
        fi
    done
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        systemctl disable --now systemd-resolved
        ok "systemd-resolved stopped"
    fi

elif [[ "$PKG_MANAGER" == "apk" ]]; then
    for svc in unbound named bind dnsmasq; do
        if svc_is_active "$svc"; then
            info "Stopping $svc..."
            svc_disable_now "$svc"
            ok "$svc ${BRED}stopped & disabled${RESET}"
        else
            ok "$svc — already inactive"
        fi
    done
fi

if [[ -L /etc/resolv.conf ]]; then
    info "Replacing symlink /etc/resolv.conf..."
    rm -f /etc/resolv.conf
fi
cat > /etc/resolv.conf << EOF
# RAHMAT — Static DNS resolvers (from .env)
nameserver ${DNS_NAMESERVER_1}
nameserver ${DNS_NAMESERVER_2}
nameserver ${DNS_NAMESERVER_3}
EOF
ok "/etc/resolv.conf set to static nameservers"
detail "Nameservers : ${DNS_NAMESERVER_1} / ${DNS_NAMESERVER_2} / ${DNS_NAMESERVER_3}"

info "Verifying DNS/DoT ports are free for bind..."
for _spec in "53 udp" "53 tcp" "853 tcp"; do
    _p="${_spec%% *}"
    _pr="${_spec##* }"
    if port_is_bound "$_p" "$_pr"; then
        warn "Port ${_p}/${_pr} still bound — stop conflicting service before deploy"
    else
        ok "Port ${_p}/${_pr} free — ready for DNS/DoT"
    fi
done

# ════════════════════════════════════════════════════════════════
# MISSION REPORT
# ════════════════════════════════════════════════════════════════
echo ""
echo ""
echo -e "${BG_HACK}                                                      ${RESET}"
echo -e "${BG_HACK}   [+] MISSION COMPLETE :: NODE READY FOR DEPLOY       ${RESET}"
echo -e "${BG_HACK}                                                      ${RESET}"
echo ""

# ── System ──────────────────────────────────────────────────────
echo -e "  ${HACK}╔══[SYS] TARGET PROFILE ════════════════════════════╗${RESET}"
echo -e "  ${HACK}║${RESET}  OS         ${HACK_DIM}:${RESET}  ${BWHITE}${PRETTY_NAME}${RESET}"
echo -e "  ${HACK}║${RESET}  Kernel     ${HACK_DIM}:${RESET}  ${BWHITE}$(uname -r)${RESET}"
echo -e "  ${HACK}║${RESET}  Arch       ${HACK_DIM}:${RESET}  ${BWHITE}$(uname -m)${RESET}"
echo -e "  ${HACK}║${RESET}  Family     ${HACK_DIM}:${RESET}  ${BWHITE}${OS_FAMILY} (${PKG_MANAGER})${RESET}"
echo -e "  ${HACK}║${RESET}  Timezone   ${HACK_DIM}:${RESET}  ${BWHITE}$(get_timezone)${RESET}  ${HACK_DIM}@ $(date '+%H:%M:%S')${RESET}"
echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Tools ───────────────────────────────────────────────────────
echo -e "  ${HACK}╔══[BIN] TOOLCHAIN ═════════════════════════════════╗${RESET}"

_row() {
    local icon="$1" name="$2" val="$3"
    printf "  ${HACK}║${RESET}  %b  %-12s${HACK_DIM}:${RESET}  ${BWHITE}%s${RESET}\n" "$icon" "$name" "$val"
}

if command -v git &>/dev/null; then
    _row "${HACK}[+]${RESET}" "git" "v$(git --version | awk '{print $3}')"
else
    _row "${HACK_ERR}[x]${RESET}" "git" "not found"
fi

if command -v make &>/dev/null; then
    _row "${HACK}[+]${RESET}" "make" "v$(make --version | head -1 | extract_version_short)"
else
    _row "${HACK_ERR}[x]${RESET}" "make" "not found"
fi

if command -v docker &>/dev/null; then
    _row "${HACK}[+]${RESET}" "docker" "v$(docker --version | extract_semver)"
else
    _row "${HACK_ERR}[x]${RESET}" "docker" "not found"
fi

if docker compose version &>/dev/null 2>&1; then
    _row "${HACK}[+]${RESET}" "compose" "v$(docker compose version --short 2>/dev/null || echo '?')"
else
    _row "${HACK_ERR}[x]${RESET}" "compose" "not available"
fi

if command -v fail2ban-client &>/dev/null; then
    _row "${HACK}[+]${RESET}" "fail2ban" "v$(fail2ban-client --version 2>&1 | extract_semver)"
else
    _row "${HACK_ERR}[x]${RESET}" "fail2ban" "not found"
fi

if command -v curl &>/dev/null; then
    _row "${HACK}[+]${RESET}" "curl" "v$(curl --version | head -1 | awk '{print $2}')"
fi

echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Docker Config ─────────────────────────────────────────────────
echo -e "  ${HACK}╔══[DKR] CONTAINER ENGINE ══════════════════════════╗${RESET}"
if docker info &>/dev/null 2>&1; then
    echo -e "  ${HACK}║${RESET}  Status        ${HACK_DIM}:${RESET}  ${HACK}online${RESET}"
    echo -e "  ${HACK}║${RESET}  Storage drv   ${HACK_DIM}:${RESET}  $(docker info --format '{{.Driver}}')"
    echo -e "  ${HACK}║${RESET}  Cgroup drv    ${HACK_DIM}:${RESET}  $(docker info --format '{{.CgroupDriver}}')"
    echo -e "  ${HACK}║${RESET}  Cgroup ver    ${HACK_DIM}:${RESET}  $(docker info --format '{{.CgroupVersion}}')"
    echo -e "  ${HACK}║${RESET}  Docker root   ${HACK_DIM}:${RESET}  $(docker info --format '{{.DockerRootDir}}')"
elif [[ "${DOCKER_NEEDS_REBOOT:-false}" == "true" ]]; then
    echo -e "  ${HACK}║${RESET}  Status        ${HACK_DIM}:${RESET}  ${HACK_WARN}pending reboot${RESET}"
    echo -e "  ${HACK}║${RESET}  Reason        ${HACK_DIM}:${RESET}  kernel modules need new kernel"
    echo -e "  ${HACK}║${RESET}  Fix           ${HACK_DIM}:${RESET}  ${BOLD}reboot${RESET} (docker is enabled)"
else
    echo -e "  ${HACK}║${RESET}  Status        ${HACK_DIM}:${RESET}  ${HACK_ERR}offline — check logs${RESET}"
    echo -e "  ${HACK}║${RESET}  Debug         ${HACK_DIM}:${RESET}  journalctl -xeu docker.service"
fi
echo -e "  ${HACK}║${RESET}  daemon.json   ${HACK_DIM}:${RESET}  ${GREEN}/etc/docker/daemon.json${RESET}"
echo -e "  ${HACK}║${RESET}  Log rotation  ${HACK_DIM}:${RESET}  json-file 10m × 3 files"
echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Security hardening ───────────────────────────────────────────
echo -e "  ${HACK}╔══[SEC] HARDENING & DDoS ══════════════════════════╗${RESET}"
echo -e "  ${HACK}║${RESET}  SSH config    ${HACK_DIM}:${RESET}  ${SSHD_DROPIN:-/etc/ssh/sshd_config.d/99-rahmat.conf}"
echo -e "  ${HACK}║${RESET}  SSH user      ${HACK_DIM}:${RESET}  ${SSH_USER}"
echo -e "  ${HACK}║${RESET}  SSH key       ${HACK_DIM}:${RESET}  $([[ -n "$SSH_PUBKEY" ]] && echo installed || echo not set)"
if [[ ${#SSH_WHITELIST[@]} -gt 0 ]]; then
    echo -e "  ${HACK}║${RESET}  SSH whitelist ${HACK_DIM}:${RESET}  ${SSH_WHITELIST[*]}"
else
    echo -e "  ${HACK}║${RESET}  SSH whitelist ${HACK_DIM}:${RESET}  ${HACK_DIM}any (port 22 open)${RESET}"
fi
echo -e "  ${HACK}║${RESET}  Fail2Ban      ${HACK_DIM}:${RESET}  ${F2B_JAIL:-/etc/fail2ban/jail.d/rahmat.local}"
echo -e "  ${HACK}║${RESET}  DDoS rules    ${HACK_DIM}:${RESET}  ${DDOS_SCRIPT:-/etc/rahmat/apply-ddos-rules.sh}"
echo -e "  ${HACK}║${RESET}  DDoS service  ${HACK_DIM}:${RESET}  $(has_systemd && echo 'rahmat-ddos.service' || echo 'rahmat-network.start (OpenRC)')"
echo -e "  ${HACK}║${RESET}  SYN cookies   ${HACK_DIM}:${RESET}  $(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo n/a)"
echo -e "  ${HACK}║${RESET}  DNS UDP cap   ${HACK_DIM}:${RESET}  300 qps/IP · burst 600"
echo -e "  ${HACK}║${RESET}  DoT 853 cap   ${HACK_DIM}:${RESET}  ${DOT_RATE}/IP · burst ${DOT_BURST} · max ${DOT_CONN_MAX} conn"
echo -e "  ${HACK}║${RESET}  Config (.env) ${HACK_DIM}:${RESET}  ${ENV_FILE}"
echo -e "  ${HACK}║${RESET}  Ping (ICMP)   ${HACK_DIM}:${RESET}  $([[ $(sysctl -n net.ipv4.icmp_echo_ignore_all 2>/dev/null) == 1 ]] && echo blocked || echo active)"
echo -e "  ${HACK}║${RESET}  Limits        ${HACK_DIM}:${RESET}  ${LIMITS_FILE:-/etc/security/limits.d/99-rahmat-dns.conf}"
echo -e "  ${HACK}║${RESET}  Swap          ${HACK_DIM}:${RESET}  $(free -h | awk '/Swap:/ {print $2}')"
echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Firewall ─────────────────────────────────────────────────────
if [[ "$PKG_MANAGER" == "apt" ]]; then
    FW_NAME="UFW"
    FW_STATE=$(ufw status | head -1 | awk '{print $NF}')
elif [[ "$PKG_MANAGER" == "apk" ]]; then
    FW_NAME="iptables (${ALPINE_IPT})"
    FW_STATE=$(${ALPINE_IPT:-iptables-legacy} -L INPUT -n 2>/dev/null | head -1 | grep -qi policy && echo "active" || echo "unknown")
else
    FW_NAME="firewalld"
    FW_STATE=$(systemctl is-active firewalld 2>/dev/null || echo "unknown")
fi

echo -e "  ${HACK}╔══[NET] FIREWALL :: ${FW_NAME} ═══════════════════════╗${RESET}"
echo -e "  ${HACK}║${RESET}  Status     ${HACK_DIM}:${RESET}  ${HACK}${FW_STATE}${RESET}"
echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD}  22${RESET}/tcp  ${HACK_DIM}::${RESET}  SSH"
echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD}  53${RESET}/tcp  ${HACK_DIM}::${RESET}  DNS Plain TCP"
echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD}  53${RESET}/udp  ${HACK_DIM}::${RESET}  DNS Plain UDP"
echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD}  80${RESET}/tcp  ${HACK_DIM}::${RESET}  HTTP / ACME"
echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD} 443${RESET}/tcp  ${HACK_DIM}::${RESET}  HTTPS / DoH"
echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD} 853${RESET}/tcp  ${HACK_DIM}::${RESET}  DoT (DNS-over-TLS)"
echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Kernel & DNS ──────────────────────────────────────────────────
echo -e "  ${HACK}╔══[KRN] DNS / DoT TUNING (53 · 853) ══════════════╗${RESET}"
echo -e "  ${HACK}║${RESET}  Sysctl file   ${HACK_DIM}:${RESET}  ${GREEN}${SYSCTL_FILE}${RESET}"
echo -e "  ${HACK}║${RESET}  UDP rmem_min  ${HACK_DIM}:${RESET}  $(sysctl -n net.ipv4.udp_rmem_min 2>/dev/null || echo n/a)"
echo -e "  ${HACK}║${RESET}  TCP syn_queue ${HACK_DIM}:${RESET}  $(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo n/a)"
echo -e "  ${HACK}║${RESET}  netdev_queue  ${HACK_DIM}:${RESET}  $(sysctl -n net.core.netdev_max_backlog 2>/dev/null || echo n/a)"
echo -e "  ${HACK}║${RESET}  conntrack     ${HACK_DIM}:${RESET}  $(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo n/a)"

for _spec in "53:udp:DNS UDP" "53:tcp:DNS TCP" "853:tcp:DoT TLS"; do
    IFS=: read -r _p _pr _lbl <<< "$_spec"
    if port_is_bound "$_p" "$_pr"; then
        echo -e "  ${HACK}║${RESET}  Port ${_p}/${_pr}   ${HACK_DIM}:${RESET}  ${HACK_ERR}in use — ${_lbl}${RESET}"
    else
        echo -e "  ${HACK}║${RESET}  Port ${_p}/${_pr}   ${HACK_DIM}:${RESET}  ${HACK}open${RESET}  ${HACK_DIM}(${_lbl})${RESET}"
    fi
done
echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── RHEL-family extra note ───────────────────────────────────────
if [[ "$OS_FAMILY" == "rhel" ]]; then
    echo -e "  ${HACK}╔══[RHL] RHEL FAMILY NOTES ════════════════════════╗${RESET}"
    echo -e "  ${HACK}║${RESET}  Distro      ${HACK_DIM}:${RESET}  ${OS_DISPLAY}"
    echo -e "  ${HACK}║${RESET}  Firewall    ${HACK_DIM}:${RESET}  firewalld (not UFW)"
    echo -e "  ${HACK}║${RESET}  SELinux     ${HACK_DIM}:${RESET}  $(getenforce 2>/dev/null || echo 'N/A')"
    if [[ "$NEEDS_EPEL" == "true" ]]; then
        echo -e "  ${HACK}║${RESET}  EPEL repo   ${HACK_DIM}:${RESET}  ${HACK}enabled${RESET}"
    fi
    echo -e "  ${HACK}║${RESET}  Docker src  ${HACK_DIM}:${RESET}  ${DOCKER_DNF_REPO#https://}"
    echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""
fi

if [[ "$OS_FAMILY" == "alpine" ]]; then
    echo -e "  ${HACK}╔══[ALP] ALPINE LINUX NOTES ═══════════════════════╗${RESET}"
    echo -e "  ${HACK}║${RESET}  Distro      ${HACK_DIM}:${RESET}  ${OS_DISPLAY}"
    echo -e "  ${HACK}║${RESET}  Init        ${HACK_DIM}:${RESET}  $(has_systemd && echo systemd || echo OpenRC)"
    echo -e "  ${HACK}║${RESET}  Firewall    ${HACK_DIM}:${RESET}  iptables (/etc/rahmat/apply-alpine-firewall.sh)"
    echo -e "  ${HACK}║${RESET}  Docker      ${HACK_DIM}:${RESET}  apk (cgroupfs driver)"
    echo -e "  ${HACK}║${RESET}  DDoS boot   ${HACK_DIM}:${RESET}  /etc/local.d/rahmat-network.start"
    echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""
fi

echo -e "  ${HACK}[+]${RESET} ${BOLD}NODE CLEARED :: DNS SAAS DEPLOYMENT READY${RESET}"
echo ""
if [[ "${DOCKER_NEEDS_REBOOT:-false}" == "true" ]]; then
    echo -e "  ${HACK_ERR}[!]${RESET}  ${BOLD}REBOOT REQUIRED${RESET} — Docker needs the updated kernel's netfilter modules"
    echo -e "  ${HACK}[>]${RESET}  ${BOLD}reboot${RESET}  ${HACK_DIM}# docker.service will start automatically${RESET}"
else
    echo -e "  ${HACK_WARN}[!]${RESET}  REBOOT RECOMMENDED — kernel params pending full apply"
    echo -e "  ${HACK}[>]${RESET}  ${BOLD}reboot${RESET}"
fi
echo ""
echo -e "  ${HACK_MUTED}RAHMAT // ${GITHUB_URL} // $(date '+%Y')${RESET}"
echo ""
