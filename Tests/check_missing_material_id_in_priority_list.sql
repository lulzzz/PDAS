select distinct material_id
from [dbo].[fact_demand_total] f
inner join dim_product dp
on f.dim_product_id = dp.id
where material_id  in (select distinct material_id
from fact_priority_list f
inner join dim_product dp
on f.dim_product_id = dp.id
)
and dim_demand_category_id = 22


SELECT *
  FROM [VCDWH].[dbo].[staging_pdas_footwear_vans_priority_list]
  where [dim_product_material_id] in (
  'VN00015GJKTP',
'VN0A38ENQA6P'
)
