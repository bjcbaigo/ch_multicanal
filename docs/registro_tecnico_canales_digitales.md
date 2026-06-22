# Registro tecnico - Panel Canales Digitales

Este documento registra las reglas y decisiones actuales del panel para facilitar mantenimiento y futuras incorporaciones de canales.

## Ubicacion del proyecto

- Repositorio GitHub: `bjcbaigo/ch_multicanal`
- Carpeta principal del panel: `outputs/panel_canales_digitales`
- HTML publicado en servidor: `\\10.10.10.109\E$\Tareas\ticketera\frontend\canales-digitales.html`
- URL servidor: `http://10.10.10.109:8089/canales-digitales.html`
- GitHub Pages: `https://bjcbaigo.github.io/ch_multicanal/`

## Flujo de datos

1. El servidor ejecuta `refresh_canales_digitales.ps1`.
2. El script exporta datos desde SQL/TANGO con `export_canales_digitales_csvs.ps1`.
3. Se genera `canales_articulos_publicados.csv`.
4. Si estan configuradas las variables de Apps Script, el CSV se publica via POST con `publish_canales_csv_appscript.ps1`.
5. El panel web lee el CSV local del servidor o el CSV servido por Apps Script, segun la forma de acceso.

## Fuentes principales

- Catalogo TANGO: `dbo.AXV_ARTICULO`
- Precios TANGO: `dbo.GVA17` y `dbo.GVA10`
- Relacion articulo/canal: `dbo.NEXO_RELACION_ARTICULO_TIENDA`
- Stock por deposito: `dbo.CTA_SALDO_ARTICULO_DEPOSITO`
- Depositos: `dbo.CTA_DEPOSITO`
- Sucursales: `dbo.SUCURSAL`
- Prestashop: API directa para stock vivo cuando esta disponible

## Depositos visibles

El panel muestra estos depositos:

- `CD`: Centro de Distribucion.
- `CA`: Deposito Candioti.
- `COLCH.`: deposito `50`, Santa Fe Colchoneria.

Cada deposito tiene su columna de disponible y comprometido:

- `CD` / `C.CD`
- `CA` / `C.CA`
- `COLCH.` / `C. COLCH`

## Regla de total disponible

Por ahora `T. DISPO.` se mantiene como referencia operativa basada en `CD + CA`.

El deposito `50` se muestra para visibilidad operativa, pero no se incorporo al calculo de quiebre/cobertura general para no cambiar las reglas ya validadas.

Si mas adelante se decide que `50` debe formar parte del saldo real, hay que modificar la CTE `Stock` en `sql/canales_articulos_publicados.sql` y recalcular:

- `Saldo_Real`
- `Stock_Actual_Total`, si corresponde
- `Dif_Prestashop_vs_Real`
- `Dias_Cobertura`
- reglas de `Estado_Monitoreo`

## Regla Producteca/BNA

La regla Producteca/BNA se mantiene separada de la vista visible de depositos:

- sucursal `100`
- depositos `CD` y `SV`
- saldo neto: `Quantity - EngagedQuantity`

Esta regla surge del script Producteca compartido:

```javascript
if ((obj.WarehouseCode == "CD" || obj.WarehouseCode == "SV") && obj.StoreNumber == 100) {
  quantity: parseInt(obj.Quantity - obj.EngagedQuantity)
}
```

Por eso `SV` no se muestra como columna operativa en el panel, pero sigue siendo parte del calculo de `PRODUC`.

El filtro visual `BNA Producteca` no se limita a `Publicado_BNA = 1`. Tambien incluye articulos con informacion Producteca calculada:

- `Saldo_BNA <> 0`
- `Stock_Producteca_Total <> 0`
- `Stock_Comprometido_Producteca <> 0`

Esto corrige casos donde el articulo no esta vinculado como publicado por NEXO, pero Producteca igualmente tiene saldo calculado por la regla del integrador.

## Prestashop

Prestashop se lee contra API directa cuando la extraccion esta habilitada. El panel distingue la fuente en columnas internas y exportacion:

- saldo desde API directa
- saldo NEXO como referencia secundaria
- fecha de consulta
- dias sin actualizar cuando aplica

La diferencia `Dif Presta` compara `PRESTA` contra la referencia disponible, evitando tomar saldos negativos como disponibilidad real.

## Estado saldo negativo

El estado `SALDO_NEGATIVO` se usa para evitar que articulos con saldos bajo cero queden como `OK`. Aplica cuando cualquiera de estos valores es menor a cero:

- `Saldo_Prestashop`
- `Stock_Producteca_Total`
- `Saldo_Real`
- `Stock_Disponible_CD`
- `Stock_Disponible_CA`
- `Stock_Disponible_50`

Ejemplo: si Prestashop informa `-4` y TANGO tiene `0`, no corresponde `QUIEBRE` porque el canal no informa stock positivo, pero tampoco corresponde `OK`. En ese caso se clasifica como `SALDO_NEGATIVO` para revision operativa.

## Imagenes de productos

El panel intenta cargar imagen local por SKU:

```text
assets/productos/SKU.jpg
```

Si la imagen local no existe y hay manifiesto, usa la URL publica de Prestashop registrada en:

```text
assets/productos_manifest.json
```

Las imagenes descargadas no se versionan en Git para evitar subir miles de archivos pesados.

## Como agregar un canal nuevo

Para sumar un canal nuevo conviene seguir esta secuencia:

1. Identificar fuente de datos: NEXO, API directa, archivo externo o integrador.
2. Definir la regla de stock del canal: deposito, sucursal, comprometido, reserva y si usa stock bruto o neto.
3. Agregar columnas en `sql/canales_articulos_publicados.sql`.
4. Incorporar el canal al CSV y al contrato de exportacion si corresponde.
5. Agregar logo en `assets/canales`.
6. Ajustar el frontend `index.html` para mostrar presencia, saldo y diferencias.
7. Agregar filtros o vistas rapidas solo si aportan accion operativa.
8. Documentar la regla en este archivo.

## Criterios de UX actuales

- Priorizar alertas accionables antes que volumen de datos.
- Mantener imagen, codigo, descripcion y familia visibles al inicio de cada fila.
- Usar logos de canales en lugar de siglas cuando sea posible.
- Mantener encabezados abreviados para reducir scroll horizontal.
- Exportar a Excel la vista filtrada para trabajo entre areas.
