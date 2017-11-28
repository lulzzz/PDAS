DECLARE @pdasid INT = 1
DECLARE @businessid INT= 1
DECLARE @buying_program_id INT = 1


-- Placeholder
DECLARE @demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')
DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
DECLARE @dim_customer_id_placeholder_casa int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'CASA')
DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')

DECLARE @dim_date_id_pdas_release_day int = (SELECT MAX(dd.[id]) FROM [dbo].[dim_date] dd INNER JOIN [dbo].[dim_pdas] pdas ON pdas.dim_date_id = dd.id)
DECLARE @dim_date_id_pdas_release_day_future int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(yy, 1, full_date) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))

DECLARE @dim_date_id_asap_73 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 73, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
DECLARE @dim_date_id_asap_103 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 103, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
-- Is it possible to keep it as “ASAP” as request week?
-- But change it to CW+73 / CW+103 (depending on the LT of the particular MTL) when you bounce it against available capacity?


-- EMEA
SELECT
    SUM(ntb.sap_qty) as quantity
FROM
    (
        SELECT
            *
            ,CASE RIGHT([dim_product_material_id], 1) WHEN 'P' THEN LEFT([dim_product_material_id], LEN([dim_product_material_id])-1) ELSE [dim_product_material_id] END AS [dim_product_material_id_corrected]
        FROM [dbo].[staging_pdas_footwear_vans_emea_ntb_bulk]
    ) AS ntb
    INNER JOIN (SELECT [id], [name], [sold_to_party] FROM [dbo].[dim_customer] WHERE is_placeholder = 0) dc
        ON ntb.dim_customer_name = dc.name
    LEFT OUTER JOIN
    (
        SELECT
            [id],
            CONVERT(NVARCHAR(2), CONVERT(INT, SUBSTRING([year_cw_accounting], 7, 2))) AS [cw]
        FROM [dbo].[dim_date]
        WHERE
            [day_name_of_week] = 'Monday'
            and [id] BETWEEN @dim_date_id_pdas_release_day AND @dim_date_id_pdas_release_day_future
    ) dd_xfw
        ON
			CASE ISNUMERIC(REPLACE(SUBSTRING(ntb.[exp_delivery_no_constraint_dt], 3, 10), ' ', ''))
				WHEN 1 THEN CONVERT(NVARCHAR(2), CONVERT(INT, REPLACE(SUBSTRING(ntb.[exp_delivery_no_constraint_dt], 3, 10), ' ', '')))
				ELSE 0
			END = dd_xfw.[cw]

    LEFT OUTER JOIN
    (
        SELECT [id], [material_id]
        FROM [dbo].[dim_product]
        WHERE
            [is_placeholder] = 1 AND
            [placeholder_level] = 'material_id'
    ) AS dp_m
        ON ntb.[dim_product_material_id_corrected] = dp_m.material_id
    LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
        ON 	ntb.[dim_product_material_id_corrected] = dp_ms.material_id AND
            ntb.dim_product_size = dp_ms.size
    LEFT OUTER JOIN [dbo].[dim_date] dd_buy ON ntb.buy_dt = dd_buy.full_date
WHERE
    ntb.lum_qty IS NOT NULL AND
    (UPPER(ntb.[exp_delivery_no_constraint_dt]) = 'ASAP' OR dd_xfw.[cw] IS NOT NULL)
