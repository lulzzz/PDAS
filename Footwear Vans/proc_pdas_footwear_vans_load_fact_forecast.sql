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
		@dim_customer_id_placeholder_apac as dim_customer_id,
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
			AND dd.month_name_short_accounting =
				CASE SUBSTRING(nf.month_label, 6, 3)
					WHEN 'Jan' THEN 'Mar'
					WHEN 'Feb' THEN 'Apr'
					WHEN 'Mar' THEN 'May'
					WHEN 'Apr' THEN 'Jun'
					WHEN 'May' THEN 'Jul'
					WHEN 'Jun' THEN 'Aug'
					WHEN 'Jul' THEN 'Sep'
					WHEN 'Aug' THEN 'Oct'
					WHEN 'Sep' THEN 'Nov'
					WHEN 'Oct' THEN 'Dec'
					WHEN 'Nov' THEN 'Jan'
					WHEN 'Dec' THEN 'Feb'
				END
	WHERE
		quantity IS NOT NULL
	GROUP BY
		CASE
			WHEN dp.id IS NOT NULL THEN dp.id
			ELSE @dim_product_id_placeholder
		END,
		dd.id


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
		@dim_customer_id_placeholder_emea as dim_customer_id,
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
		INNER JOIN
		(
			SELECT [season_year_short_buy], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_short_buy], [month_name_short_accounting]
		) dd
			ON dd.[season_year_short_buy] = nf.season
			AND dd.month_name_short_accounting =
				CASE nf.customer_type
					WHEN 'XDC' THEN nf.plan_month
					ELSE
						CASE nf.plan_month
							WHEN 'Jan' THEN 'Dec'
							WHEN 'Feb' THEN 'Jan'
							WHEN 'Mar' THEN 'Feb'
							WHEN 'Apr' THEN 'Mar'
							WHEN 'May' THEN 'Apr'
							WHEN 'Jun' THEN 'May'
							WHEN 'Jul' THEN 'Jun'
							WHEN 'Aug' THEN 'Jul'
							WHEN 'Sep' THEN 'Aug'
							WHEN 'Oct' THEN 'Sep'
							WHEN 'Nov' THEN 'Oct'
							WHEN 'Dec' THEN 'Nov'
						END
				END
		WHERE
			quantity IS NOT NULL
		GROUP BY
			CASE
				WHEN dp.id IS NOT NULL THEN dp.id
				ELSE @dim_product_id_placeholder
			END,
			dd.id

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
			SELECT [season_year_crd], [month_name_short_accounting], MIN([id]) as [id]
			FROM [dbo].[dim_date]
			GROUP BY [season_year_crd], [month_name_short_accounting]
		) dd
			ON dd.[season_year_crd] = nf.season
			AND dd.month_name_short_accounting =
				CASE nf.plan_month
					WHEN 'Jan' THEN 'Nov'
					WHEN 'Feb' THEN 'Dec'
					WHEN 'Mar' THEN 'Jan'
					WHEN 'Apr' THEN 'Feb'
					WHEN 'May' THEN 'Mar'
					WHEN 'Jun' THEN 'Apr'
					WHEN 'Jul' THEN 'May'
					WHEN 'Aug' THEN 'Jun'
					WHEN 'Sep' THEN 'Jul'
					WHEN 'Oct' THEN 'Aug'
					WHEN 'Nov' THEN 'Sep'
					WHEN 'Dec' THEN 'Oct'
				END
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
