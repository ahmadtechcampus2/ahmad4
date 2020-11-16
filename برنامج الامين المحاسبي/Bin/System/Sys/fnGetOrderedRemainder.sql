#########################################################################
CREATE FUNCTION fnGetOrderedRemainder 
(
	@StartDate	DATETIME = '01/01/1980'
	,@EndDate	DATETIME = '12/31/2079'
	,@Type		INT	 -- 5: Sell, 6: Purchase
	,@Unit		INT	 = 0 -- 0: Unit1, 1: Unit2, 2: Unit3, otherwise Default Unit
)
RETURNS TABLE 
AS
RETURN (
	SELECT 
		mtGuid, 
		SUM(ISNULL(OrderedQtySum, 0)) AS Ordered, 
		SUM(ISNULL(achievedQty, 0)) AS Achieved, 
		SUM(ISNULL(OrderedQtySum, 0)) - SUM(ISNULL(achievedQty, 0)) AS Remainder
	FROM 
	( 
		-- Ordered Part
		SELECT
			bi.biMatPtr AS mtGuid
			,(bi.biQty /
					(CASE @Unit
						WHEN 0 THEN 1
						WHEN 1 THEN ISNULL(CASE bi.[mtUnit2Fact] WHEN 0 THEN 1 ELSE bi.[mtUnit2Fact] END, 1)  
						WHEN 2 THEN ISNULL(CASE bi.[mtUnit3Fact] WHEN 0 THEN 1 ELSE bi.[mtUnit3Fact] END, 1) 
						ELSE ISNULL(CASE bi.[mtDefUnitFact] WHEN 0 THEN 1 ELSE bi.[mtDefUnitFact] END, 1) 
					END)
			) AS OrderedQtySum
			,0 AS achievedQty 
		FROM 
			vwExtended_bi bi 
			-- no need to join with ori000 to know ordered quantity
		WHERE 
			[buGUID] IN 
				(
					SELECT [GUID] FROM bu000 WHERE TypeGuid IN
						(SELECT [GUID] FROM bt000 WHERE [TYPE] = @Type)
				)
			AND 
			([buDate] BETWEEN @StartDate AND @EndDate)
		UNION ALL
		-- Achieved Part
		SELECT 
			vbi.biMatPtr AS mtGuid,
			0 AS OrderedQtySum,
			(ori.Qty /
					(CASE @Unit
						WHEN 0 THEN 1
						WHEN 1 THEN ISNULL(CASE vbi.[mtUnit2Fact] WHEN 0 THEN 1 ELSE vbi.[mtUnit2Fact] END, 1)  
						WHEN 2 THEN ISNULL(CASE vbi.[mtUnit3Fact] WHEN 0 THEN 1 ELSE vbi.[mtUnit3Fact] END, 1) 
						ELSE ISNULL(CASE vbi.[mtDefUnitFact] WHEN 0 THEN 1 ELSE vbi.[mtDefUnitFact] END, 1) 
					END)
			) AS AchievedQtySum
		FROM
			ori000 ori
			INNER JOIN 
				(
					SELECT [GUID] FROM bu000 WHERE TypeGuid IN
						(SELECT [GUID] FROM bt000 WHERE [TYPE] = @Type)
				) bu ON bu.[GUID] = ori.POGUID
			INNER JOIN 
				vwExtended_bi vbi ON vbi.biGUID = ori.POIGUID
		WHERE 
			ori.BuGuid <> 0x0
			AND 
			TypeGuid in (SELECT [GUID] FROM oit000 WHERE operation = 1)
			AND
			buDate BETWEEN @StartDate AND @EndDate
	) xyz
	GROUP BY 
		mtGuid
)
#########################################################################
#END