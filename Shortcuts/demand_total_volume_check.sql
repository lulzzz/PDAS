USE [VCDWH]
GO

SELECT [Year Month Accounting]
	,[Demand Category]
	,sum(quantity)
  FROM [VCDWH].[dbo].[xl_view_pdas_footwear_vans_demand_total]
  WHERE [dim_pdas_id] = (SELECT MAX(ID) FROM [dim_pdas])
  GROUP BY
	[Year Month Accounting]
	,[Demand Category]
ORDER BY
	[Year Month Accounting]
	,[Demand Category]
