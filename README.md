# ch_multicanal

Panel web para monitorear articulos CHEMES publicados en canales digitales.

Incluye:

- Control de Prestashop con stock vivo via API.
- Control de Producteca/BNA usando la regla de TangoTienda: depositos `CD` y `SV`, sucursal `100`, neto de comprometido.
- Stock disponible CD/CA, comprometido, ventas de ultimos 30 dias, rotacion y cobertura.
- Exportacion a Excel desde la pantalla.

El proyecto principal esta en `outputs/panel_canales_digitales`.

No se versionan credenciales ni archivos generados. Configurar las variables/archivos secretos en el servidor antes de ejecutar los scripts de refresh.
