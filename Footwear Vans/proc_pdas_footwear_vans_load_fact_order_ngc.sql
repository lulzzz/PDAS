USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the NGC orders in fact_order.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc]
	@businessid INT
AS
BEGIN

	-- Placeholders
	-- DECLARE @businessid INT = 1
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@buying_program_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
	DECLARE @dim_customer_id_placeholder int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [name] = 'PLACEHOLDER' AND [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@dim_demand_category_id_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Order')
	DECLARE @dim_demand_category_id_ntb int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Need to Buy')
	DECLARE @dim_customer_id_placeholder_casa int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'CASA')
	DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')
	DECLARE	@dim_release_id int = (SELECT id FROM [dbo].[dim_release] WHERE dim_demand_category_id = @dim_demand_category_id_order)

	-- Find delta date
	DECLARE	@starting_dt_rev_id int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT MIN(revised_crd_dt) FROM [dbo].[staging_pdas_footwear_vans_ngc_po_delta]))


	-- If starting dt exists
	IF @starting_dt_rev_id IS NOT NULL
	BEGIN

		-- Delete outdated delta
		DELETE FROM [dbo].[fact_demand_total]
		WHERE
			dim_release_id = @dim_release_id
			and dim_date_id >= @starting_dt_rev_id


		-- Fill table with NGC data
		INSERT INTO [dbo].[fact_demand_total]
	    (
			[dim_release_id]
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
			,[order_status]
			,[order_number]
			,[so_code]
			,[is_asap]
			,[quantity_lum]
			,[quantity_non_lum]
			,[production_lt_actual_buy]
			,[source_system]
	    )
		-- ngc data
		SELECT
			@dim_release_id AS dim_release_id,
			@businessid AS dim_business_id,
			@buying_program_id AS dim_buying_program_id,
			CASE
				WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
				ELSE dp_m.id
			END AS dim_product_id,
			CASE
				WHEN dd_original_crd.id IS NOT NULL THEN dd_original_crd.id
				ELSE dd_revised_crd.id
			END AS dim_date_id,
			CASE
				WHEN dd_original_crd.id IS NOT NULL THEN dd_original_crd.id
				ELSE dd_revised_crd.id
			END AS dim_date_id_buy_month,
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
				WHEN ([source_system] = 'REVA') OR ([source_system] = 'e-SPS' AND [dim_customer_dc_code_brio] = 'OABCJ') THEN @dim_customer_id_placeholder_apac
				WHEN ([source_system] IN ('JBA-VF', 'JBA-VC')) OR ([source_system] = 'e-SPS' AND [dim_customer_dc_code_brio] IN ('OCSDS', 'ORTLA')) THEN @dim_customer_id_placeholder_emea
				ELSE @dim_customer_id_placeholder
			END AS dim_customer_id,
			@dim_demand_category_id_order AS dim_demand_category_id,
			CASE ISNULL(ngc.shipment_status, 0)
				WHEN 1 THEN 'Shipped'
				ELSE 'Open'
			END AS [order_status],
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
			0 AS [production_lt_actual_buy],
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
				FROM [dbo].[staging_pdas_footwear_vans_ngc_po_delta]
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
			LEFT OUTER JOIN [dbo].[dim_date] dd_original_crd ON ngc.actual_crd_dt = dd_original_crd.full_date
		WHERE
			(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL)
			AND (dd_original_crd.id IS NOT NULL OR dd_revised_crd.id IS NOT NULL)
		GROUP BY
			ISNULL(po_code_cut, 'UNDEFINED'),
			CASE
				WHEN dd_original_crd.id IS NOT NULL THEN dd_original_crd.id
				ELSE dd_revised_crd.id
			END,
			CASE
				WHEN df.id IS NOT NULL THEN df.id
				WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
				ELSE @dim_factory_id_placeholder
			END,
			source_system,
			dim_customer_dc_code_brio,
			CASE
				WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
				ELSE dp_m.id
			END,
			ISNULL(ngc.shipment_status, 0)

		print 3
	  	print CONVERT(varchar, SYSDATETIME(), 121)

	END

END
