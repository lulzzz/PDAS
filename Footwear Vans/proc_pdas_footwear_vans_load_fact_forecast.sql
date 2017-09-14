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
	-- Check if the session has already been loaded
	IF EXISTS (SELECT 1 FROM [dbo].[fact_forecast] WHERE dim_pdas_id = @pdasid AND dim_buying_program_id = @buying_program_id)
	BEGIN
		DELETE FROM [dbo].[fact_forecast] WHERE dim_pdas_id = @pdasid AND dim_buying_program_id = @buying_program_id;
	END
	;

	-- Insert from staging
	INSERT INTO [dbo].[fact_forecast](dim_pdas_id, dim_business_id, dim_buying_program_id, dim_product_id, dim_date_id, dim_customer_id, dim_factory_id, quantity)
	-- NORA
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		dp.id as dim_product_id,
		dd.id as dim_date_id,
		dc.id as dim_customer_id,
		df.id as dim_factory_id,
		sum(quantity) as quantity
	FROM [dbo].[staging_pdas_footwear_vans_nora_forecast] nf
	INNER JOIN [dbo].[dim_business] biz ON biz.id = @businessid
	INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = @buying_program_id
	INNER JOIN [dbo].[dim_product] dp ON nf.dim_product_material_id = dp.material_id
 	INNER JOIN [dbo].[dim_factory] df ON df.is_placeholder = 1 AND df.placeholder_level = 'Vendor Group'
	INNER JOIN [dbo].[dim_customer] dc ON dc.is_placeholder = 1 AND dc.placeholder_level = 'Region' AND market = 'NORA'
	INNER JOIN [dbo].[dim_date] dd ON nf.season = dd.season_year_accounting AND nf.plan_month = dd.month_name_short_accounting
	WHERE dp.is_placeholder = 1 AND dp.placeholder_level = 'material_id'
	GROUP BY
		dp.id,
		dd.id,
		dc.id,
		df.id
	UNION
	-- EMEA
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		dp.id as dim_product_id,
		dd.id as dim_date_id,
		dc.id as dim_customer_id,
		df.id as dim_factory_id,
		sum(quantity) as quantity
	FROM [dbo].[staging_pdas_footwear_vans_emea_forecast] nf
	INNER JOIN [dbo].[dim_business] biz ON biz.id = @businessid
	INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = @buying_program_id
	INNER JOIN [dbo].[dim_product] dp ON nf.dim_product_material_id = dp.material_id
 	INNER JOIN [dbo].[dim_factory] df ON df.is_placeholder = 1 AND df.placeholder_level = 'Vendor Group'
	INNER JOIN [dbo].[dim_customer] dc ON dc.is_placeholder = 1 AND dc.placeholder_level = 'Region' AND market = 'EUR'
	INNER JOIN [dbo].[dim_date] dd ON nf.season = dd.season_year_short_accounting AND nf.plan_month = dd.month_name_short_accounting
	WHERE dp.is_placeholder = 1 AND dp.placeholder_level = 'material_id'
	GROUP BY
		dp.id,
		dd.id,
		dc.id,
		df.id
	UNION
	-- APAC
	SELECT
		@pdasid as dim_pdas_id,
		@businessid as dim_business_id,
		@buying_program_id as dim_buying_program_id,
		dp.id as dim_product_id,
		dd.id as dim_date_id,
		dc.id as dim_customer_id,
		df.id as dim_factory_id,
		sum(quantity) as quantity
	FROM [dbo].[staging_pdas_footwear_vans_apac_forecast] nf
	INNER JOIN [dbo].[dim_business] biz ON biz.id = @businessid
	INNER JOIN [dbo].[dim_buying_program] bp ON bp.id = @buying_program_id
	INNER JOIN [dbo].[dim_product] dp ON nf.dim_product_material_id = dp.material_id
	INNER JOIN [dbo].[dim_factory] df ON df.is_placeholder = 1 AND df.placeholder_level = 'Vendor Group'
	INNER JOIN [dbo].[dim_customer] dc ON dc.is_placeholder = 1 AND dc.placeholder_level = 'Region' AND market = 'APAC'
	INNER JOIN [dbo].[dim_date] dd ON SUBSTRING(nf.month_label, 1, 4) = dd.season_year_short_accounting AND nf.plan_month = dd.month_name_short_accounting
	WHERE dp.is_placeholder = 1 AND dp.placeholder_level = 'material_id'
	GROUP BY
		dp.id,
		dd.id,
		dc.id,
		df.id

	;
END
