	USE [VCDWH]
	GO
	SET ANSI_WARNINGS OFF
	GO
	-- ==============================================================
	-- Author:		ebp Global
	-- Create date: 9/18/2017
	-- Description:	Procedure to do the allocation of demand to factories (decision tree implementation)
	-- ==============================================================
	ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_unconstrained]
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

			UPDATE f
			SET
				[dim_factory_id_original_unconstrained] = @dim_factory_id_placeholder,
				[allocation_logic_unconstrained] = NULL
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
					ON f.[dim_demand_category_id] = ddc.[id]
			WHERE
				[dim_pdas_id] = @pdasid
				and [dim_business_id] = @businessid
				and ddc.[name] IN ('Forecast', 'Need to Buy')

			-- Decision tree variables level 1 (top level decision tree)
			DECLARE @dim_buying_program_id_01 int
			DECLARE @dim_product_id_01 int
			DECLARE @dim_date_id_01 int
			DECLARE @dim_factory_id_original_unconstrained_01 int
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
			DECLARE @date_buy_01 DATE
			DECLARE @date_crd_01 DATE
			DECLARE @helper_fty_qt_rqt_vendor_01 NVARCHAR(45)
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
				,[dim_product_id] INT
				,[dim_date_id] INT
				,[dim_factory_id_original_unconstrained] INT
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
				,[dim_factory_id_original_unconstrained]
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
				,[dim_factory_id_original_unconstrained]
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
				,f.[dim_factory_id_original_unconstrained]
				,f.[dim_customer_id]
				,f.[dim_demand_category_id]
				,f.[order_number]
				,f.[quantity]
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
				,dc.[sold_to_category] AS [dim_customer_sold_to_category]
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
					ON f.[dim_factory_id_original_unconstrained] = df.[id]
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
				and [edit_dt] IS NULL
				and ddc.[name] IN ('Forecast', 'Need to Buy')


			/* Decision tree algorithm */

			-- Iterate through temporary table row by row
			SET @cursor_01 = CURSOR FAST_FORWARD FOR
			SELECT
				[dim_buying_program_id]
				,[dim_product_id]
				,[dim_date_id]
				,[dim_factory_id_original_unconstrained]
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
				,@dim_factory_id_original_unconstrained_01
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

				-- Get full dates
				SET @date_buy_01 = (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_01)
				SET @date_crd_01 = (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = @pdas_release_full_date_id)

				SET @helper_fty_qt_rqt_vendor_01 =
				(
					SELECT MAX([Factory])
					FROM [dbo].[helper_pdas_footwear_vans_fty_qt]
					WHERE [MTL] = @dim_product_material_id_01
				)
				
				IF @dim_customer_sold_to_category_01 = 'DC'
				BEGIN
					SET @allocation_logic = @allocation_logic +' => ' + 'Sold to category: ' + @dim_customer_sold_to_category_01
					IF @dim_buying_program_name_01 = 'Bulk Buy'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF @dim_customer_country_region_01 = 'EMEA'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic
						END

						IF @dim_customer_country_region_01 in ('NORA', 'CASA')
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							IF @dim_customer_sold_to_party_01 LIKE 'CAN%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub02]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'US%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub05]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'Brazil%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub08]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'Chile%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub09]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'MX%' OR @dim_customer_sold_to_party_01 LIKE 'Mex%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END
						END

						IF @dim_customer_country_region_01 = 'APAC'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							IF @dim_customer_sold_to_party_01 LIKE 'China%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub07]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'Korea%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub06]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'India%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub03]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'MY%' OR @dim_customer_sold_to_party_01 LIKE 'Malaysia%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'Singapore%' OR @dim_customer_sold_to_party_01 LIKE 'SG%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_sold_to_party_01 LIKE 'Hong Kong%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END
						END
					END

					IF @dim_buying_program_name_01 = 'Retail Quick Turn'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF @dim_customer_country_region_01 = 'EMEA'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt_dtc]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic
						END

						IF @dim_customer_country_region_01 in ('NORA', 'CASA')
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt_sjv]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic
						END

						IF @dim_customer_country_region_01 = 'APAC'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							IF @dim_customer_sold_to_party_01 LIKE 'China%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt_hsc]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END
							ELSE
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt_other]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END
						END
					END

					IF @dim_buying_program_name_01 = 'Ad-Hoc Out of Sync'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF (DATEDIFF(day,@date_crd_01,@date_buy_01) >= 73) OR (DATEDIFF(day,@date_crd_01,@date_buy_01) < 73 AND @helper_fty_qt_rqt_vendor_01 IS NULL)
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Lead time: ' + CONVERT(NVARCHAR(10),(DATEDIFF(day,@date_crd_01,@date_buy_01)))
							IF @dim_customer_country_region_01 = 'EMEA'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic

							END

							IF @dim_customer_country_region_01 in ('NORA', 'CASA')
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'CAN%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub02]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'US%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub05]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Brazil%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub08]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Chile%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub09]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'MX%' OR @dim_customer_sold_to_party_01 LIKE 'MEX%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END

							IF @dim_customer_country_region_01 = 'APAC'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'China%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub07]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Korea%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub06]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'India%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub03]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'MY%' OR @dim_customer_sold_to_party_01 LIKE 'Malaysia%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Singapore%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 = 'Hong Kong%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END
						END

						ELSE
						BEGIN
							SET @dim_factory_id_original_unconstrained_01 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_fty_qt_rqt_vendor_01)
							SET @allocation_logic = @allocation_logic +' => ' + 'VQT Vendor'

							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic,
								@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
								@component_factory_short_name = NULL
						END
					END

					IF @dim_buying_program_name_01 = 'Scheduled Out of Sync'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF (DATEDIFF(day,@date_crd_01,@date_buy_01) >= 73) OR (DATEDIFF(day,@date_crd_01,@date_buy_01) < 73 AND @helper_fty_qt_rqt_vendor_01 IS NULL)
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Lead time: ' + CONVERT(NVARCHAR(10),(DATEDIFF(day,@date_crd_01,@date_buy_01)))
							IF @dim_customer_country_region_01 = 'EMEA'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END

							IF @dim_customer_country_region_01 in ('NORA', 'CASA')
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'CAN%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub02]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'US%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub05]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Brazil%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub08]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Chile%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub09]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'MX%' OR @dim_customer_sold_to_party_01 LIKE 'MEX%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END

							IF @dim_customer_country_region_01 = 'APAC'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'China%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub07]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Korea%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub06]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'India%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub03]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'MY%' OR @dim_customer_sold_to_party_01 LIKE 'Malaysia%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Singapore%' OR @dim_customer_sold_to_party_01 LIKE 'SG%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Hong Kong%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END
						END

						ELSE
						BEGIN
							SET @dim_factory_id_original_unconstrained_01 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_fty_qt_rqt_vendor_01)
							SET @allocation_logic = @allocation_logic +' => ' + 'VQT Vendor'

							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic,
								@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
								@component_factory_short_name = NULL
						END
					END
				END

				IF @dim_customer_sold_to_category_01 = 'Direct+International'
				BEGIN
					SET @allocation_logic = @allocation_logic +' => ' + 'Sold to category: ' + @dim_customer_sold_to_category_01
					IF @dim_buying_program_name_01 = 'Bulk Buy'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF @dim_customer_country_region_01 = 'EMEA'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic
						END

						IF @dim_customer_country_region_01 in ('NORA', 'CASA')
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							IF @dim_customer_sold_to_party_01 LIKE 'Canada%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub02]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END

							IF @dim_customer_sold_to_party_01 LIKE 'US%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub04]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END

							IF @dim_customer_sold_to_party_01 LIKE 'Mexico%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END

							IF @dim_customer_sold_to_party_01 LIKE 'International%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END
						END

						IF @dim_customer_country_region_01 = 'APAC'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							IF @dim_customer_sold_to_party_01 LIKE 'Korea%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub06]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END

							IF @dim_customer_sold_to_party_01 LIKE 'APAC Direct%'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END
						END
					END

					IF @dim_buying_program_name_01 = 'Retail Quick Turn'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF @dim_customer_country_region_01 = 'EMEA'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt_dtc]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic
						END

						IF @dim_customer_country_region_01 in ('NORA', 'CASA', 'APAC')
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt_sjv]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic
						END
					END

					IF @dim_buying_program_name_01 = 'Ad Hoc Vendor Quick Turn'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF (DATEDIFF(day,@date_crd_01,@date_buy_01) >= 73) OR (DATEDIFF(day,@date_crd_01,@date_buy_01) < 73 AND @helper_fty_qt_rqt_vendor_01 IS NULL)
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Lead time: ' + CONVERT(NVARCHAR(10),(DATEDIFF(day,@date_crd_01,@date_buy_01)))
							IF @dim_customer_country_region_01 = 'EMEA'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END

							IF @dim_customer_country_region_01 in ('NORA', 'CASA')
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'Canada%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub02]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'US%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub04]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Mexico%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END

							IF @dim_customer_country_region_01 = 'APAC'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'Korea%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub06]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'APAC Direct%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END
						END

						ELSE
						BEGIN
							SET @dim_factory_id_original_unconstrained_01 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_fty_qt_rqt_vendor_01)
							SET @allocation_logic = @allocation_logic +' => ' + 'VQT Vendor'

							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic,
								@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
								@component_factory_short_name = NULL
						END

					END

					IF @dim_buying_program_name_01 = 'Scheduled Out of Sync'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF (DATEDIFF(day,@date_crd_01,@date_buy_01) >= 73) OR (DATEDIFF(day,@date_crd_01,@date_buy_01) < 73 AND @helper_fty_qt_rqt_vendor_01 IS NULL)
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Lead time: ' + CONVERT(NVARCHAR(10),(DATEDIFF(day,@date_crd_01,@date_buy_01)))
							IF @dim_customer_country_region_01 = 'EMEA'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
									@pdasid = @pdasid,
									@businessid = @businessid,
									@dim_buying_program_id = @dim_buying_program_id_01,
									@dim_product_id = @dim_product_id_01,
									@dim_product_material_id = @dim_product_material_id_01,
									@dim_product_style_complexity = @dim_product_style_complexity_01,
									@dim_date_id = @dim_date_id_01,
									@dim_customer_id = @dim_customer_id_01,
									@dim_demand_category_id = @dim_demand_category_id_01,
									@order_number = @order_number_01,
									@allocation_logic = @allocation_logic
							END

							IF @dim_customer_country_region_01 in ('NORA', 'CASA')
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'Canada%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub02]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'US%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub04]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'Mexico%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END

							IF @dim_customer_country_region_01 = 'APAC'
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
								IF @dim_customer_sold_to_party_01 LIKE 'Korea%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub06]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END

								IF @dim_customer_sold_to_party_01 LIKE 'APAC Direct%'
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Sold to party: ' + @dim_customer_sold_to_party_01
									EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub10]
										@pdasid = @pdasid,
										@businessid = @businessid,
										@dim_buying_program_id = @dim_buying_program_id_01,
										@dim_product_id = @dim_product_id_01,
										@dim_product_material_id = @dim_product_material_id_01,
										@dim_product_style_complexity = @dim_product_style_complexity_01,
										@dim_date_id = @dim_date_id_01,
										@dim_customer_id = @dim_customer_id_01,
										@dim_demand_category_id = @dim_demand_category_id_01,
										@order_number = @order_number_01,
										@allocation_logic = @allocation_logic
								END
							END
						END

						ELSE
						BEGIN
							SET @dim_factory_id_original_unconstrained_01 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_fty_qt_rqt_vendor_01)
							SET @allocation_logic = @allocation_logic +' => ' + 'VQT Vendor'

							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic,
								@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
								@component_factory_short_name = NULL
						END
					END
				END

				IF @dim_customer_sold_to_category_01 = 'Crossdock'
				BEGIN
					SET @allocation_logic = @allocation_logic +' => ' + 'Sold to category: ' + @dim_customer_sold_to_category_01
					IF @dim_buying_program_name_01 = 'Bulk Buy'
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'Buying program: ' + @dim_buying_program_name_01
						IF @dim_customer_country_region_01 = 'EMEA'
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Region: ' + @dim_customer_country_region_01
							EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
								@pdasid = @pdasid,
								@businessid = @businessid,
								@dim_buying_program_id = @dim_buying_program_id_01,
								@dim_product_id = @dim_product_id_01,
								@dim_product_material_id = @dim_product_material_id_01,
								@dim_product_style_complexity = @dim_product_style_complexity_01,
								@dim_date_id = @dim_date_id_01,
								@dim_customer_id = @dim_customer_id_01,
								@dim_demand_category_id = @dim_demand_category_id_01,
								@order_number = @order_number_01,
								@allocation_logic = @allocation_logic
						END
					END
				END

				IF @allocation_logic = ''
				BEGIN
					SET @allocation_logic = ' => Sold to category: ' + @dim_customer_sold_to_category_01 + ' => Buying program: ' + @dim_buying_program_name_01 + ' => Region: ' + @dim_customer_country_region_01 + ' => Sold to party: ' + @dim_customer_sold_to_party_01
					EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
						@pdasid = @pdasid,
						@businessid = @businessid,
						@dim_buying_program_id = @dim_buying_program_id_01,
						@dim_product_id = @dim_product_id_01,
						@dim_product_material_id = @dim_product_material_id_01,
						@dim_product_style_complexity = @dim_product_style_complexity_01,
						@dim_date_id = @dim_date_id_01,
						@dim_customer_id = @dim_customer_id_01,
						@dim_demand_category_id = @dim_demand_category_id_01,
						@order_number = @order_number_01,
						@allocation_logic = @allocation_logic,
						@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
						@component_factory_short_name = NULL
				END

				FETCH NEXT FROM @cursor_01
				INTO
					@dim_buying_program_id_01
					,@dim_product_id_01
					,@dim_date_id_01
					,@dim_factory_id_original_unconstrained_01
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
