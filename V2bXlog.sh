#!/bin/bash

# 日志保存路径
LOG_DIR="/var/log/v2bx/"
mkdir -p "$LOG_DIR"

# 创建日志轮转配置（如不存在）
install_logrotate() {
    cat > /etc/logrotate.d/v2bx_access <<EOF
"${LOG_DIR}/access_*.log" {
    daily
    missingok
    rotate 365
    compress
    delaycompress
    notifempty
    create 0640 root adm
}
EOF
}
[ ! -f /etc/logrotate.d/v2bx_access ] && install_logrotate

# 获取公网 IP（启动时一次性获取）
get_public_ip() {
    curl -s --max-time 3 https://api.ipify.org
}
ip_address=$(get_public_ip)

# 日志解析主循环
journalctl -fu V2bX.service -o cat | while read -r line
do
  if [[ "$line" =~ accepted\ (tcp|udp) ]]; then
    # 提取时间
    datetime=$(TZ='Asia/Shanghai' date '+%Y/%m/%d %H:%M:%S')

    # 提取客户端 IP:Port
    client_info=$(grep -oP "from \K[0-9.:]+" <<< "$line")

    # 提取目标地址
    target_info=$(grep -oP "accepted (tcp|udp):\K\S+:\d+" <<< "$line")

    # 提取并分割用户字段
    raw_user=$(grep -oP "email: \K\S+" <<< "$line" || echo "unknown")
    user_email=$(grep -oP "^\[.*?\]" <<< "$raw_user" | tr -d '[]')
    vmess_id=$(grep -oP "\]\K.*" <<< "$raw_user")

    # 格式化输出（使用缓存的公网 IP）
    output="Time: ${datetime%.*} | Client: ${client_info} | Target: ${target_info} | VmessID: ${vmess_id} | Ip:$ip_address | Email: $user_email"

    # 动态日志文件名
    LOG_FILE="${LOG_DIR}/access_$(date +%Y%m%d).log"

    # 写入日志并打印
    echo "$output" | tee -a "$LOG_FILE"
  fi
done
