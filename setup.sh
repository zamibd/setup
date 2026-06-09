#!/usr/bin/env bash
# ================================================================
#  RAHMAT — DNS SaaS Server Setup Script
#  Supports : AlmaLinux (8, 9, 10+)
#  Author   : RAHMAT
#  GitHub   : https://github.com/zamibd/setup/setup.sh
#  Version  : 3.0.0
# ================================================================

# Re-exec with bash when invoked via sh/dash
if [ -z "${BASH_VERSION:-}" ]; then
    _rahmat_sh="$0"
    if [ -x /bin/bash ] && [ -f "$_rahmat_sh" ]; then
        exec /bin/bash "$_rahmat_sh" "$@"
    fi
    printf '%s\n' \
        'ERROR: bash is required to run this installer.' \
        'Run: bash setup.sh   (or: sudo bash setup.sh)' >&2
    exit 1
fi

set -euo pipefail

SCRIPT_NAME="RAHMAT"
SCRIPT_PRODUCT="DNS-INFRA"
SCRIPT_VERSION="3.0.0"
SCRIPT_AUTHOR="RAHMAT"
SCRIPT_REPO="https://github.com/zamibd/setup"
SCRIPT_PLATFORM="AlmaLinux 8 · 9 · 10+"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

load_dotenv() {
    local _file="$1"
    [[ -f "$_file" ]] || return 1
    set -a
    # shellcheck disable=SC1090
    source "$_file" || {
        set +a
        fail "Cannot load ${_file} — check quotes/syntax, fix the file, and re-run setup.sh"
    }
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
    : "${SYSCTL_NETDEV_BUDGET:=1200}"
    : "${SYSCTL_NETDEV_BUDGET_USECS:=16000}"
    : "${SYSCTL_SOMAXCONN:=65535}"
    : "${SYSCTL_CONNTRACK_MAX:=2097152}"
    : "${SYSCTL_CONNTRACK_TCP_ESTABLISHED:=7200}"
    : "${SYSCTL_SWAPPINESS:=10}"
    : "${SYSCTL_FILE_MAX:=2097152}"
    : "${SYSCTL_UDP_RMEM_MIN:=16384}"
    : "${TCP_BBR_ENABLED:=true}"
    : "${PERF_THP_DISABLE:=true}"
    : "${PERF_CPU_GOVERNOR:=true}"
    : "${HARDEN_CHRONY:=true}"
    : "${HARDEN_AUDITD:=true}"
    : "${HARDEN_DISABLE_UNUSED_SERVICES:=true}"
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
    : "${SSH_OPEN_PUBLIC:=false}"
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

ENV_JUST_CREATED=false

reload_config() {
    load_dotenv "/etc/rahmat/.env" || true
    load_dotenv "$ENV_FILE" || true
    apply_config_defaults
}

ensure_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        return 0
    fi
    if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
        cp "${SCRIPT_DIR}/.env.example" "$ENV_FILE"
        ENV_JUST_CREATED=true
        return 0
    fi
    if command -v curl &>/dev/null; then
        if curl -fsSL "https://raw.githubusercontent.com/zamibd/setup/main/.env.example" -o "$ENV_FILE"; then
            ENV_JUST_CREATED=true
            return 0
        fi
    fi
    fail "No ${ENV_FILE} found. Run: curl -fsSL …/.env.example -o .env && nano .env"
}

# Bootstrap .env before first load (full reload after optional nano edit)
ensure_env_file
reload_config

TOTAL_STEPS=15

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

# ── Interactive / validation helpers ─────────────────────────────
has_tty() {
    [[ -t 0 ]] || { [[ -r /dev/tty ]] && [[ -w /dev/tty ]]; }
}

is_interactive() {
    [[ "${INTERACTIVE_PROMPTS}" == "true" ]] && has_tty
}

env_needs_editor() {
    [[ -z "${SSH_PUBLIC_KEY:-}" ]]
}

