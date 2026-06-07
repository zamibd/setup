# RAHMAT — DNS SaaS Server Setup

Production-oriented Linux host bootstrap for **DNS SaaS** nodes. Prepares the OS for DNS **53** (UDP/TCP), **DoT 853**, **DoH 443**, Docker workloads, hardening, and DDoS mitigation.

| | |
|---|---|
| **Version** | `2.7.0` |
| **Script** | `setup.sh` |
| **Config** | `.env` → `/etc/rahmat/.env` |
| **Author** | [RAHMAT](https://github.com/zamibd/setup) |
| **License** | Use at your own risk — review before production |

---

## One-click install

> Requires **root**. Test on staging first. Review `.env` before production.

### curl (recommended — download + run)

```bash
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/setup.sh -o setup.sh && \
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/.env.example -o .env && \
chmod +x setup.sh && sudo bash setup.sh
```

### curl (pipe — fastest)

```bash
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/setup.sh | sudo bash
```

### wget (download + run)

```bash
wget -qO setup.sh https://raw.githubusercontent.com/zamibd/setup/main/setup.sh && \
wget -qO .env https://raw.githubusercontent.com/zamibd/setup/main/.env.example && \
chmod +x setup.sh && sudo bash setup.sh
```

### wget (pipe)

```bash
wget -qO- https://raw.githubusercontent.com/zamibd/setup/main/setup.sh | sudo bash
```

### Copy-paste URLs

| Resource | URL |
|----------|-----|
| **setup.sh (raw)** | `https://raw.githubusercontent.com/zamibd/setup/main/setup.sh` |
| **.env.example (raw)** | `https://raw.githubusercontent.com/zamibd/setup/main/.env.example` |
| **GitHub repo** | `https://github.com/zamibd/setup` |

If your default branch is not `main`, replace `main` with `master` in the URLs above.

---

## Supported operating systems

| OS | Versions | Package manager | Firewall |
|----|----------|-----------------|----------|
| **Ubuntu** | 22.04+ (LTS & interim) | `apt` | UFW |
| **Debian** | All stable/testing | `apt` | UFW |
| **AlmaLinux** | All (8, 9, 10+) | `dnf` | firewalld |
| **Rocky Linux** | All | `dnf` | firewalld |
| **RHEL** | 8, 9, 10+ | `dnf` | firewalld |
| **CentOS Stream** | All | `dnf` | firewalld |
| **Oracle Linux** | All | `dnf` | firewalld |
| **Fedora** | Current releases | `dnf` | firewalld |

**Ubuntu-based derivatives** (Mint, Pop!\_OS, Zorin, Kubuntu, etc.) — Ubuntu 22.04+ base required.

**Debian-based derivatives** (Kali, Parrot, Devuan, etc.) — supported via Debian path.

**Architecture:** `x86_64` / `amd64` (primary). ARM64 where Docker CE repos exist for your distro.

---

## What the installer does (14 phases)

| Phase | Title | Summary |
|-------|--------|---------|
| 01 | OS Detection | Detects distro, Docker repo suite, family |
| 02 | System Update | `apt upgrade` / `dnf update` + EPEL (RHEL family) |
| 03 | Essential Packages | curl, git, fail2ban, firewall tools, build deps |
| 04 | Docker | Docker CE, Compose plugin, `daemon.json` |
| 05 | Timezone | Sets timezone from `.env` (default `Asia/Dhaka`) |
| 06 | Swap & Limits | swapfile + `limits.conf` (nofile/nproc) |
| 07 | Kernel Tuning | DNS/DoT sysctl (53 udp/tcp, 853 tcp) |
| 08 | Firewall | Opens service ports, blocks ICMP ping |
| 09 | DDoS Protection | iptables rate limits + `rahmat-ddos.service` |
| 10 | SSH Hardening | Keys, whitelist, `sshd` drop-in |
| 11 | Fail2Ban | `sshd` + `recidive` jails |
| 12 | SELinux | DNS/Docker booleans (RHEL family only) |
| 13 | Auto Updates | `unattended-upgrades` / `dnf-automatic` |
| 14 | Free Port 53 | Stops systemd-resolved, static `resolv.conf` |

---

## Systemd services

Services **enabled/started** or **configured** by the installer:

| Service | Purpose | Check status |
|---------|---------|----------------|
| `docker` | Container runtime | `systemctl status docker` |
| `rahmat-ddos.service` | DDoS iptables rules (boot) | `systemctl status rahmat-ddos` |
| `fail2ban` | SSH brute-force protection | `systemctl status fail2ban` |
| `ufw` | Firewall (Debian/Ubuntu) | `ufw status` |
| `firewalld` | Firewall (RHEL family) | `systemctl status firewalld` |
| `unattended-upgrades` | Auto security patches (apt) | `systemctl status unattended-upgrades` |
| `dnf-automatic.timer` | Auto security patches (dnf) | `systemctl status dnf-automatic.timer` |
| `ssh` / `sshd` | SSH (hardened drop-in) | `systemctl status sshd` |

**Reload DDoS rules only** (after editing `.env`):

```bash
sudo systemctl restart rahmat-ddos
```

---

## Config & file paths

| File / path | Description |
|-------------|-------------|
| `.env` | Local config (edit before install) |
| `/etc/rahmat/.env` | System copy (synced on run) |
| `/etc/rahmat/ddos.conf` | DDoS rate limits (from `.env`) |
| `/etc/rahmat/apply-ddos-rules.sh` | iptables DDoS script |
| `/etc/sysctl.d/99-rahmat-dns.conf` | DNS/DoT kernel tuning |
| `/etc/sysctl.d/99-rahmat-ddos.conf` | DDoS kernel hardening |
| `/etc/security/limits.d/99-rahmat-dns.conf` | File descriptor limits |
| `/etc/systemd/system.conf.d/99-rahmat-dns.conf` | systemd global limits |
| `/etc/docker/daemon.json` | Docker log rotation & storage |
| `/etc/ssh/sshd_config.d/99-rahmat.conf` | SSH hardening |
| `/etc/fail2ban/jail.d/rahmat.local` | Fail2Ban jails |
| `/etc/modules-load.d/rahmat-dns.conf` | conntrack/hashlimit modules |

---

## Firewall ports opened

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH (rate-limited; whitelist in phase 10) |
| 53 | UDP | DNS (primary) |
| 53 | TCP | DNS (fallback) |
| 80 | TCP | HTTP / ACME |
| 443 | TCP | HTTPS / DoH |
| 853 | TCP | DoT (DNS-over-TLS) |

ICMP ping is **blocked** (kernel + firewall).

---

## Default DDoS limits (`.env`)

Tuned for **~1000 mobile DoT users** (CGNAT-friendly):

| Target | Rate | Burst | Concurrent |
|--------|------|-------|------------|
| DNS 53 UDP | 300/sec per IP | 600 | — |
| DNS 53 TCP | 50/sec per IP | 100 | 30 |
| **DoT 853** | **200/sec per IP** | **400** | **500** |
| DoH 443 | 80/sec per IP | 160 | — |
| SYN (global) | 2000/sec | 4000 | — |

Edit in `.env`, then re-run `setup.sh` or `systemctl restart rahmat-ddos`.

---

## Packages installed

### Debian / Ubuntu (`apt`)

`curl` `wget` `git` `ufw` `fail2ban` `iptables` `ipset` `unattended-upgrades` `ca-certificates` `gnupg` `lsb-release` `htop` `net-tools` `make` `build-essential` + **Docker CE** stack

### RHEL family (`dnf`)

`curl` `wget` `git` `fail2ban` `iptables` `ipset` `dnf-automatic` `ca-certificates` `gnupg2` `htop` `net-tools` `make` `gcc` `gcc-c++` `firewalld` `dnf-plugins-core` `policycoreutils-python-utils` + **Docker CE** stack

---

## Configuration (`.env`)

```bash
cp .env.example .env
nano .env
sudo bash setup.sh
```

**Production minimum** — set before deploy:

```bash
SSH_PUBLIC_KEY="ssh-ed25519 AAAA... your-key"
SSH_WHITELIST_IPS="203.0.113.10/32"
SSH_DISABLE_PASSWORD="yes"
INTERACTIVE_PROMPTS="false"
```

See `.env.example` for all variables: timezone, resolvers, swap, sysctl, Docker, DDoS, SSH, Fail2Ban.

---

## Manual install (local clone)

```bash
git clone https://github.com/zamibd/setup.git
cd setup
cp .env.example .env
nano .env
sudo bash setup.sh
```

---

## Post-install checks

```bash
# Services
systemctl is-active docker rahmat-ddos fail2ban

# Ports free for DNS deploy
ss -tulnp | grep -E ':53|:853'

# DDoS chain
sudo iptables -L RAHMAT-DDoS -n -v

# Config
cat /etc/rahmat/.env
```

Recommended: **reboot once** after first install to apply all kernel settings.

---

## What this script does NOT do

- Does **not** deploy the DNS resolver application (bind, unbound, CoreDNS, etc.)
- Does **not** issue TLS certificates for DoT — you add that in your stack
- Does **not** replace upstream DDoS scrubbing for large volumetric attacks

This script prepares the **host**. Deploy your DNS SaaS stack on Docker after setup completes.

---

## Troubleshooting

| Issue | Action |
|-------|--------|
| Locked out of SSH | Use provider console; fix `/etc/ssh/sshd_config.d/99-rahmat.conf` |
| Docker won't start | `journalctl -xeu docker.service` |
| DDoS blocks legit users | Raise `DOT_*` in `.env`, restart `rahmat-ddos` |
| Port 53 in use | Stop `systemd-resolved` / `named`; re-run phase 14 |
| Fail2Ban ban | `fail2ban-client status sshd` |

---

## Links

- **Repository:** https://github.com/zamibd/setup
- **Raw setup.sh:** https://raw.githubusercontent.com/zamibd/setup/main/setup.sh
- **Issues:** https://github.com/zamibd/setup/issues

---

**RAHMAT DNS-INFRA · v2.7.0 · DNS 53 · DoT 853 · DoH 443**
