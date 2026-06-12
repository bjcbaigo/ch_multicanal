# ch_multicanal

Panel web para monitorear articulos CHEMES publicados en canales digitales.

Incluye:

- Control de Prestashop con stock vivo via API.
- Control de Producteca/BNA usando la regla de TangoTienda: depositos `CD` y `SV`, sucursal `100`, neto de comprometido.
- Stock disponible CD/CA/Colch., comprometido, ventas de ultimos 30 dias, rotacion y cobertura.
- Exportacion a Excel desde la pantalla.

El proyecto principal esta en `outputs/panel_canales_digitales`.

Acceso directo local/GitHub Pages: `index.html`.

No se versionan credenciales ni archivos generados. Configurar las variables/archivos secretos en el servidor antes de ejecutar los scripts de refresh.

## Documentacion operativa

- Guia para usuarios: `docs/guia_usuarios_panel_canales.md`
- Registro tecnico y reglas actuales: `docs/registro_tecnico_canales_digitales.md`

Estas notas deben mantenerse actualizadas cada vez que se agregue un canal, deposito, regla de stock o cambio de lectura operativa.

## Exportacion de imagenes desde PrestaShop

El proyecto incluye un extractor para bajar las imagenes de productos de PrestaShop y guardarlas localmente con nombre basado en el SKU.

Script:

```powershell
scripts\export_prestashop_sku_images.py
```

Uso recomendado desde la raiz del proyecto:

```powershell
python .\scripts\export_prestashop_sku_images.py --output-dir .\prestashop_imagenes --page-size 50 --retries 5
```

Salida local:

```text
C:\Users\rbaig\Documents\Codex\2026-06-11\nueva-necesidad-hay-que-hacer-un\prestashop_imagenes
```

Criterio de nombres:

- Primera imagen del articulo: `SKU.jpg`
- Imagenes adicionales: `SKU_2.jpg`, `SKU_3.jpg`, etc.
- Si PrestaShop tiene espacios en la referencia, se conservan en el nombre del archivo.

El proceso genera tambien:

```text
prestashop_imagenes\_manifest.csv
```

Ese manifiesto permite auditar cada producto e imagen con estos estados:

- `OK`: imagen descargada en la corrida actual.
- `YA_EXISTE`: imagen ya estaba descargada y se omitio para no repetir trabajo.
- `SIN_IMAGEN`: el producto no informa imagenes en PrestaShop.
- `SIN_SKU`: el producto no tiene referencia/SKU.
- `ERROR_DESCARGA`: PrestaShop informo una imagen, pero no se pudo descargar, por ejemplo por `404 Not Found`.

La descarga es incremental: se puede ejecutar nuevamente y el script saltea los archivos existentes. Esto sirve para reintentar errores o actualizar la carpeta con productos nuevos.

Las carpetas `prestashop_imagenes*` estan ignoradas por Git para evitar subir miles de imagenes al repositorio.

## Imagenes en el panel web

El panel `outputs/panel_canales_digitales/index.html` muestra miniaturas de productos tomando la imagen desde:

```text
assets/productos/SKU.jpg
```

En el servidor web la ruta publicada queda bajo:

```text
\\10.10.10.109\E$\Tareas\ticketera\frontend\assets\productos
```

La carpeta de imagenes del panel no se versiona en Git. Para actualizarla se vuelve a ejecutar el extractor de PrestaShop y luego se sincronizan los `.jpg` hacia `assets/productos`.
