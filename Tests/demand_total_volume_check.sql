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
	ASAP,
	CASE ASAP
		WHEN 1 THEN 'ASAP'
		ELSE convert(nvarchar(10), MONTH(CRD))
	END AS CRD,
	[Factory Code (Unconstrained Scenario)],
	SUM(quantity) qty
FROM [dbo].[xl_view_pdas_footwear_vans_demand_total]
GROUP BY
	CASE ASAP
		WHEN 1 THEN 'ASAP'
		ELSE convert(nvarchar(10), MONTH(CRD))
	END,
	[Factory Code (Unconstrained Scenario)],
	ASAP
ORDER BY
	ASAP,
	[Factory Code (Unconstrained Scenario)],
    CRD
