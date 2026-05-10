$configPath = Join-Path $PSScriptRoot "sync-config.json"
if (Test-Path $configPath) {
    $scriptPath = Join-Path $PSScriptRoot "vault_s3_sync.py"
    python $scriptPath
} else {
    Write-Host "kiro-recall S3 sync skipped: sync-config.json not found"
}
