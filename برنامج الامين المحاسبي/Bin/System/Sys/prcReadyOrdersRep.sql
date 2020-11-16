################################################################
CREATE PROCEDURE prcReadyOrdersRep
  -- PARAMETERS 
  @Acc           UNIQUEIDENTIFIER = 0x0,
  @Mat           UNIQUEIDENTIFIER = 0x0,
  @Grp           UNIQUEIDENTIFIER = 0x0,
  @Store         UNIQUEIDENTIFIER = 0x0,
  @StartDate     DATETIME = '01/01/1980',
  @EndDate       DATETIME = '01/01/2015',
  @OrderTypesSrc UNIQUEIDENTIFIER = 0x0,
  @UseUnit       INT = 1,
  @ResultOption  INT = 3,
  @MatType       INT = 0,
  @MatCond       UNIQUEIDENTIFIER = 0x0,
  @CustCondGuid  UNIQUEIDENTIFIER = 0x0,
  @OrderCond     UNIQUEIDENTIFIER = 0x0,
  @CostGuid      UNIQUEIDENTIFIER = 0x0
AS
    SET NOCOUNT ON
    ---------------------    #OrderTypesTbl   ------------------------  
    -- ÌÏæá ÃäæÇÚ ÇáØáÈíÇÊ ÇáÊí Êã ÇÎÊíÇÑåÇ Ýí ÞÇÆãÉ ÃäæÇÚ ÇáØáÈÇÊ  
    CREATE TABLE #OrderTypesTbl
      (
         Type        UNIQUEIDENTIFIER,
         Sec         INT,
         ReadPrice   INT,
         UnPostedSec INT
      )
    INSERT INTO #OrderTypesTbl
    EXEC prcGetBillsTypesList2
      @OrderTypesSrc
    -------------------------------------------------------------------    
    -------------------------   #OrdersTbl   --------------------------    
    --  ÌÏæá ÇáØáÈíÇÊ ÇáÊí ÊÍÞÞ ÇáÔÑæØ  
    CREATE TABLE #OrdersTbl
      (
         OrderGuid UNIQUEIDENTIFIER,
         Security  INT
      )
    INSERT INTO #OrdersTbl
                (OrderGuid,
                 Security)
    EXEC prcGetOrdersList
      @OrderCond
    -------------------------------------------------------------------    
    -------------------------   #CustTbl   ---------------------------  
    -- ÌÏæá ÇáÒÈÇÆä ÇáÊí ÊÍÞÞ ÇáÔÑæØ  
    CREATE TABLE #CustTbl
      (
         CustGuid UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #CustTbl
    EXEC prcGetCustsList
      NULL,
      @Acc,
      @CustCondGuid
    IF ( ISNULL(@Acc, 0x0) = 0x00 )
       AND ( ISNULL(@CustCondGuid, 0x0) = 0X0 )
      INSERT INTO #CustTbl
      VALUES     (0x0,
                  1)
    -------------------------------------------------------------------  
    -------------------------------------------------------------------  
    --  ÌÏæá ÇáãæÇÏ ÇáÊí ÊÍÞÞ ÇáÔÑæØ  
    CREATE TABLE #MatTbl
      (
         MatGuid  UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #MatTbl
    EXEC prcGetMatsList
      @Mat,
      @Grp,
      -1,
      @MatCond
    -------------------------------------------------------------------  
    -- Cost Table
    CREATE TABLE [#CostTbl]
      (
         [CostGUID] UNIQUEIDENTIFIER,
         [Security] INT
      )
    INSERT INTO [#CostTbl]
    EXEC [prcGetCostsList]
      @CostGUID
    IF @CostGuid = 0x00
      INSERT INTO #CostTbl
      VALUES     (0x00,
                  0)
    -------------------------------------------------------------------  
    --	ÌÏæá ÇáãÓÊæÏÚÇÊ  
    DECLARE @StoreTbl TABLE
      (
         [Guid] UNIQUEIDENTIFIER,
         [Name] NVARCHAR(250)
      )
    INSERT INTO @StoreTbl
    SELECT st.[Guid],
           ( CASE dbo.fnConnections_GetLanguage()
               WHEN 0 THEN st.[Name]
               ELSE
                 CASE st.LatinName
                   WHEN '' THEN st.[Name]
                   ELSE st.LatinName
                 END
             END ) AS [Name]
    FROM   dbo.fnGetStoresList(@Store) AS fn
           INNER JOIN st000 AS st
                   ON fn.[Guid] = st.[Guid]
    -------------------------------------------------------------------
    -----------------------   #Detailes  --------------------------- 	 
    -- ÌÏæá ÇáãæÇÏ ÇáãØáæÈÉ  
    SELECT ExBi.buType                  AS SellTypeGuid,
           ExBi.btName + ' - ' + CONVERT(varchar(50), ExBi.buNumber) AS OrderName,--+ ' - ' + CONVERT(varchar(50), ExBi.buNumber)  +'		'+ 'ÇáÊÇÑíÎ : ' +  CONVERT(varchar(50), CONVERT(date, ExBi.buDate))    +'		'+ 'ÇáãæÑÏ Ãæ ÇáÒÈæä : ' +  ExBi.buCust_Name     AS OrderName,
           ExBi.buGUID                  AS OrderGuid,
           ExBi.buNumber                AS OrderNumber,
           ExBi.buDate                  AS OrderDate,
           ExBi.buCust_Name             AS CustName,
           ExBi.biGUID                  AS ItemGuid,
           ExBi.mtName                  AS MtName,
           ExBi.buCustPtr               AS CustGuid,
           ExBi.biMatPtr                AS MatGuid,
           ExBi.biStorePtr              AS StoreGuid,
           ST.NAME                      AS StoreName,
           ( CASE @useUnit
               WHEN 1 THEN mtUnity
               WHEN 2 THEN ( CASE mtUnit2Fact
                               WHEN 0 THEN mtUnity
                               ELSE mtUnit2
                             END )
               WHEN 3 THEN ( CASE mtUnit3Fact
                               WHEN 0 THEN mtUnity
                               ELSE mtUnit3
                             END )
               ELSE mtDefUnitName
             END )                      AS UnitName,
           ( CASE @useUnit
               WHEN 1 THEN 1
               WHEN 2 THEN
                 CASE mtUnit2Fact
                   WHEN 0 THEN 1
                   ELSE mtUnit2Fact
                 END
               WHEN 3 THEN
                 CASE mtUnit3Fact
                   WHEN 0 THEN 1
                   ELSE mtUnit3Fact
                 END
               ELSE mtDefUnitFact
             END )                      AS UnitFact,
           ( CASE @useUnit
               WHEN 1 THEN ExBi.biQty
               WHEN 2 THEN ExBi.biQty / ( CASE mtUnit2Fact
                                            WHEN 0 THEN 1
                                            ELSE mtUnit2Fact
                                          END )
               WHEN 3 THEN ExBi.biQty / ( CASE mtUnit3Fact
                                            WHEN 0 THEN 1
                                            ELSE mtUnit3Fact
                                          END )
               ELSE ExBi.biQty / mtDefUnitFact
             END )                      AS OrderedQty,
           ( CASE @useUnit
               WHEN 1 THEN ISNULL(MS.Qty, 0)
               WHEN 2 THEN ISNULL(MS.Qty, 0) / ( CASE mtUnit2Fact
                                                   WHEN 0 THEN 1
                                                   ELSE mtUnit2Fact
                                                 END )
               WHEN 3 THEN ISNULL(MS.Qty, 0) / ( CASE mtUnit3Fact
                                                   WHEN 0 THEN 1
                                                   ELSE mtUnit3Fact
                                                 END )
               ELSE ISNULL(MS.Qty, 0) / mtDefUnitFact
             END )                      AS StoreQty,
           (SELECT TOP 1 OIT.Guid AS FinalStateGuid
            FROM   oit000 OIT
                   INNER JOIN oitvs000 OITVS
                           ON OIT.Guid = OITVS.ParentGuid
            WHERE  OITVS.OtGuid = ExBi.buType
                   AND OITVS.Selected = 1
            ORDER  BY OIT.PostQty DESC) AS FinalStateGuid,
		   ( CASE @useUnit
               WHEN 1 THEN Exbi.biUnitPrice 
               WHEN 2 THEN Exbi.biUnitPrice  * ( CASE mtUnit2Fact
                                            WHEN 0 THEN 1
                                            ELSE mtUnit2Fact
                                          END )
               WHEN 3 THEN Exbi.biUnitPrice  * ( CASE mtUnit3Fact
                                            WHEN 0 THEN 1
                                            ELSE mtUnit3Fact
                                          END )
               ELSE ExBi.biUnitPrice * mtDefUnitFact
             END )						AS UnitPrice,
		   biTotalDiscountPercent		AS BiTotalDiscountPercent,
		   ExBi.biTotalExtraPercent		AS BiTotalExtraPercent
    INTO   #Detailes
    FROM   vwExtended_bi AS ExBi
           INNER JOIN #OrderTypesTbl AS OTypes
                   ON ExBi.buType = OTypes.Type
           INNER JOIN #OrdersTbl AS Orders
                   ON Orders.OrderGuid = ExBi.buGUID
           INNER JOIN #CustTbl AS Custs
                   ON ExBi.buCustPtr = Custs.CustGuid
           INNER JOIN #MatTbl AS Mats
                   ON ExBi.biMatPtr = Mats.MatGuid
           INNER JOIN OrAddInfo000 AS Info
                   ON Info.ParentGuid = Orders.OrderGuid
           INNER JOIN @StoreTbl AS ST
                   ON ST.Guid = ExBi.biStorePtr
           INNER JOIN [#CostTbl] AS co
                   ON co.CostGUID = ExBi.biCostPtr
           LEFT JOIN ms000 AS MS
                  ON ExBi.biStorePtr = MS.StoreGuid
                     AND ExBi.biMatPtr = MS.MatGuid
    WHERE  ExBi.btType = 5
           AND ( ExBi.buDate BETWEEN @StartDate AND @EndDate )
           AND ( Info.Finished = 0 )
           AND ( Info.Add1 = '0' )
           AND ( ExBi.mtType = CASE @MatType
                                 WHEN -1 THEN ExBi.mtType
                                 ELSE @MatType
                               END )
    -- test	
    -- SELECT * FROM #Detailes
    SELECT d.*,
           ISNULL((SELECT Sum(ORI.Qty) / d.UnitFact
                   FROM   ori000 ORI
                   WHERE  ORI.POIGuid = d.ItemGuid
                          AND ORI.TypeGuid = d.FinalStateGuid), 0) AS AchievedQty
    INTO   #Achieved
    FROM   #Detailes d
    -- test	
    -- SELECT * FROM #Achieved

	------------------------------------------------ Fill #Result

    SELECT d.*,
           ( CASE
               WHEN ( d.OrderedQty - d.AchievedQty ) >= 0 THEN( d.OrderedQty - d.AchievedQty )
               ELSE 0
             END ) AS RemainedQty, 
			 (BI.BonusQnt  - SUM(ORI.BonusPostedQty)) / d.UnitFact AS RemainingBonusQty,
			 (BI.Discount / d.OrderedQty) * (CASE WHEN (d.OrderedQty - d.AchievedQty) >= 0 THEN(d.OrderedQty - d.AchievedQty)ELSE 0 END) AS discounts,
			 (BI.Extra / d.OrderedQty) * (CASE WHEN (d.OrderedQty - d.AchievedQty) >= 0 THEN(d.OrderedQty - d.AchievedQty)ELSE 0 END) AS Extras,
			 (BI.VAT / d.OrderedQty) * (CASE WHEN (d.OrderedQty - d.AchievedQty) >= 0 THEN(d.OrderedQty - d.AchievedQty)ELSE 0 END) AS TAX,			
			 ((d.BiTotalDiscountPercent * (CASE WHEN ( d.OrderedQty - d.AchievedQty ) >= 0 THEN ( d.OrderedQty - d.AchievedQty ) ELSE 0 END)) / d.OrderedQty) AS TotalDiscount,
			 ((d.BiTotalExtraPercent * (CASE WHEN ( d.OrderedQty - d.AchievedQty ) >= 0 THEN ( d.OrderedQty - d.AchievedQty ) ELSE 0 END)) / d.OrderedQty) AS TotalExtra,
			 (((BI.Discount / d.OrderedQty) * (CASE WHEN (d.OrderedQty - d.AchievedQty) >= 0 THEN (d.OrderedQty - d.AchievedQty) ELSE 0 END)) + ((d.BiTotalDiscountPercent * (CASE WHEN ( d.OrderedQty - d.AchievedQty ) >= 0 THEN ( d.OrderedQty - d.AchievedQty ) ELSE 0 END)) / d.OrderedQty)) AS SumOfDiscounts,
			 (((BI.Extra / d.OrderedQty) * (CASE WHEN (d.OrderedQty - d.AchievedQty) >= 0 THEN (d.OrderedQty - d.AchievedQty) ELSE 0 END)) + ((d.BiTotalExtraPercent * (CASE WHEN ( d.OrderedQty - d.AchievedQty ) >= 0 THEN ( d.OrderedQty - d.AchievedQty ) ELSE 0 END)) / d.OrderedQty)) AS SumOfExtras
    INTO   #Result
    FROM   #Achieved d
	LEFT JOIN ori000 ORI ON d.ItemGuid = ORI.POIGUID
	LEFT JOIN bi000 BI   ON d.ItemGuid = BI.[GUID]
     GROUP BY d.MatGuid,
   	          d.MtName,
   	          d.SellTypeGuid,
   	          d.ItemGuid,
   	          d.OrderGuid,
   	          d.OrderName,
   	          d.OrderNumber,
   	          d.StoreGuid,
   	          d.CustGuid,
   	          d.CustName,
   	          d.FinalStateGuid,
   	          d.OrderDate,
   	          d.OrderedQty,
   	          d.UnitPrice,
   	          d.UnitName,
   	          d.UnitFact,
   	          d.StoreGuid,
   	          d.StoreName,
   	          d.StoreQty,
   	          d.AchievedQty, 
   	          BI.BonusQnt, 
			  BI.Discount,
			  BI.Extra,
			  BI.VAT,
			  BI.Qty,
			  BI.Price,
			  d.BiTotalDiscountPercent,
			  d.BiTotalExtraPercent
	------------------------------------------------

    IF @ResultOption = 1
      BEGIN
          SELECT OrderGuid,
                 Count(*) AS ItemsCount
          INTO   #ResultItemsCount
          FROM   #Result
          WHERE  ( RemainedQty <= StoreQty )
                 AND ( RemainedQty > 0 )
          GROUP  BY OrderGuid
          -- test	
          -- SELECT * FROM #ResultItemsCount
          SELECT ParentGUID AS OrderGuid,
                 Count(*)   AS ItemsCount
          INTO   #OrderItemsCount
          FROM   bi000 bi
                 INNER JOIN #Result R
                         ON R.ItemGuid = bi.GUID
          GROUP  BY ParentGUID
          -- test	
          -- SELECT * FROM #OrderItemsCount
          SELECT R.*
          INTO   #Final1
          FROM   #Result R
          WHERE  ( R.RemainedQty <= R.StoreQty )
                 AND ( R.RemainedQty > 0 )
                 AND ( (SELECT ItemsCount
                        FROM   #ResultItemsCount
                        WHERE  OrderGuid = R.OrderGuid) = (SELECT ItemsCount
                                                           FROM   #OrderItemsCount
                                                           WHERE  OrderGuid = R.OrderGuid) )
          ORDER  BY R.OrderDate,
                    R.OrderName,
                    R.OrderNumber
          IF ( (SELECT Count(*)
                FROM   #Final1) <> 0 )
            BEGIN
                SELECT Sum(OrderedQty)  AS TotalOrderedQty,
                       Sum(StoreQty)    AS TotalStoreQty,
                       Sum(AchievedQty) AS TotalAchievedQty,
                       Sum(RemainedQty) AS TotalRemainedQty
                FROM   #Final1
            END
          ELSE
            BEGIN
                SELECT OrderedQty  AS TotalOrderedQty,
                       StoreQty    AS TotalStoreQty,
                       AchievedQty AS TotalAchievedQty,
                       RemainedQty AS TotalRemainedQty
                FROM   #Final1
            END
          SELECT *
          FROM   #Final1
		  SELECT F.OrderGuid, F.OrderDate, F.CustName, F.OrderName, F.CustGuid, INFO.ADDATE,
			SUM(F.OrderedQty) AS TotalOrderedQty,
			SUM(F.AchievedQty) AS TotalAchievedQty, 
			SUM(F.RemainedQty) AS TotalRemainedQty, 
			SUM(F.RemainedQty * UnitPrice) AS Total,
			SUM(F.StoreQty) AS TotalStoreQty,
			SUM(F.RemainingBonusQty) AS TotalRemainingBonusQty,
			(SUM(F.RemainedQty * UnitPrice) - SUM(F.SumOfDiscounts) + SUM(F.SumOfExtras) + SUM(F.TAX)) AS NetTotal
		  FROM #Final1 F LEFT JOIN OrAddInfo000 INFO ON F.OrderGuid = INFO.ParentGuid
		  GROUP BY F.OrderGuid, F.OrderName, F.OrderDate, F.CustName, F.CustGuid, INFO.ADDATE
      END
    ELSE IF @ResultOption = 2
      BEGIN
          SELECT R.*
          INTO   #Final2
          FROM   #Result R
          WHERE  ( R.RemainedQty <= R.StoreQty )
                 AND ( R.RemainedQty > 0 )
          ORDER  BY R.OrderDate,
                    R.OrderName,
                    R.OrderNumber
          IF ( (SELECT Count(*)
                FROM   #Final2) <> 0 )
            BEGIN
                SELECT Sum(OrderedQty)  AS TotalOrderedQty,
                       Sum(StoreQty)    AS TotalStoreQty,
                       Sum(AchievedQty) AS TotalAchievedQty,
                       Sum(RemainedQty) AS TotalRemainedQty
                FROM   #Final2
            END
          ELSE
            BEGIN
                SELECT OrderedQty  AS TotalOrderedQty,
                       StoreQty    AS TotalStoreQty,
                       AchievedQty AS TotalAchievedQty,
                       RemainedQty AS TotalRemainedQty
                FROM   #Final2
            END
          SELECT *
          FROM   #Final2
		  SELECT F.OrderGuid, F.OrderDate, F.CustName, F.OrderName, F.CustGuid, INFO.ADDATE,
			SUM(F.OrderedQty) AS TotalOrderedQty,
			SUM(F.AchievedQty) AS TotalAchievedQty, 
			SUM(F.RemainedQty) AS TotalRemainedQty, 
			SUM(F.RemainedQty * UnitPrice) AS Total,
			SUM(F.StoreQty) AS TotalStoreQty,
			SUM(F.RemainingBonusQty) AS TotalRemainingBonusQty,
			(SUM(F.RemainedQty * UnitPrice) - SUM(F.SumOfDiscounts) + SUM(F.SumOfExtras) + SUM(F.TAX)) AS NetTotal
		  FROM #Final2 F LEFT JOIN OrAddInfo000 INFO ON F.OrderGuid = INFO.ParentGuid
		  GROUP BY F.OrderGuid, F.OrderName, F.OrderDate, F.CustName, F.CustGuid, INFO.ADDATE
      END
    ELSE -- 3: default
      BEGIN
          SELECT R.*
          INTO   #Final3
          FROM   #Result R 
          WHERE  ( R.StoreQty > 0 )
                 AND ( R.RemainedQty > 0 )
          ORDER  BY R.OrderDate,
                    R.OrderName,
                    R.OrderNumber
          IF ( (SELECT Count(*)
                FROM   #Final3) <> 0 )
            BEGIN
                SELECT Sum(OrderedQty)  AS TotalOrderedQty,
                       Sum(StoreQty)    AS TotalStoreQty,
                       Sum(AchievedQty) AS TotalAchievedQty,
                       Sum(RemainedQty) AS TotalRemainedQty
                FROM   #Final3
            END
          ELSE
            BEGIN
                SELECT OrderedQty  AS TotalOrderedQty,
                       StoreQty    AS TotalStoreQty,
                       AchievedQty AS TotalAchievedQty,
                       RemainedQty AS TotalRemainedQty
                FROM   #Final3
            END

          SELECT F.*
          FROM #Final3 F 


		  SELECT F.OrderGuid, F.OrderDate, F.CustName, F.OrderName, F.CustGuid, INFO.ADDATE,
			SUM(F.OrderedQty) AS TotalOrderedQty,
			SUM(F.AchievedQty) AS TotalAchievedQty, 
			SUM(F.RemainedQty) AS TotalRemainedQty, 
			SUM(F.RemainedQty * UnitPrice) AS Total,
			SUM(F.StoreQty) AS TotalStoreQty,
			SUM(F.RemainingBonusQty) AS TotalRemainingBonusQty,
			(SUM(F.RemainedQty * UnitPrice) - SUM(F.SumOfDiscounts) + SUM(F.SumOfExtras) + SUM(F.TAX)) AS NetTotal
		  FROM #Final3 F LEFT JOIN OrAddInfo000 INFO ON F.OrderGuid = INFO.ParentGuid
		  GROUP BY F.OrderGuid, F.OrderName, F.OrderDate, F.CustName, F.CustGuid, INFO.ADDATE
      END 
################################################################ 
#END