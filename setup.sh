#!/usr/bin/env bash
# ================================================================
#  RAHMAT — DNS SaaS Server Setup Script
#  Supports : AlmaLinux (8, 9, 10+)
#  Author   : RAHMAT
#  GitHub   : https://github.com/zamibd/setup/setup.sh
#  Version  : 3.1.0
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
SCRIPT_VERSION="3.1.0"
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
        if curl -fsSL "https://raw.githubusercontent.com/zamibd/setup/main/.env.example" -o "$ENV_FILE" 2>/dev/null; then
            ENV_JUST_CREATED=true
            return 0
        fi
    fi
    # Create minimal blank .env
    cat > "$ENV_FILE" << 'EOF'
# RAHMAT — DNS SaaS Server Config
# Generated automatically — edit below

GITHUB_URL=https://github.com/zamibd/setup/setup.sh
TIMEZONE=Asia/Dhaka
SSH_PORT=22
SSH_USER=root
SSH_PUBLIC_KEY=
SSH_WHITELIST_IPS=
SSH_OPEN_PUBLIC=false
SSH_DISABLE_PASSWORD=auto
SWAP_ENABLED=true
SWAP_SIZE_GB=2
EOF
    ENV_JUST_CREATED=true
    return 0
}

# Bootstrap .env before first load
ensure_env_file
reload_config

TOTAL_STEPS=15

# ── Colors & Styles ──────────────────────────────────────────────
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

HACK="${BGREEN}"
HACK_DIM="${DIM}${GREEN}"
HACK_MUTED="${DIM}${GREEN}"
HACK_WARN="${BYELLOW}"
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

# ── Interactive helpers ──────────────────────────────────────────
has_tty() {
    [[ -t 0 ]] || { [[ -r /dev/tty ]] && [[ -w /dev/tty ]]; }
}

is_interactive() {
    [[ "${INTERACTIVE_PROMPTS}" == "true" ]] && has_tty
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

# ── Save a value into .env ───────────────────────────────────────
_save_env_value() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$ENV_FILE"
    else
        echo "${key}=\"${val}\"" >> "$ENV_FILE"
    fi
}

