
DECLARE @dim_date_id_pdas_release_day int = (SELECT MAX(dd.[id]) FROM [dbo].[dim_date] dd INNER JOIN [dbo].[dim_pdas] pdas ON pdas.date_id = dd.id)
DECLARE @dim_date_id_pdas_release_day_future int = (SELECT [id] FROM [dbo].[dim_date] WHERE [full_date] = (SELECT DATEADD(yy, 1, full_date) FROM [dbo].[dim_date] WHERE [id] = @dim_date_id_pdas_release_day))


SELECT distinct [exp_delivery_no_constraint_dt]
FROM
	[dbo].[staging_pdas_footwear_vans_emea_ntb_bulk]
	left JOIN
	(
	SELECT
		[id],
		SUBSTRING([year_cw_accounting], 7, 2) AS cw,
		[day_name_of_week]
	FROM [dbo].[dim_date]
	WHERE
		[day_name_of_week] = 'Monday'
		and [id] BETWEEN @dim_date_id_pdas_release_day AND @dim_date_id_pdas_release_day_future
	) dd
		ON REPLACE(SUBSTRING([exp_delivery_no_constraint_dt], 3, 10), ' ', '') = dd.[cw]

		where dd.id is null
