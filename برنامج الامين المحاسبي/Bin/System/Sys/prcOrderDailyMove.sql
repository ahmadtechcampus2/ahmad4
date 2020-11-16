#########################################################################
CREATE PROCEDURE prcOrderDailyMove @MaterialGuid      UNIQUEIDENTIFIER = 0x0,
                                   @GroupGuid         UNIQUEIDENTIFIER = 0x0,
                                   @Acc               UNIQUEIDENTIFIER = 0x00,
                                   @Cost              UNIQUEIDENTIFIER = 0x00,
                                   @Store             UNIQUEIDENTIFIER = 0x00,
                                   @StartDate         DATETIME = '1/1/1980',
                                   @EndDate           DATETIME = '1/1/1980',
                                   @OrderTypesSrc     UNIQUEIDENTIFIER = 0x00,
                                   @Unit              INT = 1,
                                   @CustCondGuid      UNIQUEIDENTIFIER = 0x00,
                                   @OrderCond         UNIQUEIDENTIFIER = 0x00,
                                   @OrderOptions      BIGINT = 0,
                                   @CurGUID           UNIQUEIDENTIFIER = 0x00,
                                   @PayType           INT = 0,
                                   @RID               FLOAT = 0,
                                   @ShowChecked       INT = 0,
                                   @ItemChecked       INT = -1,
                                   @CheckForUsers     INT = 0,
                                   @MatFldsFlag       BIGINT = 0,
                                   @TypeGUID          UNIQUEIDENTIFIER = 0x00,
                                   @IsOrderCurrency   BIT = 0
