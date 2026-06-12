# Panel de articulos publicados en canales digitales

Este paquete arma un panel operativo para comparar articulos de TANGO contra canales digitales:

- Prestashop: `API / PrestaShop_itst`
- BNA Producteca: `API / Tienda_BNA`
- MercadoLibre: queda preparado como canal adicional

## Fuente de datos detectada

- Catalogo TANGO: `dbo.AXV_ARTICULO`
- Precios TANGO: `dbo.GVA17` + `dbo.GVA10`
- Relacion articulo/canal: `dbo.NEXO_RELACION_ARTICULO_TIENDA`
- Stock por deposito: `dbo.CTA_SALDO_ARTICULO_DEPOSITO`
- Depositos: `dbo.CTA_DEPOSITO`
- Sucursales: `dbo.SUCURSAL`

Base usada para el primer corte: `10.10.10.109 / SUC_CHEMESWEB`.

Nota: Producteca/BNA se calcula con la misma regla usada por el integrador: depositos `CD` y `SV`, sucursal `100`, neto de comprometido.

## CSV principal

`canales_articulos_publicados.csv` incluye una fila por articulo con:

- datos base del articulo en TANGO
- presencia en Prestashop y BNA
- saldo informado por cada canal
- precios TANGO principales: contado, web, MercadoLibre y BNA
- saldo real disponible consolidado
- diferencias de stock entre canal y TANGO
- estado operativo: `OK`, `QUIEBRE`, `CANAL_SIN_STOCK`, `CANAL_MAYOR_A_TANGO`, `SIN_CANAL_DIGITAL`

## Uso

1. Exportar datos:

```powershell
$env:CHEMES_SQL_AXOFT_USER='<usuario-sql>'
$env:CHEMES_SQL_AXOFT_PASSWORD='<password-sql>'
.\export_canales_digitales_csvs.ps1
```

2. Publicar o copiar el contenido de `out` junto con `index.html`.

3. Abrir `index.html` desde un servidor local o desde Apps Script/Drive siguiendo el mismo patron usado en la Ticketera/paneles CHEMES.

## Archivos

- `sql/canales_articulos_publicados.sql`: consulta principal.
- `csv_exports_manifest.csv`: contrato para exportar el CSV.
- `export_canales_digitales_csvs.ps1`: exportador SQL a CSV separado por `;`.
- `index.html`: panel frontend autocontenido.

## Nota de implementacion

La consulta deja columnas fijas para listas comerciales relevantes hoy:

- `Precio_Lista_1_Contado`
- `Precio_Lista_20_Web`
- `Precio_Lista_200_ML_45`
- `Precio_Lista_201_ML_75`
- `Precio_Lista_202_ML_Editable`
- `Precio_Lista_500_BNA_18CSI`
- `Precio_Lista_501_BNA_EFICI`

Si luego suman otro canal, conviene agregar sus listas a la CTE `Precios` y una seccion de agregacion en `Canales`.
