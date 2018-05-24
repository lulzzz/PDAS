USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Description:	Procedure to load the forecast in fact_forecast.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_forecast]
	@dim_release_id INT,
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
			FROM [dbo].[dim_release]
			WHERE
				[id] = @dim_release_id
		) dim_release
		INNER JOIN
		(
			SELECT
				MIN([id]) as [id]
				,[year_month_accounting]
			FROM [dbo].[dim_date]
			GROUP BY [year_month_accounting]
		) dim_date
			ON dim_release.[buy_month] = dim_date.[year_month_accounting]
	)

	-- Check if the session has already been loaded
	IF EXISTS (SELECT 1 FROM [dbo].[fact_demand_total] WHERE dim_release_id = @dim_release_id AND dim_business_id = @businessid AND dim_buying_program_id = @buying_program_id AND dim_demand_category_id = @dim_demand_category_id_forecast)
	BEGIN
		DELETE FROM [dbo].[fact_demand_total]
		WHERE dim_release_id = @dim_release_id
		AND dim_business_id = @businessid
		AND dim_buying_program_id = @buying_program_id
		AND dim_demand_category_id = @dim_demand_category_id_forecast
	END

	-- Forecast
	INSERT INTO [dbo].[fact_demand_total]
	(
		[dim_release_id]
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
		,[sold_to_customer_name]
		,[colorway_name]
		,[style_description_long]
	)
	-- APAC
	-- Providing their forecast based on BUY months
	SELECT
		@dim_release_id as dim_release_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		dd.id as dim_date_id_buy_month,
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
		[dim_market_name] as [sold_to_customer_name]
		,NULL as [colorway_name]
		,NULL as [style_description_long]
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
		END,
		[dim_market_name]


	-- EMEA
	-- Providing their forecast based on CRD months for XDC (i.e. EU DC order) and CRD month + 1 for XF (i.e. EU Direct orders)
	UNION
	SELECT
		@dim_release_id as dim_release_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		dd.id as dim_date_id_buy_month,
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
		[customer_type] as [sold_to_customer_name]
		,NULL as [colorway_name]
		,[dim_product_material_description] as [style_description_long]
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
			END,
			[customer_type],
			[dim_product_material_description]

	-- NORA (we pull intro month 2 months forward to reach CRD)
	UNION
	SELECT
		@dim_release_id as dim_release_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END as dim_product_id,
		dd.id as dim_date_id,
		dd.id as dim_date_id_buy_month,
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
		[dim_region_region] as [sold_to_customer_name],
		[dim_product_color_description] as [colorway_name],
		[dim_product_material_description] as [style_description_long]
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
		dc.id,
		[dim_region_region],
		[dim_product_color_description],
		[dim_product_material_description]


	-- Update single_or_dual_source
	UPDATE t
	SET
		[single_or_dual_source] = CASE
			WHEN ISNULL(prio.[dim_factory_id_2], 0) <> 0 THEN 'Dual source'
			WHEN t.[style_complexity] LIKE '%flex%' THEN 'Dual source'
			WHEN prio.[short_name] NOT IN ('CLK', 'DTP', 'SJD', 'MTL') THEN 'Dual source'
			ELSE 'Single source'
		END
	FROM
		(
			SELECT f.*, dp.[style_complexity]
			FROM
				[fact_demand_total] f
				INNER JOIN dim_product dp
					ON f.[dim_product_id] = dp.[id]
			WHERE
				[dim_release_id] = @dim_release_id
				and f.[dim_business_id] = @businessid
				and dim_demand_category_id = @dim_demand_category_id_forecast
		) t
		INNER JOIN
		(
			SELECT f.*, df.[short_name]
			FROM
				[fact_priority_list] f
				INNER JOIN dim_factory df
					ON f.[dim_factory_id_1] = df.[id]
			WHERE
				[dim_release_id] = @dim_release_id
				and f.[dim_business_id] = @businessid
		) prio
			ON t.[dim_product_id] = prio.[dim_product_id]

	-- Update style_ranking
	UPDATE t
	SET
		[style_ranking] = t_ranked.[ranking]
	FROM
		(
			SELECT f.*, dp.[style_id]
			FROM
				[fact_demand_total] f
				INNER JOIN dim_product dp
					ON f.[dim_product_id] = dp.[id]
			WHERE
				[dim_release_id] = @dim_release_id
				and dp.[dim_business_id] = @businessid
				and dim_demand_category_id = @dim_demand_category_id_forecast
		) t
		INNER JOIN
		(
			SELECT dp.[style_id], RANK() OVER(ORDER BY SUM(f.[quantity_lum]) DESC) as [ranking]
			FROM
				[fact_demand_total] f
				INNER JOIN dim_product dp
					ON f.[dim_product_id] = dp.[id]
			WHERE
				[dim_release_id] = @dim_release_id
				and f.[dim_business_id] = @businessid
				and dim_demand_category_id = @dim_demand_category_id_forecast
			GROUP BY
				dp.[style_id]
		) t_ranked
			ON t.[style_id] = t_ranked.[style_id]


	-- Update mtr_ranking
	UPDATE t
	SET
		[mtr_ranking] = t_ranked.[ranking]
	FROM
		(
			SELECT f.*, dp.[material_id]
			FROM
				[fact_demand_total] f
				INNER JOIN dim_product dp
					ON f.[dim_product_id] = dp.[id]
			WHERE
				[dim_release_id] = @dim_release_id
				and dp.[dim_business_id] = @businessid
				and dim_demand_category_id = @dim_demand_category_id_forecast
		) t
		INNER JOIN
		(
			SELECT dp.[material_id], RANK() OVER(ORDER BY SUM(f.[quantity_lum]) DESC) as [ranking]
			FROM
				[fact_demand_total] f
				INNER JOIN dim_product dp
					ON f.[dim_product_id] = dp.[id]
			WHERE
				[dim_release_id] = @dim_release_id
				and f.[dim_business_id] = @businessid
				and dim_demand_category_id = @dim_demand_category_id_forecast
			GROUP BY
				dp.[material_id]
		) t_ranked
			ON t.[material_id] = t_ranked.[material_id]


	-- Update top_50_mtl
	UPDATE [fact_demand_total]
	SET
		[top_50_mtl] = CASE
			WHEN [mtr_ranking] BETWEEN 1 AND 50 THEN 'Top 50 MTL'
			ELSE NULL
		END
	WHERE
		[dim_release_id] = @dim_release_id
		and [dim_business_id] = @businessid
		and [dim_demand_category_id] = @dim_demand_category_id_forecast


END
