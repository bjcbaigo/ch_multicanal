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
- stock disponible y comprometido por depositos operativos visibles: `CD`, `CA` y `50` mostrado como `COLCH.`
- saldo real disponible consolidado para la regla vigente del panel
- diferencias de stock entre canal y TANGO
- estado operativo: `OK`, `QUIEBRE`, `CANAL_SIN_STOCK`, `CANAL_MAYOR_A_TANGO`, `SIN_CANAL_DIGITAL`

## Lectura de columnas visibles

La tabla usa encabezados abreviados para reducir scroll horizontal:

- `CD`: disponible Centro de Distribucion.
- `C.CD`: comprometido Centro de Distribucion.
- `CA`: disponible Deposito Candioti.
- `C.CA`: comprometido Deposito Candioti.
- `COLCH.`: disponible deposito `50`, Santa Fe Colchoneria.
- `C. COLCH`: comprometido deposito `50`, Santa Fe Colchoneria.
- `T. DISPO.`: total disponible usado como referencia operativa.
- `C.TOTAL`: comprometido total.
- `VENTAS 30D`: unidades vendidas en los ultimos 30 dias.
- `ROT/DIA`: promedio diario de venta segun ultimos 30 dias.
- `COBERTURA`: dias estimados de stock.
- `PRESTA`: saldo Prestashop.
- `PRODUC`: saldo Producteca/BNA calculado bajo regla del integrador.

El deposito `50` se muestra para visibilidad, pero la regla vigente de `T. DISPO.` y cobertura continua basada en `CD + CA` salvo cambio funcional posterior.

## Uso

1. Exportar datos:

```powershell
$env:CHEMES_SQL_AXOFT_USER='<usuario-sql>'
$env:CHEMES_SQL_AXOFT_PASSWORD='<password-sql>'
.\export_canales_digitales_csvs.ps1
```

2. Publicar o copiar el contenido de `out` junto con `index.html`.

3. Abrir `index.html` desde un servidor local o desde Apps Script/Drive siguiendo el mismo patron usado en la Ticketera/paneles CHEMES.

## Publicacion online con Apps Script

GitHub Pages puede publicar el HTML, pero no debe versionar el CSV operativo. Para alimentar el panel online:

1. Crear un proyecto en Google Apps Script.
2. Copiar el contenido de `apps_script/Code.gs`.
3. Configurar una Script Property:
   - `CHEMES_CANALES_TOKEN`: token privado para aceptar uploads desde el servidor.
4. Publicar como Web App:
   - Execute as: el propietario del script.
   - Who has access: cualquiera con el enlace, o la opcion equivalente disponible en la cuenta.
5. En el servidor que ejecuta la tarea, configurar:

```powershell
$env:CHEMES_CANALES_APPSCRIPT_URL='<url-web-app>'
$env:CHEMES_CANALES_APPSCRIPT_TOKEN='<token-configurado>'
```

6. La tarea `refresh_canales_digitales.ps1` genera el CSV y, si esas variables existen, ejecuta:

```powershell
.\publish_canales_csv_appscript.ps1 -CsvPath '..\frontend\out\canales_articulos_publicados.csv'
```

7. Para GitHub Pages se puede abrir:

```text
https://bjcbaigo.github.io/ch_multicanal/?dataUrl=<url-web-app>
```

Tambien se puede dejar fija la URL en `APP_SCRIPT_DATA_URL` dentro de `index.html` si no se quiere usar parametro.

## Archivos

- `sql/canales_articulos_publicados.sql`: consulta principal.
- `csv_exports_manifest.csv`: contrato para exportar el CSV.
- `export_canales_digitales_csvs.ps1`: exportador SQL a CSV separado por `;`.
- `export_prestashop_live_stock.ps1`: consulta stock vivo Prestashop.
- `apply_prestashop_live_stock.ps1`: reemplaza saldo Prestashop NEXO por API.
- `publish_canales_csv_appscript.ps1`: publica el CSV hacia Apps Script.
- `apps_script/Code.gs`: receptor Apps Script para guardar y servir el CSV.
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

La guia funcional para usuarios esta en `../../docs/guia_usuarios_panel_canales.md` y el registro tecnico ampliado esta en `../../docs/registro_tecnico_canales_digitales.md`.
