#!/usr/bin/env bash
# Service Recovery Script (For Testing, Demonstration & Viva)
# Objective: Restart stopped containers and restore all services to OK status

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
    echo -e "${RED}Inventory file not found at $INVENTORY. Please run Terraform first.${NC}"
    exit 1
fi

APP_IP=$(grep -E '^app-server' "$INVENTORY" | awk -F'ansible_host=' '{print $2}' | awk '{print $1}')
MONITORING_IP=$(grep -E '^monitoring-server' "$INVENTORY" | awk -F'ansible_host=' '{print $2}' | awk '{print $1}')

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}             MICROSERVICES RECOVERY ORCHESTRATION                ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Target App Server: ${CYAN}$APP_IP${NC}"

SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_FILE ubuntu@$APP_IP"

echo -e "\n${YELLOW}Ensuring Docker engine service is running...${NC}"
$SSH_CMD "sudo systemctl start docker"

echo -e "${YELLOW}Starting all stopped containers via Docker Compose...${NC}"
$SSH_CMD "cd /home/ubuntu/chat-app && docker compose -f docker-compose.yml -f docker-compose.override.yml up -d"

echo -e "\n${YELLOW}Waiting 5 seconds for services to re-initialize...${NC}"
sleep 5

echo -e "\n${YELLOW}Current container status on App Server:${NC}"
$SSH_CMD "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo -e "\n${GREEN}[OK] All microservices restarted successfully!${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "What to observe in Nagios:"
echo -e "  1. Open Nagios Dashboard: ${CYAN}http://$MONITORING_IP/nagios4/${NC}"
echo -e "  2. Go to 'Services' -> Observe the state transition back from [${RED}CRITICAL${NC}] -> [${GREEN}OK${NC}]!"
echo -e "----------------------------------------------------------------------"
echo -e "Run health check to verify endpoints:"
echo -e "  -> ${CYAN}./scripts/test_endpoints.sh${NC}"
echo -e "${BLUE}======================================================================${NC}\n"

