-- =======================================================================================
-- Author:		ebp Global
-- Create date: 14/9/2017
-- Description:	This procedure loads the the weekly and daily factory capacity
-- =======================================================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity]
    @dim_release_id INT,
    @businessid INT
AS
BEGIN

    -- Check if the session has already been loaded
    DELETE FROM [dbo].[fact_factory_capacity]
    WHERE dim_business_id = @businessid;

    -- Cleanse weekly capacity
    UPDATE [dbo].[staging_pdas_footwear_vans_capacity_by_week]
    SET [dim_construction_type_name] = 'NA'
    WHERE [dim_construction_type_name] IS NULL

    -- Placeholder
    DECLARE @dim_customer_id_placeholder int = (SELECT [id] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER' and [name] = 'PLACEHOLDER')

    -- Temp tables
    DECLARE @temp_capacity_available_weekly TABLE(
		[dim_business_id] INT
        ,[dim_factory_id] INT
        ,[dim_customer_id] INT
        ,[dim_construction_type_id] INT
        ,[dim_date_id] INT
        ,[capacity_raw_daily] INT
        ,[capacity_raw_daily_overwritten] INT
        ,[capacity_available_weekly] INT
        ,[percentage_region] INT
        ,[percentage_from_original] INT
    )

    DECLARE @temp_percentage_region TABLE(
        [dim_factory_id] INT
        ,[dim_customer_id] INT
        ,[percentage] FLOAT
    )
    INSERT INTO @temp_percentage_region
    SELECT
        u.[dim_factory_id]
        ,dc.[id] as [dim_customer_id]
        ,u.[percentage]
    FROM
    (
        SELECT
            df.[id] as [dim_factory_id]
            ,MAX([APAC]) as [APAC]
            ,MAX([EMEA]) as [EMEA]
            ,MAX([CASA]) as [CASA]
            ,MAX([NORA]) as [NORA]
        FROM
            [dbo].[helper_pdas_footwear_vans_factory_capacity_by_region] helper
            INNER JOIN [dbo].[dim_factory] df ON helper.[factory_short_name] = df.short_name
        GROUP BY
            df.[id]
    ) c
    UNPIVOT
    (
        [percentage]
        for [region] in
        (
            [APAC]
            ,[EMEA]
            ,[CASA]
            ,[NORA]
        )
    ) u
    INNER JOIN
    (
        SELECT [id], [name] FROM [dbo].[dim_customer] WHERE [is_placeholder] = 1 and [placeholder_level] = 'Region'
    ) dc
        ON u.[region] = dc.[name]


    -- Insert daily capacity from staging area
    INSERT INTO [dbo].[fact_factory_capacity]
    (
		[dim_business_id]
        ,[dim_factory_id]
        ,[dim_customer_id]
        ,[dim_construction_type_id]
        ,[dim_date_id]
        ,[capacity_raw_daily]
        ,[capacity_raw_daily_overwritten]
        ,[capacity_available_weekly]
        ,[percentage_region]
        ,[percentage_from_original]
    )
    SELECT
        @businessid as dim_business_id,
        CASE
            WHEN df.id IS NOT NULL THEN df.id
            ELSE mapping_f.id
        END as dim_factory_id,
        ISNULL(cap_region.[dim_customer_id], @dim_customer_id_placeholder) as dim_customer_id,
        CASE
            WHEN cons.[id] IS NOT NULL THEN cons.[id]
            ELSE mapping_cons.id
        END as dim_construction_type_id,
        dd.[id] as dim_date_id,
        sum(ISNULL(cap.[quantity], 0)) * max(ISNULL(cap_region.[percentage], 0.25)) * max(ISNULL(cap_adj.[Percentage], 1)) as capacity_raw_daily,
        sum(ISNULL(cap.[quantity_adjusted], 0)) * max(ISNULL(cap_region.[percentage], 0.25)) * max(ISNULL(cap_adj.[Percentage], 1)) as capacity_raw_daily_overwritten,
        0 AS [capacity_available_weekly],
        max(ISNULL(cap_region.[percentage], 1)) AS [percentage_region],
        max(ISNULL(cap_adj.[Percentage], 1)) as percentage_from_original
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
            WHERE category = 'Construction Type Master'
        ) mapping_cons ON cap.dim_construction_type_name = mapping_cons.child

        LEFT OUTER JOIN [dbo].[dim_factory] df ON cap.dim_factory_short_name = df.short_name
        LEFT OUTER JOIN
        (
            SELECT df.id, m.child
            FROM
                [dbo].[helper_pdas_footwear_vans_mapping] m
                INNER JOIN (SELECT id, short_name FROM [dbo].[dim_factory]) df
                    ON m.parent = df.short_name
            WHERE category = 'Factory Master'
        ) mapping_f ON cap.dim_factory_short_name = mapping_f.child

        LEFT OUTER JOIN [dbo].[helper_pdas_footwear_vans_factory_capacity_adjustment] cap_adj
            ON cap_adj.[factory_short_name] = df.short_name

        LEFT OUTER JOIN @temp_percentage_region cap_region
            ON cap_region.[dim_factory_id] = df.[id]

    WHERE
        (df.id IS NOT NULL OR mapping_f.id IS NOT NULL) AND
        (cons.id IS NOT NULL OR mapping_cons.id IS NOT NULL)
    GROUP BY
        CASE
            WHEN df.id IS NOT NULL THEN df.id
            ELSE mapping_f.id
        END,
                ISNULL(cap_region.[dim_customer_id], @dim_customer_id_placeholder),
        CASE
            WHEN cons.[id] IS NOT NULL THEN cons.[id]
            ELSE mapping_cons.id
        END,
        dd.[id]

    -- Update capacity_raw_weekly field with daily raw capacity aggregated by accounting week
    UPDATE f
    SET
        f.[capacity_raw_weekly] = f_aggr.[capacity_raw_weekly],
        f.[capacity_raw_weekly_overwritten] = f_aggr.[capacity_raw_weekly_overwritten]
    FROM
        (SELECT * FROM [dbo].[fact_factory_capacity] WHERE [dim_business_id] = @businessid) as f
        INNER JOIN
        (
            SELECT
                [dim_factory_id]
                ,[dim_customer_id]
                ,[dim_construction_type_id]
                ,dd2.[id] as [dim_date_id]
                ,sum([capacity_raw_daily]) as [capacity_raw_weekly]
                ,sum([capacity_raw_daily_overwritten]) as [capacity_raw_weekly_overwritten]
            FROM
                [dbo].[fact_factory_capacity] cap
                INNER JOIN
                (
                    SELECT [id], [year_cw_accounting]
                    FROM [dbo].[dim_date]
                ) dd1
                    ON dd1.[id] = cap.[dim_date_id]
                INNER JOIN
                (
                    SELECT
                        [year_cw_accounting],
                        MIN([id]) as [id]
                    FROM [dbo].[dim_date]
                    GROUP BY [year_cw_accounting]
                ) dd2
                    ON dd1.[year_cw_accounting] = dd2.[year_cw_accounting]
            WHERE [dim_business_id] = @businessid
            GROUP BY
                [dim_factory_id]
                ,[dim_customer_id]
                ,[dim_construction_type_id]
                ,dd2.[id]
        ) f_aggr
            ON	f.[dim_factory_id] = f_aggr.[dim_factory_id] and
                f.[dim_customer_id] = f_aggr.[dim_customer_id] and
                f.[dim_construction_type_id] = f_aggr.[dim_construction_type_id] and
                f.[dim_date_id] = f_aggr.[dim_date_id]


    -- Fill table selection capacity_available_weekly (weekly capacity)
    ;WITH [pivoted_factory_capacity] AS (
    SELECT
        u.[dim_factory_id]
        ,u.[dim_construction_type_id]
        ,u.[dim_customer_id]
        ,CONVERT(NVARCHAR(4), u.[year_cw_accounting]) + 'CW' + RIGHT(u.[cw], 2) AS [year_cw_accounting]
        ,ISNULL(u.[quantity], 0) * ISNULL([percentage_region], 1) * ISNULL([percentage_from_original], 1) as capacity_available_weekly
        ,[percentage_region]
        ,[percentage_from_original]
    FROM
        (
        SELECT
            CASE
                WHEN df.id IS NOT NULL THEN df.id
                ELSE mapping_f.id
            END as dim_factory_id,
            ISNULL(cap_region.[dim_customer_id], @dim_customer_id_placeholder) as dim_customer_id,
            CASE
                WHEN cons.[id] IS NOT NULL THEN cons.[id]
                ELSE mapping_cons.id
            END as dim_construction_type_id,
            CASE
                WHEN cap_region.[percentage] IS NOT NULL THEN cap_region.[percentage]
                ELSE 0
            END as [percentage_region],
            CASE
                WHEN cap_adj.[Percentage] IS NOT NULL THEN cap_adj.[Percentage]
                ELSE 1
            END as [percentage_from_original]
            ,[dim_date_year_accounting] as [year_cw_accounting]
            ,[capacity_wk01]
            ,[capacity_wk02]
            ,[capacity_wk03]
            ,[capacity_wk04]
            ,[capacity_wk05]
            ,[capacity_wk06]
            ,[capacity_wk07]
            ,[capacity_wk08]
            ,[capacity_wk09]
            ,[capacity_wk10]
            ,[capacity_wk11]
            ,[capacity_wk12]
            ,[capacity_wk13]
            ,[capacity_wk14]
            ,[capacity_wk15]
            ,[capacity_wk16]
            ,[capacity_wk17]
            ,[capacity_wk18]
            ,[capacity_wk19]
            ,[capacity_wk20]
            ,[capacity_wk21]
            ,[capacity_wk22]
            ,[capacity_wk23]
            ,[capacity_wk24]
            ,[capacity_wk25]
            ,[capacity_wk26]
            ,[capacity_wk27]
            ,[capacity_wk28]
            ,[capacity_wk29]
            ,[capacity_wk30]
            ,[capacity_wk31]
            ,[capacity_wk32]
            ,[capacity_wk33]
            ,[capacity_wk34]
            ,[capacity_wk35]
            ,[capacity_wk36]
            ,[capacity_wk37]
            ,[capacity_wk38]
            ,[capacity_wk39]
            ,[capacity_wk40]
            ,[capacity_wk41]
            ,[capacity_wk42]
            ,[capacity_wk43]
            ,[capacity_wk44]
            ,[capacity_wk45]
            ,[capacity_wk46]
            ,[capacity_wk47]
            ,[capacity_wk48]
            ,[capacity_wk49]
            ,[capacity_wk50]
            ,[capacity_wk51]
            ,[capacity_wk52]
        FROM
            [dbo].[staging_pdas_footwear_vans_capacity_by_week] cap

            LEFT OUTER JOIN [dbo].[dim_factory] df ON cap.dim_factory_short_name = df.short_name
            LEFT OUTER JOIN
            (
                SELECT df.id, m.child
                FROM
                    [dbo].[helper_pdas_footwear_vans_mapping] m
                    INNER JOIN (SELECT id, short_name FROM [dbo].[dim_factory]) df
                        ON m.parent = df.short_name
                WHERE category = 'Factory Master'
            ) mapping_f ON cap.dim_factory_short_name = mapping_f.child

            LEFT OUTER JOIN [dbo].[dim_construction_type] cons ON cap.dim_construction_type_name = cons.name
            LEFT OUTER JOIN
            (
                SELECT cons.id, m.child
                FROM
                    [dbo].[helper_pdas_footwear_vans_mapping] m
                    INNER JOIN (SELECT id, name FROM [dbo].[dim_construction_type]) cons
                        ON m.parent = cons.name
                WHERE category = 'Construction Type Master'
            ) mapping_cons ON cap.dim_construction_type_name = mapping_cons.child

            LEFT OUTER JOIN [dbo].[helper_pdas_footwear_vans_factory_capacity_adjustment] cap_adj
                ON cap_adj.[factory_short_name] = df.short_name

            LEFT OUTER JOIN @temp_percentage_region cap_region
                ON cap_region.[dim_factory_id] = df.[id]

        WHERE
            (df.id IS NOT NULL OR mapping_f.id IS NOT NULL) AND
            (cons.id IS NOT NULL OR mapping_cons.id IS NOT NULL)
        ) c
        UNPIVOT
        (
            [quantity]
            for [cw] in
            (
                [capacity_wk01]
                ,[capacity_wk02]
                ,[capacity_wk03]
                ,[capacity_wk04]
                ,[capacity_wk05]
                ,[capacity_wk06]
                ,[capacity_wk07]
                ,[capacity_wk08]
                ,[capacity_wk09]
                ,[capacity_wk10]
                ,[capacity_wk11]
                ,[capacity_wk12]
                ,[capacity_wk13]
                ,[capacity_wk14]
                ,[capacity_wk15]
                ,[capacity_wk16]
                ,[capacity_wk17]
                ,[capacity_wk18]
                ,[capacity_wk19]
                ,[capacity_wk20]
                ,[capacity_wk21]
                ,[capacity_wk22]
                ,[capacity_wk23]
                ,[capacity_wk24]
                ,[capacity_wk25]
                ,[capacity_wk26]
                ,[capacity_wk27]
                ,[capacity_wk28]
                ,[capacity_wk29]
                ,[capacity_wk30]
                ,[capacity_wk31]
                ,[capacity_wk32]
                ,[capacity_wk33]
                ,[capacity_wk34]
                ,[capacity_wk35]
                ,[capacity_wk36]
                ,[capacity_wk37]
                ,[capacity_wk38]
                ,[capacity_wk39]
                ,[capacity_wk40]
                ,[capacity_wk41]
                ,[capacity_wk42]
                ,[capacity_wk43]
                ,[capacity_wk44]
                ,[capacity_wk45]
                ,[capacity_wk46]
                ,[capacity_wk47]
                ,[capacity_wk48]
                ,[capacity_wk49]
                ,[capacity_wk50]
                ,[capacity_wk51]
                ,[capacity_wk52]
            )
        ) u
    ),
    [target_capacity_available_weekly] AS (
        SELECT
            dd.[id] as [dim_date_id],
            piv.[dim_customer_id] as [dim_customer_id],
            piv.[dim_factory_id] as [dim_factory_id],
            piv.[dim_construction_type_id] as [dim_construction_type_id],
            piv.[capacity_available_weekly] as [capacity_available_weekly],
            piv.[percentage_region],
            piv.[percentage_from_original]
        FROM
            [pivoted_factory_capacity] piv
            INNER JOIN
            (
                SELECT
                    [year_cw_accounting],
                    MIN([id]) as [id]
                FROM [dbo].[dim_date]
                GROUP BY [year_cw_accounting]
            ) dd
                ON dd.[year_cw_accounting] = piv.[year_cw_accounting]

    )

    -- Fill temp table capacity_available_weekly (weekly capacity)
    INSERT INTO @temp_capacity_available_weekly
    (
        [dim_business_id]
        ,[dim_factory_id]
        ,[dim_customer_id]
        ,[dim_construction_type_id]
        ,[dim_date_id]
        ,[capacity_raw_daily]
		,[capacity_raw_daily_overwritten]
        ,[capacity_available_weekly]
        ,[percentage_region]
        ,[percentage_from_original]
    )
    SELECT
        @businessid as dim_business_id,
        temp.[dim_factory_id],
        temp.[dim_customer_id],
        temp.[dim_construction_type_id],
        temp.[dim_date_id],
        0 as [capacity_raw_daily],
		0 as [capacity_raw_daily_overwritten],
        MAX(temp.[capacity_available_weekly]),
        MAX(temp.[percentage_region]),
        MAX(temp.[percentage_from_original])
    FROM
        [target_capacity_available_weekly] temp
    GROUP BY
        temp.[dim_factory_id],
        temp.[dim_customer_id],
        temp.[dim_construction_type_id],
        temp.[dim_date_id]

    -- Insert on non-match (raw capacity not existing for the week)
    INSERT INTO [dbo].[fact_factory_capacity]
    (
        [dim_business_id]
        ,[dim_factory_id]
        ,[dim_customer_id]
        ,[dim_construction_type_id]
        ,[dim_date_id]
        ,[capacity_raw_daily]
        ,[capacity_raw_daily_overwritten]
        ,[capacity_available_weekly]
        ,[percentage_region]
        ,[percentage_from_original]
    )
    SELECT temp.*
    FROM
        @temp_capacity_available_weekly temp
        LEFT JOIN
        (
            SELECT *
            FROM [dbo].[fact_factory_capacity]
            WHERE
                [dim_business_id] = @businessid
        ) as f
            ON	temp.[dim_factory_id] = f.[dim_factory_id] AND
                temp.[dim_customer_id] = f.[dim_customer_id] AND
                temp.[dim_construction_type_id] = f.[dim_construction_type_id] AND
                temp.[dim_date_id] = f.[dim_date_id]
    WHERE
        f.[dim_factory_id] IS NULL

    -- Update on match (raw capacity existing for the week)
    UPDATE f
    SET
        f.[capacity_available_weekly] = temp.[capacity_available_weekly]
    FROM
        (
            SELECT *
            FROM [dbo].[fact_factory_capacity]
            WHERE
                [dim_business_id] = @businessid
        ) as f
        INNER JOIN @temp_capacity_available_weekly temp
            ON	temp.[dim_factory_id] = f.[dim_factory_id] AND
                temp.[dim_customer_id] = f.[dim_customer_id] AND
                temp.[dim_construction_type_id] = f.[dim_construction_type_id] AND
                temp.[dim_date_id] = f.[dim_date_id]


    -- Update adjusted capacity (80% second capacity line)
    UPDATE f
    SET
        f.[capacity_available_weekly_adjusted] = f.[capacity_available_weekly] * h.[percentage_adjustment]
    FROM
        (SELECT * FROM [dbo].[fact_factory_capacity] WHERE [dim_business_id] = @businessid) as f
        INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
            ON f.[dim_factory_id] = df.[id]
        INNER JOIN [dbo].[helper_pdas_footwear_vans_factory_capacity_adjustment] h
            ON df.[short_name] = h.[factory_short_name]

    -- Update negative capacity to 0
    UPDATE [dbo].[fact_factory_capacity]
    SET [capacity_raw_weekly] = 0
    WHERE
        [dim_business_id] = @businessid AND
        ISNULL([capacity_raw_weekly], 0) < 0

    UPDATE [dbo].[fact_factory_capacity]
    SET [capacity_raw_daily_overwritten] = 0
    WHERE
        [dim_business_id] = @businessid AND
        ISNULL([capacity_raw_daily_overwritten], 0) < 0

    UPDATE [dbo].[fact_factory_capacity]
    SET [capacity_raw_weekly_overwritten] = 0
    WHERE
        [dim_business_id] = @businessid AND
        ISNULL([capacity_raw_weekly_overwritten], 0) < 0

    UPDATE [dbo].[fact_factory_capacity]
    SET [capacity_available_weekly] = 0
    WHERE
        [dim_business_id] = @businessid AND
        ISNULL([capacity_available_weekly], 0) < 0

    UPDATE [dbo].[fact_factory_capacity]
    SET [capacity_available_weekly_adjusted] = 0
    WHERE
        [dim_business_id] = @businessid AND
        ISNULL([capacity_available_weekly_adjusted], 0) < 0

END
