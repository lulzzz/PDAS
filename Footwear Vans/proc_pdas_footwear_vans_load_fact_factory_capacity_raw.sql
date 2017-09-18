-- =======================================================================================
-- Author:		ebp Global
-- Create date: 14/9/2017
-- Description:	This procedure loads the dim_product table
-- =======================================================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity_raw]
    @pdasid INT,
    @businessid INT
AS
BEGIN

    -- Check if the session has already been loaded
    DELETE FROM [dbo].[fact_factory_capacity] WHERE dim_pdas_id = @pdasid;
    
    -- Insert from staging
    INSERT INTO [dbo].[fact_factory_capacity](dim_pdas_id, dim_business_id, dim_factory_id, dim_construction_type_id, dim_date_id, net_capacity_units)
    SELECT
        @pdasid as dim_pdas_id,
        @businessid as dim_business_id,
        df.id as dim_factory_id,
        cons.id as dim_construction_type_id,
        dd.id as dim_date_id,
        sum(quantity) as net_capacity_units
    FROM [dbo].[staging_pdas_footwear_vans_raw_capacity] rc
    INNER JOIN [dbo].[dim_business] biz ON biz.id = @businessid
    INNER JOIN [dbo].[dim_construction_type] cons ON rc.dim_construction_type_name = cons.name
    INNER JOIN [dbo].[dim_factory] df ON rc.dim_factory_short_name = df.short_name
    INNER JOIN [dbo].[dim_date] dd ON rc.dim_date_id = dd.full_date
    GROUP BY
        df.id,
        cons.id,
        dd.id
    ;

END
