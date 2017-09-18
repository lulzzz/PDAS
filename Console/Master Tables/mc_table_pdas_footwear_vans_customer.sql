USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the customer master.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_customer]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_customer]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL(temp.[Country], '') + ' / ' +
                ISNULL(temp.[Name], '') + ' / ' +
                ISNULL(temp.[Market], '') + ' / ' +
                ISNULL(temp.[Sold to Party], '') + ' / ' +
				ISNULL(temp.[Sold to Category], '') + ' / ' +
                ISNULL(temp.[Status], '') + ' / ' +
                ISNULL(temp.[Is Placeholder], '') + ' / ' +
                ISNULL(temp.[Placeholder Level], '')
			FROM
				[dbo].[mc_temp_pdas_footwear_vans_customer] temp
				LEFT JOIN (SELECT DISTINCT [country], 1 as flag FROM [dbo].[dim_location]) dim_l
					ON 	UPPER(temp.[Country]) = UPPER(dim_l.[country])
			WHERE
				ISNULL(dim_l.[flag],0) = 0 OR
				UPPER(temp.[Status]) NOT IN ('ACTIVE', 'INACTIVE')
		)

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Name] ORDER BY [Name])
				FROM [dbo].[mc_temp_pdas_footwear_vans_customer]
			) x
			WHERE rn > 1;

			-- Delete removed rows (secured by PK constraint)
			DELETE dim
			FROM
				[dbo].[dim_customer] dim
				LEFT OUTER JOIN [dbo].[mc_temp_pdas_footwear_vans_customer] temp
					ON	dim.[id] = temp.[id]
			WHERE temp.[id] IS NULL

			-- Insert new rows
			INSERT INTO [dbo].[dim_customer]
			(
                [dim_location_id]
                ,[name]
                ,[market]
                ,[sold_to_party]
				,[sold_to_category]
                ,[is_active]
                ,[is_placeholder]
                ,[placeholder_level]
			)
			SELECT
				dim_l.[id] AS [dim_location_id]
                ,temp.[Name] AS [name]
                ,temp.[Market] AS [market]
                ,temp.[Sold to Party] AS [sold_to_party]
				,temp.[Sold to Category] AS [sold_to_category]
                ,CASE UPPER(temp.[Status])
					WHEN 'ACTIVE' THEN 1
					ELSE 0
				END AS [is_active]
                ,CASE UPPER(temp.[Is Placeholder])
					WHEN 'YES' THEN 1
					ELSE 0
				END AS [is_placeholder]
                ,temp.[Placeholder Level] AS [placeholder_level]

			FROM
				[dbo].[mc_temp_pdas_footwear_vans_customer] temp
				INNER JOIN (SELECT [id], [country] FROM [dbo].[dim_location]) dim_l
					ON temp.[Country] = dim_l.[country]
				LEFT JOIN [dbo].[dim_customer] dim_f
					ON temp.[id] = dim_f.[id]
			WHERE dim_f.[id] IS NULL

			-- Update existing rows
			UPDATE dim
			SET
				dim.[dim_location_id] = dim_l.[id]
                ,dim.[name] = temp.[Name]
                ,dim.[market] = temp.[Market]
                ,dim.[sold_to_party] = temp.[Sold to Party]
				,dim.[sold_to_category] = temp.[Sold to Category]
                ,dim.[is_active] = CASE UPPER(temp.[Status])
					WHEN 'ACTIVE' THEN 1
					ELSE 0
				END
                ,dim.[is_placeholder] = CASE UPPER(temp.[Is Placeholder])
					WHEN 'YES' THEN 1
					ELSE 0
				END
                ,dim.[placeholder_level] = temp.[Placeholder Level]
			FROM
				[dbo].[dim_customer] dim
				INNER JOIN [dbo].[mc_temp_pdas_footwear_vans_customer] temp
					ON	dim.[id] = temp.[id]
				INNER JOIN (SELECT [id], [country] FROM [dbo].[dim_location]) dim_l
					ON temp.[Country] = dim_l.[country]

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
