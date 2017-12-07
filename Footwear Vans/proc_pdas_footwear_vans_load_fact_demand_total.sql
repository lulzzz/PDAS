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

	-- Release full dim_date_id
	DECLARE @pdas_release_full_date_id int
	SET @pdas_release_full_date_id = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)
	DECLARE @pdas_release_full_d date = (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = @pdas_release_full_date_id)

	-- Check if the session has already been loaded
	IF EXISTS (SELECT 1 FROM [dbo].[fact_demand_total] WHERE dim_pdas_id = @pdasid and dim_business_id = @businessid)
	BEGIN
		DELETE FROM [dbo].[fact_demand_total] WHERE dim_pdas_id = @pdasid and dim_business_id = @businessid;
	END

	-- Insert from other facts
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
    )
	-- fact_order
	SELECT
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
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
	FROM
		[dbo].[fact_order] f
		INNER JOIN [dbo].[dim_date] dd
			ON f.[dim_date_id] = dd.[id]
	WHERE
		[dim_pdas_id] = @pdasid
		AND [dim_business_id] = @businessid


	-- fact_forecast
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
    )
	SELECT
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_factory_id] AS [dim_factory_id_original_unconstrained]
		,[dim_factory_id] AS [dim_factory_id_original_constrained]
		,[dim_factory_id] AS [dim_factory_id_final]
        ,[dim_factory_id]
		,[dim_customer_id]
		,@dim_demand_category_id_forecast AS [dim_demand_category_id]
		,'UNDEFINED' AS [order_number]
		,0 AS [is_asap]
		,[quantity] AS [quantity_lum]
		,[quantity] AS [quantity_non_lum]
		,[quantity] AS [quantity_unconsumed]
		,[quantity]
	FROM [dbo].[fact_forecast]
	WHERE
		[dim_pdas_id] = @pdasid
		AND [dim_business_id] = @businessid


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
