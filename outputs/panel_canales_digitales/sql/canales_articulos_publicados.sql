/* Contract CSV: canales_articulos_publicados.csv
   Articulos TANGO publicados en canales digitales, con precios, saldo real y saldo informado por canal.
   Base inicial: SUC_CHEMESWEB.
*/

WITH CanalesRaw AS (
  SELECT
    LTRIM(RTRIM(COD_STA11)) COLLATE DATABASE_DEFAULT AS COD_ARTICU,
    CASE
      WHEN UPPER(ISNULL(USUARIO_TIENDA_VENDEDOR, '')) LIKE '%PRESTASHOP%' THEN 'PRESTASHOP'
      WHEN UPPER(ISNULL(USUARIO_TIENDA_VENDEDOR, '')) LIKE '%BNA%' THEN 'BNA_PRODUCTECA'
      WHEN UPPER(ISNULL(TIENDA, '')) LIKE '%MERCADOLIBRE%' THEN 'MERCADOLIBRE'
      ELSE UPPER(LTRIM(RTRIM(ISNULL(TIENDA, 'OTRO'))))
    END AS Canal,
    LTRIM(RTRIM(ISNULL(TIENDA, ''))) AS Tienda,
    LTRIM(RTRIM(ISNULL(USUARIO_TIENDA_VENDEDOR, ''))) AS Usuario_Tienda,
    LTRIM(RTRIM(ISNULL(CODIGO_ARTICULO_TIENDA, ''))) AS Codigo_Canal,
    LTRIM(RTRIM(ISNULL(SKU, ''))) AS SKU_Canal,
    LTRIM(RTRIM(ISNULL(ESTADO, ''))) AS Estado_Canal,
    CONVERT(decimal(18,2), ISNULL(CANTIDAD_DISPONIBLE, 0)) AS Saldo_Canal,
    CONVERT(varchar(19), FECHA_VIGENCIA, 120) AS Fecha_Vigencia
  FROM dbo.NEXO_RELACION_ARTICULO_TIENDA
  WHERE NULLIF(LTRIM(RTRIM(COD_STA11)), '') IS NOT NULL
    AND (
      UPPER(ISNULL(USUARIO_TIENDA_VENDEDOR, '')) LIKE '%PRESTASHOP%'
      OR UPPER(ISNULL(USUARIO_TIENDA_VENDEDOR, '')) LIKE '%BNA%'
      OR UPPER(ISNULL(TIENDA, '')) LIKE '%MERCADOLIBRE%'
    )
),
Canales AS (
  SELECT
    COD_ARTICU,
    MAX(CASE WHEN Canal = 'PRESTASHOP' THEN 1 ELSE 0 END) AS Publicado_Prestashop,
    MAX(CASE WHEN Canal = 'PRESTASHOP' THEN Estado_Canal END) AS Estado_Prestashop,
    MAX(CASE WHEN Canal = 'PRESTASHOP' THEN Codigo_Canal END) AS Id_Producto_Prestashop,
    MAX(CASE WHEN Canal = 'PRESTASHOP' THEN SKU_Canal END) AS SKU_Prestashop,
    MAX(CASE WHEN Canal = 'PRESTASHOP' THEN Saldo_Canal END) AS Saldo_Prestashop,
    COUNT(CASE WHEN Canal = 'PRESTASHOP' THEN 1 END) AS Publicaciones_Prestashop,
    MAX(CASE WHEN Canal = 'PRESTASHOP' THEN Fecha_Vigencia END) AS Fecha_Prestashop,

    MAX(CASE WHEN Canal = 'BNA_PRODUCTECA' THEN 1 ELSE 0 END) AS Publicado_BNA,
    MAX(CASE WHEN Canal = 'BNA_PRODUCTECA' THEN Estado_Canal END) AS Estado_BNA,
    MAX(CASE WHEN Canal = 'BNA_PRODUCTECA' THEN Saldo_Canal END) AS Saldo_BNA,
    COUNT(CASE WHEN Canal = 'BNA_PRODUCTECA' THEN 1 END) AS Publicaciones_BNA,
    MAX(CASE WHEN Canal = 'BNA_PRODUCTECA' THEN Fecha_Vigencia END) AS Fecha_BNA,

    MAX(CASE WHEN Canal = 'MERCADOLIBRE' THEN 1 ELSE 0 END) AS Publicado_MercadoLibre,
    MAX(CASE WHEN Canal = 'MERCADOLIBRE' THEN Saldo_Canal END) AS Saldo_MercadoLibre,
    COUNT(CASE WHEN Canal = 'MERCADOLIBRE' THEN 1 END) AS Publicaciones_MercadoLibre
  FROM CanalesRaw
  GROUP BY COD_ARTICU
),
Articulos AS (
  SELECT
    LTRIM(RTRIM(COD_STA11)) COLLATE DATABASE_DEFAULT AS COD_ARTICU,
    LTRIM(RTRIM(DESCRIPCIO)) AS Descripcion,
    LTRIM(RTRIM(ISNULL(COD_BARRA, ''))) AS Codigo_Barra,
    ISNULL(STOCK, 0) AS Maneja_Stock,
    ISNULL(SINCRONIZA_NEXO_TIENDAS, 0) AS Sincroniza_Nexo_Tiendas,
    LTRIM(RTRIM(ISNULL(FAMILIA, ''))) AS Familia,
    LTRIM(RTRIM(ISNULL(GRUPO, ''))) AS Grupo
  FROM dbo.AXV_ARTICULO
  WHERE NULLIF(LTRIM(RTRIM(COD_STA11)), '') IS NOT NULL
),
Precios AS (
  SELECT
    LTRIM(RTRIM(g.COD_ARTICU)) COLLATE DATABASE_DEFAULT AS COD_ARTICU,
    MAX(CASE WHEN g.NRO_DE_LIS = 1 THEN CONVERT(decimal(18,2), g.PRECIO) END) AS Precio_Lista_1_Contado,
    MAX(CASE WHEN g.NRO_DE_LIS = 20 THEN CONVERT(decimal(18,2), g.PRECIO) END) AS Precio_Lista_20_Web,
    MAX(CASE WHEN g.NRO_DE_LIS = 200 THEN CONVERT(decimal(18,2), g.PRECIO) END) AS Precio_Lista_200_ML_45,
    MAX(CASE WHEN g.NRO_DE_LIS = 201 THEN CONVERT(decimal(18,2), g.PRECIO) END) AS Precio_Lista_201_ML_75,
    MAX(CASE WHEN g.NRO_DE_LIS = 202 THEN CONVERT(decimal(18,2), g.PRECIO) END) AS Precio_Lista_202_ML_Editable,
    MAX(CASE WHEN g.NRO_DE_LIS = 500 THEN CONVERT(decimal(18,2), g.PRECIO) END) AS Precio_Lista_500_BNA_18CSI,
    MAX(CASE WHEN g.NRO_DE_LIS = 501 THEN CONVERT(decimal(18,2), g.PRECIO) END) AS Precio_Lista_501_BNA_EFICI,
    MAX(CONVERT(varchar(19), g.FECHA_MODI, 120)) AS Fecha_Ultimo_Precio
  FROM dbo.GVA17 g
  WHERE g.NRO_DE_LIS IN (1, 20, 200, 201, 202, 500, 501)
  GROUP BY LTRIM(RTRIM(g.COD_ARTICU)) COLLATE DATABASE_DEFAULT
),
Stock AS (
  SELECT
    LTRIM(RTRIM(a.COD_ARTICULO)) COLLATE DATABASE_DEFAULT AS COD_ARTICU,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'CD' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Disponible_CD,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'CA' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Disponible_CA,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = '50' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Disponible_50,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'SV' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Disponible_SV,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'CD' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Comprometido_CD,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'CA' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Comprometido_CA,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = '50' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Comprometido_50,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'SV' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Comprometido_SV,
    SUM(CASE WHEN suc.NRO_SUCURSAL = 100 AND d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'CD' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Producteca_CD,
    SUM(CASE WHEN suc.NRO_SUCURSAL = 100 AND d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT = 'SV' THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Producteca_SV,
    SUM(CASE WHEN suc.NRO_SUCURSAL = 100 AND d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'SV') THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Producteca_Total,
    SUM(CASE WHEN suc.NRO_SUCURSAL = 100 AND d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'SV') THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Comprometido_Producteca,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'CA') THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Saldo_Real,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'CA') THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_STOCK, 0)) ELSE 0 END) AS Stock_Actual_Total,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'CA') THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_COMPROMETIDA, 0)) ELSE 0 END) AS Stock_Comprometido_Total,
    SUM(CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'CA') THEN CONVERT(decimal(18,2), ISNULL(s.CANTIDAD_PENDIENTE, 0)) ELSE 0 END) AS Stock_Pendiente_Total,
    COUNT(DISTINCT CASE WHEN d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'CA') AND ISNULL(s.CANTIDAD_STOCK, 0) - ISNULL(s.CANTIDAD_COMPROMETIDA, 0) > 0 THEN d.COD_CTA_DEPOSITO END) AS Sucursales_Con_Saldo,
    MAX(CONVERT(varchar(19), s.FECHA, 120)) AS Fecha_Stock
  FROM dbo.CTA_SALDO_ARTICULO_DEPOSITO s
  JOIN dbo.CTA_DEPOSITO d ON d.ID_CTA_DEPOSITO = s.ID_CTA_DEPOSITO
  JOIN dbo.CTA_ARTICULO a ON a.ID_CTA_ARTICULO = s.ID_CTA_ARTICULO
  LEFT JOIN dbo.SUCURSAL suc ON suc.ID_SUCURSAL = s.ID_SUCURSAL
  WHERE d.COD_CTA_DEPOSITO COLLATE DATABASE_DEFAULT IN ('CD', 'CA', '50', 'SV')
  GROUP BY LTRIM(RTRIM(a.COD_ARTICULO)) COLLATE DATABASE_DEFAULT
),
Ventas30 AS (
  SELECT
    LTRIM(RTRIM(g.COD_ARTICU)) COLLATE DATABASE_DEFAULT AS COD_ARTICU,
    SUM(CONVERT(decimal(18,2),
      CASE
        WHEN g.T_COMP COLLATE DATABASE_DEFAULT = 'N/C' THEN -1
        ELSE 1
      END * ISNULL(g.CANTIDAD, 0)
    )) AS Ventas_Ultimos_30_Dias
  FROM dbo.GVA53 g
  WHERE g.FECHA_MOV >= DATEADD(day, -30, CONVERT(date, GETDATE()))
    AND g.FECHA_MOV < DATEADD(day, 1, CONVERT(date, GETDATE()))
    AND g.T_COMP COLLATE DATABASE_DEFAULT IN ('FAC', 'N/D', 'N/C')
    AND NULLIF(LTRIM(RTRIM(g.COD_ARTICU)), '') IS NOT NULL
  GROUP BY LTRIM(RTRIM(g.COD_ARTICU)) COLLATE DATABASE_DEFAULT
)
SELECT
  a.COD_ARTICU,
  a.Descripcion,
  a.Codigo_Barra,
  a.Familia,
  a.Grupo,
  a.Maneja_Stock,
  a.Sincroniza_Nexo_Tiendas,

  ISNULL(c.Publicado_Prestashop, 0) AS Publicado_Prestashop,
  ISNULL(c.Estado_Prestashop, '') AS Estado_Prestashop,
  ISNULL(c.Id_Producto_Prestashop, '') AS Id_Producto_Prestashop,
  ISNULL(c.SKU_Prestashop, '') AS SKU_Prestashop,
  CONVERT(decimal(18,2), ISNULL(c.Saldo_Prestashop, 0)) AS Saldo_Prestashop,
  ISNULL(c.Publicaciones_Prestashop, 0) AS Publicaciones_Prestashop,
  ISNULL(c.Fecha_Prestashop, '') AS Fecha_Prestashop,
  CASE
    WHEN ISNULL(c.Publicado_Prestashop, 0) = 1 AND TRY_CONVERT(datetime, NULLIF(c.Fecha_Prestashop, ''), 120) IS NOT NULL
      THEN DATEDIFF(day, TRY_CONVERT(datetime, c.Fecha_Prestashop, 120), GETDATE())
    ELSE NULL
  END AS Dias_Sin_Actualizar_Prestashop,
  CASE
    WHEN ISNULL(c.Publicado_Prestashop, 0) = 1
      AND TRY_CONVERT(datetime, NULLIF(c.Fecha_Prestashop, ''), 120) IS NOT NULL
      AND DATEDIFF(day, TRY_CONVERT(datetime, c.Fecha_Prestashop, 120), GETDATE()) > 2
      THEN 1
    ELSE 0
  END AS Prestashop_Desactualizado,

  ISNULL(c.Publicado_BNA, 0) AS Publicado_BNA,
  ISNULL(c.Estado_BNA, '') AS Estado_BNA,
  CONVERT(decimal(18,2), ISNULL(c.Saldo_BNA, 0)) AS Saldo_BNA_Nexo,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Producteca_Total, 0)) AS Saldo_BNA,
  ISNULL(c.Publicaciones_BNA, 0) AS Publicaciones_BNA,
  ISNULL(c.Fecha_BNA, '') AS Fecha_BNA,

  ISNULL(c.Publicado_MercadoLibre, 0) AS Publicado_MercadoLibre,
  CONVERT(decimal(18,2), ISNULL(c.Saldo_MercadoLibre, 0)) AS Saldo_MercadoLibre,
  ISNULL(c.Publicaciones_MercadoLibre, 0) AS Publicaciones_MercadoLibre,

  p.Precio_Lista_1_Contado,
  p.Precio_Lista_20_Web,
  p.Precio_Lista_200_ML_45,
  p.Precio_Lista_201_ML_75,
  p.Precio_Lista_202_ML_Editable,
  p.Precio_Lista_500_BNA_18CSI,
  p.Precio_Lista_501_BNA_EFICI,
  p.Fecha_Ultimo_Precio,

  CONVERT(decimal(18,2), ISNULL(s.Stock_Disponible_CD, 0)) AS Stock_Disponible_CD,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Disponible_CA, 0)) AS Stock_Disponible_CA,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Disponible_50, 0)) AS Stock_Disponible_50,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Disponible_SV, 0)) AS Stock_Disponible_SV,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Comprometido_CD, 0)) AS Stock_Comprometido_CD,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Comprometido_CA, 0)) AS Stock_Comprometido_CA,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Comprometido_50, 0)) AS Stock_Comprometido_50,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Comprometido_SV, 0)) AS Stock_Comprometido_SV,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Producteca_CD, 0)) AS Stock_Producteca_CD,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Producteca_SV, 0)) AS Stock_Producteca_SV,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Producteca_Total, 0)) AS Stock_Producteca_Total,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Comprometido_Producteca, 0)) AS Stock_Comprometido_Producteca,
  CONVERT(decimal(18,2), ISNULL(s.Saldo_Real, 0)) AS Saldo_Real,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Actual_Total, 0)) AS Stock_Actual_Total,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Comprometido_Total, 0)) AS Stock_Comprometido_Total,
  CONVERT(decimal(18,2), ISNULL(s.Stock_Pendiente_Total, 0)) AS Stock_Pendiente_Total,
  ISNULL(s.Sucursales_Con_Saldo, 0) AS Sucursales_Con_Saldo,
  ISNULL(s.Fecha_Stock, '') AS Fecha_Stock,

  CONVERT(decimal(18,2), ISNULL(c.Saldo_Prestashop, 0) - CASE WHEN ISNULL(s.Saldo_Real, 0) < 0 THEN 0 ELSE ISNULL(s.Saldo_Real, 0) END) AS Dif_Prestashop_vs_Real,
  CONVERT(decimal(18,2), ISNULL(c.Saldo_BNA, 0) - ISNULL(s.Saldo_Real, 0)) AS Dif_BNA_vs_Real,
  CONVERT(decimal(18,2), 0) AS Dif_BNA_vs_Producteca,
  CONVERT(decimal(18,2), ISNULL(c.Saldo_BNA, 0) - ISNULL(s.Stock_Producteca_Total, 0)) AS Dif_BNA_Nexo_vs_Producteca,

  CONVERT(decimal(18,2), ISNULL(v.Ventas_Ultimos_30_Dias, 0)) AS Ventas_Ultimos_30_Dias,
  CONVERT(decimal(18,2), ISNULL(v.Ventas_Ultimos_30_Dias, 0) / 30.0) AS Rotacion_Diaria,
  CONVERT(decimal(18,2),
    CASE
      WHEN ISNULL(v.Ventas_Ultimos_30_Dias, 0) > 0 THEN ISNULL(s.Saldo_Real, 0) / (ISNULL(v.Ventas_Ultimos_30_Dias, 0) / 30.0)
      ELSE NULL
    END
  ) AS Dias_Cobertura,

  CASE
    WHEN ISNULL(c.Saldo_Prestashop, 0) < 0
      OR ISNULL(s.Stock_Producteca_Total, 0) < 0
      OR ISNULL(s.Saldo_Real, 0) < 0
      OR ISNULL(s.Stock_Disponible_CD, 0) < 0
      OR ISNULL(s.Stock_Disponible_CA, 0) < 0
      OR ISNULL(s.Stock_Disponible_50, 0) < 0 THEN 'SALDO_NEGATIVO'
    WHEN ISNULL(c.Publicado_Prestashop, 0) = 0 AND ISNULL(c.Publicado_BNA, 0) = 0 THEN 'SIN_CANAL_DIGITAL'
    WHEN (ISNULL(s.Saldo_Real, 0) <= 0 AND ISNULL(c.Saldo_Prestashop, 0) > 0)
      OR (ISNULL(c.Publicado_BNA, 0) = 1 AND ISNULL(s.Stock_Producteca_Total, 0) <= 0) THEN 'QUIEBRE'
    WHEN ISNULL(v.Ventas_Ultimos_30_Dias, 0) > 0 AND ISNULL(s.Saldo_Real, 0) > 0 AND ISNULL(s.Saldo_Real, 0) / (ISNULL(v.Ventas_Ultimos_30_Dias, 0) / 30.0) <= 7 THEN 'COBERTURA_BAJA'
    WHEN ISNULL(c.Saldo_Prestashop, 0) > ISNULL(s.Saldo_Real, 0) THEN 'CANAL_MAYOR_A_TANGO'
    WHEN ISNULL(c.Publicado_Prestashop, 0) = 1 AND ISNULL(c.Saldo_Prestashop, 0) <= 0 AND ISNULL(s.Saldo_Real, 0) > 0 THEN 'CANAL_SIN_STOCK'
    ELSE 'OK'
  END AS Estado_Monitoreo,
  CONVERT(varchar(19), GETDATE(), 120) AS Fecha_Exportacion
