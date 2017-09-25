
USE [VCDWH]
GO

SELECT
    [Accounting Month]
	,[Demand Signal Type]
	,[Buying Program]
	,[Customer Region]
	,SUM(quantity)
FROM [dbo].[xl_view_pdas_footwear_vans_demand_total]

GROUP BY
	[Accounting Month]
	,[Demand Signal Type]
	,[Buying Program]
	,[Customer Region]
ORDER BY
[Accounting Month]
	,[Demand Signal Type]
	,[Buying Program]
	,[Customer Region]
