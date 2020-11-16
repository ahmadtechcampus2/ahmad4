################################################################
CREATE PROCEDURE OrderMatsDetailes 
	@CustAccGuid      UNIQUEIDENTIFIER = 0x00,
    @MatGuid          UNIQUEIDENTIFIER = 0x00,
    @GroupGuid        UNIQUEIDENTIFIER = 0x00,
    @StoreGuid        UNIQUEIDENTIFIER = 0x00,
    @StartDate        DATETIME = '1/1/1980',
    @EndDate          DATETIME = '1/1/1980',
    @ReportSource     UNIQUEIDENTIFIER = 0x00,
    @TypeGuid         UNIQUEIDENTIFIER = 0x00,
    @UseUnit          INT = 0,
    @isDetailedReport BIT = 0,
    @isServiceMat     BIT = 0,
    @isAssetsMat      BIT = 0,
    @isStoreMat       BIT = 0,
    @isFinished       BIT = 0,
    @isCancled        BIT = 0,
    @MatCond          UNIQUEIDENTIFIER = 0x00,
    @CustCondGuid     UNIQUEIDENTIFIER = 0x00,
    @OrderCond        UNIQUEIDENTIFIER = 0x00,
    @Collect1         INT = 0,
    @Collect2         INT = 0,
    @Collect3         INT = 0,
    @CostGuid         UNIQUEIDENTIFIER = 0x00
