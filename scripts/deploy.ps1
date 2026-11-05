# ==============================================================================
# End-to-End Automated Deployment Script (Windows PowerShell + WSL)
# Project: Automated Deployment & Monitoring of Microservices Chat App
# Tools: Terraform + Ansible (WSL) + Nagios + Docker Compose
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   🚀 Automated Microservices Deployment & Monitoring Orchestrator   " -ForegroundColor Yellow
Write-Host "       Terraform (IaC)  ->  Ansible (WSL)  ->  Nagios (Monitoring)    " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $ProjectRoot "terraform"
$AnsibleDir = Join-Path $ProjectRoot "ansible"

# Step 1: Run Terraform
Write-Host "`n[Step 1/3] Provisioning AWS Infrastructure with Terraform..." -ForegroundColor Green
Set-Location $TerraformDir

terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform init failed."
    exit $LASTEXITCODE
}

terraform apply -auto-approve
if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform apply failed."
    exit $LASTEXITCODE
}

$AppIP = (terraform output -raw app_server_public_ip)
$MonitoringIP = (terraform output -raw monitoring_server_public_ip)

Write-Host "Infrastructure Provisioned Successfully!" -ForegroundColor Green
Write-Host "  App Server IP       : $AppIP" -ForegroundColor Cyan
Write-Host "  Monitoring Server IP: $MonitoringIP" -ForegroundColor Cyan

# Step 2: Trigger Ansible via WSL Ubuntu
Write-Host "`n[Step 2/3] Configuring Servers & Deploying Microservices via Ansible in WSL..." -ForegroundColor Green

# Convert Windows path to WSL mount path
$WslProjectRoot = $ProjectRoot -replace '\\', '/' -replace '^[a-zA-Z]:', { '/mnt/' + $_.Value.Substring(0,1).ToLower() }
$WslAnsibleDir = "$WslProjectRoot/ansible"

Write-Host "Connecting to WSL Ubuntu to execute Ansible playbook..." -ForegroundColor Yellow
wsl -d Ubuntu -e bash -c "export ANSIBLE_CONFIG='$WslAnsibleDir/ansible.cfg'; chmod 600 '$WslAnsibleDir/id_rsa_devops' 2>/dev/null || true; cd '$WslAnsibleDir' && ansible-playbook -i inventory/hosts.ini site.yml"

# Step 3: Summary
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "             🎉 FULL DEPLOYMENT & MONITORING COMPLETE!               " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  💬 Chat Web Application  : http://${AppIP}:3000" -ForegroundColor Cyan
Write-Host "  🌐 Central API Gateway    : http://${AppIP}:5000/health" -ForegroundColor Cyan
Write-Host "  📊 Nagios Core Dashboard : http://${MonitoringIP}/nagios4/" -ForegroundColor Cyan
Write-Host "  👤 Nagios Web Username   : nagiosadmin" -ForegroundColor Yellow
Write-Host "  🔑 Nagios Web Password   : Devops@2026" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan
Set-Location $ProjectRoot
