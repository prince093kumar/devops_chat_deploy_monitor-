#!/usr/bin/env bash
# ==============================================================================
# Clean Cloud Infrastructure Teardown Script
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}======================================================================${NC}"
echo -e "${YELLOW}           ⚠️   AWS CLOUD INFRASTRUCTURE TEARDOWN INITIATED          ${NC}"
echo -e "${RED}======================================================================${NC}"
echo "This will destroy both EC2 instances and all associated security groups."
read -p "Are you sure you want to destroy all AWS cloud resources? (y/N): " confirm

if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    echo "Teardown aborted."
    exit 0
fi

echo -e "\nRunning 'terraform destroy'..."
cd "$TERRAFORM_DIR"
terraform destroy -auto-approve

echo -e "\n${GREEN}✔ All AWS resources have been successfully destroyed.${NC}"