# ── Interactive terminal config collector ────────────────────────
collect_config_interactively() {
    echo ""
    echo -e "  ${HACK}╔══[CONFIG] INITIAL SETUP ══════════════════════════╗${RESET}"
    echo -e "  ${HACK}║${RESET}  কিছু তথ্য দিতে হবে — install শুরু হবে পরে"
    echo -e "  ${HACK}║${RESET}  Enter চাপলে default value থাকবে"
    echo -e "  ${HACK}╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""

    # ── SSH Public Key ───────────────────────────────────────────
    if [[ -z "${SSH_PUBLIC_KEY:-}" ]]; then
        echo -e "  ${HACK}[1/5]${RESET}  ${BOLD}SSH Public Key${RESET} ${HACK_DIM}(ssh-ed25519 AAAA... / ssh-rsa AAAA...)${RESET}"
        echo -e "       ${HACK_DIM}Tip: cat ~/.ssh/id_ed25519.pub${RESET}"
        while true; do
            echo -ne "  ${HACK}>#${RESET}  "
            read -r _input_key </dev/tty
            _input_key="${_input_key// /}"
            # re-read with spaces (trim leading/trailing only)
            echo -ne "  ${HACK}>#${RESET}  "
            read -r _input_key </dev/tty
            _input_key="$(echo "$_input_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            if [[ -z "$_input_key" ]]; then
                warn "SSH key cannot be empty — try again"
                continue
            fi
            if valid_ssh_pubkey "$_input_key"; then
                SSH_PUBLIC_KEY="$_input_key"
                ok "SSH public key accepted"
                break
            else
                warn "Invalid key format — try again (must start with ssh-ed25519 / ssh-rsa / ecdsa-sha2-nistp256)"
            fi
        done
    else
        ok "[1/5] SSH_PUBLIC_KEY already set — skipping"
    fi

    echo ""

    # ── SSH Whitelist IPs ────────────────────────────────────────
    echo -e "  ${HACK}[2/5]${RESET}  ${BOLD}SSH Whitelist IPs${RESET} ${HACK_DIM}(comma separated: 1.2.3.4,5.6.7.8/24)${RESET}"
    if [[ -n "$CURRENT_SSH_IP" ]]; then
        echo -e "       ${HACK_DIM}Current session IP: ${BWHITE}${CURRENT_SSH_IP}${RESET} ${HACK_DIM}(Enter = use this)${RESET}"
    else
        echo -e "       ${HACK_DIM}Enter = leave empty (current session IP will be auto-allowed)${RESET}"
    fi
    if [[ -z "${SSH_WHITELIST_IPS:-}" ]]; then
        echo -ne "  ${HACK}>#${RESET}  "
        read -r _input_ips </dev/tty
        _input_ips="$(echo "$_input_ips" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [[ -z "$_input_ips" && -n "$CURRENT_SSH_IP" ]]; then
            SSH_WHITELIST_IPS="$CURRENT_SSH_IP"
            ok "Whitelist set to current session IP: ${SSH_WHITELIST_IPS}"
        elif [[ -n "$_input_ips" ]]; then
            SSH_WHITELIST_IPS="$_input_ips"
            ok "Whitelist IPs set: ${SSH_WHITELIST_IPS}"
        else
            warn "No IPs entered — SSH port may be blocked (set SSH_OPEN_PUBLIC=true to allow all)"
        fi
    else
        ok "[2/5] SSH_WHITELIST_IPS already set: ${SSH_WHITELIST_IPS} — skipping"
    fi

    echo ""

    # ── SSH Port ─────────────────────────────────────────────────
    echo -e "  ${HACK}[3/5]${RESET}  ${BOLD}SSH Port${RESET} ${HACK_DIM}(default: ${SSH_PORT:-22}, Enter = keep)${RESET}"
    echo -ne "  ${HACK}>#${RESET}  "
    read -r _input_port </dev/tty
    _input_port="$(echo "$_input_port" | tr -d '[:space:]')"
    if [[ "$_input_port" =~ ^[0-9]+$ ]] && [[ "$_input_port" -ge 1 && "$_input_port" -le 65535 ]]; then
        SSH_PORT="$_input_port"
        ok "SSH port set: ${SSH_PORT}"
    else
        SSH_PORT="${SSH_PORT:-22}"
        ok "SSH port unchanged: ${SSH_PORT}"
    fi

    echo ""

    # ── Timezone ─────────────────────────────────────────────────
    echo -e "  ${HACK}[4/5]${RESET}  ${BOLD}Timezone${RESET} ${HACK_DIM}(default: ${TIMEZONE}, Enter = keep)${RESET}"
    echo -e "       ${HACK_DIM}Examples: Asia/Dhaka · Asia/Kolkata · UTC · Asia/Dubai${RESET}"
    echo -ne "  ${HACK}>#${RESET}  "
    read -r _input_tz </dev/tty
    _input_tz="$(echo "$_input_tz" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ -n "$_input_tz" ]]; then
        if timedatectl list-timezones 2>/dev/null | grep -qx "$_input_tz"; then
            TIMEZONE="$_input_tz"
            ok "Timezone set: ${TIMEZONE}"
        else
            warn "Unknown timezone '${_input_tz}' — keeping default: ${TIMEZONE}"
        fi
    else
        ok "Timezone unchanged: ${TIMEZONE}"
    fi

    echo ""

    # ── Swap Size ────────────────────────────────────────────────
    echo -e "  ${HACK}[5/5]${RESET}  ${BOLD}Swap Size (GB)${RESET} ${HACK_DIM}(default: ${SWAP_SIZE_GB}GB, 0 = disable, Enter = keep)${RESET}"
    echo -ne "  ${HACK}>#${RESET}  "
    read -r _input_swap </dev/tty
    _input_swap="$(echo "$_input_swap" | tr -d '[:space:]')"
    if [[ "$_input_swap" =~ ^[0-9]+$ ]]; then
        if [[ "$_input_swap" -eq 0 ]]; then
            SWAP_ENABLED="false"
            ok "Swap disabled"
        else
            SWAP_SIZE_GB="$_input_swap"
            SWAP_ENABLED="true"
            ok "Swap set: ${SWAP_SIZE_GB}GB"
        fi
    else
        ok "Swap unchanged: ${SWAP_SIZE_GB}GB"
    fi

    # ── Save to .env ─────────────────────────────────────────────
    echo ""
    info "Saving config → ${ENV_FILE}"
    _save_env_value "SSH_PUBLIC_KEY"    "$SSH_PUBLIC_KEY"
    _save_env_value "SSH_WHITELIST_IPS" "$SSH_WHITELIST_IPS"
    _save_env_value "SSH_PORT"          "$SSH_PORT"
    _save_env_value "TIMEZONE"          "$TIMEZONE"
    _save_env_value "SWAP_SIZE_GB"      "$SWAP_SIZE_GB"
    _save_env_value "SWAP_ENABLED"      "$SWAP_ENABLED"

    ok "Config saved — starting installation..."
    echo ""
    echo -e "  ${HACK_MUTED}$(printf '%.0s═' {1..50})${RESET}"
    echo ""
}

