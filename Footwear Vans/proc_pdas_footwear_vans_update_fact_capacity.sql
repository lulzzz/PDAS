-- =======================================================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	This procedure updates the fact_factory_capacity table with weekly capacity
-- =======================================================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_updates_fact_factory_capacity]
    @pdasid INT,
    @businessid INT
AS
BEGIN

    -- Insert from staging
    UPDATE ffc
    SET
    SELECT
        @pdasid as dim_pdas_id,
        @businessid as dim_business_id,
        df.id as dim_factory_id,
        cons.id as dim_construction_type_id,
        dd.id as dim_date_id,
        sum(quantity) as net_capacity_units
    FROM [dbo].[fact_factory_capacity]
    INNER JOIN [dbo].[dim_business] biz ON biz.id = @businessid
    INNER JOIN [dbo].[dim_construction_type] cons ON rc.dim_construction_type_name = cons.name
    INNER JOIN [dbo].[dim_factory] df ON rc.dim_factory_short_name = df.short_name
    INNER JOIN [dbo].[dim_date] dd ON rc.dim_date_id = dd.full_date
    INNER JOIN [dbo].[staging_pdas_footwear_vans_raw_capacity] rc
    ;

END
