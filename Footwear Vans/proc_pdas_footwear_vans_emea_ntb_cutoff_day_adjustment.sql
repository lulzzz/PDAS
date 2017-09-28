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


    -- Update the date based on cutoff day table (default day is Monday)
	CASE
		WHEN dc.[sold_to_party] = 'EU DC' AND dd_xfd.[id] IS NOT NULL THEN dd_xfd.[id]
		ELSE '2017-09-27'
	END as dim_date_id,
	UPDATE target
        target.[dim_date_id] = dd.[id]
	FROM
    	(
            SELECT *
            FROM [dbo].[fact_demand_total]
            WHERE dim_pdas_id = @pdasid and dim_business_id = @businessid
        ) target
        INNER JOIN
		[dbo].[staging_pdas_footwear_vans_emea_ntb_bulk] ntb
		INNER JOIN (SELECT [id], [name], [sold_to_party] FROM [dbo].[dim_customer] WHERE is_placeholder = 0) dc
			ON ntb.dim_customer_name = dc.name
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
		LEFT OUTER JOIN [dbo].[dim_date] dd_buy ON ntb.buy_dt = dd_buy.full_date
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
