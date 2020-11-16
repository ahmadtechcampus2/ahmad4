#########################################################################
CREATE FUNCTION fnGetOrderedRemainderByOrderAndStateAndMaterial
( 
	@StartDate	DATETIME = '01/01/1980' 
	,@EndDate	DATETIME = '12/31/2079' 
	,@Type		INT	 -- 5: Sell, 6: Purchase 
	,@Unit		INT	 = 1 -- 1: Unit1, 2: Unit2, 3: Unit3, otherwise Default Unit 
	,@MatGUID   UNIQUEIDENTIFIER = 0x0
	,@OrderGUID UNIQUEIDENTIFIER = 0x0
	,@CustomerGUID	UNIQUEIDENTIFIER = 0x0
	,@StateGUID	UNIQUEIDENTIFIER = 0x0
) 
RETURNS TABLE  
AS 
RETURN ( 
	SELECT
		MatGuid,  
		MatName,
		SUM(ISNULL(OrderedQtySum, 0)) AS Ordered,  
		SUM(ISNULL(achievedQty, 0)) AS Achieved,  
		SUM(ISNULL(OrderedQtySum, 0)) - SUM(ISNULL(achievedQty, 0)) AS Remainder,
		SUM(ISNULL(StateQty, 0)) AS StateQty
	FROM  
	(  
		-- Ordered Part 
		SELECT 
			bi.biMatPtr AS MatGuid,
			bi.mtName AS MatName,
			(bi.biQty / 
					(CASE @Unit 
						WHEN 1 THEN 1 
						WHEN 2 THEN ISNULL(CASE bi.[mtUnit2Fact] WHEN 0 THEN 1 ELSE bi.[mtUnit2Fact] END, 1)   
						WHEN 3 THEN ISNULL(CASE bi.[mtUnit3Fact] WHEN 0 THEN 1 ELSE bi.[mtUnit3Fact] END, 1)  
						ELSE ISNULL(CASE bi.[mtDefUnitFact] WHEN 0 THEN 1 ELSE bi.[mtDefUnitFact] END, 1)  
					END) 
			) AS OrderedQtySum 
			,0 AS achievedQty
			,0 AS StateQty
		FROM  
			vwExtended_bi bi  
			-- no need to join with ori000 to know ordered quantity 
		WHERE  
			
			(([buGUID] = @OrderGUID) AND (@OrderGUID <> 0x0)
				OR
				 ( (@OrderGUID = 0x0) AND [buGUID] IN ( 
						SELECT [GUID] FROM bu000 WHERE TypeGuid IN 
							(SELECT [GUID] FROM bt000 WHERE [TYPE] = @Type) 
					))
			)
			AND  
			([buDate] BETWEEN @StartDate AND @EndDate) 
			AND 
			((bi.biMatPtr = @MatGUID) OR (@MatGUID = 0x0))
			AND
			(((bi.buCustPtr = @CustomerGUID) AND (@CustomerGUID <> 0x0)) 
				OR
				(@CustomerGUID = 0x0)
			)
		UNION ALL 
		-- Achieved Part 
		SELECT  
			vbi.biMatPtr AS MatGuid, 
			vbi.mtName AS MatName,
			0 AS OrderedQtySum, 
			(ori.Qty / 
					(CASE @Unit 
						WHEN 1 THEN 1 
						WHEN 2 THEN ISNULL(CASE vbi.[mtUnit2Fact] WHEN 0 THEN 1 ELSE vbi.[mtUnit2Fact] END, 1)   
						WHEN 3 THEN ISNULL(CASE vbi.[mtUnit3Fact] WHEN 0 THEN 1 ELSE vbi.[mtUnit3Fact] END, 1)  
						ELSE ISNULL(CASE vbi.[mtDefUnitFact] WHEN 0 THEN 1 ELSE vbi.[mtDefUnitFact] END, 1)  
					END) 
			) AS AchievedQtySum 
			,0 AS StateQty
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
			((ori.POGUID = @OrderGUID) AND (@OrderGUID <> 0x0)
				OR
				 ( (@OrderGUID = 0x0) AND ori.POGUID IN ( 
						SELECT [GUID] FROM bu000 WHERE TypeGuid IN 
							(SELECT [GUID] FROM bt000 WHERE [TYPE] = @Type) 
					))
			)
			AND  
			TypeGuid in (SELECT [GUID] FROM oit000 WHERE operation = 1) 
			AND 
			buDate BETWEEN @StartDate AND @EndDate 
			AND 
			((vbi.biMatPtr = @MatGUID) OR (@MatGUID = 0x0))
			AND
			(((vbi.buCustPtr = @CustomerGUID) AND (@CustomerGUID <> 0x0)) 
				OR
				(@CustomerGUID = 0x0)
			)
		UNION ALL
		-- State Part
		SELECT 
			@MatGUID AS MatGuid,
			(Select Name FROM mt000 WHERE GUID = @MatGUID) AS MatName,
			0 AS OrderedQtySum,
			0 AS AchievedQtySum 
			,(
			CASE 
			WHEN (@OrderGUID <> 0x00) AND (@StateGUID <> 0x00) THEN ori.Qty /
			(CASE @Unit 
						WHEN 1 THEN 1 
						WHEN 2 THEN ISNULL(CASE vbi.[mtUnit2Fact] WHEN 0 THEN 1 ELSE vbi.[mtUnit2Fact] END, 1)   
						WHEN 3 THEN ISNULL(CASE vbi.[mtUnit3Fact] WHEN 0 THEN 1 ELSE vbi.[mtUnit3Fact] END, 1)  
						ELSE ISNULL(CASE vbi.[mtDefUnitFact] WHEN 0 THEN 1 ELSE vbi.[mtDefUnitFact] END, 1)  
					END)
			ELSE 0 
			END) AS StateQty
		FROM
			ori000 ori
			INNER JOIN vwExtended_bi vbi ON vbi.biGUID = ori.POIGUID 
		WHERE  
			(POGuid =  @OrderGUID)
			AND
			(TypeGuid = @StateGUID)
			AND (vbi.biMatPtr = @MatGUID)
	) ResultTable 
	GROUP BY  
		MatGuid, MatName
) 
#########################################################################
#END