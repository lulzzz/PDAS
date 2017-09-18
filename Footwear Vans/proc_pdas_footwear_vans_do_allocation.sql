USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/18/2017
-- Description:	Procedure to do the allocation of demand to factories (decision tree implementation)
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation]
	@pdasid INT
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

        -- Reset allocation
        UPDATE [dbo].[fact_demand_total]
        SET
            [dim_factory_id_original] = [dim_factory_id]
        WHERE
            [dim_pdas_id] = @pdasid

        -- Variable declarations
        DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')

        DECLARE @etl_month_date_id int
		SET @etl_month_date_id = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (DATEADD(MONTH, (DATEDIFF(MONTH, 0, (SELECT [full_date] FROM [dbo].[dim_date] WHERE [id] = (SELECT [etl_date_id] FROM [dbo].[dim_pdas] WHERE id = @dim_pdas_id)))), 0)))

		DECLARE @cursor_01 CURSOR
		DECLARE @cursor_02 CURSOR
		DECLARE @cursor_03 CURSOR
		DECLARE @cursor_04 CURSOR

		DECLARE @year_month_date_id_01 int

		DECLARE @dim_factory_id_02 int
		DECLARE @dim_factory_short_name_02 nvarchar(30)
		DECLARE @net_capacity_units_02 int

		DECLARE @dim_product_id_03 int
		DECLARE @dim_product_style_03 nvarchar(30)
		DECLARE @dim_market_id_03 int
		DECLARE @dim_location_category_03 nvarchar(15)
		DECLARE @dim_demand_category_id_03 nvarchar(15)

		DECLARE @dim_factory_alternative_id_04 int
		DECLARE @dim_factory_alternative_short_name_04 nvarchar(30)
		DECLARE @factory_capacity_04 int
		DECLARE @factory_allocated_demand_04 int
		DECLARE @factory_reallocated_demand_04 int
		DECLARE @allocation_priority_04 int
		DECLARE @dim_product_style_04 nvarchar(30)
		DECLARE @was_allocated_04 tinyint


        /* CURSOR 01 START: Loop through consumed demand year/month values ordered chronologically */

			/* CURSOR 02 START: Loop through factory list for given year/month value ordered by capacity DESC */

			IF OBJECT_ID('tempdb..#select_cursor02') IS NOT NULL
			 BEGIN
				DROP TABLE #select_cursor02;
			 END

			CREATE TABLE #select_cursor02 (
				year_month_date_id INT,
				dim_factory_id INT,
				net_capacity_units INT
			)
			CREATE INDEX idx_select_cursor02 ON #select_cursor02(year_month_date_id, dim_factory_id, net_capacity_units);

			INSERT INTO #select_cursor02(year_month_date_id,dim_factory_id,net_capacity_units)
			SELECT
				[year_month_date_id],
				[dim_factory_id],
				SUM([net_capacity_units]) as net_capacity_units
			FROM
				[dbo].[fact_factory_capacity] f
				INNER JOIN (SELECT [id] FROM [dbo].[dim_factory] WHERE [product_line] = 'Shoes') df
					ON f.[dim_factory_id] = df.[id]
			WHERE
				[dim_rccp_id] = @dim_rccp_id
				and [year_month_date_id] >= @etl_month_date_id
			GROUP BY [year_month_date_id], [dim_factory_id]
			;


			SET @cursor_02 = CURSOR FAST_FORWARD FOR
			SELECT
				[year_month_date_id],
				[dim_factory_id],
				[net_capacity_units]
			FROM #select_cursor02
			ORDER BY [year_month_date_id], [net_capacity_units] DESC

			OPEN @cursor_02
			FETCH NEXT FROM @cursor_02
			INTO @year_month_date_id_01, @dim_factory_id_02, @net_capacity_units_02
			WHILE @@FETCH_STATUS = 0
			BEGIN


            END


    END



END
