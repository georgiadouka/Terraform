$ErrorActionPreference = "Stop"
$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "private-connectivity-smoke.ps1"
$scenario = [pscustomobject]@{
    DnsAddresses = @("10.42.1.4")
    EgressIp     = "203.0.113.10"
    HttpStatus   = 200
    DnsCalls     = 0
    WebCalls     = 0
}

${function:Resolve-DnsName} = {
    param([string]$Name, [string]$Type, [string]$ErrorAction)
    $scenario.DnsCalls++
    foreach ($address in $scenario.DnsAddresses) {
        [pscustomobject]@{ Type = "A"; IPAddress = $address }
    }
}.GetNewClosure()

${function:Invoke-WebRequest} = {
    param([string]$Uri, [switch]$UseBasicParsing, [int]$TimeoutSec)
    $scenario.WebCalls++
    [pscustomobject]@{ Content = $scenario.EgressIp; StatusCode = $scenario.HttpStatus }
}.GetNewClosure()

$parameters = @{
    SQL_HOST                   = "sql.test"
    POSTGRESQL_HOST            = "postgresql.test"
    MYSQL_HOST                 = "mysql.test"
    KEY_VAULT_HOST             = "vault.test"
    STORAGE_BLOB_HOST          = "blob.test"
    PREMIUM_FILES_HOST         = "files.test"
    FUNCTION_STORAGE_BLOB_HOST = "function-storage.test"
    FUNCTION_APP_HOST          = "function.test"
    WEB_APP_HOST               = "web-app.test"
    CONTAINER_REGISTRY_HOST     = "registry.test"
    CONTAINER_APP_HOST         = "container.test"
    NAT_GATEWAY_PUBLIC_IP      = "203.0.113.10"
}

function Assert-SmokeFailure {
    param([string]$ExpectedMessage)
    $failure = $null
    try {
        & $scriptPath @parameters | Out-Null
    }
    catch {
        $failure = $_.Exception.Message
    }
    if ($null -eq $failure -or $failure -notlike $ExpectedMessage) {
        throw "Expected failure '$ExpectedMessage', received '$failure'."
    }
}

& $scriptPath @parameters | Out-Null
if ($scenario.DnsCalls -ne 11 -or $scenario.WebCalls -ne 3) {
    throw "Default smoke test must check eleven DNS hosts, NAT egress, Web App HTTPS, and Container App HTTPS."
}
Write-Output "PASS default Windows smoke checks"

$parameters.SQL_MANAGED_INSTANCE_HOST = "sqlmi.test"
$parameters.COSMOS_DB_HOST = "cosmos.test"
$scenario.DnsCalls = 0
& $scriptPath @parameters | Out-Null
if ($scenario.DnsCalls -ne 13) {
    throw "Optional database hostnames must also be checked."
}
Write-Output "PASS optional database hostnames"

$scenario.DnsAddresses = @("198.51.100.5")
Assert-SmokeFailure -ExpectedMessage "FAIL sql.test*"
Write-Output "PASS public DNS rejected"

$scenario.DnsAddresses = @()
Assert-SmokeFailure -ExpectedMessage "FAIL sql.test*"
Write-Output "PASS empty DNS rejected"

$scenario.DnsAddresses = @("10.42.1.4")
$scenario.EgressIp = "203.0.113.11"
Assert-SmokeFailure -ExpectedMessage "FAIL outbound IP*"
Write-Output "PASS mismatched NAT IP rejected"

$scenario.EgressIp = "203.0.113.10"
$scenario.HttpStatus = 503
Assert-SmokeFailure -ExpectedMessage "Web App HTTPS status: 503"
Write-Output "PASS unsuccessful HTTPS rejected"
