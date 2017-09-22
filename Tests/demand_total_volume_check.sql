
USE [VCDWH]
GO

SELECT
    [Year Month Accounting]
	,[Demand Category]
	,[Buying Program]
	,[Customer Region]
	,SUM(quantity)
FROM [dbo].[xl_view_pdas_footwear_vans_demand_total]
WHERE [dim_pdas_id] = (SELECT MAX(ID) FROM [dbo].[dim_pdas])
GROUP BY
	[Year Month Accounting]
	,[Demand Category]
	,[Buying Program]
	,[Customer Region]
ORDER BY
	[Year Month Accounting]
	,[Demand Category]
	,[Buying Program]
	,[Customer Region]
