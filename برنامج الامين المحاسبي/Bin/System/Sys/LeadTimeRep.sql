########################################################################################
CREATE PROCEDURE prcLeadTime @CustGuid      UNIQUEIDENTIFIER = 0x00,
                             @MatGuid       UNIQUEIDENTIFIER = 0x00,
                             @CostGuid      UNIQUEIDENTIFIER = 0x00,
                             @GroupGuid     UNIQUEIDENTIFIER = 0x00,
                             @StartDate     DATETIME = '1/1/1980',
                             @EndDate       DATETIME = '1/1/1980',
                             @UseUnit       INT = 1,
                             @OrderNumber   INT = 0,
                             @IsActive      BIT = 0,
                             @IsFinished    BIT = 0,
                             @BillSrcs      UNIQUEIDENTIFIER = 0x00,
                             @TypeSrcs      UNIQUEIDENTIFIER = 0x00,
                             @MatCond       UNIQUEIDENTIFIER = 0x00,
                             @CustCondGuid  UNIQUEIDENTIFIER = 0x00,
                             @OrderCond     UNIQUEIDENTIFIER = 0x00,
                             @OrderIndex    BIGINT = 0,
                             @StoreGuid     UNIQUEIDENTIFIER = 0x00

AS
    SET NOCOUNT ON
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
    --///////////////////////////////////////////////////////////////////////////////    
    ---------------------    #BtTbl   ------------------------  
    -- ÃœÊ· √‰Ê«⁄ «·ÿ·»Ì«  «· Ì  „ «Œ Ì«—Â« ›Ì ﬁ«∆„… √‰Ê«⁄ «·ÿ·»«   
    CREATE TABLE #BtTbl
      (
         Type        UNIQUEIDENTIFIER,
         Sec         INT,
         ReadPrice   INT,
         UnPostedSec INT
      )
    INSERT INTO #BtTbl
    EXEC prcGetBillsTypesList2
      @BillSrcs
    ----------------------------------------------------------------------------------------- 
    -- EXEC  [prcGetCostsList] 
    ----------------------------------------------------------------------------------------- 
    CREATE TABLE [#CostTbl]
      (
         [CostGUID] UNIQUEIDENTIFIER,
         [Security] INT
      )
    INSERT INTO [#CostTbl]
    EXEC [prcGetCostsList]
      @CostGUID
    IF @costGuid = 0x00
      INSERT INTO #CostTbl
      VALUES     (0x00,
                  0)
    ------------------------------------------------------------------- 
    -------------------     #OitTbl   -------------------------  
    -- ÃœÊ· Õ«·«  «·ÿ·»  
    DECLARE @OitTbl TABLE
      (
         StateGuid    UNIQUEIDENTIFIER,
         NAME         NVARCHAR(255) COLLATE ARABIC_CI_AI,
         LatinName    NVARCHAR(255) COLLATE ARABIC_CI_AI,
         Operation    INT,
         PostQty      INT,
         QtyCompleted BIT,
         FirstState   BIT
      )
    INSERT INTO @OitTbl
    SELECT IdType,
           t2.NAME,
           t2.LatinName,
           Operation,
           PostQty,
           QtyStageCompleted,
           CASE
             WHEN PostQty IN (SELECT Min(PostQty)
                              FROM   dbo.fnGetOrderItemTypes() IT
                                     INNER JOIN OITVS000 OIT
                                             ON OIT.ParentGuid = IT.GUID
                              GROUP  BY OTGUID) THEN 1
             ELSE 0
           END
    FROM   RepSrcs AS t1
           INNER JOIN dbo.fnGetOrderItemTypes() AS t2
                   ON t1.IdType = t2.Guid
    WHERE  IdTbl = @TypeSrcs
    ORDER  BY PostQty
    -------------------------------------------------------------------	   
    -------------------------   #OrdersCondTbl   ---------------------- 
    --  ÃœÊ· «·ÿ·»Ì«  «· Ì  Õﬁﬁ «·‘—Êÿ  
    CREATE TABLE #OrdersCondTbl
      (
         OrderGuid UNIQUEIDENTIFIER,
         Security  INT
      )
    INSERT INTO #OrdersCondTbl
                (OrderGuid,
                 Security)
    EXEC prcGetOrdersList
      @OrderCond
    -------------------------------------------------------------------  
    -------------------------   #CustTbl   ---------------------------  
    -- ÃœÊ· «·“»«∆‰ «· Ì  Õﬁﬁ «·‘—Êÿ  
    CREATE TABLE #CustTbl
      (
         CustGuid UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #CustTbl
    EXEC prcGetCustsList
      @CustGuid,
      NULL,
      @CustCondGuid -- ??? 
    IF ( ISNULL(@CustGuid, 0x0) = 0x00 )
       AND ( ISNULL(@CustCondGuid, 0x0) = 0X0 )
      INSERT INTO #CustTbl
      VALUES     (0x0,
                  1)
    -------------------------------------------------------------------  
    ---------------------------   #MatTbl   ---------------------------- 
    --  ÃœÊ· «·„Ê«œ «· Ì  Õﬁﬁ «·‘—Êÿ  
    CREATE TABLE #MatTbl
      (
         MatGuid  UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #MatTbl
    EXEC prcGetMatsList
      @MatGuid,
      @GroupGuid,
      -1,
      @MatCond
    ------------------------------------------------------------------- 
    -------Store Table----------------------------------------------------------   
    DECLARE @StoreTbl TABLE
      (
         [GUID] [UNIQUEIDENTIFIER]
      )
    INSERT INTO @StoreTbl
    SELECT [Guid]
    FROM   [fnGetStoresList](@StoreGUID)
    -------------------------------------------------------------------
    DECLARE @CurrentLanguage BIT = 0
    SET @CurrentLanguage = (SELECT dbo.fnConnections_GetLanguage())
    ------------------------  #bi  --------------------------- 
    SELECT bt.Guid                                    AS BtGuid,
           bi.buGUID                                  AS BuGuid,
           bi.mtUnitFact,
           bi.mtUnit2Fact,
           bi.mtUnit3Fact,
           bi.mtDefUnitFact,
           ( CASE @UseUnit
               WHEN 1 THEN
                 CASE bi.mtUnitFact
                   WHEN 0 THEN bi.MtUnity
                   ELSE bi.MtUnity
                 END
               WHEN 2 THEN
                 CASE bi.mtUnit2Fact
                   WHEN 0 THEN bi.MtUnity
                   ELSE bi.MtUnit2
                 END
               WHEN 3 THEN
                 CASE bi.mtUnit3Fact
                   WHEN 0 THEN bi.MtUnity
                   ELSE bi.MtUnit3
                 END
               ELSE bi.mtDefUnitName
             END )                                    AS mtUnityName,
           bi.biClassPtr,
          (CASE @Lang WHEN 0 THEN bt.abbrev ELSE (CASE bt.LatinAbbrev WHEN N'' THEN bt.abbrev ELSE bt.LatinAbbrev END) END )  + '-'
           + Cast(bi.buNumber AS NVARCHAR(10))        AS BuName,
           bi.buDate                                  AS BuDate,
           bi.biGUID                                  AS BiGuid,
           bi.biMatPtr                                AS MatGuid,
           ( bi.biBillQty * bi.mtUnitFact ) / ( CASE @UseUnit
                                                  WHEN 1 THEN 1
                                                  WHEN 2 THEN
                                                    CASE
                                                      WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact
                                                      ELSE 1
                                                    END
                                                  WHEN 3 THEN
                                                    CASE
                                                      WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact
                                                      ELSE 1
                                                    END
                                                  ELSE bi.mtDefUnitFact
                                                END ) BiQty,
            (CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE bi.mtLatinName WHEN N'' THEN bi.mtName ELSE bi.mtLatinName END) END )                                  AS MatName,
           bi.buCustPtr                               CustGuid,
           bi.buCust_Name                             AS CustName,
           OInfo.Finished                             Finished,
           OInfo.Add1                                 Canceled,
           OInfo.ADDATE                               OrderAgreeDate,
           CASE
             WHEN OInfo.Finished = 1 THEN OInfo.FDATE
             ELSE Getdate()
           END                                        OrderFinishDate,
           (CASE @CurrentLanguage
                    WHEN 0 THEN cost.NAME
                    ELSE cost.LatinName
                  END)                            AS ItemCostName,
           (CASE @CurrentLanguage
                    WHEN 0 THEN store.NAME
                    ELSE store.LatinName
                  END)                            AS ItemStoreName,
           (CASE @CurrentLanguage
                    WHEN 0 THEN buCost.NAME
                    ELSE buCost.LatinName
                  END)                            AS OrderCostName,
           (CASE @CurrentLanguage
                    WHEN 0 THEN buStore.NAME
                    ELSE buStore.LatinName
                  END)                            AS OrderStoreName
    INTO   #bi
    FROM   bt000 AS bt
           INNER JOIN #BtTbl AS bts
                   ON bt.Guid = bts.Type
           INNER JOIN vwExtended_bi AS bi
                   ON bi.buType = bts.Type
           INNER JOIN #CostTbl AS co
                   ON co.CostGUID = bi.buCostPtr
           INNER JOIN #OrdersCondTbl AS buc
                   ON buc.OrderGuid = bi.buGUID
           INNER JOIN @StoreTbl AS st
                   ON st.[GUID] = bi.buStorePtr
           INNER JOIN ORADDINFO000 OInfo
                   ON bi.buGUID = OInfo.ParentGuid
           INNER JOIN #CustTbl AS cu
                   ON cu.CustGuid = bi.buCustPtr
           INNER JOIN #MatTbl AS mat
                   ON mat.MatGuid = bi.biMatPtr
           LEFT JOIN co000 cost
                  ON cost.Guid = bi.biCostPtr
           LEFT JOIN st000 store
                  ON store.GUID = bi.biStorePtr
           LEFT JOIN st000 buStore
                  ON buStore.GUID = bi.buStorePtr
           LEFT JOIN co000 buCost
                  ON buCost.GUID = bi.buCostPtr
	WHERE  (bi.buDate BETWEEN @StartDate AND @EndDate)
           AND 
		   (bi.buNumber = @OrderNumber OR @OrderNumber = 0)
    -------------------------------------------------------------------------- 
    IF ( @isActive = 0 )
      DELETE FROM #bi
      WHERE  [Canceled] = 0
             AND [Finished] = 0
    IF ( @isFinished = 0 )
      DELETE FROM #bi
      WHERE  [Finished] IN ( 1, 2 )
    ------------------------------     #ori     ------------------------------ 
    SELECT ori.POIGuid                                AS BiGuid,
           ori.TypeGuid,
           bi.CustGuid,
           ( CASE oit.PostQty
               WHEN (SELECT Max(PostQty)
                     FROM   @OitTbl
                     WHERE  StateGuid IN (SELECT DISTINCT TypeGuid
                                          FROM   ori000
                                          WHERE  POIGuid = ori.POIGuid)) THEN Max(ori.Date)
               ELSE Min(ori.Date)
             END )                                    AS OriDate,
           oit.PostQty                                PostQty,
           Sum(( ori.Qty * bi.mtUnitFact ) / ( CASE @UseUnit
                                                 WHEN 1 THEN 1
                                                 WHEN 2 THEN
                                                   CASE
                                                     WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact
                                                     ELSE 1
                                                   END
                                                 WHEN 3 THEN
                                                   CASE
                                                     WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact
                                                     ELSE 1
                                                   END
                                                 ELSE bi.mtDefUnitFact
                                               END )) PostQty2,
           Sum(CASE
                 WHEN oit.QtyCompleted = 1
                      AND ori.Qty > 0
                      AND ori.Type = 0 THEN ori.Qty / ( CASE
                                                          WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact
                                                          ELSE 1
                                                        END )
                 ELSE 0
               END)                                   AcheviedQty,
			   DATEDIFF(day, bi.BuDate, ( CASE oit.PostQty
               WHEN (SELECT Max(PostQty)
                     FROM   @OitTbl
                     WHERE  StateGuid IN (SELECT DISTINCT TypeGuid
                                          FROM   ori000
                                          WHERE  POIGuid = ori.POIGuid)) THEN Max(ori.Date)
               ELSE Min(ori.Date) END )) AS Days
    INTO   #ori
    FROM   ori000 AS ori
           INNER JOIN #bi AS bi
                   ON bi.BiGuid = ori.POIGuid
           INNER JOIN @OitTbl AS oit
                   ON oit.StateGuid = ori.TypeGuid
    GROUP  BY ori.POIGuid,
              bi.CustGuid,
			  bi.BuDate,
              ori.TypeGuid,
              oit.PostQty
    ---------------------------------------------------------------------
    SELECT Count(TypeGuid) StateCount,
           biGuid
    INTO   #StateCountTbl
    FROM   #ori
    GROUP  BY BiGuid
    --------------------------------------------------------------------------- 
    
    SELECT DISTINCT
					bi.BtGuid,
                    bi.BuGuid,
                    bi.BuName,
                    bi.BuDate,
                    bi.BiGuid,
                    bi.MatGuid,
                    bi.MatName,
                    bi.CustGuid,
                    bi.CustName,
                    bi.ItemCostName,
                    bi.ItemStoreName,
                    bi.mtUnityName AS Unit,
                    bi.biClassPtr AS Class,
                    ori.TypeGuid,
                    ori.OriDate,
                    bi.OrderAgreeDate,
					ori.Days,
                    bi.BiQty																AS RequiredQty,
                    ori.PostQty2                                                            AS PostedQty,
                    CASE
                      WHEN bi.Canceled = 0
                           AND bi.Finished = 0 THEN 1
                      WHEN bi.Canceled = 1 THEN 2
                      WHEN bi.Finished IN ( 1, 2 ) THEN 3
                    END                                                                     AS OrderState,
					 ISNULL(CASE @CurrentLanguage
                    WHEN 0 THEN oit.NAME
                    ELSE oit.LatinName
                  END, '')                          										AS StateName,
				  oit.PostQty																AS StateNumber
	INTO #Detailed
    FROM   #bi AS bi
           INNER JOIN #ori AS ori
                   ON ori.BiGuid = bi.BiGuid
           INNER JOIN @OitTbl oit
                   ON oit.StateGuid = ori.TypeGuid
    ORDER  BY bi.BtGuid,
              bi.BuGuid,
              bi.BiGuid,
              ori.TypeGuid
    -------------------------------------------------------  
      --«·⁄—÷ «· ›’Ì·Ì
      --  ›’Ì· „Ê«œ ﬂ· ÿ·» Ê«ŸÂ«— ﬂ„Ì«  ﬂ· „—Õ·… 
      BEGIN
         
          SELECT * FROM  #Detailed  ORDER BY BuName
		  
      END 
	  --------------------------------------------------------
	   --«·⁄—÷ «· Ã„Ì⁄Ì
    -- Ã„Ì⁄ „Ê«œ ﬂ· ÿ·» ›Ì ”ÿ— Ê«Õœ Ê «ŸÂ«—Â« „Ã„Ê⁄ ﬂ„Ì… ﬂ· „—Õ·…
      BEGIN
          SELECT DISTINCT bi.BuGuid,
                          bi.BuName,
                          bi.CustGuid,
                          bi.CustName,
                          bi.BuDate,
                          bi.OrderStoreName,
                          bi.OrderCostName,
                          Sum(bi.BiQty / ( c.StateCount ))                                                               RequiredQty,
                          Sum(ori.AcheviedQty)                                                                           AchievedQty,
                          Sum(( bi.BiQty / c.StateCount ) - ori.AcheviedQty)                                             RemQty,
                          CASE
                            WHEN bi.Canceled = 0
                                 AND bi.Finished = 0 THEN 1
                            WHEN bi.Canceled = 1 THEN 2
                            WHEN bi.Finished IN ( 1, 2 ) THEN 3
                          END                                                                                            AS OrderState,
                          bi.OrderAgreeDate,
                          bi.OrderFinishDate,
                          Datediff(day, bi.buDate, bi.OrderAgreeDate)                                                    AgreePeriod,
                          Datediff(day, bi.buDate, bi.OrderFinishDate)                                                   ActualDeliveryPeriod,
                          ( Datediff(day, bi.buDate, bi.OrderFinishDate) - Datediff(day, bi.buDate, bi.OrderAgreeDate) ) DelayPeriod
          FROM   #bi bi
                 INNER JOIN #ori AS ori
                         ON ori.BiGuid = bi.BiGuid
                 INNER JOIN #StateCountTbl c
                         ON c.BiGuid = bi.BiGuid
          GROUP  BY bi.BuGuid,
                    bi.BuName,
                    bi.CustGuid,
                    bi.CustName,
                    bi.BuDate,
                    bi.OrderStoreName,
                    bi.OrderCostName,
                    bi.Canceled,
                    bi.Finished,
                    bi.OrderAgreeDate,
                    bi.OrderFinishDate
          -------------------------------------------------- 
      END
########################################################################################
#END