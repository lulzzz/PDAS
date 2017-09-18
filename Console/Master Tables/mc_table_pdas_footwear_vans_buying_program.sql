USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the buying program master.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_buying_program]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_buying_program]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL(temp.[Purchasing Organization], '') + ' / ' +
                ISNULL(temp.[Product Category], '') + ' / ' +
				ISNULL(temp.[Category], '') + ' / ' +
				ISNULL(temp.[Name], '')
			FROM
                [dbo].[mc_temp_pdas_footwear_vans_buying_program] temp
                LEFT JOIN (SELECT DISTINCT [brand], [product_line], 1 as flag FROM [dbo].[dim_business]) dim_b
                    ON 	temp.[Purchasing Organization] = dim_b.[brand]
                        AND temp.[Product Category] = dim_b.[product_line]
            WHERE
                ISNULL(dim_b.[flag],0) = 0 OR
                LEN([Name]) < 2
		)

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Purchasing Organization], [Product Category], [Name] ORDER BY [Purchasing Organization], [Product Category], [Name])
				FROM [dbo].[mc_temp_pdas_footwear_vans_buying_program]
			) x
			WHERE rn > 1;

			-- Delete removed rows (secured by PK constraint)
			DELETE dim
			FROM
				[dbo].[dim_buying_program] dim
				LEFT OUTER JOIN (
					SELECT temp.*
					FROM
						[dbo].[mc_temp_pdas_footwear_vans_buying_program] temp
						INNER JOIN (SELECT [id], [brand], [product_line] FROM [dbo].[dim_business]) dim_b
							ON 	temp.[Purchasing Organization] = dim_b.[brand]
								AND temp.[Product Category] = dim_b.[product_line]
				) temp
					ON	dim.[id] = temp.[id]
			WHERE temp.[id] IS NULL

			-- Insert new rows
			INSERT INTO [dbo].[dim_buying_program]
            (
                [dim_business_id]
				,[category]
                ,[name]
            )
            SELECT
				dim_b.[id] AS [dim_business_id]
				,temp.[Category] AS [category]
				,temp.[Name] AS [name]
			FROM
				[dbo].[mc_temp_pdas_footwear_vans_buying_program] temp
				INNER JOIN (SELECT [id], [brand], [product_line] FROM [dbo].[dim_business]) dim_b
					ON 	temp.[Purchasing Organization] = dim_b.[brand]
						AND temp.[Product Category] = dim_b.[product_line]
				LEFT JOIN [dbo].[dim_buying_program] dim_bp
					ON temp.[id] = dim_bp.[id]
			WHERE dim_bp.[id] IS NULL

			-- Update existing rows
			UPDATE dim
			SET
                dim.[dim_business_id] = dim_b.[id]
				,dim.[category] = temp.[Category]
				,dim.[name] = temp.[Name]
			FROM
				[dbo].[dim_buying_program] dim
				INNER JOIN [dbo].[mc_temp_pdas_footwear_vans_buying_program] temp
					ON	dim.[id] = temp.[id]
                INNER JOIN (SELECT [id], [brand], [product_line] FROM [dbo].[dim_business]) dim_b
					ON 	temp.[Purchasing Organization] = dim_b.[brand]
						AND temp.[Product Category] = dim_b.[product_line]

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
