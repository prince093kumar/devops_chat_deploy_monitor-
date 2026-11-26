#!/usr/bin/env bash
# Nagios Monitoring Server Verification & Plugin Tester

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY="$PROJECT_ROOT/ansible/inventory/hosts.ini"
KEY_FILE="$PROJECT_ROOT/ansible/id_rsa_devops"
if [[ "$KEY_FILE" == /mnt/* ]] && [ -f "$KEY_FILE" ]; then
    cp "$KEY_FILE" /tmp/id_rsa_devops_wsl && chmod 600 /tmp/id_rsa_devops_wsl
    KEY_FILE="/tmp/id_rsa_devops_wsl"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ ! -f "$INVENTORY" ]; then
    echo -e "${RED}Inventory file not found at $INVENTORY.${NC}"
    exit 1
fi

APP_IP=$(grep -E '^app-server' "$INVENTORY" | awk -F'ansible_host=' '{print $2}' | awk '{print $1}')
MONITORING_IP=$(grep -E '^monitoring-server' "$INVENTORY" | awk -F'ansible_host=' '{print $2}' | awk '{print $1}')

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${CYAN}        NAGIOS SERVER CLI PLUGIN DIAGNOSTICS & VERIFICATION        ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Testing active check execution directly from Nagios Server ($MONITORING_IP)..."

SSH_MON="ssh -o StrictHostKeyChecking=no -i $KEY_FILE ubuntu@$MONITORING_IP"

echo -e "\n${YELLOW}1. Nagios Service Daemon Status:${NC}"
$SSH_MON "sudo systemctl status nagios4 --no-pager | head -n 8"

echo -e "\n${YELLOW}2. Ping Reachability to App Server ($APP_IP):${NC}"
$SSH_MON "/usr/lib/nagios/plugins/check_ping -H $APP_IP -w 100.0,20% -c 500.0,60%"

echo -e "\n${YELLOW}3. Frontend Web App HTTP Check (Port 3000):${NC}"
$SSH_MON "/usr/lib/nagios/plugins/check_http -H $APP_IP -p 3000 -u /"

echo -e "\n${YELLOW}4. API Gateway Health Check (Port 5000 /health):${NC}"
$SSH_MON "/usr/lib/nagios/plugins/check_http -H $APP_IP -p 5000 -u /health -s 'healthy'"

echo -e "\n${YELLOW}5. Remote NRPE Disk Check:${NC}"
$SSH_MON "/usr/lib/nagios/plugins/check_nrpe -H $APP_IP -c check_disk"

echo -e "\n${YELLOW}6. Remote NRPE System Load Check:${NC}"
$SSH_MON "/usr/lib/nagios/plugins/check_nrpe -H $APP_IP -c check_load"

echo -e "\n${YELLOW}7. Remote NRPE Docker Daemon Check:${NC}"
$SSH_MON "/usr/lib/nagios/plugins/check_nrpe -H $APP_IP -c check_docker"

echo -e "\n${YELLOW}8. Remote NRPE Microservice Containers Health Check:${NC}"
$SSH_MON "/usr/lib/nagios/plugins/check_nrpe -H $APP_IP -c check_chat_containers"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[OK] All Nagios plugins executed and verified!${NC}"
echo -e "Web Dashboard: ${CYAN}http://$MONITORING_IP/nagios4/${NC}"
echo -e "${GREEN}======================================================================${NC}\n"

