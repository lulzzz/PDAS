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

	-- Placeholder
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
        dim_pdas_id,
        dim_business_id,
        dim_buying_program_id,
        order_number,
        dim_date_id,
        dim_factory_id,
        dim_customer_id,
        dim_product_id,
        dim_demand_category_id,
        placed_date_id,
        customer_requested_xf_date_id,
        original_factory_confirmed_xf_date_id,
        current_factory_confirmed_xf_date_id,
        expected_xf_date_id,actual_xf_date_id,
        delay_reason,initial_confirmed_date_id,
        current_vendor_requested_xf_date_id,
        current_customer_requested_xf_date_id,
        customer_canceled_date_id,
        original_customer_requested_date_id,
        estimated_eta_date_id,
        release_date_id,
        lum_quantity,
        quantity
    )
	SELECT
        @pdasid as dim_pdas_id,
        @businessid as dim_business_id,
        @buying_program_id as dim_buying_program_id,
        ISNULL(po_code, 'UNDEFINED') as order_number,
		CASE ngc.shipment_status
			WHEN 1 THEN dd_original_crd.id
			ELSE dd_revised_crd.id
		END as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END as dim_factory_id,
		@dim_customer_id_placeholder as dim_customer_id,
		-- CASE
		-- 	WHEN dc.id IS NOT NULL THEN dc.id
		-- 	ELSE @dim_customer_id_placeholder
		-- END as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        CASE
		 	WHEN ISNULL(shipped_qty, 0) <> ngc.order_qty THEN @dim_demand_category_id_open_order
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
		(
			SELECT
				REPLACE(dim_product_style_id, ' ', '') as dim_product_style_id
				,LTRIM(RTRIM(dim_product_size)) as dim_product_size
				,REPLACE([dim_factory_factory_code], ' ', '') as dim_factory_factory_code
				,notes
				,revised_crd_dt
				,original_crd_dt
				,po_issue_dt
			    ,shipped_dt
			    ,shipment_closed_on_dt
				,po_code
				,shipment_status
				,shipped_qty
				,lum_qty
				,order_qty
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
		LEFT OUTER JOIN [dbo].[dim_customer] dc ON ngc.notes LIKE '%'+ dc.name +'%'
		INNER JOIN [dbo].[dim_date] dd_revised_crd ON ngc.revised_crd_dt = dd_revised_crd.full_date
		INNER JOIN [dbo].[dim_date] dd_original_crd ON ngc.original_crd_dt = dd_original_crd.full_date
		LEFT OUTER JOIN [dbo].[dim_date] dd_po_issue ON ngc.po_issue_dt = dd_po_issue.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_shipped ON ngc.shipped_dt = dd_shipped.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_shipment_closed_on ON ngc.shipment_closed_on_dt = dd_shipment_closed_on.full_date
	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL)
    GROUP BY
		ISNULL(po_code, 'UNDEFINED'),
		CASE ngc.shipment_status
			WHEN 1 THEN dd_original_crd.id
			ELSE dd_revised_crd.id
		END,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END,
		-- CASE
		-- 	WHEN dc.id IS NOT NULL THEN dc.id
		-- 	ELSE @dim_customer_id_placeholder
		-- END,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END,
		CASE
		 	WHEN ISNULL(shipped_qty, 0) <> ngc.order_qty THEN @dim_demand_category_id_open_order
			ELSE @dim_demand_category_id_shipped_order
		END

END
