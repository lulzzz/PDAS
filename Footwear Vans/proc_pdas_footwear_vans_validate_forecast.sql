USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Backend procedure to validate the staging area forecasting tables and generate a validatio report.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_validate_forecast]
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


    /* APAC */

	SET @source = 'APAC Forecast';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Market not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_market_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_market_name] FROM [dbo].[staging_pdas_footwear_vans_apac_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_customer]
        ) dim
			ON staging.[dim_market_name] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [type] = 'Customer Master'
        ) mapping
			ON staging.[dim_market_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_apac_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id]
            FROM [dbo].[dim_product]
        ) dim
			ON staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

    -- Check short_name from dim_factory
    SET @type = 'Factory short name not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_factory_short_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_factory_short_name] FROM [dbo].[staging_pdas_footwear_vans_apac_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[dim_factory_short_name] = dim.[short_name]
	WHERE
		dim.[short_name] IS NULL


    /* US */

    SET @source = 'NORA Forecast';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Region not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_region_region], '') as [value]
	FROM
		(SELECT DISTINCT [dim_region_region] FROM [dbo].[staging_pdas_footwear_vans_nora_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_customer]
            WHERE
                [is_placeholder] = 1
                AND [placeholder_level] = 'Region'
        ) dim
			ON staging.[dim_region_region] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [type] = 'Customer Master'
        ) mapping
			ON staging.[dim_region_region] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_nora_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id]
            FROM [dbo].[dim_product]
        ) dim
			ON staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

    -- Check season_year_accounting and month_name_short_accounting from dim_date
    SET @type = 'Season/Plan Month combination not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL(staging.[season], '') + '/' + ISNULL(staging.[plan_month], '') as [value]
	FROM
		(SELECT DISTINCT [season], [plan_month] FROM [dbo].[staging_pdas_footwear_vans_nora_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [season_year_accounting]
                ,[month_name_short_accounting]
            FROM [dbo].[dim_date]
        ) dim
			ON   staging.[season] = dim.[season_year_accounting]
                AND staging.[plan_month] = dim.[month_name_short_accounting]
	WHERE
		dim.[season_year_accounting] IS NULL


    /* EMEA */

    SET @source = 'EMEA Forecast';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_emea_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id]
            FROM [dbo].[dim_product]
        ) dim
			ON staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

    -- Check season_year_accounting and month_name_short_accounting from dim_date
    SET @type = 'Season/Plan Month combination not in master data';
  	INSERT INTO [dbo].[system_log_file] (system, source, type, value)
  	SELECT DISTINCT @system, @source, @type, ISNULL(staging.[season], '') + '/' + ISNULL(staging.[plan_month], '') as [value]
  	FROM
  		(SELECT DISTINCT [season], [plan_month] FROM [dbo].[staging_pdas_footwear_vans_emea_forecast]) staging
          LEFT OUTER JOIN
          (
              SELECT DISTINCT
                  [season_year_short_accounting]
                  ,[month_name_short_accounting]
              FROM [dbo].[dim_date]
          ) dim
  			ON   staging.[season] = dim.[season_year_short_accounting]
                  AND staging.[plan_month] = dim.[month_name_short_accounting]
  	WHERE
  		dim.[season_year_short_accounting] IS NULL


END
