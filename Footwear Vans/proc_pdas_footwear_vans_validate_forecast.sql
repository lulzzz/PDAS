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

	SET @source = 'PDAS_FTW_VANS_APAC_FORECAST.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Customer not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
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
            WHERE [category] = 'Customer Master'
        ) mapping
			ON staging.[dim_market_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
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
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
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

	-- Buy month
    SET @type = 'Buy Month not in master data';
  	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
  	SELECT DISTINCT @system, @source, @type, ISNULL(SUBSTRING(staging.month_label, 1, 4), '') + '/' + ISNULL(SUBSTRING(staging.month_label, 6, 3), '') as [value]
  	FROM
  		(SELECT DISTINCT [month_label] FROM [dbo].[staging_pdas_footwear_vans_apac_forecast]) staging
      	LEFT OUTER JOIN
		(
			SELECT [season_year_short_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_short_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_short_buy] = SUBSTRING(staging.month_label, 1, 4)
			AND dd.month_name_short_accounting = SUBSTRING(staging.month_label, 6, 3)
  	WHERE
  		dd.[season_year_short_buy] IS NULL


    /* NORA */

    SET @source = 'PDAS_FTW_VANS_NORA_FORECAST.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Market not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_region_region], '') as [value]
	FROM
		(SELECT DISTINCT [dim_region_region] FROM [dbo].[staging_pdas_footwear_vans_nora_forecast]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [market]
            FROM [dbo].[dim_customer]
        ) dim
			ON staging.[dim_region_region] = dim.[market]
	WHERE
		(dim.[market] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
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

	-- Buy month
    SET @type = 'Buy Month not in master data';
  	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
  	SELECT DISTINCT @system, @source, @type, ISNULL(staging.[season], '') + '/' + ISNULL(staging.[plan_month], '') as [value]
  	FROM
  		(SELECT DISTINCT [season], [plan_month] FROM [dbo].[staging_pdas_footwear_vans_nora_forecast]) staging
      	LEFT OUTER JOIN
		(
			SELECT [season_year_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_buy] = staging.season
			AND dd.month_name_short_accounting = staging.plan_month
	WHERE
		dd.[season_year_buy] IS NULL


    /* EMEA */

    SET @source = 'PDAS_FTW_VANS_EMEA_FORECAST.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
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

    -- Buy month
    SET @type = 'Buy Month not in master data';
  	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
  	SELECT DISTINCT @system, @source, @type, ISNULL(staging.[season], '') + '/' + ISNULL(staging.[plan_month], '') as [value]
  	FROM
  		(SELECT DISTINCT [season], [plan_month], [customer_type] FROM [dbo].[staging_pdas_footwear_vans_emea_forecast]) staging
      	LEFT OUTER JOIN
		(
			SELECT [season_year_short_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_short_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_short_buy] = staging.season
			AND dd.month_name_short_accounting = staging.plan_month
  	WHERE
  		dd.[season_year_short_buy] IS NULL


END
