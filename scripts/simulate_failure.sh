#!/usr/bin/env bash
# Controlled Failure Injection Script (For Testing, Demonstration & Viva)
# Objective: Stop a microservice container and observe Nagios alerting CRITICAL

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

echo -e "${RED}======================================================================${NC}"
echo -e "${YELLOW}           CONTROLLED MICROSERVICES FAILURE SIMULATION           ${NC}"
echo -e "${RED}======================================================================${NC}"
echo -e "Target App Server: ${CYAN}$APP_IP${NC}"
echo -e "Monitoring Server: ${CYAN}http://$MONITORING_IP/nagios4/${NC}"
echo ""
echo "Select the failure scenario to simulate:"
echo "  1) Stop Chat Microservice container (chat_service on port 5002)"
echo "  2) Stop API Gateway container (api_gateway on port 5000)"
echo "  3) Stop Authentication Service container (auth_service on port 5001)"
echo "  4) Stop Frontend Web Client container (chat_client on port 3000)"
echo "  5) Stop entire Docker engine daemon on App Server"
echo "  6) Exit"
echo ""
read -p "Enter choice [1-5]: " choice

SSH_CMD="ssh -o StrictHostKeyChecking=no -i $KEY_FILE ubuntu@$APP_IP"

case $choice in
    1)
        echo -e "\n${YELLOW}Simulating failure: Stopping 'chat_service' container...${NC}"
        $SSH_CMD "docker stop chat_service"
        TARGET_CHECK="Microservice - Chat Service (Port 5002) AND Containers - Chat Microservices Health"
        ;;
    2)
        echo -e "\n${YELLOW}Simulating failure: Stopping 'api_gateway' container...${NC}"
        $SSH_CMD "docker stop api_gateway"
        TARGET_CHECK="API Gateway - Health Endpoint (Port 5000) AND Containers - Chat Microservices Health"
        ;;
    3)
        echo -e "\n${YELLOW}Simulating failure: Stopping 'auth_service' container...${NC}"
        $SSH_CMD "docker stop auth_service"
        TARGET_CHECK="Microservice - Auth Service (Port 5001) AND Containers - Chat Microservices Health"
        ;;
    4)
        echo -e "\n${YELLOW}Simulating failure: Stopping 'chat_client' frontend container...${NC}"
        $SSH_CMD "docker stop chat_client"
        TARGET_CHECK="Frontend - React Web Client (Port 3000) AND Containers - Chat Microservices Health"
        ;;
    5)
        echo -e "\n${YELLOW}Simulating catastrophic failure: Stopping Docker daemon...${NC}"
        $SSH_CMD "sudo systemctl stop docker"
        TARGET_CHECK="Docker - Engine Daemon Status (via NRPE) AND all container checks"
        ;;
    *)
        echo "Exiting without making changes."
        exit 0
        ;;
esac

echo -e "\n${GREEN}[OK] Failure successfully injected!${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "What to observe now in Nagios:"
echo -e "  1. Open the Nagios Dashboard: ${CYAN}http://$MONITORING_IP/nagios4/${NC}"
echo -e "  2. Go to ${YELLOW}'Services'${NC} on the left navigation bar."
echo -e "  3. The following check(s) will transition from [${GREEN}OK${NC}] -> [${RED}CRITICAL${NC}]:"
echo -e "     -> ${RED}$TARGET_CHECK${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "To restore the system back to healthy state, run:"
echo -e "  -> ${GREEN}./scripts/recover_service.sh${NC}"
echo -e "======================================================================\n"

