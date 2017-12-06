DECLARE @pdasid INT = 1
DECLARE @businessid INT = 1


	-- Placeholders
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@buying_program_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
	DECLARE @dim_customer_id_placeholder int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [name] = 'PLACEHOLDER' AND [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@dim_demand_category_id_open_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Open Order')
	DECLARE	@dim_demand_category_id_shipped_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Shipped Order')
	DECLARE	@current_date date = GETDATE()

	-- Check if the session has already been loaded
	DELETE FROM [dbo].[fact_order_ngc_only]

	-- Insert from staging
	INSERT INTO [dbo].[fact_order_ngc_only](
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
		END as [quantity_non_lum]

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
		LEFT OUTER JOIN [dbo].[dim_date] dd_original_crd ON ngc.actual_crd_dt = dd_original_crd.full_date

	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		(
			(ISNULL(ngc.shipment_status, 0) = 1 AND dd_original_crd.id IS NOT NULL)
			OR
			(ISNULL(ngc.shipment_status, 0) = 0 AND dd_revised_crd.id IS NOT NULL)
		)
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