AS
     SET NOCOUNT ON
    ------------------------------------------------------------------- 
    DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	CREATE TABLE #MatTble
      (
         MatGuid    UNIQUEIDENTIFIER,
         mtSecurity INT
      )
    INSERT INTO #MatTble
                (MatGuid,
                 mtSecurity)
    EXEC [prcGetMatsList]
      @MaterialGuid,
      @GroupGuid,
      -1 /*@MatType*/,
      0x0/*@MatCond*/
    ------------------------------------------------------------------- 
    CREATE TABLE #BtTbl
      (
         Type        UNIQUEIDENTIFIER,
         Sec         INT,
         ReadPrice   INT,
         UnPostedSec INT
      )
    INSERT INTO #BtTbl
    EXEC prcGetBillsTypesList2
      @OrderTypesSrc
    ---------------------    #OrderTypesTbl   ------------------------ 
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
    ---------- 
    ------------------------------------------------------------------- 
    -------------------------   #OrdersTbl   -------------------------- 
    CREATE TABLE #OrdersTbl
      (
         OrderGuid  UNIQUEIDENTIFIER,
         [Security] INT
      )
    INSERT INTO #OrdersTbl
                (OrderGuid,
                 Security)
    EXEC prcGetOrdersList
      @OrderCond
    ------------------------------------------------------------------- 
    -------------------------   #CustTbl   --------------------------- 
    CREATE TABLE #CustTbl
      (
         CustGuid UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #CustTbl
    EXEC prcGetCustsList
      0x0,
      @Acc,
      @CustCondGuid
    IF ( ISNULL(@Acc, 0x0) = 0x00 )
       AND ( ISNULL(@CustCondGuid, 0x0) = 0X0 )
      INSERT INTO #CustTbl
      VALUES     (0x0,
                  1)
    ------------------------------------------------------------------- 
    DECLARE @StoreTbl TABLE
      (
         StoreGuid UNIQUEIDENTIFIER
      )
    INSERT INTO @StoreTbl
    SELECT Guid
    FROM   fnGetStoresList(@Store)
    ------------------------------------------------------------------- 
    ------------------------------------------------------------------- 
    DECLARE @CostTbl TABLE
      (
         CostGuid UNIQUEIDENTIFIER
      )
    INSERT INTO @CostTbl
    SELECT Guid
    FROM   fnGetCostsList(@Cost)
    IF ISNULL(@Cost, 0x0) = 0x0
      INSERT INTO @CostTbl
      VALUES     (0x0)
    ----------------------------------------------------------------------------- 
    SELECT DISTINCT vw.buGUID          AS OrderGuid,
                    (CASE @Lang WHEN 0 THEN vw.btName ELSE (CASE vw.btLatinName WHEN N'' THEN vw.btName ELSE vw.btLatinName END) END ) AS OrderName,
                    vw.buNumber        AS OrderNumber,
                    vw.buType          AS OrderTypeGuid,
                    vw.buNotes         AS OrderNotes,
                    ( vw.btType * 0 )  AS OCheck --initializing column value 
                    ,
                    CurrencyTable.NAME AS OrderCurrencyName,
                    vw.buCurrencyVal   AS OrderCurrencyVal
    INTO   #Ordered
    FROM   vwExtended_bi AS vw
           INNER JOIN #OrderTypesTbl AS OTypes
                   ON OTypes.Type = vw.buType
           INNER JOIN @CostTbl AS Costs
                   ON vw.buCostPtr = Costs.CostGuid
           INNER JOIN #OrdersTbl AS Orders
                   ON Orders.OrderGuid = vw.buGUID
           INNER JOIN bi000 AS BI
                   ON BI.ParentGuid = Orders.OrderGuid
           INNER JOIN #CustTbl AS Custs
                   ON vw.buCustPtr = Custs.CustGuid
           INNER JOIN OrAddInfo000 AS Info
                   ON Info.ParentGuid = Orders.OrderGuid
           INNER JOIN @StoreTbl AS Stores
                   ON Stores.StoreGuid = vw.buStorePtr
           INNER JOIN #MatTble AS mt
                   ON mt.MatGuid = bi.MATGUID
           INNER JOIN my000 AS CurrencyTable
                   ON CurrencyTable.GUID = vw.buCurrencyPtr
    WHERE  vw.buPayType = ( CASE @PayType
                              WHEN -1 THEN vw.buPayType
                              ELSE @PayType
                            END )
           AND ( vw.buDate BETWEEN @StartDate AND @EndDate )--AND  BU.CurrencyGUID=@CurGUID 
           AND ( ( Info.Finished = ( CASE @OrderOptions&1
                                       WHEN 1 THEN 0
                                       ELSE NULL
                                     END ) )
                 AND ( Info.Add1 = ( CASE @OrderOptions&1
                                       WHEN 1 THEN '0'
                                       ELSE NULL
                                     END ) )
                  OR ( Info.Finished >= ( CASE @OrderOptions&2
                                            WHEN 2 THEN 1
                                            ELSE NULL
                                          END ) )
                  OR ( Info.Add1 = ( CASE @OrderOptions&4
                                       WHEN 4 THEN '1'
                                       ELSE NULL
                                     END ) ) )
    DECLARE @IFDETLASE AS BIT
    SET @IFDETLASE = 0;
    IF ( ( @OrderOptions & 64 ) = 64 )
      SET @IFDETLASE = 1;
    IF ( @IFDETLASE = 0 )
      BEGIN
	  
          SELECT -- DISTINCT 
          ord.OrderTypeGuid                                                                AS OrderTypeGuid,
          ord.OrderName COLLATE ARABIC_CI_AI                                               AS OrderName,
          ord.OrderGuid                                                                    AS OrderGuid,
          Sum(bi.Qty / ( CASE @Unit
                           WHEN 0 THEN ( CASE Bi.Unity
                                           WHEN 1 THEN 1
                                           WHEN 2 THEN ( CASE mt.Unit2Fact
                                                           WHEN 0 THEN 1
                                                           ELSE mt.Unit2Fact
                                                         END )
                                           WHEN 3 THEN ( CASE mt.Unit3Fact
                                                           WHEN 0 THEN 1
                                                           ELSE mt.Unit3Fact
                                                         END )
                                           ELSE 1
                                         END )
                           WHEN 1 THEN 1
                           WHEN 2 THEN ( CASE mt.Unit2Fact
                                           WHEN 0 THEN 1
                                           ELSE mt.Unit2Fact
                                         END )
                           WHEN 3 THEN ( CASE mt.Unit3Fact
                                           WHEN 0 THEN 1
                                           ELSE mt.Unit3Fact
                                         END )
                           ELSE ( CASE mt.DefUnit
                                    WHEN 1 THEN 1
                                    WHEN 2 THEN mt.Unit2Fact
                                    WHEN 3 THEN mt.Unit3Fact
                                    ELSE 1
                                  END )
                         END ))                                                            AS OrderQty,
          --ord.OrderedQty		AS OrderQty, 
          ord.OrderNumber                                                                  AS OrderNumber,
          VW.buCust_Name COLLATE ARABIC_CI_AI                                              AS Custmar,
          VW.buDate                                                                        AS BILLDATE,
          VW.buPayType                                                                     AS PayType,
          VW.buCustPtr                                                                     AS CustGuid,
          VW.buStorePtr                                                                    AS buStoreGUID,
          VW.buCostPtr                                                                     AS buCOSTGUID,
          Sum(dbo.fnCurrency_fix(CASE VW.btVatSystem
                                   WHEN 1 THEN ( VW.biUnitPrice * VW.biQty + VW.buVat )
                                   ELSE ( VW.biUnitPrice * VW.biQty )
                                 END, VW.buCurrencyPtr, VW.buCurrencyVal, CASE
                                                                            WHEN @IsOrderCurrency = 1 THEN VW.buCurrencyPtr
                                                                            ELSE @CurGUID
                                                                          END, VW.buDate)) AS TOTAL,
          ord.OrderNotes,
          ord.OCheck                                                                       AS [Check],
          Sum(vw.buTotalDisc)                                                              AS OrderDiscount,
          Sum(vw.buTotalExtra)                                                             AS OrderExtra,
          dbo.fnOrderApprovalState(ord.OrderGuid)                                          AS ApprovalState,
          ord.OrderCurrencyName                                                            AS OrderCurrencyName,
          ord.OrderCurrencyVal                                                             AS OrderCurrencyVal
          INTO   #RES1
          FROM   #Ordered ORD
                 INNER JOIN bi000 bi
                         ON bi.ParentGuid = ORD.OrderGuid
                 INNER JOIN mt000 AS MT
                         ON MT.GUID = bi.MATGUID
                 INNER JOIN #MatTble MAT
                         ON MAT.MatGuid = MT.GUID
                 INNER JOIN vwExtended_bi AS VW
                         ON VW.biGUID = bi.GUID
          GROUP  BY ORD.OrderTypeGuid,
                    ORD.OrderName,
                    ORD.OrderGuid,
                    ORD.OrderNumber,
                    ORD.OrderNotes,
                    ORD.OCheck,
                    ORD.OrderCurrencyName,
                    ORD.OrderCurrencyVal,
                    VW.buCust_Name,
                    VW.buDate,
                    VW.buPayType,
                    VW.buCustPtr,
                    VW.buStorePtr,
                    VW.buCostPtr

          IF ( @ShowChecked > 0 )
            BEGIN
                DECLARE @UserGuid [UNIQUEIDENTIFIER]
                SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
                UPDATE [Res]
                SET    [Check] = 1
                FROM   [#Res1] AS [Res]
                       INNER JOIN [RCH000] AS [RCH]
                               ON [Res].[OrderGuid] = [RCH].[ObjGUID]
                WHERE  @RID = [RCH].[Type]
                       AND ( ( @CheckForUsers = 1 )
                              OR ( [RCH].[UserGuid] = @UserGuid ) )
                IF( @ItemChecked = 0 )
                  DELETE FROM [#Res1]
                  WHERE  [Check] <> 1
                          OR [Check] IS NULL
                ELSE IF( @ItemChecked = 1 )
                  DELETE FROM [#Res1]
                  WHERE  [Check] = 1
            END
      END
    ELSE
      BEGIN
          --------------------------------------------------------------------------------- 
          DECLARE @TypeTbl TABLE
            (
               [Type]      [UNIQUEIDENTIFIER],
               [Name]      NVARCHAR(255) COLLATE ARABIC_CI_AI,
               [LatinName] NVARCHAR(255) COLLATE ARABIC_CI_AI,
               [Operation] INT,
               [PostQty]   INT
            )
          INSERT INTO @TypeTbl
          SELECT [idType],
                 ISNULL([Name], ''),
                 ISNULL([LatinName], ''),
                 ISNULL(Operation, 0),
                 ISNULL(PostQty, 0)
          FROM   [RepSrcs] [src]
                 LEFT JOIN [dbo].[fnGetOrderItemTypes]() AS [fnType]
                        ON [fnType].[Guid] = [src].[idType]
          WHERE  [IdTbl] = @TypeGuid
          GROUP  BY [idType],
                    [Name],
                    [LatinName],
                    Operation,
                    PostQty
          ORDER  BY PostQty -- sequence number of Order State 
          ---------------------------------------------------------------------------------- 
          DECLARE @SHOWTAX INT
          SET @SHOWTAX = 524288
          SELECT ORD.BIGUID                              AS BIGUID,
                 ORD.MATGUID                             AS MATGUID,
                 ORD.CostGuid                            AS CostGuid,
                 ORD.buCostGuid,
                 ORD.OrderTypeGuid                       AS OrderTypeGuid,
                 ORD.StoreGUID                           AS StoreGUID,
                 ORD.buStoreGUID,
                 ORD.OrderGuid                           AS OrderGuid,
                 ORD.PRICEITEM                           AS PRICEITEM,
                 ORD.ITEMQTY                             AS ITEMQTY,
                 ORD.OrderNumber                         AS OrderNumber,
                 bu.Cust_Name COLLATE ARABIC_CI_AI       AS Custmar,
                 (CASE @Lang WHEN 0 THEN mt.Name ELSE (CASE mt.LatinName WHEN N'' THEN mt.Name ELSE mt.LatinName END) END ) AS MtName,
                 bu.Date                                 AS BILLDATE,
                 bu.PayType                              AS PayType,
                 BU.Total                                AS Total,
                 BU.CustGUID                             AS CustGuid,
                 bi.Notes COLLATE ARABIC_CI_AI           AS Notes,
                 (BI.BonusQnt /( CASE @Unit
                                                 WHEN 0 THEN ( CASE Bi.Unity
                                                                 WHEN 1 THEN 1
                                                                 WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                                 WHEN 0 THEN 1
                                                                                 ELSE mt.Unit2Fact
                                                                               END )
                                                                 WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                                 WHEN 0 THEN 1
                                                                                 ELSE mt.Unit3Fact
                                                                               END )
                                                                 ELSE 1
                                                               END )
                                                 WHEN 1 THEN 1
                                                 WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                 WHEN 0 THEN 1
                                                                 ELSE mt.Unit2Fact
                                                               END )
                                                 WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                 WHEN 0 THEN 1
                                                                 ELSE mt.Unit3Fact
                                                               END )
                                                 ELSE ( CASE mt.DefUnit
                                                          WHEN 1 THEN 1
                                                          WHEN 2 THEN mt.Unit2Fact
                                                          WHEN 3 THEN mt.Unit3Fact
                                                          ELSE 1
                                                        END )
                                               END ))                             AS BONUSQTY,
				 BI.[ExpireDate]						 As [ExpireDate],
                 BU.CheckTypeGUID                        AS CheckGUID,
                 (CASE @Lang WHEN 0 THEN bt.NAME ELSE (CASE bt.LatinName WHEN N'' THEN bt.NAME ELSE bt.LatinName END) END )   AS ORDERNAME,
                 ORD.OrderNotes,
                 ( ORD.ITEMQTY * ORD.PRICEITEM )         AS ItemTotal,
                 bi.Discount                             AS ItemDiscount,
                 bi.Extra                                AS ItemExtra,
                 ord.TAX                                 AS TAX,
                 ord.OCheck                              AS [Check],
                 dbo.fnOrderApprovalState(ord.OrderGuid) AS ApprovalState,
                 ord.OrderCurrencyName                   AS OrderCurrencyName,
                 ord.OrderCurrencyVal                    AS OrderCurrencyVal,
				 bu.CurrencyVal  AS CurrencyVal,
				 bu.CurrencyGUID AS CurrencyPtr,
				 bi.TotalDiscountPercent AS TotalDiscount,
				 bi.TotalExtraPercent	AS TotalExtra,
				(bi.TotalDiscountPercent + bi.Discount)	AS SumTotalDiscount,
				(bi.TotalExtraPercent + bi.Extra)	AS SumTotalExtra,
				bu.TotalDisc  AS OrderTotalDiscount,
				bu.TotalExtra AS OrderTotalExtra
          INTO   #RES2
          FROM   (SELECT DISTINCT Bi.CostGuid                                                                                AS CostGuid,
                                  BU.CostGuid                                                                                AS buCostGuid,
                                  BI.StoreGUID                                                                               AS StoreGUID,
                                  Bu.StoreGUID                                                                               AS buStoreGUID,
                                  ord.OrderTypeGuid                                                                          AS OrderTypeGuid,
                                  ord.OrderGuid                                                                              AS OrderGuid,
                                  BI.MATGUID                                                                                 AS MATGUID,
                                  BI.GUID                                                                                    AS BIGUID,
                                  ord.OrderNumber                                                                            AS OrderNumber,
                                  dbo.fnCurrency_fix(CASE ( @OrderOptions & @SHOWTAX )
                                                       WHEN @SHOWTAX THEN BI.Price
                                                       ELSE ( CASE BT.VATSystem
                                                                WHEN 0 THEN BI.Price
                                                                ELSE BI.Price + ( BI.VAT / BI.QTY )
                                                              END )
                                                     END, bu.CurrencyGUID, bu.CurrencyVal, CASE
                                                                                             WHEN @IsOrderCurrency = 1 THEN bu.CurrencyGUID
                                                                                             ELSE @CurGUID
                                                                                           END, bu.Date) * ( CASE @Unit
                                                                                                               WHEN 0 THEN ( CASE Bi.Unity
                                                                                                                               WHEN 1 THEN 1
                                                                                                                               WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                                                                                               WHEN 0 THEN 1
                                                                                                                                               ELSE mt.Unit2Fact
                                                                                                                                             END )
                                                                                                                               WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                                                                                               WHEN 0 THEN 1
                                                                                                                                               ELSE mt.Unit3Fact
                                                                                                                                             END )
                                                                                                                               ELSE 1
                                                                                                                             END )
                                                                                                               WHEN 1 THEN 1
                                                                                                               WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                                                                               WHEN 0 THEN 1
                                                                                                                               ELSE mt.Unit2Fact
                                                                                                                             END )
                                                                                                               WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                                                                               WHEN 0 THEN 1
                                                                                                                               ELSE mt.Unit3Fact
                                                                                                                             END )
                                                                                                               ELSE ( CASE mt.DefUnit
                                                                                                                        WHEN 1 THEN 1
                                                                                                                        WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                        WHEN 0 THEN 1
                                                                                                                                        ELSE [mt].[Unit2Fact]
                                                                                                                                      END )
                                                                                                                        ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                 WHEN 0 THEN 1
                                                                                                                                 ELSE [mt].[Unit3Fact]
                                                                                                                               END )
                                                                                                                      END )
                                                                                                             END ) / ( CASE @Unit
                                                                                                                         WHEN 1 THEN ( CASE bi.Unity
                                                                                                                                         WHEN 1 THEN 1
                                                                                                                                         WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                                         WHEN 0 THEN 1
                                                                                                                                                         ELSE [mt].[Unit2Fact]
                                                                                                                                                       END )
                                                                                                                                         ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                                  WHEN 0 THEN 1
                                                                                                                                                  ELSE [mt].[Unit3Fact]
                                                                                                                                                END )
                                                                                                                                       END )
                                                                                                                         WHEN 2 THEN ( CASE bi.Unity
                                                                                                                                         WHEN 1 THEN 1
                                                                                                                                         WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                                         WHEN 0 THEN 1
                                                                                                                                                         ELSE [mt].[Unit2Fact]
                                                                                                                                                       END )
                                                                                                                                         ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                                  WHEN 0 THEN 1
                                                                                                                                                  ELSE [mt].[Unit3Fact]
                                                                                                                                                END )
                                                                                                                                       END )
                                                                                                                         WHEN 3 THEN ( CASE bi.Unity
                                                                                                                                         WHEN 1 THEN 1
                                                                                                                                         WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                                         WHEN 0 THEN 1
                                                                                                                                                         ELSE [mt].[Unit2Fact]
                                                                                                                                                       END )
                                                                                                                                         ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                                  WHEN 0 THEN 1
                                                                                                                                                  ELSE [mt].[Unit3Fact]
                                                                                                                                                END )
                                                                                                                                       END )
                                                                                                                         ELSE ( CASE bi.Unity
                                                                                                                                  WHEN 1 THEN 1
                                                                                                                                  WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                                  WHEN 0 THEN 1
                                                                                                                                                  ELSE [mt].[Unit2Fact]
                                                                                                                                                END )
                                                                                                                                  ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                           WHEN 0 THEN 1
                                                                                                                                           ELSE [mt].[Unit3Fact]
                                                                                                                                         END )
                                                                                                                                END )
                                                                                                                       END ) AS PRICEITEM,
                                  BI.VAT                                                                                     AS TAX,
                                  ( BI.QTY / ( CASE @Unit
                                                 WHEN 0 THEN ( CASE Bi.Unity
                                                                 WHEN 1 THEN 1
                                                                 WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                                 WHEN 0 THEN 1
                                                                                 ELSE mt.Unit2Fact
                                                                               END )
                                                                 WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                                 WHEN 0 THEN 1
                                                                                 ELSE mt.Unit3Fact
                                                                               END )
                                                                 ELSE 1
                                                               END )
                                                 WHEN 1 THEN 1
                                                 WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                 WHEN 0 THEN 1
                                                                 ELSE mt.Unit2Fact
                                                               END )
                                                 WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                 WHEN 0 THEN 1
                                                                 ELSE mt.Unit3Fact
                                                               END )
                                                 ELSE ( CASE mt.DefUnit
                                                          WHEN 1 THEN 1
                                                          WHEN 2 THEN mt.Unit2Fact
                                                          WHEN 3 THEN mt.Unit3Fact
                                                          ELSE 1
                                                        END )
                                               END ) )                                                                       AS ITEMQTY,
                                  ord.OrderNotes,
                                  ord.OCheck,
                                  ord.OrderCurrencyName                                                                      AS OrderCurrencyName,
                                  ord.OrderCurrencyVal                                                                       AS OrderCurrencyVal
                  FROM   #Ordered AS ord
                         INNER JOIN bu000 AS BU
                                 ON ord.OrderGuid = BU.GUID
                         INNER JOIN bt000 AS BT
                                 ON BT.GUID = BU.TypeGUID
                         INNER JOIN bi000 AS BI
                                 ON BI.ParentGUID = BU.GUID
                         INNER JOIN mt000 AS MT
                                 ON MT.GUID = BI.MATGUID
                         INNER JOIN #MatTble MAT
                                 ON MAT.MatGuid = BI.MATGUID
                         INNER JOIN (SELECT [o].[oriPOIGuid],
                                            [o].[oriTypeGuid],
                                            Sum([o].[oriQty]) AS [oriQty],
                                            [o].[oriDate]     AS [oriDate],
                                            [o].[oriNotes]    AS [oriNotes],
                                            [o].[oriNumber]   AS [oriNumber]
                                     FROM   [vwORI][o]
                                     WHERE  oriQty > 0
                                            AND o.oriDate BETWEEN @StartDate AND @EndDate
                                     GROUP  BY [oriPOIGuid],
                                               [o].[oriTypeGuid],
                                               [oriDate],
                                               [oriNumber],
                                               [oriNotes]) AS [ori]
                                 ON [ori].[oriPOIGuid] = [bi].[GUID]
                         INNER JOIN @TypeTbl [t]
                                 ON ISNULL([ori].[oriTypeGuid], 0x0) = [t].[Type]
                  GROUP  BY BU.CostGuid,
                            bi.CostGuid,
                            BI.StoreGUID,
                            bu.StoreGuid,
                            ord.OrderGuid,
                            ord.OrderNumber,
                            bi.MATGUID,
                            MAT.MatGuid,
                            BI.GUID,
                            ord.OrderTypeGuid,
                            dbo.fnCurrency_fix(CASE ( @OrderOptions & @SHOWTAX )
                                                 WHEN @SHOWTAX THEN BI.Price
                                                 ELSE ( CASE BT.VATSystem
                                                          WHEN 0 THEN BI.Price
                                                          ELSE BI.Price + ( BI.VAT / BI.QTY )
                                                        END )
                                               END, bu.CurrencyGUID, bu.CurrencyVal, CASE
                                                                                       WHEN @IsOrderCurrency = 1 THEN bu.CurrencyGUID
                                                                                       ELSE @CurGUID
                                                                                     END, bu.Date) * ( CASE @Unit
                                                                                                         WHEN 0 THEN ( CASE Bi.Unity
                                                                                                                         WHEN 1 THEN 1
                                                                                                                         WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                                                                                         WHEN 0 THEN 1
                                                                                                                                         ELSE mt.Unit2Fact
                                                                                                                                       END )
                                                                                                                         WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                                                                                         WHEN 0 THEN 1
                                                                                                                                         ELSE mt.Unit3Fact
                                                                                                                                       END )
                                                                                                                         ELSE 1
                                                                                                                       END )
                                                                                                         WHEN 1 THEN 1
                                                                                                         WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                                                                         WHEN 0 THEN 1
                                                                                                                         ELSE mt.Unit2Fact
                                                                                                                       END )
                                                                                                         WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                                                                         WHEN 0 THEN 1
                                                                                                                         ELSE mt.Unit3Fact
                                                                                                                       END )
                                                                                                         ELSE ( CASE mt.DefUnit
                                                                                                                  WHEN 1 THEN 1
                                                                                                                  WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                  WHEN 0 THEN 1
                                                                                                                                  ELSE [mt].[Unit2Fact]
                                                                                                                                END )
                                                                                                                  ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                           WHEN 0 THEN 1
                                                                                                                           ELSE [mt].[Unit3Fact]
                                                                                                                         END )
                                                                                                                END )
                                                                                                       END ) / ( CASE @Unit
                                                                                                                   WHEN 1 THEN ( CASE bi.Unity
                                                                                                                                   WHEN 1 THEN 1
                                                                                                                                   WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                                   WHEN 0 THEN 1
                                                                                                                                                   ELSE [mt].[Unit2Fact]
                                                                                                                                                 END )
                                                                                                                                   ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                            WHEN 0 THEN 1
                                                                                                                                            ELSE [mt].[Unit3Fact]
                                                                                                                                          END )
                                                                                                                                 END )
                                                                                                                   WHEN 2 THEN ( CASE bi.Unity
                                                                                                                                   WHEN 1 THEN 1
                                                                                                                                   WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                                   WHEN 0 THEN 1
                                                                                                                                                   ELSE [mt].[Unit2Fact]
                                                                                                                                                 END )
                                                                                                                                   ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                            WHEN 0 THEN 1
                                                                                                                                            ELSE [mt].[Unit3Fact]
                                                                                                                                          END )
                                                                                                                                 END )
                                                                                                                   WHEN 3 THEN ( CASE bi.Unity
                                                                                                                                   WHEN 1 THEN 1
                                                                                                                                   WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                                   WHEN 0 THEN 1
                                                                                                                                                   ELSE [mt].[Unit2Fact]
                                                                                                                                                 END )
                                                                                                                                   ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                            WHEN 0 THEN 1
                                                                                                                                            ELSE [mt].[Unit3Fact]
                                                                                                                                          END )
                                                                                                                                 END )
                                                                                                                   ELSE ( CASE bi.Unity
                                                                                                                            WHEN 1 THEN 1
                                                                                                                            WHEN 2 THEN ( CASE [mt].[Unit2Fact]
                                                                                                                                            WHEN 0 THEN 1
                                                                                                                                            ELSE [mt].[Unit2Fact]
                                                                                                                                          END )
                                                                                                                            ELSE ( CASE [mt].[Unit3Fact]
                                                                                                                                     WHEN 0 THEN 1
                                                                                                                                     ELSE [mt].[Unit3Fact]
                                                                                                                                   END )
                                                                                                                          END )
                                                                                                                 END ),
                            BI.VAT,
                            ( BI.QTY / ( CASE @Unit
                                           WHEN 0 THEN ( CASE Bi.Unity
                                                           WHEN 1 THEN 1
                                                           WHEN 2 THEN ( CASE mt.Unit2Fact
                                                                           WHEN 0 THEN 1
                                                                           ELSE mt.Unit2Fact
                                                                         END )
                                                           WHEN 3 THEN ( CASE mt.Unit3Fact
                                                                           WHEN 0 THEN 1
                                                                           ELSE mt.Unit3Fact
                                                                         END )
                                                           ELSE 1
                                                         END )
                                           WHEN 1 THEN 1
                                           WHEN 2 THEN ( CASE mt.Unit2Fact
                                                           WHEN 0 THEN 1
                                                           ELSE mt.Unit2Fact
                                                         END )
                                           WHEN 3 THEN ( CASE mt.Unit3Fact
                                                           WHEN 0 THEN 1
                                                           ELSE mt.Unit3Fact
                                                         END )
                                           ELSE ( CASE mt.DefUnit
                                                    WHEN 1 THEN 1
                                                    WHEN 2 THEN mt.Unit2Fact
                                                    WHEN 3 THEN mt.Unit3Fact
                                                    ELSE 1
                                                  END )
                                         END ) ),
                            ord.OrderNotes,
                            ord.OCheck,
                            ord.OrderCurrencyName,
                            ord.OrderCurrencyVal) AS ORD
                 INNER JOIN bu000 AS bu
                         ON bu.GUID = ord.OrderGuid
                 INNER JOIN mt000 AS mt
                         ON mt.GUID = ord.MATGUID
                 INNER JOIN #MatTble AS mat
                         ON mat.MatGuid = ord.MATGUID
                 INNER JOIN bi000 AS bi
                         ON bi.GUID = ord.BIGUID
                 INNER JOIN bt000 AS bt
                         ON bt.GUID = ord.OrderTypeGuid


          IF ( @ShowChecked > 0 )
            BEGIN
                --DECLARE @UserGuid [UNIQUEIDENTIFIER] 
                SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
                UPDATE [Res]
                SET    [Check] = 1
                FROM   [#Res2] AS [Res]
                       INNER JOIN [RCH000] AS [RCH]
                               ON [Res].[OrderGuid] = [RCH].[ObjGUID]
                WHERE  @RID = [RCH].[Type]
                       AND ( ( @CheckForUsers = 1 )
                              OR ( [RCH].[UserGuid] = @UserGuid ) )
                IF( @ItemChecked = 0 )
                  DELETE FROM [#Res2]
                  WHERE  [Check] <> 1
                          OR [Check] IS NULL
                ELSE IF( @ItemChecked = 1 )
                  DELETE FROM [#Res2]
                  WHERE  [Check] = 1
            END
      END
    DECLARE @FINALRESULT1 AS NVARCHAR(max)
    DECLARE @ResTbl AS NVARCHAR(50)
    DECLARE @SelectState AS NVARCHAR(MAX)
    IF ( @IFDETLASE = 0 )
      BEGIN
          SET @ResTbl = '#RES1'
          SET @SelectState = 'R.OrderTypeGuid' + ',R.OrderName'
                             + ',R.OrderGuid' + ',R.OrderQty'
                             + ',R.OrderNumber' + ',R.Custmar'
                             + ',R.BILLDATE' + ',R.PayType' + ',R.CustGuid'
                             + ',R.buStoreGUID' + ',R.buCOSTGUID'
                             + ',R.TOTAL' + ',R.OrderNotes'
                             + ',R.OrderDiscount AS Discount' --Discount 
                             + ',CASE R.TOTAL WHEN 0 THEN 0 ELSE ((R.OrderDiscount / R.TOTAL) * 100) END AS DiscountRatio' --DiscountRatio 
                             + ',R.OrderExtra AS Extra' --Extra 
                             + ',CASE R.TOTAL WHEN 0 THEN 0 ELSE ((R.OrderExtra / R.TOTAL) * 100) END AS ExtraRatio' --ExtraRatio 
                             + ',R.[Check]' + ',R.ApprovalState'
                             + ',R.OrderCurrencyName '
                             + ',R.OrderCurrencyVal'
      END
    ELSE
      BEGIN
          SET @ResTbl = '#RES2' 
          SET @SelectState = 'R.BIGUID' + ',R.MATGUID' + ',R.CostGuid'
                             + ',R.buCostGuid' + ',R.OrderTypeGuid'
                             + ',R.StoreGUID' + ',R.buStoreGUID'
                             + ',R.OrderGuid' + ',R.PRICEITEM' + ',R.CurrencyVal' + ',R.ITEMQTY'
                             + ',R.OrderNumber' + ',R.Custmar' + ',R.MtName'
                             + ',R.BILLDATE' + ',R.PayType' + ',R.Total'
                             + ',R.CustGuid' + ',R.Notes' + ',R.BONUSQTY, R.ExpireDate'
                             + ',R.CheckGUID' + ',R.ORDERNAME'
                             + ',R.OrderNotes'
							 + ',(dbo.fnCurrency_fix(R.ItemDiscount , R.CurrencyPtr, R.CurrencyVal, 
																			CASE
                                                                            WHEN '+ Cast(@IsOrderCurrency AS nvarchar(50)) +' = 1 THEN R.CurrencyPtr
                                                                            ELSE '''+convert(nvarchar(250), @CurGUID)+'''
                                                                            END, R.BILLDATE)) AS Discount' --Discount
							+ ',(dbo.fnCurrency_fix(R.ItemExtra , R.CurrencyPtr, R.CurrencyVal, 
																			CASE
                                                                            WHEN '+ Cast(@IsOrderCurrency AS nvarchar(50)) +' = 1 THEN R.CurrencyPtr
                                                                            ELSE '''+convert(nvarchar(250), @CurGUID)+'''
                                                                            END, R.BILLDATE)) AS Extra' --Extra
						   + ',(dbo.fnCurrency_fix(R.TAX , R.CurrencyPtr, R.CurrencyVal, 
																			CASE
                                                                            WHEN '+ Cast(@IsOrderCurrency AS nvarchar(50)) +' = 1 THEN R.CurrencyPtr
                                                                            ELSE '''+convert(nvarchar(250), @CurGUID)+'''
                                                                            END, R.BILLDATE)) AS TAX' --TAX
						  + ',(dbo.fnCurrency_fix(R.TotalDiscount , R.CurrencyPtr, R.CurrencyVal, 
																			CASE
                                                                            WHEN '+ Cast(@IsOrderCurrency AS nvarchar(50)) +' = 1 THEN R.CurrencyPtr
                                                                            ELSE '''+convert(nvarchar(250), @CurGUID)+'''
                                                                            END, R.BILLDATE)) AS TotalDiscount' --TotalDiscount
						+ ',(dbo.fnCurrency_fix(R.TotalExtra , R.CurrencyPtr, R.CurrencyVal, 
																			CASE
                                                                            WHEN '+ Cast(@IsOrderCurrency AS nvarchar(50)) +' = 1 THEN R.CurrencyPtr
                                                                            ELSE '''+convert(nvarchar(250), @CurGUID)+'''
                                                                            END, R.BILLDATE)) AS TotalExtra' --TotalExtra	
						+ ',(dbo.fnCurrency_fix(R.SumTotalDiscount , R.CurrencyPtr, R.CurrencyVal, 
																			CASE
                                                                            WHEN '+ Cast(@IsOrderCurrency AS nvarchar(50)) +' = 1 THEN R.CurrencyPtr
                                                                            ELSE '''+convert(nvarchar(250), @CurGUID)+'''
                                                                            END, R.BILLDATE)) AS SumTotalDiscount' --SumTotalDiscount	
					   + ',(dbo.fnCurrency_fix(R.SumTotalExtra , R.CurrencyPtr, R.CurrencyVal, 
																			CASE
                                                                            WHEN '+ Cast(@IsOrderCurrency AS nvarchar(50)) +' = 1 THEN R.CurrencyPtr
                                                                            ELSE '''+convert(nvarchar(250), @CurGUID)+'''
                                                                            END, R.BILLDATE)) AS SumTotalExtra' --SumTotalExtra
							
                             SET @SelectState = @SelectState + ',CASE R.ItemTotal WHEN 0 THEN 0 ELSE (R.ItemDiscount / R.ItemTotal) END AS DiscountRatio' --DiscountRatio 
                             + ',CASE R.ItemTotal WHEN 0 THEN 0 ELSE (R.ItemExtra / R.ItemTotal) END AS ExtraRatio' --ExtraRatio 
							 + ',R.[Check]' + ',R.ApprovalState'
                             + ',R.OrderCurrencyName'
                             + ',R.OrderCurrencyVal'
      END

    DECLARE @MatSelect AS NVARCHAR(1000)
    SET @MatSelect = ' '
      SET @MatSelect = @MatSelect + ',(CASE '
                       + Cast(@Unit AS NVARCHAR(10))
                       + '
						WHEN 0 THEN (CASE bi.Unity
										WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
										WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
										ELSE mt.Unity
									END)
						WHEN 1 THEN mt.Unity
						WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
						WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
						ELSE CASE mt.DefUnit 
								WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
								WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
							 ELSE mt.Unity
							 END
					    END) AS [Unity]'
    SET @FINALRESULT1 = 'DECLARE @Lang INT = dbo.fnConnections_GetLanguage(); SELECT ' + @SelectState  + ( CASE
                                                                    WHEN ( @MatFldsFlag > 0 )
                                                                         AND ( @IFDETLASE = 1 ) THEN @MatSelect
                                                                    ELSE ''
                                                                  END ) 
																  + CASE @IFDETLASE
                                                                            WHEN 1 THEN ( CASE ( @OrderOptions&8 )
                                                                                            WHEN 8 THEN ',(CASE @Lang WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN N'''' THEN st.Name ELSE st.LatinName END) END ) Store   '
                                                                                            ELSE ' '
                                                                                          END )
                                                                            ELSE ''
                                                                          END + ( CASE ( @OrderOptions&8 )
                                                                                    WHEN 8 THEN ',ST2.NAME buSTORENAME   '
                                                                                    ELSE ' '
                                                                                  END ) + CASE @IFDETLASE
                                                                                            WHEN 1 THEN ( CASE ( @OrderOptions&16 )
                                                                                                            WHEN 16 THEN ',(CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'''' THEN co.NAME ELSE co.LatinName END) END )  AS CostCenter  '
                                                                                                            ELSE ''
                                                                                                          END )
                                                                                            ELSE ''
                                                                                          END + ( CASE ( @OrderOptions&16 )
                                                                                                    WHEN 16 THEN ',CO2.NAME  AS buCOSTNAME  '
                                                                                                    ELSE ''
                                                                                                  END ) + ( CASE ( @OrderOptions&32 )
                                                                                                              WHEN 32 THEN ',INFO.Finished Finished , INFO.Add1 COLSED  '
                                                                                                              ELSE ''
                                                                                                            END ) + ( CASE ( @OrderOptions&64 )
                                                                                                                        WHEN 64 THEN ',bi.Classptr  AS OrderClassptr  '
                                                                                                                        ELSE ''
                                                                                                                      END ) + 'FROM ' + @ResTbl + '  AS R ' +
																										  CASE @IFDETLASE
                                                                                                            WHEN 1 THEN ( CASE ( @OrderOptions&8 )
                                                                                                                            WHEN 8 THEN '  LEFT JOIN ST000 AS ST   ON ST.GUID  =   R.StoreGUID '
                                                                                                                            ELSE ''
                                                                                                                          END )
                                                                                                            ELSE ''
                                                                                                          END + ( CASE ( @OrderOptions&8 )
                                                                                                                    WHEN 8 THEN '  LEFT JOIN ST000 AS ST2   ON ST2.GUID  =   R.buStoreGUID '
                                                                                                                    ELSE ''
                                                                                                                  END ) + CASE @IFDETLASE
                                                                                                                            WHEN 1 THEN ( CASE ( @OrderOptions&16 )
                                                                                                                            WHEN 16 THEN '  LEFT JOIN CO000 AS CO   ON CO.GUID  =   R.CostGuid '
                                                                                                                            ELSE ''
                                                                                                                                          END )
                                                                                                                            ELSE ''
                                                                                                                          END + ( CASE ( @OrderOptions&16 )
                        WHEN 16 THEN '  LEFT JOIN CO000 AS CO2   ON CO2.GUID  =   R.buCostGuid '
                        ELSE ''
                                                                                                                                  END ) + ( CASE ( @OrderOptions&32 )
                        WHEN 32 THEN ' INNER JOIN ORADDINFO000 INFO ON INFO.ParentGuid=R.OrderGuid '
                        ELSE ''
                                                                                                                                            END ) + ( CASE ( @OrderOptions&64 )
                                            WHEN 64 THEN 'INNER JOIN Bi000 bi ON bi.ParentGuid = r.OrderGuid AND R.MATGUID = BI.MATGUID AND bi.GUID = R.BIGUID'
                                            ELSE ''
                                                                                                                                                      END ) + ( CASE
                                            WHEN ( @MatFldsFlag > 0 )
                                                 AND ( @IFDETLASE = 1 ) THEN ' INNER JOIN mt000 AS MT ON MT.GUID = R.MATGUID '
                                            ELSE ''
                                                                                                                                                                END )
                        +' INNER JOIN #MatTble MAT ON MAT.MatGuid = R.MatGuid' 
                        + ' ORDER BY  r.Custmar'  + ' ,r.OrderTypeGuid, OrderNumber' + CASE @IFDETLASE
                                                                                         WHEN 1 THEN ', MtName'
                                                                                         ELSE ''
                                                                                       END;
	-- First Result Set:
    EXEC (@FINALRESULT1)

	CREATE TABLE #StatesResult
	(
		Name NVARCHAR(max),
		StateGuid UNIQUEIDENTIFIER,
		StateQty FLOAT,
		PayType INT,
		ItemPrice FLOAT,
		biGuid UNIQUEIDENTIFIER,
		CurrencyName NVARCHAR(max),
		CurrencyGuid UNIQUEIDENTIFIER,
		UnitFact FLOAT
	)

	INSERT INTO #StatesResult
    SELECT 
		(CASE @Lang WHEN 0 THEN oit.Name ELSE (CASE oit.LatinName WHEN N'' THEN oit.Name ELSE oit.LatinName END) END ) , 
		ori.TypeGuid AS StateGuid, 
		(ori.Qty /(CASE @Unit
				WHEN 0 THEN (CASE bi.biUnity
								WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0  THEN 1 ELSE mt.Unit2Fact END) 
								WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0  THEN 1 ELSE mt.Unit3Fact END) 
								 ELSE 1
							 END)
				WHEN 1 THEN 1 
				WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0  THEN 1 ELSE mt.Unit2Fact END) 
				WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0  THEN 1 ELSE mt.Unit3Fact END) 
				ELSE (CASE mt.DefUnit WHEN 1 THEN 1  WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END) 
				END) 
				) AS StateQty,
		bu.PayType, 
		(dbo.fnCurrency_fix
			(
				((bi.biQty * (bi.biUnitPrice + bi.biUnitExtra - bi.biUnitDiscount)) + bi.biVAT) / (CASE bi.biQty WHEN 0 THEN 1 ELSE bi.biQty END) 
		 ,bu.CurrencyGUID, bu.CurrencyVal, CASE WHEN @IsOrderCurrency = 1 THEN bu.CurrencyGUID ELSE @CurGUID END , bu.Date) 
		) As ItemPrice 
		, bi.[biGUID] AS biGuid
        , CurrencyTable.Name AS CurrencyName, CurrencyTable.GUID AS CurrencyGuid,
		(CASE @Unit
				WHEN 0 THEN (CASE bi.biUnity
								WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0  THEN 1 ELSE mt.Unit2Fact END) 
								WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0  THEN 1 ELSE mt.Unit3Fact END) 
								 ELSE 1
							 END)
				WHEN 1 THEN 1 
				WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0  THEN 1 ELSE mt.Unit2Fact END) 
				WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0  THEN 1 ELSE mt.Unit3Fact END) 
				ELSE (CASE mt.DefUnit WHEN 1 THEN 1  WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END) 
				END) 	  
             FROM #RES2 AS res
              INNER JOIN vwExtended_bi AS bi ON bi.buGUID = res.OrderGuid 
		INNER JOIN #MatTble AS MAT ON MAT.MatGuid = bi.biMatPtr 
		INNER JOIN mt000 AS MT ON MT.GUID = bi.biMatPtr 
		INNER JOIN ORI000 AS ori ON ori.POIGuid = bi.biGUID 
		INNER JOIN bu000 AS bu ON bu.[Guid] = res.OrderGuid 
		INNER JOIN bt000 AS bt ON bt.[Guid] = bu.typeGuid 
		INNER JOIN oit000 AS oit ON oit.[Guid] = ori.TypeGuid
        INNER JOIN my000  AS CurrencyTable  ON  CurrencyTable.GUID = bu.CurrencyGUID
		GROUP BY 
		(CASE @Lang WHEN 0 THEN oit.Name ELSE (CASE oit.LatinName WHEN N'' THEN oit.Name ELSE oit.LatinName END) END ) , 
		ori.TypeGuid, 
		ori.Qty, 
		bu.PayType, 
		(dbo.fnCurrency_fix
			(
			((bi.biQty * (bi.biUnitPrice +  bi.biUnitExtra - bi.biUnitDiscount)) + bi.biVAT) / (CASE bi.biQty WHEN 0 THEN 1 ELSE bi.biQty END) ,
			  bu.CurrencyGUID,
			  bu.CurrencyVal,
			  CASE WHEN @IsOrderCurrency = 1 THEN bu.CurrencyGUID ELSE @CurGUID END,
			  bu.Date) 
			) 
		,bi.[biGUID],bi.biMatPtr , CurrencyTable.Name, CurrencyTable.GUID,mt.DefUnit,mt.Unit2Fact,mt.Unit3Fact, bi.biUnity
		ORDER BY bi.biGUID
		
	-- Second Result Set
	SELECT #StatesResult.*, biStatesCount.StatesCount FROM #StatesResult
	        INNER JOIN (
				SELECT COUNT(Name) AS StatesCount, biGuid
				FROM #StatesResult
				GROUP BY
				biGuid
			) AS biStatesCount ON biStatesCount.biGuid = #StatesResult.biGuid

	CREATE TABLE #StatesSummary
	(
		SummaryName NVARCHAR(max),
		PayType INT,
		Qty	FLOAT,
		Price FLOAT
	)

	INSERT INTO #StatesSummary
		SELECT
		CASE @IsOrderCurrency WHEN 1 THEN CurrencyName ELSE Name END,
		PayType,
		Sum(StateQty) AS Qty,
		SUM(ItemPrice * StateQty * UnitFact) AS Price
		FROM #StatesResult
		GROUP BY
		PayType,
		CASE @IsOrderCurrency WHEN 1 THEN CurrencyName ELSE Name END

	-- Third Result Set (Footer Totals):		
	SELECT 
	PayTypeSummary.SummaryName,
	SUM(Qty) AS Qty,
	SUM(Price) AS Total,
	PayTypeSummary.Cash Cash,
	PayTypeSummary.Forward Forward
	FROM #StatesSummary
	INNER JOIN (
			SELECT SummaryName, 
			CASE PayType WHEN 0 THEN SUM(Price) ELSE 0 END AS Cash,
			CASE PayType WHEN 1 THEN SUM(Price) ELSE 0 END AS Forward
			FROM #StatesSummary
			GROUP BY SummaryName, PayType
		) AS PayTypeSummary ON PayTypeSummary.SummaryName = #StatesSummary.SummaryName
	
	GROUP BY
	PayTypeSummary.SummaryName,
	PayTypeSummary.Cash,
	PayTypeSummary.Forward
		
    IF @OrderOptions & 256 = 256
      BEGIN
		-- States Result:
        SELECT
		oit.[GUID],
        oit.NAME oitName,
        oit.LatinName oitLatinName,
        oit.[Type] IsSalesType
        FROM   oit000 oit
        WHERE  oit.[GUID] IN ( SELECT ori.TypeGuid
							   FROM   #RES2 AS res
							   INNER JOIN ORI000 AS ori ON ori.POIGuid = res.biGuid
							 )
        ORDER  BY
		oit.Type,
		oit.PostQty

      END 
	   IF ( @IFDETLASE = 0 )
		BEGIN
			SELECT  DISTINCT r.OrderGuid, ch.TypeGUID 
			FROM #RES1 r 
			INNER JOIN ch000 ch ON r.OrderGuid = ch.ParentGUID
		END
	   ELSE
		BEGIN
			SELECT DISTINCT R2.OrderGuid, 
							R2.ORDERNAME AS OrderName,
							(SUM(R2.ITEMQTY) + SUM(R2.BONUSQTY))	AS TotalQty,
							SUM(R2.BONUSQTY) AS TotalBonus,
							SUM(R2.PRICEITEM * R2.ITEMQTY) AS TotalPrices,
							SUM(dbo.fnCurrency_fix(R2.TAX , R2.CurrencyPtr, R2.CurrencyVal, 
																			CASE
                                                                            WHEN @IsOrderCurrency = 1 THEN R2.CurrencyPtr
                                                                            ELSE @CurGUID
                                                                            END, R2.BILLDATE)) AS TotalTax,
							SUM(CASE @IsOrderCurrency WHEN 0 THEN R2.ItemDiscount / R2.CurrencyVal WHEN 1 THEN R2.ItemDiscount / R2.OrderCurrencyVal END) AS Discounts,
							SUM(CASE @IsOrderCurrency WHEN 0 THEN R2.ItemExtra / R2.CurrencyVal WHEN 1 THEN R2.ItemExtra / R2.OrderCurrencyVal END) AS Extras,
							R2.OrderNumber,
							R2.BILLDATE, 
							R2.Custmar,
							R2.CustGuid,
							R2.ApprovalState,
							R2.PayType,
							R2.OrderCurrencyName, 
							R2.OrderCurrencyVal,
							st.Name AS buSTORENAME,
							co.Name AS buCOSTNAME, 
							R2.OrderTypeGuid,
							info.Finished,
							INFO.Add1 AS COLSED,
							R2.[Check],
							(dbo.fnCurrency_fix(R2.OrderTotalDiscount , R2.CurrencyPtr, R2.CurrencyVal, 
																			CASE
                                                                            WHEN @IsOrderCurrency = 1 THEN R2.CurrencyPtr
                                                                            ELSE @CurGUID
                                                                            END, R2.BILLDATE)) AS OrderTotalDiscount
							,(dbo.fnCurrency_fix(R2.OrderTotalExtra , R2.CurrencyPtr, R2.CurrencyVal, 
																			CASE
                                                                            WHEN @IsOrderCurrency = 1 THEN R2.CurrencyPtr
                                                                            ELSE @CurGUID
                                                                            END, R2.BILLDATE)) AS OrderTotalExtra
			FROM #RES2 R2
			LEFT JOIN st000 st ON R2.buStoreGUID = st.[GUID]
			LEFT JOIN co000 co ON R2.buCostGuid = co.[GUID]
			LEFT JOIN OrAddInfo000 info ON R2.OrderGuid = info.ParentGuid
			GROUP BY		R2.OrderGuid,
							R2.ORDERNAME,
							R2.OrderNumber,
							R2.BILLDATE,
							R2.Custmar,
							R2.CustGuid, 
							R2.ApprovalState,
							R2.PayType,
							R2.OrderCurrencyName, 
							R2.OrderCurrencyVal,
							R2.OrderTypeGuid,
							R2.[Check],
							st.Name,
							co.Name, 
							info.Finished,
							INFO.Add1,
							R2.OrderTotalDiscount,
							R2.OrderTotalExtra,
							R2.CurrencyVal,
							R2.CurrencyPtr
							
			SELECT  DISTINCT r.OrderGuid,
							 ch.TypeGUID 
			FROM #RES2 r 
			INNER JOIN ch000 ch ON r.OrderGuid = ch.ParentGUID
		END
#########################################################################
#END
