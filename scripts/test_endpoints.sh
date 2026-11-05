#!/usr/bin/env bash
# ==============================================================================
# Microservices & Monitoring Endpoints Verification Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY="$PROJECT_ROOT/ansible/inventory/hosts.ini"

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

if [ -z "$APP_IP" ] || [ -z "$MONITORING_IP" ]; then
    echo -e "${RED}Could not extract IPs from inventory file.${NC}"
    exit 1
fi

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${CYAN}             🔍 MICROSERVICES & NAGIOS ENDPOINTS HEALTH CHECK        ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "App Server IP       : $APP_IP"
echo -e "Monitoring Server IP: $MONITORING_IP"
echo -e "----------------------------------------------------------------------"

check_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    local start_time=$(date +%s%N)
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))

    if [ "$response" == "$expected_code" ] || [ "$response" == "200" ] || [ "$response" == "301" ] || [ "$response" == "302" ] || [ "$response" == "401" ]; then
        printf "  %-35s [ %-28s ] Status: ${GREEN}%-4s OK${NC} (${duration}ms)\n" "$name" "$url" "$response"
    else
        printf "  %-35s [ %-28s ] Status: ${RED}%-4s FAILED${NC} (${duration}ms)\n" "$name" "$url" "$response"
    fi
}

echo -e "${YELLOW}Testing Microservices Stack on App Server:${NC}"
check_endpoint "Frontend React Client"       "http://$APP_IP:3000"         "200"
check_endpoint "API Gateway Health"          "http://$APP_IP:5000/health"  "200"
check_endpoint "API Gateway Base Route"      "http://$APP_IP:5000/"        "200"
check_endpoint "Auth Microservice Direct"    "http://$APP_IP:5001/"        "200"
check_endpoint "Chat Microservice Direct"    "http://$APP_IP:5002/"        "200"
check_endpoint "Notification Service Direct" "http://$APP_IP:5003/"        "200"

echo -e "\n${YELLOW}Testing Nagios Monitoring Stack on Monitoring Server:${NC}"
# Nagios returns 401 Unauthorized if queried without credentials, which confirms the service and auth are working!
check_endpoint "Nagios Web UI Root Redirect" "http://$MONITORING_IP/"      "302"
check_endpoint "Nagios Core Protected UI"    "http://$MONITORING_IP/nagios4/" "401"
# Test with basic auth
NAGIOS_AUTH=$(curl -s -u "nagiosadmin:Devops@2026" -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$MONITORING_IP/nagios4/" 2>/dev/null || echo "000")
if [ "$NAGIOS_AUTH" == "200" ]; then
    printf "  %-35s [ %-28s ] Status: ${GREEN}%-4s OK (Auth Valid)${NC}\n" "Nagios Dashboard Authenticated" "http://$MONITORING_IP/nagios4/" "$NAGIOS_AUTH"
else
    printf "  %-35s [ %-28s ] Status: ${RED}%-4s FAILED${NC}\n" "Nagios Dashboard Authenticated" "http://$MONITORING_IP/nagios4/" "$NAGIOS_AUTH"
fi

echo -e "${BLUE}======================================================================${NC}"
