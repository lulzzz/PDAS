USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to consume NTB with NGC orders.
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


	/* Variable definition */
	-- DECLARE @dim_rccp_id_param int
	DECLARE @dim_rccp_id int = @dim_rccp_id_param
	IF(@dim_rccp_id IS NULL)
		SELECT @dim_rccp_id = MAX(id) FROM dbo.dim_rccp

	DECLARE @dim_category_id_forecast int
	SET @dim_category_id_forecast = (SELECT id FROM dbo.dim_demand_category WHERE name = 'FORECAST')
	DECLARE @year_month_min_forecast_date_id int
	SET @year_month_min_forecast_date_id =
	(
		SELECT MIN([year_month_date_id])
		FROM [dbo].[fact_forecast]
		WHERE
			[dim_rccp_id] = @dim_rccp_id
			and [dim_demand_category_id] = @dim_category_id_forecast
	)
	DECLARE @textfield VARCHAR(500)
	SET @textfield = (SELECT TOP 1 [value] FROM [dbo].[helper_configuration] WHERE [system] = 'rccp_footwear' and [variable] = 'Forecast Consumption Sequence')
	DECLARE @consumption_month_logic int

	DECLARE @staging_area_cusor CURSOR


	/* Initiation */

	-- Reset forecast table
	UPDATE f
	SET
		[quantity_after_consumption] = [quantity_before_consumption]
		,[was_consumed] = 0
		,[consumed_quantity] = 0
	FROM
		[dbo].[fact_forecast] f
		INNER JOIN (SELECT [id] FROM [dbo].[dim_product] WHERE [line] = 'Shoes') dp
			ON f.[dim_product_id] = dp.[id]
	WHERE
		dim_rccp_id = @dim_rccp_id

	-- Drop temporary tables
	IF OBJECT_ID('tempdb..#forecast_consumption_sequence') IS NOT NULL
		DROP TABLE #forecast_consumption_sequence
	IF OBJECT_ID('tempdb..#temp_forecast') IS NOT NULL
		DROP TABLE #temp_forecast
	IF OBJECT_ID('tempdb..#temp_order') IS NOT NULL
		DROP TABLE #temp_order

	-- Get parameter temporary table
	;WITH tmp(data_item, data) as (
	SELECT CONVERT(VARCHAR(500),LEFT(REPLACE(@textfield,' ',''), CHARINDEX(';',REPLACE(@textfield,' ','')+';')-1)),
		STUFF(REPLACE(@textfield,' ',''), 1, CHARINDEX(';',REPLACE(@textfield,' ','')+';'), '')
	UNION all
	SELECT CONVERT(VARCHAR(500),LEFT(data, CHARINDEX(';',data+';')-1)),
		STUFF(data, 1, CHARINDEX(';',data+';'), '')
	FROM tmp
	WHERE data > ''
	)
	SELECT
		IDENTITY(INT,1,1) as sequence,
		CAST(data_item AS INT) as month
	INTO #forecast_consumption_sequence
	FROM tmp

	-- Create temporary tables
	CREATE TABLE #temp_forecast (
		[dim_product_id] INT
		,[dim_market_id] INT
		,[year_month_date_id] INT
		,[initial_quantity] INT
		,[remaining_quantity] INT
	)
	INSERT INTO #temp_forecast
	(
		[dim_product_id]
		,[dim_market_id]
		,[year_month_date_id]
		,[initial_quantity]
		,[remaining_quantity]
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

	CREATE TABLE #temp_order (
		[dim_product_id] INT
		,[dim_market_id] INT
		,[year_month_date_id] INT
		,[initial_quantity] INT
		,[remaining_quantity] INT
	)
	INSERT INTO #temp_order
	(
		[dim_product_id]
		,[dim_market_id]
		,[year_month_date_id]
		,[initial_quantity]
		,[remaining_quantity]
	)
	SELECT
		[dim_product_id]
		,[dim_market_id]
		,[nb_accounting_expected_xf_year_month_date_id]
		,SUM([quantity]) as [initial_quantity]
		,SUM([quantity]) as [remaining_quantity]
	FROM
		[dbo].[fact_order] f
		INNER JOIN (SELECT [id] FROM [dbo].[dim_product] WHERE [line] = 'Shoes') dp
			ON f.[dim_product_id] = dp.[id]
		INNER JOIN -- INTL orders only
		(
			SELECT dm.[id] as [id]
			FROM
				[dbo].[dim_market] dm
				INNER JOIN (SELECT [id] FROM [dbo].[dim_location] WHERE [category] <> 'NORTH AMERICA') dl
					ON dm.[dim_location_id] = dl.[id]
		) dm
			ON f.[dim_market_id] = dm.[id]
	WHERE
		[dim_rccp_id] = @dim_rccp_id
		and [nb_accounting_expected_xf_year_month_date_id] >= @year_month_min_forecast_date_id
	GROUP BY
		[dim_product_id]
		,[dim_market_id]
		,[nb_accounting_expected_xf_year_month_date_id]
	CREATE INDEX idx_temp_order ON #temp_order([dim_product_id],[dim_market_id],[year_month_date_id])


	/* Consume forecast */

	SET @staging_area_cusor = CURSOR FAST_FORWARD FOR
	SELECT
		[month]
	FROM
		#forecast_consumption_sequence
	ORDER BY
		[sequence]

	OPEN @staging_area_cusor
	FETCH NEXT FROM @staging_area_cusor
	INTO @consumption_month_logic
	WHILE @@FETCH_STATUS = 0
	BEGIN

		-- Reduction of forecast volume in fact_forecast
		UPDATE t1
		SET
			t1.[remaining_quantity] =
				CASE
					WHEN t1.[initial_quantity] - t2.[initial_quantity] > 0 THEN t1.[initial_quantity] - t2.[initial_quantity]
					ELSE 0
				END
		FROM
			(
				SELECT
					[dim_product_id]
					,[dim_market_id]
					,[year_month_date_id]
					,[initial_quantity]
					,[remaining_quantity]
				FROM
					#temp_forecast
			) t1 -- Source
			INNER JOIN
			(
				SELECT
					[dim_product_id]
					,[dim_market_id]
					,dd2.[id] as [year_month_date_id] -- use consumption month from helper_configuration
					,[initial_quantity]
					,[remaining_quantity]
				FROM
					#temp_order t
					INNER JOIN (SELECT [id], DATEADD(MONTH, DATEDIFF(MONTH, 0, [full_date]) + @consumption_month_logic, 0) as [full_date_with_shift] FROM [dbo].[dim_date]) dd1
						ON t.[year_month_date_id] = dd1.[id]
					INNER JOIN (SELECT [id], [full_date] FROM [dbo].[dim_date]) dd2
						ON dd1.[full_date_with_shift] = dd2.[full_date]
			) t2 -- Target
				ON
					t1.[dim_product_id] = t2.[dim_product_id]
					and t1.[dim_market_id] = t2.[dim_market_id]
					and t1.[year_month_date_id] = t2.[year_month_date_id]

		-- Reduction of order volume in #temp_order
		UPDATE t1
		SET
			t1.[remaining_quantity] =
				CASE
					WHEN t1.[initial_quantity] - t2.[initial_quantity] > 0 THEN t1.[initial_quantity] - t2.[initial_quantity]
					ELSE 0
				END
		FROM
			(
				SELECT
					[dim_product_id]
					,[dim_market_id]
					,[year_month_date_id]
					,[initial_quantity]
					,[remaining_quantity]
				FROM
					#temp_forecast
			) t2 -- Target
			INNER JOIN
			(
				SELECT
					[dim_product_id]
					,[dim_market_id]
					,dd2.[id] as [year_month_date_id] -- use consumption month from helper_configuration
					,[initial_quantity]
					,[remaining_quantity]
				FROM
					#temp_order t
					INNER JOIN (SELECT [id], DATEADD(MONTH, DATEDIFF(MONTH, 0, [full_date]) + @consumption_month_logic, 0) as [full_date_with_shift] FROM [dbo].[dim_date]) dd1
						ON t.[year_month_date_id] = dd1.[id]
					INNER JOIN (SELECT [id], [full_date] FROM [dbo].[dim_date]) dd2
						ON dd1.[full_date_with_shift] = dd2.[full_date]
			) t1 -- Source
				ON
					t1.[dim_product_id] = t2.[dim_product_id]
					and t1.[dim_market_id] = t2.[dim_market_id]
					and t1.[year_month_date_id] = t2.[year_month_date_id]

			-- Overwrite initial quantity with remaining quantity to get new initial quantity for next round
			UPDATE #temp_forecast
			SET [initial_quantity] = [remaining_quantity]
			UPDATE #temp_order
			SET [initial_quantity] = [remaining_quantity]

		FETCH NEXT FROM @staging_area_cusor
		INTO @consumption_month_logic
	END
	CLOSE @staging_area_cusor
	DEALLOCATE @staging_area_cusor

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
