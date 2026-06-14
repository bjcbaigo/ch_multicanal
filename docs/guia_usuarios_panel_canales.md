# Guia de usuarios - Panel Canales Digitales

Esta guia explica como leer el panel de Canales Digitales de CHEMES y que acciones operativas conviene tomar con cada dato.

## Objetivo del panel

El panel permite comparar, articulo por articulo, la informacion de TANGO contra los canales digitales publicados:

- Prestashop / Chemes Web
- BNA Producteca
- MercadoLibre, preparado para seguimiento visual y futuras reglas especificas
- TANGO como fuente de referencia

La lectura principal es detectar diferencias de stock, posibles quiebres, cobertura baja y articulos publicados con informacion desalineada.

## Encabezado superior

La parte superior resume la situacion general:

- `Monitoreados`: cantidad total de articulos evaluados.
- `Quiebre critico`: articulos donde hay riesgo operativo de venta sin stock suficiente.
- `Cobertura baja`: articulos con ventas recientes y pocos dias de cobertura.
- `Canal mayor a TANGO`: articulos donde algun canal informa mas stock que el disponible de referencia.
- `Prestashop`: cantidad de articulos publicados en Prestashop.
- `BNA Producteca`: cantidad de articulos con informacion Producteca/BNA disponible en el panel. Puede incluir articulos con saldo calculado por la regla Producteca aunque no esten marcados como publicados por la relacion NEXO.

La fecha de `Ultima exportacion` indica cuando fue actualizada la informacion.

## Vistas rapidas

Las vistas rapidas son filtros operativos:

- `Todo`: muestra todos los articulos.
- `Quiebres`: muestra articulos con posible quiebre de stock.
- `Cobertura baja`: muestra articulos con menos de 7 dias estimados de cobertura.
- `Diferencias`: muestra articulos donde el canal informa mas stock que TANGO.
- `Canal sin stock`: muestra articulos donde el canal informa stock cero, pero TANGO tiene disponible.

Estas vistas sirven para ordenar la revision diaria sin tener que armar filtros manuales.

## Tabla de articulos

Cada fila representa un articulo. Las columnas principales son:

- `Articulo`: codigo, descripcion, familia e imagen del producto.
- `Estado`: clasificacion operativa del articulo.
- `Canales`: logos de los canales donde el articulo esta vinculado o publicado.
- `CD`: stock disponible del deposito Centro de Distribucion.
- `C.CD`: stock comprometido del deposito Centro de Distribucion.
- `CA`: stock disponible del deposito Candioti.
- `C.CA`: stock comprometido del deposito Candioti.
- `COLCH.`: stock disponible del deposito 50, Santa Fe Colchoneria.
- `C. COLCH`: stock comprometido del deposito 50, Santa Fe Colchoneria.
- `T. DISPO.`: total disponible de referencia para el panel.
- `C.TOTAL`: total comprometido.
- `VENTAS 30D`: ventas de los ultimos 30 dias.
- `ROT/DIA`: rotacion diaria calculada con las ventas de los ultimos 30 dias.
- `COBERTURA`: dias estimados de cobertura.
- `PRESTA`: saldo informado o leido para Prestashop.
- `PRODUC`: saldo calculado bajo la regla de Producteca/BNA.

Las columnas de diferencias ayudan a detectar rapidamente desalineaciones entre canal y referencia.

Cuando se filtra por `BNA Producteca`, el panel muestra articulos con informacion Producteca: publicados/vinculados en BNA o con saldo calculado por la regla Producteca. Esto evita ocultar articulos que tienen saldo Producteca aunque no figuren como publicados en la relacion NEXO.

## Como interpretar los estados

- `OK`: no se detecta alerta principal para el articulo.
- `Quiebre`: el canal puede vender, pero el stock de referencia no acompana.
- `Cobertura baja`: hay ventas recientes y la cobertura estimada es menor o igual a 7 dias.
- `Canal mayor a TANGO`: el canal informa mas stock que la referencia de TANGO.
- `Canal sin stock`: TANGO tiene disponible, pero el canal esta informando stock cero.
- `Sin canal digital`: el articulo existe en TANGO, pero no esta publicado en los canales monitoreados.

## Lectura sugerida para operacion diaria

1. Revisar primero `Quiebres`.
2. Validar los articulos con `Canal mayor a TANGO`, porque pueden generar ventas sin respaldo.
3. Revisar `Cobertura baja` para anticipar reposicion o ajuste comercial.
4. Usar `Canal sin stock` para detectar oportunidades de venta bloqueadas por stock mal informado.
5. Exportar a Excel cuando sea necesario compartir revision con compras, deposito, ecommerce o administracion.

## Exportacion a Excel

El boton `Exportar Excel` descarga la vista actual. Si hay filtros aplicados, se exportan los articulos filtrados; si no hay filtros, se exporta el conjunto completo.

El archivo exportado conserva columnas tecnicas adicionales para auditoria, como fechas de consulta, fuente del saldo y datos de precios.
