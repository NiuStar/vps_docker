用法: 
```bash
fix-ssh-root.sh [选项]
  --port <num>               指定 SSH 端口（默认 22）
  --allow-password           允许 root 使用密码登录（默认只允许密钥登录）
  --pubkey "<key>"           直接传入一条公钥字符串（推荐 ed25519）
  --pubkey-file <path>       从文件读取公钥
  --set-root-password        交互式为 root 设置/重设密码（仅当允许密码登录时有意义）
  -h, --help                 显示帮助
```
示例：
```bash
  wget -o fix-ssh-root.sh https://raw.githubusercontent.com/NiuStar/vps_docker/refs/heads/main/fis-ssh-root.sh & chmod +x ./fis-ssh-root.sh & bash fis-ssh-root.sh --allow-password
```
其他用法
```
  sudo bash fix-ssh-root.sh --pubkey "ssh-ed25519 AAAAC3... user@host"
  sudo bash fix-ssh-root.sh --allow-password --pubkey-file ~/.ssh/id_ed25519.pub
  sudo bash fix-ssh-root.sh --allow-password --set-root-password
```
