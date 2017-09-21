97635 => total

58341 => join on product

4901 => join on customer


SELECT count(*)
  FROM [VCDWH].[dbo].[staging_pdas_footwear_vans_ngc_po] ngc
  INNER JOIN [dbo].[dim_customer] dc ON ngc.dc_name = dc.name
  INNER JOIN [dbo].[dim_product] dp ON ngc.dim_product_style_id = dp.material_id and ngc.dim_product_size = dp.size
