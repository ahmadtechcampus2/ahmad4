#########################################################
CREATE VIEW vwMatQtys
As
	SELECT
		[biMatPtr] AS [ReadyMatPtr],
		[mtName] AS [ReadyMatName],
		SUM([biBillQty]) AS [ReadyMatTotalQty],
		[mtDefUnitName] AS [ReadyMatUnit],
		[budate] As [BillDate],
		[butype] AS [BillType],
		[bucostptr] AS [BillCostPtr],
		[buSecurity],
		[mtSecurity]
	FROM
		[vwExtended_bi]
	GROUP BY
		[biMatPtr],
		[mtName],
		[buDate],
		[buType],
		[buCostPtr],
		[mtDefUnitName],
		[buSecurity],
		[mtSecurity]

#########################################################
#END