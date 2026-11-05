# ==============================================================================
# Clean Cloud Infrastructure Teardown Script (PowerShell)
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Red
Write-Host "           ⚠️   AWS CLOUD INFRASTRUCTURE TEARDOWN INITIATED          " -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Red
$Confirm = Read-Host "Are you sure you want to destroy all AWS cloud resources? (y/N)"

if ($Confirm -ne "y" -and $Confirm -ne "Y") {
    Write-Host "Teardown aborted." -ForegroundColor Yellow
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $ProjectRoot "terraform"

Set-Location $TerraformDir
terraform destroy -auto-approve

Write-Host "`n✔ All AWS resources have been successfully destroyed." -ForegroundColor Green
Set-Location $ProjectRoot
