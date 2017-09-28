use ESPSODV14RPT

select count(*)
FROM Prbunhea
WHERE
	Prbunhea.ModifiedOn >= '2017-01-01'
-- 2,100,827 rows
-- 3:38

select count(*)
FROM
	Prbunhea
	LEFT OUTER JOIN Nbbundet WITH (nolock) ON (Prbunhea.Id_Cut=Nbbundet.Id_Cut)
WHERE
	Prbunhea.ModifiedOn >= '2017-01-01' 
-- 8,011,694
-- 2:02



SELECT DISTINCT
	LTRIM(RTRIM(Shipped.shipment)) as shipment,
	LTRIM(RTRIM(Prbunhea.rdacode)) as rdacode,
	LTRIM(RTRIM(Prbunhea.rfactory)) as rfactory,
	LTRIM(RTRIM(Prbunhea.lot)) as lot,
	LTRIM(RTRIM(Prbunhea.misc1)) as misc1,
	LTRIM(RTRIM(Nbbundet.size)) as size,
	LTRIM(RTRIM(Nbbundet.color)) as color,
	LTRIM(RTRIM(Nbbundet.dimension)) as dimension,
	LTRIM(RTRIM(Prbunhea.plan_date)) as plan_date,
	LTRIM(RTRIM(Shipment.closed)) as closed,
	LTRIM(RTRIM(Prbunhea.misc6)) as misc6,
	SUM(Nbbundet.qty) as qty,
	SUM(Shipped.unitship) as unitship,
	LTRIM(RTRIM(Prbunhea.style)) as style,
	LTRIM(RTRIM(Shshipto.ship_to_1)) as ship_to_1,
	LTRIM(RTRIM(Shshipto_2.ship_to_1)) as ship_to_1_bis,
	LTRIM(RTRIM(Prbunhea.ship_no)) as ship_no,
	LTRIM(RTRIM(Prbunhea.misc25)) as misc25,
	LTRIM(RTRIM(Prbunhea.misc41)) as misc41,
	LTRIM(RTRIM(Prbunhea.store_no)) as store_no,
	LTRIM(RTRIM(Prbunhea.origdd)) as origdd,
	LTRIM(RTRIM(Prbunhea.revdd)) as revdd,
	LTRIM(RTRIM(Shipped.shipdate)) as shipdate,
	LTRIM(RTRIM(CONVERT(VARCHAR(8000), Prbunhea.notes))) as notes,
	LTRIM(RTRIM(Prbunhea.misc18)) as misc18,
	LTRIM(RTRIM(Shipment.misc2)) as misc2,
	LTRIM(RTRIM(Prscale.desce)) as desce,
	LTRIM(RTRIM(Prbunhea.misc21)) as misc21,
	LTRIM(RTRIM(Shipment.firstclosedon)) as firstclosedon,
	LTRIM(RTRIM(Prbunhea.done)) as done,
	LTRIM(RTRIM(Shipmast.shipname)) as shipname
FROM
	Prbunhea
	LEFT OUTER JOIN Nbbundet WITH (nolock) ON (Prbunhea.Id_Cut=Nbbundet.Id_Cut)
	LEFT OUTER JOIN Shipped WITH (nolock)ON (Prbunhea.Season=Shipped.Season AND Prbunhea.Style=Shipped.Style AND Prbunhea.Lot=Shipped.Cut AND Nbbundet.Color=Shipped.Color AND Nbbundet.Size=Shipped.Size AND Nbbundet.Dimension=Shipped.Dimension)
	LEFT OUTER JOIN Shipment WITH (nolock)ON (Shipped.Shipment=Shipment.Shipment)
	LEFT OUTER JOIN Shshipto WITH (nolock) ON (Prbunhea.Rdacode=Shshipto.Factory)
	LEFT OUTER JOIN shshipto as Shshipto_2 WITH (nolock) ON (Prbunhea.Rfactory=Shshipto_2.Factory)
	LEFT OUTER JOIN prscale WITH (nolock) ON (nbbundet.size=prscale.scale)
	LEFT OUTER JOIN Shipmast WITH (nolock) ON (Shipmast.shipno=Prbunhea.Store_No)
WHERE
	Prbunhea.ModifiedOn >= '2017-01-01'
	AND Prbunhea.Misc21 IN ('CONDOR', 'JBA-VF', 'JBA-VS', 'REVA', 'S65')
	AND Prbunhea.Misc6 IN ('OCN', 'OIN', 'OSA', 'VF ASIA', 'VF INDIA', 'VF Thailand', 'VFA', 'VFA Bangladesh', 'VFA Guangzhou', 'VFA HongKong', 'VFA India', 'VFA Indonesia', 'VFA Qingdao', 'VFA Shanghai', 'VFA Vietnam', 'VFA Zhuhai', 'VFI')
	AND Prbunhea.Misc1 IN ('50 VANS FOOTWEAR', '503', '503 VN_Footwear', '508', '508 VN_Snow Footwear', '56 VANS SNOWBOOTS', 'VANS Footwear', 'VANS FOOTWEAR', 'VANS Snowboots', 'VANS SNOWBOOTS', 'VF  Vans Footwear', 'VN_Footwear', 'VN_Snow Footwear', 'VS  Vans Snowboots')
	AND	Prbunhea.Misc25 IN ('DS', 'DYO', 'PG', 'REGULAR', 'ZCS', 'ZCUS', 'ZDIR', 'ZFGP', 'ZOT', 'ZRDS', 'ZTP', 'ZVFL', 'ZVFS')
	AND Not (Prbunhea.Qtyship=0 AND Prbunhea.Done=1)
	AND Prbunhea.POLocation NOT IN('CANCELED')
	AND  Not(Nbbundet.qty=0)

GROUP BY
	Shipped.shipment,
	Prbunhea.rdacode,
	Prbunhea.rfactory,
	Prbunhea.lot,
	Prbunhea.misc1,
	Nbbundet.size,
	Nbbundet.color,
	Nbbundet.dimension,
	Prbunhea.plan_date,
	Shipment.closed,
	Prbunhea.misc6,
	Prbunhea.style,
	Shshipto.ship_to_1,
	Shshipto_2.ship_to_1,
	Prbunhea.ship_no,
	Prbunhea.misc25,
	Prbunhea.misc41,
	Prbunhea.store_no,
	Prbunhea.origdd,
	Prbunhea.revdd,
	Shipped.shipdate,
	CONVERT(VARCHAR(8000), Prbunhea.notes),
	Prbunhea.misc18,
	Shipment.misc2,
	Prscale.desce,
	Prbunhea.misc21,
	Shipment.firstclosedon,
	Prbunhea.done,
	Shipmast.shipname
