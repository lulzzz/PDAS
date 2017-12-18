USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Backend procedure to validate the staging area priority list and generate a validatio report.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_validate_priority_list]
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


	SET @source = 'PDAS_FTW_VANS_PRIORITY_LIST.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source


    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_priority_list]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id]
            FROM [dbo].[dim_product]
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

    -- Check short_name from dim_factory for alloc_1
    SET @type = 'Factory short name not in master data (1st Priority)';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([alloc_1], '') as [value]
	FROM
		(SELECT DISTINCT [alloc_1] FROM [dbo].[staging_pdas_footwear_vans_priority_list]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[alloc_1] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Factory Master'
        ) mapping
			ON staging.[alloc_1] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)

	-- Check short_name from dim_factory for alloc_2
    SET @type = 'Factory short name not in master data (2nd Priority)';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([alloc_2], '') as [value]
	FROM
		(SELECT DISTINCT [alloc_2] FROM [dbo].[staging_pdas_footwear_vans_priority_list]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[alloc_2] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Factory Master'
        ) mapping
			ON staging.[alloc_2] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)


	-- Check name from dim_construction_type
    SET @type = 'Construction type not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_construction_type_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_construction_type_name] FROM [dbo].[staging_pdas_footwear_vans_priority_list]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_construction_type]
        ) dim
			ON staging.[dim_construction_type_name] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Construction Type Master'
        ) mapping
			ON staging.[dim_construction_type_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)


	-- Check dim_product_style_complexity from hard coded valid list
    SET @type = 'Style complexity not valid';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_construction_type_name], '') as [value]
	FROM
		[dbo].[staging_pdas_footwear_vans_priority_list]
	WHERE
		[dim_product_style_complexity] NOT IN
		(
			'Flex',
			'Complex',
			'Basic',
			'Standard',
			'Flex 2'
		)


END
