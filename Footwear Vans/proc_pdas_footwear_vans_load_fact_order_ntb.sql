USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the NTB in fact_order.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb]
	@dim_release_id INT,
	@businessid INT,
	@buying_program_id INT
AS
BEGIN

	--DECLARE @dim_release_id INT =
	--DECLARE @businessid INT = 1
	--DECLARE @buying_program_id int = (SELECT [dim_buying_program_id] FROM [dbo].[dim_release] WHERE [id] = @dim_release_id)

	-- Placeholder
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
	DECLARE @dim_customer_id_placeholder_casa int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'CASA')
	DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')
	DECLARE @dim_demand_category_id_ntb int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Need to Buy')

	DECLARE @dim_date_id_pdas_release_day int = (SELECT MAX(dd.[id]) FROM [dbo].[dim_date] dd INNER JOIN [dbo].[dim_release] pdas ON pdas.dim_date_id = dd.id)
	DECLARE @dim_date_id_pdas_release_day_future int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(month, -1, DATEADD(yy, 1, full_date)) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))

	DECLARE @dim_date_id_asap_73 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 73, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
	DECLARE @dim_date_id_asap_103 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 103, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
	-- Is it possible to keep it as “ASAP” as request week?
	-- But change it to CW+73 / CW+103 (depending on the LT of the particular MTL) when you bounce it against available capacity?

	-- Release full dim_date_id
	DECLARE @pdas_release_full_date_id int
	SET @pdas_release_full_date_id = (SELECT [dim_date_id] FROM [dbo].[dim_release] WHERE [id] = @dim_release_id)
	DECLARE @pdas_release_full_d date = (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = @pdas_release_full_date_id)

	DECLARE @dim_date_id_buy_month int = (
		SELECT dim_date.[id]
		FROM
		(
			SELECT [id], [buy_month]
			FROM [dbo].[dim_release]
			WHERE
				[id] = @dim_release_id
		) dim_release
		INNER JOIN
		(
			SELECT
				MIN([id]) as [id]
				,[year_month_accounting]
			FROM [dbo].[dim_date]
			GROUP BY [year_month_accounting]
		) dim_date
			ON dim_release.[buy_month] = dim_date.[year_month_accounting]
	)

	-- Create temp table
	CREATE TABLE #source_temp (
		[dim_release_id] INT
		,[dim_business_id] INT
		,[dim_buying_program_id] INT
		,[dim_product_id] INT
		,[dim_date_id] INT
		,[dim_date_id_original] INT
		,[dim_date_id_buy_month] INT
		,[dim_factory_id_original_unconstrained] INT
		,[dim_factory_id_original_constrained] INT
		,[dim_factory_id_final] INT
		,[dim_factory_id] INT
		,[dim_customer_id] INT
		,[dim_demand_category_id] INT
		,[order_number] NVARCHAR(45)
		,[pr_code] NVARCHAR(45)
		,[pr_cut_code] NVARCHAR(45)
		,[po_code_customer] NVARCHAR(45)
		,[so_code] NVARCHAR(45)
		,[is_asap] TINYINT
		,[quantity_lum] INT
		,[quantity_non_lum] INT
		,[material_id_sr] NVARCHAR(45)
		,[production_lt_actual_buy] INT
		,[comment_region] NVARCHAR(1000)
		,[sold_to_customer_name] NVARCHAR(100)
		,[mcq] INT
		,[musical_cnt] NVARCHAR(200)
		,[delivery_d] DATE
		,[smu] NVARCHAR(200)
		,[order_reference] NVARCHAR(45)
		,[sku_footlocker] NVARCHAR(45)
		,[prepack_code] NVARCHAR(45)
		,[exp_delivery_with_constraint] NVARCHAR(45)
		,[exp_delivery_without_constraint] NVARCHAR(45)
		,[coo] NVARCHAR(45)
		,[remarks_region] NVARCHAR(1000)
		,[carton_qty] INT
	)


	-- NTB (temp table)
	INSERT INTO #source_temp
	(
		[dim_release_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_date_id_original]
		,[dim_date_id_buy_month]
		,[dim_factory_id_original_unconstrained]
		,[dim_factory_id_original_constrained]
		,[dim_factory_id_final]
		,[dim_factory_id]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[order_number]
		,[pr_code]
		,[pr_cut_code]
		,[po_code_customer]
		,[so_code]
		,[is_asap]
		,[quantity_lum]
		,[quantity_non_lum]
		,[material_id_sr]
		,[production_lt_actual_buy]
		,[comment_region]
		,[sold_to_customer_name]
		,[mcq]
		,[musical_cnt]
		,[delivery_d]
		,[smu]
		,[order_reference]
		,[sku_footlocker]
		,[prepack_code]
		,[exp_delivery_with_constraint]
		,[exp_delivery_without_constraint]
		,[coo]
		,[remarks_region]
		,[carton_qty]
	)
	-- fact_order
	SELECT
		[dim_release_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,ntb.[dim_date_id]
		,ntb.[dim_date_id] as dim_date_id_original
		,@dim_date_id_buy_month
		,@dim_factory_id_placeholder as [dim_factory_id_original_unconstrained]
		,@dim_factory_id_placeholder as [dim_factory_id_original_constrained]
		,@dim_factory_id_placeholder as [dim_factory_id_final]
		,@dim_factory_id_placeholder as [dim_factory_id]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,'UNDEFINED' as [order_number]
		,[pr_code]
		,[pr_cut_code]
		,[po_code_customer]
		,[so_code]
		,[is_asap]
		,[quantity_lum]
		,[quantity_non_lum]
		,[material_id_sr]
		,DATEDIFF(day, @pdas_release_full_d, dd.[full_date]) as [production_lt_actual_buy]
		,[comment_region]
		,[sold_to_customer_name]
		,[mcq]
		,[musical_cnt]
		,[delivery_d]
		,[smu]
		,[order_reference]
		,[sku_footlocker]
		,[prepack_code]
		,[exp_delivery_with_constraint]
		,[exp_delivery_without_constraint]
		,[coo]
		,[remarks_region]
		,[carton_qty]
	FROM
		(
			-- EMEA
			SELECT
				@dim_release_id as dim_release_id,
				@businessid as dim_business_id,
				@buying_program_id as dim_buying_program_id,
				ISNULL(ntb.[pr_code], 'UNDEFINED') as order_number,
				CASE UPPER(ntb.[exp_delivery_no_constraint_dt])
					WHEN 'ASAP' THEN
						CASE dp_m.[production_lt]
							WHEN 110 THEN @dim_date_id_asap_103
							ELSE @dim_date_id_asap_73
						END
					ELSE dd_xfw.id
				END as dim_date_id,
				CASE UPPER(ntb.[exp_delivery_no_constraint_dt])
					WHEN 'ASAP' THEN
						CASE dp_m.[production_lt]
							WHEN 110 THEN @dim_date_id_asap_103
							ELSE @dim_date_id_asap_73
						END
					ELSE dd_xfw.id
				END as dim_date_id_original,
				dc.id as dim_customer_id,
				CASE
					WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
					ELSE dp_m.id
				END as dim_product_id,
				@dim_demand_category_id_ntb as dim_demand_category_id,
				SUM(ntb.lum_qty) as quantity_lum,
				SUM(ntb.sap_qty) as quantity_non_lum,
				CASE UPPER(ntb.[exp_delivery_no_constraint_dt])
					WHEN 'ASAP' THEN 1
					ELSE 0
				END as is_asap,
				MAX(ntb.[dim_product_material_id]) as material_id_sr,
				MAX(ISNULL(ntb.[pr_code], '')) as pr_code,
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
				MAX(ntb.comment_region) as [remarks_region],
				NULL as [carton_qty]
			FROM
				(
					SELECT
						*
						,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
					FROM [dbo].[staging_pdas_footwear_vans_emea_ntb]
				) ntb
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
				ISNULL(ntb.[pr_code], 'UNDEFINED'),
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
				@dim_release_id as dim_release_id,
				@businessid as dim_business_id,
				@buying_program_id as dim_buying_program_id,
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[line_item], 'UNDEFINED') as order_number,
				dd_xfac.id as dim_date_id,
				dd_xfac.id as dim_date_id_original,
				dc.id as dim_customer_id,
				CASE
					WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
					ELSE dp_m.id
				END as dim_product_id,
				@dim_demand_category_id_ntb as dim_demand_category_id,
				SUM(ntb.lum_qty) as quantity_lum,
				SUM(ntb.sap_qty) as quantity_non_lum,
				0 as is_asap,
				MAX(ntb.[dim_product_material_id]) as material_id_sr,
				MAX(ISNULL(ntb.[pr_code], '')) as pr_code,
				MAX(ISNULL(ntb.[line_item], '')) as pr_cut_code,
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
				MAX(ntb.remarks) as [remarks_region],
				MAX([carton_qty]) as [carton_qty]
			FROM
				(
					SELECT
						*
						,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
					FROM [dbo].[staging_pdas_footwear_vans_apac_ntb]
				) ntb
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
			WHERE
				(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
				ntb.lum_qty IS NOT NULL
			GROUP BY
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[line_item], 'UNDEFINED'),
				dd_xfac.id,
				dc.id,
				CASE
					WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
					ELSE dp_m.id
				END

			-- CASA
			UNION
			SELECT
				@dim_release_id as dim_release_id,
				@businessid as dim_business_id,
				@buying_program_id as dim_buying_program_id,
				ISNULL(ntb.[pr_code], 'UNDEFINED') as order_number,
				dd_xfac.id as dim_date_id,
				dd_xfac.id as dim_date_id_original,
				CASE
					WHEN dc.id IS NOT NULL THEN dc.id
					WHEN dcm.id IS NOT NULL THEN dcm.id
					ELSE @dim_customer_id_placeholder_casa
				END as dim_customer_id,
				CASE
					WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
					ELSE dp_m.id
				END as dim_product_id,
				@dim_demand_category_id_ntb as dim_demand_category_id,
				SUM(ntb.lum_qty) as quantity_lum,
				SUM(ntb.sap_qty) as quantity_non_lum,
				0 as is_asap,
				MAX(ntb.[dim_product_material_id]) as material_id_sr,
				ISNULL(ntb.[pr_code], 'UNDEFINED') as pr_code,
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
				MAX(ntb.comment_region) as [remarks_region],
				NULL as [carton_qty]
			FROM
				(
					SELECT
						*
						,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
					FROM [dbo].[staging_pdas_footwear_vans_casa_ntb]
				) ntb
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

				LEFT OUTER JOIN
				(
					SELECT MAX([id]) AS [id], [child]
					FROM
						[dbo].[dim_customer] dc
						INNER JOIN
						(SELECT [parent], [child] FROM [dbo].[helper_pdas_footwear_vans_mapping] WHERE [category] = 'Customer Master') m
							ON dc.[name] = m.[parent]
					GROUP BY
						[child]
				) dcm
					ON ntb.[dim_customer_dc_sr_code] = dcm.[child]

				INNER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
			WHERE
				ntb.lum_qty IS NOT NULL AND
				(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL)
			GROUP BY
				ISNULL(ntb.[pr_code], 'UNDEFINED'),
				dd_xfac.id,
				CASE
					WHEN dc.id IS NOT NULL THEN dc.id
					WHEN dcm.id IS NOT NULL THEN dcm.id
					ELSE @dim_customer_id_placeholder_casa
				END,
				CASE
					WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
					ELSE dp_m.id
				END

			-- NORA
			UNION
			SELECT
				@dim_release_id as dim_release_id,
				@businessid as dim_business_id,
				@buying_program_id as dim_buying_program_id,
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[item], 'UNDEFINED') as order_number,
				dd_xfac.id as dim_date_id,
				dd_xfac.id as dim_date_id_original,
				CASE
					WHEN dc_name.id IS NOT NULL THEN dc_name.id
					WHEN dc_plt.id IS NOT NULL THEN dc_plt.id
					WHEN dcm.id IS NOT NULL THEN dcm.id
					ELSE @dim_customer_id_placeholder_nora
				END as dim_customer_id,
				CASE
					WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
					ELSE dp_m.id
				END as dim_product_id,
				@dim_demand_category_id_ntb as dim_demand_category_id,
				SUM(ntb.lum_qty) as quantity_lum,
				SUM(ntb.quantity) as quantity_non_lum,
				0 as is_asap,
				MAX(ISNULL(ntb.[dim_product_material_id], '')) as material_id_sr,
				MAX(ISNULL(ntb.[pr_code], '')) as pr_code,
				MAX(ISNULL([item], '')) as pr_cut_code,
				MAX(ISNULL(ntb.[sales_doc], '')) as so_code,
				MAX(ISNULL(ntb.[customer_po_code], '')) as po_code_customer,
				MAX(ISNULL(ntb.[us_planning_notes], '')) as comment_region,
				MAX(ntb.xfac_dt) as customer_requested_xf_dt,
				MAX(ntb.req_dt) as original_customer_requested_dt,
				MAX(ISNULL(ntb.[sold_to_customer_name], '')) as [sold_to_customer_name],
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
				NULL as [remarks_region],
				NULL as [carton_qty]
			FROM
				(
					SELECT
						*
						,CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id_corrected]
					FROM [dbo].[staging_pdas_footwear_vans_nora_ntb]
				) ntb
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

				LEFT OUTER JOIN
				(
					SELECT MAX([id]) AS [id], [child]
					FROM
						[dbo].[dim_customer] dc
						INNER JOIN
						(SELECT [parent], [child] FROM [dbo].[helper_pdas_footwear_vans_mapping] WHERE [category] = 'Customer Master') m
							ON dc.[name] = m.[parent]
					GROUP BY
						[child]
				) dcm
					ON ntb.[plnt] = dcm.[child]

			WHERE
				(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
				ntb.lum_qty IS NOT NULL
			GROUP BY
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[item], 'UNDEFINED'),
				dd_xfac.id,
				CASE
					WHEN dc_name.id IS NOT NULL THEN dc_name.id
					WHEN dc_plt.id IS NOT NULL THEN dc_plt.id
					WHEN dcm.id IS NOT NULL THEN dcm.id
					ELSE @dim_customer_id_placeholder_nora
				END,
				CASE
					WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
					ELSE dp_m.id
				END
		) ntb
		INNER JOIN [dbo].[dim_date] dd
			ON ntb.[dim_date_id] = dd.[id]
		WHERE
			[dim_release_id] = @dim_release_id
			AND [dim_business_id] = @businessid



	-- Insert/update/delete in real table
	PRINT 'Insert'
	INSERT INTO [dbo].[fact_demand_total]
	(
		[dim_release_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_date_id_original]
		,[dim_date_id_buy_month]
		,[dim_factory_id_original_unconstrained]
		,[dim_factory_id_original_constrained]
		,[dim_factory_id_final]
		,[dim_factory_id]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[order_number]
		,[pr_code]
		,[pr_cut_code]
		,[po_code_customer]
		,[so_code]
		,[is_asap]
		,[quantity_lum]
		,[quantity_non_lum]
		,[material_id_sr]
		,[production_lt_actual_buy]
		,[comment_region]
		,[sold_to_customer_name]
		,[mcq]
		,[musical_cnt]
		,[delivery_d]
		,[smu]
		,[order_reference]
		,[sku_footlocker]
		,[prepack_code]
		,[exp_delivery_with_constraint]
		,[exp_delivery_without_constraint]
		,[coo]
		,[remarks_region]
		,[carton_qty]
	)
	SELECT s.*
	FROM
		#source_temp s
		LEFT OUTER JOIN
		(
			SELECT *
			FROM [dbo].[fact_demand_total]
			WHERE
				dim_release_id = @dim_release_id
		) t
			ON
				s.[dim_product_id] = t.[dim_product_id] and
				s.[dim_date_id] = t.[dim_date_id_original] and
				s.[dim_customer_id] = t.[dim_customer_id] and
				ISNULL(s.[pr_cut_code], 0) = ISNULL(t.[pr_cut_code], 0) and
				ISNULL(s.[pr_code], 0) = ISNULL(t.[pr_code], 0)
	WHERE
		t.[id] IS NULL

	PRINT 'Update'
	UPDATE t
	SET
		t.[dim_date_id] = s.[dim_date_id]
		,t.[po_code_customer] = s.[po_code_customer]
		,t.[so_code] = s.[so_code]
		,t.[is_asap] = s.[is_asap]
		,t.[quantity_lum] = s.[quantity_lum]
		,t.[quantity_non_lum] = s.[quantity_non_lum]
		,t.[material_id_sr] = s.[material_id_sr]
		,t.[production_lt_actual_buy] = s.[production_lt_actual_buy]
		,t.[sold_to_customer_name] = s.[sold_to_customer_name]
		,t.[mcq] = s.[mcq]
		,t.[musical_cnt] = s.[musical_cnt]
		,t.[delivery_d] = s.[delivery_d]
		,t.[smu] = s.[smu]
		,t.[order_reference] = s.[order_reference]
		,t.[sku_footlocker] = s.[sku_footlocker]
		,t.[prepack_code] = s.[prepack_code]
		,t.[exp_delivery_with_constraint] = s.[exp_delivery_with_constraint]
		,t.[exp_delivery_without_constraint] = s.[exp_delivery_without_constraint]
		,t.[coo] = s.[coo]
	FROM
		#source_temp s
		INNER JOIN
		(
			SELECT *
			FROM [dbo].[fact_demand_total]
			WHERE
				dim_release_id = @dim_release_id
		) t
			ON
				s.[dim_product_id] = t.[dim_product_id] and
				s.[dim_date_id] = t.[dim_date_id_original] and
				s.[dim_customer_id] = t.[dim_customer_id] and
				ISNULL(s.[pr_cut_code], 0) = ISNULL(t.[pr_cut_code], 0) and
				ISNULL(s.[pr_code], 0) = ISNULL(t.[pr_code], 0)

	PRINT 'Delete'
	DELETE t
	FROM
		#source_temp s
		RIGHT OUTER JOIN
		(
			SELECT *
			FROM [dbo].[fact_demand_total]
			WHERE
				dim_release_id = @dim_release_id
		) t
			ON
				s.[dim_product_id] = t.[dim_product_id] and
				s.[dim_date_id] = t.[dim_date_id_original] and
				s.[dim_customer_id] = t.[dim_customer_id] and
				ISNULL(s.[pr_cut_code], 0) = ISNULL(t.[pr_cut_code], 0) and
				ISNULL(s.[pr_code], 0) = ISNULL(t.[pr_code], 0)
	WHERE
		s.[dim_release_id] IS NULL


END
