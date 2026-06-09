# RAHMAT — DNS SaaS Server Setup

Production-oriented Linux host bootstrap for **DNS SaaS** nodes. Prepares the OS for DNS **53** (UDP/TCP), **DoT 853**, **DoH 443**, Docker workloads, hardening, and DDoS mitigation.

| | |
|---|---|
| **Version** | `3.0.0` |
| **Script** | `setup.sh` |
| **Config** | `.env` → `/etc/rahmat/.env` |
| **Author** | [RAHMAT](https://github.com/zamibd/setup) |
| **License** | Use at your own risk — review before production |

---

## One-click install

> Requires **root** (or `sudo`). Test on staging first. Review `.env` before production.

### curl (recommended — download, edit .env, run)

```bash
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/setup.sh -o setup.sh && \
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/.env.example -o .env && \
nano .env && \
chmod +x setup.sh && sudo bash setup.sh
```

Set at minimum in `.env` before running:

```bash
SSH_PUBLIC_KEY="ssh-ed25519 AAAA... your-key"
SSH_WHITELIST_IPS="YOUR_PUBLIC_IP/32"
SSH_OPEN_PUBLIC="false"
SSH_DISABLE_PASSWORD="yes"
```

If you skip `nano .env`, setup opens the editor at start (interactive terminal only). Phase 10 does **not** prompt for SSH keys or IPs.

### curl (pipe — non-interactive only)

```bash
# Requires /etc/rahmat/.env with SSH_PUBLIC_KEY set first
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/setup.sh | sudo bash
```

### wget (download + run)

```bash
wget -qO setup.sh https://raw.githubusercontent.com/zamibd/setup/main/setup.sh && \
wget -qO .env https://raw.githubusercontent.com/zamibd/setup/main/.env.example && \
nano .env && \
chmod +x setup.sh && sudo bash setup.sh
```

### wget (pipe)

```bash
wget -qO- https://raw.githubusercontent.com/zamibd/setup/main/setup.sh | bash
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
| **AlmaLinux** | 8, 9, 10+ | `dnf` | firewalld |

**Architecture:** `x86_64` / `amd64` (primary). ARM64 where Docker CE repos exist for AlmaLinux.

---

## What the installer does (15 phases)

| Phase | Title | Summary |
|-------|--------|---------|
| 01 | OS Detection | Verifies AlmaLinux, Docker repo, family |
| 02 | System Update | `dnf update` + EPEL |
| 03 | Essential Packages | curl, git, fail2ban, firewall tools, build deps |
| 04 | Docker | Docker CE, Compose plugin, `daemon.json` |
| 05 | Timezone | Sets timezone from `.env` (default `Asia/Dhaka`) |
| 06 | Swap & Limits | swapfile + `limits.conf` (nofile/nproc) |
| 07 | Kernel Tuning | DNS/DoT sysctl (53 udp/tcp, 853 tcp) + TCP BBR |
| 08 | Firewall | Opens service ports, blocks ICMP ping (firewalld) |
| 09 | DDoS Protection | iptables rate limits + `rahmat-ddos.service` |
| 10 | SSH Hardening | Applies `.env` key, whitelist, `sshd` drop-in (no prompts) |
| 11 | Fail2Ban | `sshd` + `recidive` jails |
| 12 | SELinux | DNS/Docker booleans |
| 13 | Auto Updates | `dnf-automatic` |
| 14 | Free Port 53 | Stops systemd-resolved, static `resolv.conf` |
| 15 | Perf & Hardening | THP off, CPU governor, chrony, auditd, unused services |

---

## Systemd services

Services **enabled/started** or **configured** by the installer:

| Service | Purpose | Check status |
|---------|---------|----------------|
| `docker` | Container runtime | `systemctl status docker` |
| `rahmat-ddos.service` | DDoS iptables rules (boot) | `systemctl status rahmat-ddos` |
| `fail2ban` | SSH brute-force protection | `systemctl status fail2ban` |
| `firewalld` | Firewall | `systemctl status firewalld` |
| `dnf-automatic.timer` | Auto security patches | `systemctl status dnf-automatic.timer` |
| `chronyd` | Accurate NTP time (TLS/logs) | `systemctl status chronyd` |
| `auditd` | Config change auditing | `systemctl status auditd` |
| `rahmat-cpugovernor.service` | CPU performance governor at boot | `systemctl status rahmat-cpugovernor` |
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
| `/etc/tmpfiles.d/rahmat-thp.conf` | Disable transparent huge pages |
| `/etc/audit/rules.d/rahmat.rules` | auditd watches (SSH, rahmat, firewall) |

---

## Firewall ports opened

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH (whitelist only by default; set `SSH_WHITELIST_IPS` or `SSH_OPEN_PUBLIC=true`) |
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

Edit in `.env`, then re-run `setup.sh` or restart DDoS rules (`systemctl restart rahmat-ddos`).

---

## Packages installed

`curl` `wget` `git` `nano` `fail2ban` `iptables` `ipset` `dnf-automatic` `chrony` `audit` `kernel-tools` `ca-certificates` `gnupg2` `htop` `net-tools` `make` `gcc` `gcc-c++` `firewalld` `dnf-plugins-core` `policycoreutils-python-utils` + **Docker CE** stack

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
SSH_OPEN_PUBLIC="false"
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

## Fresh VPS test (recommended)

```bash
# 1. On your laptop — copy your public key
cat ~/.ssh/id_ed25519.pub

# 2. On the new VPS (as root)
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/setup.sh -o setup.sh
curl -fsSL https://raw.githubusercontent.com/zamibd/setup/main/.env.example -o .env
nano .env   # set SSH_PUBLIC_KEY + SSH_WHITELIST_IPS to your IP
chmod +x setup.sh && bash setup.sh

# 3. After setup — verify SSH is NOT open to the world
firewall-cmd --list-ports              # should NOT show 22/tcp (unless SSH_OPEN_PUBLIC=true)
firewall-cmd --list-rich-rules         # should show rahmat-ssh-allow ipset rule
firewall-cmd --ipset=list rahmat-ssh-allow

# 4. Reboot, then SSH in with your key
reboot
ssh -i ~/.ssh/id_ed25519 root@YOUR_VPS_IP
```

## Post-install checks

```bash
# Services
systemctl is-active docker firewalld rahmat-ddos fail2ban sshd

# SSH firewall (whitelist mode)
firewall-cmd --list-ports
firewall-cmd --list-rich-rules
firewall-cmd --ipset=list rahmat-ssh-allow

# SSH hardening
sshd -t
grep -E '^(Port|PermitRootLogin|PasswordAuthentication|AllowUsers)' \
  /etc/ssh/sshd_config.d/99-rahmat.conf

# Ports free for DNS deploy
ss -tulnp | grep -E ':53|:853'

# DDoS chain
iptables -L RAHMAT-DDoS -n -v

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
| Locked out of SSH | Provider console — see below |
| Port 22 open to everyone | Set `SSH_OPEN_PUBLIC=false` and `SSH_WHITELIST_IPS` in `.env`, re-run `setup.sh` |
| Docker won't start | `journalctl -xeu docker.service` |
| DDoS blocks legit users | Raise `DOT_*` in `.env`, restart `rahmat-ddos` |
| Port 53 in use | Stop `systemd-resolved` / `named`; re-run phase 14 |
| Fail2Ban ban | `fail2ban-client status sshd` |

### SSH lockout recovery (provider console)

Setup never prompts for SSH keys — set `SSH_PUBLIC_KEY` in `.env` before running. If the key is missing, root password login stays enabled so you are not locked out.

1. Open your VPS **serial / web console** (not SSH).
2. Log in as root with the provider password.
3. Quick restore (password login):

```bash
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config.d/99-rahmat.conf
sshd -t && systemctl reload sshd
```

4. Or install your key and keep hardening:

```bash
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo 'ssh-ed25519 AAAA... your-key' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

5. Check other blockers:

```bash
fail2ban-client status sshd          # unban: fail2ban-client set sshd unbanip YOUR_IP
firewall-cmd --list-ports
firewall-cmd --list-rich-rules
firewall-cmd --ipset=list rahmat-ssh-allow
```

**Before production**, set `SSH_PUBLIC_KEY`, `SSH_WHITELIST_IPS`, and `SSH_OPEN_PUBLIC=false` in `.env`.

---

## Links

- **Repository:** https://github.com/zamibd/setup
- **Raw setup.sh:** https://raw.githubusercontent.com/zamibd/setup/main/setup.sh
- **Issues:** https://github.com/zamibd/setup/issues

---

**RAHMAT DNS-INFRA · v3.0.0 · DNS 53 · DoT 853 · DoH 443**
