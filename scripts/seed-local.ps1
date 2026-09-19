# G9POS local catalog seed
#
# Prerequisites:
#   - API listening at http://localhost:8080 (or set $env:API_URL)
#   - Owner already created via setupowner / POST /v1/setup
#
# Usage (from repo root):
#   .\scripts\seed-local.ps1
#
# Optional env:
#   API_URL          default http://localhost:8080
#   OWNER_USERNAME   default owner
#   OWNER_PASSWORD   default testpass123
#
# Flow:
#   1) POST /v1/auth/login with login_context=dashboard (API-SPEC §2.1)
#   2) Read envelope { data, meta } — access_token is under data
#   3) POST /v1/catalog/import multipart field "file" (API-SPEC §10.2)
#   4) Print data.products_created / categories_created / inventory_events_created

$ErrorActionPreference = 'Stop'

$ApiUrl = if ($env:API_URL) { $env:API_URL.TrimEnd('/') } else { 'http://localhost:8080' }
$Username = if ($env:OWNER_USERNAME) { $env:OWNER_USERNAME } else { 'owner' }
$Password = if ($env:OWNER_PASSWORD) { $env:OWNER_PASSWORD } else { 'testpass123' }

$RepoRoot = Split-Path -Parent $PSScriptRoot
$CsvPath = Join-Path $RepoRoot 'templates\catalog-import-sample.csv'
if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV not found: $CsvPath"
}

$DeviceId = [guid]::NewGuid().ToString()
$LoginBody = @{
    username      = $Username
    password      = $Password
    device_id     = $DeviceId
    device_name   = 'Local seed script'
    device_type   = 'dashboard'
    login_context = 'dashboard'
} | ConvertTo-Json

Write-Host "Logging in as '$Username' at $ApiUrl ..."
try {
    $LoginResponse = Invoke-RestMethod `
        -Method Post `
        -Uri "$ApiUrl/v1/auth/login" `
        -ContentType 'application/json' `
        -Body $LoginBody
} catch {
    throw "Login failed. Is the API up and has setupowner been run? $_"
}

# Envelope: { data: { access_token, ... }, meta: ... }
$Token = $LoginResponse.data.access_token
if (-not $Token) {
    throw 'Login response missing data.access_token (expected {data, meta} envelope).'
}

Write-Host "Uploading $CsvPath ..."
$Boundary = [guid]::NewGuid().ToString()
$FileBytes = [System.IO.File]::ReadAllBytes($CsvPath)
$FileName = [System.IO.Path]::GetFileName($CsvPath)
$Encoding = [System.Text.Encoding]::UTF8

$Header = "--$Boundary`r`nContent-Disposition: form-data; name=`"file`"; filename=`"$FileName`"`r`nContent-Type: text/csv`r`n`r`n"
$Footer = "`r`n--$Boundary--`r`n"
$HeaderBytes = $Encoding.GetBytes($Header)
$FooterBytes = $Encoding.GetBytes($Footer)

$BodyStream = New-Object System.IO.MemoryStream
$BodyStream.Write($HeaderBytes, 0, $HeaderBytes.Length)
$BodyStream.Write($FileBytes, 0, $FileBytes.Length)
$BodyStream.Write($FooterBytes, 0, $FooterBytes.Length)
$BodyBytes = $BodyStream.ToArray()
$BodyStream.Dispose()

try {
    $ImportResponse = Invoke-RestMethod `
        -Method Post `
        -Uri "$ApiUrl/v1/catalog/import" `
        -Headers @{ Authorization = "Bearer $Token"; Accept = 'application/json' } `
        -ContentType "multipart/form-data; boundary=$Boundary" `
        -Body $BodyBytes
} catch {
    $msg = "$_"
    if ($msg -match 'already exists') {
        Write-Host "Catalog already seeded (barcodes exist) — OK to continue."
        exit 0
    }
    throw "Catalog import failed: $_"
}

$Data = $ImportResponse.data
if (-not $Data) {
    throw 'Import response missing data (expected {data, meta} envelope).'
}

Write-Host "Import OK:"
Write-Host "  products_created:          $($Data.products_created)"
Write-Host "  categories_created:        $($Data.categories_created)"
Write-Host "  inventory_events_created:  $($Data.inventory_events_created)"