env_needs_setup() {
    [[ -z "${SSH_PUBLIC_KEY:-}" ]]
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
        warn "SSH_WHITELIST_IPS empty — auto-allowed current session ${SSH_WHITELIST[0]}"
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
        warn "SSH port ${SSH_PORT}/tcp blocked — set SSH_WHITELIST_IPS or SSH_OPEN_PUBLIC=true"
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
net.ipv4.tcp_syncookies              = 1
net.ipv4.tcp_synack_retries          = 2
net.ipv4.tcp_syn_retries             = 2
net.ipv4.conf.all.rp_filter          = 1
net.ipv4.conf.default.rp_filter      = 1
net.ipv4.icmp_ratelimit              = 100
net.ipv4.icmp_ratemask               = 6168
net.ipv4.conf.all.accept_redirects   = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects     = 0
net.ipv4.conf.default.send_redirects = 0
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
# RAHMAT DDoS rate limits — generated from .env

DNS_UDP_RATE='${DNS_UDP_RATE}'
DNS_UDP_BURST='${DNS_UDP_BURST}'
DNS_TCP_RATE='${DNS_TCP_RATE}'
DNS_TCP_BURST='${DNS_TCP_BURST}'
DNS_TCP_CONN_MAX='${DNS_TCP_CONN_MAX}'
DNS_UDP_MAX_PACKET='${DNS_UDP_MAX_PACKET}'
DOT_RATE='${DOT_RATE}'
DOT_BURST='${DOT_BURST}'
DOT_CONN_MAX='${DOT_CONN_MAX}'
DOH_RATE='${DOH_RATE}'
DOH_BURST='${DOH_BURST}'
SYN_RATE='${SYN_RATE}'
SYN_BURST='${SYN_BURST}'
EOF

    cat > "$DDOS_SCRIPT" << 'EOFSCRIPT'
#!/usr/bin/env bash
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

$IPT -A "$CHAIN" -p udp --dport 53 \
    -m hashlimit --hashlimit-name dns_udp --hashlimit-mode srcip \
    --hashlimit-above "${DNS_UDP_RATE}" --hashlimit-burst "${DNS_UDP_BURST}" -j DROP
DNS_UDP_MAX_PACKET="${DNS_UDP_MAX_PACKET:-1232}"
DNS_UDP_DROP_MIN=$((DNS_UDP_MAX_PACKET + 1))
$IPT -A "$CHAIN" -p udp --dport 53 -m length --length ${DNS_UDP_DROP_MIN}:65535 -j DROP

$IPT -A "$CHAIN" -p tcp --dport 53 -m conntrack --ctstate NEW \
    -m hashlimit --hashlimit-name dns_tcp --hashlimit-mode srcip \
    --hashlimit-above "${DNS_TCP_RATE}" --hashlimit-burst "${DNS_TCP_BURST}" -j DROP
$IPT -A "$CHAIN" -p tcp --dport 53 \
    -m connlimit --connlimit-above "${DNS_TCP_CONN_MAX}" --connlimit-mask 32 --connlimit-saddr -j DROP

$IPT -A "$CHAIN" -p tcp --dport 853 -m conntrack --ctstate NEW \
    -m hashlimit --hashlimit-name dot_new --hashlimit-mode srcip \
    --hashlimit-above "${DOT_RATE}" --hashlimit-burst "${DOT_BURST}" -j DROP
$IPT -A "$CHAIN" -p tcp --dport 853 \
    -m connlimit --connlimit-above "${DOT_CONN_MAX}" --connlimit-mask 32 --connlimit-saddr -j DROP

$IPT -A "$CHAIN" -p tcp --dport 443 -m conntrack --ctstate NEW \
    -m hashlimit --hashlimit-name doh_new --hashlimit-mode srcip \
    --hashlimit-above "${DOH_RATE}" --hashlimit-burst "${DOH_BURST}" -j DROP

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
    printf '  ║%s║\n' "     ${SCRIPT_NAME} ${SCRIPT_PRODUCT} — INSTALLATION COMPLETE          "
    echo '  ╚══════════════════════════════════════════════════════════╝'
    echo -e "${RESET}"

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
    echo -e "      ${HACK_DIM}1.${RESET}  ${BOLD}reboot${RESET}  ${HACK_DIM}(recommended)${RESET}"
    echo -e "      ${HACK_DIM}2.${RESET}  ${BOLD}nano /etc/rahmat/.env${RESET}  ${HACK_DIM}(review settings)${RESET}"
    echo -e "      ${HACK_DIM}3.${RESET}  Deploy DNS resolver on Docker"
    echo -e "      ${HACK_DIM}4.${RESET}  ${BOLD}systemctl restart rahmat-ddos${RESET}  ${HACK_DIM}(after DDoS changes)${RESET}"
    echo ""
    if [[ "${DOCKER_NEEDS_REBOOT:-false}" == "true" ]]; then
        echo -e "  ${HACK_ERR}[!]${RESET}  ${BOLD}REBOOT REQUIRED${RESET} — Docker needs updated kernel modules"
    else
        echo -e "  ${HACK_WARN}[!]${RESET}  ${BOLD}REBOOT RECOMMENDED${RESET} — kernel parameters apply fully after restart"
    fi
    echo -e "  ${HACK}[>]${RESET}  ${BOLD}reboot${RESET}"
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

# ════════════════════════════════════════════════════════════════
# PRE-FLIGHT — Interactive terminal config
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "  ${HACK}[CONFIG]${RESET}  ${BOLD}>> Pre-flight configuration${RESET}"
echo -e "  ${HACK_MUTED}$(printf '%.0s-' {1..50})${RESET}"

if [[ "$ENV_JUST_CREATED" == "true" ]]; then
    ok "Created ${ENV_FILE}"
else
    ok "Using ${ENV_FILE}"
fi

if env_needs_setup; then
    if is_interactive; then
        collect_config_interactively
        reload_config
    else
        fail "SSH_PUBLIC_KEY is empty and terminal is non-interactive — set it in ${ENV_FILE} and re-run"
    fi
else
    ok "Config already complete — skipping interactive setup"
    detail "SSH_PUBLIC_KEY : set"
    detail "SSH_WHITELIST  : ${SSH_WHITELIST_IPS:-auto}"
    detail "SSH_PORT       : ${SSH_PORT}"
    detail "Timezone       : ${TIMEZONE}"
fi

capture_ssh_client_ip
validate_preflight_ssh

# Sync .env to system path
install -d -m 750 /etc/rahmat
if [[ -f "$ENV_FILE" ]]; then
    install -m 640 "$ENV_FILE" /etc/rahmat/.env
    ok "Config synced → /etc/rahmat/.env"
fi

echo ""
ok "Starting installation — phase 1/${TOTAL_STEPS}"
echo ""

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

DOCKER_NF_MODULES=(overlay br_netfilter nf_conntrack nf_nat xt_addrtype xt_conntrack xt_nat)
DOCKER_NEEDS_REBOOT="${DOCKER_NEEDS_REBOOT:-false}"

prepare_docker_dnf_host() {
    info "Preparing RHEL-family host for Docker..."
    local kver
    kver=$(uname -r)

    rpm -q iptables-nft &>/dev/null || dnf install -y -q iptables-nft 2>/dev/null || true

    if ! rpm -q "kernel-modules-extra-${kver}" &>/dev/null; then
        info "Installing kernel-modules-extra for running kernel ${kver}..."
        dnf install -y -q "kernel-modules-extra-${kver}" 2>/dev/null \
            || dnf install -y -q kernel-modules-extra 2>/dev/null \
            || warn "Could not install kernel-modules-extra for ${kver}"
    fi

    for _m in "${DOCKER_NF_MODULES[@]}"; do
        modprobe "$_m" 2>/dev/null || true
    done

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
        warn "Docker daemon not responding — retrying with recovery..."
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
# RAHMAT — DNS workload limits
*               soft    nofile          ${LIMIT_NOFILE}
*               hard    nofile          ${LIMIT_NOFILE}
root            soft    nofile          ${LIMIT_NOFILE}
root            hard    nofile          ${LIMIT_NOFILE}
*               soft    nproc           ${LIMIT_NPROC}
*               hard    nproc           ${LIMIT_NPROC}
EOF
ok "limits.conf → ${LIMITS_FILE}"
detail "nofile max : ${LIMIT_NOFILE}"

SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
if [[ "$SWAP_TOTAL" -gt 0 ]]; then
    ok "Swap already configured ($(numfmt --to=iec $((SWAP_TOTAL * 1024)) 2>/dev/null || echo "${SWAP_TOTAL}KB"))"
elif [[ "$SWAP_ENABLED" != "true" ]]; then
    warn "Swap disabled (SWAP_ENABLED=false)"
else
    info "Creating ${SWAP_SIZE_GB}G swapfile at ${SWAP_FILE}..."
    fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE" 2>/dev/null || \
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE" > /dev/null
    swapon "$SWAP_FILE"
    grep -q "$SWAP_FILE" /etc/fstab || echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab
    ok "Swapfile ${SWAP_SIZE_GB}G active → ${SWAP_FILE}"
fi

# ────────────────────────────────────────────────────────────────
# STEP 7 — Kernel Tuning
# ────────────────────────────────────────────────────────────────
step 7 "$TOTAL_STEPS" "Kernel Tuning — DNS 53 udp/tcp · DoT 853"

SYSCTL_FILE="/etc/sysctl.d/99-rahmat-dns.conf"
SYSTEMD_DNS="/etc/systemd/system.conf.d/99-rahmat-dns.conf"

cat > "$SYSCTL_FILE" << EOF
# RAHMAT — DNS (53 udp/tcp) + DoT (853 tcp)

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

net.netfilter.nf_conntrack_max                     = ${SYSCTL_CONNTRACK_MAX}
net.netfilter.nf_conntrack_udp_timeout             = 30
net.netfilter.nf_conntrack_udp_timeout_stream      = 60
net.netfilter.nf_conntrack_tcp_timeout_syn_recv    = 30
net.netfilter.nf_conntrack_tcp_timeout_established = ${SYSCTL_CONNTRACK_TCP_ESTABLISHED}

net.ipv4.ip_forward                  = 1
net.ipv4.icmp_echo_ignore_all        = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
vm.swappiness                        = ${SYSCTL_SWAPPINESS}
fs.file-max                          = ${SYSCTL_FILE_MAX}
fs.nr_open                           = ${SYSCTL_FILE_MAX}
EOF

if [[ "$TCP_BBR_ENABLED" == "true" ]]; then
    cat >> "$SYSCTL_FILE" << 'EOF'

# TCP BBR
net.core.default_qdisc          = fq
net.ipv4.tcp_congestion_control = bbr
EOF
fi

modprobe nf_conntrack 2>/dev/null || true
[[ "$TCP_BBR_ENABLED" == "true" ]] && modprobe tcp_bbr 2>/dev/null || true

cat > /etc/modules-load.d/rahmat-dns.conf << EOF
nf_conntrack
xt_hashlimit
xt_connlimit
xt_recent
$([[ "$TCP_BBR_ENABLED" == "true" ]] && echo tcp_bbr)
EOF

info "Applying sysctl parameters..."
sysctl -p "$SYSCTL_FILE" > /dev/null 2>&1 || true

if [[ "$TCP_BBR_ENABLED" == "true" ]]; then
    if sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        ok "Kernel tuned — DNS 53/DoT 853 + TCP BBR active"
    else
        ok "Kernel tuned — DNS 53/DoT 853"
        warn "TCP BBR not active — reboot after kernel update"
    fi
else
    ok "Kernel tuned — DNS 53/DoT 853"
fi

mkdir -p /etc/systemd/system.conf.d
if has_systemd; then
    cat > "$SYSTEMD_DNS" << EOF
[Manager]
DefaultLimitNOFILE=${LIMIT_NOFILE}:${LIMIT_NOFILE}
DefaultLimitNPROC=${LIMIT_NPROC}:${LIMIT_NPROC}
EOF
    svc_daemon_reload
    ok "systemd limits → ${SYSTEMD_DNS}"
fi

detail "UDP rmem_min   : $(sysctl -n net.ipv4.udp_rmem_min 2>/dev/null || echo n/a)"
detail "TCP syn_backlog: $(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo n/a)"
detail "conntrack_max  : $(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo n/a)"
detail "fs.file-max    : $(sysctl -n fs.file-max 2>/dev/null || echo n/a)"

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
ok "Default policy → DENY incoming / ALLOW outgoing"
echo ""
open_port_firewalld "53/udp"  "DNS — Plain UDP"
open_port_firewalld "53/tcp"  "DNS — Plain TCP"
open_port_firewalld "853/tcp" "DoT — DNS-over-TLS"
open_port_firewalld "80/tcp"  "HTTP — ACME"
open_port_firewalld "443/tcp" "HTTPS — DoH"
firewall-cmd --permanent --add-icmp-block=echo-request > /dev/null 2>&1 || true
ok "ICMP ping blocked"
firewall-cmd --reload > /dev/null 2>&1
ok "firewalld reloaded & active"

# ────────────────────────────────────────────────────────────────
# STEP 9 — DDoS Protection
# ────────────────────────────────────────────────────────────────
step 9 "$TOTAL_STEPS" "DDoS Protection (DNS / DoT / SYN flood)"

DDOS_SCRIPT="/etc/rahmat/apply-ddos-rules.sh"
DDOS_CONF="/etc/rahmat/ddos.conf"

modprobe xt_hashlimit >/dev/null 2>&1 || true
modprobe xt_connlimit >/dev/null 2>&1 || true
modprobe xt_recent    >/dev/null 2>&1 || true

apply_ddos_kernel
install_ddos_script
apply_ddos_firewalld

ok "DDoS protection active"
detail "Config    : ${DDOS_CONF}"
detail "Script    : ${DDOS_SCRIPT}"
detail "Service   : rahmat-ddos.service"
detail "DNS UDP   : ${DNS_UDP_RATE}/IP burst ${DNS_UDP_BURST}"
detail "DNS TCP   : ${DNS_TCP_RATE}/IP max ${DNS_TCP_CONN_MAX} conn"
detail "DoT 853   : ${DOT_RATE}/IP burst ${DOT_BURST} max ${DOT_CONN_MAX} conn"
detail "DoH 443   : ${DOH_RATE}/IP"
detail "SYN flood : ${SYN_RATE} burst ${SYN_BURST}"

# ────────────────────────────────────────────────────────────────
# STEP 10 — SSH Hardening
# ────────────────────────────────────────────────────────────────
step 10 "$TOTAL_STEPS" "SSH Hardening, Keys & IP Whitelist"

SSHD_DROPIN="/etc/ssh/sshd_config.d/99-rahmat.conf"
SSH_USER="${SSH_USER:-root}"
SSH_PUBKEY="${SSH_PUBLIC_KEY:-}"

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
    warn "No SSH key — password auth will remain enabled"
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
    ROOT_LOGIN=$([[ -n "$SSH_PUBKEY" ]] && echo "prohibit-password" || echo "yes")
else
    ROOT_LOGIN="no"
fi

cat > "$SSHD_DROPIN" << EOF
# RAHMAT — SSH hardening
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
# STEP 11 — Fail2Ban
# ────────────────────────────────────────────────────────────────
step 11 "$TOTAL_STEPS" "Fail2Ban Jail Configuration"

F2B_JAIL="/etc/fail2ban/jail.d/rahmat.local"
mkdir -p /etc/fail2ban/jail.d

F2B_IGNOREIP="127.0.0.1/8 ::1"
for _f2b_ip in "${SSH_WHITELIST[@]}"; do
    F2B_IGNOREIP+=" ${_f2b_ip}"
done

cat > "$F2B_JAIL" << EOF
# RAHMAT — Fail2Ban jails
[DEFAULT]
bantime  = ${F2B_DEFAULT_BANTIME}
findtime = ${F2B_DEFAULT_FINDTIME}
maxretry = ${F2B_DEFAULT_MAXRETRY}
banaction = firewallcmd-rich-rules
backend = systemd
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
ok "Fail2Ban configured → ${F2B_JAIL}"
detail "sshd bantime  : 24h"
detail "recidive      : 7d (repeat offenders)"

# ────────────────────────────────────────────────────────────────
# STEP 12 — SELinux
# ────────────────────────────────────────────────────────────────
step 12 "$TOTAL_STEPS" "SELinux Tuning"

if [[ "$OS_FAMILY" == "rhel" ]] && command -v getenforce &>/dev/null; then
    SEL_MODE=$(getenforce 2>/dev/null || echo "Disabled")
    detail "Current mode : ${SEL_MODE}"

    if [[ "$SEL_MODE" != "Disabled" ]]; then
        setsebool -P container_manage_cgroup on 2>/dev/null || true
        setsebool -P domain_can_tcp_connect_dnsport on 2>/dev/null || true
        setsebool -P nis_enabled off 2>/dev/null || true

        for _port_spec in "tcp 53" "udp 53" "tcp 853"; do
            _proto="${_port_spec%% *}"
            _port="${_port_spec##* }"
            semanage port -a -t dns_port_t -p "$_proto" "$_port" 2>/dev/null || \
            semanage port -m -t dns_port_t -p "$_proto" "$_port" 2>/dev/null || true
        done

        ok "SELinux tuned for DNS + Docker"
        detail "dns_port_t : 53/tcp, 53/udp, 853/tcp"
    else
        skip "SELinux disabled"
    fi
else
    skip "SELinux not applicable"
fi

# ────────────────────────────────────────────────────────────────
# STEP 13 — Auto Security Updates
# ────────────────────────────────────────────────────────────────
step 13 "$TOTAL_STEPS" "Automatic Security Updates"

command -v dnf-automatic &>/dev/null || dnf install -y -q dnf-automatic
if [[ -f /etc/dnf/automatic.conf ]]; then
    sed -i 's/^apply_updates\s*=.*/apply_updates = yes/' /etc/dnf/automatic.conf
    sed -i 's/^upgrade_type\s*=.*/upgrade_type = security/' /etc/dnf/automatic.conf
    grep -q '^apply_updates' /etc/dnf/automatic.conf || echo 'apply_updates = yes' >> /etc/dnf/automatic.conf
    grep -q '^upgrade_type'  /etc/dnf/automatic.conf || echo 'upgrade_type = security' >> /etc/dnf/automatic.conf
fi
systemctl enable --now dnf-automatic.timer > /dev/null 2>&1
ok "dnf-automatic timer enabled"
det
