USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to do MOQ upcharge adjustment
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_moq_upcharge_adjustment]
	@dim_release_id INT,
	@businessid INT
AS
BEGIN

	DECLARE @dim_demand_category_id_ntb int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Need to Buy')

	-- Reset data
	UPDATE [dbo].[fact_demand_total]
	SET
		[quantity_region_mtl_lvl] = NULL,
		[quantity_customer_mtl_lvl] = NULL,
		[customer_moq] = NULL,
		[customer_below_moq] = NULL,
		[region_moq] = NULL,
		[region_below_moq] = NULL,
		[upcharge] = NULL,
		[is_rejected] = NULL
	WHERE
		[dim_release_id] = @dim_release_id
		and [dim_business_id] = @businessid
		and dim_demand_category_id = @dim_demand_category_id_ntb

	-- Drop temporary table if exists
	IF OBJECT_ID('tempdb..#fact_demand_total_region_level') IS NOT NULL
	BEGIN
		DROP TABLE #fact_demand_total_region_level;
	END

	-- Create temporary table
	CREATE TABLE #fact_demand_total_region_level (
		[dim_buying_program_id] INT
		,[dim_demand_category_id] INT
		-- ,[dim_date_id] INT
		,[dim_factory_id] INT
		,[region] NVARCHAR(100)
		,[material_id] NVARCHAR(45)
		,[quantity] INT
	)

	-- Create table index
	CREATE INDEX idx_select_cursor01 ON #fact_demand_total_region_level
	(
		[dim_buying_program_id]
		,[dim_demand_category_id]
		-- ,[dim_date_id]
		,[dim_factory_id]
		,[region]
		,[material_id]
	)

	-- Fill temp table with data aggregated by region
	INSERT INTO #fact_demand_total_region_level
	SELECT
		[dim_buying_program_id]
		,[dim_demand_category_id]
		-- ,[dim_date_id]
		,[dim_factory_id]
		,dc.[region]
		,dp.[material_id]
		,SUM([quantity_lum]) as [quantity]
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
		INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product]) dp
			ON f.[dim_product_id] = dp.[id]
	WHERE
		[dim_release_id] = @dim_release_id and
		[dim_business_id] = @businessid and
		dim_demand_category_id = @dim_demand_category_id_ntb
	GROUP BY
		[dim_buying_program_id]
		,[dim_demand_category_id]
		-- ,[dim_date_id]
		,[dim_factory_id]
		,dc.[region]
		,dp.[material_id]

    -- Update quantity_region_mtl_lvl
	UPDATE f
	SET
		f.[quantity_region_mtl_lvl] = f_agg.[quantity]
	FROM
    	(
            SELECT
				f.*
				,dc.[region]
				,dp.[material_id]
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
				INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product]) dp
					ON f.[dim_product_id] = dp.[id]
            WHERE
				[dim_release_id] = @dim_release_id and
				[dim_business_id] = @businessid and
				dim_demand_category_id = @dim_demand_category_id_ntb
        ) f
		INNER JOIN #fact_demand_total_region_level
		as f_agg
			ON
				f.[dim_buying_program_id] = f_agg.[dim_buying_program_id] AND
				f.[dim_demand_category_id] = f_agg.[dim_demand_category_id] AND
				-- f.[dim_date_id] = f_agg.[dim_date_id] AND
				f.[dim_factory_id] = f_agg.[dim_factory_id] AND
				f.[region] = f_agg.[region] AND
				f.[material_id] = f_agg.[material_id]

	DROP TABLE #fact_demand_total_region_level;

	-- Update moq
	UPDATE f
	SET
		f.[region_moq] = moq.[from_by_region]
		,f.[region_below_moq] = CASE
			WHEN f.[quantity_region_mtl_lvl] < moq.[from_by_region] THEN 1
			ELSE 0
		END
	FROM
		[dbo].[fact_demand_total] f
		INNER JOIN (SELECT [id], [product_type] FROM [dbo].[dim_product]) dp
			ON f.[dim_product_id] = dp.[id]

		INNER JOIN
		(
			SELECT
				[product_type]
				,MAX([from_by_region]) as [from_by_region]
			FROM [dbo].[helper_pdas_footwear_vans_moq_policy]
			GROUP BY [product_type]
		) moq
			ON dp.[product_type] = moq.[product_type]

    WHERE
		[dim_release_id] = @dim_release_id and
		[dim_business_id] = @businessid and
		dim_demand_category_id = @dim_demand_category_id_ntb

	-- ,f.[customer_below_moq] =
	-- ,f.[customer_moq] =
	-- ,f.[upcharge] =
	-- ,f.[is_rejected] =


	-- Drop temporary table if exists
	IF OBJECT_ID('tempdb..#fact_demand_total_customer_level') IS NOT NULL
	BEGIN
		DROP TABLE #fact_demand_total_customer_level;
	END

	-- Create temporary table
	CREATE TABLE #fact_demand_total_customer_level (
		[dim_buying_program_id] INT
		,[dim_demand_category_id] INT
		,[dim_date_id] INT
		,[vendor_group] NVARCHAR(45)
		,[dim_customer_id] INT
		,[material_id] NVARCHAR(45)
		,[quantity] INT
	)

	-- Create table index
	CREATE INDEX idx_select_cursor01 ON #fact_demand_total_customer_level
	(
		[dim_buying_program_id]
		,[dim_demand_category_id]
		,[dim_date_id]
		,[vendor_group]
		,[dim_customer_id]
		,[material_id]
	)

	-- Fill temp table with data aggregated by region
	INSERT INTO #fact_demand_total_customer_level
	SELECT
		[dim_buying_program_id]
		,[dim_demand_category_id]
		,[dim_date_id]
		,df.[vendor_group]
		,[dim_customer_id]
		,dp.[material_id]
		,SUM([quantity_lum]) as [quantity]
	FROM
		[dbo].[fact_demand_total] f
		INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product]) dp
			ON f.[dim_product_id] = dp.[id]
		INNER JOIN (SELECT [id], [vendor_group] FROM [dbo].[dim_factory]) df
			ON f.[dim_factory_id] = df.[id]
	WHERE
		[dim_release_id] = @dim_release_id and
		[dim_business_id] = @businessid and
		dim_demand_category_id = @dim_demand_category_id_ntb
	GROUP BY
		[dim_buying_program_id]
		,[dim_demand_category_id]
		,[dim_date_id]
		,df.[vendor_group]
		,[dim_customer_id]
		,dp.[material_id]


	-- Update quantity_customer_mtl_lvl
	UPDATE f
	SET
		f.[quantity_customer_mtl_lvl] = f_agg.[quantity]
	FROM
    	(
            SELECT
				f.*
				,df.[vendor_group]
				,dp.[material_id]
            FROM
				[dbo].[fact_demand_total] f
				INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product]) dp
					ON f.[dim_product_id] = dp.[id]
				INNER JOIN (SELECT [id], [vendor_group] FROM [dbo].[dim_factory]) df
					ON f.[dim_factory_id] = df.[id]
            WHERE
				[dim_release_id] = @dim_release_id and
				[dim_business_id] = @businessid and
				dim_demand_category_id = @dim_demand_category_id_ntb
        ) f
		INNER JOIN #fact_demand_total_customer_level
		as f_agg
			ON
				f.[dim_buying_program_id] = f_agg.[dim_buying_program_id] AND
				f.[dim_demand_category_id] = f_agg.[dim_demand_category_id] AND
				f.[dim_date_id] = f_agg.[dim_date_id] AND
				f.[vendor_group] = f_agg.[vendor_group] AND
				f.[dim_customer_id] = f_agg.[dim_customer_id] AND
				f.[material_id] = f_agg.[material_id]

	DROP TABLE #fact_demand_total_customer_level;


	-- Update customer_moq
	UPDATE f
	SET
		f.[customer_moq] = CASE
			WHEN f.[region_below_moq] = 1
			THEN (
				SELECT MAX([from_by_customer])
				FROM [dbo].[helper_pdas_footwear_vans_moq_policy]
				WHERE [from_by_region] <> f.[region_moq]
					AND [product_type] = dp.[product_type]
			)
			ELSE (
				SELECT MAX([from_by_customer])
				FROM [dbo].[helper_pdas_footwear_vans_moq_policy]
				WHERE [from_by_region] = f.[region_moq]
					AND [product_type] = dp.[product_type]
			)
		END
	FROM
		[dbo].[fact_demand_total] f
		INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
			ON f.[dim_demand_category_id] = ddc.[id]
		INNER JOIN (SELECT [id], [product_type] FROM [dbo].[dim_product]) dp
			ON f.[dim_product_id] = dp.[id]
    WHERE
		[dim_release_id] = @dim_release_id and
		[dim_business_id] = @businessid and
		dim_demand_category_id = @dim_demand_category_id_ntb

	-- Update customer_below_moq
	UPDATE f
	SET
		f.[customer_below_moq] = CASE
			WHEN f.[quantity_customer_mtl_lvl] < f.[customer_moq] THEN 1
			ELSE 0
		END
	FROM
		[dbo].[fact_demand_total] f
		INNER JOIN (SELECT [id], [product_type] FROM [dbo].[dim_product]) dp
			ON f.[dim_product_id] = dp.[id]
    WHERE
		[dim_release_id] = @dim_release_id and
		[dim_business_id] = @businessid and
		dim_demand_category_id = @dim_demand_category_id_ntb


	-- Update upcharge
	UPDATE f
	SET f.[upcharge] = CASE
		WHEN f.[customer_below_moq] = 1 THEN h2.[Upcharge]
		ELSE 0
	END
	FROM
		[dbo].[fact_demand_total] f
		INNER JOIN (SELECT [id], [product_type] FROM [dbo].[dim_product]) dp
			ON f.[dim_product_id] = dp.[id]
		INNER JOIN [dbo].[helper_pdas_footwear_vans_moq_policy] h
			ON dp.[product_type] = h.[product_type]
			AND f.[customer_moq] = h.[from_by_customer]
		INNER JOIN
		(
			SELECT [product_type]
			      ,[from_by_region]
			      ,MAX([Upcharge]) AS [Upcharge]
			  FROM [VCDWH].[dbo].[helper_pdas_footwear_vans_moq_policy]
			  group by [product_type], [from_by_region]
	    ) h2
			ON h.[from_by_region] = h2.[from_by_region]

END
