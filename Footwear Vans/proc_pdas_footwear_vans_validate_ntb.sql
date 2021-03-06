USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Backend procedure to validate the staging area NTB tables and generate a validatio report.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_validate_ntb]
	@dim_release_id INT
AS
BEGIN
	SET NOCOUNT ON;

    /* Declare variables */

    DECLARE	@current_date date = GETDATE()
	DECLARE @system nvarchar(15) = 'pdas_ftw_vans'
	DECLARE @source	nvarchar(45)
	DECLARE @type nvarchar(100)


    /* APAC */

	SET @source = 'PDAS_FTW_VANS_APAC_NTB.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Customer not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_customer_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_customer_name] FROM [dbo].[staging_pdas_footwear_vans_apac_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_customer]
        ) dim
			ON staging.[dim_customer_name] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Customer Master'
        ) mapping
			ON staging.[dim_customer_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_apac_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id], [size]
            FROM [dbo].[dim_product]
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
                AND staging.[dim_product_size] = dim.[size]
	WHERE
		dim.[material_id] IS NULL

	-- Check material_id from [fact_priority_list]
    SET @type = 'Material ID not in priority list';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_apac_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                dp.[material_id]
			FROM
				[dbo].[fact_priority_list] f
				INNER JOIN [dbo].[dim_product] dp
					ON f.dim_product_id = dp.id
			WHERE
				f.[dim_release_id] = @dim_release_id
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

	-- Check short_name from dim_factory
    SET @type = 'XFD is not a valid date';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL(staging.xfac_dt, '') as [value]
	FROM [dbo].[staging_pdas_footwear_vans_apac_ntb] staging
	WHERE ISDATE(CONVERT(NVARCHAR(23), staging.xfac_dt)) = 0

    -- Check short_name from dim_factory
    SET @type = 'Factory short name not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_factory_reva_vendor], '') as [value]
	FROM
		(SELECT DISTINCT [dim_factory_reva_vendor] FROM [dbo].[staging_pdas_footwear_vans_apac_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[dim_factory_reva_vendor] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Factory Master'
        ) mapping
			ON staging.[dim_factory_reva_vendor] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)


    /* NORA */

	SET @source = 'PDAS_FTW_VANS_NORA_NTB.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Customer not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_customer_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_customer_name] FROM [dbo].[staging_pdas_footwear_vans_nora_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_customer]
        ) dim
			ON staging.[dim_customer_name] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Customer Master'
        ) mapping
			ON staging.[dim_customer_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_nora_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id], [size]
            FROM [dbo].[dim_product]
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
                AND staging.[dim_product_size] = dim.[size]
	WHERE
		dim.[material_id] IS NULL

	-- Check material_id from [fact_priority_list]
    SET @type = 'Material ID not in priority list';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_nora_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                dp.[material_id]
			FROM
				[dbo].[fact_priority_list] f
				INNER JOIN [dbo].[dim_product] dp
					ON f.dim_product_id = dp.id
			WHERE
				f.[dim_release_id] = @dim_release_id
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

    -- Check short_name from dim_factory
    SET @type = 'Factory short name not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_factory_acadia_vendor_code], '') as [value]
	FROM
		(SELECT DISTINCT [dim_factory_acadia_vendor_code] FROM [dbo].[staging_pdas_footwear_vans_nora_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[dim_factory_acadia_vendor_code] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Factory Master'
        ) mapping
			ON staging.[dim_factory_acadia_vendor_code] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)

	-- Check short_name from dim_factory
    SET @type = 'XFD is not a valid date';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL(staging.xfac_dt, '') as [value]
	FROM [dbo].[staging_pdas_footwear_vans_nora_ntb] staging
	WHERE ISDATE(CONVERT(NVARCHAR(23), staging.xfac_dt)) = 0


    /* CASA */

	SET @source = 'PDAS_FTW_VANS_CASA_NTB.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Customer not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_customer_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_customer_name] FROM [dbo].[staging_pdas_footwear_vans_casa_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_customer]
        ) dim
			ON staging.[dim_customer_name] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Customer Master'
        ) mapping
			ON staging.[dim_customer_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

	-- Check short_name from dim_factory
    SET @type = 'XFD is not a valid date';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL(staging.xfac_dt, '') as [value]
	FROM [dbo].[staging_pdas_footwear_vans_casa_ntb] staging
	WHERE ISDATE(CONVERT(NVARCHAR(23), staging.xfac_dt)) = 0

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_casa_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id], [size]
            FROM [dbo].[dim_product]
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
                AND staging.[dim_product_size] = dim.[size]
	WHERE
		dim.[material_id] IS NULL

	-- Check material_id from [fact_priority_list]
    SET @type = 'Material ID not in priority list';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_casa_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                dp.[material_id]
			FROM
				[dbo].[fact_priority_list] f
				INNER JOIN [dbo].[dim_product] dp
					ON f.dim_product_id = dp.id
			WHERE
				f.[dim_release_id] = @dim_release_id
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

    -- Check short_name from dim_factory
    SET @type = 'Factory short name not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([confirmed_vendor_code], '') as [value]
	FROM
		(SELECT DISTINCT [confirmed_vendor_code] FROM [dbo].[staging_pdas_footwear_vans_casa_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[confirmed_vendor_code] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Factory Master'
        ) mapping
			ON staging.[confirmed_vendor_code] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)


    /* EMEA */

	SET @source = 'PDAS_FTW_VANS_EMEA_NTB.xlsx';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check market from dim_customer (and mapping)
	SET @type = 'Customer not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_customer_name], '') as [value]
	FROM
		(SELECT DISTINCT [dim_customer_name] FROM [dbo].[staging_pdas_footwear_vans_emea_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [name]
            FROM [dbo].[dim_customer]
        ) dim
			ON staging.[dim_customer_name] = dim.[name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Customer Master'
        ) mapping
			ON staging.[dim_customer_name] = mapping.[child]
	WHERE
		(dim.[name] IS NULL AND mapping.[parent] IS NULL)

    -- Check material_id from dim_product
    SET @type = 'Material ID not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id], [dim_product_size] FROM [dbo].[staging_pdas_footwear_vans_emea_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [material_id], [size]
            FROM [dbo].[dim_product]
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
                AND staging.[dim_product_size] = dim.[size]
	WHERE
		dim.[material_id] IS NULL

	-- Check material_id from [fact_priority_list]
    SET @type = 'Material ID not in priority list';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([dim_product_material_id], '') as [value]
	FROM
		(SELECT DISTINCT CONVERT(NVARCHAR(11), [dim_product_material_id]) AS [dim_product_material_id] FROM [dbo].[staging_pdas_footwear_vans_emea_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                dp.[material_id]
			FROM
				[dbo].[fact_priority_list] f
				INNER JOIN [dbo].[dim_product] dp
					ON f.dim_product_id = dp.id
			WHERE
				f.[dim_release_id] = @dim_release_id
        ) dim
			ON  staging.[dim_product_material_id] = dim.[material_id]
	WHERE
		dim.[material_id] IS NULL

    -- Check short_name from dim_factory
    SET @type = 'Factory short name not in master data';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL([vendor_name], '') as [value]
	FROM
		(SELECT DISTINCT [vendor_name] FROM [dbo].[staging_pdas_footwear_vans_emea_ntb]) staging
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [short_name]
            FROM [dbo].[dim_factory]
        ) dim
			ON staging.[vendor_name] = dim.[short_name]
        LEFT OUTER JOIN
        (
            SELECT DISTINCT
                [parent]
                ,[child]
            FROM [dbo].[helper_pdas_footwear_vans_mapping]
            WHERE [category] = 'Factory Master'
        ) mapping
			ON staging.[vendor_name] = mapping.[child]
	WHERE
		(dim.[short_name] IS NULL AND mapping.[parent] IS NULL)


	/* Retail Quick Turn Master Table*/

	SET @source = 'Retail Quick Turn Master Table';
	DELETE FROM [dbo].[system_log_file] WHERE [system] = @system and [source] = @source

    -- Check absence of entries: (MTL#, sold-to-party) tuple
	SET @type = 'MTL# sold-to-party missing';
	INSERT INTO [dbo].[system_log_file] (system, source, category, value)
	SELECT DISTINCT @system, @source, @type, ISNULL(CONCAT(reference.[material_id], ' ', reference.[sold_to_party]), '') as [value]
	FROM (
		SELECT mtl.[material_id], stp.[sold_to_party]
		FROM (SELECT DISTINCT [material_id] FROM [VCDWH].[dbo].[helper_pdas_footwear_vans_retail_qt]) mtl
		CROSS JOIN (SELECT DISTINCT [sold_to_party] FROM [VCDWH].[dbo].[helper_pdas_footwear_vans_retail_qt]) stp
		) reference

	WHERE NOT EXISTS(
		SELECT *
		FROM [VCDWH].[dbo].[helper_pdas_footwear_vans_retail_qt] actual
		WHERE actual.[material_id] = reference.[material_id]
		AND actual.[sold_to_party] = reference.[sold_to_party])


END
