[CmdletBinding()]
param(
    [ValidateSet("Plan", "ApplyDestroy")]
    [string]$Action = "Plan",

    [ValidateRange(0, 60)]
    [int]$HoldMinutes = 0,

    [ValidatePattern("^[a-z][a-z0-9-]{0,11}$")]
    [string]$SmokeTestVmKey = "primary",

    [ValidatePattern("^[a-z][a-z0-9-]{0,11}$")]
    [string]$SmokeTestStorageAccountKey = "primary",

    [ValidatePattern("^[a-z][a-z0-9-]{0,11}$")]
    [string]$SmokeTestPremiumFileAccountKey = "primary",

    [ValidatePattern("^[a-z][a-z0-9-]{0,11}$")]
    [string]$SmokeTestKeyVaultKey = "primary",

    [ValidatePattern("^[a-z][a-z0-9-]{0,11}$")]
    [string]$SmokeTestContainerRegistryKey = "primary",

    # Relative paths resolve against environments\lab.
    [ValidateNotNullOrEmpty()]
    [string]$VarFile = "lab.tfvars"
)

$ErrorActionPreference = "Stop"
$workspacePath = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $workspacePath "environments\lab"
$smokeScriptPath = Join-Path $PSScriptRoot "private-connectivity-smoke.sh"

$varFilePath = if ([System.IO.Path]::IsPathRooted($VarFile)) { $VarFile } else { Join-Path $environmentPath $VarFile }
if (-not (Test-Path -LiteralPath $varFilePath -PathType Leaf)) {
    throw "Variable file '$varFilePath' was not found. Copy environments\lab\lab.tfvars.example to environments\lab\lab.tfvars or pass -VarFile."
}
$varFileArgument = "-var-file=$((Resolve-Path -LiteralPath $varFilePath).Path)"

function Invoke-Terraform {
    param([Parameter(Mandatory)][string[]]$Arguments)

    & terraform "-chdir=$environmentPath" @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "terraform $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

& terraform fmt -check -recursive $workspacePath
if ($LASTEXITCODE -ne 0) {
    throw "terraform fmt check failed."
}

Invoke-Terraform -Arguments @("init", "-input=false")
Invoke-Terraform -Arguments @("validate", "-no-color")
Invoke-Terraform -Arguments @("plan", "-input=false", $varFileArgument, "-out=ephemeral.tfplan", "-no-color")

if ($Action -eq "Plan") {
    Write-Host "Plan completed. No Azure resources were created."
    exit 0
}

try {
    Invoke-Terraform -Arguments @("apply", "-input=false", "-auto-approve", "ephemeral.tfplan", "-no-color")

    $outputsJson = & terraform "-chdir=$environmentPath" output -json
    if ($LASTEXITCODE -ne 0) {
        throw "terraform output failed with exit code $LASTEXITCODE."
    }
    $outputs = $outputsJson | ConvertFrom-Json

    $smokeTestVm = $outputs.virtual_machines.value.PSObject.Properties[$SmokeTestVmKey].Value
    if ($null -eq $smokeTestVm) {
        throw "The configured smoke-test VM key '$SmokeTestVmKey' was not found."
    }

    $runCommandId = "RunShellScript"
    if ($smokeTestVm.os_type -eq "Windows") {
        $runCommandId = "RunPowerShellScript"
        $smokeScriptPath = Join-Path $PSScriptRoot "private-connectivity-smoke.ps1"
    }

    $smokeTestStorageAccount = $outputs.storage_accounts.value.PSObject.Properties[$SmokeTestStorageAccountKey].Value
    if ($null -eq $smokeTestStorageAccount) {
        throw "The configured smoke-test storage account key '$SmokeTestStorageAccountKey' was not found."
    }

    $smokeTestPremiumFileAccount = $outputs.premium_file_accounts.value.PSObject.Properties[$SmokeTestPremiumFileAccountKey].Value
    if ($null -eq $smokeTestPremiumFileAccount) {
        throw "The configured smoke-test Premium Files account key '$SmokeTestPremiumFileAccountKey' was not found."
    }

    $smokeTestKeyVault = $outputs.key_vaults.value.PSObject.Properties[$SmokeTestKeyVaultKey].Value
    if ($null -eq $smokeTestKeyVault) {
        throw "The configured smoke-test Key Vault key '$SmokeTestKeyVaultKey' was not found."
    }

    $smokeTestContainerRegistry = $outputs.container_registries.value.PSObject.Properties[$SmokeTestContainerRegistryKey].Value
    if ($null -eq $smokeTestContainerRegistry) {
        throw "The configured smoke-test container registry key '$SmokeTestContainerRegistryKey' was not found."
    }

    $smokeParameters = @(
        "SQL_HOST=$($outputs.azure_sql_fqdn.value)",
        "POSTGRESQL_HOST=$($outputs.postgresql_fqdn.value)",
        "MYSQL_HOST=$($outputs.mysql_fqdn.value)",
        "KEY_VAULT_HOST=$($smokeTestKeyVault.hostname)",
        "STORAGE_BLOB_HOST=$($smokeTestStorageAccount.blob_hostname)",
        "PREMIUM_FILES_HOST=$($smokeTestPremiumFileAccount.file_hostname)",
        "FUNCTION_STORAGE_BLOB_HOST=$($outputs.function_storage_blob_hostname.value)",
        "FUNCTION_APP_HOST=$($outputs.function_app_hostname.value)",
        "WEB_APP_HOST=$($outputs.web_app_hostname.value)",
        "CONTAINER_REGISTRY_HOST=$($smokeTestContainerRegistry.login_server)",
        "CONTAINER_APP_HOST=$($outputs.container_app_fqdn.value)"
    )

    # Run Command drops empty parameters, which would shift the Linux script's
    # positional arguments, so unset optional values are sent as "none".
    $optionalSmokeValues = [ordered]@{
        SQL_MANAGED_INSTANCE_HOST = $outputs.sql_managed_instance_fqdn.value
        COSMOS_DB_HOST            = $outputs.cosmos_db_hostname.value
        NAT_GATEWAY_PUBLIC_IP     = $outputs.nat_gateway_public_ip_address.value
    }
    foreach ($entry in $optionalSmokeValues.GetEnumerator()) {
        $value = if ([string]::IsNullOrWhiteSpace($entry.Value)) { "none" } else { $entry.Value }
        $smokeParameters += "$($entry.Key)=$value"
    }

    & az vm run-command invoke `
        --resource-group $outputs.resource_group_name.value `
        --name $smokeTestVm.name `
        --command-id $runCommandId `
        --scripts "@$smokeScriptPath" `
        --parameters $smokeParameters `
        --query "value[0].message" `
        --output tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Private connectivity smoke test failed with exit code $LASTEXITCODE."
    }

    if ($HoldMinutes -gt 0) {
        Write-Host "Holding the lab for $HoldMinutes minute(s)."
        Start-Sleep -Seconds ($HoldMinutes * 60)
    }
}
finally {
    Write-Host "Destroying the ephemeral lab."
    Invoke-Terraform -Arguments @("plan", "-destroy", "-input=false", $varFileArgument, "-out=destroy.tfplan", "-no-color")
    Invoke-Terraform -Arguments @("apply", "-input=false", "-auto-approve", "destroy.tfplan", "-no-color")
}
