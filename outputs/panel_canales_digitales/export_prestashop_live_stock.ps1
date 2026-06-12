param(
  [string]$ShopUrl = "https://chemesweb.com.ar",
  [string]$InputCsv = ".\out\canales_articulos_publicados.csv",
  [string]$OutputCsv = ".\out\prestashop_stock_live.csv",
  [string]$CredentialFile = ".\.config\dashboard-credentials.xml",
  [string]$ApiKeyFile = "",
  [string]$PrestaApiKey = "",
  [int]$PageSize = 500
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function ConvertFrom-SecureStringValue {
  param([securestring]$SecureString)
  if ($null -eq $SecureString) { return "" }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
  finally {
    if ($bstr -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  }
}

function Resolve-LocalPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return (Join-Path -Path (Get-Location) -ChildPath $Path)
}

function New-PrestashopAuthHeader {
  param([string]$Key)
  $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Key}:"))
  return @{ Authorization = "Basic $token" }
}

function Join-Url {
  param([string]$Base, [string]$Path)
  return $Base.TrimEnd("/") + "/" + $Path.TrimStart("/")
}

function Invoke-PrestashopXml {
  param([string]$Url)
  $response = Invoke-WebRequest -Uri $Url -Headers $script:Headers -Method Get -UseBasicParsing
  return [xml]$response.Content
}

function Get-XmlText {
  param($Node)
  if ($null -eq $Node) { return "" }
  return [string]$Node.InnerText
}

if ([string]::IsNullOrWhiteSpace($PrestaApiKey)) {
  $envKey = [Environment]::GetEnvironmentVariable("CHEMES_PRESTASHOP_API_KEY", "Process")
  if (![string]::IsNullOrWhiteSpace($envKey)) { $PrestaApiKey = $envKey }
}

$apiKeyFullPath = if ([string]::IsNullOrWhiteSpace($ApiKeyFile)) { "" } else { Resolve-LocalPath $ApiKeyFile }
if ([string]::IsNullOrWhiteSpace($PrestaApiKey) -and ![string]::IsNullOrWhiteSpace($apiKeyFullPath) -and (Test-Path -LiteralPath $apiKeyFullPath)) {
  $PrestaApiKey = (Get-Content -LiteralPath $apiKeyFullPath -Raw).Trim()
}

$credentialFullPath = Resolve-LocalPath $CredentialFile
if ([string]::IsNullOrWhiteSpace($PrestaApiKey) -and (Test-Path -LiteralPath $credentialFullPath)) {
  $savedCredentials = Import-Clixml -LiteralPath $credentialFullPath
  if ($null -ne $savedCredentials.PrestaApiKey) {
    $PrestaApiKey = ConvertFrom-SecureStringValue $savedCredentials.PrestaApiKey
  }
}

if ([string]::IsNullOrWhiteSpace($PrestaApiKey)) {
  throw "No hay API key PrestaShop disponible. Usar -PrestaApiKey, CHEMES_PRESTASHOP_API_KEY o CredentialFile."
}

$inputFullPath = Resolve-LocalPath $InputCsv
$outputFullPath = Resolve-LocalPath $OutputCsv
$outputDir = Split-Path -Parent $outputFullPath
if (!(Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$script:Headers = New-PrestashopAuthHeader -Key $PrestaApiKey

$apiIndex = Invoke-PrestashopXml (Join-Url $ShopUrl "/api/")
$resourceNames = @($apiIndex.prestashop.api.ChildNodes | ForEach-Object { $_.Name })
$stockResource = $apiIndex.prestashop.api.stock_availables
if ($resourceNames -notcontains "stock_availables" -or [string]$stockResource.get -ne "true") {
  throw "La API key PrestaShop valida, pero no tiene permiso GET sobre stock_availables. Habilitar ese recurso para leer stock vivo."
}

$rows = Import-Csv -LiteralPath $inputFullPath -Delimiter ";"
$productIds = @(
  $rows |
    Where-Object { $_.Publicado_Prestashop -eq "1" -and ![string]::IsNullOrWhiteSpace($_.Id_Producto_Prestashop) } |
    ForEach-Object { [string]$_.Id_Producto_Prestashop } |
    Sort-Object -Unique
)

if (!$productIds.Count) {
  @() | Export-Csv -LiteralPath $outputFullPath -Delimiter ";" -NoTypeInformation -Encoding UTF8
  Write-Host "No hay productos PrestaShop para consultar."
  return
}

$wanted = @{}
foreach ($id in $productIds) { $wanted[$id] = $true }

$liveRows = New-Object System.Collections.Generic.List[object]
$offset = 0
do {
  $url = Join-Url $ShopUrl "/api/stock_availables"
  $query = "display=[id,id_product,id_product_attribute,quantity,depends_on_stock,out_of_stock]&sort=[id_ASC]&limit=$offset,$PageSize"
  $xml = Invoke-PrestashopXml "$url`?$query"
  $batch = @($xml.prestashop.stock_availables.stock_available)

  foreach ($stock in $batch) {
    $idProduct = Get-XmlText $stock.id_product
    if ($wanted.ContainsKey($idProduct)) {
      $liveRows.Add([pscustomobject]@{
        Id_Producto_Prestashop = $idProduct
        Id_Stock_Available = Get-XmlText $stock.id
        Id_Product_Attribute = Get-XmlText $stock.id_product_attribute
        Cantidad_Prestashop_Live = Get-XmlText $stock.quantity
        Depends_On_Stock = Get-XmlText $stock.depends_on_stock
        Out_Of_Stock = Get-XmlText $stock.out_of_stock
        Fecha_Consulta_Live = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      })
    }
  }

  $offset += $PageSize
} while ($batch.Count -eq $PageSize)

$liveRows |
  Group-Object Id_Producto_Prestashop |
  ForEach-Object {
    $sum = ($_.Group | ForEach-Object { [decimal]($_.Cantidad_Prestashop_Live -replace ",", ".") } | Measure-Object -Sum).Sum
    [pscustomobject]@{
      Id_Producto_Prestashop = $_.Name
      Cantidad_Prestashop_Live = [decimal]$sum
      Registros_Stock_Live = $_.Count
      Fecha_Consulta_Live = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
  } |
  Export-Csv -LiteralPath $outputFullPath -Delimiter ";" -NoTypeInformation -Encoding UTF8

Write-Host "OK $outputFullPath ($($liveRows.Count) registros stock consultados)"
