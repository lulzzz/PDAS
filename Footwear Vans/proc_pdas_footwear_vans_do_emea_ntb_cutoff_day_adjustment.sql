USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to upate the XFD of EMEA NTBs according to the logic based on [dbo].[helper_pdas_footwear_vans_cutoff]
--              1. If the NTB sold to party is "EU DC", take the day from Cutoff Day EU DC field for the corresponding port
--              2. Else if the NTB sold to party is "EU Crossdock", take the day from Cutoff Day EU Crossdock field for the corresponding port
--              3. Else keep Monday (standard)
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_emea_ntb_cutoff_day_adjustment]
	@dim_release_id INT,
	@businessid INT
AS
BEGIN

	-- Declare variables
	DECLARE @dim_demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')

    -- Update the date based on cutoff day table (default day is Monday)
	UPDATE target
	SET
        target.[dim_date_id] =
			CASE target.[sold_to_party]
				WHEN 'EU DC' THEN eu_dc_xfd.[id]
				ELSE eu_crossdock_xfd.[id]
			END
	FROM
    	(
            SELECT
				f.*
				,dc.[sold_to_party]
				,dd.[year_cw_accounting]
            FROM
				[dbo].[fact_demand_total] f
				INNER JOIN
				(
					SELECT
						[id]
						,[sold_to_party]
					FROM
						[dbo].[dim_customer] dc
					WHERE
						[sold_to_party] IN ('EU DC', 'EU Crossdock')
				) as dc
					ON f.[dim_customer_id] = dc.[id]
				INNER JOIN
				(
					SELECT
						[id],
						[year_cw_accounting],
						[day_name_of_week]
					FROM [dbo].[dim_date]
				) dd
					ON f.[dim_date_id] = dd.[id]
            WHERE
				[dim_release_id] = @dim_release_id and
				[dim_business_id] = @businessid and
				[dim_demand_category_id] = @dim_demand_category_id_ntb
        ) target
		INNER JOIN
		(
			SELECT
				df.[id],
				[short_name],
				[port],
				cut.[cutoff_day_eu_dc] as [cutoff_day_eu_dc],
				cut.[cutoff_day_eu_crossdock] as [cutoff_day_eu_crossdock]
			FROM
				[dbo].[dim_factory] df
				LEFT OUTER JOIN [dbo].[helper_pdas_footwear_vans_cutoff] cut
					ON 	df.port = cut.[port_name]
			WHERE is_placeholder = 0
		) df
			ON target.[dim_factory_id] = df.[id]

		LEFT OUTER JOIN -- Cutoff join EU DC
		(
			SELECT
				id,
				[year_cw_accounting],
				[day_name_of_week]
			FROM [dbo].[dim_date]
		) eu_dc_xfd
			ON 	eu_dc_xfd.[year_cw_accounting] = target.[year_cw_accounting] AND
				eu_dc_xfd.day_name_of_week = df.[cutoff_day_eu_dc]

		LEFT OUTER JOIN -- Cutoff join EU Crossdock
		(
			SELECT
				id,
				[year_cw_accounting],
				[day_name_of_week]
			FROM [dbo].[dim_date]
		) eu_crossdock_xfd
			ON 	eu_crossdock_xfd.[year_cw_accounting] = target.[year_cw_accounting] AND
				eu_crossdock_xfd.day_name_of_week = df.[cutoff_day_eu_crossdock]
	WHERE
		(target.[sold_to_party] = 'EU DC' and eu_dc_xfd.[id] IS NOT NULL) or
		(target.[sold_to_party] = 'EU Crossdock' and eu_crossdock_xfd.[id] IS NOT NULL)


END
