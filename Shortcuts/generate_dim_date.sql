
exec [dbo].[proc_pdas_footwear_vans_load_dim_date]
	@FiscalCalendarStart = '2010-01-03',
	@FiscalCalendarEnd = '2050-01-01',
	@FiscalStartingMonth = 1,
	@MonthExtraWeekAdded = 12



SELECT min([full_date]), max([full_date]), count(*)
  FROM [VCDWH].[dbo].[dim_date]


select year_accounting, year_month_accounting, season_year_accounting, season_year_short_accounting, month_name_short_accounting, min(id) d  from dim_date
where season_year_short_accounting IN ('SP17', 'FA17', 'HO17')
group by year_accounting, year_month_accounting,  season_year_accounting, season_year_short_accounting, month_name_short_accounting
order by d
