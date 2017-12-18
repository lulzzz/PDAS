USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Description:	Procedure to load the order and forecast demand in proc_pdas_footwear_vans_load_fact_demand_total.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]
	@pdasid INT,
	@businessid INT
AS
BEGIN

    -- Variable declarations
    DECLARE @dim_demand_category_id_forecast int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Forecast')
	DECLARE @dim_demand_category_id_ntb int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Need to Buy')
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')
	DECLARE @dim_customer_id_placeholder_casa int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'CASA')
	DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
	DECLARE @dim_product_id_placeholder int = (SELECT [id] FROM [dbo].[dim_product] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'FUAC/SMU' and [material_id] = 'FUAC/SMU' and [size] = 'FUAC/SMU')
	DECLARE	@dim_demand_category_id_open_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Open Order')
	DECLARE	@dim_demand_category_id_shipped_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Shipped Order')
	DECLARE	@buying_program_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
	DECLARE @dim_customer_id_placeholder int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [name] = 'PLACEHOLDER' AND [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')

	DECLARE @dim_date_id_pdas_release_day int = (SELECT MAX(dd.[id]) FROM [dbo].[dim_date] dd INNER JOIN [dbo].[dim_pdas] pdas ON pdas.dim_date_id = dd.id)
	DECLARE @dim_date_id_pdas_release_day_future int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(yy, 1, full_date) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))

	DECLARE @dim_date_id_asap_73 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 73, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
	DECLARE @dim_date_id_asap_103 int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(day, 103, [full_date]) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))
	-- Is it possible to keep it as “ASAP” as request week?
	-- But change it to CW+73 / CW+103 (depending on the LT of the particular MTL) when you bounce it against available capacity?


	-- Release full dim_date_id
	DECLARE @pdas_release_full_date_id int
	SET @pdas_release_full_date_id = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)
	DECLARE @pdas_release_full_d date = (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = @pdas_release_full_date_id)

	-- Check if the session has already been loaded
	-- DELETE forecast and NTB only
	IF EXISTS (SELECT 1 FROM [dbo].[fact_demand_total] WHERE dim_pdas_id = @pdasid AND dim_business_id = @businessid AND dim_buying_program_id = @buying_program_id AND dim_demand_category_id in (@dim_demand_category_id_ntb, @dim_demand_category_id_forecast) AND is_from_previous_release = 0)
	BEGIN
		DELETE FROM [dbo].[fact_demand_total]
		WHERE
			dim_pdas_id = @pdasid
			AND dim_business_id = @businessid
			AND dim_buying_program_id = @buying_program_id
			AND dim_demand_category_id in (@dim_demand_category_id_ntb, @dim_demand_category_id_forecast)
			AND is_from_previous_release = 0
	END

	-- for NTB table, it has a is_previous field, the default value is 0, and it's non null

	-- Check if the session has already been loaded, DELETE NGC for those which are is_previous,
	-- ngc should do an insert/update of current PDAS release month -3 to future, not a delete as this takes too much time


	-- NTB
	INSERT INTO [dbo].[fact_demand_total]
    (
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
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
		,[quantity_unconsumed]
		,[quantity]
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
		,[is_from_previous_release]
    )
	-- fact_order
	SELECT
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,ntb.[dim_date_id]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id_original_unconstrained]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id_original_constrained]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id_final]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id]
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
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN [quantity_lum]
			ELSE [quantity_non_lum]
		END AS [quantity_unconsumed]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN [quantity_lum]
			ELSE [quantity_non_lum]
		END AS [quantity]
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
		,0 AS [is_from_previous_release]
	FROM
		(
			-- EMEA
			SELECT
				@pdasid as dim_pdas_id,
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
				@dim_factory_id_placeholder as dim_factory_id,
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
				@pdasid as dim_pdas_id,
				@businessid as dim_business_id,
				@buying_program_id as dim_buying_program_id,
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[line_item], 'UNDEFINED') as order_number,
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
					WHERE category = 'Factory Master'
				) mapping_f ON ntb.dim_factory_reva_vendor = mapping_f.child
			WHERE
				(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
				ntb.lum_qty IS NOT NULL
			GROUP BY
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[line_item], 'UNDEFINED'),
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
				ISNULL(ntb.[pr_code], 'UNDEFINED') as order_number,
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
				ISNULL(ntb.[pr_code], 'UNDEFINED'),
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
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[item], 'UNDEFINED') as order_number,
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
				@dim_demand_category_id_ntb as dim_demand_category_id,
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
					WHERE category = 'Factory Master'
				) mapping_f ON ntb.dim_factory_short_name = mapping_f.child
			WHERE
				(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
				ntb.lum_qty IS NOT NULL
			GROUP BY
				ISNULL(ntb.[pr_code], 'UNDEFINED') + '-' + ISNULL(ntb.[item], 'UNDEFINED'),
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
		) ntb
		INNER JOIN [dbo].[dim_date] dd
			ON ntb.[dim_date_id] = dd.[id]
		WHERE
			[dim_pdas_id] = @pdasid
			AND [dim_business_id] = @businessid





	-- Forecast
	INSERT INTO [dbo].[fact_demand_total]
    (
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_factory_id_original_unconstrained]
		,[dim_factory_id_original_constrained]
		,[dim_factory_id_final]
		,[dim_factory_id]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[order_number]
		,[is_asap]
		,[quantity_lum]
		,[quantity_non_lum]
		,[quantity_unconsumed]
		,[quantity]
		,[is_from_previous_release]
    )
	-- APAC
	-- Providing their forecast based on BUY months
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		@dim_factory_id_placeholder AS [dim_factory_id_original_unconstrained],
		@dim_factory_id_placeholder AS [dim_factory_id_original_constrained],
		@dim_factory_id_placeholder AS [dim_factory_id_final],
		@dim_factory_id_placeholder AS [dim_factory_id],
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_apac
		END as dim_customer_id,
		@dim_demand_category_id_forecast AS [dim_demand_category_id],
		'UNDEFINED' AS [order_number],
		0 AS [is_asap],
		sum(quantity) AS [quantity_lum],
		sum(quantity) AS [quantity_non_lum],
		sum(quantity) AS [quantity_unconsumed],
		sum(quantity) AS [quantity],
		0 AS [is_from_previous_release]
	FROM
		[dbo].[staging_pdas_footwear_vans_apac_forecast] nf
		LEFT OUTER JOIN
		(
			SELECT id, material_id
			FROM [dbo].[dim_product] dp
			WHERE
				dp.is_placeholder = 1 AND
				dp.placeholder_level = 'material_id'
		) dp
			ON nf.dim_product_material_id = dp.material_id
		INNER JOIN
		(
			SELECT [season_year_short_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_short_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_short_buy] = SUBSTRING(nf.month_label, 1, 4)
			AND dd.month_name_short_accounting = SUBSTRING(nf.month_label, 6, 3)

		LEFT OUTER JOIN
		(
			SELECT id, name
			FROM [dbo].[dim_customer]
		) dc
			ON nf.[dim_customer_dc_sr_code] = dc.name

	WHERE
		quantity IS NOT NULL
	GROUP BY
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END,
		dd.id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_apac
		END


	-- EMEA
	-- Providing their forecast based on CRD months for XDC (i.e. EU DC order) and CRD month + 1 for XF (i.e. EU Direct orders)
	UNION
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		@dim_factory_id_placeholder AS [dim_factory_id_original_unconstrained],
		@dim_factory_id_placeholder AS [dim_factory_id_original_constrained],
		@dim_factory_id_placeholder AS [dim_factory_id_final],
		@dim_factory_id_placeholder AS [dim_factory_id],
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_emea
		END as dim_customer_id,
		@dim_demand_category_id_forecast AS [dim_demand_category_id],
		'UNDEFINED' AS [order_number],
		0 AS [is_asap],
		sum(quantity) AS [quantity_lum],
		sum(quantity) AS [quantity_non_lum],
		sum(quantity) AS [quantity_unconsumed],
		sum(quantity) AS [quantity],
		0 AS [is_from_previous_release]
	FROM
		[dbo].[staging_pdas_footwear_vans_emea_forecast] nf
		LEFT OUTER JOIN
		(
			SELECT id, material_id
			FROM [dbo].[dim_product] dp
			WHERE
				dp.is_placeholder = 1 AND
				dp.placeholder_level = 'material_id'
		) dp
			ON nf.dim_product_material_id = dp.material_id

		LEFT OUTER JOIN
		(
			SELECT id, name
			FROM [dbo].[dim_customer]
		) dc
			ON nf.customer_type = dc.name

		INNER JOIN
		(
			SELECT [season_year_short_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_short_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_short_buy] = nf.season
			AND dd.month_name_short_accounting = nf.plan_month
		WHERE
			quantity IS NOT NULL
		GROUP BY
			CASE
				WHEN dp.id IS NOT NULL THEN dp.id
				ELSE @dim_product_id_placeholder
			END,
			dd.id,
			CASE
				WHEN dc.id IS NOT NULL THEN dc.id
				ELSE @dim_customer_id_placeholder_emea
			END

	-- NORA (we pull intro month 2 months forward to reach CRD)
	UNION
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		@dim_factory_id_placeholder AS [dim_factory_id_original_unconstrained],
		@dim_factory_id_placeholder AS [dim_factory_id_original_constrained],
		@dim_factory_id_placeholder AS [dim_factory_id_final],
		@dim_factory_id_placeholder AS [dim_factory_id],
		dc.id as dim_customer_id,
		@dim_demand_category_id_forecast AS [dim_demand_category_id],
		'UNDEFINED' AS [order_number],
		0 AS [is_asap],
		sum(quantity) AS [quantity_lum],
		sum(quantity) AS [quantity_non_lum],
		sum(quantity) AS [quantity_unconsumed],
		sum(quantity) AS [quantity],
		0 AS [is_from_previous_release]
	FROM
		[dbo].[staging_pdas_footwear_vans_nora_forecast] nf
		INNER JOIN
		(
			SELECT max([id]) as id, [market]
			FROM [dbo].[dim_customer]
			GROUP BY market
		) dc
			ON nf.[dim_region_region] = dc.[market]
		LEFT OUTER JOIN
		(
			SELECT id, material_id
			FROM [dbo].[dim_product]
			WHERE
				is_placeholder = 1 AND
				placeholder_level = 'material_id'
		) dp
			ON nf.dim_product_material_id = dp.material_id
		INNER JOIN
		(
			SELECT [season_year_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_buy] = nf.season
			AND dd.month_name_short_accounting = nf.plan_month
	WHERE
		quantity IS NOT NULL
	GROUP BY
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END,
		dd.id,
		dc.id






	-- NGC

	-- Drop temporary table if exists
	IF OBJECT_ID('tempdb..#source_temp') IS NOT NULL
	BEGIN
		DROP TABLE #source_temp;
	END

	-- Create temp table
	CREATE TABLE #source_temp (
		[dim_pdas_id] INT
		,[dim_business_id] INT
		,[dim_buying_program_id] INT
		,[dim_product_id] INT
		,[dim_date_id] INT
		,[dim_factory_id_original_unconstrained] INT
		,[dim_factory_id_original_constrained] INT
		,[dim_factory_id_final] INT
		,[dim_factory_id] INT
		,[dim_customer_id] INT
		,[dim_demand_category_id] INT
		,[order_number] NVARCHAR(45)
		,[so_code] NVARCHAR(45)
		,[is_asap] SMALLINT
		,[quantity_lum] INT
		,[quantity_non_lum] INT
		,[quantity_unconsumed] INT
		,[quantity] INT
		,[production_lt_actual_buy] INT
		,[is_from_previous_release] TINYINT
		,[source_system] NVARCHAR(45)
	)

	-- Fill temp table with NGC data
	INSERT INTO #source_temp
    (
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_factory_id_original_unconstrained]
		,[dim_factory_id_original_constrained]
		,[dim_factory_id_final]
		,[dim_factory_id]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[order_number]
		,[so_code]
		,[is_asap]
		,[quantity_lum]
		,[quantity_non_lum]
		,[quantity_unconsumed]
		,[quantity]
		,[production_lt_actual_buy]
		,[is_from_previous_release]
		,[source_system]
    )
	-- ngc data
	SELECT
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,ngc.[dim_date_id]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id_original_unconstrained]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id_original_constrained]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id_final]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN @dim_factory_id_placeholder
			ELSE [dim_factory_id]
		END AS [dim_factory_id]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[order_number]
		,[so_code]
		,[is_asap]
		,[quantity_lum]
		,[quantity_non_lum]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN [quantity_lum]
			ELSE [quantity_non_lum]
		END AS [quantity_unconsumed]
		,CASE [dim_demand_category_id]
			WHEN @dim_demand_category_id_ntb THEN [quantity_lum]
			ELSE [quantity_non_lum]
		END AS [quantity]
		,DATEDIFF(day, @pdas_release_full_d, dd.[full_date]) as [production_lt_actual_buy]
		,0 AS [is_from_previous_release]
		,[source_system]
	FROM
	(
		SELECT
			@pdasid as dim_pdas_id,
			@businessid as dim_business_id,
			@buying_program_id as dim_buying_program_id,
			ISNULL(po_code_cut, 'UNDEFINED') as order_number,
			dd_revised_crd.id as dim_date_id,
			0 as is_asap,
			CASE
				WHEN df.id IS NOT NULL THEN df.id
				WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
				ELSE @dim_factory_id_placeholder
			END as dim_factory_id,
			CASE
				WHEN dc_plt.id IS NOT NULL THEN dc_plt.id
				ELSE @dim_customer_id_placeholder
			END as dim_customer_id,
			CASE
				WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
				ELSE dp_m.id
			END as dim_product_id,
			CASE ISNULL(ngc.shipment_status, 0)
				WHEN 1 THEN @dim_demand_category_id_shipped_order
				ELSE @dim_demand_category_id_open_order
			END as dim_demand_category_id,
			MAX(revised_crd_dt) as [customer_requested_xf_dt],
			MAX(actual_crd_dt) as [original_customer_requested_dt],
			CASE ISNULL(ngc.shipment_status, 0)
				WHEN 1 THEN SUM(ngc.lum_shipped_qty)
				ELSE SUM(ngc.lum_order_qty)
			END as [quantity_lum],
			CASE ISNULL(ngc.shipment_status, 0)
				WHEN 1 THEN SUM(ngc.shipped_qty)
				ELSE SUM(ngc.order_qty)
			END as [quantity_non_lum],
			MAX([source_system]) as [source_system],
			MAX(sales_order) as [so_code]

		FROM
			(
				SELECT
					REPLACE(dim_product_style_id, ' ', '') as dim_product_style_id
					,LTRIM(RTRIM(dim_product_size)) as dim_product_size
					,REPLACE([dim_factory_factory_code], ' ', '') as dim_factory_factory_code
					,REPLACE(dim_customer_dc_code_brio, ' ', '') as dim_customer_dc_code_brio
					,revised_crd_dt
					,actual_crd_dt
					,po_code
					,po_code_cut
					,shipment_status
					,shipped_qty
					,lum_shipped_qty
					,order_qty
					,lum_order_qty
					,source_system
					,sales_order
				FROM [dbo].[staging_pdas_footwear_vans_ngc_po]
			) ngc

			LEFT OUTER JOIN
			(
				SELECT [id], [material_id]
				FROM [dbo].[dim_product]
				WHERE
					[is_placeholder] = 1 AND
					[placeholder_level] = 'material_id'
			) AS dp_m
				ON ngc.dim_product_style_id = dp_m.material_id
			LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
				ON 	ngc.dim_product_style_id = dp_ms.material_id AND
					ngc.dim_product_size = dp_ms.size

			LEFT OUTER JOIN [dbo].[dim_factory] df ON ngc.dim_factory_factory_code = df.short_name
			LEFT OUTER JOIN
			(
				SELECT df.id, m.child
				FROM
					[dbo].[helper_pdas_footwear_vans_mapping] m
					INNER JOIN (SELECT id, short_name FROM [dbo].[dim_factory]) df
						ON m.parent = df.short_name
				WHERE category = 'Factory Master'
			) mapping_f ON ngc.dim_factory_factory_code = mapping_f.child

			LEFT OUTER JOIN (SELECT MAX([id]) as [id], [dc_plt] FROM [dbo].[dim_customer] GROUP BY [dc_plt]) dc_plt
				ON ngc.dim_customer_dc_code_brio = dc_plt.dc_plt

			LEFT OUTER JOIN [dbo].[dim_date] dd_revised_crd ON ngc.revised_crd_dt = dd_revised_crd.full_date
			-- LEFT OUTER JOIN [dbo].[dim_date] dd_original_crd ON ngc.actual_crd_dt = dd_original_crd.full_date

		WHERE
			(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
			dd_revised_crd.id IS NOT NULL
		GROUP BY
			ISNULL(po_code_cut, 'UNDEFINED'),
			dd_revised_crd.id,
			CASE
				WHEN df.id IS NOT NULL THEN df.id
				WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
				ELSE @dim_factory_id_placeholder
			END,
			CASE
				WHEN dc_plt.id IS NOT NULL THEN dc_plt.id
				ELSE @dim_customer_id_placeholder
			END,
			CASE
				WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
				ELSE dp_m.id
			END,
			ISNULL(ngc.shipment_status, 0)
	) ngc
		INNER JOIN [dbo].[dim_date] dd
			ON ngc.[dim_date_id] = dd.[id]
	WHERE
		[dim_pdas_id] = @pdasid
		AND [dim_business_id] = @businessid
		AND DATEDIFF(month, dd.full_date, @pdas_release_full_d) <= 2

	-- Update fact demand total with NGC
	UPDATE target WITH (serializable)
	SET
	   target.[dim_pdas_id] = #source_temp.[dim_pdas_id]
	   ,target.[dim_business_id] = #source_temp.[dim_business_id]
	   ,target.[dim_buying_program_id] = #source_temp.[dim_buying_program_id]
	   ,target.[dim_product_id] = #source_temp.[dim_product_id]
	   ,target.[dim_date_id] = #source_temp.[dim_date_id]
	   ,target.[dim_factory_id_original_unconstrained] = #source_temp.[dim_factory_id_original_unconstrained]
	   ,target.[dim_factory_id_original_constrained] = #source_temp.[dim_factory_id_original_constrained]
	   ,target.[dim_factory_id_final] = #source_temp.[dim_factory_id_final]
	   ,target.[dim_factory_id] = #source_temp.[dim_factory_id]
	   ,target.[dim_customer_id] = #source_temp.[dim_customer_id]
	   ,target.[dim_demand_category_id] = #source_temp.[dim_demand_category_id]
	   ,target.[order_number] = #source_temp.[order_number]
	   ,target.[so_code] = #source_temp.[so_code]
	   ,target.[is_asap] = #source_temp.[is_asap]
	   ,target.[quantity_lum] = #source_temp.[quantity_lum]
	   ,target.[quantity_non_lum] = #source_temp.[quantity_non_lum]
	   ,target.[quantity_unconsumed] = #source_temp.[quantity_unconsumed]
	   ,target.[quantity] = #source_temp.[quantity]
	   ,target.[production_lt_actual_buy] = #source_temp.[production_lt_actual_buy]
	   ,target.[is_from_previous_release] = #source_temp.[is_from_previous_release]
	   ,target.[source_system] = #source_temp.[source_system]

	FROM (
		   SELECT *
		   FROM [dbo].[fact_demand_total]
		   WHERE
			   [dim_pdas_id] = @pdasid and
			   [dim_business_id] = @businessid and
			   [dim_demand_category_id] IN (
				   @dim_demand_category_id_open_order,
				   @dim_demand_category_id_shipped_order
			   )
	     ) target
		INNER JOIN
		#source_temp
			ON target.[order_number] = #source_temp.[order_number]

	IF @@rowcount = 0
	BEGIN
	  INSERT INTO [dbo].[fact_demand_total]
	  (
			[dim_pdas_id]
			,[dim_business_id]
			,[dim_buying_program_id]
			,[dim_product_id]
			,[dim_date_id]
			,[dim_factory_id_original_unconstrained]
			,[dim_factory_id_original_constrained]
			,[dim_factory_id_final]
			,[dim_factory_id]
			,[dim_customer_id]
			,[dim_demand_category_id]
			,[order_number]
			,[so_code]
			,[is_asap]
			,[quantity_lum]
			,[quantity_non_lum]
			,[quantity_unconsumed]
			,[quantity]
			,[production_lt_actual_buy]
			,[is_from_previous_release]
			,[source_system]
	  )
	  SELECT *
	  FROM #source_temp
	END

	-- Update dim_customer_id from initial customer mapping via PO/cut#
	UPDATE target
	SET
		target.[dim_customer_id] = source.[dim_customer_id]
	FROM
		(
			SELECT *
			FROM [dbo].[fact_demand_total]
			WHERE
				[dim_pdas_id] = @pdasid and
				[dim_business_id] = @businessid and
				[dim_demand_category_id] IN (
					@dim_demand_category_id_open_order,
					@dim_demand_category_id_shipped_order
				)
		) target
		INNER JOIN
		(
			SELECT
				source.[PO/cut#] as po_code_cut
				,dc.id as dim_customer_id
			FROM
				[dbo].[staging_pdas_footwear_vans_ngc_initial_load_customer_mapping] source
				INNER JOIN dim_customer dc
					ON dc.name = source.[Customer]
		) source
			ON target.[order_number] = source.po_code_cut

	-- Update dim_customer_id for source system 'S65'
	-- If (source_system =='S65')  // NORA POs
	-- { Map sales_order (trim the leading zero) against Sales Doc (column BA) in NORA NTB file}
	UPDATE target
	SET
		target.[dim_customer_id] = source.[dim_customer_id]
	FROM
		(
			SELECT
				SUBSTRING([so_code], 2, 255) as sales_order
				,dim_customer_id as dim_customer_id
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN
				(
					SELECT dc.id
					FROM
						dim_customer dc
						INNER JOIN dim_location dl
							ON dc.dim_location_id = dl.[id]
					WHERE dl.[region] = 'NORA'
				) dim_customer
					ON f.dim_customer_id = dim_customer.id
			WHERE
				[dim_pdas_id] = @pdasid and
				[dim_business_id] = @businessid and
				[dim_demand_category_id] IN (
					@dim_demand_category_id_open_order,
					@dim_demand_category_id_shipped_order
				)
				and [source_system] = 'S65' and
				[so_code] IS NOT NULL
		) target
		INNER JOIN -- NORA NTB
		(
			SELECT
				f.[so_code] as sales_order
				,f.dim_customer_id as dim_customer_id
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN
				(
					SELECT dc.id
					FROM
						dim_customer dc
						INNER JOIN dim_location dl
						 	ON dc.dim_location_id = dl.[id]
					WHERE dl.[region] = 'NORA'
				) dim_customer
					ON f.dim_customer_id = dim_customer.id
			WHERE
				[dim_pdas_id] = @pdasid and
				[dim_business_id] = @businessid and
				[dim_demand_category_id] = @dim_demand_category_id_ntb and
				[so_code] IS NOT NULL
		) source
			ON target.sales_order = source.sales_order

	-- Update dim_customer_id for source system 'REVA'
	-- 	If (source_system =='REVA')  // APAC POs
	-- { Map sales_order against Customer PO# (column T) in APAC NTB file}
	UPDATE target
	SET
		target.[dim_customer_id] = source.[dim_customer_id]
	FROM
		(
			SELECT
				[so_code] as sales_order
				,dim_customer_id as dim_customer_id
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN
				(
					SELECT dc.id
					FROM
						dim_customer dc
						INNER JOIN dim_location dl
						 	ON dc.dim_location_id = dl.[id]
					WHERE dl.[region] = 'APAC'
				) dim_customer
					ON f.dim_customer_id = dim_customer.id
			WHERE
				[dim_pdas_id] = @pdasid and
				[dim_business_id] = @businessid and
				[dim_demand_category_id] IN (
					@dim_demand_category_id_open_order,
					@dim_demand_category_id_shipped_order
				)
				and [source_system] = 'REVA'
		) target
		INNER JOIN -- APAC NTB
		(
			SELECT
				f.[po_code_customer] as sales_order
				,f.dim_customer_id as dim_customer_id
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN
				(
					SELECT dc.id
					FROM
						dim_customer dc
						INNER JOIN dim_location dl
						 	ON dc.dim_location_id = dl.[id]
					WHERE dl.[region] = 'APAC'
				) dim_customer
					ON f.dim_customer_id = dim_customer.id
			WHERE
				[dim_pdas_id] = @pdasid and
				[dim_business_id] = @businessid and
				[dim_demand_category_id] = @dim_demand_category_id_ntb
		) source
			ON target.sales_order = source.sales_order



	-- Update the dim_date_id_buy_month
	UPDATE f
	SET
		f.[dim_date_id_buy_month] = dim_date.[id]
	FROM
		(
			SELECT *
			FROM [dbo].[fact_demand_total]
			WHERE
				[dim_pdas_id] = @pdasid
				AND [dim_business_id] = @businessid
		) f
		INNER JOIN
		(
			SELECT [id], [buy_month]
			FROM [dbo].[dim_pdas]
			WHERE
				[id] = @pdasid
		) dim_pdas
			ON f.[dim_pdas_id] = dim_pdas.[id]
		INNER JOIN
		(
			SELECT
				MIN([id]) as [id]
				,[year_month_accounting]
			FROM [dbo].[dim_date]
			GROUP BY [year_month_accounting]
		) dim_date
			ON dim_pdas.[buy_month] = dim_date.[year_month_accounting]


	-- Update the dim_date_id_forecast_vs_actual
	UPDATE [dbo].[fact_demand_total]
	SET
		[dim_date_id_forecast_vs_actual] =
			CASE dim_demand_category_id
				WHEN @dim_demand_category_id_ntb THEN [dim_date_id_buy_month]
				ELSE [dim_date_id]
			END
	WHERE
		[dim_pdas_id] = @pdasid
		AND [dim_business_id] = @businessid

END
