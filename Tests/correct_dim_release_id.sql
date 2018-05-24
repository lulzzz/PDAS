update t
set t.dim_release_id =  s.dim_release_id
from
	fact_demand_total t
	inner join
	(
		SELECT
			dim_release.[id] as dim_release_id,
			dim_date.[id] as dim_date_id_buy_month,
			[dim_buying_program_id]
		FROM
		(
			SELECT [id], [buy_month], [dim_buying_program_id]
			FROM [dbo].[dim_release]
		) dim_release
		INNER JOIN
		(
			SELECT
				MIN([id]) as [id]
				,[year_month_accounting]
			FROM [dbo].[dim_date]
			GROUP BY [year_month_accounting]
		) dim_date
			ON dim_release.[buy_month] = dim_date.[year_month_accounting]
	) s
		on
			t.dim_date_id_buy_month = s.dim_date_id_buy_month
			and t.[dim_buying_program_id] = s.[dim_buying_program_id]
