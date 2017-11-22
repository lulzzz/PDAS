USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the NTB in fact_order.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb]
	@pdasid INT,
	@businessid INT,
	@buying_program_id INT
AS
BEGIN

	-- Placeholder
	DECLARE @demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
	DECLARE @dim_customer_id_placeholder_casa int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'CASA')
	DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')

	DECLARE @dim_date_id_pdas_release_day int = (SELECT MAX(dd.[id]) FROM [dbo].[dim_date] dd INNER JOIN [dbo].[dim_pdas] pdas ON pdas.date_id = dd.id)
	DECLARE @dim_date_id_pdas_release_day_future int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(yy, 1, full_date) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))

	DECLARE @dim_date_id_asap_73 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 73, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
	DECLARE @dim_date_id_asap_103 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 103, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
	-- Is it possible to keep it as “ASAP” as request week?
	-- But change it to CW+73 / CW+103 (depending on the LT of the particular MTL) when you bounce it against available capacity?


	-- Check if the session has already been loaded
	IF EXISTS (SELECT 1 FROM [dbo].[fact_order] WHERE dim_pdas_id = @pdasid AND dim_business_id = @businessid AND dim_buying_program_id = @buying_program_id AND dim_demand_category_id = @demand_category_id_ntb)
	BEGIN
		DELETE FROM [dbo].[fact_order]
		WHERE
			dim_pdas_id = @pdasid
			AND dim_buying_program_id = @buying_program_id
			AND dim_demand_category_id = @demand_category_id_ntb
	END


	-- Insert from staging
	INSERT INTO [dbo].[fact_order](
		dim_pdas_id,
		dim_business_id,
		dim_buying_program_id,
		order_number,
		dim_date_id,
		dim_factory_id,
		dim_customer_id,
		dim_product_id,
		dim_demand_category_id,
		quantity_lum,
		quantity_non_lum,
		is_asap,
		material_id_sr,
		pr_code,
		pr_cut_code,
		so_code,
		po_code_customer,
		comment_region,
		customer_requested_xf_dt,
		original_customer_requested_dt,
		[sold_to_customer_name],
		[mcq],
		[musical_cnt],
		[delivery_d],
		[smu],
		[order_reference],
		[sku_footlocker],
		[prepack_code],
		[exp_delivery_with_constraint],
		[exp_delivery_without_constraint],
		[coo],
		[remarks_region]
	)

	-- EMEA
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		'UNDEFINED' as order_number,
		CASE UPPER(ntb.[exp_delivery_no_constraint_dt])
			WHEN 'ASAP' THEN
				CASE dp_m.[production_lt]
					WHEN 110 THEN @dim_date_id_asap_103
					ELSE @dim_date_id_asap_73
				END
			ELSE dd_xfw.id
		END as dim_date_id,
		@dim_factory_id_placeholder as dim_factory_id,
		dc.id as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
		@demand_category_id_ntb as dim_demand_category_id,
		SUM(ntb.lum_qty) as quantity_lum,
		SUM(ntb.sap_qty) as quantity_non_lum,
		CASE UPPER(ntb.[exp_delivery_no_constraint_dt])
			WHEN 'ASAP' THEN 1
			ELSE 0
		END as is_asap,
		MAX(ntb.[dim_product_material_id]) as material_id_sr,
		MAX(ntb.[pr_code]) as pr_code,
		NULL as pr_cut_code,
		MAX(ntb.so_code) as so_code,
		NULL as po_code_customer,
		NULL as comment_region,
		NULL as customer_requested_xf_dt,
		NULL as original_customer_requested_dt,
		MAX(dim_customer_sold_party) as [sold_to_customer_name],
		MAX(ntb.moq) as [mcq],
		NULL as [musical_cnt],
		NULL as [delivery_d],
		MAX(ntb.smu) as [smu],
		MAX(ntb.order_reference) as [order_reference],
		MAX(ntb.sku_footlocker) as [sku_footlocker],
		MAX(ntb.prepack_code) as [prepack_code],
		MAX(ntb.exp_delivery_with_constraint_dt) as [exp_delivery_with_constraint],
		MAX(ntb.exp_delivery_no_constraint_dt) as [exp_delivery_without_constraint],
		MAX(ntb.dim_location_country) as [coo],
		MAX(ntb.comment_region) as [remarks_region]
	FROM
		(
			SELECT
				*
				,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
			FROM [dbo].[staging_pdas_footwear_vans_emea_ntb]
		) AS ntb
		INNER JOIN (SELECT [id], [name], [sold_to_party] FROM [dbo].[dim_customer] WHERE is_placeholder = 0) dc
			ON ntb.dim_customer_name = dc.name
		LEFT OUTER JOIN
		(
			SELECT
				[id],
				SUBSTRING([year_cw_accounting], 7, 2) AS [cw]
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
			SELECT [id], [material_id], [production_lt]
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
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		(UPPER(ntb.[exp_delivery_no_constraint_dt]) = 'ASAP' OR dd_xfw.[cw] IS NOT NULL)
	GROUP BY
		CASE UPPER(ntb.[exp_delivery_no_constraint_dt])
			WHEN 'ASAP' THEN
				CASE dp_m.[production_lt]
					WHEN 110 THEN @dim_date_id_asap_103
					ELSE @dim_date_id_asap_73
				END
			ELSE dd_xfw.id
		END,
		dc.id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END,
		CASE UPPER(ntb.[exp_delivery_no_constraint_dt])
			WHEN 'ASAP' THEN 1
			ELSE 0
		END

	-- APAC
	UNION
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		'UNDEFINED' as order_number,
		dd_xfac.id as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END as dim_factory_id,
		dc.id as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
		@demand_category_id_ntb as dim_demand_category_id,
		SUM(ntb.lum_qty) as quantity_lum,
		SUM(ntb.sap_qty) as quantity_non_lum,
		0 as is_asap,
		MAX(ntb.[dim_product_material_id]) as material_id_sr,
		MAX(ntb.[pr_code]) as pr_code,
		MAX(ntb.[line_item]) as pr_cut_code,
		MAX(ntb.so_code) as so_code,
		MAX(ntb.[customer_po_code]) as po_code_customer,
		MAX(ntb.[comment]) as comment_region,
		MAX(ntb.xfac_dt) as customer_requested_xf_dt,
		MAX(ntb.xfac_dt) as original_customer_requested_dt,
		MAX(ntb.ship_name) as [sold_to_customer_name],
		MAX(ntb.moq) as [mcq],
		MAX(ntb.musicalcnt) as [musical_cnt],
		NULL as [delivery_d],
		NULL as [smu],
		NULL as [order_reference],
		NULL as [sku_footlocker],
		NULL as [prepack_code],
		NULL as [exp_delivery_with_constraint],
		NULL as [exp_delivery_without_constraint],
		NULL as [coo],
		MAX(ntb.remarks) as [remarks_region]
	FROM
		(
			SELECT
				*
				,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
			FROM [dbo].[staging_pdas_footwear_vans_apac_ntb]
		) AS ntb
		INNER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
		INNER JOIN [dbo].[dim_customer] dc ON ntb.dim_customer_name = dc.name
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
		LEFT OUTER JOIN [dbo].[dim_factory] df ON ntb.dim_factory_reva_vendor = df.short_name
		LEFT OUTER JOIN
		(
			SELECT df.id, m.child
			FROM
				[dbo].[helper_pdas_footwear_vans_mapping] m
				INNER JOIN (SELECT id, short_name FROM [dbo].[dim_factory]) df
					ON m.parent = df.short_name
			WHERE type = 'Factory Master'
		) mapping_f ON ntb.dim_factory_reva_vendor = mapping_f.child
	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		ntb.lum_qty IS NOT NULL
	GROUP BY
		dd_xfac.id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END,
		dc.id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END

	-- CASA
	UNION
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		'UNDEFINED' as order_number,
		dd_xfac.id as dim_date_id,
		@dim_factory_id_placeholder as dim_factory_id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_casa
		END as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
		@demand_category_id_ntb as dim_demand_category_id,
		SUM(ntb.lum_qty) as quantity_lum,
		SUM(ntb.sap_qty) as quantity_non_lum,
		0 as is_asap,
		MAX(ntb.[dim_product_material_id]) as material_id_sr,
		MAX(ntb.[pr_code]) as pr_code,
		NULL as pr_cut_code,
		NULL as so_code,
		MAX(ntb.[customer_po_code]) as po_code_customer,
		MAX(ntb.[comment_region]) as comment_region,
		MAX(ntb.xfac_dt) as customer_requested_xf_dt,
		MAX(ntb.xfac_dt) as original_customer_requested_dt,
		'CASA' as [sold_to_customer_name],
		MAX(ntb.moq) as [mcq],
		NULL as [musical_cnt],
		NULL as [delivery_d],
		MAX(ntb.smu) as [smu],
		MAX(ntb.order_reference) as [order_reference],
		MAX(ntb.sku_footlocker) as [sku_footlocker],
		MAX(ntb.prepack_code) as [prepack_code],
		NULL as [exp_delivery_with_constraint],
		NULL as [exp_delivery_without_constraint],
		MAX(ntb.country_origin) as [coo],
		MAX(ntb.comment_region) as [remarks_region]
	FROM
		(
			SELECT
				*
				,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
			FROM [dbo].[staging_pdas_footwear_vans_casa_ntb]
		) AS ntb
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
		LEFT OUTER JOIN
		(
			SELECT MAX([id]) AS [id], [dc_plt]
			FROM [dbo].[dim_customer]
			GROUP BY [dc_plt]
		) AS dc
			ON ntb.[dim_customer_dc_sr_code] = dc.[dc_plt]
		INNER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
	WHERE
		ntb.lum_qty IS NOT NULL AND
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL)
	GROUP BY
		dd_xfac.id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_casa
		END,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END

	-- NORA
	UNION
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		'UNDEFINED' as order_number,
		dd_xfac.id as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END as dim_factory_id,
		CASE
			WHEN dc_name.id IS NOT NULL THEN dc_name.id
			WHEN dc_plt.id IS NOT NULL THEN dc_plt.id
			ELSE @dim_customer_id_placeholder_nora
		END as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
		@demand_category_id_ntb as dim_demand_category_id,
		SUM(ntb.lum_qty) as quantity_lum,
		SUM(ntb.quantity) as quantity_non_lum,
		0 as is_asap,
		MAX(ISNULL(ntb.[dim_product_material_id], '')) as material_id_sr,
		MAX(ISNULL(ntb.[pr_code], '')) as pr_code,
		MAX(ISNULL([item], '')) as pr_cut_code,
		MAX(ISNULL(ntb.[sales_doc], '')) as so_code,
		MAX(ISNULL(ntb.[customer_po_code], '')) as po_code_customer,
		NULL as comment_region,
		MAX(ntb.xfac_dt) as customer_requested_xf_dt,
		MAX(ntb.req_dt) as original_customer_requested_dt,
		MAX(ISNULL(ntb.[sold_to_pt], '')) as [sold_to_customer_name],
		CASE LEN(MAX(ntb.[dim_product_material_id]))
			WHEN 11 THEN 1
			ELSE RIGHT(MAX(ntb.dim_product_size), 2)
		END as [mcq],
		NULL as [musical_cnt],
		CASE ISDATE(MAX(ntb.[delivered_dt]))
			WHEN 1 THEN MAX(ntb.[delivered_dt])
			ELSE NULL
		END as [delivery_d],
		MAX(ntb.smu) as [smu],
		NULL as [order_reference],
		NULL as [sku_footlocker],
		NULL as [prepack_code],
		NULL as [exp_delivery_with_constraint],
		NULL as [exp_delivery_without_constraint],
		NULL as [coo],
		NULL as [remarks_region]
	FROM
		(
			SELECT
				*
				,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
			FROM [dbo].[staging_pdas_footwear_vans_nora_ntb]
		) AS ntb
		INNER JOIN [dbo].[dim_date] dd_xfac
			ON CONVERT(date, ntb.xfac_dt) = dd_xfac.full_date
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

		LEFT OUTER JOIN (SELECT [id], [name] FROM [dbo].[dim_customer]) dc_name
			ON ntb.[dim_customer_name] = dc_name.[name]

		LEFT OUTER JOIN (SELECT MAX([id]) as [id], MAX([sold_to_party]) as [sold_to_party], [dc_plt] FROM [dbo].[dim_customer] GROUP BY [dc_plt]) dc_plt
			ON ntb.[plnt] = dc_plt.[dc_plt]

		LEFT OUTER JOIN [dbo].[dim_factory] df ON ntb.dim_factory_short_name = df.short_name
		LEFT OUTER JOIN
		(
			SELECT df.id, m.child
			FROM
				[dbo].[helper_pdas_footwear_vans_mapping] m
				INNER JOIN (SELECT id, short_name FROM [dbo].[dim_factory]) df
					ON m.parent = df.short_name
			WHERE type = 'Factory Master'
		) mapping_f ON ntb.dim_factory_short_name = mapping_f.child
	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		ntb.lum_qty IS NOT NULL
	GROUP BY
		dd_xfac.id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END,
		CASE
			WHEN dc_name.id IS NOT NULL THEN dc_name.id
			WHEN dc_plt.id IS NOT NULL THEN dc_plt.id
			ELSE @dim_customer_id_placeholder_nora
		END,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END


END
