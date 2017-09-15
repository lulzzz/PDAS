-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the fact_priority_list table.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_priority_list]
	@pdasid INT,
	@businessid INT
AS
BEGIN
	-- Check if the session has already been loaded
	IF EXISTS (
        SELECT 1 FROM [dbo].[fact_priority_list]
        WHERE dim_pdas_id = @pdasid
    )
	BEGIN
		DELETE FROM [dbo].[fact_priority_list]
        WHERE dim_pdas_id = @pdasid
        ;
	END
	;


	-- Insert from staging
	INSERT INTO [dbo].[fact_priority_list](dim_pdas_id, dim_business_id, dim_product_id, dim_factory_id_1, dim_factory_id_2)
	SELECT
        @pdasid as dim_pdas_id,
        @businessid as dim_business_id,
        dp.id as dim_product_id,
        df1.id as dim_factory_id_1,
        df2.id as dim_factory_id_2
	FROM [dbo].[staging_pdas_footwear_vans_priority_list] pl
	INNER JOIN [dbo].[dim_business] biz ON biz.id = @businessid
	INNER JOIN [dbo].[dim_product] dp ON pl.dim_product_material_id = dp.material_id
 	INNER JOIN [dbo].[dim_factory] df1 ON df1.short_name = pl.alloc_1
    LEFT OUTER JOIN [dbo].[dim_factory] df2 ON df2.short_name = pl.alloc_2
	WHERE dp.is_placeholder = 1 AND dp.placeholder_level = 'material_id'
	;
END
