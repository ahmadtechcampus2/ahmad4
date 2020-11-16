#############################################################################
CREATE PROCEDURE repOrdersPlanningMaterialsWithBorders @Store                    AS [UNIQUEIDENTIFIER],
                                                       @Group                    AS [UNIQUEIDENTIFIER],
                                                       @Unit                     AS INT,--1: First, 2: Second, 3: Third, Else: Default
                                                       @MaterialCondition        AS [UNIQUEIDENTIFIER] = 0x00,
                                                       @ReportSources            AS [UNIQUEIDENTIFIER],--
                                                       @ReportOption             AS INT,
                                                       -- Purchase options (0: Less than High limit, 1: Less than Order limit, 2: Less than Low limit, 3: less than specific value)

                                                       -- Sales options (4: greater than High limit, 5: greater than specific value, 6: Between min and max values)
                                                       @MinValue                 AS FLOAT,--related to @ReportOption
                                                       @MaxValue                 AS FLOAT,--related to @ReportOption
                                                       @IncludeEmptyMaterials    AS BIT,
                                                       @IncludeBalancedMaterials AS BIT,
                                                       @StoresDetails            AS BIT,
                                                       @OnlyOrderedMaterials     AS BIT
AS
    SET NOCOUNT ON

    ----------------------------
	CREATE TABLE [#SecViol]
      (
         [Type] [INT],
         [Cnt]  [INT]
      )

    ----------------------------
    CREATE TABLE [#Mat]
      (
         [mtNumber]   [UNIQUEIDENTIFIER],
         [mtSecurity] [INT]
      )

    INSERT INTO [#Mat]
    EXEC [prcGetMatsList]
      NULL,
      @Group,
      0,
      @MaterialCondition

	
    CREATE CLUSTERED INDEX [ovFlow]
      ON [#Mat]([mtNumber])

    --select '#Mat', * from #Mat
    ----------------------------
    CREATE TABLE [#Store]
      (
         [Number] [UNIQUEIDENTIFIER]
      )

    INSERT INTO [#Store]
    SELECT [GUID]
    FROM   [fnGetStoresList](@Store)

    --select '#Store', * from #Store
    -- «· Œ·’ „‰ «·„” Êœ⁄«  «· Ã„Ì⁄Ì…
    SELECT hst.[Number]
    INTO   #Stores
    FROM   #Store hst
           INNER JOIN st000 st
                   ON hst.[Number] = st.[GUID]
    WHERE  st.Kind = 0

    --select '#Stores', * from #Stores
    ----------------------------
    CREATE TABLE [#Groups]
      (
         [GUID] [UNIQUEIDENTIFIER]
      )

    INSERT INTO [#Groups]
    SELECT [GUID]
    FROM   [fnGetGroupsList](@Group)

    ----------------------------
    CREATE TABLE #OrderTypesTbl
      (
         Type        UNIQUEIDENTIFIER,
         Sec         INT,
         ReadPrice   INT,
         UnPostedSec INT
      )

    INSERT INTO #OrderTypesTbl
    EXEC prcGetBillsTypesList2
      @ReportSources

    ----------------------------
    SELECT DISTINCT mt.mtGUID
    INTO   #OnlyOrderedMats
    FROM   vwMt mt
           INNER JOIN vwExtended_bi vbi
                   ON mt.mtGUID = vbi.biMatPtr
           INNER JOIN #OrderTypesTbl otbl
                   ON vbi.buType = otbl.[Type]
    WHERE  vbi.buGuid IN (SELECT bu.[GUID]
                          FROM   bu000 bu
                                 INNER JOIN bt000 bt
                                         ON bu.TypeGuid = bt.[GUID]
                          WHERE  bt.[Type] IN ( 5, 6 ))
	
	--select '#OnlyOrderedMats', * from #OnlyOrderedMats;
    ----------------------------
    --STOCK
    (SELECT xuz.mtGuid,
            ISNULL(stGUID, 0x00)                           AS stGUID,
            Sum(ISNULL(inQty, 0)) - Sum(ISNULL(outQty, 0)) AS StockQty,
            ( CASE
                WHEN ( Sum(ISNULL(inQty, 0)) = 0 )
                     AND ( Sum(ISNULL(outQty, 0)) = 0 ) THEN 1
                ELSE 0
              END )                                        AS IsStockEmpty,
            ( CASE
                WHEN ( Sum(ISNULL(inQty, 0)) - Sum(ISNULL(outQty, 0)) = 0 )
                     AND ( Sum(ISNULL(inQty, 0)) <> 0 )
                     AND ( Sum(ISNULL(outQty, 0)) <> 0 ) THEN 1
                ELSE 0
              END )                                        AS IsStockBalanced,
            Sum(ISNULL(inQty, 0))                          AS InQty,
            Sum(ISNULL(outQty, 0))                         AS OutQty,
            0                                              AS SalesOrdered,
            0                                              AS SalesAchieved,
            0                                              AS SalesRemainder,
            0                                              AS PurchaseOrdered,
            0                                              AS PurchaseAchieved,
            0                                              AS PurchaseRemainder
     INTO   #Stock
     FROM   (SELECT mt.[GUID]         AS mtGuid,
                    bb.stGUID         AS stGUID,
                    ISNULL(bb.Qty, 0) AS inQty,
                    0                 AS outQty
             FROM   vbMt AS mt
                     LEFT JOIN (SELECT bi.MatGuid,
                                      bi.StoreGUID                       AS stGUID,
                                      ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS Qty
                               FROM   bi000 AS bi
                                      INNER JOIN bu000 AS bu
                                              ON bi.ParentGuid = bu.[GUID]
                                      INNER JOIN bt000 AS bt
                                              ON bu.TypeGuid = bt.[GUID]
                               --INNER JOIN #OrderTypesTbl AS otbl ON bt.[GUID] = otbl.[TYPE] -- ≈–« ·€Ì‰«  ⁄·Ìﬁ Â–« «·”ÿ— ”‰Œ”— »÷«⁄… √Ê· «·„œ… ›Ì «·„Œ“Ê‰
                               WHERE  ( bt.bIsInput = 1 )
                                      AND ( bt.[Type] NOT IN ( 5, 6 ) )
                                      AND ( bu.[IsPosted] = 1 )									 
                                      AND ( ( @Store = 0x0 )
                                             OR ( ( bi.StoreGUID IN (SELECT [Number]
                                                                     FROM   #Stores) )
                                                  AND ( @Store <> 0x0 ) ) )
                               GROUP  BY bi.MatGuid,
                                         bi.StoreGUID) AS bb
                           ON bb.MatGuid = mt.[GUID] 
             -----------------------------------------------------------------------------------------     
             UNION ALL
             SELECT mt.[GUID],
                    bb.stGUID,
                    0                 AS inQty,
                    ISNULL(bb.Qty, 0) AS outQty
             FROM   mt000 AS mt
                     LEFT JOIN (SELECT bi.MatGuid,
                                      bi.StoreGUID                       AS stGUID,
                                      ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS Qty
                               FROM   bi000 AS bi
                                      INNER JOIN bu000 AS bu
                                              ON bi.ParentGuid = bu.[GUID]
                                      INNER JOIN bt000 AS bt
                                              ON bu.TypeGuid = bt.[GUID]
                               --INNER JOIN #OrderTypesTbl AS otbl ON bt.[GUID] = otbl.[TYPE]   
                               WHERE  ( bt.bIsInput = 0 )
                                      AND ( bt.[Type] NOT IN ( 5, 6 ) )
                                      AND ( bu.[IsPosted] = 1 )
                                      AND ( ( @Store = 0x0 )
                                             OR ( ( bi.StoreGUID IN (SELECT [Number]
                                                                     FROM   #Stores) )
                                                  AND ( @Store <> 0x0 ) ) )
                               GROUP  BY bi.MatGuid,
                                         bi.StoreGUID) AS bb
                           ON bb.MatGuid = mt.[GUID] 
             UNION ALL
             SELECT mt.mtGUID AS MatGuid,
                    stGUID,
                    0         AS inQty,
                    0         AS outQty
             FROM   vwMt mt
                    JOIN vwSt st
                      ON ( st.stGUID <> 0x0 )
                         AND ( mt.mtGUID <> 0x0 )) xuz
     GROUP  BY xuz.mtGuid,
               xuz.stGUID)

    --select '#Stock', * from #Stock Order by mtGuid
    -- Sales Orders
    SELECT sls.mtGuid,
           sls.stGUID,
           0                                                                      AS StockQty,
           0                                                                      AS IsStockEmpty,
           0                                                                      AS IsStockBalanced,
           0                                                                      AS InQty,
           0                                                                      AS OutQty,
           Sum(ISNULL(sls.OrderedQtySum, 0))                                      AS SalesOrdered,
           Sum(ISNULL(sls.AchievedQtySum, 0))                                     AS SalesAchieved,
           Sum(ISNULL(sls.OrderedQtySum, 0)) - Sum(ISNULL(sls.AchievedQtySum, 0)) AS SalesRemainder,
           0                                                                      AS PurchaseOrdered,
           0                                                                      AS PurchaseAchieved,
           0                                                                      AS PurchaseRemainder
    INTO   #Sales
    FROM   (
           --Ordered Part 
           SELECT bi.biMatPtr            AS mtGuid,
                  bi.biStorePtr          AS stGUID,
                  ( bi.biQty / ( CASE @Unit
                                   WHEN 1 THEN 1
                                   WHEN 2 THEN ISNULL(CASE bi.[mtUnit2Fact]
                                                        WHEN 0 THEN 1
                                                        ELSE bi.[mtUnit2Fact]
                                                      END, 1)
                                   WHEN 3 THEN ISNULL(CASE bi.[mtUnit3Fact]
                                                        WHEN 0 THEN 1
                                                        ELSE bi.[mtUnit3Fact]
                                                      END, 1)
                                   ELSE ISNULL(CASE bi.[mtDefUnitFact]
                                                 WHEN 0 THEN 1
                                                 ELSE bi.[mtDefUnitFact]
                                               END, 1)
                                 END ) ) AS OrderedQtySum,
                  0                      AS AchievedQtySum
           FROM   vwExtended_bi bi
           -- no need to join with ori000 to know ordered quantity 
           WHERE  [buGUID] IN (SELECT bu.[GUID]
                               FROM   bu000 bu
                                      INNER JOIN ORADDINFO000 oinfo
                                              ON bu.[GUID] = oinfo.ParentGuid
                                      INNER JOIN bt000 bt
                                              ON bu.TypeGUID = bt.[GUID]
                                      INNER JOIN #OrderTypesTbl AS otbl
                                              ON bt.[GUID] = otbl.[TYPE]
                               WHERE  bt.[TYPE] = 5
                                      AND oinfo.Finished = 0
                                      AND oinfo.Add1 = 0)
                  AND ( ( @Store = 0x0 )
                         OR ( ( bi.biStorePtr IN (SELECT [Number]
                                                  FROM   #Stores) )
                              AND ( @Store <> 0x0 ) ) )
           UNION ALL
           -- Achieved Part 
           SELECT vbi.biMatPtr          AS mtGuid,
                  vbi.biStorePtr        AS stGUID,
                  0                     AS OrderedQtySum,
                  ( ori.Qty / ( CASE @Unit
                                  WHEN 1 THEN 1
                                  WHEN 2 THEN ISNULL(CASE vbi.[mtUnit2Fact]
                                                       WHEN 0 THEN 1
                                                       ELSE vbi.[mtUnit2Fact]
                                                     END, 1)
                                  WHEN 3 THEN ISNULL(CASE vbi.[mtUnit3Fact]
                                                       WHEN 0 THEN 1
                                                       ELSE vbi.[mtUnit3Fact]
                                                     END, 1)
                                  ELSE ISNULL(CASE vbi.[mtDefUnitFact]
                                                WHEN 0 THEN 1
                                                ELSE vbi.[mtDefUnitFact]
                                              END, 1)
                                END ) ) AS AchievedQtySum
           FROM   ori000 ori
                  INNER JOIN (SELECT [GUID]
                              FROM   bu000
                              WHERE  TypeGuid IN (SELECT bt.[GUID]
                                                  FROM   bt000 AS bt
                                                         INNER JOIN #OrderTypesTbl AS otbl
                                                                 ON bt.[GUID] = otbl.[TYPE]
                                                  WHERE  bt.[TYPE] = 5)) bu
                          ON bu.[GUID] = ori.POGUID
                  INNER JOIN vwExtended_bi vbi
                          ON vbi.biGUID = ori.POIGUID
                  RIGHT JOIN vwSt st
                          ON vbi.biStorePtr = st.[stGUID]
           WHERE  ori.BuGuid <> 0x0
                  AND TypeGuid IN (SELECT [GUID]
                                   FROM   oit000
                                   WHERE  operation = 1)
                  AND ( ( @Store = 0x0 )
                         OR ( ( vbi.biStorePtr IN (SELECT [Number]
                                                   FROM   #Stores) )
                              AND ( @Store <> 0x0 ) ) )
            UNION ALL
            SELECT mt.mtGUID,
                   stGUID,
                   0 AS OrderedQtySum,
                   0 AS AchievedQtySum
            FROM   vwMt mt
                   JOIN vwSt st
                     ON ( st.stGUID <> 0x0 )
                        AND ( mt.mtGUID <> 0x0 )) sls
    GROUP  BY mtGuid,
              stGUID

    --select '#Sales', * from #Sales
    -- Purchase
    SELECT mtGuid,
           stGUID,
           0                                                                        AS StockQty,
           0                                                                        AS IsStockEmpty,
           0                                                                        AS IsStockBalaced,
           0                                                                        AS InQty,
           0                                                                        AS OutQty,
           0                                                                        AS SalesOrdered,
           0                                                                        AS SalesAchieved,
           0                                                                        AS SalesRemainder,
           Sum(ISNULL(prch.OrderedQtySum, 0))                                       AS PurchaseOrdered,
           Sum(ISNULL(prch.AchievedQtySum, 0))                                      AS PurchaseAchieved,
           Sum(ISNULL(prch.OrderedQtySum, 0)) - Sum(ISNULL(prch.AchievedQtySum, 0)) AS PurchaseRemainder
    INTO   #Purchase
    FROM   (SELECT bi.biMatPtr            AS mtGuid,
                   bi.biStorePtr          AS stGUID,
                   ( bi.biQty / ( CASE @Unit
                                    WHEN 1 THEN 1
                                    WHEN 2 THEN ISNULL(CASE bi.[mtUnit2Fact]
                                                         WHEN 0 THEN 1
                                                         ELSE bi.[mtUnit2Fact]
                                                       END, 1)
                                    WHEN 3 THEN ISNULL(CASE bi.[mtUnit3Fact]
                                                         WHEN 0 THEN 1
                                                         ELSE bi.[mtUnit3Fact]
                                                       END, 1)
                                    ELSE ISNULL(CASE bi.[mtDefUnitFact]
                                                  WHEN 0 THEN 1
                                                  ELSE bi.[mtDefUnitFact]
                                                END, 1)
                                  END ) ) AS OrderedQtySum,
                   0                      AS AchievedQtySum
            FROM   vwExtended_bi bi
            -- no need to join with ori000 to know ordered quantity 
            WHERE  [buGUID] IN (SELECT bu.[GUID]
                                FROM   bu000 bu
                                       INNER JOIN ORADDINFO000 oinfo
                                               ON bu.[GUID] = oinfo.ParentGuid
                                       INNER JOIN bt000 bt
                                               ON bu.TypeGUID = bt.[GUID]
                                       INNER JOIN #OrderTypesTbl AS otbl
                                               ON bt.[GUID] = otbl.[TYPE]
                                WHERE  bt.[TYPE] = 6
                                       AND oinfo.Finished = 0
                                       AND oinfo.Add1 = 0)
                   AND ( ( @Store = 0x0 )
                          OR ( ( bi.biStorePtr IN (SELECT [Number]
                                                   FROM   #Stores) )
                               AND ( @Store <> 0x0 ) ) )
            UNION ALL
            -- Achieved Part 
            SELECT vbi.biMatPtr          AS mtGuid,
                   vbi.biStorePtr        AS stGUID,
                   0                     AS OrderedQtySum,
                   ( ori.Qty / ( CASE @Unit
                                   WHEN 1 THEN 1
                                   WHEN 2 THEN ISNULL(CASE vbi.[mtUnit2Fact]
                                                        WHEN 0 THEN 1
                                                        ELSE vbi.[mtUnit2Fact]
                                                      END, 1)
                                   WHEN 3 THEN ISNULL(CASE vbi.[mtUnit3Fact]
                                                        WHEN 0 THEN 1
                                                        ELSE vbi.[mtUnit3Fact]
                                                      END, 1)
                                   ELSE ISNULL(CASE vbi.[mtDefUnitFact]
                                                 WHEN 0 THEN 1
                                                 ELSE vbi.[mtDefUnitFact]
                                               END, 1)
                                 END ) ) AS AchievedQtySum
            FROM   ori000 ori
                   INNER JOIN (SELECT [GUID]
                               FROM   bu000
                               WHERE  TypeGuid IN (SELECT bt.[GUID]
                                                   FROM   bt000 AS bt
                                                          INNER JOIN #OrderTypesTbl AS otbl
                                                                  ON bt.[GUID] = otbl.[TYPE]
                                                   WHERE  bt.[TYPE] = 6)) bu
                           ON bu.[GUID] = ori.POGUID
                   INNER JOIN vwExtended_bi vbi
                           ON vbi.biGUID = ori.POIGUID
            WHERE  ori.BuGuid <> 0x0
                   AND TypeGuid IN (SELECT [GUID]
                                    FROM   oit000
                                    WHERE  operation = 1)
                   AND ( ( @Store = 0x0 )
                          OR ( ( vbi.biStorePtr IN (SELECT [Number]
                                                    FROM   #Stores) )
                               AND ( @Store <> 0x0 ) ) )
            UNION ALL
            SELECT mt.mtGUID,
                   stGUID,
                   0 AS OrderedQtySum,
                   0 AS AchievedQtySum
            FROM   vwMt mt
                   JOIN vwSt st
                     ON ( st.stGUID <> 0x0 )
                        AND ( mt.mtGUID <> 0x0 )) prch
    GROUP  BY mtGuid,
              stGUID

    --select '#Purchase', * from #Purchase
    --//////////////////////////////////
    SELECT mt.mtGUID,
           ISNULL(YYY.stGUID, 0x00)                                                                   AS stGUID,
           ISNULL(st.Name,CAST('' AS NVARCHAR(250)))	                                              AS stName,
           mt.mtName                                                                                  AS MatName,
           mt.mtLatinName                                                                             AS MatLatinName,
           mt.mtCode                                                                                  AS MatCode,
           @Unit                                                                                      AS MatUnit,
           ( CASE @Unit
               WHEN 1 THEN mt.mtUnity
               WHEN 2 THEN mt.mtUnit2
               WHEN 3 THEN mt.mtUnit3
               ELSE mt.mtDefUnitName
             END )                                                                                    AS MatUnity,
           ( CASE @Unit
               WHEN 1 THEN 1
               WHEN 2 THEN mt.mtUnit2Fact
               WHEN 3 THEN mt.mtUnit3Fact
               ELSE mt.mtDefUnitFact
             END )                                                                                    AS MatUnityFactor,
           gr.grGUID                                                                                  AS GroupGUID,
           gr.grName                                                                                  AS GroupName,
           gr.grCode                                                                                  AS GroupCode,
           ( mt.mtHigh ) / ( CASE @Unit
                               WHEN 1 THEN 1
                               WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                    WHEN 0 THEN 1
                                                    ELSE mt.[mtUnit2Fact]
                                                  END, 1)
                               WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                    WHEN 0 THEN 1
                                                    ELSE mt.[mtUnit3Fact]
                                                  END, 1)
                               ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                             WHEN 0 THEN 1
                                             ELSE mt.[mtDefUnitFact]
                                           END, 1)
                             END )                                                                    AS High,
           ( mt.mtLow ) / ( CASE @Unit
                              WHEN 1 THEN 1
                              WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                   WHEN 0 THEN 1
                                                   ELSE mt.[mtUnit2Fact]
                                                 END, 1)
                              WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                   WHEN 0 THEN 1
                                                   ELSE mt.[mtUnit3Fact]
                                                 END, 1)
                              ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                            WHEN 0 THEN 1
                                            ELSE mt.[mtDefUnitFact]
                                          END, 1)
                            END )                                                                     AS Low,
           ( mt.mtOrder ) / ( CASE @Unit
                                WHEN 1 THEN 1
                                WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                     WHEN 0 THEN 1
                                                     ELSE mt.[mtUnit2Fact]
                                                   END, 1)
                                WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                     WHEN 0 THEN 1
                                                     ELSE mt.[mtUnit3Fact]
                                                   END, 1)
                                ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                              WHEN 0 THEN 1
                                              ELSE mt.[mtDefUnitFact]
                                            END, 1)
                              END )                                                                   AS OrderLimit,
           Sum(ISNULL(SalesOrdered, 0))                                                               AS SalesOrdered,
           Sum(ISNULL(SalesRemainder, 0))                                                             AS SalesRemainder,
           Sum(ISNULL(PurchaseOrdered, 0))                                                            AS PurchaseOrdered,
           Sum(ISNULL(PurchaseRemainder, 0))                                                          AS PurchaseRemainder,
           Sum(ISNULL(PurchaseRemainder, 0) - ISNULL(SalesRemainder, 0))                              AS OrdersNet,
           ( CASE
               WHEN Sum(ISNULL(SalesOrdered, 0)) = 0
                    AND Sum(ISNULL(PurchaseOrdered, 0)) = 0 THEN 1
               ELSE 0
             END )                                                                                    AS IsOrdersEmpty,
           ( CASE
               WHEN ( Sum(ISNULL(SalesRemainder, 0)) - Sum(ISNULL(PurchaseRemainder, 0)) = 0
                      AND Sum(ISNULL(SalesRemainder, 0)) <> 0
                      AND Sum(ISNULL(PurchaseRemainder, 0)) <> 0 )
                     OR ( Sum(ISNULL(SalesOrdered, 0)) = 0
                          AND Sum(ISNULL(PurchaseOrdered, 0)) = 0 ) THEN 1
               ELSE 0
             END )                                                                                    AS IsOrdersBalanced,
           Sum(StockQty / ( CASE @Unit
                              WHEN 1 THEN 1
                              WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                   WHEN 0 THEN 1
                                                   ELSE mt.[mtUnit2Fact]
                                                 END, 1)
                              WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                   WHEN 0 THEN 1
                                                   ELSE mt.[mtUnit3Fact]
                                                 END, 1)
                              ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                            WHEN 0 THEN 1
                                            ELSE mt.[mtDefUnitFact]
                                          END, 1)
                            END ))                                                                    AS StockQty,
           Sum(IsStockEmpty)                                                                          AS IsStockEmpty,
           Sum(IsStockBalanced)                                                                       AS IsStockBalanced,
           Sum(InQty / ( CASE @Unit
                           WHEN 1 THEN 1
                           WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                WHEN 0 THEN 1
                                                ELSE mt.[mtUnit2Fact]
                                              END, 1)
                           WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                WHEN 0 THEN 1
                                                ELSE mt.[mtUnit3Fact]
                                              END, 1)
                           ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                         WHEN 0 THEN 1
                                         ELSE mt.[mtDefUnitFact]
                                       END, 1)
                         END ))                                                                       AS InQty,
           Sum(OutQty / ( CASE @Unit
                            WHEN 1 THEN 1
                            WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                 WHEN 0 THEN 1
                                                 ELSE mt.[mtUnit2Fact]
                                               END, 1)
                            WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                 WHEN 0 THEN 1
                                                 ELSE mt.[mtUnit3Fact]
                                               END, 1)
                            ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                          WHEN 0 THEN 1
                                          ELSE mt.[mtDefUnitFact]
                                        END, 1)
                          END ))                                                                      AS OutQty,
           Sum(( ISNULL(PurchaseRemainder, 0) - ISNULL(SalesRemainder, 0) ) + ( StockQty / ( CASE @Unit
                                                                                               WHEN 1 THEN 1
                                                                                               WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                                                                                    WHEN 0 THEN 1
                                                                                                                    ELSE mt.[mtUnit2Fact]
                                                                                                                  END, 1)
                                                                                               WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                                                                                    WHEN 0 THEN 1
                                                                                                                    ELSE mt.[mtUnit3Fact]
                                                                                                                  END, 1)
                                                                                               ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                                                                                             WHEN 0 THEN 1
                                                                                                             ELSE mt.[mtDefUnitFact]
                                                                                                           END, 1)
                                                                                             END ) )) AS StockNet,
           ( CASE
               WHEN Sum(ISNULL(SalesOrdered, 0)) <> 0
                     OR Sum(ISNULL(PurchaseOrdered, 0)) <> 0 THEN 1
               ELSE 0
             END )                                                                                    AS IsOrderedMaterial
    INTO   #Result
    FROM   vwMt AS mt
           INNER JOIN dbo.vwGr AS gr
                   ON mt.mtGroup = gr.grGUID
           LEFT JOIN (SELECT *
                      FROM   #Stock stk
                      UNION ALL
                      SELECT *
                      FROM   #Sales sls
                      UNION ALL
                      SELECT *
                      FROM   #Purchase prch) YYY
                  ON ( YYY.mtGUID = mt.mtGUID )
           LEFT JOIN vbSt AS st
                  ON YYY.stGUID = st.[GUID]
    WHERE  st.Kind = 0
    GROUP  BY mt.mtGUID,
              YYY.stGUID,
              st.Name,
              mt.mtName,
              mt.mtLatinName,
              mt.mtCode,
              ( CASE @Unit
                  WHEN 1 THEN mt.mtUnity
                  WHEN 2 THEN mt.mtUnit2
                  WHEN 3 THEN mt.mtUnit3
                  ELSE mt.mtDefUnitName
                END ),
              ( CASE @Unit
                  WHEN 1 THEN 1
                  WHEN 2 THEN mt.mtUnit2Fact
                  WHEN 3 THEN mt.mtUnit3Fact
                  ELSE mt.mtDefUnitFact
                END ),
              gr.grGUID,
              gr.grName,
              gr.grCode,
              ( mt.mtHigh ) / ( CASE @Unit
                                  WHEN 1 THEN 1
                                  WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                       WHEN 0 THEN 1
                                                       ELSE mt.[mtUnit2Fact]
                                                     END, 1)
                                  WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                       WHEN 0 THEN 1
                                                       ELSE mt.[mtUnit3Fact]
                                                     END, 1)
                                  ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                                WHEN 0 THEN 1
                                                ELSE mt.[mtDefUnitFact]
                                              END, 1)
                                END ),
              ( mt.mtLow ) / ( CASE @Unit
                                 WHEN 1 THEN 1
                                 WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                      WHEN 0 THEN 1
                                                      ELSE mt.[mtUnit2Fact]
                                                    END, 1)
                                 WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                      WHEN 0 THEN 1
                                                      ELSE mt.[mtUnit3Fact]
                                                    END, 1)
                                 ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                               WHEN 0 THEN 1
                                               ELSE mt.[mtDefUnitFact]
                                             END, 1)
                               END ),
              ( mt.mtOrder ) / ( CASE @Unit
                                   WHEN 1 THEN 1
                                   WHEN 2 THEN ISNULL(CASE mt.[mtUnit2Fact]
                                                        WHEN 0 THEN 1
                                                        ELSE mt.[mtUnit2Fact]
                                                      END, 1)
                                   WHEN 3 THEN ISNULL(CASE mt.[mtUnit3Fact]
                                                        WHEN 0 THEN 1
                                                        ELSE mt.[mtUnit3Fact]
                                                      END, 1)
                                   ELSE ISNULL(CASE mt.[mtDefUnitFact]
                                                 WHEN 0 THEN 1
                                                 ELSE mt.[mtDefUnitFact]
                                               END, 1)
                                 END )
    HAVING ( YYY.stguid <> 0x00 )

    --select '#result', * from #result
    --++++++++++++++++++++++++++++

    IF ( @StoresDetails = 0 )
      BEGIN
          -- Data Grouping 
          SELECT r.mtGUID,
                 CONVERT(UNIQUEIDENTIFIER, 0x00) AS stGuid,
                 CAST ('' AS NVARCHAR(250))      AS stName,
                 MatName,
                 MatLatinName,
                 MatCode,
                 MatUnit,
                 MatUnity,
                 MatUnityFactor,
                 GroupGUID,
                 GroupName,
                 GroupCode,
                 High,
                 Low,
                 OrderLimit,
                 Sum(SalesOrdered)               AS SalesOrdered,
                 Sum(PurchaseOrdered)            AS PurchaseOrdered,
                 Sum(IsStockEmpty)               AS IsStockEmpty,
                 Sum(IsStockBalanced)            AS IsStockBalanced,
                 Sum(IsOrdersEmpty)              AS IsOrdersEmpty,
                 Sum(IsOrdersBalanced)           AS IsOrdersBalanced,
                 Sum(SalesRemainder)             AS SalesRemainder,
                 Sum(PurchaseRemainder)          AS PurchaseRemainder,
                 Sum(OrdersNet)                  AS OrdersNet,
                 Sum(StockQty)                   AS StockQty,
                 Sum(StockNet)                   AS StockNet,
                 Sum(InQty)                      AS InQty,
                 Sum(OutQty)                     AS OutQty,
                 ( CASE
                     WHEN Sum(IsOrderedMaterial) > 0 THEN 1
                     ELSE 2
                   END )                         AS IsOrderedMaterial,
                 Count(stGUID)                   AS StoresCount
          INTO   #RESULTx
          FROM   (SELECT *
                  FROM   #RESULT
                  WHERE  ( ( @Store = 0x0 )
                            OR ( ( @Store <> 0x0 )
                                 AND ( stGUID IN (SELECT [Number]
                                                  FROM   #Stores) ) ) )) r
          GROUP  BY r.mtGUID,
                    MatName,
                    MatLatinName,
                    MatCode,
                    MatUnit,
                    MatUnity,
                    MatUnityFactor,
                    GroupGUID,
                    GroupName,
                    GroupCode,
                    High,
                    Low,
                    OrderLimit

          --select '#RESULTx', * FROM #RESULTx
          --+++++++++++++++++++
          -- Data Filtering
          SELECT r.mtGUID,
                 stGUID,
                 stName,
                 MatName,
                 MatLatinName,
                 MatCode,
                 MatUnit,
                 MatUnity,
                 MatUnityFactor,
                 GroupGUID,
                 GroupName,
                 GroupCode,
                 High,
                 Low,
                 OrderLimit,
                 SalesRemainder,
                 PurchaseRemainder,
                 OrdersNet,
                 StockQty,
                 StockNet,
                 CASE
                   WHEN PurchaseOrdered = 0
                        AND SalesOrdered = 0
                        AND IsStockEmpty = StoresCount THEN 1
                   ELSE 0
                 END AS IsEmpty,
                 CASE
                   WHEN SalesRemainder = 0
                        AND PurchaseRemainder = 0
                        AND ( PurchaseOrdered <> 0
                               OR SalesOrdered <> 0
                               OR IsStockEmpty <> StoresCount )
                        AND ( IsStockBalanced <> 0 ) THEN 1
                   ELSE 0
                 END AS IsBalanced
          INTO   #RESULTx2
          FROM   #RESULTx r
                 INNER JOIN vwMt mt
                         ON r.mtGuid = mt.mtGUID
          WHERE  ( ( @ReportOption = -1 ) -- for debug only: to show all rows
                    OR ( ( @ReportOption = 0 )
                         AND ( r.StockNet < mtHigh )
                         AND ( mtHigh <> 0 ) )
                    OR ( ( @ReportOption = 1 )
                         AND ( r.StockNet < mtOrder )
                         AND ( mtOrder <> 0 ) )
                    OR ( ( @ReportOption = 2 )
                         AND ( r.StockNet < mtLow )
                         AND ( mtLow <> 0 ) )
                    OR ( ( @ReportOption = 3 )
                         AND ( r.StockNet < @MinValue ) )
                    OR ( ( @ReportOption = 4 )
                         AND ( r.StockNet > mtHigh )
                         AND ( mtHigh <> 0 ) )
                    OR ( ( @ReportOption = 5 )
                         AND ( r.StockNet > @MinValue ) )
                    OR ( ( @ReportOption = 6 )
                         AND ( r.StockNet >= @MinValue
                               AND r.StockNet <= @MaxValue ) ) )
                 AND ( ( @IncludeEmptyMaterials = 1 AND ( mt.mtHasSegments <> 1 ))
                        OR ( ( @IncludeEmptyMaterials = 0 )
                             AND ( PurchaseOrdered <> 0
                                    OR SalesOrdered <> 0
                                    OR InQty <> 0
                                    OR OutQty <> 0 ) ) )
                 AND ( ( @IncludeBalancedMaterials = 1 )
                        OR
                       -- For clarification ((@IncludeBalancedMaterials = 0) AND (IsBalanced = 0))
                       ( ( @IncludeBalancedMaterials = 0 )
                         AND ( CASE
                                 WHEN SalesRemainder = 0
                                      AND PurchaseRemainder = 0
                                      AND ( PurchaseOrdered <> 0
                                             OR SalesOrdered <> 0
                                             OR IsStockEmpty <> StoresCount )
                                      AND ( IsStockBalanced <> 0 ) THEN 1
                                 ELSE 0
                               END = 0 ) ) )
                 AND ( ( @OnlyOrderedMaterials = 0 )
                        OR ( ( @OnlyOrderedMaterials = 1 )
                             AND ( mt.mtGUID IN (SELECT mtGUID
                                                 FROM   #OnlyOrderedMats) ) ) )
                 AND ( ( @MaterialCondition = 0x0 )
                        OR ( ( @MaterialCondition <> 0x0 )
                             AND ( mt.mtGUID IN (SELECT mtNumber
                                                 FROM   #Mat) ) ) )
                 AND ( ( @Group = 0x0 )
                        OR ( ( @Group <> 0x0 )
                             AND ( GroupGUID IN (SELECT [GUID]
                                                 FROM   #Groups) )
                              OR ( mt.mtGUID IN (SELECT mtNumber
                                                 FROM   #Mat) ) ) )

          --AND
          --((@Store = 0x0) OR ((@Store <> 0x0) AND (stGUID IN (Select [Number] FROM #Stores))))
          -- Ordering Data 
         SELECT * 
		   FROM #RESULTx2 r
		  ORDER BY r.MatCode
                                
      END
    ELSE --(@StoresDetails = 1)
      BEGIN
          -- for sorting to be easy as demanded
          UPDATE #result
          SET    IsOrderedMaterial = 2
          WHERE  IsOrderedMaterial = 0

          -- Data Filtering
          SELECT r.*,
                 ( CASE
                     WHEN ( r.IsStockEmpty = 1
                            AND r.IsOrdersEmpty = 1 ) THEN 1
                     ELSE 0
                   END ) AS IsEmpty,
                 ( CASE
                     WHEN ( r.IsStockBalanced = 1
                            AND r.IsOrdersBalanced = 1 ) THEN 1
                     ELSE 0
                   END ) AS IsBalanced
          INTO   #RESULTy
          FROM   #RESULT r
                 INNER JOIN vwMt mt
                         ON r.mtGuid = mt.mtGUID
          WHERE  ( ( @ReportOption = -1 ) -- for debug only: to show all rows
                    OR ( ( @ReportOption = 0 )
                         AND ( r.StockNet < mtHigh )
                         AND ( mtHigh <> 0 ) )
                    OR ( ( @ReportOption = 1 )
                         AND ( r.StockNet < mtOrder )
                         AND ( mtOrder <> 0 ) )
                    OR ( ( @ReportOption = 2 )
                         AND ( r.StockNet < mtLow )
                         AND ( mtLow <> 0 ) )
                    OR ( ( @ReportOption = 3 )
                         AND ( r.StockNet < @MinValue ) )
                    OR ( ( @ReportOption = 4 )
                         AND ( r.StockNet > mtHigh )
                         AND ( mtHigh <> 0 ) )
                    OR ( ( @ReportOption = 5 )
                         AND ( r.StockNet > @MinValue ) )
                    OR ( ( @ReportOption = 6 )
                         AND ( r.StockNet >= @MinValue
                               AND r.StockNet <= @MaxValue ) ) )
                 AND ( ( @IncludeEmptyMaterials = 1 AND ( mt.mtHasSegments <> 1 ))
                        OR ( ( @IncludeEmptyMaterials = 0 )
                             AND ( IsStockEmpty = 0
                                    OR IsOrdersEmpty = 0 ) ) )
                 AND ( ( @IncludeBalancedMaterials = 1  )
                        OR ( ( @IncludeBalancedMaterials = 0 )
                             AND ( IsStockBalanced = 0
                                    OR IsOrdersBalanced = 0 ) ) )
                 AND ( ( @OnlyOrderedMaterials = 0 )
                        OR ( ( @OnlyOrderedMaterials = 1 )
                             AND ( IsOrderedMaterial = 1 )
                             AND ( mt.mtGUID IN (SELECT mtGUID
                                                 FROM   #OnlyOrderedMats) ) ) )
                 AND ( ( @MaterialCondition = 0x0 )
                        OR ( ( @MaterialCondition <> 0x0 )
                             AND ( mt.mtGUID IN (SELECT mtNumber
                                                 FROM   #Mat) ) ) )
                 AND ( ( @Group = 0x0 )
                        OR ( ( @Group <> 0x0 )
                             AND ( GroupGUID IN (SELECT [GUID]
                                                 FROM   #Groups) )
                              OR ( mt.mtGUID IN (SELECT mtNumber
                                                 FROM   #Mat) ) ) )
                 AND ( ( @Store = 0x0 )
                        OR ( ( @Store <> 0x0 )
                             AND ( stGUID IN (SELECT [Number]
                                              FROM   #Stores) ) ) )

          -- Ordering Data
           SELECT * 
		     FROM #RESULTy r
			ORDER BY  r.MatCode, r.IsOrderedMaterial, r.stName 
                              
      END
#############################################################################
#END