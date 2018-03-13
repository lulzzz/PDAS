SELECT distinct comment_region
  FROM [VCDWH].[dbo].[fact_demand_total]
  where
	dim_pdas_id = (select max(id) from dim_pdas)
	and dim_buying_program_id = 14
	and dim_demand_category_id = 22
	and is_from_previous_release = 0
