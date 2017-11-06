USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/18/2017
-- Description:	Procedure to do the allocation of demand to factories (decision tree implementation)
--				Constrained scenario
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_constrained]
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

		/* Variable declarations */

		-- Placeholders
		DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')

		-- Release month date_id
		DECLARE @pdas_release_month_date_id int
		SET @pdas_release_month_date_id = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (DATEADD(MONTH, (DATEDIFF(MONTH, 0, (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = (SELECT [date_id] FROM [dbo].[dim_pdas] WHERE id = @pdasid)))), 0)))

		-- Release full date_id
		DECLARE @pdas_release_full_date_id int
		SET @pdas_release_full_date_id = (SELECT [date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)

		/* Reset allocation */

		UPDATE [dbo].[fact_demand_total]
		SET
			[dim_factory_id_original_constrained] = [dim_factory_id_original]
		WHERE
			[dim_pdas_id] = @pdasid
			and [dim_business_id] = @businessid

		-- Decision tree variables level 1 (top level decision tree)
		DECLARE @dim_buying_program_id_01 int
		DECLARE @dim_date_id_01 int
		DECLARE @dim_factory_id_original_01 int
		DECLARE @dim_factory_original_short_name_01 NVARCHAR(100)
		DECLARE @dim_factory_original_region_01 NVARCHAR(100)
		DECLARE @dim_factory_original_country_code_a2_01 NVARCHAR(2)
		DECLARE @dim_customer_id_01 int
		DECLARE @dim_demand_category_id_01 int
		DECLARE @quantity_01 int
		DECLARE @dim_date_year_cw_accounting_01 NVARCHAR(8)
		DECLARE @dim_buying_program_name_01 NVARCHAR(100)
		DECLARE @dim_demand_category_name_01 NVARCHAR(100)
		DECLARE @dim_product_material_id_01 NVARCHAR(100)
		DECLARE @dim_product_style_complexity_01 NVARCHAR(100)
		DECLARE @dim_construction_type_name_01 NVARCHAR(100)
		DECLARE @dim_customer_name_01 NVARCHAR(100)
		DECLARE @dim_customer_sold_to_party_01 NVARCHAR(100)
		DECLARE @dim_customer_sold_to_category_01 NVARCHAR(100)
		DECLARE @dim_customer_country_region_01 NVARCHAR(100)
		DECLARE @dim_customer_country_code_a2_01 NVARCHAR(100)
		DECLARE @allocation_logic NVARCHAR(1000)
		DECLARE @helper_fty_qt_rqt_vendor_01 NVARCHAR(45)
		DECLARE @current_fill_01 int
		DECLARE @max_capacity_01 int
		/* DECLARE @dim_product_id  */

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
			,[dim_factory_id_original] INT
			,[dim_customer_id] INT
			,[dim_demand_category_id] INT
			,[quantity] INT
			,[dim_date_year_cw_accounting] NVARCHAR(8)
			,[dim_buying_program_name] NVARCHAR(100)
			,[dim_demand_category_name] NVARCHAR(100)
			,[dim_product_material_id] NVARCHAR(100) -- Here you are at MTL level
			,[dim_product_style_complexity] NVARCHAR(100)
			,[dim_construction_type_name] NVARCHAR(100)
			,[dim_factory_original_short_name]  NVARCHAR(100)
			,[dim_factory_original_region] NVARCHAR(100)
			,[dim_factory_original_country_code_a2] NVARCHAR(2)
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
			,[dim_factory_id_original]
			,[dim_customer_id]
			,[dim_demand_category_id]
		)

		-- Fill table with data model data
		INSERT INTO #select_cursor01
		(
			[dim_buying_program_id]
			,[dim_factory_id_original]
			,[dim_customer_id]
			,[dim_demand_category_id]
			,[quantity]
			,[dim_date_year_cw_accounting]
			,[dim_buying_program_name]
			,[dim_demand_category_name]
			,[dim_product_material_id] -- Here you are at MTL level
			,[dim_product_style_complexity]
			,[dim_construction_type_name]
			,[dim_factory_original_short_name]
			,[dim_factory_original_region]
			,[dim_factory_original_country_code_a2]
			,[dim_customer_name]
			,[dim_customer_sold_to_party]
			,[dim_customer_sold_to_category]
			,[dim_customer_country_region]
			,[dim_customer_country_code_a2]
		)
		SELECT
				[dim_buying_program_id]
				,[dim_factory_id_original]
				,[dim_customer_id]
				,[dim_demand_category_id]
				,SUM([quantity_consumed]) AS [quantity]
				,[dim_date_year_cw_accounting]
				,[dim_buying_program_name]
				,[dim_demand_category_name]
				,[dim_product_material_id]
				,[dim_product_style_complexity]
				,[dim_construction_type_name]
				,[dim_factory_original_short_name]
				,[dim_factory_original_region]
				,[dim_factory_original_country_code_a2]
				,[dim_customer_name]
				,[dim_customer_sold_to_party]
				,[dim_customer_sold_to_category]
				,[dim_customer_country_region]
				,[dim_customer_country_code_a2]

		FROM
		(
			SELECT
				f.[dim_buying_program_id]
				,f.[dim_date_id]
				,f.[dim_factory_id_original]
				,f.[dim_customer_id]
				,f.[dim_demand_category_id]
				,f.[quantity_consumed]
				,dd.[year_cw_accounting] AS [dim_date_year_cw_accounting]
				,dbp.[name] AS [dim_buying_program_name]
				,ddc.[name] AS [dim_demand_category_name]
				,dp.[material_id] AS [dim_product_material_id]
				,dp.[style_complexity] AS [dim_product_style_complexity]
				,dp.[dim_construction_type_name]
				,df.[short_name] AS [dim_factory_original_short_name]
				,df.[region] AS [dim_factory_original_region]
				,df.[country_code_a2] AS [dim_factory_original_country_code_a2]
				,dc.[name] AS [dim_customer_name]
				,dc.[sold_to_party] AS [dim_customer_sold_to_party]
				,dc.[sold_to_category] AS [dim_customer_sold_to_category]
				,dc.[region] AS [dim_customer_country_region]
				,dc.[country_code_a2] AS [dim_customer_country_code_a2]
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN (SELECT [id], [year_cw_accounting] FROM [dbo].[dim_date]) dd
					ON f.[dim_date_id] = dd.[id]
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
				[dim_pdas_id] = 1
				and [dim_business_id] = 1
				and [dim_date_id] >= @pdas_release_month_date_id
				and [edit_username] IS NULL
				and ddc.[name] IN ('Forecast', 'Need to Buy')
		) x
		group by
			[dim_buying_program_id]
			,[dim_factory_id_original]
			,[dim_customer_id]
			,[dim_demand_category_id]
			,[dim_date_year_cw_accounting]
			,[dim_buying_program_name]
			,[dim_demand_category_name]
			,[dim_product_material_id]
			,[dim_product_style_complexity]
			,[dim_construction_type_name]
			,[dim_factory_original_short_name]
			,[dim_factory_original_region]
			,[dim_factory_original_country_code_a2]
			,[dim_customer_name]
			,[dim_customer_sold_to_party]
			,[dim_customer_sold_to_category]
			,[dim_customer_country_region]
			,[dim_customer_country_code_a2]

		/* Decision tree algorithm */

		-- Iterate through temporary table row by row
		SET @cursor_01 = CURSOR FAST_FORWARD FOR
		SELECT
			[dim_buying_program_id]
			,[dim_factory_id_original]
			,[dim_customer_id]
			,[dim_demand_category_id]
			,[quantity]
			,[dim_date_year_cw_accounting]
			,[dim_buying_program_name]
			,[dim_demand_category_name]
			,[dim_product_material_id]
			,[dim_product_style_complexity]
			,[dim_construction_type_name]
			,[dim_factory_original_short_name]
			,[dim_factory_original_region]
			,[dim_factory_original_country_code_a2]
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
			,@dim_factory_id_original_01
			,@dim_customer_id_01
			,@dim_demand_category_id_01
			,@quantity_01
			,@dim_date_year_cw_accounting_01
			,@dim_buying_program_name_01
			,@dim_demand_category_name_01
			,@dim_product_material_id_01
			,@dim_product_style_complexity_01
			,@dim_construction_type_name_01
			,@dim_factory_original_short_name_01
			,@dim_factory_original_region_01
			,@dim_factory_original_country_code_a2_01
			,@dim_customer_name_01
			,@dim_customer_sold_to_party_01
			,@dim_customer_sold_to_category_01
			,@dim_customer_country_region_01
			,@dim_customer_country_code_a2_01
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Reset allocation logic
			SET @allocation_logic = ''

			SET @current_fill_01 =
			(
				SELECT SUM([quantity_consumed])
				FROM [dbo].[fact_demand_total] f
				INNER JOIN (SELECT [id], [year_cw_accounting] FROM [dbo].[dim_date]) dd
					ON f.[dim_date_id] = dd.[id]
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
				GROUP BY [dim_factory_id_original], [year_cw_accounting], [dim_construction_type_name]
				HAVING [dim_factory_id_original] = @dim_factory_id_original_01
					AND [year_cw_accounting] = @dim_date_year_cw_accounting_01
					AND [dim_construction_type_name] = @dim_construction_type_name_01
			)

			-- we don't have the 2018 capacities...
			SET @max_capacity_01 =
			(
				SELECT SUM([Available Capacity by Week])
			  	FROM [VCDWH].[dbo].[xl_view_pdas_footwear_vans_factory_capacity]
			 	GROUP BY [dim_factory_id], [Accounting CW], [Construction Type]
				HAVING [dim_factory_id] = @dim_factory_id_original_01
					AND [Accounting CW] = @dim_date_year_cw_accounting_01
					AND [Construction Type] = @dim_construction_type_name_01
			)

			IF @current_fill_01 > @max_capacity_01
			BEGIN
				IF @dim_factory_original_short_name_01 = 'CLK'
				BEGIN
					SET @allocation_logic = @allocation_logic + ' => ' + 'Unconstrained: ' + @dim_factory_original_short_name_01
					EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_clk_b]
						@pdasid = @pdasid,
						@businessid = @businessid,
						@dim_buying_program_id = @dim_buying_program_id_01,
						@dim_factory_id_original = @dim_factory_id_original_01,
						@dim_product_material_id = @dim_product_material_id_01,
						@dim_product_style_complexity = @dim_product_style_complexity_01,
						@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
						@dim_customer_id = @dim_customer_id_01,
						@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
						@dim_demand_category_id = @dim_demand_category_id_01,
						@allocation_logic = @allocation_logic
				END
			END

			IF @allocation_logic = ''
			BEGIN
				SET @allocation_logic =
				(
					@dim_factory_original_short_name_01
					+ ' fill: '
					+ convert(NVARCHAR(12), @current_fill_01)
					+ '/'
					+ convert(NVARCHAR(12), @max_capacity_01)
				)
				EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_updater]
					@pdasid = @pdasid,
					@businessid = @businessid,
					@dim_buying_program_id = @dim_buying_program_id_01,
					@dim_factory_id_original = @dim_factory_id_original_01,
					@dim_product_material_id = @dim_product_material_id_01,
					@dim_product_style_complexity = @dim_product_style_complexity_01,
					@dim_factory_original_region = @dim_factory_original_region_01,
					@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
					@dim_customer_id = @dim_customer_id_01,
					@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
					@dim_demand_category_id = @dim_demand_category_id_01,
					@allocation_logic = @allocation_logic,
					@dim_factory_id_original_constrained = @dim_factory_id_original_01
			END


			FETCH NEXT FROM @cursor_01
			INTO
				@dim_buying_program_id_01
				,@dim_factory_id_original_01
				,@dim_customer_id_01
				,@dim_demand_category_id_01
				,@quantity_01
				,@dim_date_year_cw_accounting_01
				,@dim_buying_program_name_01
				,@dim_demand_category_name_01
				,@dim_product_material_id_01
				,@dim_product_style_complexity_01
				,@dim_construction_type_name_01
				,@dim_factory_original_short_name_01
				,@dim_factory_original_region_01
				,@dim_factory_original_country_code_a2_01
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
