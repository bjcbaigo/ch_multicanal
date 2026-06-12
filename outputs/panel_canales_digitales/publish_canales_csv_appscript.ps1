param(
  [string]$CsvPath = "..\frontend\out\canales_articulos_publicados.csv",
  [string]$WebAppUrl = "",
  [string]$Token = ""
)

$ErrorActionPreference = "Stop"

function Get-OptionalEnv {
  param([string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "Machine")
  }
  return $value
}

function Resolve-LocalPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return (Join-Path -Path (Get-Location) -ChildPath $Path)
}

if ([string]::IsNullOrWhiteSpace($WebAppUrl)) {
  $WebAppUrl = Get-OptionalEnv -Name "CHEMES_CANALES_APPSCRIPT_URL"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
  $Token = Get-OptionalEnv -Name "CHEMES_CANALES_APPSCRIPT_TOKEN"
}

if ([string]::IsNullOrWhiteSpace($WebAppUrl)) {
  throw "Falta WebAppUrl o variable CHEMES_CANALES_APPSCRIPT_URL"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
  throw "Falta Token o variable CHEMES_CANALES_APPSCRIPT_TOKEN"
}

$csvFullPath = Resolve-LocalPath $CsvPath
if (!(Test-Path -LiteralPath $csvFullPath)) {
  throw "No existe CsvPath: $csvFullPath"
}

$separator = if ($WebAppUrl.Contains("?")) { "&" } else { "?" }
$uploadUrl = "$WebAppUrl${separator}token=$([uri]::EscapeDataString($Token))"
$csv = Get-Content -LiteralPath $csvFullPath -Raw -Encoding UTF8

$response = Invoke-WebRequest -Uri $uploadUrl -Method Post -ContentType "text/csv; charset=utf-8" -Body $csv -UseBasicParsing
if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
  throw "Apps Script respondio HTTP $($response.StatusCode)"
}

$payload = $response.Content | ConvertFrom-Json
if (!$payload.ok) {
  throw "Apps Script rechazo el CSV: $($payload.error)"
}

Write-Host "OK Apps Script CSV publicado: $($payload.bytes) bytes, fileId=$($payload.fileId)"
