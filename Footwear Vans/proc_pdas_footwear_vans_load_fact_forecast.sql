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
	DECLARE @dim_demand_category_id_forecast int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Forecast')

	DECLARE @dim_date_id_buy_month int = (
		SELECT dim_date.[id]
		FROM
		(
			SELECT [id], [buy_month]
			FROM [dbo].[dim_pdas]
			WHERE
				[id] = @pdasid
		) dim_pdas
		INNER JOIN
		(
			SELECT
				MIN([id]) as [id]
				,[year_month_accounting]
			FROM [dbo].[dim_date]
			GROUP BY [year_month_accounting]
		) dim_date
			ON dim_pdas.[buy_month] = dim_date.[year_month_accounting]
	)

	-- Check if the session has already been loaded
	IF EXISTS (SELECT 1 FROM [dbo].[fact_demand_total] WHERE dim_pdas_id = @pdasid AND dim_business_id = @businessid AND dim_buying_program_id = @buying_program_id AND dim_demand_category_id = @dim_demand_category_id_forecast AND is_from_previous_release = 0)
	BEGIN
		DELETE FROM [dbo].[fact_demand_total]
		WHERE dim_pdas_id = @pdasid
		AND dim_business_id = @businessid
		AND dim_buying_program_id = @buying_program_id
		AND dim_demand_category_id = @dim_demand_category_id_forecast
		AND is_from_previous_release = 0
	END

	-- Forecast
	INSERT INTO [dbo].[fact_demand_total]
    (
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_date_id_buy_month]
		,[dim_factory_id_original_unconstrained]
		,[dim_factory_id_original_constrained]
		,[dim_factory_id_final]
		,[dim_factory_id]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[order_number]
		,[is_asap]
		,[quantity_lum]
		,[quantity_non_lum]
		,[quantity_unconsumed]
		,[quantity]
		,[is_from_previous_release]
    )
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
		@dim_date_id_buy_month,
		@dim_factory_id_placeholder AS [dim_factory_id_original_unconstrained],
		@dim_factory_id_placeholder AS [dim_factory_id_original_constrained],
		@dim_factory_id_placeholder AS [dim_factory_id_final],
		@dim_factory_id_placeholder AS [dim_factory_id],
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_apac
		END as dim_customer_id,
		@dim_demand_category_id_forecast AS [dim_demand_category_id],
		'UNDEFINED' AS [order_number],
		0 AS [is_asap],
		sum(quantity) AS [quantity_lum],
		sum(quantity) AS [quantity_non_lum],
		sum(quantity) AS [quantity_unconsumed],
		sum(quantity) AS [quantity],
		0 AS [is_from_previous_release]
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
		@dim_date_id_buy_month,
		@dim_factory_id_placeholder AS [dim_factory_id_original_unconstrained],
		@dim_factory_id_placeholder AS [dim_factory_id_original_constrained],
		@dim_factory_id_placeholder AS [dim_factory_id_final],
		@dim_factory_id_placeholder AS [dim_factory_id],
		CASE
			WHEN dc.id IS NOT NULL THEN dc.id
			ELSE @dim_customer_id_placeholder_emea
		END as dim_customer_id,
		@dim_demand_category_id_forecast AS [dim_demand_category_id],
		'UNDEFINED' AS [order_number],
		0 AS [is_asap],
		sum(quantity) AS [quantity_lum],
		sum(quantity) AS [quantity_non_lum],
		sum(quantity) AS [quantity_unconsumed],
		sum(quantity) AS [quantity],
		0 AS [is_from_previous_release]
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
		@dim_date_id_buy_month,
		@dim_factory_id_placeholder AS [dim_factory_id_original_unconstrained],
		@dim_factory_id_placeholder AS [dim_factory_id_original_constrained],
		@dim_factory_id_placeholder AS [dim_factory_id_final],
		@dim_factory_id_placeholder AS [dim_factory_id],
		dc.id as dim_customer_id,
		@dim_demand_category_id_forecast AS [dim_demand_category_id],
		'UNDEFINED' AS [order_number],
		0 AS [is_asap],
		sum(quantity) AS [quantity_lum],
		sum(quantity) AS [quantity_non_lum],
		sum(quantity) AS [quantity_unconsumed],
		sum(quantity) AS [quantity],
		0 AS [is_from_previous_release]
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
