param(
  [string]$PanelCsv = ".\out\canales_articulos_publicados.csv",
  [string]$LiveCsv = ".\out\prestashop_stock_live.csv"
)

$ErrorActionPreference = "Stop"

function Resolve-LocalPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return (Join-Path -Path (Get-Location) -ChildPath $Path)
}

function To-Decimal {
  param([object]$Value)
  if ($null -eq $Value) { return [decimal]0 }
  $text = ([string]$Value).Trim().Replace(",", ".")
  if ([string]::IsNullOrWhiteSpace($text)) { return [decimal]0 }
  return [decimal]::Parse($text, [Globalization.CultureInfo]::InvariantCulture)
}

function Format-Decimal {
  param([decimal]$Value)
  return $Value.ToString("0.00", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-MonitorState {
  param($Row)

  $saldoReal = To-Decimal $Row.Saldo_Real
  $saldoProducteca = To-Decimal $Row.Stock_Producteca_Total
  $saldoPresta = To-Decimal $Row.Saldo_Prestashop
  $saldoBna = To-Decimal $Row.Saldo_BNA
  $ventas30 = To-Decimal $Row.Ventas_Ultimos_30_Dias
  $publicadoPresta = [string]$Row.Publicado_Prestashop -eq "1"
  $publicadoBna = [string]$Row.Publicado_BNA -eq "1"

  if (!$publicadoPresta -and !$publicadoBna) { return "SIN_CANAL_DIGITAL" }
  if (($saldoReal -le 0 -and $saldoPresta -gt 0) -or ($publicadoBna -and $saldoProducteca -le 0)) { return "QUIEBRE" }
  if ($ventas30 -gt 0 -and $saldoReal -gt 0 -and ($saldoReal / ($ventas30 / 30)) -le 7) { return "COBERTURA_BAJA" }
  if ($saldoPresta -gt $saldoReal) { return "CANAL_MAYOR_A_TANGO" }
  if ($publicadoPresta -and $saldoPresta -le 0 -and $saldoReal -gt 0) { return "CANAL_SIN_STOCK" }
  return "OK"
}

$panelFullPath = Resolve-LocalPath $PanelCsv
$liveFullPath = Resolve-LocalPath $LiveCsv

if (!(Test-Path -LiteralPath $panelFullPath)) {
  throw "No existe PanelCsv: $panelFullPath"
}

if (!(Test-Path -LiteralPath $liveFullPath)) {
  throw "No existe LiveCsv: $liveFullPath"
}

$panelRows = @(Import-Csv -LiteralPath $panelFullPath -Delimiter ";")
$liveRows = @(Import-Csv -LiteralPath $liveFullPath -Delimiter ";")
$liveByProduct = @{}
foreach ($live in $liveRows) {
  if (![string]::IsNullOrWhiteSpace($live.Id_Producto_Prestashop)) {
    $liveByProduct[[string]$live.Id_Producto_Prestashop] = $live
  }
}

$merged = foreach ($row in $panelRows) {
  $live = $null
  if (![string]::IsNullOrWhiteSpace($row.Id_Producto_Prestashop)) {
    $live = $liveByProduct[[string]$row.Id_Producto_Prestashop]
  }

  $saldoNexo = To-Decimal $row.Saldo_Prestashop
  $saldoReal = To-Decimal $row.Saldo_Real
  $saldoRealComparacion = if ($saldoReal -lt 0) { [decimal]0 } else { $saldoReal }
  $saldoBna = To-Decimal $row.Saldo_BNA

  if ($null -ne $live) {
    $saldoLive = To-Decimal $live.Cantidad_Prestashop_Live
    $row.Saldo_Prestashop = Format-Decimal $saldoLive
    $row.Dif_Prestashop_vs_Real = Format-Decimal ($saldoLive - $saldoRealComparacion)
    $row.Dias_Sin_Actualizar_Prestashop = "0"
    $row.Prestashop_Desactualizado = "0"
    $row.Estado_Monitoreo = Get-MonitorState $row
  }

  $ordered = [ordered]@{}
  foreach ($prop in $row.PSObject.Properties) {
    $ordered[$prop.Name] = $prop.Value
    if ($prop.Name -eq "Saldo_Prestashop") {
      $ordered["Saldo_Prestashop_Nexo"] = Format-Decimal $saldoNexo
      $ordered["Saldo_Prestashop_Live"] = if ($null -ne $live) { Format-Decimal (To-Decimal $live.Cantidad_Prestashop_Live) } else { "" }
      $ordered["Fecha_Consulta_Prestashop_Live"] = if ($null -ne $live) { $live.Fecha_Consulta_Live } else { "" }
      $ordered["Fuente_Saldo_Prestashop"] = if ($null -ne $live) { "PRESTASHOP_API" } else { "NEXO" }
    }
  }

  [pscustomobject]$ordered
}

$merged | Export-Csv -LiteralPath $panelFullPath -Delimiter ";" -NoTypeInformation -Encoding UTF8

$liveCount = ($merged | Where-Object { $_.Fuente_Saldo_Prestashop -eq "PRESTASHOP_API" }).Count
Write-Host "OK merge PrestaShop live: $liveCount articulos actualizados en $panelFullPath"
