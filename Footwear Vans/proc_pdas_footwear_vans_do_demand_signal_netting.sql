USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to consume NTB with NGC orders.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_demand_signal_netting]
	@pdasid INT,
	@businessid INT,
	@buying_program_id INT
AS
BEGIN

	/* Variable declaration */
	-- Placeholder
	DECLARE @demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
	DECLARE @dim_customer_id_placeholder_nora int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'NORA')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')

	-- Temp tables
	IF OBJECT_ID('tempdb..#temp_forecast') IS NOT NULL
		DROP TABLE #temp_forecast

	/* Initiation */

	-- Reset fact_demand_total
	UPDATE f
	SET
		[quantity] = [quantity_unconsumed]
		,[consumed_quantity] = 0
	FROM
		[dbo].[fact_demand_total] f
	WHERE
		dim_pdas_id = @pdasid and
		dim_business_id = @businessid;


	/* Netting */




	IF OBJECT_ID('tempdb..#temp_order_ngc') IS NOT NULL
		DROP TABLE #temp_order_ngc


	-- Create temporary tables
	CREATE TABLE #temp_order_ngc (
		,[dim_product_id] INT
		,[dim_date_id] INT
		,[dim_customer_id] INT
		,[order_number] NVARCHAR(45)
		,[quantity] INT
	)
	INSERT INTO #temp_order_ngc
	(
		[dim_product_id]
		,[dim_date_id]
		,[dim_customer_id]
		,[order_number]
		,[quantity]
	)
	SELECT
		[dim_product_id]
		,[dim_market_id]
		,[year_month_date_id]
		,[quantity_before_consumption]
		,[quantity_before_consumption]
	FROM
		[dbo].[fact_forecast] f
		INNER JOIN (SELECT [id] FROM [dbo].[dim_product] WHERE [line] = 'Shoes') dp
			ON f.[dim_product_id] = dp.[id]
	WHERE
		[dim_rccp_id] = @dim_rccp_id
		and [dim_demand_category_id] = @dim_category_id_forecast
	CREATE INDEX idx_temp_forecast ON #temp_forecast([dim_product_id],[dim_market_id],[year_month_date_id])




	-- Update fact forecast with temporary values
	UPDATE ff
	SET
		ff.[quantity_after_consumption] = tf.[remaining_quantity]
		,ff.[was_consumed] = CASE WHEN ff.[quantity_before_consumption] <> tf.[remaining_quantity] THEN 1 ELSE 0 END
		,ff.[consumed_quantity] = ff.[quantity_before_consumption] - tf.[remaining_quantity]
	FROM
		(
			SELECT *
			FROM
				[dbo].[fact_forecast] f
				INNER JOIN (SELECT [id] FROM [dbo].[dim_product] WHERE [line] = 'Shoes') dp
					ON f.[dim_product_id] = dp.[id]
		) ff
		INNER JOIN #temp_forecast tf
			ON
				ff.[dim_product_id] = tf.[dim_product_id]
				and ff.[dim_market_id] = tf.[dim_market_id]
				and ff.[year_month_date_id] = tf.[year_month_date_id]
	WHERE
		[dim_rccp_id] = @dim_rccp_id


	IF (@mc_user_name IS NOT NULL)
	BEGIN
		INSERT INTO mc_user_log (	mc_user_name,	message)
		VALUES					(	@mc_user_name,	'Forecast consumption completed successfully.')
	END

END
