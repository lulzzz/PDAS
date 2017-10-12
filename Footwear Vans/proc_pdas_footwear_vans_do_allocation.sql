USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/18/2017
-- Description:	Procedure to do the allocation of demand to factories (decision tree implementation)
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation]
	@pdasid INT,
	@businessid INT
AS
BEGIN

	IF
	(
		SELECT COUNT(*)
		FROM
			[dbo].[fact_demand_total]
		WHERE
			[dim_pdas_id] = @pdasid
	) > 0
	BEGIN

		/* Reset allocation */

		/*
		UPDATE [dbo].[fact_demand_total]
		SET
			[dim_factory_id_original] = @dim_factory_id_placeholder
		WHERE
			[dim_pdas_id] = @pdasid
			and [dim_business_id] = @businessid
		*/


		/* Variable declarations */

		-- Placeholders
		DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')

		-- Release month date_id
		DECLARE @pdas_release_month_date_id int
		SET @pdas_release_month_date_id = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (DATEADD(MONTH, (DATEDIFF(MONTH, 0, (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = (SELECT [date_id] FROM [dbo].[dim_pdas] WHERE id = @pdasid)))), 0)))

		-- Decision tree variables level 1 (top level decision tree)
		DECLARE @dim_buying_program_id_01 int
		DECLARE @dim_product_id_01 int
		DECLARE @dim_date_id_01 int
		DECLARE @dim_factory_id_original_01 int
		DECLARE @dim_customer_id_01 int
		DECLARE @dim_demand_category_id_01 int
		DECLARE @order_number_01 NVARCHAR(45)
		DECLARE @quantity_01 int
		DECLARE @dim_buying_program_name_01 NVARCHAR(100)
		DECLARE @dim_demand_category_name_01 NVARCHAR(100)
		DECLARE @dim_product_material_id_01 NVARCHAR(100)
		DECLARE @dim_product_style_complexity_01 NVARCHAR(100)
		DECLARE @dim_construction_type_name_01 NVARCHAR(100)
		DECLARE @dim_factory_short_name_01 NVARCHAR(100)
		DECLARE @dim_factory_region_01 NVARCHAR(100)
		DECLARE @dim_factory_country_code_a2_01 NVARCHAR(2)
		DECLARE @dim_customer_name_01 NVARCHAR(100)
		DECLARE @dim_customer_sold_to_party_01 NVARCHAR(100)
		DECLARE @dim_customer_sold_to_category_01 NVARCHAR(100)
		DECLARE @dim_customer_country_region_01 NVARCHAR(100)
		DECLARE @dim_customer_country_code_a2_01 NVARCHAR(100)
		DECLARE @allocation_logic NVARCHAR(1000)

		-- Cursors
		DECLARE @cursor_01 CURSOR


		/* Temporary table setup (for algorithm performance improvement and avoiding deadlocks) */

		-- Drop temporary table if exists
		IF OBJECT_ID('tempdb..#select_cursor01') IS NOT NULL
		BEGIN
			DROP TABLE #select_cursor01;
		END

		-- Create table
		CREATE TABLE #select_cursor01 (
			[dim_buying_program_id] INT
			,[dim_product_id] INT
			,[dim_date_id] INT
			,[dim_factory_id_original] INT
			,[dim_customer_id] INT
			,[dim_demand_category_id] INT
			,[order_number] NVARCHAR(45)
			,[quantity] INT
			,[dim_buying_program_name] NVARCHAR(100)
			,[dim_demand_category_name] NVARCHAR(100)
			,[dim_product_material_id] NVARCHAR(100)
			,[dim_product_style_complexity] NVARCHAR(100)
			,[dim_construction_type_name] NVARCHAR(100)
			,[dim_factory_short_name]  NVARCHAR(100)
			,[dim_factory_region] NVARCHAR(100)
			,[dim_factory_country_code_a2] NVARCHAR(2)
			,[dim_customer_name]  NVARCHAR(100)
			,[dim_customer_sold_to_party] NVARCHAR(100)
			,[dim_customer_sold_to_category] NVARCHAR(100)
			,[dim_customer_country_region] NVARCHAR(100)
			,[dim_customer_country_code_a2] NVARCHAR(2)
		)

		-- Create table index
		CREATE INDEX idx_select_cursor01 ON #select_cursor01
		(
			[dim_buying_program_id]
			,[dim_product_id]
			,[dim_date_id]
			,[dim_factory_id_original]
			,[dim_customer_id]
			,[dim_demand_category_id]
			,[order_number]
		)

		-- Fill table with data model data
		INSERT INTO #select_cursor01
		(
			[dim_buying_program_id]
			,[dim_product_id]
			,[dim_date_id]
			,[dim_factory_id_original]
			,[dim_customer_id]
			,[dim_demand_category_id]
			,[order_number]
			,[quantity]
			,[dim_buying_program_name]
			,[dim_demand_category_name]
			,[dim_product_material_id]
			,[dim_product_style_complexity]
			,[dim_construction_type_name]
			,[dim_factory_short_name]
			,[dim_factory_region]
			,[dim_factory_country_code_a2]
			,[dim_customer_name]
			,[dim_customer_sold_to_party]
			,[dim_customer_sold_to_category]
			,[dim_customer_country_region]
			,[dim_customer_country_code_a2]
		)
		SELECT
			f.[dim_buying_program_id]
			,f.[dim_product_id]
			,f.[dim_date_id]
			,f.[dim_factory_id_original]
			,f.[dim_customer_id]
			,f.[dim_demand_category_id]
			,f.[order_number]
			,f.[quantity_consumed]
			,dbp.[name] AS [dim_buying_program_name]
			,ddc.[name] AS [dim_demand_category_name]
			,dp.[material_id] AS [dim_product_material_id]
			,dp.[style_complexity] AS [dim_product_style_complexity]
			,dp.[dim_construction_type_name]
			,df.[short_name] AS [dim_factory_short_name]
			,df.[region] AS [dim_factory_region]
			,df.[country_code_a2] AS [dim_factory_country_code_a2]
			,dc.[name] AS [dim_customer_name]
			,dc.[sold_to_party] AS [dim_customer_sold_to_party]
			,dc.[sold_to_category] AS [dim_customer_sold_to_category
			,dc.[region] AS [dim_customer_country_region]
			,dc.[country_code_a2] AS [dim_customer_country_code_a2]
		FROM
			[dbo].[fact_demand_total] f
			INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_buying_program]) dbp
				ON f.[dim_buying_program_id] = dbp.[id]
			INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
				ON f.[dim_demand_category_id] = ddc.[id]
			INNER JOIN
			(
				SELECT
					f.[id]
					,f.[material_id]
					,f.[style_complexity]
					,f.[is_placeholder]
					,dl.[name] AS [dim_construction_type_name]
				FROM
					[dbo].[dim_product] f
					INNER JOIN [dbo].[dim_construction_type] dl
						ON dl.[id] = f.[dim_construction_type_id]
			) dp
				ON f.[dim_product_id] = dp.[id]
			INNER JOIN
			(
				SELECT
					f.[id]
					,f.[short_name]
					,f.[is_placeholder]
					,dl.[region]
					,dl.[country_code_a2]
				FROM
					[dbo].[dim_factory] f
					INNER JOIN [dbo].[dim_location] dl
						ON dl.[id] = f.[dim_location_id]
			) df
				ON f.[dim_factory_id_original] = df.[id]
			INNER JOIN
			(
				SELECT
					f.[id]
					,f.[name]
					,f.[sold_to_party]
					,f.[sold_to_category]
					,f.[is_placeholder]
					,dl.[region]
					,dl.[country_code_a2]
				FROM
					[dbo].[dim_customer] f
					INNER JOIN [dbo].[dim_location] dl
						ON dl.[id] = f.[dim_location_id]
			) dc
				ON f.[dim_customer_id] = dc.[id]
		WHERE
			[dim_pdas_id] = @pdasid
			and [dim_business_id] = @businessid
			and [dim_date_id] >= @pdas_release_month_date_id
			and [edit_username] IS NULL
			and ddc.[name] IN ('Forecast', 'Need to Buy')


		/* Decision tree algorithm */

		-- Iterate through temporary table row by row
		SET @cursor_01 = CURSOR FAST_FORWARD FOR
		SELECT
			[dim_buying_program_id]
			,[dim_product_id]
			,[dim_date_id]
			,[dim_factory_id_original]
			,[dim_customer_id]
			,[dim_demand_category_id]
			,[order_number]
			,[quantity]
			,[dim_buying_program_name]
			,[dim_demand_category_name]
			,[dim_product_material_id]
			,[dim_product_style_complexity]
			,[dim_construction_type_name]
			,[dim_factory_short_name]
			,[dim_factory_region]
			,[dim_factory_country_code_a2]
			,[dim_customer_name]
			,[dim_customer_sold_to_party]
			,[dim_customer_sold_to_category]
			,[dim_customer_country_region]
			,[dim_customer_country_code_a2]
		FROM #select_cursor01
		OPEN @cursor_01
		FETCH NEXT FROM @cursor_01
		INTO
			@dim_buying_program_id_01
			,@dim_product_id_01
			,@dim_date_id_01
			,@dim_factory_id_original_01
			,@dim_customer_id_01
			,@dim_demand_category_id_01
			,@order_number_01
			,@quantity_01
			,@dim_buying_program_name_01
			,@dim_demand_category_name_01
			,@dim_product_material_id_01
			,@dim_product_style_complexity_01
			,@dim_construction_type_name_01
			,@dim_factory_short_name_01
			,@dim_factory_region_01
			,@dim_factory_country_code_a2_01
			,@dim_customer_name_01
			,@dim_customer_sold_to_party_01
			,@dim_customer_sold_to_category_01
			,@dim_customer_country_region_01
			,@dim_customer_country_code_a2_01
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Reset allocation logic
			SET @allocation_logic = ''

			-- Test sub proc
			EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
				@pdasid = @pdasid,
				@businessid = @businessid,
				@dim_buying_program_id = @dim_buying_program_id_01,
				@dim_product_id = @dim_product_id_01,
				@dim_date_id = @dim_date_id_01,
				@dim_customer_id = @dim_customer_id_01,
				@dim_demand_category_id = @dim_demand_category_id_01,
				@order_number = @order_number_01,
				@allocation_logic = @allocation_logic

			IF @dim_customer_sold_to_party_01 = 'DC'
			BEGIN
				SET @allocation_logic = @allocation_logic +'\n' + 'Sold to party: ' + @dim_customer_sold_to_party_01
				IF @dim_buying_program_name_01 = 'Bulk Buy'
				BEGIN
					SET @allocation_logic = @allocation_logic +'\n' + 'Buying program: ' + @dim_buying_program_name_01
					IF @dim_customer_country_region_01 = 'EMEA'
					BEGIN
						SET @allocation_logic = @allocation_logic +'\n' + 'Region: ' + @dim_customer_country_region_01

						print('put sub proc 01 here')

					END

				END
			END

			FETCH NEXT FROM @cursor_01
			INTO
				@dim_buying_program_id_01
				,@dim_product_id_01
				,@dim_date_id_01
				,@dim_factory_id_original_01
				,@dim_customer_id_01
				,@dim_demand_category_id_01
				,@order_number_01
				,@quantity_01
				,@dim_buying_program_name_01
				,@dim_demand_category_name_01
				,@dim_product_material_id_01
				,@dim_product_style_complexity_01
				,@dim_construction_type_name_01
				,@dim_factory_short_name_01
				,@dim_factory_region_01
				,@dim_factory_country_code_a2_01
				,@dim_customer_name_01
				,@dim_customer_sold_to_party_01
				,@dim_customer_sold_to_category_01
				,@dim_customer_country_region_01
				,@dim_customer_country_code_a2_01
		END
		CLOSE @cursor_01
		DEALLOCATE @cursor_01


	END

END
