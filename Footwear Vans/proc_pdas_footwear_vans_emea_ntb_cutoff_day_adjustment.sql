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
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_emea_ntb_cutoff_day_adjustment]
	@pdasid INT,
	@businessid INT,
	@buying_program_id INT
AS
BEGIN

	-- Declare variables
	DECLARE @dim_demand_category_id_ntb int = (SELECT id FROM [dbo].[dim_demand_category] WHERE name = 'Need to Buy')

    -- Update the date based on cutoff day table (default day is Monday)
	UPDATE target
        target.[dim_date_id] =
			CASE target.[sold_to_party]
				WHEN 'EU DC' THEN dd_xfd.[id]
				ELSE
			END
	FROM
    	(
            SELECT *
            FROM
				[dbo].[fact_demand_total] f
				INNER JOIN
				(
					SELECT
						[id]
					FROM
						[dbo].[dim_customer] dc
					WHERE [sold_to_party] IN ('EU DC', 'EU Crossdock')
				) as dc
					ON f.[dim_customer_id] = dc.[id]
            WHERE
				[dim_pdas_id] = @pdasid and
				[dim_business_id] = @businessid and
				[dim_demand_category_id] = @dim_demand_category_id_ntb
        ) target
		INNER JOIN
		(
			SELECT [id], [short_name], [port], cut.[Cutoff Weekday] as [cutoff_day], cut.[Season Year] as [cutoff_season]
			FROM
				[dbo].[dim_factory] df
				LEFT OUTER JOIN [dbo].[helper_pdas_footwear_vans_cutoff] cut
					ON 	df.port = cut.[Port Name]
			WHERE is_placeholder = 0
		) df
			ON ntb.vfa_allocation = df.short_name
		LEFT OUTER JOIN -- Cutoff join
		(
			SELECT
				id,
				SUBSTRING([year_cw_accounting], 7, 2) AS cw,
				[day_name_of_week],
				[season_year_short_crd]
			FROM [dbo].[dim_date]
		) dd_xfd
			ON 	dd_xfd.cw = SUBSTRING([exp_delivery_no_constraint_dt], 3, 5) AND
				dd_xfd.day_name_of_week = df.[cutoff_day] AND
				dd_xfd.season_year_short_crd = df.[cutoff_season]


END
