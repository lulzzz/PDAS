USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the vendor master.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_factory]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_factory]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
				ISNULL(temp.[Purchasing Organization], '') + ' / ' +
				ISNULL(temp.[Product Category], '') + ' / ' +
				ISNULL(temp.[Country], '') + ' / ' +
				ISNULL(temp.[Short Name], '') + ' / ' +
				ISNULL(temp.[Status], '')
			FROM
				[dbo].[mc_temp_pdas_footwear_vans_factory] temp
				LEFT JOIN (SELECT DISTINCT [country], 1 as flag FROM [dbo].[dim_location]) dim_l
					ON 	UPPER(temp.[Country]) = UPPER(dim_l.[country])
				LEFT JOIN (SELECT DISTINCT [brand], [product_line], 1 as flag FROM [dbo].[dim_business]) dim_b
					ON 	temp.[Purchasing Organization] = dim_b.[brand]
						AND temp.[Product Category] = dim_b.[product_line]
			WHERE
				ISNULL(dim_b.[flag],0) = 0 OR
				ISNULL(dim_l.[flag],0) = 0 OR
				UPPER(temp.[Status]) NOT IN ('ACTIVE', 'INACTIVE')
		)

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Purchasing Organization], [Product Category], [Short Name] ORDER BY [Purchasing Organization], [Product Category], [Short Name])
				FROM [dbo].[mc_temp_pdas_footwear_vans_factory]
			) x
			WHERE rn > 1;

			-- Delete removed rows (secured by PK constraint)
			DELETE dim
			FROM
				(
					SELECT *
					FROM [dbo].[dim_factory]
					WHERE [is_placeholder] = 0
				) dim
				LEFT OUTER JOIN (
					SELECT temp.*
					FROM
						[dbo].[mc_temp_pdas_footwear_vans_factory] temp
						INNER JOIN (SELECT [id], [brand], [product_line] FROM [dbo].[dim_business]) dim_b
							ON 	temp.[Purchasing Organization] = dim_b.[brand]
								AND temp.[Product Category] = dim_b.[product_line]
				) temp
					ON	dim.[id] = temp.[id]
			WHERE temp.[id] IS NULL

			-- Insert new rows
			INSERT INTO [dbo].[dim_factory]
			(
				[dim_business_id]
				,[dim_location_id]
				,[vendor_group]
				,[short_name]
				,[long_name]
				,[port]
				,[is_active]
				,[is_placeholder]
				,[placeholder_level]
				,[allocation_group]
				,[valid_acadia_fty_plant_code]
				,[valid_acadia_vendor_code_1505_1510]
				,[valid_acadia_vendor_code_1550_mexico]
				,[condor_factory_code_brazil]
				,[condor_vendor_code_brazil]
				,[condor_factory_code_chile]
				,[condor_vendor_code_chile]
				,[eu_supplier_code]
				,[reva_vendor_fty]
				,[reva_agent_vendor]
			)
			SELECT
				dim_b.[id] AS [dim_business_id]
				,dim_l.[id] AS [dim_location_id]
				,temp.[Vendor Group] AS [vendor_group]
				,temp.[Short Name] AS [short_name]
				,temp.[Long Name] AS [long_name]
				,temp.[Port] AS [port]
				,CASE UPPER(temp.[Status])
					WHEN 'ACTIVE' THEN 1
					ELSE 0
				END as [is_active]
				,0 [is_placeholder]
                ,NULL AS [placeholder_level]
				,temp.[Allocation Group] AS [allocation_group]
				,temp.[Valid Acadia FTY Plant code]
				,temp.[Valid Acadia Vendor code (1505/1510)]
				,temp.[Valid Acadia Vendor code (1550 Mexico)]
				,temp.[CONDOR Factory Code (Brazil)]
				,temp.[CONDOR Vendor Code (Brazil)]
				,temp.[CONDOR Factory Code (Chile)]
				,temp.[CONDOR Vendor Code (Chile)]
				,temp.[EU Supplier Code]
				,temp.[Reva Vendor (FTY)]
				,temp.[Reva Agent (Vendor)]
			FROM
				[dbo].[mc_temp_pdas_footwear_vans_factory] temp
				INNER JOIN (SELECT [id], [country] FROM [dbo].[dim_location]) dim_l
					ON temp.[Country] = dim_l.[country]
				INNER JOIN (SELECT [id], [brand], [product_line] FROM [dbo].[dim_business]) dim_b
					ON 	temp.[Purchasing Organization] = dim_b.[brand]
						AND temp.[Product Category] = dim_b.[product_line]
				LEFT JOIN [dbo].[dim_factory] dim_f
					ON temp.[id] = dim_f.[id]
			WHERE dim_f.[id] IS NULL

			-- Update existing rows
			UPDATE dim
			SET
				dim.[dim_business_id] = dim_b.[id]
				,dim.[dim_location_id] = dim_l.[id]
				,dim.[vendor_group] = temp.[Vendor Group]
				,dim.[short_name] = temp.[Short Name]
				,dim.[long_name] = temp.[Long Name]
				,dim.[port] = temp.[Port]
				,dim.[is_active] = 	CASE UPPER(temp.[Status])
										WHEN 'ACTIVE' THEN 1
										ELSE 0
									END
				,dim.[allocation_group] = temp.[Allocation Group]

				,dim.[valid_acadia_fty_plant_code] = temp.[Valid Acadia FTY Plant code]
				,dim.[valid_acadia_vendor_code_1505_1510] = temp.[Valid Acadia Vendor code (1505/1510)]
				,dim.[valid_acadia_vendor_code_1550_mexico] = temp.[Valid Acadia Vendor code (1550 Mexico)]
				,dim.[condor_factory_code_brazil] = temp.[CONDOR Factory Code (Brazil)]
				,dim.[condor_vendor_code_brazil] = temp.[CONDOR Vendor Code (Brazil)]
				,dim.[condor_factory_code_chile] = temp.[CONDOR Factory Code (Chile)]
				,dim.[condor_vendor_code_chile] = temp.[CONDOR Vendor Code (Chile)]
				,dim.[eu_supplier_code] = temp.[EU Supplier Code]
				,dim.[reva_vendor_fty] = temp.[Reva Vendor (FTY)]
				,dim.[reva_agent_vendor] = temp.[Reva Agent (Vendor)]
			FROM
				[dbo].[dim_factory] dim
				INNER JOIN [dbo].[mc_temp_pdas_footwear_vans_factory] temp
					ON	dim.[id] = temp.[id]
				INNER JOIN (SELECT [id], [country] FROM [dbo].[dim_location]) dim_l
					ON temp.[Country] = dim_l.[country]
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
