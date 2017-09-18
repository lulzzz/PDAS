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

        -- Variable declarations
        DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
		DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')

        DECLARE @etl_month_date_id int
		SET @etl_month_date_id = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (DATEADD(MONTH, (DATEDIFF(MONTH, 0, (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = (SELECT [etl_date_id] FROM [dbo].[dim_pdas] WHERE id = @dim_pdas_id)))), 0)))

		DECLARE @cursor_01 CURSOR


		DECLARE @dim_buying_program_id_01 int
		DECLARE @dim_product_id_01 int
		TODO


		-- Reset allocation
        UPDATE [dbo].[fact_demand_total]
        SET
            [dim_factory_id_original] = @dim_factory_id_placeholder
        WHERE
            [dim_pdas_id] = @pdasid


		/* CURSOR 01 START: Loop through exploded fact_demand_total row by row */

		IF OBJECT_ID('tempdb..#select_cursor01') IS NOT NULL
		BEGIN
			DROP TABLE #select_cursor01;
		END

		CREATE TABLE #select_cursor01 (
			[dim_buying_program_id] INT
			,[dim_product_id] INT
			,[dim_date_id] INT
			,[dim_factory_id_original] INT
			,[dim_customer_id] INT
			,[dim_demand_category_id] INT
			,[order_number] INT
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
			,[dim_customer_country_region] NVARCHAR(100)
			,[dim_customer_country_code_a2] NVARCHAR(2)
		)
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
			and [dim_business_id] = @dim_business_id_footwear_vans
			and [dim_date_id] >= @etl_month_date_id
			and [edit_username] IS NULL



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
			,[dim_customer_country_region]
			,[dim_customer_country_code_a2]
		FROM #select_cursor01

		OPEN @cursor_01
		FETCH NEXT FROM @cursor_01
		INTO
			@dim_buying_program_id_01
			,TODO
		WHILE @@FETCH_STATUS = 0
		BEGIN


			FETCH NEXT FROM @cursor_01
			INTO
				TODO
		END
		CLOSE @cursor_01
		DEALLOCATE @cursor_01


    END

END
