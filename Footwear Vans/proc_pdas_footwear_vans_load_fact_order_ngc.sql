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
	DECLARE	@current_date date = GETDATE()

	-- Check if the session has already been loaded
	DELETE FROM [dbo].[fact_order]
    WHERE
        dim_pdas_id = @pdasid
        AND dim_demand_category_id IN (@dim_demand_category_id_open_order, @dim_demand_category_id_shipped_order)
        AND dim_buying_program_id = @buying_program_id

	-- Insert from staging
	INSERT INTO [dbo].[fact_order](
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[order_number]
		,[dim_date_id]
		,[is_asap]
		,[dim_factory_id]
		,[dim_customer_id]
		,[dim_product_id]
		,[dim_demand_category_id]
		,[customer_requested_xf_dt]
		,[original_customer_requested_dt]
		,[quantity_lum]
		,[quantity_non_lum]
		,[source_system]
		,[so_code]
    )
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
			WHERE type = 'Factory Master'
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


	-- Update dim_customer_id from initial customer mapping via PO/cut#
	UPDATE target
	SET
		target.[dim_customer_id] = source.[dim_customer_id]
	FROM
		(
			SELECT *
			FROM [dbo].[fact_order]
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
				,MAX(dim_customer_id) as dim_customer_id
			FROM
				[dbo].[fact_order] f
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
				and [source_system] = 'S65'
				and ISNULL([so_code], '') <> ''
			GROUP BY 
				f.[so_code]
		) target
		INNER JOIN -- NORA NTB
		(
			SELECT
				f.[so_code] as sales_order
				,MAX(f.dim_customer_id) as dim_customer_id
			FROM
				[dbo].[fact_order] f
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
				[dim_demand_category_id] = @demand_category_id_ntb and
				ISNULL([so_code], '') <> ''
			GROUP BY
				f.[so_code]
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
				,MAX(dim_customer_id) as dim_customer_id
			FROM
				[dbo].[fact_order] f
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
				and ISNULL([so_code], '') <> ''
			GROUP BY
				f.[so_code]
		) target
		INNER JOIN -- APAC NTB
		(
			SELECT
				f.[po_code_customer] as sales_order
				,MAX(f.dim_customer_id) as dim_customer_id
			FROM
				[dbo].[fact_order] f
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
				[dim_demand_category_id] = @demand_category_id_ntb
				and ISNULL([po_code_customer], '') <> ''
			GROUP BY
				f.[po_code_customer]
		) source
			ON target.sales_order = source.sales_order

	-- Update dim_customer_id for source system 'JBA'
	-- 	If (source_system LIKE '%JBA%')  // EMEA POs
	-- { Use DC_Name in NGC PO file}
	-- Nothing to update

END
