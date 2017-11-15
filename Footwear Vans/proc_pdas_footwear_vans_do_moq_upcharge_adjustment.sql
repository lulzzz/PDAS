USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to do MOQ upcharge adjustment
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_moq_upcharge_adjustment]
	@pdasid INT,
	@businessid INT
AS
BEGIN

	-- Drop temporary table if exists
	IF OBJECT_ID('tempdb..#fact_demand_total_region_level') IS NOT NULL
	BEGIN
		DROP TABLE #fact_demand_total_region_level;
	END

	-- Create temporary table
	CREATE TABLE #fact_demand_total_region_level (
		[dim_buying_program_id] INT
		,[dim_product_id] INT
		,[dim_date_id] INT
		,[dim_factory_id] INT
		,[region] NVARCHAR(100)
		,[dim_demand_category_id] INT
		,[quantity] INT
	)

	-- Create table index
	CREATE INDEX idx_select_cursor01 ON #fact_demand_total_region_level
	(
		[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_factory_id]
		,[region]
		,[dim_demand_category_id]
	)

	-- Fill temp table with data aggregated by region
	INSERT INTO #fact_demand_total_region_level
	SELECT
		[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_factory_id]
		,dc.[region]
		,[dim_demand_category_id]
		,SUM([quantity]) as [quantity]
	FROM
		[dbo].[fact_demand_total] f
		INNER JOIN
		(
			SELECT
				dc.[id]
				,dl.[region]
			FROM
				[dbo].[dim_customer] dc
				INNER JOIN [dbo].[dim_location] dl
					ON dc.[dim_location_id] = dl.[id]
		) dc
			ON dc.[id] = f.[dim_customer_id]
		INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
			ON f.[dim_demand_category_id] = ddc.[id]
	WHERE
		[dim_pdas_id] = @pdasid and
		[dim_business_id] = @businessid and
		ddc.[name] IN ('Forecast', 'Need to Buy')
	GROUP BY
		[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_factory_id]
		,dc.[region]
		,[dim_demand_category_id]

    -- Update quantity_region
	UPDATE f
	SET
		f.[quantity_region] = f_agg.[quantity]
	FROM
    	(
            SELECT
				f.*
				,dc.[region]
            FROM
				[dbo].[fact_demand_total] f
				INNER JOIN
				(
					SELECT
						dc.[id]
						,dl.[region]
					FROM
						[dbo].[dim_customer] dc
						INNER JOIN [dbo].[dim_location] dl
							ON dc.[dim_location_id] = dl.[id]
				) dc
					ON dc.[id] = f.[dim_customer_id]

				INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
					ON f.[dim_demand_category_id] = ddc.[id]
            WHERE
				[dim_pdas_id] = @pdasid and
				[dim_business_id] = @businessid and
				ddc.[name] IN ('Forecast', 'Need to Buy')
        ) f
		INNER JOIN #fact_demand_total_region_level
		as f_agg
			ON
				f.[dim_buying_program_id] = f_agg.[dim_buying_program_id] AND
				f.[dim_product_id] = f_agg.[dim_product_id] AND
				f.[dim_date_id] = f_agg.[dim_date_id] AND
				f.[dim_factory_id] = f_agg.[dim_factory_id] AND
				f.[region] = f_agg.[region] AND
				f.[dim_demand_category_id] = f_agg.[dim_demand_category_id]


	-- Update quantity_region
	UPDATE f
	SET
		f.[region_moq] = moq.[From by Region]
		,f.[region_below_moq] = CASE
			WHEN f.[quantity_region] < moq.[From by Region] THEN 1
			ELSE 0
		END
	FROM
		[dbo].[fact_demand_total] f
		INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
			ON f.[dim_demand_category_id] = ddc.[id]
		INNER JOIN (SELECT [id], [product_type] FROM [dbo].[dim_product]) dp
			ON f.[dim_product_id] = dp.[id]

		INNER JOIN
		(
			SELECT
				[Product Type]
				,MAX([From by Region]) as [From by Region]
			FROM [dbo].[mc_temp_pdas_footwear_vans_moq_policy]
			GROUP BY [Product Type]
		) moq
			ON dp.[product_type] = moq.[Product Type]

    WHERE
		[dim_pdas_id] = @pdasid and
		[dim_business_id] = @businessid and
		ddc.[name] IN ('Forecast', 'Need to Buy')

	-- ,f.[customer_below_moq] =
	-- ,f.[customer_moq] =
	-- ,f.[upcharge] =
	-- ,f.[is_rejected] =

END
