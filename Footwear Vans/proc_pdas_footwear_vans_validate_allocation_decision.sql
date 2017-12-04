USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Backend procedure to validate the staging area decision tables for vendor, region and VFA.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_validate_allocation_decision]
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


	SET @source = 'PDAS Allocation Decision VFA.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source


    -- Check short_name from dim_factory for alloc_1
    SET @type = 'Factory Code VFA not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([Factory Code VFA], '') as [value]
	FROM
		(SELECT DISTINCT [Factory Code VFA] FROM [dbo].[staging_pdas_footwear_vans_allocation_report_vfa]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[Factory Code VFA] = dim.[short_name]
	WHERE dim.[short_name] IS NULL

	-- Check comments
    SET @type = 'Missing comment VFA';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([Allocation Comment (VFA)], '') as [value]
	FROM
		(SELECT DISTINCT [Factory Code VFA], [Allocation Comment (VFA)], [Factory Code (Constrained)] FROM [dbo].[staging_pdas_footwear_vans_allocation_report_vfa]) staging
	WHERE
		(staging.[Factory Code (Constrained)] <> staging.[Factory Code VFA] AND staging.[Allocation Comment (VFA)] IS NULL)

END