FROM Articulos a
LEFT JOIN Canales c ON c.COD_ARTICU = a.COD_ARTICU
LEFT JOIN Precios p ON p.COD_ARTICU = a.COD_ARTICU
LEFT JOIN Stock s ON s.COD_ARTICU = a.COD_ARTICU
LEFT JOIN Ventas30 v ON v.COD_ARTICU = a.COD_ARTICU
WHERE
  a.Sincroniza_Nexo_Tiendas = 1
  OR ISNULL(c.Publicado_Prestashop, 0) = 1
  OR ISNULL(c.Publicado_BNA, 0) = 1
  OR ISNULL(c.Publicado_MercadoLibre, 0) = 1
ORDER BY
  CASE
    WHEN ISNULL(c.Saldo_Prestashop, 0) < 0
      OR ISNULL(s.Stock_Producteca_Total, 0) < 0
      OR ISNULL(s.Saldo_Real, 0) < 0
      OR ISNULL(s.Stock_Disponible_CD, 0) < 0
      OR ISNULL(s.Stock_Disponible_CA, 0) < 0
      OR ISNULL(s.Stock_Disponible_50, 0) < 0 THEN 1
    WHEN (ISNULL(s.Saldo_Real, 0) <= 0 AND ISNULL(c.Saldo_Prestashop, 0) > 0)
      OR (ISNULL(c.Publicado_BNA, 0) = 1 AND ISNULL(s.Stock_Producteca_Total, 0) <= 0) THEN 2
    WHEN ISNULL(v.Ventas_Ultimos_30_Dias, 0) > 0 AND ISNULL(s.Saldo_Real, 0) > 0 AND ISNULL(s.Saldo_Real, 0) / (ISNULL(v.Ventas_Ultimos_30_Dias, 0) / 30.0) <= 7 THEN 3
    WHEN ISNULL(c.Saldo_Prestashop, 0) > ISNULL(s.Saldo_Real, 0) THEN 4
    WHEN ISNULL(c.Publicado_Prestashop, 0) = 0 AND ISNULL(c.Publicado_BNA, 0) = 0 THEN 5
    ELSE 5
  END,
  a.COD_ARTICU;
