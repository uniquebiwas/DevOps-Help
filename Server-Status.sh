#!/bin/bash

# Colors
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
GREEN='\033[1;32m'
RESET='\033[0m'
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

# Separator
SEP="----------------------------------------"

# Print header
print_header() {
    echo -e "\n${BLUE}${BOLD}$1${RESET}"
    echo "$SEP"
}

# ---------------- Server Overview ----------------
print_header "🧾 Server Overview"

# CPU Model and Core Count
cpu_model=$(lscpu | grep "Model name" | awk -F ':' '{print $2}' | sed 's/^[ \t]*//')
cpu_cores=$(nproc)

# Total RAM
total_mem_gb=$(awk '/MemTotal/ {printf "%.2f", $2/1024/1024}' /proc/meminfo)

# Total Swap
total_swap_gb=$(awk '/SwapTotal/ {printf "%.2f", $2/1024/1024}' /proc/meminfo)

# Disk Size (first disk only)
disk_total=$(df -h / | awk 'NR==2 {print $2}')

# Network Interface Speed
if command -v ethtool >/dev/null 2>&1 && ethtool eth0 &>/dev/null; then
    net_speed=$(ethtool eth0 | grep "Speed" | awk -F ': ' '{print $2}')
else
    net_speed="Unavailable"
fi

# Output
echo -e "CPU       : ${MAGENTA}${cpu_model} (${cpu_cores} cores)${RESET}"
echo -e "RAM       : ${MAGENTA}${total_mem_gb} GB${RESET}"
echo -e "Swap      : ${MAGENTA}${total_swap_gb} GB${RESET}"
echo -e "Disk      : ${MAGENTA}${disk_total}${RESET}"
echo -e "NIC Speed : ${MAGENTA}${net_speed}${RESET}"

# ---------------- CPU Usage ----------------
print_header "🖥️ CPU Usage"
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", 100 - $8}')
io_wait=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $10}')
echo -e "Usage : ${GREEN}${cpu_usage}%${RESET}"
echo -e "I/O Wait: ${MAGENTA}${io_wait}%${RESET}"

# ---------------- Load Average ----------------
print_header "📊 Load Average"
load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1, $2, $3}')
echo -e "1m, 5m, 15m: ${GREEN}${load_avg}${RESET}"

# ---------------- Memory Usage ----------------
print_header "🧠 Memory Usage"
mem_info=$(free -m | awk '/Mem:/ {print $2, $3, $7}')
read total_mem used_mem avail_mem <<< "$mem_info"
used_percent=$(awk -v u=$used_mem -v t=$total_mem 'BEGIN {printf "%.1f", (u/t)*100}')
avail_percent=$(awk -v a=$avail_mem -v t=$total_mem 'BEGIN {printf "%.1f", (a/t)*100}')

echo -e "Total : ${MAGENTA}${total_mem} MB${RESET}"
echo -e "Used  : ${MAGENTA}${used_mem} MB${RESET} (${used_percent}%)"
echo -e "Free  : ${MAGENTA}${avail_mem} MB${RESET} (${avail_percent}%)"

# ---------------- Swap Usage ----------------
print_header "💿 Swap Usage"
swap_info=$(free -m | awk '/Swap:/ {print $2, $3, $4}')
read total_swap used_swap free_swap <<< "$swap_info"
if [ "$total_swap" -gt 0 ]; then
    used_swap_percent=$(awk -v u=$used_swap -v t=$total_swap 'BEGIN {printf "%.1f", (u/t)*100}')
    echo -e "Total: ${MAGENTA}${total_swap} MB${RESET}"
    echo -e "Used : ${MAGENTA}${used_swap} MB${RESET} (${used_swap_percent}%)"
    echo -e "Free : ${MAGENTA}${free_swap} MB${RESET}"
else
    echo -e "Swap : ${GREEN}Disabled${RESET}"
fi

# ---------------- Disk Usage ----------------
print_header "💾 Disk Usage"
disk_info=$(df -h / | awk 'NR==2 {print $2, $3, $4, $5}')
read size used avail used_percent <<< "$disk_info"
avail_percent=$(awk -v u=${used_percent%\%} 'BEGIN {printf "%.1f", 100-u}')

echo -e "Size  : ${MAGENTA}${size}${RESET}"
echo -e "Used  : ${MAGENTA}${used}${RESET} (${used_percent})"
echo -e "Free  : ${MAGENTA}${avail}${RESET} (${avail_percent}%)"

# ---------------- Network Usage ----------------
print_header "🌐 Network Usage"
if [[ -f /proc/net/dev ]]; then
    net_info=$(cat /proc/net/dev | grep eth0 || echo "0 0")
    rx_bytes=$(echo "$net_info" | awk '{print $2}')
    tx_bytes=$(echo "$net_info" | awk '{print $10}')
    rx_mb=$(awk -v rx=$rx_bytes 'BEGIN {printf "%.2f", rx/1024/1024}')
    tx_mb=$(awk -v tx=$tx_bytes 'BEGIN {printf "%.2f", tx/1024/1024}')
    echo -e "Received: ${MAGENTA}${rx_mb} MB${RESET}"
    echo -e "Sent    : ${MAGENTA}${tx_mb} MB${RESET}"
else
    echo -e "Network data: ${MAGENTA}Unavailable${RESET}"
fi

# ---------------- Active Connections ----------------
print_header "🔗 Active Connections"
if command -v ss >/dev/null 2>&1; then
    conn_count=$(ss -tun | grep -v "State" | wc -l)
    echo -e "Connections: ${GREEN}${conn_count}${RESET}"
else
    echo -e "Connections: ${MAGENTA}ss command not found${RESET}"
fi

# ---------------- System Uptime ----------------
print_header "⏰ System Uptime"
uptime_info=$(uptime -p)
echo -e "Uptime: ${GREEN}${uptime_info}${RESET}"

# ---------------- Service Status ----------------
print_header "🛠️ Critical Services"
services=("sshd" "nginx" "apache2")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "$service: ${GREEN}Running${RESET}"
    elif command -v systemctl >/dev/null 2>&1; then
        echo -e "$service: ${MAGENTA}Not running${RESET}"
    else
        echo -e "$service: ${MAGENTA}Systemctl not found${RESET}"
        break
    fi
done

# ---------------- Top 5 Processes by CPU ----------------
print_header "🔥 Top 5 Processes by CPU Usage"
printf "${BOLD}%-10s %-6s %-5s %-5s %s${NORMAL}\n" "USER" "PID" "%CPU" "%MEM" "COMMAND"
ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {printf "%-10s %-6s %-5.1f %-5.1f %s\n", $1, $2, $3, $4, $11}'

# ---------------- Top 5 Processes by Memory ----------------
print_header "🧠 Top 5 Processes by Memory Usage"
printf "${BOLD}%-10s %-6s %-5s %-5s %s${NORMAL}\n" "USER" "PID" "%MEM" "%CPU" "COMMAND"
ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {printf "%-10s %-6s %-5.1f %-5.1f %s\n", $1, $2, $4, $3, $11}'

# ---------------- Watermark ----------------
echo -e "\n${SEP}"
echo -e "${GREEN}${BOLD}Monitored by: Biwas Pudasaini (DevOps Engineer)${RESET}\n"
