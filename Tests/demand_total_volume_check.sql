-- Month Demand Signal Type
SELECT
	[Accounting Month],
	[Demand Signal Type],
	SUM(quantity) qty
FROM [dbo].[xl_view_pdas_footwear_vans_demand_total]
GROUP BY
	[Accounting Month],
	[Demand Signal Type]
ORDER BY
	[Accounting Month],
	[Demand Signal Type]

-- Month Region
SELECT
	ASAP,
	CASE ASAP
		WHEN 1 THEN 'ASAP'
		ELSE convert(nvarchar(10), MONTH(CRD))
	END AS CRD,
	[Customer Region],
	SUM(quantity) qty
FROM [dbo].[xl_view_pdas_footwear_vans_demand_total]
GROUP BY
	CASE ASAP
		WHEN 1 THEN 'ASAP'
		ELSE convert(nvarchar(10), MONTH(CRD))
	END,
	[Customer Region],
	ASAP
ORDER BY
	ASAP,
	[Customer Region],
    CRD


-- Month Factory
SELECT
	[Urgency],
	convert(nvarchar(10), MONTH(CRD)) crd_month,
	[Factory Code (Constrained)],
	SUM(quantity) qty
FROM [dbo].[xl_view_pdas_footwear_vans_demand_total]
where
[Demand Signal Type] in ('Need to Buy')
GROUP BY
	[Urgency],
	convert(nvarchar(10), MONTH(CRD)),
	[Factory Code (Constrained)]
ORDER BY
	[Urgency],
	convert(nvarchar(10), MONTH(CRD)),
	[Factory Code (Constrained)]