open_env_editor() {
    info "Opening editor — set SSH_PUBLIC_KEY and SSH_WHITELIST_IPS, then save and exit (Ctrl+O, Enter, Ctrl+X)"
    if command -v nano &>/dev/null; then
        if [[ -t 0 ]]; then
            nano "$ENV_FILE" || return 1
        else
            nano "$ENV_FILE" </dev/tty >/dev/tty || return 1
        fi
    elif [[ -n "${EDITOR:-}" ]]; then
        if [[ -t 0 ]]; then
            "$EDITOR" "$ENV_FILE" || return 1
        else
            "$EDITOR" "$ENV_FILE" </dev/tty >/dev/tty || return 1
        fi
    elif [[ -t 0 ]]; then
        vi "$ENV_FILE" || return 1
    else
        vi "$ENV_FILE" </dev/tty >/dev/tty || return 1
    fi
    return 0
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

capture_ssh_client_ip() {
    CURRENT_SSH_IP=""
    [[ -n "${SSH_CONNECTION:-}" ]] && CURRENT_SSH_IP="${SSH_CONNECTION%% *}"
}

normalize_whitelist_entry() {
    local ip="$1"
    [[ "$ip" == */* ]] && printf '%s' "$ip" || printf '%s/32' "$ip"
}

parse_ssh_whitelist() {
    local input="${1:-}" part ip
    SSH_WHITELIST=()
    [[ -z "$input" ]] && return 0
    IFS=',' read -ra _wl_parts <<< "$input"
    for part in "${_wl_parts[@]}"; do
        ip="${part// /}"
        [[ -z "$ip" ]] && continue
        if valid_ip_or_cidr "$ip"; then
            SSH_WHITELIST+=("$(normalize_whitelist_entry "$ip")")
        else
            warn "Invalid IP/CIDR skipped: $ip"
        fi
    done
}

current_ip_in_whitelist() {
    local ip="$1" entry base
    [[ -z "$ip" ]] && return 1
    for entry in "${SSH_WHITELIST[@]}"; do
        [[ "$entry" == "$ip" || "$entry" == "${ip}/32" ]] && return 0
        base="${entry%%/*}"
        [[ "$entry" != */* && "$base" == "$ip" ]] && return 0
    done
    return 1
}

validate_preflight_ssh() {
    local _key="${SSH_PUBLIC_KEY:-}"
    if [[ -n "$_key" ]] && ! valid_ssh_pubkey "$_key"; then
        fail "SSH_PUBLIC_KEY in ${ENV_FILE} is invalid — fix before continuing"
    fi
    if [[ "$SSH_DISABLE_PASSWORD" == "yes" && -z "$_key" ]]; then
        fail "SSH_DISABLE_PASSWORD=yes requires a valid SSH_PUBLIC_KEY in ${ENV_FILE}"
    fi
    if [[ "$SSH_DISABLE_PASSWORD" == "no" && -z "$_key" ]]; then
        warn "No SSH_PUBLIC_KEY — password login will stay enabled for ${SSH_USER}"
    fi
    if [[ -z "${SSH_WHITELIST_IPS:-}" && "$SSH_OPEN_PUBLIC" != "true" && -z "$CURRENT_SSH_IP" ]]; then
        warn "SSH_WHITELIST_IPS empty and not connected via SSH — port ${SSH_PORT} will be blocked"
    fi
}

ssh_firewall_rich_rule() {
    printf 'rule family="ipv4" source ipset="%s" port port="%s" protocol="tcp" accept' \
        "$SSH_IPSET_NAME" "$SSH_PORT"
}

reset_ssh_firewall_state() {
    local _rule _old
    _rule=$(ssh_firewall_rich_rule)
    firewall-cmd --permanent --remove-rich-rule="${_rule}" > /dev/null 2>&1 || true
    while IFS= read -r _old; do
        [[ -n "$_old" ]] || continue
        firewall-cmd --permanent --remove-rich-rule="${_old}" > /dev/null 2>&1 || true
    done < <(firewall-cmd --permanent --list-rich-rules 2>/dev/null | \
        grep -E "port port=\"?${SSH_PORT}\"?.*protocol=\"?tcp\"?.*accept" || true)
    firewall-cmd --permanent --delete-ipset="${SSH_IPSET_NAME}" > /dev/null 2>&1 || true
    firewall-cmd --permanent --remove-port="${SSH_PORT}/tcp" > /dev/null 2>&1 || true
    firewall-cmd --permanent --remove-service=ssh > /dev/null 2>&1 || true
}

apply_ssh_firewall_rules() {
    local ip _rule
    SSH_IPSET_NAME="rahmat-ssh-allow"
    capture_ssh_client_ip
    parse_ssh_whitelist "${SSH_WHITELIST_IPS:-}"

    if [[ ${#SSH_WHITELIST[@]} -eq 0 && -n "$CURRENT_SSH_IP" ]]; then
        SSH_WHITELIST+=("$(normalize_whitelist_entry "$CURRENT_SSH_IP")")
        warn "SSH_WHITELIST_IPS empty — auto-allowed current session ${SSH_WHITELIST[0]} (add your IP to .env)"
    fi

    reset_ssh_firewall_state

    if [[ ${#SSH_WHITELIST[@]} -gt 0 ]]; then
        detail "SSH whitelist: ${SSH_WHITELIST[*]}"
        if [[ -n "$CURRENT_SSH_IP" ]] && ! current_ip_in_whitelist "$CURRENT_SSH_IP"; then
            warn "Current session IP ${CURRENT_SSH_IP} NOT in whitelist — verify before disconnect!"
        fi
        firewall-cmd --permanent --new-ipset="${SSH_IPSET_NAME}" --type=hash:net > /dev/null 2>&1 || \
            fail "Failed to create firewalld ipset ${SSH_IPSET_NAME}"
        for ip in "${SSH_WHITELIST[@]}"; do
            firewall-cmd --permanent --ipset="${SSH_IPSET_NAME}" --add-entry="${ip}" > /dev/null 2>&1 || \
                fail "Failed to add ${ip} to ${SSH_IPSET_NAME}"
            detail "firewalld allow SSH from ${ip} → port ${SSH_PORT}"
        done
        _rule=$(ssh_firewall_rich_rule)
        firewall-cmd --permanent --add-rich-rule="${_rule}" > /dev/null 2>&1 || \
            fail "Failed to add SSH whitelist rich rule"
        SSH_FIREWALL_MODE="whitelist"
        ok "SSH port ${SSH_PORT}/tcp restricted to ${#SSH_WHITELIST[@]} IP/CIDR rule(s)"
    elif [[ "$SSH_OPEN_PUBLIC" == "true" ]]; then
        firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" > /dev/null 2>&1
        SSH_FIREWALL_MODE="public"
        warn "SSH port ${SSH_PORT}/tcp open to all IPs (SSH_OPEN_PUBLIC=true)"
    else
        SSH_FIREWALL_MODE="closed"
        warn "SSH port ${SSH_PORT}/tcp blocked — set SSH_WHITELIST_IPS in .env or SSH_OPEN_PUBLIC=true"
    fi
    firewall-cmd --reload > /dev/null 2>&1
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
        ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
        echo "$TIMEZONE" > /etc/timezone 2>/dev/null || true
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
After=network-online.target firewalld.service docker.service
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
# RAHMAT — DDoS iptables rules at boot (non-systemd hosts)
${DDOS_SCRIPT}
EOF
        chmod +x /etc/local.d/rahmat-network.start
        bash "$DDOS_SCRIPT" >/dev/null 2>&1 || true
        ok "Boot script → /etc/local.d/rahmat-network.start"
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
SSH_FIREWALL_MODE="closed"
SSH_IPSET_NAME="rahmat-ssh-allow"
CURRENT_SSH_IP=""
capture_ssh_client_ip

banner() {
    clear
    echo ""
    echo -e "${HACK_DIM}[!] initialising payload...${RESET}"
    echo -e "${HACK}${BOLD}"
    echo '  ┌──────────────────────────────────────────────────────────┐'
    echo "  │ 0x5241484D4154 :: ${SCRIPT_NAME} :: ${SCRIPT_PRODUCT} :: v${SCRIPT_VERSION}          │"
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
    echo -e "  ${HACK_MUTED}[#]${RESET} ${HACK_DIM}${SCRIPT_PLATFORM}${RESET}"
    echo ""
    echo -e "  ${HACK_MUTED}$(printf '%.0s=' {1..58})${RESET}"
    echo ""
}

_row() {
    local icon="$1" name="$2" val="$3"
    printf "  ${HACK}║${RESET}  %b  %-12s${HACK_DIM}:${RESET}  ${BWHITE}%s${RESET}\n" "$icon" "$name" "$val"
}

_svc_status_icon() {
    local svc="$1"
    if svc_is_active "$svc"; then
        echo -e "${HACK}[+]${RESET}"
    else
        echo -e "${HACK_ERR}[x]${RESET}"
    fi
}

_chrony_active() {
    svc_is_active chronyd || svc_is_active chrony
}

print_final_summary() {
    local _host _installed _docker_st _fw_st _f2b_st _ddos_st _chr_st _aud_st
    local _ports_ok=0 _ports_total=3 _spec _p _pr

    _host=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown")
    _installed=$(date '+%A, %d %B %Y  %H:%M:%S %Z')

    if docker info &>/dev/null 2>&1; then
        _docker_st="${HACK}online${RESET}"
    elif [[ "${DOCKER_NEEDS_REBOOT:-false}" == "true" ]]; then
        _docker_st="${HACK_WARN}pending reboot${RESET}"
    else
        _docker_st="${HACK_ERR}offline${RESET}"
    fi

    _fw_st=$(systemctl is-active firewalld 2>/dev/null || echo "inactive")
    _f2b_st=$(systemctl is-active fail2ban 2>/dev/null || echo "inactive")
    _ddos_st=$(systemctl is-active rahmat-ddos 2>/dev/null || echo "inactive")
    _chr_st=$(systemctl is-active chronyd 2>/dev/null || systemctl is-active chrony 2>/dev/null || echo "inactive")
    _aud_st=$(systemctl is-active auditd 2>/dev/null || echo "inactive")

    for _spec in "53:udp" "53:tcp" "853:tcp"; do
        IFS=: read -r _p _pr <<< "$_spec"
        port_is_bound "$_p" "$_pr" || _ports_ok=$((_ports_ok + 1))
    done

    echo ""
    echo -e "${HACK}${BOLD}"
    echo '  ╔══════════════════════════════════════════════════════════╗'
    echo '  ║                                                          ║'
    printf '  ║%s║\n' "     ${SCRIPT_NAME} ${SCRIPT_PRODUCT} — INSTALLATION COMPLETE          "
    echo '  ║                                                          ║'
    echo '  ╠══════════════════════════════════════════════════════════╣'
    echo -e "${RESET}"

    echo -e "  ${HACK}╔══[META] PROJECT ══════════════════════════════════╗${RESET}"
    echo -e "  ${HACK}║${RESET}  Name        ${HACK_DIM}:${RESET}  ${BWHITE}${SCRIPT_NAME} DNS SaaS Server Bootstrap${RESET}"
    echo -e "  ${HACK}║${RESET}  Product     ${HACK_DIM}:${RESET}  ${BWHITE}${SCRIPT_PRODUCT}${RESET}"
    echo -e "  ${HACK}║${RESET}  Version     ${HACK_DIM}:${RESET}  ${BWHITE}v${SCRIPT_VERSION}${RESET}"
    echo -e "  ${HACK}║${RESET}  Author      ${HACK_DIM}:${RESET}  ${BWHITE}${SCRIPT_AUTHOR}${RESET}"
    echo -e "  ${HACK}║${RESET}  Repository  ${HACK_DIM}:${RESET}  ${BWHITE}${SCRIPT_REPO}${RESET}"
    echo -e "  ${HACK}║${RESET}  Script      ${HACK_DIM}:${RESET}  ${BWHITE}${GITHUB_URL}${RESET}"
    echo -e "  ${HACK}║${RESET}  Platform    ${HACK_DIM}:${RESET}  ${BWHITE}${SCRIPT_PLATFORM}${RESET}"
    echo -e "  ${HACK}║${RESET}  Phases      ${HACK_DIM}:${RESET}  ${BWHITE}${TOTAL_STEPS} / ${TOTAL_STEPS} completed${RESET}"
    echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""

    echo -e "  ${HACK}╔══[NODE] DEPLOYMENT TARGET ════════════════════════╗${RESET}"
    echo -e "  ${HACK}║${RESET}  Hostname    ${HACK_DIM}:${RESET}  ${BWHITE}${_host}${RESET}"
    echo -e "  ${HACK}║${RESET}  OS          ${HACK_DIM}:${RESET}  ${BWHITE}${PRETTY_NAME}${RESET}"
    echo -e "  ${HACK}║${RESET}  Kernel      ${HACK_DIM}:${RESET}  ${BWHITE}$(uname -r)${RESET}"
    echo -e "  ${HACK}║${RESET}  Arch        ${HACK_DIM}:${RESET}  ${BWHITE}$(uname -m)${RESET}"
    echo -e "  ${HACK}║${RESET}  Timezone    ${HACK_DIM}:${RESET}  ${BWHITE}$(get_timezone)${RESET}"
    echo -e "  ${HACK}║${RESET}  Finished    ${HACK_DIM}:${RESET}  ${BWHITE}${_installed}${RESET}"
    echo -e "  ${HACK}║${RESET}  Config      ${HACK_DIM}:${RESET}  ${BWHITE}/etc/rahmat/.env${RESET}"
    echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""

    echo -e "  ${HACK}╔══[SVC] SERVICE STATUS ════════════════════════════╗${RESET}"
    echo -e "  ${HACK}║${RESET}  $(_svc_status_icon docker)  docker         ${HACK_DIM}:${RESET}  ${_docker_st}"
    echo -e "  ${HACK}║${RESET}  $(_svc_status_icon firewalld)  firewalld     ${HACK_DIM}:${RESET}  $([[ "$_fw_st" == active ]] && echo -e "${HACK}${_fw_st}${RESET}" || echo -e "${HACK_ERR}${_fw_st}${RESET}")"
    echo -e "  ${HACK}║${RESET}  $(_svc_status_icon fail2ban)  fail2ban      ${HACK_DIM}:${RESET}  $([[ "$_f2b_st" == active ]] && echo -e "${HACK}${_f2b_st}${RESET}" || echo -e "${HACK_ERR}${_f2b_st}${RESET}")"
    echo -e "  ${HACK}║${RESET}  $(_svc_status_icon rahmat-ddos)  rahmat-ddos   ${HACK_DIM}:${RESET}  $([[ "$_ddos_st" == active ]] && echo -e "${HACK}${_ddos_st}${RESET}" || echo -e "${HACK_WARN}${_ddos_st}${RESET}")"
    if [[ "$HARDEN_CHRONY" == "true" ]]; then
        echo -e "  ${HACK}║${RESET}  $(_chrony_active && echo -e "${HACK}[+]${RESET}" || echo -e "${HACK_ERR}[x]${RESET}")  chronyd       ${HACK_DIM}:${RESET}  $([[ "$_chr_st" == active ]] && echo -e "${HACK}${_chr_st}${RESET}" || echo -e "${HACK_WARN}${_chr_st}${RESET}")"
    fi
    if [[ "$HARDEN_AUDITD" == "true" ]]; then
        echo -e "  ${HACK}║${RESET}  $(_svc_status_icon auditd)  auditd        ${HACK_DIM}:${RESET}  $([[ "$_aud_st" == active ]] && echo -e "${HACK}${_aud_st}${RESET}" || echo -e "${HACK_WARN}${_aud_st}${RESET}")"
    fi
    echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""

    echo -e "  ${HACK}╔══[DNS] LISTENING PORTS ═══════════════════════════╗${RESET}"
    echo -e "  ${HACK}║${RESET}  Ready       ${HACK_DIM}:${RESET}  ${BWHITE}${_ports_ok}/${_ports_total} ports free for DNS stack${RESET}"
    echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD} 53${RESET}/udp  ${HACK_DIM}+${RESET}  ${BOLD}53${RESET}/tcp  ${HACK_DIM}→${RESET}  DNS Plain"
    echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD}853${RESET}/tcp ${HACK_DIM}→${RESET}  DoT (DNS-over-TLS)"
    echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD}443${RESET}/tcp ${HACK_DIM}→${RESET}  DoH (DNS-over-HTTPS)"
    if [[ "$SSH_FIREWALL_MODE" == "whitelist" ]]; then
        echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD} ${SSH_PORT}${RESET}/tcp ${HACK_DIM}→${RESET}  SSH (whitelist)"
    elif [[ "$SSH_FIREWALL_MODE" == "public" ]]; then
        echo -e "  ${HACK}║${RESET}  ${HACK_WARN}[!]${RESET}  ${BOLD} ${SSH_PORT}${RESET}/tcp ${HACK_DIM}→${RESET}  SSH (open to all)"
    else
        echo -e "  ${HACK}║${RESET}  ${HACK_ERR}[x]${RESET}  ${BOLD} ${SSH_PORT}${RESET}/tcp ${HACK_DIM}→${RESET}  SSH (blocked)"
    fi
    echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD} 80${RESET}/tcp ${HACK_DIM}→${RESET}  HTTP / ACME"
    echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""

    echo -e "${BG_HACK}                                                      ${RESET}"
    if [[ "${DOCKER_NEEDS_REBOOT:-false}" == "true" ]]; then
        echo -e "${BG_HACK}   [!] REBOOT REQUIRED — then deploy your DNS stack    ${RESET}"
    else
        echo -e "${BG_HACK}   [+] NODE READY — deploy your DNS SaaS stack now     ${RESET}"
    fi
    echo -e "${BG_HACK}                                                      ${RESET}"
    echo ""
    echo -e "  ${HACK}[>]${RESET}  ${BOLD}Next steps${RESET}"
    echo -e "      ${HACK_DIM}1.${RESET}  ${BOLD}reboot${RESET}  ${HACK_DIM}(recommended — apply all kernel tuning)${RESET}"
    echo -e "      ${HACK_DIM}2.${RESET}  ${BOLD}nano /etc/rahmat/.env${RESET}  ${HACK_DIM}(review production settings)${RESET}"
    echo -e "      ${HACK_DIM}3.${RESET}  Deploy DNS resolver on Docker ${HACK_DIM}(bind / unbound / CoreDNS)${RESET}"
    echo -e "      ${HACK_DIM}4.${RESET}  ${BOLD}systemctl restart rahmat-ddos${RESET}  ${HACK_DIM}(after .env DDoS changes)${RESET}"
    echo ""
    if [[ "${DOCKER_NEEDS_REBOOT:-false}" == "true" ]]; then
        echo -e "  ${HACK_ERR}[!]${RESET}  ${BOLD}REBOOT REQUIRED${RESET} — Docker needs updated kernel netfilter modules"
        echo -e "  ${HACK}[>]${RESET}  ${BOLD}reboot${RESET}  ${HACK_DIM}# docker.service will start automatically${RESET}"
    else
        echo -e "  ${HACK_WARN}[!]${RESET}  ${BOLD}REBOOT RECOMMENDED${RESET} — kernel parameters apply fully after restart"
        echo -e "  ${HACK}[>]${RESET}  ${BOLD}reboot${RESET}"
    fi
    echo ""
    echo -e "  ${HACK_MUTED}────────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${HACK}${BOLD}${SCRIPT_NAME}${RESET} ${HACK_DIM}·${RESET} ${SCRIPT_PRODUCT} ${HACK_DIM}·${RESET} v${SCRIPT_VERSION} ${HACK_DIM}·${RESET} ${SCRIPT_AUTHOR}"
    echo -e "  ${HACK_DIM}${SCRIPT_REPO} · $(date '+%Y')${RESET}"
    echo -e "  ${HACK_MUTED}────────────────────────────────────────────────────────────${RESET}"
    echo ""
}

# ── Root Check ───────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && {
    echo -e "\n  ${HACK_ERR}[x] ACCESS DENIED${RESET}  ${HACK_DIM}root privileges required${RESET}"
    echo -e "  ${HACK}[>]${RESET}  ${HACK_WARN}sudo bash $0${RESET}\n"
    exit 1
}

banner

# ── Pre-flight — edit .env (SSH key, whitelist, etc.) ───────────
echo ""
echo -e "  ${HACK}[CONFIG]${RESET}  ${BOLD}>> Review ${ENV_FILE} before install${RESET}"
echo -e "  ${HACK_MUTED}$(printf '%.0s-' {1..50})${RESET}"
if [[ "$ENV_JUST_CREATED" == "true" ]]; then
    ok "Created ${ENV_FILE} from .env.example"
else
    ok "Using ${ENV_FILE}"
fi
detail "Set SSH_PUBLIC_KEY and SSH_WHITELIST_IPS in .env — port 22 is not open to the world by default"

if env_needs_editor; then
    if is_interactive; then
        echo ""
        open_env_editor || fail "Editor cancelled — save ${ENV_FILE} and re-run setup.sh"
        echo ""
        reload_config
        ok "Config saved — continuing install automatically"
    else
        fail "SSH_PUBLIC_KEY is empty in ${ENV_FILE} — edit the file and re-run setup.sh"
    fi
elif [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
    ok "Config ready (SSH_PUBLIC_KEY set) — skipping editor"
else
    warn "Non-interactive run with empty SSH_PUBLIC_KEY"
fi

capture_ssh_client_ip
validate_preflight_ssh

echo ""
ok "Starting installation — phase 1/${TOTAL_STEPS}"
echo ""

# Sync .env to system path
install -d -m 750 /etc/rahmat
if [[ -f "$ENV_FILE" ]]; then
    install -m 640 "$ENV_FILE" /etc/rahmat/.env
    ok "Config synced → /etc/rahmat/.env"
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
PKG_MANAGER="dnf"
OS_FAMILY="rhel"
OS_DISPLAY=""
DOCKER_DNF_REPO=""

configure_almalinux() {
    DOCKER_DNF_REPO=$(resolve_docker_dnf_repo)
    OS_DISPLAY="AlmaLinux ${OS_VERSION:-}"
    ok "${BGREEN}${OS_DISPLAY}${RESET} — supported"
    detail "Version     : ${OS_VERSION:-unknown}"
    detail "Arch        : $(uname -m)"
    detail "Docker repo : ${DOCKER_DNF_REPO##*/}"
    is_rhel_el10_plus && detail "EL10+ notes  : iptables-nft + kernel-modules-extra"
    detail "EPEL        : enabled"
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
    if is_rhel_el10_plus; then
        echo "https://download.docker.com/linux/rhel/docker-ce.repo"
    else
        echo "https://download.docker.com/linux/centos/docker-ce.repo"
    fi
}

case "$OS_ID" in
    almalinux)
        configure_almalinux
        ;;
    *)
        fail "Unsupported OS: '$OS_ID'. This installer supports AlmaLinux only."
        ;;
esac

detail "Package mgr : $PKG_MANAGER"
detail "OS family   : $OS_FAMILY"

# ────────────────────────────────────────────────────────────────
# STEP 2 — System Update & Upgrade
# ────────────────────────────────────────────────────────────────
step 2 "$TOTAL_STEPS" "System Update & Upgrade"

info "Running dnf update (this may take a while)..."
dnf update -y -q
ok "System packages upgraded successfully"

if ! dnf repolist 2>/dev/null | grep -qi "epel"; then
    info "Enabling EPEL repository..."
    dnf install -y -q epel-release
    ok "EPEL repository enabled"
else
    skip "EPEL repository"
fi

# ────────────────────────────────────────────────────────────────
# STEP 3 — Essential Packages
# ────────────────────────────────────────────────────────────────
step 3 "$TOTAL_STEPS" "Essential Packages"

PKGS=(
    curl wget git nano fail2ban dnf-automatic iptables ipset
    ca-certificates gnupg2 chrony audit kernel-tools
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

    warn "Docker failed to start — running AlmaLinux recovery..."
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

# cgroupv2 + overlay2 — AlmaLinux compatible
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

upgrade_docker_dnf() {
    dnf upgrade -y -q \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
}

if command -v docker &>/dev/null; then
    OLD_VER=$(docker --version | extract_semver)
    info "docker found (${HACK_WARN}v${OLD_VER}${RESET}) — checking for upgrades..."
    upgrade_docker_dnf
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
        warn "Docker daemon not responding — retrying with AlmaLinux host recovery..."
        prepare_docker_dnf_host
        svc_daemon_reload
        ensure_docker_running || true
    fi
else
    install_docker_dnf
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
net.core.netdev_budget       = ${SYSCTL_NETDEV_BUDGET}
net.core.netdev_budget_usecs = ${SYSCTL_NETDEV_BUDGET_USECS}
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

if [[ "$TCP_BBR_ENABLED" == "true" ]]; then
    cat >> "$SYSCTL_FILE" << 'EOF'

# TCP BBR congestion control (DoT/DoH throughput)
net.core.default_qdisc             = fq
net.ipv4.tcp_congestion_control    = bbr
EOF
fi

modprobe nf_conntrack 2>/dev/null || true
if [[ "$TCP_BBR_ENABLED" == "true" ]]; then
    modprobe tcp_bbr 2>/dev/null || true
fi
cat > /etc/modules-load.d/rahmat-dns.conf << EOF
nf_conntrack
xt_hashlimit
xt_connlimit
xt_recent
$([[ "$TCP_BBR_ENABLED" == "true" ]] && echo tcp_bbr)
EOF

info "Applying DNS/DoT sysctl parameters..."
while IFS= read -r _line; do
    [[ "$_line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${_line// }" ]] && continue
    sysctl -w "$_line" > /dev/null 2>&1 || true
done < "$SYSCTL_FILE"
sysctl -p "$SYSCTL_FILE" > /dev/null 2>&1 || true
if [[ "$TCP_BBR_ENABLED" == "true" ]]; then
    if sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        ok "Kernel tuned for DNS 53 (udp/tcp) + DoT 853 + TCP BBR"
    else
        ok "Kernel tuned for DNS 53 (udp/tcp) + DoT 853"
        warn "TCP BBR requested but not active — kernel may lack tcp_bbr (reboot after kernel update)"
    fi
else
    ok "Kernel tuned for DNS 53 (udp/tcp) + DoT 853"
fi

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
    skip "systemd limits not applicable (non-systemd host)"
fi

detail "Config file    : $SYSCTL_FILE"
detail "UDP rmem_min   : $(sysctl -n net.ipv4.udp_rmem_min 2>/dev/null || echo n/a)"
detail "TCP syn_backlog: $(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo n/a)"
detail "netdev_backlog : $(sysctl -n net.core.netdev_max_backlog 2>/dev/null || echo n/a)"
detail "conntrack_max  : $(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo n/a)"
detail "fs.file-max    : $(sysctl -n fs.file-max 2>/dev/null || echo n/a)"
if [[ "$TCP_BBR_ENABLED" == "true" ]]; then
    detail "TCP congestion: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo n/a) (qdisc $(sysctl -n net.core.default_qdisc 2>/dev/null || echo n/a))"
fi
detail "Port targets   : 53/udp 53/tcp 853/tcp"

# ────────────────────────────────────────────────────────────────
# STEP 8 — Firewall
# ────────────────────────────────────────────────────────────────
step 8 "$TOTAL_STEPS" "Firewall Rules"

open_port_firewalld() {
    local port="$1" label="$2"
    firewall-cmd --permanent --add-port="${port}" > /dev/null 2>&1
    local proto num
    proto=$(echo "$port" | cut -d/ -f2 | tr '[:lower:]' '[:upper:]')
    num=$(echo "$port" | cut -d/ -f1)
    echo -e "  ${HACK}[+]${RESET}  ${BOLD}${GREEN}${num}${RESET}/${HACK}${proto}${RESET}   ${HACK_DIM}::${RESET} ${WHITE}${label}${RESET}"
}

info "Configuring firewalld..."
systemctl enable --now firewalld > /dev/null 2>&1
ok "Default policy → ${BRED}DENY${RESET} incoming / ${BGREEN}ALLOW${RESET} outgoing"
echo ""
open_port_firewalld "53/udp"  "DNS — Plain UDP (primary)"
open_port_firewalld "53/tcp"  "DNS — Plain TCP (fallback)"
open_port_firewalld "853/tcp" "DoT — DNS-over-TLS"
detail "SSH port ${SSH_PORT}/tcp deferred to phase 10 (whitelist or SSH_OPEN_PUBLIC)"
open_port_firewalld "80/tcp"  "HTTP — ACME / Certificate Renewal"
open_port_firewalld "443/tcp" "HTTPS — DoH (DNS-over-HTTPS)"
firewall-cmd --permanent --add-icmp-block=echo-request > /dev/null 2>&1 || true
ok "ICMP ping blocked (firewalld + sysctl)"
echo ""
firewall-cmd --reload > /dev/null 2>&1
ok "firewalld ${BGREEN}reloaded & active${RESET}"

# ────────────────────────────────────────────────────────────────
# STEP 9 — DDoS Protection
# ────────────────────────────────────────────────────────────────
step 9 "$TOTAL_STEPS" "DDoS Protection (DNS / DoT / SYN flood)"

DDOS_SCRIPT="/etc/rahmat/apply-ddos-rules.sh"
DDOS_CONF="/etc/rahmat/ddos.conf"

info "Loading DDoS kernel modules..."
modprobe xt_hashlimit >/dev/null 2>&1 || true
modprobe xt_connlimit >/dev/null 2>&1 || true
modprobe xt_recent   >/dev/null 2>&1 || true

apply_ddos_kernel

info "Installing per-IP rate limits (53 udp/tcp · 853 · 443)..."
install_ddos_script

apply_ddos_firewalld
ok "firewalld DDoS passthrough rules applied"

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

detail "SSH settings from .env — user: ${SSH_USER}"

SSH_HOME=$(getent passwd "$SSH_USER" | cut -d: -f6)
[[ -n "$SSH_HOME" ]] || fail "SSH user '$SSH_USER' not found"

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

apply_ssh_firewall_rules

PASSWORD_AUTHENTICATION="yes"
if [[ "$SSH_DISABLE_PASSWORD" == "yes" ]]; then
    PASSWORD_AUTHENTICATION="no"
elif [[ "$SSH_DISABLE_PASSWORD" == "no" ]]; then
    PASSWORD_AUTHENTICATION="yes"
elif [[ -n "$SSH_PUBKEY" ]]; then
    PASSWORD_AUTHENTICATION="no"
fi

if [[ "$SSH_USER" == "root" ]]; then
    if [[ -n "$SSH_PUBKEY" ]]; then
        ROOT_LOGIN="prohibit-password"
    else
        ROOT_LOGIN="yes"
        warn "No SSH key installed — root password login kept enabled (set SSH_PUBLIC_KEY before re-run)"
    fi
else
    ROOT_LOGIN="no"
fi

cat > "$SSHD_DROPIN" << EOF
# RAHMAT — SSH hardening (from .env)
Port ${SSH_PORT}
PermitRootLogin ${ROOT_LOGIN}
PubkeyAuthentication yes
PasswordAuthentication ${PASSWORD_AUTHENTICATION}
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
detail "Password auth : ${PASSWORD_AUTHENTICATION}"
detail "AllowUsers    : ${SSH_USER}"

# ────────────────────────────────────────────────────────────────
# STEP 11 — Fail2Ban Jails
# ────────────────────────────────────────────────────────────────
step 11 "$TOTAL_STEPS" "Fail2Ban Jail Configuration"

F2B_JAIL="/etc/fail2ban/jail.d/rahmat.local"
mkdir -p /etc/fail2ban/jail.d

F2B_BANACTION="firewallcmd-rich-rules"
F2B_BACKEND="systemd"
F2B_IGNOREIP="127.0.0.1/8 ::1"
for _f2b_ip in "${SSH_WHITELIST[@]}"; do
    F2B_IGNOREIP+=" ${_f2b_ip}"
done

cat > "$F2B_JAIL" << EOF
# RAHMAT — Fail2Ban jails (from .env)
[DEFAULT]
bantime  = ${F2B_DEFAULT_BANTIME}
findtime = ${F2B_DEFAULT_FINDTIME}
maxretry = ${F2B_DEFAULT_MAXRETRY}
banaction = ${F2B_BANACTION}
backend = ${F2B_BACKEND}
ignoreip = ${F2B_IGNOREIP}

[sshd]
enabled  = true
port     = ${SSH_PORT}
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
# STEP 12 — SELinux Tuning (AlmaLinux)
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

command -v dnf-automatic &>/dev/null || dnf install -y -q dnf-automatic
if [[ -f /etc/dnf/automatic.conf ]]; then
    sed -i 's/^apply_updates\s*=.*/apply_updates = yes/' /etc/dnf/automatic.conf
    sed -i 's/^upgrade_type\s*=.*/upgrade_type = security/' /etc/dnf/automatic.conf
    grep -q '^apply_updates' /etc/dnf/automatic.conf || echo 'apply_updates = yes' >> /etc/dnf/automatic.conf
    grep -q '^upgrade_type' /etc/dnf/automatic.conf || echo 'upgrade_type = security' >> /etc/dnf/automatic.conf
fi
systemctl enable --now dnf-automatic.timer > /dev/null 2>&1
ok "dnf-automatic timer enabled (AlmaLinux)"
detail "Config : /etc/dnf/automatic.conf"
detail "Type   : security updates only"

# ────────────────────────────────────────────────────────────────
# STEP 14 — Free Port 53
# ────────────────────────────────────────────────────────────────
step 14 "$TOTAL_STEPS" "Free Port 53"

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

# ────────────────────────────────────────────────────────────────
# STEP 15 — Performance & Advanced Hardening
# ────────────────────────────────────────────────────────────────
step 15 "$TOTAL_STEPS" "Performance & Advanced Hardening"

if [[ "$PERF_THP_DISABLE" == "true" ]]; then
    info "Disabling transparent huge pages (lower DNS latency jitter)..."
    for _thp in /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag; do
        [[ -f "$_thp" ]] && echo never > "$_thp" 2>/dev/null || true
    done
    cat > /etc/tmpfiles.d/rahmat-thp.conf << 'EOF'
# RAHMAT — disable THP at boot
w /sys/kernel/mm/transparent_hugepage/enabled - - - - never
w /sys/kernel/mm/transparent_hugepage/defrag - - - - never
EOF
    systemd-tmpfiles --create /etc/tmpfiles.d/rahmat-thp.conf 2>/dev/null || true
    ok "Transparent huge pages disabled"
    detail "Persist : /etc/tmpfiles.d/rahmat-thp.conf"
else
    skip "THP disable (PERF_THP_DISABLE=false)"
fi

if [[ "$PERF_CPU_GOVERNOR" == "true" ]]; then
    if command -v cpupower &>/dev/null; then
        info "Setting CPU governor to performance..."
        if cpupower frequency-set -g performance &>/dev/null; then
            ok "CPU governor → performance"
        else
            warn "cpupower could not set performance governor (VM or unsupported CPU)"
        fi
        if has_systemd && [[ ! -f /etc/systemd/system/rahmat-cpugovernor.service ]]; then
            cat > /etc/systemd/system/rahmat-cpugovernor.service << 'EOF'
[Unit]
Description=RAHMAT CPU performance governor
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/cpupower frequency-set -g performance

[Install]
WantedBy=multi-user.target
EOF
            svc_daemon_reload
            systemctl enable rahmat-cpugovernor.service > /dev/null 2>&1
            detail "Boot unit : rahmat-cpugovernor.service"
        fi
    else
        warn "cpupower not found — install kernel-tools"
    fi
else
    skip "CPU performance governor (PERF_CPU_GOVERNOR=false)"
fi

if [[ "$HARDEN_CHRONY" == "true" ]]; then
    info "Configuring chrony (accurate time for TLS/logs)..."
    systemctl enable --now chronyd > /dev/null 2>&1 || systemctl enable --now chrony > /dev/null 2>&1 || true
    if chronyc tracking &>/dev/null || timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
        ok "chrony enabled — NTP synchronized"
    else
        ok "chrony enabled (sync may take a minute)"
    fi
    detail "Service : chronyd"
else
    skip "chrony (HARDEN_CHRONY=false)"
fi

if [[ "$HARDEN_AUDITD" == "true" ]]; then
    info "Configuring auditd rules (SSH, rahmat, firewall, Docker)..."
    mkdir -p /etc/audit/rules.d
    cat > /etc/audit/rules.d/rahmat.rules << 'EOF'
# RAHMAT — audit critical config changes
-w /etc/ssh/sshd_config -p wa -k rahmat_sshd
-w /etc/ssh/sshd_config.d/ -p wa -k rahmat_sshd
-w /etc/rahmat/ -p wa -k rahmat_config
-w /etc/firewalld/ -p wa -k rahmat_firewall
-w /etc/docker/daemon.json -p wa -k rahmat_docker
-w /etc/sysctl.d/99-rahmat-dns.conf -p wa -k rahmat_sysctl
-w /etc/sysctl.d/99-rahmat-ddos.conf -p wa -k rahmat_sysctl
EOF
    if command -v augenrules &>/dev/null; then
        augenrules --load > /dev/null 2>&1 || true
    fi
    systemctl enable --now auditd > /dev/null 2>&1 || true
    ok "auditd rules loaded → /etc/audit/rules.d/rahmat.rules"
    detail "Query   : ausearch -k rahmat_sshd"
else
    skip "auditd (HARDEN_AUDITD=false)"
fi

if [[ "$HARDEN_DISABLE_UNUSED_SERVICES" == "true" ]]; then
    info "Disabling unused services..."
    _disabled=0
    for _svc in avahi-daemon cups bluetooth; do
        if systemctl cat "${_svc}.service" &>/dev/null; then
            if systemctl is-enabled --quiet "${_svc}.service" 2>/dev/null; then
                systemctl disable --now "${_svc}.service" > /dev/null 2>&1 || true
                detail "disabled: ${_svc}"
                _disabled=$((_disabled + 1))
            else
                skip "${_svc} (already disabled)"
            fi
        fi
    done
    if [[ $_disabled -gt 0 ]]; then
        ok "${_disabled} unused service(s) disabled"
    else
        ok "No unused services needed disabling"
    fi
else
    skip "unused service cleanup (HARDEN_DISABLE_UNUSED_SERVICES=false)"
fi

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
if [[ "$SSH_FIREWALL_MODE" == "whitelist" ]]; then
    echo -e "  ${HACK}║${RESET}  SSH firewall  ${HACK_DIM}:${RESET}  whitelist → ${SSH_WHITELIST[*]}"
elif [[ "$SSH_FIREWALL_MODE" == "public" ]]; then
    echo -e "  ${HACK}║${RESET}  SSH firewall  ${HACK_DIM}:${RESET}  ${HACK_WARN}port ${SSH_PORT} open to all${RESET}"
else
    echo -e "  ${HACK}║${RESET}  SSH firewall  ${HACK_DIM}:${RESET}  ${HACK_ERR}port ${SSH_PORT} blocked${RESET}"
fi
echo -e "  ${HACK}║${RESET}  Fail2Ban      ${HACK_DIM}:${RESET}  ${F2B_JAIL:-/etc/fail2ban/jail.d/rahmat.local}"
echo -e "  ${HACK}║${RESET}  DDoS rules    ${HACK_DIM}:${RESET}  ${DDOS_SCRIPT:-/etc/rahmat/apply-ddos-rules.sh}"
echo -e "  ${HACK}║${RESET}  DDoS service  ${HACK_DIM}:${RESET}  $(has_systemd && echo 'rahmat-ddos.service' || echo 'rahmat-network.start')"
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
FW_NAME="firewalld"
FW_STATE=$(systemctl is-active firewalld 2>/dev/null || echo "unknown")

echo -e "  ${HACK}╔══[NET] FIREWALL :: ${FW_NAME} ═══════════════════════╗${RESET}"
echo -e "  ${HACK}║${RESET}  Status     ${HACK_DIM}:${RESET}  ${HACK}${FW_STATE}${RESET}"
if [[ "$SSH_FIREWALL_MODE" == "whitelist" ]]; then
    echo -e "  ${HACK}║${RESET}  ${HACK}[+]${RESET}  ${BOLD} ${SSH_PORT}${RESET}/tcp  ${HACK_DIM}::${RESET}  SSH (whitelist only)"
elif [[ "$SSH_FIREWALL_MODE" == "public" ]]; then
    echo -e "  ${HACK}║${RESET}  ${HACK_WARN}[!]${RESET}  ${BOLD} ${SSH_PORT}${RESET}/tcp  ${HACK_DIM}::${RESET}  SSH (open to all)"
else
    echo -e "  ${HACK}║${RESET}  ${HACK_ERR}[x]${RESET}  ${BOLD} ${SSH_PORT}${RESET}/tcp  ${HACK_DIM}::${RESET}  SSH (blocked)"
fi
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
if [[ "$TCP_BBR_ENABLED" == "true" ]]; then
    echo -e "  ${HACK}║${RESET}  TCP BBR       ${HACK_DIM}:${RESET}  $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo n/a) / qdisc $(sysctl -n net.core.default_qdisc 2>/dev/null || echo n/a)"
fi

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

# ── Phase 15 extras ───────────────────────────────────────────────
echo -e "  ${HACK}╔══[OPT] PERF & ADVANCED HARDENING ═════════════════╗${RESET}"
if [[ "$PERF_THP_DISABLE" == "true" ]]; then
    _thp_state=$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | awk '{print $1}' | tr -d '[]' || echo n/a)
    echo -e "  ${HACK}║${RESET}  THP           ${HACK_DIM}:${RESET}  ${_thp_state}"
else
    echo -e "  ${HACK}║${RESET}  THP           ${HACK_DIM}:${RESET}  ${HACK_DIM}unchanged${RESET}"
fi
if [[ "$PERF_CPU_GOVERNOR" == "true" ]] && command -v cpupower &>/dev/null; then
    echo -e "  ${HACK}║${RESET}  CPU governor  ${HACK_DIM}:${RESET}  $(cpupower frequency-info -p 2>/dev/null | awk -F: '{print $2}' | xargs || echo n/a)"
else
    echo -e "  ${HACK}║${RESET}  CPU governor  ${HACK_DIM}:${RESET}  ${HACK_DIM}default${RESET}"
fi
echo -e "  ${HACK}║${RESET}  netdev_budget ${HACK_DIM}:${RESET}  $(sysctl -n net.core.netdev_budget 2>/dev/null || echo n/a) / $(sysctl -n net.core.netdev_budget_usecs 2>/dev/null || echo n/a) usecs"
if [[ "$HARDEN_CHRONY" == "true" ]]; then
    echo -e "  ${HACK}║${RESET}  chrony        ${HACK_DIM}:${RESET}  $(systemctl is-active chronyd 2>/dev/null || systemctl is-active chrony 2>/dev/null || echo inactive)"
else
    echo -e "  ${HACK}║${RESET}  chrony        ${HACK_DIM}:${RESET}  ${HACK_DIM}skipped${RESET}"
fi
if [[ "$HARDEN_AUDITD" == "true" ]]; then
    echo -e "  ${HACK}║${RESET}  auditd        ${HACK_DIM}:${RESET}  $(systemctl is-active auditd 2>/dev/null || echo inactive)"
    echo -e "  ${HACK}║${RESET}  audit rules   ${HACK_DIM}:${RESET}  /etc/audit/rules.d/rahmat.rules"
else
    echo -e "  ${HACK}║${RESET}  auditd        ${HACK_DIM}:${RESET}  ${HACK_DIM}skipped${RESET}"
fi
echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── AlmaLinux notes ──────────────────────────────────────────────
echo -e "  ${HACK}╔══[ALM] ALMALINUX NOTES ══════════════════════════╗${RESET}"
echo -e "  ${HACK}║${RESET}  Distro      ${HACK_DIM}:${RESET}  ${OS_DISPLAY}"
echo -e "  ${HACK}║${RESET}  Firewall    ${HACK_DIM}:${RESET}  firewalld"
echo -e "  ${HACK}║${RESET}  SELinux     ${HACK_DIM}:${RESET}  $(getenforce 2>/dev/null || echo 'N/A')"
echo -e "  ${HACK}║${RESET}  EPEL repo   ${HACK_DIM}:${RESET}  ${HACK}enabled${RESET}"
echo -e "  ${HACK}║${RESET}  Docker src  ${HACK_DIM}:${RESET}  ${DOCKER_DNF_REPO#https://}"
echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"

print_final_summary
