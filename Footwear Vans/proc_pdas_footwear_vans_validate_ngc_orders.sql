USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Backend procedure to validate the staging area NGC FGPO table and generate a validatio report.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_validate_ngc_orders]
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

    /* Declare variables */

    DECLARE	@current_date date = GETDATE()

	DECLARE @dim_pdas_id int
	SELECT @dim_pdas_id = MAX(id) FROM [dbo].[dim_pdas];


	DECLARE @system nvarchar(15) = 'pdas_ftw_vans'
	DECLARE @source	nvarchar(45)
	DECLARE @type nvarchar(100)


	SET @source = 'NGC SQL Extract';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Customer not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_customer_dc_code_brio], '') as [value]
	FROM
		(SELECT DISTINCT [dim_customer_dc_code_brio] FROM [dbo].[staging_pdas_footwear_vans_ngc_po]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_customer]
        ) dim
			ON staging.[dim_customer_dc_code_brio] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [type] = 'Customer Master'
        ) mapping
			ON staging.[dim_customer_dc_code_brio] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_style_id], '') + '/' + ISNULL([dim_product_size], '') as [value]
	FROM
		(SELECT DISTINCT [dim_product_style_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_ngc_po]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id], [size]
            FROM [dbo].[dim_product]
        ) dim
			ON  staging.[dim_product_style_id] = dim.[material_id]
                AND staging.[dim_product_size] = dim.[size]
	WHERE
		dim.[material_id] IS NULL

    -- Check short_name from dim_factory
    SET @type = 'Factory short name not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_factory_factory_code], '') as [value]
	FROM
		(SELECT DISTINCT [dim_factory_factory_code] FROM [dbo].[staging_pdas_footwear_vans_ngc_po]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[dim_factory_factory_code] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [type] = 'Factory Master'
        ) mapping
			ON staging.[dim_factory_factory_code] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)


END
