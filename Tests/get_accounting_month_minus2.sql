/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (1000) [id]
      ,[full_date]
      ,[season_buy]
      ,[season_year_buy]
      ,[season_year_short_buy]
      ,[season_crd]
      ,[season_year_crd]
      ,[season_year_short_crd]
      ,[season_intro]
      ,[season_year_intro]
      ,[season_year_short_intro]
      ,[year_accounting]
      ,[year_cw_accounting]
      ,[year_month_accounting]
      ,[month_name_accounting]
      ,[month_name_short_accounting]
      ,[day_of_week]
      ,[day_name_of_week]
      ,[is_last_day_of_month]
      ,[is_weekend_day]
  FROM [dbo].[dim_date]
  where [season_year_intro] = 'Spring 2018'

  SELECT CONVERT(INT, RIGHT([year_month_accounting], 2))-2
  FROM DIM_DATE

	select 'Spring 2018' as [season_year_intro], 'Jan' as [month_name_accounting]

	SELECT
		Year
	FROM [dbo].[dim_date]
	GROUP BY [year_month_accounting],
	CASE [month_name_short_accounting]
			WHEN 'Jan' THEN CONVERT(NVARCHAR(4), [year_accounting] - 1) + '-11'
			WHEN 'Feb' THEN CONVERT(NVARCHAR(4), [year_accounting] - 1) + '-12'
			ELSE CONVERT(NVARCHAR(4), [year_accounting]) + CONVERT(INT, RIGHT([year_month_accounting], 2))-2
		END
	ORDER BY [year_month_accounting]


		[year_month_accounting],
		CASE [month_name_short_accounting]
			WHEN 'Jan' THEN CONVERT(NVARCHAR(4), [year_accounting] - 1) + '-11'
			WHEN 'Feb' THEN CONVERT(NVARCHAR(4), [year_accounting] - 1) + '-12'
			ELSE CONVERT(NVARCHAR(4), [year_accounting]) + CONVERT(INT, RIGHT([year_month_accounting], 2))-2
		END AS [year_month_accounting_minus2],
		MIN([id])
