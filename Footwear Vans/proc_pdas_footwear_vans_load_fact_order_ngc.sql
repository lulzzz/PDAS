USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the NGC orders in fact_order.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc]
	@pdasid INT,
	@businessid INT
AS
BEGIN

	-- Placeholders
	DECLARE @demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@buying_program_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
	DECLARE @dim_customer_id_placeholder int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [name] = 'PLACEHOLDER' AND [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@dim_demand_category_id_open_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Open Order')
	DECLARE	@dim_demand_category_id_shipped_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Shipped Order')
	DECLARE @dim_customer_id_placeholder_casa int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'CASA')
	DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')
	DECLARE	@current_date date = GETDATE()
	DECLARE @dim_demand_category_id_ntb int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Need to Buy')

	-- Release full dim_date_id
	DECLARE @pdas_release_full_date_id int
	SET @pdas_release_full_date_id = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)
	DECLARE @pdas_release_full_d date = (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = @pdas_release_full_date_id)

	DECLARE @dim_date_id_buy_month int = (
		SELECT dim_date.[id]
		FROM
		(
			SELECT [id], [buy_month]
			FROM [dbo].[dim_pdas]
			WHERE
				[id] = @pdasid
		) dim_pdas
		INNER JOIN
		(
			SELECT
				MIN([id]) as [id]
				,[year_month_accounting]
			FROM [dbo].[dim_date]
			GROUP BY [year_month_accounting]
		) dim_date
			ON dim_pdas.[buy_month] = dim_date.[year_month_accounting]
	)

	-- NGC
  	print 1
  	print CONVERT(varchar, SYSDATETIME(), 121)
	-- Drop temporary table if exists
	IF OBJECT_ID('tempdb..#source_temp') IS NOT NULL
	BEGIN
		DROP TABLE #source_temp;
	END

  	print 2
  	print CONVERT(varchar, SYSDATETIME(), 121)

	-- Create temp table
	CREATE TABLE #source_temp (
		[dim_pdas_id] INT
		,[dim_business_id] INT
		,[dim_buying_program_id] INT
		,[dim_product_id] INT
		,[dim_date_id] INT
		,[dim_date_id_buy_month] INT
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
		,[dim_date_id_buy_month]
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
		@pdasid AS dim_pdas_id,
		@businessid AS dim_business_id,
		@buying_program_id AS dim_buying_program_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END AS dim_product_id,
		dd_revised_crd.id AS dim_date_id,
		@dim_date_id_buy_month AS dim_date_id_buy_month,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END AS [dim_factory_id_original_unconstrained],
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END AS [dim_factory_id_original_constrained],
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END AS [dim_factory_id_final],
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END AS [dim_factory_id],
		CASE
			WHEN [source_system] = 'S65' THEN @dim_customer_id_placeholder_nora
			WHEN [source_system] = 'CONDOR' THEN @dim_customer_id_placeholder_casa
			WHEN ([source_system] = 'REVA') OR ([source_system] = 'e-SPS' AND [dim_customer_dc_code_brio] = 'OABCJ') THEN @dim_customer_id_placeholder_nora
			WHEN ([source_system] IN ('JBA-VF', 'JBA-VC') OR ([source_system] = 'e-SPS' AND [dim_customer_dc_code_brio] IN ('OCSDS', 'ORTLA')) THEN @dim_customer_id_placeholder_nora
			ELSE @dim_customer_id_placeholder
		END AS dim_customer_id,
		CASE ISNULL(ngc.shipment_status, 0)
			WHEN 1 THEN @dim_demand_category_id_shipped_order
			ELSE @dim_demand_category_id_open_order
		END AS dim_demand_category_id,
		ISNULL(po_code_cut, 'UNDEFINED') AS order_number,
		MAX(sales_order) AS [so_code],
		0 AS is_asap,
		CASE ISNULL(ngc.shipment_status, 0)
			WHEN 1 THEN SUM(ngc.lum_shipped_qty)
			ELSE SUM(ngc.lum_order_qty)
		END AS [quantity_lum],
		CASE ISNULL(ngc.shipment_status, 0)
			WHEN 1 THEN SUM(ngc.shipped_qty)
			ELSE SUM(ngc.order_qty)
		END AS [quantity_non_lum],
		CASE ISNULL(ngc.shipment_status, 0)
			WHEN 1 THEN SUM(ngc.shipped_qty)
			ELSE SUM(ngc.order_qty)
		END AS [quantity_unconsumed],
		CASE ISNULL(ngc.shipment_status, 0)
			WHEN 1 THEN SUM(ngc.shipped_qty)
			ELSE SUM(ngc.order_qty)
		END AS [quantity],
		DATEDIFF(day, @pdas_release_full_d, dd_revised_crd.full_date) AS [production_lt_actual_buy],
		0 AS [is_from_previous_release],
		[source_system]
	FROM
		(
			SELECT
				REPLACE(dim_product_style_id, ' ', '') AS dim_product_style_id
				,LTRIM(RTRIM(dim_product_size)) AS dim_product_size
				,REPLACE([dim_factory_factory_code], ' ', '') AS dim_factory_factory_code
				,REPLACE(dim_customer_dc_code_brio, ' ', '') AS dim_customer_dc_code_brio
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
			ON 	ngc.dim_product_style_id = dp_ms.material_id
			AND ngc.dim_product_size = dp_ms.size

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

		LEFT OUTER JOIN (SELECT MAX([id]) AS [id], [dc_plt] FROM [dbo].[dim_customer] GROUP BY [dc_plt]) dc_plt
			ON ngc.dim_customer_dc_code_brio = dc_plt.dc_plt

		LEFT OUTER JOIN [dbo].[dim_date] dd_revised_crd ON ngc.revised_crd_dt = dd_revised_crd.full_date
		-- LEFT OUTER JOIN [dbo].[dim_date] dd_original_crd ON ngc.actual_crd_dt = dd_original_crd.full_date
	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL)
		AND dd_revised_crd.id IS NOT NULL
		-- AND DATEDIFF(month, dd_revised_crd.full_date, @pdas_release_full_d) <= 2

		-- AND YEAR(actual_crd_dt) = 2018
		-- AND MONTH(actual_crd_dt) >= 2
		-- AND MONTH(actual_crd_dt) <= 4
	GROUP BY
		ISNULL(po_code_cut, 'UNDEFINED'),
		dd_revised_crd.id,
		dd_revised_crd.full_date,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END,
		source_system
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END,
		ISNULL(ngc.shipment_status, 0)

	print 3
  print CONVERT(varchar, SYSDATETIME(), 121)

	-- Update fact demand total with NGC

	-- Update existing rows
	UPDATE target WITH (serializable)
	SET
	    target.[dim_pdas_id] = #source_temp.[dim_pdas_id]
	   ,target.[dim_business_id] = #source_temp.[dim_business_id]
	   ,target.[dim_buying_program_id] = #source_temp.[dim_buying_program_id]
	   ,target.[dim_product_id] = #source_temp.[dim_product_id]
	   ,target.[dim_date_id] = #source_temp.[dim_date_id]
	   ,target.[dim_date_id_buy_month] = @dim_date_id_buy_month
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

		INNER JOIN #source_temp
			ON target.[dim_pdas_id] = #source_temp.[dim_pdas_id]
			AND target.[dim_business_id] = #source_temp.[dim_business_id]
			AND target.[dim_buying_program_id] = #source_temp.[dim_buying_program_id]
			AND target.[dim_product_id] = #source_temp.[dim_product_id]
			AND target.[dim_date_id] = #source_temp.[dim_date_id]
			AND target.[dim_factory_id_original_unconstrained] = #source_temp.[dim_factory_id_original_unconstrained]
			AND target.[dim_customer_id] = #source_temp.[dim_customer_id]
			AND target.[dim_demand_category_id] = #source_temp.[dim_demand_category_id]
			AND target.[order_number] = #source_temp.[order_number]



		   AND target.[dim_date_id_buy_month] = @dim_date_id_buy_month
		   AND target.[so_code] = #source_temp.[so_code]
		   AND target.[is_asap] = #source_temp.[is_asap]

		   -- ,target.[quantity_lum] = #source_temp.[quantity_lum]
		   -- ,target.[quantity_non_lum] = #source_temp.[quantity_non_lum]
		   -- ,target.[quantity_unconsumed] = #source_temp.[quantity_unconsumed]
		   -- ,target.[quantity] = #source_temp.[quantity]
		   -- ,target.[production_lt_actual_buy] = #source_temp.[production_lt_actual_buy]
		   AND target.[is_from_previous_release] = #source_temp.[is_from_previous_release]
		   AND target.[source_system] = #source_temp.[source_system]

	print 4
  print CONVERT(varchar, SYSDATETIME(), 121)
	-- Insert NGC new rows
	INSERT INTO [dbo].[fact_demand_total]
	(
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_date_id_buy_month]
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
	SELECT
		#source_temp.[dim_pdas_id]
		,#source_temp.[dim_business_id]
		,#source_temp.[dim_buying_program_id]
		,#source_temp.[dim_product_id]
		,#source_temp.[dim_date_id]
		,#source_temp.[dim_date_id_buy_month]
		,#source_temp.[dim_factory_id_original_unconstrained]
		,#source_temp.[dim_factory_id_original_constrained]
		,#source_temp.[dim_factory_id_final]
		,#source_temp.[dim_factory_id]
		,#source_temp.[dim_customer_id]
		,#source_temp.[dim_demand_category_id]
		,#source_temp.[order_number]
		,#source_temp.[so_code]
		,#source_temp.[is_asap]
		,#source_temp.[quantity_lum]
		,#source_temp.[quantity_non_lum]
		,#source_temp.[quantity_unconsumed]
		,#source_temp.[quantity]
		,#source_temp.[production_lt_actual_buy]
		,#source_temp.[is_from_previous_release]
		,#source_temp.[source_system]
	FROM
		#source_temp
		LEFT OUTER JOIN
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
			ON target.[dim_pdas_id] = #source_temp.[dim_pdas_id]
			AND target.[dim_business_id] = #source_temp.[dim_business_id]
			AND target.[dim_buying_program_id] = #source_temp.[dim_buying_program_id]
			AND target.[dim_product_id] = #source_temp.[dim_product_id]
			AND target.[dim_date_id] = #source_temp.[dim_date_id]
			AND target.[dim_factory_id_original_unconstrained] = #source_temp.[dim_factory_id_original_unconstrained]
			AND target.[dim_customer_id] = #source_temp.[dim_customer_id]
			AND target.[dim_demand_category_id] = #source_temp.[dim_demand_category_id]
			AND target.[order_number] = #source_temp.[order_number]

		WHERE target.[order_number] IS NULL


	-- WHERE
	-- 	NOT EXISTS (
	-- 		SELECT *
	-- 		FROM [dbo].[fact_demand_total] target
	-- 		WHERE
	-- 					target.[dim_pdas_id] = #source_temp.[dim_pdas_id]
	-- 			AND target.[dim_business_id] = #source_temp.[dim_business_id]
	-- 			AND target.[dim_buying_program_id] = #source_temp.[dim_buying_program_id]
	-- 			AND target.[dim_product_id] = #source_temp.[dim_product_id]
	-- 			AND target.[dim_date_id] = #source_temp.[dim_date_id]
	-- 			AND target.[dim_factory_id_original_unconstrained] = #source_temp.[dim_factory_id_original_unconstrained]
	-- 			AND target.[dim_customer_id] = #source_temp.[dim_customer_id]
	-- 			AND target.[dim_demand_category_id] = #source_temp.[dim_demand_category_id]
	-- 			AND target.[order_number] = #source_temp.[order_number]
	-- 			AND target.[is_from_previous_release] = 1
	-- 	)

	-- print 5
  -- print CONVERT(varchar, SYSDATETIME(), 121)
  --
	-- -- Update dim_customer_id from initial customer mapping via PO/cut#
	-- UPDATE target
	-- SET
	-- 	target.[dim_customer_id] = source.[dim_customer_id]
	-- FROM
	-- 	(
	-- 		SELECT *
	-- 		FROM [dbo].[fact_demand_total]
	-- 		WHERE
	-- 			[dim_pdas_id] = @pdasid and
	-- 			[dim_business_id] = @businessid and
	-- 			[dim_demand_category_id] IN (
	-- 				@dim_demand_category_id_open_order,
	-- 				@dim_demand_category_id_shipped_order
	-- 			)
	-- 	) target
	-- 	INNER JOIN
	-- 	(
	-- 		SELECT
	-- 			source.[PO/cut#] as po_code_cut
	-- 			,dc.id as dim_customer_id
	-- 		FROM
	-- 			[dbo].[staging_pdas_footwear_vans_ngc_initial_load_customer_mapping] source
	-- 			INNER JOIN dim_customer dc
	-- 				ON dc.name = source.[Customer]
	-- 	) source
	-- 		ON target.[order_number] = source.po_code_cut
  	--
	-- -- Update dim_customer_id for source system 'S65'
	-- -- If (source_system =='S65')  // NORA POs
	-- -- { Map sales_order (trim the leading zero) against Sales Doc (column BA) in NORA NTB file}
	-- UPDATE target
	-- SET
	-- 	target.[dim_customer_id] = source.[dim_customer_id]
	-- FROM
	-- 	(
	-- 		SELECT
	-- 			SUBSTRING([so_code], 2, 255) as sales_order
	-- 			,dim_customer_id as dim_customer_id
	-- 		FROM
	-- 			[dbo].[fact_demand_total] f
	-- 			INNER JOIN
	-- 			(
	-- 				SELECT dc.id
	-- 				FROM
	-- 					dim_customer dc
	-- 					INNER JOIN dim_location dl
	-- 						ON dc.dim_location_id = dl.[id]
	-- 				WHERE dl.[region] = 'NORA'
	-- 			) dim_customer
	-- 				ON f.dim_customer_id = dim_customer.id
	-- 		WHERE
	-- 			[dim_pdas_id] = @pdasid and
	-- 			[dim_business_id] = @businessid and
	-- 			[dim_demand_category_id] IN (
	-- 				@dim_demand_category_id_open_order,
	-- 				@dim_demand_category_id_shipped_order
	-- 			)
	-- 			and [source_system] = 'S65' and
	-- 			[so_code] IS NOT NULL
	-- 	) target
	-- 	INNER JOIN -- NORA NTB
	-- 	(
	-- 		SELECT
	-- 			f.[so_code] as sales_order
	-- 			,f.dim_customer_id as dim_customer_id
	-- 		FROM
	-- 			[dbo].[fact_demand_total] f
	-- 			INNER JOIN
	-- 			(
	-- 				SELECT dc.id
	-- 				FROM
	-- 					dim_customer dc
	-- 					INNER JOIN dim_location dl
	-- 					 	ON dc.dim_location_id = dl.[id]
	-- 				WHERE dl.[region] = 'NORA'
	-- 			) dim_customer
	-- 				ON f.dim_customer_id = dim_customer.id
	-- 		WHERE
	-- 			[dim_pdas_id] = @pdasid and
	-- 			[dim_business_id] = @businessid and
	-- 			[dim_demand_category_id] = @dim_demand_category_id_ntb and
	-- 			[so_code] IS NOT NULL
	-- 	) source
	-- 		ON target.sales_order = source.sales_order
  	--
	-- -- Update dim_customer_id for source system 'REVA'
	-- -- 	If (source_system =='REVA')  // APAC POs
	-- -- { Map sales_order against Customer PO# (column T) in APAC NTB file}
	-- UPDATE target
	-- SET
	-- 	target.[dim_customer_id] = source.[dim_customer_id]
	-- FROM
	-- 	(
	-- 		SELECT
	-- 			[so_code] as sales_order
	-- 			,dim_customer_id as dim_customer_id
	-- 		FROM
	-- 			[dbo].[fact_demand_total] f
	-- 			INNER JOIN
	-- 			(
	-- 				SELECT dc.id
	-- 				FROM
	-- 					dim_customer dc
	-- 					INNER JOIN dim_location dl
	-- 					 	ON dc.dim_location_id = dl.[id]
	-- 				WHERE dl.[region] = 'APAC'
	-- 			) dim_customer
	-- 				ON f.dim_customer_id = dim_customer.id
	-- 		WHERE
	-- 			[dim_pdas_id] = @pdasid and
	-- 			[dim_business_id] = @businessid and
	-- 			[dim_demand_category_id] IN (
	-- 				@dim_demand_category_id_open_order,
	-- 				@dim_demand_category_id_shipped_order
	-- 			)
	-- 			and [source_system] = 'REVA'
	-- 	) target
	-- 	INNER JOIN -- APAC NTB
	-- 	(
	-- 		SELECT
	-- 			f.[po_code_customer] as sales_order
	-- 			,f.dim_customer_id as dim_customer_id
	-- 		FROM
	-- 			[dbo].[fact_demand_total] f
	-- 			INNER JOIN
	-- 			(
	-- 				SELECT dc.id
	-- 				FROM
	-- 					dim_customer dc
	-- 					INNER JOIN dim_location dl
	-- 					 	ON dc.dim_location_id = dl.[id]
	-- 				WHERE dl.[region] = 'APAC'
	-- 			) dim_customer
	-- 				ON f.dim_customer_id = dim_customer.id
	-- 		WHERE
	-- 			[dim_pdas_id] = @pdasid and
	-- 			[dim_business_id] = @businessid and
	-- 			[dim_demand_category_id] = @dim_demand_category_id_ntb
	-- 	) source
	-- 		ON target.sales_order = source.sales_order


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

	-- Update dim_customer_id for source system 'JBA'
	-- 	If (source_system LIKE '%JBA%')  // EMEA POs
	-- { Use DC_Name in NGC PO file}
	-- Nothing to update

	print 6
  	print CONVERT(varchar, SYSDATETIME(), 121)


	-- Update id_original
	UPDATE [fact_demand_total]
	SET [id_original] = [id]
	WHERE
		[dim_pdas_id] = @pdasid
		and [dim_business_id] = @businessid
		and [is_from_previous_release] = 0
		and ISNULL([id_original], 0) = 0

END