AS
    SET NOCOUNT ON

    CREATE TABLE #SecViol ( Type INT, Cnt  INT )
    
	-------Bill Resource ---------------------------------------------              
    -- „’«œ— «· ﬁ—Ì—         
    CREATE TABLE #OrderTypes ( Type UNIQUEIDENTIFIER, Sec INT, ReadPrice INT, UnPostedSec INT )
    INSERT INTO #OrderTypes
    EXEC prcGetBillsTypesList2 @ReportSource

    -------------------------------------------------------------------    
    -- ÃœÊ· «·„Ê«œ „⁄  ÕﬁÌﬁ ‘—Êÿ «·„Ê«œ    
    -- «·„Ê«œ «· Ì Ì„·ﬂ «·„” Œœ„ ’·«ÕÌ… ⁄·ÌÂ«        
    CREATE TABLE #MatTbl ( MatGuid UNIQUEIDENTIFIER, mtSecurity INT )
    DECLARE @MatType INT = 0
    IF ( @isServiceMat & @isStoreMat & @isAssetsMat = 1 )
      SET @MatType = -1
    ELSE IF @isServiceMat = 1
      SET @MatType = 1
    ELSE IF @isAssetsMat = 1
      SET @MatType = 2
    ELSE IF @isStoreMat = 1
      SET @MatType = 0
    INSERT INTO #MatTbl (MatGuid, mtSecurity)
    EXEC [prcGetMatsList] @MatGuid, @GroupGuid, @MatType,@MatCond
    -------------------------------------------------------------------    
    -- ÃœÊ· «·“»«∆‰ „⁄  ÕﬁÌﬁ ‘—Êÿ «·“»«∆‰    
    CREATE TABLE #CustTbl ( CustGuid UNIQUEIDENTIFIER, [Security] [INT], CustomerName NVARCHAR(255) COLLATE ARABIC_CI_AI)
    INSERT INTO #CustTbl (CustGuid, [Security])
    EXEC [prcGetCustsList] @CustAccGuid, 0X00, @CustCondGuid -- ÌÊÃœ Œÿ√ «—ÃÊ „—«Ã⁄… 	        
    UPDATE C
    SET    CustomerName = cu.CustomerName
    FROM   #CustTbl AS C
    INNER JOIN [CU000] AS [CU] ON [CU].GUID = C.CustGuid
    -- ≈÷«›… “»Ê‰ ›«—€ ·Ã·» «·›Ê« Ì— «· Ì ·«  „·ﬂ “»Ê‰ ›Ì Õ«· «·„” Œœ„ ·„ ÌÕœœ “»Ê‰         
    -- „Õœœ ›Ì «· ﬁ—Ì—        
    IF ( ISNULL(@CustAccGuid, 0x0) = 0x00 ) AND ( ISNULL(@CustCondGuid, 0x0) = 0X0 )
      INSERT INTO #CustTbl VALUES (0x00, 1, '')
    -------------------------------------------------------------------     
    --  ÃœÊ· «·ÿ·»Ì«  „⁄  ÕﬁÌﬁ ‘—Êÿ «·ÿ·»Ì«     
    CREATE TABLE #OrderCond (OrderGuid  UNIQUEIDENTIFIER, [Security] [INT] )
    INSERT INTO #OrderCond (OrderGuid, [Security])
    EXEC [prcGetOrdersList] @OrderCond
    -------------------------------------------------------------------     
    -- Õ«·«  «·ÿ·»Ì«          
    CREATE TABLE #OrderTypesStates ( Guid UNIQUEIDENTIFIER, NAME NVARCHAR(255) COLLATE ARABIC_CI_AI, LatinName NVARCHAR(255) COLLATE ARABIC_CI_AI)

    INSERT INTO #OrderTypesStates
    SELECT idType, ISNULL(NAME, ''), ISNULL(LatinName, '')
    FROM   RepSrcs src
    LEFT JOIN dbo.fnGetOrderItemTypes() AS fnType ON fnType.Guid = src.idType
    WHERE  IdTbl = @TypeGuid
    GROUP  BY
	idType,
    NAME,
    LatinName
    -------Store Table--------------------------------------------------        
    -- ÃœÊ· «·„” Êœ⁄«         
    CREATE TABLE #StoreTbl (Guid UNIQUEIDENTIFIER)
    INSERT INTO #StoreTbl
    SELECT Guid
    FROM fnGetStoresList(@StoreGuid)
    ----------------------------------------------------------------------   
    -------COST TABLE------------------------------------------------------------------------  
    CREATE TABLE #CostTbl ([CostGUID] UNIQUEIDENTIFIER, [Security] INT )
    INSERT INTO #CostTbl
    EXEC [prcGetCostsList] @CostGUID
    IF @CostGuid = 0x00
      INSERT INTO #CostTbl VALUES (0x00, 0)
    ----------------------------------------------------------------------  

	CREATE TABLE #Ordered (
		OrderName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		Date DATETIME,
		RequiredQty FLOAT,
		Unit NVARCHAR(100),
		StockQty FLOAT,
		CollectCol1 NVARCHAR(250),
		CollectCol2 NVARCHAR(250),
		CollectCol3 NVARCHAR(250),
		MatName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		MatGUID UNIQUEIDENTIFIER,
		CustName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		buGUID UNIQUEIDENTIFIER,
		biGUID UNIQUEIDENTIFIER
	)

	INSERT INTO #Ordered
	SELECT
	bt.Abbrev + ':' + Convert(NVARCHAR(25),bu.Number) AS OrderName,
	bu.Date,
	bi.Qty,
	' ',
	0,
	CASE @Collect1 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	CASE @Collect2 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	CASE @Collect3 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	mt.Name,
	bi.MatGUID,
	bu.Cust_Name,
	bu.GUID AS buGUID,
	bi.GUID AS biGUID
	FROM bu000 bu
	INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID
	INNER JOIN bi000 bi ON bi.ParentGUID = bu.GUID
	INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID
	INNER JOIN gr000 gr ON gr.GUID = mt.GroupGUID
	INNER JOIN #OrderTypes OT ON OT.type = bu.TypeGUID	-- limit to selected order types
	INNER JOIN #CostTbl CO ON CO.CostGUID = bu.CostGUID	-- limit to selcted cost centers
	INNER JOIN #StoreTbl ST ON ST.Guid = bu.StoreGUID	-- limit to selected stores
	INNER JOIN #CustTbl CU ON CU.CustGuid = bu.CustGUID	-- limit to selected customers
	INNER JOIN #MatTbl ON #MatTbl.MatGuid = bi.MatGUID	-- limit to selected materials
	INNER JOIN #OrderCond OrderCondition ON OrderCondition.OrderGuid = bu.GUID -- limit to selected order conditions
	INNER JOIN ORADDINFO000 OrderAddInfo ON OrderAddInfo.ParentGuid = bu.GUID  -- limit to order state using WHERE
	WHERE
	bu.Date between @StartDate AND @EndDate -- limit to selected date range
	AND ( OrderAddInfo.Finished = 0 OR  ( @isFinished = 1 AND OrderAddInfo.Finished IN (1,2) ) ) -- show finished orders
	AND (OrderAddInfo.Add1 = 0 OR (@isCancled = 1 AND  OrderAddInfo.Add1 = '1') ) -- show canceled orders

	UPDATE  Ordered	SET
	Unit = CASE @UseUnit WHEN 1 THEN mt.Unity
							 WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
							 WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
							 ELSE (CASE mt.DefUnit
									WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
									WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
									ELSE mt.Unity 
							END)
				END,
	RequiredQty = CASE  @UseUnit  WHEN 1 THEN RequiredQty
							WHEN 2 THEN RequiredQty / CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
							WHEN 3 THEN RequiredQty / CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE  mt.Unit3Fact END
							ELSE RequiredQty  / (CASE mt.defunit 
													WHEN 2 THEN mt.Unit2Fact       
													WHEN 3 THEN mt.Unit3Fact
													ELSE 1 END)
							END,
	StockQty = ISNULL(InTotalQty, 0) - ISNULL(OutTotalQty, 0)
	FROM #Ordered Ordered
	INNER JOIN mt000 mt ON mt.GUID = Ordered.MatGUID
	LEFT JOIN (	SELECT bi.MatGuid, ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS OutTotalQty
				FROM   bi000 AS bi
				INNER JOIN bu000 AS bu ON bi.ParentGuid = bu.Guid
				INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
				INNER JOIN #StoreTbl AS Store ON Store.GUID = bu.StoreGUID
				WHERE bt.bIsInput = 0 AND bt.Type NOT IN ( 5, 6 ) AND bu.IsPosted = 1 AND bu.[Date] BETWEEN @StartDate AND @EndDate
				GROUP BY
				bi.MatGuid
			  ) AS BillOut ON BillOut.MatGuid = Ordered.MatGUID
	LEFT JOIN (	SELECT bi.MatGuid, ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS InTotalQty
				FROM   bi000 AS bi
				INNER JOIN bu000 AS bu ON bi.ParentGuid = bu.Guid
				INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
				INNER JOIN #StoreTbl AS Store ON Store.GUID = bu.StoreGUID
				WHERE bt.bIsInput = 1 AND bt.Type NOT IN ( 5, 6 ) AND bu.IsPosted = 1 AND bu.[Date] BETWEEN @StartDate AND @EndDate
				GROUP BY
				bi.MatGuid
			  ) AS BillIn ON BillIn.MatGuid = Ordered.MatGUID

	--SELECT * FROM #Ordered

	CREATE TABLE #AllOrdersStates
	(
		buGUID UNIQUEIDENTIFIER,
		biGUID UNIQUEIDENTIFIER,
		TypeGUID UNIQUEIDENTIFIER,
		CollectCol1 NVARCHAR(250),
		CollectCol2 NVARCHAR(250),
		CollectCol3 NVARCHAR(250),
		MatName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		MatGUID UNIQUEIDENTIFIER,
		TypeName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		TypeLatinName NVARCHAR(255),
		TypeQty FLOAT,
		IsSalesType INT
	)

	INSERT INTO #AllOrdersStates
	SELECT
	POGUID AS buGUID,
	POIGUID AS biGUID,
	TypeGuid,
	CASE @Collect1 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	CASE @Collect2 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	CASE @Collect3 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	mt.Name,
	bi.MatGUID,
	oit.Name,
	oit.LatinName,
	SUM (	CASE  @UseUnit	WHEN 1 THEN ori.QTY
							WHEN 2 THEN ori.QTY / CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
							WHEN 3 THEN ori.QTY / CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
							ELSE ori.QTY / CASE mt.defunit WHEN 2 THEN mt.Unit2Fact  
															WHEN 3 THEN mt.Unit3Fact        
															ELSE 1
															END
							END
		),
	oit.Type AS IsSalesType
	FROM ori000 ori
	INNER JOIN oit000 oit ON oit.GUID = ori.TypeGuid
	INNER JOIN bi000 bi ON bi.GUID = POIGUID
	INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID
	INNER JOIN gr000 gr ON gr.GUID = mt.GroupGUID
	INNER JOIN #OrderTypesStates OTS ON OTS.Guid = ori.TypeGuid -- limit to the only selected Order types states
	INNER JOIN #Ordered O ON O.buGUID = POGUID	AND O.biGUID = POIGUID -- get only filtered bills ( needed bills )
	GROUP BY
	POGUID,
	POIGUID,
	TypeGuid,
	CASE @Collect1 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	CASE @Collect2 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	CASE @Collect3 WHEN 0 THEN '' WHEN 1 THEN Dim WHEN 2 THEN Pos WHEN 3 THEN Origin WHEN 4 THEN Company WHEN 5 THEN Color WHEN 6 THEN Model WHEN 7 THEN Quality WHEN 8 THEN Provenance WHEN 9 THEN mt.Name WHEN 10 THEN mt.LatinName WHEN 11 THEN gr.Name END,
	mt.Name,
	bi.MatGUID,
	oit.Name,
	oit.LatinName,
	oit.Type

	--SELECT * FROM #AllOrdersStates

	SELECT
	DISTINCT
	TypeName,
	TypeLatinName,
	IsSalesType
	FROM #AllOrdersStates


	IF @isDetailedReport = 1
		SELECT
		Ordered.buGUID,
		Ordered.biGUID,
		OrderName,
		Date,
		RequiredQty,
		Unit,
		Ordered.MatName,
		Ordered.MatGUID,
		CustName,
		TypeGUID,
		TypeName,
		TypeLatinName,
		TypeQty,
		IsSalesType
		FROM #AllOrdersStates AllSatates
		INNER JOIN #Ordered Ordered ON Ordered.buGUID = AllSatates.buGUID AND Ordered.biGUID = AllSatates.biGUID
	ELSE
	BEGIN
		IF @Collect1 = 0
		BEGIN
			SELECT
			SUM(RequiredQty) AS RequiredQty,
			SUM(CASE WHEN IsSalesType = 1 THEN RequiredQty ELSE 0 END) AS RequiredSellQty,
			SUM(CASE WHEN IsSalesType = 0 THEN RequiredQty ELSE 0 END) AS RequiredPurchaseQty,
			Unit,
			StockQty,
			Ordered.CollectCol1,
			Ordered.CollectCol2,
			Ordered.CollectCol3,
			Ordered.MatName,
			Ordered.MatGUID
			INTO #GroupedOrdered
			FROM #Ordered Ordered
			LEFT JOIN #AllOrdersStates AllSatates ON Ordered.buGUID = AllSatates.buGUID AND Ordered.biGUID = AllSatates.biGUID
			GROUP BY
			Unit,
			StockQty,
			Ordered.CollectCol1,
			Ordered.CollectCol2,
			Ordered.CollectCol3,
			Ordered.MatName,
			Ordered.MatGUID
		
			--SELECT * FROM #GroupedOrdered

			SELECT
			RequiredQty,
			Min(RequiredSellQty) AS RequiredSellQty,
			Min(RequiredPurchaseQty) AS RequiredPurchaseQty,
			Unit,
			StockQty,
			GroupedOrdered.MatName,
			GroupedOrdered.MatGUID,
			TypeGUID,
			TypeName,
			TypeLatinName,
			SUM(TypeQty) AS TypeQty,
			IsSalesType
			FROM #AllOrdersStates AllSatates
			INNER JOIN #GroupedOrdered GroupedOrdered ON GroupedOrdered.MatGUID = AllSatates.MatGUID
			GROUP BY
			RequiredQty,
			Unit,
			StockQty,
			GroupedOrdered.MatName,
			GroupedOrdered.MatGUID,
			TypeGUID,
			TypeName,
			TypeLatinName,
			IsSalesType
		END
		ELSE
		BEGIN

			--SELECT * FROM #Ordered

			SELECT
			SUM(RequiredQty) AS RequiredQty,
			Unit,
			CollectCol1,
			CollectCol2,
			CollectCol3
			INTO #CollectedOrdered
			FROM #Ordered
			GROUP BY
			Unit,
			CollectCol1,
			CollectCol2,
			CollectCol3
		
			--SELECT * FROM #CollectedOrdered

			SELECT
			RequiredQty,
			FetchedStockQty AS StockQty,
			CollectedOrdered.CollectCol1,
			CollectedOrdered.CollectCol2,
			CollectedOrdered.CollectCol3,
			TypeGUID,
			TypeName,
			TypeLatinName,
			SUM(TypeQty) AS TypeQty,
			IsSalesType
			FROM #AllOrdersStates AllSatates
			INNER JOIN #CollectedOrdered CollectedOrdered ON CollectedOrdered.CollectCol1 = AllSatates.CollectCol1 AND CollectedOrdered.CollectCol2 = AllSatates.CollectCol2 AND CollectedOrdered.CollectCol3 = AllSatates.CollectCol3
			INNER JOIN 
			(
				SELECT SUM(StockQty) AS FetchedStockQty, CollectCol1, CollectCol2, CollectCol3
				FROM
				(
					SELECT DISTINCT StockQty, MatGUID, CollectCol1, CollectCol2, CollectCol3
					FROM #Ordered
				) innerDistinct
				GROUP BY 
				CollectCol1, CollectCol2, CollectCol3
			) AS StockSum ON StockSum.CollectCol1 = CollectedOrdered.CollectCol1 AND StockSum.CollectCol2 = CollectedOrdered.CollectCol2 AND StockSum.CollectCol3 = CollectedOrdered.CollectCol3
			GROUP BY
			RequiredQty,
			FetchedStockQty,
			CollectedOrdered.CollectCol1,
			CollectedOrdered.CollectCol2,
			CollectedOrdered.CollectCol3,
			TypeGUID,
			TypeName,
			TypeLatinName,
			IsSalesType
		END
	END

    SELECT *
    FROM   #SecViol

################################################################
#END	
