DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
	DECLARE @businessid int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')

-- Placeholder
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@buying_program_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
    DECLARE	@dim_demand_category_id_open_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Open Order')
	DECLARE	@dim_demand_category_id_shipped_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Shipped Order')
	DECLARE	@dim_demand_category_id_received_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Received Order')
	DECLARE	@current_date date = GETDATE()


SELECT
        @pdasid as dim_pdas_id,
        @businessid as dim_business_id,
        @buying_program_id as dim_buying_program_id,
        ISNULL(po_code, 'UNDEFINED') as order_number,
        dd_revised_crd.id as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END as dim_factory_id,
        dc.id as dim_customer_id,
        dp.id as dim_product_id,
        CASE
		 	WHEN shipped_qty IS NULL THEN @dim_demand_category_id_open_order
			WHEN revised_crd_dt < @current_date THEN @dim_demand_category_id_received_order
			ELSE @dim_demand_category_id_shipped_order
		END as dim_demand_category_id,
        MAX(dd_po_issue.id) as placed_date_id,
        MAX(dd_revised_crd.id) as customer_requested_xf_date_id,
        NULL as original_factory_confirmed_xf_date_id,
        MAX(dd_shipped.id) as current_factory_confirmed_xf_date_id,
        NULL as expected_xf_date_id,
        NULL as actual_xf_date_id,
        NULL as delay_reason,
        NULL as initial_confirmed_date_id,
        NULL as current_vendor_requested_xf_date_id,
        NULL as current_customer_requested_xf_date_id,
        NULL as customer_canceled_date_id,
        NULL as original_customer_requested_date_id,
        NULL as estimated_eta_date_id,
        NULL as release_date_id,
        SUM(ngc.lum_qty) as lum_quantity,
        SUM(ngc.order_qty) as quantity
	FROM
		[dbo].[staging_pdas_footwear_vans_ngc_po] ngc
		INNER JOIN [dbo].[dim_product] dp ON ngc.dim_product_style_id = dp.material_id and ngc.dim_product_size = dp.size
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
		INNER JOIN [dbo].[dim_customer] dc ON ngc.dc_name = dc.name
	    LEFT OUTER JOIN [dbo].[dim_date] dd_po_issue ON ngc.po_issue_dt = dd_po_issue.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_original_crd ON ngc.original_crd_dt = dd_original_crd.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_revised_crd ON ngc.revised_crd_dt = dd_revised_crd.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_shipped ON ngc.shipped_dt = dd_shipped.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_shipment_closed_on ON ngc.shipment_closed_on_dt = dd_shipment_closed_on.full_date
	WHERE
		dp.is_placeholder = 0 AND
		(df.id IS NOT NULL OR mapping_f.id IS NOT NULL)
    GROUP BY
		ISNULL(po_code, 'UNDEFINED'),
		dd_revised_crd.id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END,
		dc.id,
		dp.id,
		CASE
			WHEN shipped_qty IS NULL THEN @dim_demand_category_id_open_order
			WHEN revised_crd_dt < @current_date THEN @dim_demand_category_id_received_order
			ELSE @dim_demand_category_id_shipped_order
		END
