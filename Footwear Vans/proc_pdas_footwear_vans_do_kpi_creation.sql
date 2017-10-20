USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Creation of report tables for Dashboard frontend
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
	@pdasid INT,
	@businessid INT
AS
BEGIN
	SET NOCOUNT ON;

    /* Variable declaration */

    DECLARE @sql NVARCHAR(MAX);
	DECLARE @cols NVARCHAR(MAX);
	DECLARE @diff_calc NVARCHAR(MAX);
	DECLARE @cols_isnull NVARCHAR(MAX);
	DECLARE @dim_rccp_name NVARCHAR(45)
	DECLARE @dim_rccp_etl_date_id int = (SELECT [etl_date_id] FROM dbo.dim_rccp WHERE [id] = @dim_rccp_id)

	DECLARE @accounting_month nvarchar(7)
	DECLARE @factory_short_name nvarchar(100)
	DECLARE @demand int
	DECLARE @discrepancy int
	DECLARE @fill_rate float
	DECLARE @penalty_points int
	DECLARE @staging_area_cusor CURSOR

	DECLARE @horizon_name NVARCHAR(30)
	DECLARE @horizon_start_date_id int
	DECLARE @horizon_end_date_id int
	DECLARE @horizon_cursor CURSOR


	/* Initiation */

    -- Demand vs capacity table
    IF OBJECT_ID('#helper_demand_vs_capacity', 'U') IS NOT NULL
    BEGIN
        DROP TABLE #helper_demand_vs_capacity
    END

    CREATE TABLE #helper_demand_vs_capacity(
        [year_month_date_id] [int] NOT NULL,
        [Accounting Month] [nvarchar](7) NOT NULL,
        [Factory Short Name] [nvarchar](100) NOT NULL,
        [Total Demand] [int] DEFAULT 0,
        [Total Capacity] [int] DEFAULT 0,
        [Discrepancy] [int] DEFAULT 0,
        [Fill Rate] [float] DEFAULT 0
    ) ON [PRIMARY]

	INSERT INTO #helper_demand_vs_capacity
	(
		[year_month_date_id]
		,[Accounting Month]
		,[Factory Short Name]
		,[Total Demand]
	)
	SELECT
		[dim_date_id]
		,[Accounting Month]
		,[short_name]
		,SUM([quantity])
	FROM
		[dbo].[view_rccp_footwear_demand_total] f
		INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
			ON f.[dim_factory_alternative_id] = df.[id]
		INNER JOIN (SELECT [id], [year_month_name] FROM [dbo].[dim_date]) dd
			ON f.[year_month_date_id] = dd.[id]
	GROUP BY
		[year_month_date_id]
		,[year_month_name]
		,[short_name]

	UPDATE t1
	SET
		t1.[Total Capacity] = t2.[Total Capacity]
	FROM
		#helper_demand_vs_capacity  t1
		INNER JOIN
		(
			SELECT
				[year_month_name]
				,[short_name]
				,SUM([net_capacity_units]) as [Total Capacity]
			FROM
				[dbo].[view_rccp_footwear_factory_capacity] f
				INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
					ON f.[dim_factory_id] = df.[id]
				INNER JOIN (SELECT [id], [year_month_name] FROM [dbo].[dim_date]) dd
					ON f.[year_month_date_id] = dd.[id]
			GROUP BY
				[year_month_name]
				,[short_name]
		) t2
			ON
				t1.[Accounting Month] = t2.[year_month_name]
				and t1.[Factory Short Name] = t2.[short_name]

	UPDATE #helper_demand_vs_capacity
	SET
		[Discrepancy] = [Total Capacity] - [Total Demand],
		[Fill Rate] = CONVERT(float, CONVERT(float, [Total Demand])/CONVERT(float, [Total Capacity]))
	WHERE
		[Total Capacity] > 0

	-- Horizon table
	IF OBJECT_ID('#helper_horizon', 'U') IS NOT NULL
	BEGIN
		DROP TABLE #helper_horizon
	END

	CREATE TABLE #helper_horizon(
		[id] [int] NOT NULL,
		[name] [nvarchar](30) NOT NULL,
		[start_date_id] [int] NOT NULL,
		[end_date_id] [int] NOT NULL
	) ON [PRIMARY]

	INSERT INTO #helper_horizon
	(
		[id]
		,[name]
		,[start_date_id]
		,[end_date_id]
	)
	VALUES
	(
		1
		,'Month 1 to 3 (Firm)'
		,(SELECT id FROM dim_date WHERE full_date = DATEADD(MONTH, DATEDIFF(MONTH, 0, (SELECT full_date FROM dim_date WHERE id = @dim_rccp_etl_date_id)), 0))
		,(SELECT id FROM dim_date WHERE full_date = DATEADD(MONTH, DATEDIFF(MONTH, 0, (SELECT full_date FROM dim_date WHERE id = @dim_rccp_etl_date_id)) + 2, 0))
	),
	(
		2
		,'Month 4 to 6 (Slush)'
		,(SELECT id FROM dim_date WHERE full_date = DATEADD(MONTH, DATEDIFF(MONTH, 0, (SELECT full_date FROM dim_date WHERE id = @dim_rccp_etl_date_id)) + 3, 0))
		,(SELECT id FROM dim_date WHERE full_date = DATEADD(MONTH, DATEDIFF(MONTH, 0, (SELECT full_date FROM dim_date WHERE id = @dim_rccp_etl_date_id)) + 5, 0))
	),
	(
		3
		,'Month 7 onwards (Liquid)'
		,(SELECT id FROM dim_date WHERE full_date = DATEADD(MONTH, DATEDIFF(MONTH, 0, (SELECT full_date FROM dim_date WHERE id = @dim_rccp_etl_date_id)) + 6, 0))
		,(SELECT MAX([year_month_date_id]) FROM [dbo].[fact_factory_capacity] WHERE dim_rccp_id = @dim_rccp_id)
	)


    /***********************/
	/* Horizon Non-Related */
	/***********************/

	/*
	 *	KPI - Factories that give away/receive the biggest volume in the multi-sourcing scenario
	 */

	DELETE FROM [dbo].[report_rccp_footwear_alternative_factory_volume]

	-- Give away
	INSERT INTO [dbo].[report_rccp_footwear_alternative_factory_volume]
	(
		[Factory Short Name]
		,[Quantity]
		,[Report Type]
		,[Ranking]
	)
	SELECT TOP 10
		df.[short_name] as [Factory Short Name]
		, SUM([quantity]) as [Quantity]
		, 'Going-Out' as [Report Type]
		, DENSE_RANK() OVER (ORDER BY SUM([quantity]) DESC) as [Ranking]
	FROM
		(
			SELECT *
			FROM
				[dbo].[view_rccp_footwear_demand_total]
			WHERE
				[dim_scenario_id] = 1
		and [is_alternative_factory] = 1
		) f
		INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
			ON f.[dim_factory_id] = df.[id]
	GROUP BY
		df.[short_name]

	-- Coming in
	INSERT INTO [dbo].[report_rccp_footwear_alternative_factory_volume]
	(
		[Factory Short Name]
		,[Quantity]
		,[Report Type]
		,[Ranking]
	)
	SELECT TOP 10
		df.[short_name] as [Factory Short Name]
		, SUM([quantity]) as [Quantity]
		, 'Coming-In' as [Report Type]
		, DENSE_RANK() OVER (ORDER BY SUM([quantity]) DESC) as [Ranking]
	FROM
		(
			SELECT *
			FROM
				[dbo].[view_rccp_footwear_demand_total]
			WHERE
				[dim_scenario_id] = 1
		and [is_alternative_factory] = 1
		) f
		INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
			ON f.[dim_factory_alternative_id] = df.[id]
	GROUP BY
		df.[short_name]

	--select * from [report_rccp_footwear_alternative_factory_volume]


	/*
	 *	KPI - Factories with the biggest average discrepancy between the capacity of the current RCCP and the last RCCP
	 */

	DELETE FROM [dbo].[report_rccp_footwear_factory_capacity_change]

	INSERT INTO [dbo].[report_rccp_footwear_factory_capacity_change]
	(
		[Factory Short Name]
		,[Average Discrepancy]
		,[Max Discrepancy]
		,[Report Type]
		,[Ranking]
	)
	SELECT TOP 5
		[short_name]
		,AVG([discrepancy]) as [Average Discrepancy]
		,MAX([discrepancy]) as [Max Discrepancy]
		,'TOP' as [Report Type]
		,DENSE_RANK() OVER (ORDER BY AVG([discrepancy]) DESC) AS Ranking
	FROM
	(
	SELECT -- Get result by month
		[year_month_name]
		,[short_name]
		,MAX(sum_capacity) - MIN(sum_capacity) as [discrepancy]
		FROM
		(
			SELECT -- Get around the location category
				dd.[year_month_name]
				,df.[short_name]
				,[dim_rccp_id]
				,SUM([net_capacity_units]) as sum_capacity
			FROM
				[dbo].[fact_factory_capacity] f
				INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
					ON f.[dim_factory_id] = df.[id]
				INNER JOIN (SELECT [id], [year_month_name] FROM [dbo].[dim_date]) dd
					ON f.[year_month_date_id] = dd.[id]
			WHERE
				[year_month_date_id] >= (SELECT MAX([etl_date_id]) FROM [dbo].[dim_rccp])
				and [dim_rccp_id] IN (SELECT TOP 2 [id] FROM [dbo].[dim_rccp] ORDER BY [id] DESC)
			GROUP BY
				dd.[year_month_name]
				,df.[short_name]
				,[dim_rccp_id]
		) t1
		GROUP BY
		[year_month_name]
		,[short_name]
	) t2
	GROUP BY
		[short_name]

	--select * from [report_rccp_footwear_factory_capacity_change]


	/***********************/
	/* Horizon Related     */
	/***********************/

	/*
	 *	KPI - Most over-/under-loaded factories for multi-sourcing ONLY (based on fill rate, not absolute number)
	 */

	DELETE FROM dbo.report_factory_loading_performance

	SET @horizon_cursor = CURSOR FAST_FORWARD FOR
	SELECT [name], [start_date_id], [end_date_id]
	FROM #helper_horizon
	ORDER BY [id] ASC

	OPEN @horizon_cursor
	FETCH NEXT FROM @horizon_cursor
	INTO @horizon_name, @horizon_start_date_id, @horizon_end_date_id
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO [report_factory_loading_performance] (	[Horizon],			[Factory Short Name],	[Penalty Points])
		SELECT DISTINCT										@horizon_name,		[Factory Short Name],	0
		FROM
			[dbo].[report_rccp_footwear_demand_vs_capacity]
		WHERE
			[year_month_date_id] BETWEEN @horizon_start_date_id AND @horizon_end_date_id
		ORDER BY
			[Factory Short Name]

		SET @staging_area_cusor = CURSOR FAST_FORWARD FOR
		SELECT
			[Accounting Month]
			,[Factory Short Name]
			,[Fill Rate]
		FROM
			[dbo].[report_rccp_footwear_demand_vs_capacity]
		WHERE
			[year_month_date_id] BETWEEN @horizon_start_date_id AND @horizon_end_date_id
			--and [Fill Rate] IS NOT NULL
		ORDER BY
			[Accounting Month]
			,[Factory Short Name]

		-- Open the cursor
		OPEN @staging_area_cusor

		-- Fetch the first row
		FETCH NEXT FROM @staging_area_cusor
		INTO @accounting_month, @factory_short_name, @fill_rate

		-- Loop until there are no more results
		WHILE @@FETCH_STATUS = 0
		BEGIN

			IF @fill_rate IS NULL
				SET @penalty_points = 100
			ELSE
			BEGIN

				SET @penalty_points = 0

				IF (@fill_rate*100 >= 105 or @fill_rate*100 <= 90)
					SET @penalty_points = @penalty_points + 1

				IF (@fill_rate*100 >= 120 or @fill_rate*100 <= 80)
					SET @penalty_points = @penalty_points + 1

				IF (@fill_rate*100 >= 150 or @fill_rate*100 <= 50)
					SET @penalty_points = @penalty_points + 1

				IF (@fill_rate*100 >= 200 or @fill_rate*100 <= 25)
					SET @penalty_points = @penalty_points + 1

				IF (@fill_rate*100 >= 300 or @fill_rate*100 <= 15)
					SET @penalty_points = @penalty_points + 1

				IF (@fill_rate*100 >= 350 or @fill_rate*100 <= 10)
					SET @penalty_points = @penalty_points + 1

				IF (@fill_rate*100 >= 400 or @fill_rate*100 <= 5)
					SET @penalty_points = @penalty_points + 1

			END

			--print convert(varchar(20), @accounting_month)
			--print convert(varchar(20), @penalty_points)

			UPDATE [report_factory_loading_performance]
			SET [Penalty Points] = [Penalty Points] + @penalty_points
			WHERE
				[Factory Short Name] = @factory_short_name
				and [Horizon] = @horizon_name

			FETCH NEXT FROM @staging_area_cusor
			INTO @accounting_month, @factory_short_name, @fill_rate
		END

		CLOSE @staging_area_cusor
		DEALLOCATE @staging_area_cusor

		-- Ranking BOTTOM
		INSERT INTO [report_factory_loading_performance] (	[Horizon],		[Factory Short Name],	[Penalty Points],	[Ranking],															[Report Type])
		SELECT TOP 10										@horizon_name,	[Factory Short Name],	[Penalty Points],	DENSE_RANK() OVER (ORDER BY [Penalty Points] DESC) AS Ranking,		'BOTTOM'
		FROM report_factory_loading_performance
		WHERE
			[Penalty Points] > 0
			and [Horizon] = @horizon_name
			and [Ranking] IS NULL

		INSERT INTO [report_factory_loading_performance] (	[Horizon],		[Factory Short Name],	[Penalty Points],	[Ranking],															[Report Type])
		SELECT TOP 10										@horizon_name,	[Factory Short Name],	[Penalty Points],	DENSE_RANK() OVER (ORDER BY [Penalty Points] ASC) AS Ranking,		'TOP'
		FROM report_factory_loading_performance
		WHERE
			[Penalty Points] > 0
			and [Horizon] = @horizon_name
			and [Ranking] IS NULL

		DELETE FROM [report_factory_loading_performance]
		WHERE
			[Ranking] IS NULL
			and [Horizon] = @horizon_name

		FETCH NEXT FROM @horizon_cursor
		INTO @horizon_name, @horizon_start_date_id, @horizon_end_date_id
	END
	CLOSE @horizon_cursor
	DEALLOCATE @horizon_cursor

	-- select * from [report_factory_loading_performance] order by [Horizon], [Report Type], [Penalty Points], [Ranking]


	/*
	 *	KPI - Ratio of number of production demand to styles sourced
	 */

	DELETE FROM [dbo].[report_rccp_footwear_style_mix]

	SET @horizon_cursor = CURSOR FAST_FORWARD FOR
	SELECT [name], [start_date_id], [end_date_id]
	FROM #helper_horizon
	ORDER BY [id] ASC

	OPEN @horizon_cursor
	FETCH NEXT FROM @horizon_cursor
	INTO @horizon_name, @horizon_start_date_id, @horizon_end_date_id
	WHILE @@FETCH_STATUS = 0
	BEGIN

		-- Highest
		INSERT INTO [report_rccp_footwear_style_mix]
		(
			[Horizon]
			,[Report Type]
			,[Factory Short Name]
			,[Production Demand]
			,[Style Count]
			,[Ratio]
			,[Ranking]
		)
		SELECT TOP 10
			@horizon_name
			, 'TOP'
			, [short_name]
			, SUM([quantity])
			, COUNT(DISTINCT [dim_product_id])
			, SUM([quantity]) / COUNT(distinct [dim_product_id])
			, DENSE_RANK() OVER (ORDER BY SUM([quantity]) / COUNT(DISTINCT dim_product_id) DESC) AS Ranking
		FROM
			[dbo].[view_rccp_footwear_demand_total] f
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
				ON f.[dim_factory_alternative_id] = df.[id]
			INNER JOIN (SELECT [id], [year_month_name] FROM [dbo].[dim_date]) dd
				ON f.[year_month_date_id] = dd.[id]
		WHERE
			[dim_scenario_id] = 1
			and	[year_month_date_id] BETWEEN @horizon_start_date_id AND @horizon_end_date_id
		GROUP BY [short_name]

		INSERT INTO [report_rccp_footwear_style_mix]
		(
			[Horizon]
			,[Report Type]
			,[Factory Short Name]
			,[Production Demand]
			,[Style Count]
			,[Ratio]
			,[Ranking]
		)
		SELECT TOP 10
			@horizon_name
			, 'BOTTOM'
			, [short_name]
			, SUM([quantity])
			, COUNT(DISTINCT [dim_product_id])
			, SUM([quantity]) / COUNT(DISTINCT [dim_product_id])
			, DENSE_RANK() OVER (ORDER BY SUM([quantity]) / COUNT(distinct dim_product_id) ASC) AS Ranking
		FROM
			[dbo].[view_rccp_footwear_demand_total] f
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
				ON f.[dim_factory_alternative_id] = df.[id]
			INNER JOIN (SELECT [id], [year_month_name] FROM [dbo].[dim_date]) dd
				ON f.[year_month_date_id] = dd.[id]
		WHERE
			[dim_scenario_id] = 1
			and	[year_month_date_id] BETWEEN @horizon_start_date_id AND @horizon_end_date_id
		GROUP BY [short_name]

		FETCH NEXT FROM @horizon_cursor
		INTO @horizon_name, @horizon_start_date_id, @horizon_end_date_id
	END
	CLOSE @horizon_cursor
	DEALLOCATE @horizon_cursor

	-- select * from [report_rccp_footwear_style_mix]



	/*
	 *	KPI - Styles and models with the most demand
	 */

	DELETE FROM [dbo].[report_rccp_footwear_volume_style]
	DELETE FROM [dbo].[report_rccp_footwear_volume_model]

	SET @horizon_cursor = CURSOR FAST_FORWARD FOR
	SELECT [name], [start_date_id], [end_date_id]
	FROM #helper_horizon
	ORDER BY [id] ASC

	OPEN @horizon_cursor
	FETCH NEXT FROM @horizon_cursor
	INTO @horizon_name, @horizon_start_date_id, @horizon_end_date_id
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO [report_rccp_footwear_volume_style] (	[Horizon],		[Report Type],	[Product Style],		[Total Demand],				[Ranking])
		SELECT TOP 10										@horizon_name,	'TOP',			[style],				SUM([quantity]),		DENSE_RANK() OVER (ORDER BY SUM([quantity]) DESC) AS Ranking
		FROM
			[dbo].[view_rccp_footwear_demand_total] f
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
				ON f.[dim_factory_alternative_id] = df.[id]
			INNER JOIN (SELECT [id], [year_month_name] FROM [dbo].[dim_date]) dd
				ON f.[year_month_date_id] = dd.[id]
			INNER JOIN (SELECT [id], [style] FROM [dbo].[dim_product] WHERE [line] = 'Shoes' and [is_placeholder] = 0) dp
				ON f.[dim_product_id] = dp.[id]
		WHERE
			[dim_scenario_id] = 1
			and	[year_month_date_id] BETWEEN @horizon_start_date_id AND @horizon_end_date_id
		GROUP BY
			[style]

		INSERT INTO [report_rccp_footwear_volume_model] (	[Horizon],		[Report Type],	[Product Model],		[Total Demand],				[Ranking])
		SELECT TOP 10										@horizon_name,	'TOP',			[model],				SUM([quantity]),		DENSE_RANK() OVER (ORDER BY SUM([quantity]) DESC) AS Ranking
		FROM
			[dbo].[view_rccp_footwear_demand_total] f
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes' and [is_domestic] = 0) df
				ON f.[dim_factory_alternative_id] = df.[id]
			INNER JOIN (SELECT [id], [year_month_name] FROM [dbo].[dim_date]) dd
				ON f.[year_month_date_id] = dd.[id]
			INNER JOIN (SELECT [id], [model] FROM [dbo].[dim_product] WHERE [line] = 'Shoes' and [is_placeholder] = 0) dp
				ON f.[dim_product_id] = dp.[id]
		WHERE
			[dim_scenario_id] = 1
			and	[year_month_date_id] BETWEEN @horizon_start_date_id AND @horizon_end_date_id
		GROUP BY
			[model]

		FETCH NEXT FROM @horizon_cursor
		INTO @horizon_name, @horizon_start_date_id, @horizon_end_date_id
	END

	CLOSE @horizon_cursor
	DEALLOCATE @horizon_cursor

	-- select * from [report_rccp_footwear_volume_style]
	-- select * from [report_rccp_footwear_volume_model]

END
