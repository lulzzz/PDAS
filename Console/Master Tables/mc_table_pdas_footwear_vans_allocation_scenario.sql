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
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_allocation_scenario_vfa]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL(temp.[id], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa]  temp
                LEFT JOIN (SELECT DISTINCT [brand], [product_line], 1 as flag FROM [dbo].[dim_business]) dim_b
                    ON 	temp.[Purchasing Organization] = dim_b.[brand]
                        AND temp.[Product Category] = dim_b.[product_line]
                LEFT JOIN (SELECT DISTINCT [name], 1 as flag FROM [dbo].[dim_pdas]) dim_pdas
                    ON 	temp.[PDAS Release Name] = dim_pdas.[name]
                LEFT JOIN (SELECT [material_id], [size], 1 as flag FROM [dbo].[dim_product]) dim_p
                    ON  temp.[MTL] = dim_p.[material_id]
                        AND temp.[size] = dim_p.[size]
                LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) dim_f1
                    ON 	UPPER(temp.[Factory PDAS]) = UPPER(dim_f1.[short_name])
                LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) dim_f2
                    ON 	UPPER(temp.[Factory User]) = UPPER(dim_f2.[short_name])
                LEFT JOIN (SELECT DISTINCT [name], 1 as flag FROM [dbo].[dim_buying_program]) dim_bp
                    ON 	UPPER(temp.[Buying Program]) = UPPER(dim_bp.[name])
                LEFT JOIN (SELECT DISTINCT [year_cw_accounting], [year_month_accounting], 1 as flag FROM [dbo].[dim_date]) dim_d
                    ON 	UPPER(temp.[Accounting Year CW]) = UPPER(dim_d.[year_cw_accounting])
                        AND UPPER(temp.[Accounting Year Month]) = UPPER(dim_d.[year_month_accounting])
                LEFT JOIN (SELECT [name], 1 as flag FROM [dbo].[dim_customer]) dim_c
                    ON 	UPPER(temp.[Customer]) = UPPER(dim_c.[name])
                LEFT JOIN (SELECT [name], 1 as flag FROM [dbo].[dim_demand_category]) dim_dst
                    ON 	UPPER(temp.[Demand Signal Type]) = UPPER(dim_c.[name])
            WHERE
				ISNULL(dim_b.[flag], 0) = 0 OR
                ISNULL(dim_pdas.[flag], 0) = 0 OR
                ISNULL(dim_f1.[flag], 0) = 0 OR
                ISNULL(dim_f2.[flag], 0) = 0 OR
                ISNULL(dim_bp.[flag], 0) = 0 OR
                ISNULL(dim_d.[flag], 0) = 0 OR
                ISNULL(dim_c.[flag], 0) = 0 OR
                ISNULL(dim_dst.[flag], 0) = 0 OR
                temp.[Quantity Unconsumed PDAS] < temp.[Quantity Consumed PDAS] OR
                (
                    [Factory PDAS] <> [Factory User] AND LEN(ISNULL([Comment], '')) = 0
                ) OR
                (
                    [Quantity Consumed PDAS] <> [Quantity User] AND LEN(ISNULL([Comment], '')) = 0
                )
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [id] ORDER BY [id])
				FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
				DELETE dim
				FROM
					[dbo].[helper_pdas_footwear_vans_allocation_scenario] dim
					LEFT JOIN [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa] temp
						ON	dim.[id] = temp.[id]
				WHERE temp.[id] IS NULL

				-- Insert new rows
				INSERT INTO [dbo].[helper_pdas_footwear_vans_allocation_scenario]
				(
					[PDAS Release Name]
					,[Purchasing Organization]
					,[Product Category]
					,[Buying Program]
					,[MTL]
					,[Size]
					,[Accounting Year CW]
					,[Accounting Year Month]
					,[Customer]
					,[Demand Signal Type]
					,[Order Number]
					,[Factory PDAS]
					,[Quantity Unconsumed PDAS]
					,[Quantity Consumed PDAS]
					,[Factory User]
					,[Quantity User]
					,[Comment]
				)
				SELECT
					[PDAS Release Name]
					,[Purchasing Organization]
					,[Product Category]
					,[Buying Program]
					,[MTL]
					,[Size]
					,[Accounting Year CW]
					,[Accounting Year Month]
					,[Customer]
					,[Demand Signal Type]
					,[Order Number]
					,[Factory PDAS]
					,[Quantity Unconsumed PDAS]
					,[Quantity Consumed PDAS]
					,[Factory User]
					,[Quantity User]
					,[Comment]
				FROM
					[dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa] temp
					LEFT JOIN (SELECT [id] FROM [dbo].[helper_pdas_footwear_vans_allocation_scenario]) dim
						ON temp.[id] = dim.[id]
				WHERE dim.[id] IS NULL

				-- Update existing rows
				UPDATE dim
				SET
					dim.[Factory User] = temp.[Factory User]
					,dim.[Quantity User] = temp.[Quantity User]
					,dim.[Comment] = temp.[Comment]
				FROM
					[dbo].[helper_pdas_footwear_vans_allocation_scenario] dim
					INNER JOIN [dbo].[mc_temp_pdas_footwear_vans_allocation_scenario_vfa] temp
						ON	dim.[id] = temp.[id]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated ID. Not allowed by PDAS.'
    			RETURN -999

    		END

		END
		ELSE
		BEGIN

			SET @output_param = 'Row ' + @test + ' is invalid.' + '<br />' +
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
