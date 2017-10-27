SELECT name
  FROM dbo.sysobjects
 WHERE (type = 'P')
 and name like '%proc_pdas_footwear_vans_do_allocation_%'
 order by name
