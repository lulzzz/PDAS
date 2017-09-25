-- =======================================================================================
-- Author:		ebp Global
-- Create date: 14/9/2017
-- Description:	This procedure loads the the weekly and daily factory capacity
-- =======================================================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity]
    @pdasid INT,
    @businessid INT
AS
BEGIN

    -- Check if the session has already been loaded
    DELETE FROM [dbo].[fact_factory_capacity] WHERE dim_pdas_id = @pdasid;

    -- Insert from staging
    INSERT INTO [dbo].[fact_factory_capacity]
    (
        [dim_pdas_id]
        ,[dim_business_id]
        ,[dim_factory_id]
        ,[dim_construction_type_id]
        ,[dim_date_id]
        ,[net_capacity_units]
    )
    -- Daily capacity
    SELECT
        @pdasid as dim_pdas_id,
        @businessid as dim_business_id,
        CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END as dim_factory_id,
		CASE
			WHEN cons.[id] IS NOT NULL THEN cons.[id]
			ELSE mapping_cons.id
		END as dim_customer_id,
        dd.[id] as dim_date_id,
        sum(ISNULL(cap.[quantity], 0)) as net_capacity_units
    FROM
        [dbo].[staging_pdas_footwear_vans_raw_capacity] cap
        INNER JOIN [dbo].[dim_date] dd ON cap.dim_date_id = dd.full_date
        LEFT OUTER JOIN [dbo].[dim_construction_type] cons ON cap.dim_construction_type_name = cons.name
		LEFT OUTER JOIN
		(
			SELECT cons.id, m.child
			FROM
				[dbo].[helper_pdas_footwear_vans_mapping] m
				INNER JOIN (SELECT id, name FROM [dbo].[dim_construction_type]) cons
					ON m.parent = cons.name
			WHERE type = 'Construction Type Master'
		) mapping_cons ON cap.dim_factory_short_name = mapping_cons.child

        LEFT OUTER JOIN [dbo].[dim_factory] df ON cap.dim_factory_short_name = df.short_name
		LEFT OUTER JOIN
		(
			SELECT df.id, m.child
			FROM
				[dbo].[helper_pdas_footwear_vans_mapping] m
				INNER JOIN (SELECT id, short_name FROM [dbo].[dim_factory]) df
					ON m.parent = df.short_name
			WHERE type = 'Factory Master'
		) mapping_f ON cap.dim_factory_short_name = mapping_f.child
    WHERE
        (df.id IS NOT NULL OR mapping_f.id IS NOT NULL) AND
		(cons.id IS NOT NULL OR mapping_cons.id IS NOT NULL)
    GROUP BY
        CASE
			WHEN df.id IS NOT NULL THEN df.id
			ELSE mapping_f.id
		END,
		CASE
			WHEN cons.[id] IS NOT NULL THEN cons.[id]
			ELSE mapping_cons.id
		END,
        dd.[id]

    -- Weekly capacity (pivot)

END
