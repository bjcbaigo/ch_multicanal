$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:CHEMES_SQL_AXOFT_PASSWORD)) {
  throw "Falta variable de entorno CHEMES_SQL_AXOFT_PASSWORD"
}

if ([string]::IsNullOrWhiteSpace($env:CHEMES_SQL_AXOFT_USER)) {
  throw "Falta variable de entorno CHEMES_SQL_AXOFT_USER"
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$logDir = Join-Path $root "logs"
if (!(Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logPath = Join-Path $logDir "refresh_canales_digitales.log"

try {
  "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Inicio refresh canales digitales" | Set-Content -LiteralPath $logPath -Encoding UTF8

  $outputDir = "..\frontend\out"
  $panelCsv = Join-Path $outputDir "canales_articulos_publicados.csv"
  $liveCsv = Join-Path $outputDir "prestashop_stock_live.csv"
  $credentialFile = "..\.config\dashboard-credentials.xml"
  $apiKeyFile = "..\.config\prestashop-api-key.txt"

  .\export_canales_digitales_csvs.ps1 -OutputDir $outputDir -SqlRoot "." -ManifestPath ".\csv_exports_manifest.csv" *>> $logPath
  .\export_prestashop_live_stock.ps1 -CredentialFile $credentialFile -ApiKeyFile $apiKeyFile -InputCsv $panelCsv -OutputCsv $liveCsv *>> $logPath
  .\apply_prestashop_live_stock.ps1 -PanelCsv $panelCsv -LiveCsv $liveCsv *>> $logPath
  if (![string]::IsNullOrWhiteSpace($env:CHEMES_CANALES_APPSCRIPT_URL) -and ![string]::IsNullOrWhiteSpace($env:CHEMES_CANALES_APPSCRIPT_TOKEN)) {
    .\publish_canales_csv_appscript.ps1 -CsvPath $panelCsv *>> $logPath
  } else {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Apps Script no configurado; se omite publicacion online" | Add-Content -LiteralPath $logPath -Encoding UTF8
  }

  "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] OK refresh canales digitales" | Add-Content -LiteralPath $logPath -Encoding UTF8
  exit 0
}
catch {
  "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR $($_.Exception.Message)" | Add-Content -LiteralPath $logPath -Encoding UTF8
  $_ | Out-String | Add-Content -LiteralPath $logPath -Encoding UTF8
  exit 1
}
