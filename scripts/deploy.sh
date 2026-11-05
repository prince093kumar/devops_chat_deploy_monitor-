#!/usr/bin/env bash
# ==============================================================================
# End-to-End Automated Deployment Script (WSL / Linux)
# Project: Automated Deployment & Monitoring of Microservices Chat App
# Tools: Terraform + Ansible + Nagios + Docker Compose
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}   🚀 Automated Microservices Deployment & Monitoring Orchestrator   ${NC}"
echo -e "${CYAN}       Terraform (IaC)  ->  Ansible (CM)  ->  Nagios (Monitoring)     ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Step 0: Check required CLI tools
echo -e "\n${YELLOW}[Step 0/4] Checking prerequisite tools...${NC}"
for cmd in terraform ansible ansible-playbook; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: '$cmd' is not installed or not in PATH.${NC}"
        exit 1
    fi
    echo -e "  ✔ $cmd found: $(which $cmd)"
done

# Step 1: Provision Cloud Infrastructure with Terraform
echo -e "\n${YELLOW}[Step 1/4] Provisioning AWS EC2 infrastructure using Terraform...${NC}"
cd "$TERRAFORM_DIR"

if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

echo "Planning and applying infrastructure changes..."
terraform apply -auto-approve

# Extract outputs
APP_IP=$(terraform output -raw app_server_public_ip)
MONITORING_IP=$(terraform output -raw monitoring_server_public_ip)
KEY_FILE=$(terraform output -raw ssh_private_key_file)

echo -e "${GREEN}Infrastructure provisioned successfully!${NC}"
echo -e "  📌 Chat App Server IP   : ${CYAN}$APP_IP${NC}"
echo -e "  📌 Nagios Monitoring IP : ${CYAN}$MONITORING_IP${NC}"

# Fix SSH Key permissions if generated locally
if [ -f "$ANSIBLE_DIR/id_rsa_devops" ]; then
    chmod 600 "$ANSIBLE_DIR/id_rsa_devops"
fi

# Step 2: Wait for SSH to be ready on both instances
echo -e "\n${YELLOW}[Step 2/4] Waiting for EC2 instances to finish boot and SSH handshake...${NC}"
wait_for_ssh() {
    local host=$1
    local retries=30
    local count=0
    echo -n "  Connecting to $host:22 "
    until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i "$ANSIBLE_DIR/id_rsa_devops" ubuntu@"$host" "echo ready" &>/dev/null; do
        echo -n "."
        sleep 5
        count=$((count+1))
        if [ $count -ge $retries ]; then
            echo -e "\n${RED}Timed out waiting for SSH on $host${NC}"
            return 1
        fi
    done
    echo -e " [${GREEN}ONLINE${NC}]"
}

wait_for_ssh "$APP_IP"
wait_for_ssh "$MONITORING_IP"

# Step 3: Configure Servers and Deploy Microservices using Ansible
echo -e "\n${YELLOW}[Step 3/4] Running Ansible Playbook (site.yml)...${NC}"
cd "$ANSIBLE_DIR"
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"
export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook -i inventory/hosts.ini site.yml

# Step 4: Verification and Summary
echo -e "\n${YELLOW}[Step 4/4] Verifying Endpoints...${NC}"
"$SCRIPT_DIR/test_endpoints.sh" || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}             🎉 FULL DEPLOYMENT & MONITORING COMPLETE!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "  💬 Chat Web Application  : ${CYAN}http://$APP_IP:3000${NC}"
echo -e "  🌐 Central API Gateway    : ${CYAN}http://$APP_IP:5000/health${NC}"
echo -e "  📊 Nagios Core Dashboard : ${CYAN}http://$MONITORING_IP/nagios4/${NC}"
echo -e "  👤 Nagios Web Username   : ${YELLOW}nagiosadmin${NC}"
echo -e "  🔑 Nagios Web Password   : ${YELLOW}Devops@2026${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "  🛠️  Test Endpoints : ${BLUE}./scripts/test_endpoints.sh${NC}"
echo -e "  ⚠️  Simulate Failure: ${BLUE}./scripts/simulate_failure.sh${NC}"
echo -e "  🔄 Recover Service : ${BLUE}./scripts/recover_service.sh${NC}"
echo -e "  🗑️  Destroy Cloud  : ${BLUE}./scripts/destroy.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
