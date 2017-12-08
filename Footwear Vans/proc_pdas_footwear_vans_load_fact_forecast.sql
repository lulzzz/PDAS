USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Description:	Procedure to load the forecast in fact_forecast.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_forecast]
	@pdasid INT,
	@businessid INT,
	@buying_program_id INT
AS
BEGIN

	-- Placeholder
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')
	DECLARE @dim_customer_id_placeholder_emea int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'EMEA')
	DECLARE @dim_customer_id_placeholder_apac int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'Region' and [name] = 'APAC')
	DECLARE @dim_product_id_placeholder int = (SELECT [id] FROM [dbo].[dim_product] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'FUAC/SMU' and [material_id] = 'FUAC/SMU' and [size] = 'FUAC/SMU')


	-- Check if the session has already been loaded
	IF EXISTS (SELECT 1 FROM [dbo].[fact_forecast] WHERE dim_pdas_id = @pdasid AND dim_business_id = @businessid AND dim_buying_program_id = @buying_program_id)
	BEGIN
		DELETE FROM [dbo].[fact_forecast] WHERE dim_pdas_id = @pdasid AND dim_business_id = @businessid AND dim_buying_program_id = @buying_program_id;
	END

	-- Insert from staging
	INSERT INTO [dbo].[fact_forecast](dim_pdas_id, dim_business_id, dim_buying_program_id, dim_product_id, dim_date_id, dim_customer_id, dim_factory_id, quantity)

	-- APAC
	-- Providing their forecast based on BUY months
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_apac
		END as dim_customer_id,
		@dim_factory_id_placeholder as dim_factory_id,
		sum(quantity) as quantity
	FROM
		[dbo].[staging_pdas_footwear_vans_apac_forecast] nf
		LEFT OUTER JOIN
		(
			SELECT id, material_id
			FROM [dbo].[dim_product] dp
			WHERE
				dp.is_placeholder = 1 AND
				dp.placeholder_level = 'material_id'
		) dp
			ON nf.dim_product_material_id = dp.material_id
		INNER JOIN
		(
			SELECT [season_year_short_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_short_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_short_buy] = SUBSTRING(nf.month_label, 1, 4)
			AND dd.month_name_short_accounting = SUBSTRING(nf.month_label, 6, 3)

		LEFT OUTER JOIN
		(
			SELECT id, name
			FROM [dbo].[dim_customer]
		) dc
			ON nf.[dim_customer_dc_sr_code] = dc.name

	WHERE
		quantity IS NOT NULL
	GROUP BY
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END,
		dd.id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_apac
		END


	-- EMEA
	-- Providing their forecast based on CRD months for XDC (i.e. EU DC order) and CRD month + 1 for XF (i.e. EU Direct orders)
	UNION
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_emea
		END as dim_customer_id,
		@dim_factory_id_placeholder as dim_factory_id,
		sum(quantity) as quantity
	FROM
		[dbo].[staging_pdas_footwear_vans_emea_forecast] nf
		LEFT OUTER JOIN
		(
			SELECT id, material_id
			FROM [dbo].[dim_product] dp
			WHERE
				dp.is_placeholder = 1 AND
				dp.placeholder_level = 'material_id'
		) dp
			ON nf.dim_product_material_id = dp.material_id

		LEFT OUTER JOIN
		(
			SELECT id, name
			FROM [dbo].[dim_customer]
		) dc
			ON nf.customer_type = dc.name

		INNER JOIN
		(
			SELECT [season_year_short_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_short_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_short_buy] = nf.season
			AND dd.month_name_short_accounting = nf.plan_month
		WHERE
			quantity IS NOT NULL
		GROUP BY
			CASE
				WHEN dp.id IS NOT NULL THEN dp.id
				ELSE @dim_product_id_placeholder
			END,
			dd.id,
			CASE
				WHEN dc.id IS NOT NULL THEN dc.id
				ELSE @dim_customer_id_placeholder_emea
			END

	-- NORA (we pull intro month 2 months forward to reach CRD)
	UNION
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		dc.id as dim_customer_id,
		@dim_factory_id_placeholder as dim_factory_id,
		sum(quantity) as quantity
	FROM
		[dbo].[staging_pdas_footwear_vans_nora_forecast] nf
		INNER JOIN
		(
			SELECT max([id]) as id, [market]
			FROM [dbo].[dim_customer]
			GROUP BY market
		) dc
			ON nf.[dim_region_region] = dc.[market]
		LEFT OUTER JOIN
		(
			SELECT id, material_id
			FROM [dbo].[dim_product]
			WHERE
				is_placeholder = 1 AND
				placeholder_level = 'material_id'
		) dp
			ON nf.dim_product_material_id = dp.material_id
		INNER JOIN
		(
			SELECT [season_year_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_buy] = nf.season
			AND dd.month_name_short_accounting = nf.plan_month
	WHERE
		quantity IS NOT NULL
	GROUP BY
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END,
		dd.id,
		dc.id

END
