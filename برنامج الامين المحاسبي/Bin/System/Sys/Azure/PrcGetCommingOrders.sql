#########################################################################
CREATE PROCEDURE PrcGetCommingOrders
	@StartDate		DATETIME
	,@EndDate		DATETIME
	,@ReportSources	UNIQUEIDENTIFIER = 0x0
	,@MatFldsFlag	BIGINT = 0 
	,@CustFldsFlag	BIGINT = 0
	,@OrderFldsFlag	BIGINT = 0
	,@MatCFlds 		NVARCHAR(max) = ''
	,@CustCFlds 	NVARCHAR(max) = ''
	,@OrderCFlds 	NVARCHAR(max) = ''
	,@IsDetailed	BIT = 1
	,@Material		UNIQUEIDENTIFIER = 0x00
	,@Group			UNIQUEIDENTIFIER = 0x00
	,@CostCenter	UNIQUEIDENTIFIER = 0x00
	,@Store			UNIQUEIDENTIFIER = 0x00
	,@Unit			INT = 0
	,@Customer		UNIQUEIDENTIFIER = 0x00
	,@OrderCond		UNIQUEIDENTIFIER = 0x00
AS
BEGIN
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON

	CREATE TABLE [#MatTbl]([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]([CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CustTbl]([CustGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	
	CREATE TABLE #OrderCond (OrderGuid UNIQUEIDENTIFIER, [Security] [INT])
	INSERT INTO [#OrderCond](OrderGuid, [Security]) EXEC [prcGetOrdersList] @OrderCond
	
	-- PRODUCES ##MatFlds
	EXEC GetMatFlds   @MatFldsFlag,   @MatCFlds 
	
	-- PRODUCES ##CustFlds
	EXEC GetCustFlds  @CustFldsFlag,  @CustCFlds 
	
	-- PRODUCES ##OrderFlds
	EXEC GetOrderFlds @OrderFldsFlag, @OrderCFlds
	
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@Material, @Group ,-1, 0x0 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@Store
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		0X00
	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList]		@Customer, 0x0, 0x0
	INSERT INTO [#CustTbl]			SELECT 0x0, 1

	SELECT 
		* 
	INTO
		#MainData
	FROM
		( 
		SELECT 
			vwbi.biMatPtr AS mtGuid,
			vwbi.mtName,
			vwbi.mtCode,
			vwbi.buGUID AS OrderGuid, 
			vwbi.buType AS OrderTypeGuid,
			CONVERT(UNIQUEIDENTIFIER, 0x00) AS OrderOriginGuid,
			CONVERT(UNIQUEIDENTIFIER, 0x00) AS OrderOriginTypeGuid,  
			vwbi.buDate AS OrderDate,
			(bt.Abbrev + ': ' + CONVERT(NVARCHAR(50), bu.[Number])) AS OrderName, 
			(vwbi.biQty /
				(CASE @Unit
					WHEN 0 THEN 1
					WHEN 1 THEN vwbi.mtUnit2Fact
					WHEN 2 THEN vwbi.mtUnit3Fact
					ELSE vwbi.mtDefUnitFact
				END)
			) AS OrderedQtySum,
			0 AS AchievedQty,
			vwbi.mtUnityName AS Unit,
			ISNULL(cu2.CustomerName, '')AS CustomerName,
			mtflds.*,
			O.*,
			C.*
		FROM 
			vwExtended_bi vwbi 
			INNER JOIN bu000 bu ON bu.GUID = vwbi.buGUID
			INNER JOIN bt000 bt ON bt.[GUID] = bu.[TypeGUID]
			INNER JOIN ##MatFlds mtflds ON mtflds.MatFldGuid = vwbi.biMatPtr
			INNER JOIN ##OrderFlds O ON O.OrderFldGuid = vwbi.buGUID
			INNER JOIN #OrderCond OC ON OC.OrderGuid = vwbi.buGUID
			LEFT JOIN ##CustFlds C ON C.CustFldGuid = vwbi.buCustPtr 
			INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [vwbi].[biMatPtr]
			INNER JOIN [#StoreTbl] AS [st] ON st.[StoreGUID] = [vwbi].[biStorePtr]
			LEFT JOIN [#CostTbl] AS [co] ON ((co.[CostGUID] = [vwbi].[biCostPtr]) OR (co.[CostGUID] = bu.[CostGUID]))
			INNER JOIN [#CustTbl] AS [cu] ON [cu].CustGuid = vwbi.[buCustPtr]
			LEFT JOIN cu000 cu2 ON cu2.[GUID] = vwbi.[buCustPtr] OR cu2.[Guid] = 0x00
			-- no need to join with ori000 to know ordered quantity
		WHERE 
			buGUID IN 
			(SELECT 
					bu.[GUID]
				FROM
					bu000 bu
					INNER JOIN RepSrcs rs ON [IdType] = bu.TypeGUID
					INNER JOIN ORADDINFO000 oinf ON oinf.ParentGuid = bu.[GUID]
				WHERE
					oinf.Finished = 0
					AND
					oinf.Add1 = 0
					AND
					rs.IdTbl = @ReportSources
					AND
					TypeGuid IN	(SELECT [GUID] FROM bt000 WHERE [TYPE] = 6)
					AND
					bu.[Date] BETWEEN @StartDate AND @EndDate
			)
			AND
			((@CostCenter = 0x00) OR ([vwbi].[biCostPtr] = @CostCenter) OR (bu.CostGUID = @CostCenter))
			AND
			((@Customer = 0X00) OR (vwbi.buCustPtr = @Customer))
		UNION ALL
		SELECT 
			vbi.biMatPtr AS mtGuid,
			vbi.mtName,
			vbi.mtCode,
			bu.GUID AS OrderGuid, 
			bu.TypeGuid AS OrderTypeGuid,
			CONVERT(UNIQUEIDENTIFIER, 0x00) AS OrderOriginGuid,
			CONVERT(UNIQUEIDENTIFIER, 0x00) AS OrderOriginTypeGuid,
			bu.[Date] AS OrderDate,
			(bt.Abbrev + ': ' + CONVERT(NVARCHAR(50), bu.[Number])) AS OrderName, 
			0 AS OrderedQtySum, 
			(ori.Qty /
				(CASE @Unit
					WHEN 0 THEN 1
					WHEN 1 THEN vbi.mtUnit2Fact
					WHEN 2 THEN vbi.mtUnit3Fact
					ELSE vbi.mtDefUnitFact
				END)
			) AS AchievedQtySum,
			vbi.mtUnityName AS Unit,
			ISNULL(cu2.[CustomerName], '') AS CustomerName,
			mtflds.*,
			O.*,
			C.*
		FROM ori000 ori
			INNER JOIN bu000 bu ON bu.GUID = ori.POGUID
			INNER JOIN bt000 bt ON bt.[GUID] = bu.[TypeGUID]
			INNER JOIN 
				vwExtended_bi vbi ON vbi.biGUID = ori.POIGUID
			INNER JOIN ##MatFlds mtflds ON mtflds.MatFldGuid = vbi.biMatPtr
			INNER JOIN ##OrderFlds O ON O.OrderFldGuid = vbi.buGUID
			INNER JOIN #OrderCond OC ON OC.OrderGuid = vbi.buGUID
			LEFT JOIN ##CustFlds C ON C.CustFldGuid = vbi.buCustPtr
			INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [vbi].[biMatPtr]
			INNER JOIN [#StoreTbl] AS [st] ON st.[StoreGUID] = [vbi].[biStorePtr]
			LEFT JOIN [#CostTbl] AS [co] ON ((co.[CostGUID] = [vbi].[biCostPtr]) OR (co.[CostGUID] = bu.CostGUID))
			INNER JOIN [#CustTbl] AS [cu] ON [cu].CustGuid = vbi.[buCustPtr]
			LEFT JOIN cu000 cu2 ON cu2.[GUID] = vbi.[buCustPtr]  OR cu2.[Guid] = 0x00
		WHERE 
			bu.TypeGuid IN
				(SELECT DISTINCT [GUID] FROM bt000 WHERE [TYPE] = 6)
			AND
			bu.[Date] BETWEEN @StartDate AND @EndDate
			AND
			ori.BuGuid <> 0x0
			AND 
			ori.TypeGuid IN (SELECT [GUID] FROM oit000 WHERE operation = 1)
			AND
			((@CostCenter = 0x00) OR ([vbi].[biCostPtr] = @CostCenter) OR (bu.CostGUID = @CostCenter))
			AND
			((@Customer = 0X00) OR (vbi.buCustPtr = @Customer))
		) xyz
	
	DECLARE @sql NVARCHAR(500)
	
	IF @IsDetailed = 1
	BEGIN
		-- First Result Set
		SELECT
			abc.*
			,mtf.*
		FROM
			(
				SELECT 
					mtGuid AS MaterialGUID, 
					mtName AS MaterialName,
					mtCode AS MaterialCode,
					Unit,
					SUM(ISNULL(OrderedQtySum, 0)) Ordered, 
					SUM(ISNULL(achievedQty, 0))  Achieved, 
					SUM(ISNULL(OrderedQtySum, 0)) - SUM(ISNULL(achievedQty, 0)) Remainder
				FROM 
					#MainData main
				GROUP BY 
					mtGuid,
					mtName,
					mtCode,
					Unit
			) abc
			INNER JOIN ##MatFlds mtf ON abc.MaterialGUID = mtf.MatFldGuid
		ORDER BY 
			abc.MaterialCode
			
		-- Second Result Set
		SELECT
			ADDATE,
			mtGuid MaterialGuid,
			SUM(ISNULL(OrderedQtySum, 0)) - SUM(ISNULL(achievedQty, 0)) Quantity
		FROM
			#MainData main
			INNER JOIN ORADDINFO000 oinf ON oinf.[ParentGuid] = OrderGuid
		GROUP BY
			ADDATE,
			mtGuid
		Order By ADDATE
	END
	ELSE -- AGGREGATE
	BEGIN
--select * from #MainData
		SELECT
			abc.*,
			O.*,
			C.*
		FROM
		(
			SELECT 
				OrderGuid
				,OrderTypeGuid
				,OrderOriginGuid
				,OrderOriginTypeGuid
				,OrderName
				,CustomerName
				,OrderDate
				,ADDate
				,SUM(ISNULL(OrderedQtySum, 0)) Ordered
				,SUM(ISNULL(achievedQty, 0))  Achieved
				,SUM(ISNULL(OrderedQtySum, 0)) - SUM(ISNULL(achievedQty, 0)) Remainder
				,Unit
			FROM 
				#MainData
				INNER JOIN ORADDINFO000 oinf ON oinf.[ParentGuid] = OrderGuid
			GROUP BY 
				OrderGuid
				,OrderTypeGuid
				,OrderOriginGuid
				,OrderOriginTypeGuid
				,OrderName
				,CustomerName
				,OrderDate
				,ADDATE
				,Unit
		) abc
		INNER JOIN ##OrderFlds O ON O.OrderFldGuid = abc.OrderGuid
		LEFT JOIN cu000 cu ON abc.CustomerName = cu.CustomerName
		LEFT JOIN ##CustFlds C ON C.CustFldGuid = cu.[GUID]
		ORDER BY abc.OrderDate, abc.ADDate
	END
*/
END

#########################################################################
#END