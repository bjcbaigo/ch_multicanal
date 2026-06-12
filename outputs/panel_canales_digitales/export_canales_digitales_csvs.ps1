param(
  [string]$Server = "",
  [string]$Database = "",
  [string]$User = "",
  [string]$OutputDir = ".\out",
  [string]$ManifestPath = ".\csv_exports_manifest.csv",
  [string]$SqlRoot = "."
)

$ErrorActionPreference = "Stop"

function Get-RequiredEnv {
  param([string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "Machine")
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Falta variable de entorno $Name"
  }
  return $value
}

function Resolve-ExportPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return (Join-Path -Path (Get-Location) -ChildPath $Path)
}

function Escape-CsvValue {
  param([object]$Value)
  $text = if ($null -eq $Value -or $Value -is [DBNull]) { "" } else { [string]$Value }
  if ($text -match '[;"\r\n]') { return '"' + $text.Replace('"', '""') + '"' }
  return $text
}

function Convert-DataTableToSemicolonCsv {
  param([System.Data.DataTable]$Table)
  $lines = New-Object System.Collections.Generic.List[string]
  $headers = foreach ($col in $Table.Columns) { Escape-CsvValue $col.ColumnName }
  $lines.Add(($headers -join ";"))

  foreach ($row in $Table.Rows) {
    $values = foreach ($col in $Table.Columns) { Escape-CsvValue $row[$col.ColumnName] }
    $lines.Add(($values -join ";"))
  }

  return $lines
}

if ([string]::IsNullOrWhiteSpace($User)) {
  $User = Get-RequiredEnv -Name "CHEMES_SQL_AXOFT_USER"
}
$password = Get-RequiredEnv -Name "CHEMES_SQL_AXOFT_PASSWORD"
$manifestFullPath = Resolve-ExportPath $ManifestPath
$outputFullPath = Resolve-ExportPath $OutputDir
$sqlRootFullPath = Resolve-ExportPath $SqlRoot

if (!(Test-Path -LiteralPath $manifestFullPath)) {
  throw "No existe manifest: $manifestFullPath"
}

if (!(Test-Path -LiteralPath $outputFullPath)) {
  New-Item -ItemType Directory -Path $outputFullPath | Out-Null
}

$exports = Import-Csv -LiteralPath $manifestFullPath -Delimiter ";"

foreach ($export in $exports) {
  $sqlPath = Join-Path -Path $sqlRootFullPath -ChildPath $export.ConsultaSql
  $outPath = Join-Path -Path $outputFullPath -ChildPath $export.Archivo
  $exportServer = if ([string]::IsNullOrWhiteSpace($Server)) { $export.Server } else { $Server }
  $exportDatabase = if ([string]::IsNullOrWhiteSpace($Database)) { $export.Database } else { $Database }

  if (!(Test-Path -LiteralPath $sqlPath)) {
    Write-Warning "Se omite $($export.Archivo): no existe $sqlPath"
    continue
  }

  Write-Host "Exportando $($export.Archivo) desde $exportServer/$exportDatabase - $sqlPath"

  $query = Get-Content -LiteralPath $sqlPath -Raw
  $conn = "Server=$exportServer;Database=$exportDatabase;User ID=$User;Password=$password;TrustServerCertificate=True;Encrypt=False;Connect Timeout=60;"

  $connection = New-Object System.Data.SqlClient.SqlConnection $conn
  $command = $connection.CreateCommand()
  $command.CommandText = $query
  $command.CommandTimeout = 300

  $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
  $table = New-Object System.Data.DataTable

  try {
    [void]$adapter.Fill($table)
    Convert-DataTableToSemicolonCsv -Table $table | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "OK $($export.Archivo) ($($table.Rows.Count) filas)"
  }
  finally {
    $connection.Dispose()
  }
}
