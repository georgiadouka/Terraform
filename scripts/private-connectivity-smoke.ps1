[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SQL_HOST,
    [Parameter(Mandatory)][string]$POSTGRESQL_HOST,
    [Parameter(Mandatory)][string]$MYSQL_HOST,
    [Parameter(Mandatory)][string]$KEY_VAULT_HOST,
    [Parameter(Mandatory)][string]$STORAGE_BLOB_HOST,
    [Parameter(Mandatory)][string]$PREMIUM_FILES_HOST,
    [Parameter(Mandatory)][string]$FUNCTION_STORAGE_BLOB_HOST,
    [Parameter(Mandatory)][string]$FUNCTION_APP_HOST,
    [Parameter(Mandatory)][string]$WEB_APP_HOST,
    [Parameter(Mandatory)][string]$CONTAINER_REGISTRY_HOST,
    [Parameter(Mandatory)][string]$CONTAINER_APP_HOST,
    [string]$SQL_MANAGED_INSTANCE_HOST,
    [string]$COSMOS_DB_HOST,
    [string]$NAT_GATEWAY_PUBLIC_IP
)

$ErrorActionPreference = "Stop"

foreach ($hostname in @(
    $SQL_HOST, $POSTGRESQL_HOST, $MYSQL_HOST, $KEY_VAULT_HOST,
    $STORAGE_BLOB_HOST, $PREMIUM_FILES_HOST, $FUNCTION_STORAGE_BLOB_HOST,
    $FUNCTION_APP_HOST, $WEB_APP_HOST, $CONTAINER_REGISTRY_HOST, $CONTAINER_APP_HOST,
    $SQL_MANAGED_INSTANCE_HOST, $COSMOS_DB_HOST
)) {
    if ([string]::IsNullOrWhiteSpace($hostname)) {
        continue
    }

    $addresses = @(Resolve-DnsName -Name $hostname -Type A -ErrorAction Stop |
        Where-Object { $_.Type -eq "A" } |
        Select-Object -ExpandProperty IPAddress)
    if ($addresses.Count -eq 0 -or @($addresses | Where-Object { $_ -notlike "10.*" }).Count -gt 0) {
        throw "FAIL $hostname -> $($addresses -join ', ')"
    }
    Write-Output "PASS $hostname -> $($addresses -join ', ')"
}

if (-not [string]::IsNullOrWhiteSpace($NAT_GATEWAY_PUBLIC_IP)) {
    $observedEgressIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 30).Content.Trim()
    if ($observedEgressIp -ne $NAT_GATEWAY_PUBLIC_IP) {
        throw "FAIL outbound IP $observedEgressIp; expected $NAT_GATEWAY_PUBLIC_IP"
    }
    Write-Output "PASS outbound IP $observedEgressIp"
}

$webAppResponse = Invoke-WebRequest -Uri "https://$WEB_APP_HOST/" -UseBasicParsing -TimeoutSec 30
if ($webAppResponse.StatusCode -ne 200) {
    throw "Web App HTTPS status: $($webAppResponse.StatusCode)"
}
Write-Output "Web App HTTPS status: $($webAppResponse.StatusCode)"

$containerAppResponse = Invoke-WebRequest -Uri "https://$CONTAINER_APP_HOST/" -UseBasicParsing -TimeoutSec 30
if ($containerAppResponse.StatusCode -ne 200) {
    throw "Container App HTTPS status: $($containerAppResponse.StatusCode)"
}
Write-Output "Container App HTTPS status: $($containerAppResponse.StatusCode)"
