USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
--- Create date: 9/18/2017
--- Description:	Procedure to do the allocation of demand to factories (decision tree implementation)
---				Constrained scenario
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

		-- Release month dim_date_id
		DECLARE @pdas_release_month_date_id int
		SET @pdas_release_month_date_id = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (DATEADD(MONTH, (DATEDIFF(MONTH, 0, (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE id = @pdasid)))), 0)))

		-- Release full dim_date_id
		DECLARE @pdas_release_full_date_id int
		SET @pdas_release_full_date_id = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)

		/* Reset allocation */

		UPDATE f
		SET
			[dim_factory_id_original_constrained] = [dim_factory_id_original_unconstrained],
			[allocation_logic_constrained] = ''
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
		DECLARE @dim_date_id_01 int
		DECLARE @dim_factory_id_original_unconstrained_01 int
		DECLARE @dim_factory_id_original_constrained_01 int
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
		DECLARE @allocation_logic_01 NVARCHAR(1000)
		DECLARE @helper_fty_qt_rqt_vendor_01 NVARCHAR(45)
		DECLARE @current_fill_01 int
		DECLARE @max_capacity_01 int
		DECLARE @fill_status NVARCHAR(1000)
		DECLARE @loop_01 int = 1
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
			,[dim_factory_id_original_unconstrained] INT
			,[dim_factory_id_original_constrained] INT
			,[dim_customer_id] INT
			,[dim_demand_category_id] INT
			,[quantity] INT
			,[allocation_logic_constrained] NVARCHAR(1000)
			,[dim_date_year_cw_accounting] NVARCHAR(8)
			,[dim_buying_program_name] NVARCHAR(100)
			,[dim_demand_category_name] NVARCHAR(100)
			,[dim_product_material_id] NVARCHAR(100) -- Here we are at MTL level
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
			,[dim_factory_id_original_unconstrained]
			,[dim_customer_id]
			,[dim_demand_category_id]
		)
		WHILE @loop_01 <= 1
		BEGIN

			-- Fill table with data model data
			INSERT INTO #select_cursor01
			(
				[dim_buying_program_id]
				,[dim_factory_id_original_unconstrained]
				,[dim_factory_id_original_constrained]
				,[dim_customer_id]
				,[dim_demand_category_id]
				,[quantity]
				,[allocation_logic_constrained]
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
					,[dim_factory_id_original_unconstrained]
					,[dim_factory_id_original_constrained]
					,[dim_customer_id]
					,[dim_demand_category_id]
					,SUM([quantity]) AS [quantity]
					,MAX([allocation_logic_constrained])
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
					,f.[dim_factory_id_original_unconstrained]
					,f.[dim_factory_id_original_constrained]
					,f.[dim_customer_id]
					,f.[dim_demand_category_id]
					,f.[quantity]
					,f.[allocation_logic_constrained]
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
					and ddc.[name] IN ('Forecast', 'Need to Buy')
			) x
			GROUP BY
				[dim_buying_program_id]
				,[dim_factory_id_original_unconstrained]
				,[dim_factory_id_original_constrained]
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
			ORDER BY
				[dim_date_year_cw_accounting] ASC
				,[quantity] DESC


			/* Decision tree algorithm */

			-- Iterate through temporary table row by row
			SET @cursor_01 = CURSOR FAST_FORWARD FOR
			SELECT
				[dim_buying_program_id]
				,[dim_factory_id_original_unconstrained]
				,[dim_factory_id_original_constrained]
				,[dim_customer_id]
				,[dim_demand_category_id]
				,[quantity]
				,[allocation_logic_constrained]
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
				,@dim_factory_id_original_unconstrained_01
				,@dim_factory_id_original_constrained_01
				,@dim_customer_id_01
				,@dim_demand_category_id_01
				,@quantity_01
				,@allocation_logic_01
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
				SET @fill_status = ''

				SET @current_fill_01 =
				(
					SELECT SUM([quantity])
					FROM
						[dbo].[fact_demand_total] f
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
						INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
							ON f.[dim_demand_category_id] = ddc.[id]
					WHERE
						[dim_pdas_id] = @pdasid
						and [dim_business_id] = @businessid
						and [dim_date_id] >= @pdas_release_month_date_id
						and ddc.[name] IN ('Forecast', 'Need to Buy')
					GROUP BY [dim_factory_id_original_unconstrained], [year_cw_accounting], [dim_construction_type_name]
					HAVING [dim_factory_id_original_unconstrained] IN (
							SELECT [id]
						    FROM [dbo].[dim_factory]
						    WHERE [allocation_group] = (SELECT [allocation_group] FROM [dbo].[dim_factory] WHERE [id] = @dim_factory_id_original_unconstrained_01)
						)
						AND [year_cw_accounting] = @dim_date_year_cw_accounting_01
						AND [dim_construction_type_name] = @dim_construction_type_name_01
						-- TO DO there should be two additional conditions
				)

				SET @max_capacity_01 =
				(
					SELECT SUM([Available Capacity by Week])
				  	FROM [VCDWH].[dbo].[xl_view_pdas_footwear_vans_factory_capacity]
				 	GROUP BY [dim_factory_id], [Accounting CW], [Construction Type]
					HAVING [dim_factory_id] = @dim_factory_id_original_unconstrained_01
						AND [Accounting CW] = @dim_date_year_cw_accounting_01
						AND [Construction Type] = @dim_construction_type_name_01
				)

				IF @current_fill_01 IS NULL
				BEGIN
					SET @fill_status = @dim_factory_original_short_name_01
					+ ' quantity not found for '
					+ @dim_date_year_cw_accounting_01
					+ ' construction type '
					+ @dim_construction_type_name_01
				END
				ELSE IF @max_capacity_01 IS NULL
				BEGIN
					SET @fill_status = @dim_factory_original_short_name_01
					+ ' capacity not found for '
					+ @dim_date_year_cw_accounting_01
					+ ' construction type '
					+ @dim_construction_type_name_01
				END
				ELSE IF @max_capacity_01 = 0
				BEGIN
					SET @fill_status = @dim_factory_original_short_name_01
					+ ' Weekly fill rate: '
					+ CONVERT(NVARCHAR(10), @current_fill_01) + '/'
					+ CONVERT(NVARCHAR(10), @max_capacity_01)
				END
				ELSE
				BEGIN
					SET @fill_status = @dim_factory_original_short_name_01
					+ ' Weekly fill rate: '
					+ CONVERT(NVARCHAR(10), @current_fill_01) + '/'
					+ CONVERT(NVARCHAR(10), @max_capacity_01) + ' ('
					+ FORMAT(CONVERT(FLOAT, @current_fill_01)/CONVERT(FLOAT, @max_capacity_01),'P') + ')'
				END

				IF @current_fill_01 > @max_capacity_01
				BEGIN
					IF @loop_01 = 1
					BEGIN
						SET @allocation_logic_01 = @allocation_logic_01 + '[OVERLOAD] ' + @fill_status
					END
					IF @dim_factory_original_short_name_01 = 'CLK'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_clk_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE IF @dim_factory_original_short_name_01 = 'DTC'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_dtc_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE IF @dim_factory_original_short_name_01 = 'DTP'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_dtp_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE IF @dim_factory_original_short_name_01 = 'FSC'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_fsc_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE IF @dim_factory_original_short_name_01 = 'HSC'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_hsc_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE IF @dim_factory_original_short_name_01 = 'ICC'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_icc_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE IF @dim_factory_original_short_name_01 = 'SJD'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_sjd_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE IF @dim_factory_original_short_name_01 = 'SJV'
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + @dim_factory_original_short_name_01 + ' scenario B'
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_sjv_b]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@loop = @loop_01
					END
					ELSE
					BEGIN
						IF @loop_01 = 1
						BEGIN
							SET @allocation_logic_01 = @allocation_logic_01 + ' => ' + 'No allocation logic found for ' + @dim_factory_original_short_name_01
						END
						EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_updater]
							@pdasid = @pdasid,
							@businessid = @businessid,
							@pdas_release_month_date_id = @pdas_release_month_date_id,
							@dim_buying_program_id = @dim_buying_program_id_01,
							@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
							@dim_product_material_id = @dim_product_material_id_01,
							@dim_product_style_complexity = @dim_product_style_complexity_01,
							@dim_construction_type_name = @dim_construction_type_name_01,
							@dim_factory_original_region = @dim_factory_original_region_01,
							@quantity = @quantity_01,
							@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
							@dim_customer_id = @dim_customer_id_01,
							@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
							@dim_demand_category_id = @dim_demand_category_id_01,
							@allocation_logic = @allocation_logic_01,
							@dim_factory_id_original_constrained = @dim_factory_id_original_unconstrained_01
					END
				END

				ELSE
				BEGIN
					IF @loop_01 = 1
					BEGIN
						SET @allocation_logic_01 = @allocation_logic_01 + '[AVAILABLE] ' + @fill_status
					END
					EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_updater]
						@pdasid = @pdasid,
						@businessid = @businessid,
						@pdas_release_month_date_id = @pdas_release_month_date_id,
						@dim_buying_program_id = @dim_buying_program_id_01,
						@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_01,
						@dim_product_material_id = @dim_product_material_id_01,
						@dim_product_style_complexity = @dim_product_style_complexity_01,
						@dim_construction_type_name = @dim_construction_type_name_01,
						@dim_factory_original_region = @dim_factory_original_region_01,
						@quantity = @quantity_01,
						@dim_date_year_cw_accounting = @dim_date_year_cw_accounting_01,
						@dim_customer_id = @dim_customer_id_01,
						@dim_customer_sold_to_party = @dim_customer_sold_to_party_01,
						@dim_demand_category_id = @dim_demand_category_id_01,
						@allocation_logic = @allocation_logic_01,
						@dim_factory_id_original_constrained = @dim_factory_id_original_unconstrained_01
				END

				FETCH NEXT FROM @cursor_01
				INTO
					@dim_buying_program_id_01
					,@dim_factory_id_original_unconstrained_01
					,@dim_factory_id_original_constrained_01
					,@dim_customer_id_01
					,@dim_demand_category_id_01
					,@quantity_01
					,@allocation_logic_01
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

		    SET @loop_01 = @loop_01 + 1
		END
	END
END
