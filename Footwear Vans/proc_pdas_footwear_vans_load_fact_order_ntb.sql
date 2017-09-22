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
	@buying_program_id INT,
	@buying_program_ref NVARCHAR(100) = NULL
AS
BEGIN

	-- Placeholder
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')

	-- Converted values
	DECLARE @pdasid_nvarchar NVARCHAR(10) = @pdasid
	DECLARE @businessid_nvarchar NVARCHAR(10) = @businessid
	DECLARE @buying_program_id_nvarchar NVARCHAR(10) = @buying_program_id

	-- Check if the session has already been loaded
	DELETE FROM [dbo].[fact_order]
    WHERE dim_pdas_id = @pdasid
    AND dim_buying_program_id = @buying_program_id
    AND dim_demand_category_id = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy');


	-- Insert from staging
	EXEC('
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
	-- NORA
	SELECT
		' + @pdasid_nvarchar + ' as dim_pdas_id,
        ' + @businessid_nvarchar + ' as dim_business_id,
        ' + @buying_program_id_nvarchar + ' as dim_buying_program_id,
        ISNULL(customer_po_code, ''UNDEFINED'') as order_number,
        dd_req.id as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END as dim_factory_id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE mapping_c.id
		END as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        ddc.id as dim_demand_category_id,
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
	FROM [dbo].[staging_pdas_footwear_vans_nora_ntb_' + @buying_program_ref + '] ntb
	INNER JOIN [dbo].[dim_business] biz ON biz.id = ' + @businessid_nvarchar + '
	INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = ' + @buying_program_id_nvarchar + '
    INNER JOIN [dbo].[dim_demand_category] ddc ON ddc.name = ''Need to Buy''
	LEFT OUTER JOIN
	(
		SELECT [id], [material_id]
		FROM [dbo].[dim_product]
		WHERE
			[is_placeholder] = 1 AND
			[placeholder_level] = ''material_id''
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
			INNER JOIN (SELECT id, name FROM [dbo].[dim_customer]) df
				ON m.parent = df.name
		WHERE type = ''Customer Master''
	) mapping_c ON ntb.dc_name = mapping_c.child
	INNER JOIN [dbo].[dim_customer] dc ON dc.is_placeholder = 1 AND dc.placeholder_level = ''Region'' AND market = ''NORA''
    LEFT OUTER JOIN [dbo].[dim_date] dd_req ON ntb.req_dt = dd_req.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_eta ON ntb.delivered_dt = dd_eta.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_rel ON ntb.sr_sent_dt = dd_rel.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_act ON ntb.actual_buy_acceptance_dt = dd_act.full_date
	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		(df.id IS NOT NULL OR mapping_f.id IS NOT NULL)
    GROUP BY
        ISNULL(customer_po_code, ''UNDEFINED''),
        dd_req.id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END,
		dc.id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END,
        ddc.id
    UNION
        -- CASA
	SELECT
		' + @pdasid_nvarchar + ' as dim_pdas_id,
		' + @businessid_nvarchar + ' as dim_business_id,
		' + @buying_program_id_nvarchar + ' as dim_buying_program_id,
        ISNULL(pr_code, ''UNDEFINED'') as order_number,
        dd_xfac.id as dim_date_id,
        fpl.dim_factory_id_1 as dim_factory_id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE mapping_c.id
		END as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        ddc.id as dim_demand_category_id,
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
	FROM [dbo].[staging_pdas_footwear_vans_casa_ntb_' + @buying_program_ref + '] ntb
	INNER JOIN [dbo].[dim_business] biz ON biz.id = ' + @businessid_nvarchar + '
	INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = ' + @buying_program_id_nvarchar + '
    INNER JOIN [dbo].[dim_demand_category] ddc ON ddc.name = ''Need to Buy''
	LEFT OUTER JOIN
	(
		SELECT [id], [material_id]
		FROM [dbo].[dim_product]
		WHERE
			[is_placeholder] = 1 AND
			[placeholder_level] = ''material_id''
	) AS dp_m
		ON ntb.dim_product_style_id = dp_m.material_id
	LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
		ON 	ntb.dim_product_material_id = dp_ms.material_id AND
			ntb.dim_product_size = dp_ms.size
	LEFT OUTER JOIN [dbo].[dim_customer] dc ON ntb.dim_customer_name = dc.name
	LEFT OUTER JOIN
	(
		SELECT df.id, m.child
		FROM
			[dbo].[helper_pdas_footwear_vans_mapping] m
			INNER JOIN (SELECT id, name FROM [dbo].[dim_customer]) df
				ON m.parent = df.name
		WHERE type = ''Customer Master''
	) mapping_c ON ntb.dim_customer_name = mapping_c.child
	INNER JOIN [dbo].[fact_priority_list] fpl ON fpl.dim_pdas_id = ' + @pdasid_nvarchar + '
                                              AND dp.id = fpl.dim_product_id
    INNER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
	WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		(dc.id IS NOT NULL OR mapping_c.id IS NOT NULL)
    GROUP BY
        ISNULL(pr_code, ''UNDEFINED''),
        dd_xfac.id,
        fpl.dim_factory_id_1,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE mapping_c.id
		END,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END,
        ddc.id
	UNION
	-- EMEA
    SELECT
		' + @pdasid_nvarchar + ' as dim_pdas_id,
		' + @businessid_nvarchar + ' as dim_business_id,
		' + @buying_program_id_nvarchar + ' as dim_buying_program_id,
        ISNULL(pr_code, ''UNDEFINED'') as order_number,
        dd_req.id as dim_date_id,
        COALESCE(fpl.dim_factory_id_1, ' + @dim_factory_id_placeholder + ') as dim_factory_id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE mapping_c.id
		END as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        ddc.id as dim_demand_category_id,
        NULL as placed_date_id,
        MAX(dd_req.id) as customer_requested_xf_date_id,
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
    FROM [dbo].[staging_pdas_footwear_vans_emea_ntb_' + @buying_program_ref + '] ntb
    INNER JOIN [dbo].[dim_business] biz ON biz.id = ' + @businessid_nvarchar + '
    INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = ' + @buying_program_id_nvarchar + '
    INNER JOIN [dbo].[dim_demand_category] ddc ON ddc.name = ''Need to Buy''
	LEFT OUTER JOIN
	(
		SELECT [id], [material_id]
		FROM [dbo].[dim_product]
		WHERE
			[is_placeholder] = 1 AND
			[placeholder_level] = ''material_id''
	) AS dp_m
		ON ntb.dim_product_style_id = dp_m.material_id
	LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
		ON 	ntb.dim_product_material_id = dp_ms.material_id AND
			ntb.dim_product_size = dp_ms.size
	LEFT OUTER JOIN [dbo].[dim_customer] dc ON ntb.dim_customer_name = dc.name
	LEFT OUTER JOIN
	(
		SELECT df.id, m.child
		FROM
			[dbo].[helper_pdas_footwear_vans_mapping] m
			INNER JOIN (SELECT id, name FROM [dbo].[dim_customer]) df
				ON m.parent = df.name
		WHERE type = ''Customer Master''
	) mapping_c ON ntb.dim_customer_name = mapping_c.child
	INNER JOIN [dbo].[fact_priority_list] fpl ON fpl.dim_pdas_id = ' + @pdasid_nvarchar + '
                                              AND dp.id = fpl.dim_product_id
    INNER JOIN [dbo].[dim_date] dd_buy ON ntb.buy_dt = dd_buy.full_date
    INNER JOIN [dbo].[helper_pdas_footwear_vans_cutoff] vc ON ntb.dim_location_country = vc.[Country]
                                                           AND dd_buy.season_year_short_accounting = vc.[Season Year]
    INNER JOIN [dbo].[dim_date] dd_req ON dd_req.year_accounting = dd_buy.year_accounting
                                       AND SUBSTRING(ntb.exp_delivery_with_constraint_dt, 3, 2) = SUBSTRING(dd_req.year_cw_accounting, 7, 2)
                                       AND vc.[Cutoff Weekday] = dd_req.day_name_of_week
    WHERE dp.is_placeholder = 0
    GROUP BY
        ISNULL(pr_code, ''UNDEFINED''),
        dd_req.id,
        COALESCE(fpl.dim_factory_id_1, ' + @dim_factory_id_placeholder + '),
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE mapping_c.id
		END,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END,
        ddc.id,
        dd_req.id
	UNION
	-- APAC
    SELECT
		' + @pdasid_nvarchar + ' as dim_pdas_id,
		' + @businessid_nvarchar + ' as dim_business_id,
		' + @buying_program_id_nvarchar + ' as dim_buying_program_id,
        ISNULL(pr_code, ''UNDEFINED'') as order_number,
        dd_xfac.id as dim_date_id,
		CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END as dim_factory_id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE mapping_c.id
		END as dim_customer_id,
		CASE
			WHEN dp_ms.id IS NOT NULL THEN dp_ms.id
			ELSE dp_m.id
		END as dim_product_id,
        ddc.id as dim_demand_category_id,
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
		[dbo].[staging_pdas_footwear_vans_apac_ntb_' + @buying_program_ref + '] ntb
	    INNER JOIN [dbo].[dim_business] biz ON biz.id = ' + @businessid_nvarchar + '
	    INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = ' + @buying_program_id_nvarchar + '
	    INNER JOIN [dbo].[dim_demand_category] ddc ON ddc.name = ''Need to Buy''
	    INNER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
		LEFT OUTER JOIN
		(
			SELECT [id], [material_id]
			FROM [dbo].[dim_product]
			WHERE
				[is_placeholder] = 1 AND
				[placeholder_level] = ''material_id''
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
			WHERE type = ''Factory Master''
		) mapping_f ON ntb.dim_factory_reva_vendor = mapping_f.child
		LEFT OUTER JOIN [dbo].[dim_customer] dc ON ntb.dim_customer_name = dc.name
		LEFT OUTER JOIN
		(
			SELECT df.id, m.child
			FROM
				[dbo].[helper_pdas_footwear_vans_mapping] m
				INNER JOIN (SELECT id, name FROM [dbo].[dim_customer]) df
					ON m.parent = df.name
			WHERE type = ''Customer Master''
		) mapping_c ON ntb.dim_customer_name = mapping_c.child
    WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		(df.id IS NOT NULL OR mapping_f.id IS NOT NULL) AND
		(dc.id IS NOT NULL OR mapping_c.id IS NOT NULL)
    GROUP BY
        ISNULL(pr_code, ''UNDEFINED''),
        dd_xfac.id,
        df.id,
        dc.id,
        dp.id,
        ddc.id
    ;
	')

END
