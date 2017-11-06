USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the allocation sandbox.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_allocation_scenario_vfa_ntb]
	@output_param nvarchar(500) OUTPUT,
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa_ntb]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL(temp.[id], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa_ntb]  temp
                LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) df
                    ON 	UPPER(temp.[Factory Code]) = UPPER(df.[short_name])
            WHERE
				ISNULL(df.[flag], 0) = 0 OR
                (
                    [Factory Code] <> [Factory Code (Constrained Scenario)] AND LEN(ISNULL([VFA Comment], '')) = 0
                )
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa_ntb])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [id] ORDER BY [id])
				FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa_ntb]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa_ntb])

            IF @table_count_before = @table_count_after
            BEGIN

				-- Declare variables
				DECLARE	@current_dt datetime = GETDATE()

				-- Update fact_demand_total
				UPDATE target
				SET
					target.[dim_factory_id] = temp.[dim_factory_id]
					,target.[comment] = temp.[VFA Comment]
					,target.[edit_username] = @mc_user_name
					,target.[edit_dt] = @current_dt
				FROM
					(
						SELECT
							*
							,CONVERT(NVARCHAR(100), CONVERT(NVARCHAR(10), dim_buying_program_id) + '-' + CONVERT(NVARCHAR(10), dim_demand_category_id) + '-' + CONVERT(NVARCHAR(10), dim_product_id) + '-' + CONVERT(NVARCHAR(10), dim_date_id) + '-' + CONVERT(NVARCHAR(10), dim_customer_id) + '-' + [order_number]) AS id
						FROM [dbo].[fact_demand_total]
					) as target
					INNER JOIN
					(
						SELECT
							temp.[id]
						    ,temp.[VFA Comment]
						    ,df.[id] as	[dim_factory_id]
						FROM
							[dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa_ntb] temp
							INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
								ON temp.[Factory Code] = df.[short_name]
						WHERE
							[Factory Code] <> [Factory Code (Constrained Scenario)]
					) as temp
						ON	target.[id] = temp.[id]


    			-- Delete removed rows
				DELETE FROM [dbo].[helper_pdas_footwear_vans_allocation_scenario_vfa]

				-- Insert new rows
				INSERT INTO [dbo].[helper_pdas_footwear_vans_allocation_scenario_vfa]
				(
					[dim_buying_program_id]
					,[dim_demand_category_id]
					,[dim_product_id]
					,[dim_date_id]
					,[dim_customer_id]
					,[dim_factory_id]
					,[order_number]
					,[comment]
					,[edit_username]
					,[edit_dt]
				)
				SELECT
					[dim_buying_program_id]
					,[dim_demand_category_id]
					,[dim_product_id]
					,[dim_date_id]
					,[dim_customer_id]
					,[dim_factory_id]
					,[order_number]
					,[comment]
					,[edit_username]
					,[edit_dt]
				FROM
					[dbo].[fact_demand_total]
				WHERE
					[dim_factory_id_original_constrained] <> [dim_factory_id]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated ID. Not allowed by PDAS.'
    			RETURN -999

    		END

		END
		ELSE
		BEGIN

			SET @output_param = 'Row ' + @test + ' is invalid. Changes require a comment.' + '<br />' +
			'Please review the business rules of this table for more details.'
			RETURN -999

		END

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
