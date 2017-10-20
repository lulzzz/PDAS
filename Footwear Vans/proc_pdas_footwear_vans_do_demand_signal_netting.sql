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
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN

	/* Variable declaration */
	-- Placeholder
	DECLARE @dim_demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')
	DECLARE	@dim_demand_category_id_open_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Open Order')
	DECLARE	@dim_demand_category_id_shipped_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Shipped Order')
	DECLARE	@dim_demand_category_id_received_order int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Received Order')
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')

	/* Temp table creation */

	-- Drop temp table if exist
	IF OBJECT_ID('tempdb..#temp_order_ngc') IS NOT NULL
		DROP TABLE #temp_order_ngc

	-- Create temporary tables
	CREATE TABLE #temp_order_ngc (
		[dim_product_id] INT
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
		,[dim_date_id]
		,[dim_customer_id]
		,[order_number]
		,SUM([quantity]) AS [quantity]
	FROM [dbo].[fact_demand_total]
	WHERE
		[dim_pdas_id] = @pdasid and
		[dim_business_id] = @businessid and
		[dim_demand_category_id] IN
		(
			@dim_demand_category_id_open_order,
			@dim_demand_category_id_received_order,
			@dim_demand_category_id_shipped_order
		)
	GROUP BY
		[dim_product_id]
		,[dim_date_id]
		,[dim_customer_id]
		,[order_number]
	CREATE INDEX idx_temp_order_ngc ON #temp_order_ngc (
		[dim_product_id]
		,[dim_date_id]
		,[dim_customer_id]
		,[order_number]
	)


	/* Netting */

	UPDATE f
	SET
		f.[quantity] = CASE
			WHEN f.[quantity_unconsumed] - t.[quantity] < 0 THEN 0
			ELSE f.[quantity_unconsumed] - t.[quantity]
		END
		,f.[consumed_quantity] = ABS(t.[quantity] - f.[quantity_unconsumed])
	FROM
	(
		SELECT *
		FROM [dbo].[fact_demand_total]
		WHERE
			[dim_pdas_id] = @pdasid and
			[dim_business_id] = @businessid and
			[dim_demand_category_id] = @dim_demand_category_id_ntb
	) AS f
	INNER JOIN #temp_order_ngc t
	ON
		f.[dim_product_id] = t.[dim_product_id] and
		f.[dim_date_id] = t.[dim_date_id] and
		f.[dim_customer_id] = t.[dim_customer_id] and
		f.[order_number] = t.[order_number]


	-- Message to be displayed in the Console
	IF (@mc_user_name IS NOT NULL)
	BEGIN
		INSERT INTO mc_user_log (	mc_user_name,	message)
		VALUES					(	@mc_user_name,	'NTB consumed with NGB orders successfully.')
	END

END
