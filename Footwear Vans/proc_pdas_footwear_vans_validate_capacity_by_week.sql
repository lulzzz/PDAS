USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Backend procedure to validate the staging area weekly capacity table and generate a validatio report.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_validate_capacity_by_week]
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


	SET @source = 'PDAS_FTW_VANS_WEEKLY_CAPACITY.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check short_name from dim_factory
    SET @type = 'Factory short name not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_factory_short_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_factory_short_name] FROM [dbo].[staging_pdas_footwear_vans_capacity_by_week]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[dim_factory_short_name] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [type] = 'Factory Master'
        ) mapping
			ON staging.[dim_factory_short_name] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)


	-- Check name from dim_construction_type
    SET @type = 'Construction type not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_construction_type_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_construction_type_name] FROM [dbo].[staging_pdas_footwear_vans_capacity_by_week]) staging
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
            WHERE [type] = 'Construction Type Master'
        ) mapping
			ON staging.[dim_construction_type_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)


END
