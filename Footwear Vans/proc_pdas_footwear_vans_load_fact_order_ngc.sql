USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the NGC orders in fact_order.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb]
	@pdasid INT,
	@businessid INT
AS
BEGIN

	-- Placeholder
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
    DECLARE	@buying_program_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'NGC')
    DECLARE	@dim_demand_category_id int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Order')

	-- Check if the session has already been loaded
	DELETE FROM [dbo].[fact_order]
    WHERE
        dim_pdas_id = @pdasid
        AND dim_demand_category_id = @dim_demand_category_id
        AND buying_program_id = @buying_program_id

	-- Insert from staginG
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
        @pdasid as dim_pdas_id,
        @businessid as dim_business_id,
        @buying_program_id as dim_buying_program_id,
        ISNULL(po_code, ''UNDEFINED'') as order_number,
        dd_req.id as dim_date_id,
        df.id as dim_factory_id,
        dc.id as dim_customer_id,
        dp.id as dim_product_id,
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
	FROM ' + @staging_table_name_nora + ' ntb
	INNER JOIN [dbo].[dim_business] biz ON biz.id = ' + CONVERT(NVARCHAR(10), @businessid) + '
	INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = ' + CONVERT(NVARCHAR(10), @buying_program_id) + '
    INNER JOIN [dbo].[dim_demand_category] ddc ON ddc.name = ''Need to Buy''
	INNER JOIN [dbo].[dim_product] dp ON ntb.dim_product_material_id = dp.material_id and ntb.dim_product_size = dp.size
 	INNER JOIN [dbo].[dim_factory] df ON ntb.dim_factory_short_name = df.short_name
	INNER JOIN [dbo].[dim_customer] dc ON dc.is_placeholder = 1 AND dc.placeholder_level = ''Region'' AND market = ''NORA''
    LEFT OUTER JOIN [dbo].[dim_date] dd_req ON ntb.req_dt = dd_req.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_xfac ON ntb.xfac_dt = dd_xfac.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_eta ON ntb.delivered_dt = dd_eta.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_rel ON ntb.sr_sent_dt = dd_rel.full_date
    LEFT OUTER JOIN [dbo].[dim_date] dd_act ON ntb.actual_buy_acceptance_dt = dd_act.full_date
	WHERE dp.is_placeholder = 0
    GROUP BY
        ISNULL(customer_po_code, ''UNDEFINED''),
        dd_req.id,
        df.id,
        dc.id,
        dp.id,
        ddc.id

END
