#!/usr/bin/env bash
# fix-ssh-root.sh
# Debian 12/13: Make root SSH login work reliably after reinstall.
# Default: root can login with SSH key only (safer). Add --allow-password to enable password login.
# Usage examples:
#   sudo bash fix-ssh-root.sh --pubkey "ssh-ed25519 AAAAC3... user@host"
#   sudo bash fix-ssh-root.sh --allow-password --pubkey-file /path/to/id_ed25519.pub
#   sudo bash fix-ssh-root.sh --allow-password --set-root-password   # will prompt securely
#
# Re-run safe any time; it's idempotent.
set -euo pipefail

PORT=22
ALLOW_PASSWORD=0
PUBKEY_STRING=""
PUBKEY_FILE=""
SET_ROOT_PASSWORD=0

log() { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m[✗] %s\033[0m\n" "$*" >&2; }

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    err "请用 root 运行（例如：sudo bash $0 ...）"
    exit 1
  fi
}

usage() {
  cat <<'EOF'
用法: fix-ssh-root.sh [选项]
  --port <num>               指定 SSH 端口（默认 22）
  --allow-password           允许 root 使用密码登录（默认只允许密钥登录）
  --pubkey "<key>"           直接传入一条公钥字符串（推荐 ed25519）
  --pubkey-file <path>       从文件读取公钥
  --set-root-password        交互式为 root 设置/重设密码（仅当允许密码登录时有意义）
  -h, --help                 显示帮助

示例：
  sudo bash fix-ssh-root.sh --pubkey "ssh-ed25519 AAAAC3... user@host"
  sudo bash fix-ssh-root.sh --allow-password --pubkey-file ~/.ssh/id_ed25519.pub
  sudo bash fix-ssh-root.sh --allow-password --set-root-password
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="${2:-}"; shift 2 ;;
    --allow-password)
      ALLOW_PASSWORD=1; shift ;;
    --pubkey)
      PUBKEY_STRING="${2:-}"; shift 2 ;;
    --pubkey-file)
      PUBKEY_FILE="${2:-}"; shift 2 ;;
    --set-root-password)
      SET_ROOT_PASSWORD=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      err "未知参数: $1"; usage; exit 1 ;;
  esac
done

require_root

# 0) Install openssh-server if missing
if ! command -v sshd >/dev/null 2>&1; then
  log "安装 openssh-server..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y openssh-server
fi

# 1) Backup original sshd_config (once per run with timestamp)
if [[ -f /etc/ssh/sshd_config ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.${TS}"
  log "已备份 /etc/ssh/sshd_config -> /etc/ssh/sshd_config.bak.${TS}"
fi

# 2) Ensure Include directive exists (Debian 默认有，但我们双保险)
if ! grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
  log "在 sshd_config 中添加 Include 指令"
  echo -e "\nInclude /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
fi

mkdir -p /etc/ssh/sshd_config.d

# 3) Write our drop-in file
CONF="/etc/ssh/sshd_config.d/99-root-login.conf"

if [[ "${ALLOW_PASSWORD}" -eq 1 ]]; then
  ROOT_LOGIN_LINE="PermitRootLogin yes"
  PASSAUTH_LINE="PasswordAuthentication yes"
  warn "已启用 root 密码登录（存在安全风险）。请确保强密码或尽快切换为仅密钥登录。"
else
  ROOT_LOGIN_LINE="PermitRootLogin prohibit-password"  # 允许 root 仅用密钥登录
  PASSAUTH_LINE="PasswordAuthentication no"
fi

cat > "${CONF}" <<EOF
# Managed by fix-ssh-root.sh
Port ${PORT}
Protocol 2
${ROOT_LOGIN_LINE}
PubkeyAuthentication yes
${PASSAUTH_LINE}
# 对老旧 RSA-SHA1 公钥的兼容（不推荐）。如需启用，去掉下一行注释：
# PubkeyAcceptedAlgorithms +ssh-rsa
# HostKeyAlgorithms +ssh-rsa

# 更稳妥的超时设置（可选）
LoginGraceTime 30
ClientAliveInterval 60
ClientAliveCountMax 3
EOF

log "已写入 ${CONF}"

# 4) Prepare root authorized_keys if a key was provided
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

if [[ -n "${PUBKEY_FILE}" ]]; then
  if [[ -f "${PUBKEY_FILE}" ]]; then
    PUBKEY_STRING="$(sed -e 's/[[:space:]]\+$//' "${PUBKEY_FILE}")"
  else
    err "未找到公钥文件: ${PUBKEY_FILE}"
    exit 1
  fi
fi

if [[ -n "${PUBKEY_STRING}" ]]; then
  if ! grep -Fxq "${PUBKEY_STRING}" /root/.ssh/authorized_keys; then
    echo "${PUBKEY_STRING}" >> /root/.ssh/authorized_keys
    log "已将公钥写入 /root/.ssh/authorized_keys"
  else
    log "该公钥已存在于 /root/.ssh/authorized_keys，跳过追加"
  fi
else
  if [[ "${ALLOW_PASSWORD}" -eq 0 ]]; then
    warn "未提供公钥且未启用密码登录。若你需要 root 通过密钥登录，请用 --pubkey 或 --pubkey-file 传入公钥。"
  fi
fi

# 5) Optionally set root password
if [[ "${SET_ROOT_PASSWORD}" -eq 1 ]]; then
  if [[ "${ALLOW_PASSWORD}" -eq 1 ]]; then
    warn "设置 root 密码（输入时不会回显）"
    # shellcheck disable=SC3010,SC2162
    read -s -p "输入新的 root 密码: " p1; echo
    read -s -p "再次输入以确认: " p2; echo
    if [[ "${p1}" != "${p2}" ]]; then
      err "两次输入不一致，未修改密码。"
    else
      echo "root:${p1}" | chpasswd
      log "已更新 root 密码"
    fi
  else
    warn "--set-root-password 被忽略：当前未启用 --allow-password"
  fi
fi

# 6) Enable/Restart SSH service
systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh

# 7) Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -qi "Status: active"; then
    ufw allow "${PORT}/tcp" || true
    log "已通过 ufw 放行端口 ${PORT}/tcp"
  fi
fi

# 8) Show effective settings
log "当前 sshd 关键配置："
sshd -T 2>/dev/null | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication) ' || true

log "完成。你现在可以通过如下方式连接："
if [[ "${PORT}" -eq 22 ]]; then
  echo "  ssh root@服务器IP"
else
  echo "  ssh -p ${PORT} root@服务器IP"
fi
if [[ "${ALLOW_PASSWORD}" -eq 1 ]]; then
  echo "（已允许密码登录，但建议尽快改为仅密钥登录以提升安全性）"
else
  echo "（仅允许使用 SSH 密钥登录 root。若你需要密码登录，请重新运行并添加 --allow-password）"
fi
