USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the NTB in fact_order.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb_bulk]
	@pdasid INT,
	@businessid INT,
	@buying_program_id INT
AS
BEGIN

	-- Placeholder
	DECLARE @demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
	DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')

	DECLARE @dim_date_id_pdas_release_day int = (SELECT MAX(dd.[id]) FROM [dbo].[dim_date] dd INNER JOIN [dbo].[dim_pdas] pdas ON pdas.date_id = dd.id)
	DECLARE @dim_date_id_pdas_release_day_future int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(yy, 1, full_date) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))


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

	-- EMEA
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		ISNULL(pr_code, 'UNDEFINED') as order_number,
		dd_xfw.id as dim_date_id,
		@dim_factory_id_placeholder as dim_factory_id,
		dc.id as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
		@demand_category_id_ntb as dim_demand_category_id,
		MAX(dd_buy.id) as placed_date_id,
		NULL as customer_requested_xf_date_id,
		NULL as original_factory_confirmed_xf_date_id,
		NULL as current_factory_confirmed_xf_date_id,
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
		SUM(ntb.lum_qty) as lum_quantity,
		SUM(ntb.sap_qty) as quantity
	FROM
		[dbo].[staging_pdas_footwear_vans_emea_ntb_bulk] ntb
		INNER JOIN (SELECT [id], [name], [sold_to_party] FROM [dbo].[dim_customer] WHERE is_placeholder = 0) dc
			ON ntb.dim_customer_name = dc.name
		INNER JOIN
		(
			SELECT
				[id],
				SUBSTRING([year_cw_accounting], 7, 2) AS [cw]
			FROM [dbo].[dim_date]
			WHERE
				[day_name_of_week] = 'Monday'
				and [id] BETWEEN @dim_date_id_pdas_release_day AND @dim_date_id_pdas_release_day_future
		) dd_xfw
			ON REPLACE(SUBSTRING(ntb.[exp_delivery_no_constraint_dt], 3, 10), ' ', '') = dd_xfw.[cw]
		LEFT OUTER JOIN
		(
			SELECT [id], [material_id]
			FROM [dbo].[dim_product]
			WHERE
				[is_placeholder] = 1 AND
				[placeholder_level] = 'material_id'
		) AS dp_m
			ON ntb.dim_product_style_id = dp_m.material_id
		LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
			ON 	ntb.dim_product_material_id = dp_ms.material_id AND
				ntb.dim_product_size = dp_ms.size
		LEFT OUTER JOIN [dbo].[dim_date] dd_buy ON ntb.buy_dt = dd_buy.full_date
	WHERE
		ntb.lum_qty IS NOT NULL
	GROUP BY
		ISNULL(pr_code, 'UNDEFINED'),
		dd_xfw.id,
		dc.id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END

	-- APAC
	UNION
    SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
        ISNULL(pr_code, 'UNDEFINED') as order_number,
        dd_xfac.id as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END as dim_factory_id,
		dc.id as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        @demand_category_id_ntb as dim_demand_category_id,
        NULL as placed_date_id,
        MAX(dd_xfac.id) as customer_requested_xf_date_id,
        NULL as original_factory_confirmed_xf_date_id,
        NULL as current_factory_confirmed_xf_date_id,
        MAX(dd_xfac.id) as expected_xf_date_id,
        NULL as actual_xf_date_id,
        NULL as delay_reason,
        NULL as initial_confirmed_date_id,
        NULL as current_vendor_requested_xf_date_id,
        NULL as current_customer_requested_xf_date_id,
        NULL as customer_canceled_date_id,
        NULL as original_customer_requested_date_id,
        NULL as estimated_eta_date_id,
        NULL as release_date_id,
        SUM(ntb.lum_qty) as lum_quantity,
        SUM(ntb.sap_qty) as quantity
    FROM
		[dbo].[staging_pdas_footwear_vans_apac_ntb_bulk] ntb
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
		 	ON ntb.dim_product_material_id = dp_m.material_id
		LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
			ON 	ntb.dim_product_material_id = dp_ms.material_id AND
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
		(df.id IS NOT NULL OR mapping_f.id IS NOT NULL) AND
		ntb.lum_qty IS NOT NULL
    GROUP BY
        ISNULL(pr_code, 'UNDEFINED'),
        dd_xfac.id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
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
        ISNULL(pr_code, 'UNDEFINED') as order_number,
        dd_xfac.id as dim_date_id,
        @dim_factory_id_placeholder as dim_factory_id,
		dc.id as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        @demand_category_id_ntb as dim_demand_category_id,
        NULL as placed_date_id,
        MAX(dd_xfac.id) as customer_requested_xf_date_id,
        NULL as original_factory_confirmed_xf_date_id,
        NULL as current_factory_confirmed_xf_date_id,
        MAX(dd_xfac.id) as expected_xf_date_id,
        MAX(dd_xfac.id) as actual_xf_date_id,
        NULL as delay_reason,
        NULL as initial_confirmed_date_id,
        NULL as current_vendor_requested_xf_date_id,
        NULL as current_customer_requested_xf_date_id,
        NULL as customer_canceled_date_id,
        NULL as original_customer_requested_date_id,
        NULL as estimated_eta_date_id,
        NULL as release_date_id,
        SUM(ntb.lum_qty) as lum_quantity,
        SUM(ntb.sap_qty) as quantity
	FROM
		[dbo].[staging_pdas_footwear_vans_casa_ntb_bulk] ntb
		LEFT OUTER JOIN
		(
			SELECT [id], [material_id]
			FROM [dbo].[dim_product]
			WHERE
				[is_placeholder] = 1 AND
				[placeholder_level] = 'material_id'
		) AS dp_m
			ON ntb.dim_product_style_id = dp_m.material_id
		LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
			ON 	ntb.dim_product_material_id = dp_ms.material_id AND
				ntb.dim_product_size = dp_ms.size
		INNER JOIN [dbo].[dim_customer] dc ON ntb.dim_customer_name = dc.name
	    INNER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
	WHERE
		ntb.lum_qty IS NOT NULL
    GROUP BY
        ISNULL(pr_code, 'UNDEFINED'),
        dd_xfac.id,
		dc.id,
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
        ISNULL(customer_po_code, 'UNDEFINED') as order_number,
        dd_xfac.id as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			WHEN mapping_f.id IS NOT NULL THEN mapping_f.id
			ELSE @dim_factory_id_placeholder
		END as dim_factory_id,
		@dim_customer_id_placeholder_nora as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        @demand_category_id_ntb as dim_demand_category_id,
        NULL as placed_date_id,
        MAX(dd_req.id) as customer_requested_xf_date_id,
        NULL as original_factory_confirmed_xf_date_id,
        NULL as current_factory_confirmed_xf_date_id,
        MAX(dd_xfac.id) as expected_xf_date_id,
        MAX(dd_act.id) as actual_xf_date_id,
        NULL as delay_reason,
        NULL as initial_confirmed_date_id,
        NULL as current_vendor_requested_xf_date_id,
        NULL as current_customer_requested_xf_date_id,
        NULL as customer_canceled_date_id,
        NULL as original_customer_requested_date_id,
        MAX(dd_eta.id) as estimated_eta_date_id,
        MAX(dd_rel.id) as release_date_id,
        SUM(ntb.lum_qty) as lum_quantity,
        SUM(ntb.quantity) as quantity
	FROM
		[dbo].[staging_pdas_footwear_vans_nora_ntb_bulk] ntb
		LEFT OUTER JOIN
		(
			SELECT [id], [material_id]
			FROM [dbo].[dim_product]
			WHERE
				[is_placeholder] = 1 AND
				[placeholder_level] = 'material_id'
		) AS dp_m
			ON ntb.dim_product_style_id = dp_m.material_id
		LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
			ON 	ntb.dim_product_material_id = dp_ms.material_id AND
				ntb.dim_product_size = dp_ms.size
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
	    LEFT OUTER JOIN [dbo].[dim_date] dd_req ON ntb.req_dt = dd_req.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_eta ON ntb.delivered_dt = dd_eta.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_rel ON ntb.sr_sent_dt = dd_rel.full_date
	    LEFT OUTER JOIN [dbo].[dim_date] dd_act ON ntb.actual_buy_acceptance_dt = dd_act.full_date
	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		ntb.lum_qty IS NOT NULL
    GROUP BY
		ISNULL(customer_po_code, 'UNDEFINED'),
		dd_xfac.id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
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
