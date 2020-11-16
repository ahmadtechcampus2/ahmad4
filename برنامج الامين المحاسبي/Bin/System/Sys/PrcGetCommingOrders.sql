#########################################################################
CREATE PROCEDURE PrcGetCommingOrders @StartDate     DATETIME,
                                     @EndDate       DATETIME,
                                     @ReportSources UNIQUEIDENTIFIER = 0x0,
                                     @IsDetailed    BIT = 1,
                                     @Material      UNIQUEIDENTIFIER = 0x00,
                                     @Group         UNIQUEIDENTIFIER = 0x00,
                                     @CostCenter    UNIQUEIDENTIFIER = 0x00,
                                     @Store         UNIQUEIDENTIFIER = 0x00,
                                     @Unit          INT = 0,
                                     @Customer      UNIQUEIDENTIFIER = 0x00,
                                     @OrderCond     UNIQUEIDENTIFIER = 0x00
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
    CREATE TABLE [#MatTbl]
        (
           [MatGUID]    [UNIQUEIDENTIFIER],
           [mtSecurity] [INT]
        )
	
      CREATE TABLE [#StoreTbl]
        (
           [StoreGUID] [UNIQUEIDENTIFIER],
           [Security]  [INT]
        )
	
      CREATE TABLE [#CostTbl]
        (
           [CostGUID] [UNIQUEIDENTIFIER],
           [Security] [INT]
        )
      CREATE TABLE [#CustTbl]
        (
           [CustGuid] [UNIQUEIDENTIFIER],
           [Security] [INT]
        )
      CREATE TABLE #OrderCond
        (
           OrderGuid  UNIQUEIDENTIFIER,
           [Security] [INT]
        )
      INSERT INTO [#OrderCond]
                  (OrderGuid,
                   [Security])
      EXEC [prcGetOrdersList]
        @OrderCond
	
      INSERT INTO [#MatTbl]
      EXEC [prcGetMatsList]
        @Material,
        @Group,
        -1,
        0x0
      INSERT INTO [#StoreTbl]
      EXEC [prcGetStoresList]
        @Store
      INSERT INTO [#CostTbl]
      EXEC [prcGetCostsList]
        0X00
      INSERT INTO [#CustTbl]
      EXEC [prcGetCustsList]
        @Customer,
        0x0,
        0x0
      INSERT INTO [#CustTbl]
      SELECT 0x0,
             1
      SELECT *
      INTO   #MainData
      FROM   (SELECT vwbi.biMatPtr                            AS mtGuid,
			(CASE @Lang WHEN 0 THEN vwbi.mtName ELSE (CASE vwbi.mtLatinName WHEN N'' THEN vwbi.mtName ELSE vwbi.mtLatinName END) END ) AS mtName,
			vwbi.mtCode,
                     vwbi.buGUID                              AS OrderGuid,
                     vwbi.buType                              AS OrderTypeGuid,
                     CONVERT(UNIQUEIDENTIFIER, 0x00)          AS OrderOriginGuid,
                     CONVERT(UNIQUEIDENTIFIER, 0x00)          AS OrderOriginTypeGuid,
                     vwbi.buDate                              AS OrderDate,
                     ( bt.Abbrev + ': '
                       + CONVERT(NVARCHAR(50), bu.[Number]) ) AS OrderName,
                     ( vwbi.biQty / ( CASE @Unit
					WHEN 0 THEN 1
					WHEN 1 THEN (case vwbi.mtUnit2Fact when 0 then vwbi.mtDefUnitFact else vwbi.mtUnit2Fact end) -- vwbi.mtUnit2Fact
					WHEN 2 THEN (case vwbi.mtUnit3Fact when 0 then vwbi.mtDefUnitFact else vwbi.mtUnit3Fact end) -- vwbi.mtUnit3Fact
					ELSE vwbi.mtDefUnitFact
                                      END ) )                 AS OrderedQtySum,
                     0                                        AS AchievedQty,
                     vwbi.mtUnityName                         AS Unit,
                     ISNULL(cu2.CustomerName, '')             AS CustomerName
              FROM   vwExtended_bi vwbi
                     INNER JOIN bu000 bu
                             ON bu.GUID = vwbi.buGUID
                     INNER JOIN bt000 bt
                             ON bt.[GUID] = bu.[TypeGUID]
                     INNER JOIN #OrderCond OC
                             ON OC.OrderGuid = vwbi.buGUID
                     INNER JOIN [#MatTbl] AS [mt]
                             ON [mt].[MatGUID] = [vwbi].[biMatPtr]
                     INNER JOIN [#StoreTbl] AS [st]
                             ON st.[StoreGUID] = [vwbi].[biStorePtr]
                     LEFT JOIN [#CostTbl] AS [co]
                            ON ( ( co.[CostGUID] = [vwbi].[biCostPtr] )
                                  OR ( co.[CostGUID] = bu.[CostGUID] ) )
                     INNER JOIN [#CustTbl] AS [cu]
                             ON [cu].CustGuid = vwbi.[buCustPtr]
                     LEFT JOIN cu000 cu2
                            ON cu2.[GUID] = vwbi.[buCustPtr]
                                OR cu2.[Guid] = 0x00
			-- no need to join with ori000 to know ordered quantity
              WHERE  buGUID IN (SELECT bu.[GUID]
                                FROM   bu000 bu
                                       INNER JOIN RepSrcs rs
                                               ON [IdType] = bu.TypeGUID
                                       INNER JOIN ORADDINFO000 oinf
                                               ON oinf.ParentGuid = bu.[GUID]
                                WHERE  oinf.Finished = 0
                                       AND oinf.Add1 = 0
                                       AND rs.IdTbl = @ReportSources
                                       AND TypeGuid IN (SELECT [GUID]
                                                        FROM   bt000
                                                        WHERE  [TYPE] = 6)
                                       AND bu.[Date] BETWEEN @StartDate AND @EndDate)
                     AND ( ( @CostCenter = 0x00 )
                            OR ( [vwbi].[biCostPtr] = @CostCenter )
                            OR ( bu.CostGUID = @CostCenter ) )
                     AND ( ( @Customer = 0X00 )
                            OR ( vwbi.buCustPtr = @Customer ) )
		UNION ALL
              SELECT vbi.biMatPtr                             AS mtGuid,
			vbi.mtName,
			vbi.mtCode,
                     bu.GUID                                  AS OrderGuid,
                     bu.TypeGuid                              AS OrderTypeGuid,
                     CONVERT(UNIQUEIDENTIFIER, 0x00)          AS OrderOriginGuid,
                     CONVERT(UNIQUEIDENTIFIER, 0x00)          AS OrderOriginTypeGuid,
                     bu.[Date]                                AS OrderDate,
                     ( bt.Abbrev + ': '
                       + CONVERT(NVARCHAR(50), bu.[Number]) ) AS OrderName,
                     0                                        AS OrderedQtySum,
                     ( ori.Qty / ( CASE @Unit
					WHEN 0 THEN 1
					WHEN 1 THEN (case vbi.mtUnit2Fact when 0 then vbi.mtDefUnitFact else vbi.mtUnit2Fact end) -- vbi.mtUnit2Fact
					WHEN 2 THEN (case vbi.mtUnit3Fact when 0 then vbi.mtDefUnitFact else vbi.mtUnit3Fact end) -- vbi.mtUnit3Fact
					ELSE vbi.mtDefUnitFact
                                   END ) )                    AS AchievedQtySum,
                     vbi.mtUnityName                          AS Unit,
                     ISNULL(cu2.[CustomerName], '')           AS CustomerName
              FROM   ori000 ori
                     INNER JOIN bu000 bu
                             ON bu.GUID = ori.POGUID
                     INNER JOIN bt000 bt
                             ON bt.[GUID] = bu.[TypeGUID]
                     INNER JOIN vwExtended_bi vbi
                             ON vbi.biGUID = ori.POIGUID
                     INNER JOIN #OrderCond OC
                             ON OC.OrderGuid = vbi.buGUID
                     INNER JOIN [#MatTbl] AS [mt]
                             ON [mt].[MatGUID] = [vbi].[biMatPtr]
                     INNER JOIN [#StoreTbl] AS [st]
                             ON st.[StoreGUID] = [vbi].[biStorePtr]
                     LEFT JOIN [#CostTbl] AS [co]
                            ON ( ( co.[CostGUID] = [vbi].[biCostPtr] )
                                  OR ( co.[CostGUID] = bu.CostGUID ) )
                     INNER JOIN [#CustTbl] AS [cu]
                             ON [cu].CustGuid = vbi.[buCustPtr]
                     LEFT JOIN cu000 cu2
                            ON cu2.[GUID] = vbi.[buCustPtr]
                                OR cu2.[Guid] = 0x00
              WHERE  bu.TypeGuid IN (SELECT DISTINCT [GUID]
                                     FROM   bt000
                                     WHERE  [TYPE] = 6)
                     AND bu.[Date] BETWEEN @StartDate AND @EndDate
                     AND ori.BuGuid <> 0x0
                     AND ori.TypeGuid IN (SELECT [GUID]
                                          FROM   oit000
                                          WHERE  operation = 1)
                     AND ( ( @CostCenter = 0x00 )
                            OR ( [vbi].[biCostPtr] = @CostCenter )
                            OR ( bu.CostGUID = @CostCenter ) )
                     AND ( ( @Customer = 0X00 )
                            OR ( vbi.buCustPtr = @Customer ) )) xyz
	
	DECLARE @sql NVARCHAR(500)
	
	IF @IsDetailed = 1
	BEGIN
            SELECT abc.*
			INTO #MaterialQtyInfo
            FROM   (SELECT mtGuid                                                      AS MaterialGUID,
                           mtName                                                      AS MtName,
                           mtCode                                                      AS MaterialCode,
						   Unit,
                           Sum(ISNULL(OrderedQtySum, 0))                               Ordered,
                           Sum(ISNULL(achievedQty, 0))                                 Achieved,
                           Sum(ISNULL(OrderedQtySum, 0)) - Sum(ISNULL(achievedQty, 0)) Remainder
                    FROM   #MainData main
                    GROUP  BY mtGuid, mtName, mtCode,
                              Unit) abc
			
		-- Result Set
            SELECT ADDATE,
                   mtGuid                                                      MaterialGuid,
                   Sum(ISNULL(OrderedQtySum, 0)) - Sum(ISNULL(achievedQty, 0)) Quantity,
				   MQI.*
            FROM #MainData main 
			INNER JOIN ORADDINFO000 oinf ON oinf.[ParentGuid] = OrderGuid
			LEFT JOIN #MaterialQtyInfo MQI ON MQI.[MaterialGUID] = main.[mtGuid]
            GROUP  BY ADDATE, mtGuid,
					  MQI.MaterialGUID, MQI.MaterialCode, MQI.MtName, MQI.Achieved, MQI.Ordered, MQI.Remainder, MQI.Unit
            ORDER  BY MQI.MaterialCode

	END

	ELSE -- AGGREGATE
	BEGIN
--select * from #MainData
            SELECT abc.*, bu.CustGUID AS CustFldGuid
            FROM   (SELECT OrderGuid,
                           OrderTypeGuid,
                           OrderOriginGuid,
                           OrderOriginTypeGuid,
                           OrderName,
                           CustomerName,
                           OrderDate,
                           ADDate,
                           Sum(ISNULL(OrderedQtySum, 0))                               Ordered,
                           Sum(ISNULL(achievedQty, 0))                                 Achieved,
                           Sum(ISNULL(OrderedQtySum, 0)) - Sum(ISNULL(achievedQty, 0)) Remainder,
                           Unit
                    FROM   #MainData
                           INNER JOIN ORADDINFO000 oinf
                                   ON oinf.[ParentGuid] = OrderGuid
                    GROUP  BY OrderGuid,
                              OrderTypeGuid,
                              OrderOriginGuid,
                              OrderOriginTypeGuid,
                              OrderName,
                              CustomerName,
                              OrderDate,
                              ADDATE,
                              Unit) abc
                   LEFT JOIN cu000 cu ON abc.CustomerName = cu.CustomerName
				   LEFT JOIN bu000 bu ON abc.OrderGuid = bu.[GUID]
            ORDER  BY abc.OrderDate,
                      abc.ADDate
	END
END

#########################################################################
#END