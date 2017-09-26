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
    DELETE FROM [dbo].[fact_factory_capacity]
    WHERE dim_pdas_id = @pdasid and dim_business_id = @businessid;

    -- Insert from staging
    INSERT INTO [dbo].[fact_factory_capacity]
    (
        [dim_pdas_id]
        ,[dim_business_id]
        ,[dim_factory_id]
        ,[dim_construction_type_id]
        ,[dim_date_id]
        ,[capacity_daily]
        ,[capacity_weekly]
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
		END as dim_construction_type_id,
        dd.[id] as dim_date_id,
        sum(ISNULL(cap.[quantity], 0)) as capacity_daily,
        0 as capacity_weekly
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
		) mapping_cons ON cap.dim_construction_type_name = mapping_cons.child

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

	DECLARE @temp_capacity TABLE(
		[dim_pdas_id] INT
		,[dim_business_id] INT
		,[dim_factory_id] INT
		,[dim_construction_type_id] INT
		,[dim_date_id] INT
		,[capacity_daily] INT
		,[capacity_weekly]	INT
	)

	;WITH [pivoted_factory_capacity] AS (
	SELECT
		u.[dim_factory_id]
		,u.[dim_construction_type_id]
		,CONVERT(NVARCHAR(4), u.[year_cw_accounting]) + 'CW' + RIGHT(u.[cw], 2) AS [year_cw_accounting]
		,u.[quantity] AS [capacity_weekly]
	FROM
		(
		SELECT
			CASE
				WHEN df.id IS NOT NULL THEN df.id
				ELSE mapping_f.id
			END as dim_factory_id,
			CASE
				WHEN cons.[id] IS NOT NULL THEN cons.[id]
				ELSE mapping_cons.id
			END as dim_construction_type_id
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
				WHERE type = 'Factory Master'
			) mapping_f ON cap.dim_factory_short_name = mapping_f.child

			LEFT OUTER JOIN [dbo].[dim_construction_type] cons ON cap.dim_construction_type_name = cons.name
			LEFT OUTER JOIN
			(
				SELECT cons.id, m.child
				FROM
					[dbo].[helper_pdas_footwear_vans_mapping] m
					INNER JOIN (SELECT id, name FROM [dbo].[dim_construction_type]) cons
						ON m.parent = cons.name
				WHERE type = 'Construction Type Master'
			) mapping_cons ON cap.dim_construction_type_name = mapping_cons.child
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
	[target_factory_capacity] AS (
		SELECT
			dd.[id] as [dim_date_id],
			piv.[dim_factory_id] as [dim_factory_id],
			piv.[dim_construction_type_id] as [dim_construction_type_id],
			piv.[capacity_weekly] as [capacity_weekly]
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

	INSERT INTO @temp_capacity
	(
		[dim_pdas_id]
		,[dim_business_id]
		,[dim_factory_id]
		,[dim_construction_type_id]
		,[dim_date_id]
		,[capacity_daily]
		,[capacity_weekly]
	)
	SELECT
		@pdasid as dim_pdas_id,
        @businessid as dim_business_id,
		temp.[dim_factory_id],
		temp.[dim_construction_type_id],
		temp.[dim_date_id],
		0 as [capacity_daily],
		temp.[capacity_weekly]
	FROM
		[target_factory_capacity] temp


	-- Insert on non-match
	INSERT INTO [dbo].[fact_factory_capacity]
	SELECT temp.*
	FROM
		@temp_capacity temp
		LEFT JOIN
		(SELECT * FROM [fact_factory_capacity] WHERE [dim_pdas_id] = @pdasid AND [dim_business_id] = @businessid) as f
			ON	temp.[dim_factory_id] = f.[dim_factory_id] AND
				temp.[dim_construction_type_id] = f.[dim_construction_type_id] AND
				temp.[dim_date_id] = f.[dim_date_id]
	WHERE f.[dim_factory_id] IS NULL

	-- Update on match
	UPDATE f
	SET
		f.[capacity_weekly] = temp.[capacity_weekly]
	FROM
		(SELECT * FROM [fact_factory_capacity] WHERE [dim_pdas_id] = @pdasid AND [dim_business_id] = @businessid) as f
		INNER JOIN @temp_capacity temp
			ON	temp.[dim_factory_id] = f.[dim_factory_id] AND
				temp.[dim_construction_type_id] = f.[dim_construction_type_id] AND
				temp.[dim_date_id] = f.[dim_date_id]


END
