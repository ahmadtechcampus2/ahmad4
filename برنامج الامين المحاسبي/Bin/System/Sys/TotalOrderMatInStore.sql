###########################################################################
CREATE PROCEDURE TotalOrderMatInStore 
	@MatGuid         UNIQUEIDENTIFIER = 0x00,
    @StoreGuid       UNIQUEIDENTIFIER = 0x00,
    @CostGuid        UNIQUEIDENTIFIER = 0x00,
    @GroupGuid       UNIQUEIDENTIFIER = 0x00,
    @StartDate       DATETIME = '1/1/1980',
    @EndDate         DATETIME = '1/1/1980',
    @ReportSource    UNIQUEIDENTIFIER = 0x00,
    @UseUnit         INT = 1,
    @DetailsStores   BIT = 0,
    @ShowMinLevel    BIT = 0,
    @ShowMaxLevel    BIT = 0,
    @ShowOrderLevel  BIT = 0,
    @MatCond         UNIQUEIDENTIFIER = 0x00,
    @CustCond        UNIQUEIDENTIFIER = 0x00,
    @OrderCond       UNIQUEIDENTIFIER = 0x00,
    @MatFldsFlag     BIGINT = 0,
    @MatCFlds        NVARCHAR (max) = '',
    @Collect1        INT = 0,
    @Collect2        INT = 0,
    @Collect3        INT = 0,
    @ShowAvailable   BIT = 0,
    @ShowBalanced    BIT = 0,
    @ShowUnavailable BIT = 0,
    @ShowUnordered   BIT = 0
AS
    SET NOCOUNT ON
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();

    CREATE TABLE [#SecViol]
      (
         [Type] INT,
         [Cnt]  INT
      )

    CREATE TABLE [#MatTbl]
      (
         [MatGUID]    UNIQUEIDENTIFIER,
         [mtSecurity] INT
      )

    CREATE TABLE [#StoreTbl]
      (
         [StoreGUID] UNIQUEIDENTIFIER,
         [Security]  INT
      )

    CREATE TABLE [#BillsTypesTbl]
      (
         [TypeGuid]              UNIQUEIDENTIFIER,
         [UserSecurity]          INT,
         [UserReadPriceSecurity] INT
      )

    CREATE TABLE [#OrderedTypesTbl]
      (
         [TypeGuid]              UNIQUEIDENTIFIER,
         [UserSecurity]          INT,
         [UserReadPriceSecurity] INT,
         [Type]                  INT
      )

    CREATE TABLE [#CostTbl]
      (
         [CostGUID] UNIQUEIDENTIFIER,
         [Security] INT
      )

    CREATE TABLE #CustTbl
      (
         Guid       UNIQUEIDENTIFIER,
         [Security] [INT]
      )

    CREATE TABLE [#MatUnordered]
      (
         [MatGuid]    UNIQUEIDENTIFIER,
         [mtSecurity] INT
      )

    CREATE TABLE [#UnorderedTypesTbl]
      (
         [TypeGuid]              UNIQUEIDENTIFIER,
         [UserSecurity]          INT,
         [UserReadPriceSecurity] INT
      )

    -------------------------------------------------------------------     
    --  ���� �������� �� ������ ���� ��������    
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

    -------------------------------------------------------------------            
    INSERT INTO [#MatTbl]
    EXEC [prcGetMatsList]
      @MatGUID,
      @GroupGUID,
      -1,
      @MatCond

    INSERT INTO [#StoreTbl]
    EXEC [prcGetStoresList]
      @StoreGUID

    INSERT INTO [#BillsTypesTbl]
    EXEC [prcGetBillsTypesList]
      @ReportSource

    INSERT INTO [#OrderedTypesTbl]
    SELECT btt.*,
           bt.type
    FROM   #BillsTypesTbl btt
           INNER JOIN bt000 bt
                   ON btt.TypeGuid = bt.Guid
    WHERE  bt.Type IN ( 5, 6 )

    --? should it be only (purchase / sales bt.type = 1) or any bills with bt.type other than orders (5,6) ????
    -- right here we select all bills that are not orders (5,6)
    INSERT INTO [#UnorderedTypesTbl]
    EXEC [prcGetBillsTypesList]

    DELETE FROM [#UnorderedTypesTbl]
    WHERE  TypeGuid IN (SELECT [Guid]
                        FROM   bt000
                        WHERE  [Type] IN ( 5, 6 ))

    INSERT INTO [#MatUnordered]
    SELECT DISTINCT bi.biMatPtr,
                    bi.mtSecurity
    FROM vwExtended_bi bi
         INNER JOIN #UnorderedTypesTbl uno
                   ON uno.TypeGuid = bi.buType
    WHERE  bi.biMatPtr NOT IN (SELECT bi.biMatPtr FROM vwExtended_bi bi INNER JOIN #OrderedTypesTbl uno ON uno.TypeGuid = bi.buType)

    INSERT INTO [#CostTbl]
    EXEC [prcGetCostsList] @CostGUID

    INSERT INTO [#CustTbl] (Guid, [Security])
    EXEC [prcGetCustsList] 0x00, 0X00, @CustCond

    IF @costGuid = 0x00
      INSERT INTO #CostTbl
      VALUES (0x00, 0)

    IF @CustCond = 0x00
      INSERT INTO #CustTbl
      VALUES(0x00, 0)

    IF @StoreGUID = 0x00
      INSERT INTO #StoreTbl
      VALUES     (0x00, 0)

    CREATE TABLE [#EndResult]
      (
         [MatGuid]       [UNIQUEIDENTIFIER],
         [Qty]           [FLOAT] DEFAULT 0,
         [Qty2]          [FLOAT] DEFAULT 0,
         [Qty3]          [FLOAT] DEFAULT 0,
         [mtUnity]       [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [mtUnit2]       [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [mtUnit3]       [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [mtDefUnitFact] [FLOAT],
         [mtName]        [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [mtCode]        [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [mtLatinName]   [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [mtUnit2Fact]   [FLOAT],
         [mtUnit3Fact]   [FLOAT],
         [mtDefUnitName] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [MtGroup]       [UNIQUEIDENTIFIER],
         [StoreGuid]     [UNIQUEIDENTIFIER],
         [High]          FLOAT DEFAULT 0,
         [Low]           FLOAT DEFAULT 0,
         [OrderLimit]    FLOAT DEFAULT 0
      )

    --Get Qtys  
    IF @DetailsStores = 1
      BEGIN
          CREATE TABLE [#MSQtys]
            (
               [MatGuid]   [UNIQUEIDENTIFIER],
               [Qty]       [FLOAT],
               [StoreGuid] [UNIQUEIDENTIFIER]
            )
      END
    ELSE --@DetailsStores = 0
      BEGIN
          CREATE TABLE [#MQtys]
            (
               [MatGuid] [UNIQUEIDENTIFIER],
               [Qty]     [FLOAT]
            )
      END

    -----------------------------------------------------------------------------------------    
    IF @DetailsStores = 0
      BEGIN
          SELECT mt.MatGuid,
                 ISNULL(bb.Qty, 0) AS Qty
          INTO   #inTotal
          FROM   #MatTbl AS mt
                 LEFT JOIN (SELECT bi.MatGuid,
                                   ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS Qty
                            FROM   bi000 AS bi
                                   INNER JOIN bu000 AS bu
                                           ON bi.ParentGuid = bu.Guid
                                   INNER JOIN bt000 AS bt
                                           ON bu.TypeGuid = bt.Guid
                            WHERE  ( bt.bIsInput = 1 )
                                   AND ( bt.[Type] NOT IN ( 5, 6 ) )
                                   AND ( bu.[IsPosted] = 1 )
                                   AND ( bu.[Date] <= @EndDate ) --����������� ��� / ��� �����  
                            GROUP  BY bi.MatGuid) AS bb
                        ON bb.MatGuid = mt.MatGuid

          -----------------------------------------------------------------------------------------    
          SELECT mt.MatGuid,
                 ISNULL(bb.Qty, 0) AS Qty
          INTO   #outTotal
          FROM   #MatTbl AS mt
                 LEFT JOIN (SELECT bi.MatGuid,
                                   ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS Qty
                            FROM   bi000 AS bi
                                   INNER JOIN bu000 AS bu
                                           ON bi.ParentGuid = bu.Guid
                                   INNER JOIN bt000 AS bt
                                           ON bu.TypeGuid = bt.Guid
                            WHERE  ( bt.bIsInput = 0 )
                                   AND ( bt.Type NOT IN ( 5, 6 ) )
                                   AND ( bu.[IsPosted] = 1 )
                                   AND ( bu.[Date] <= @EndDate ) --����������� ��� / ��� �����
                            GROUP  BY bi.MatGuid) AS bb
                        ON bb.MatGuid = mt.MatGuid

          -----------------------------------------------------------------------------------------	     
          INSERT INTO #MQtys
          SELECT inTotal.MatGuid,
                 ISNULL(inTotal.Qty, 0) - ISNULL(outTotal.Qty, 0)
          FROM   #inTotal AS inTotal
                 LEFT JOIN #outTotal AS outTotal
                        ON inTotal.MatGuid = outTotal.MatGuid

          --����� ������ ��� �������� ������ ������ ��� ������ ��� �������
          SELECT bi.MatGuid,
                 0 AS Qty
          INTO   #temp0
          FROM   bi000 AS bi
                 INNER JOIN bu000 AS bu
                         ON bi.ParentGuid = bu.Guid
                 INNER JOIN bt000 AS bt
                         ON bu.TypeGuid = bt.Guid
                 INNER JOIN #MatTbl AS mt
                         ON bi.MatGuid = mt.MatGuid
          WHERE  ( bt.Type IN ( 5, 6 ) )
                 AND ( bu.[Date] <= @EndDate ) --����������� ��� / ��� �����

          SELECT DISTINCT *
          INTO   #temp1
          FROM   #temp0 t0
          WHERE  (SELECT Count(*)
                  FROM   #MQtys
                  WHERE  t0.MatGuid = MatGuid) = 0

          INSERT INTO #MQtys
          SELECT *
          FROM   #temp1
      END
    ELSE -- @DetailsStores = 1   
      BEGIN
          SELECT mt.MatGuid,
                 ISNULL(bb.Qty, 0)          AS Qty,
                 ISNULL(bb.StoreGuid, 0x00) AS StoreGuid
          INTO   #inDetailed
          FROM   #MatTbl AS mt
                 LEFT JOIN (SELECT bi.MatGuid,
                                   ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS Qty,
                                   bi.StoreGuid
                            FROM   bi000 AS bi
                                   INNER JOIN bu000 AS bu
                                           ON bi.ParentGuid = bu.Guid
                                   INNER JOIN bt000 AS bt
                                           ON bu.TypeGuid = bt.Guid
                                   INNER JOIN #StoreTbl AS st
                                           ON st.StoreGuid = bi.StoreGuid
                            WHERE  ( bt.bIsInput = 1 )
                                   AND ( bt.Type NOT IN ( 5, 6 ) )
                                   AND ( bu.[IsPosted] = 1 )
                                   AND ( bu.[Date] <= @EndDate ) --����������� ��� / ��� �����
                            GROUP  BY bi.MatGuid,
                                      bi.StoreGuid) AS bb
                        ON bb.MatGuid = mt.MatGuid

          -----------------------------------------------------------------------------------------    
          SELECT mt.MatGuid,
                 ISNULL(bb.Qty, 0)          AS Qty,
                 ISNULL(bb.StoreGuid, 0x00) AS StoreGuid
          INTO   #outDetailed
          FROM   #MatTbl AS mt
                 LEFT JOIN (SELECT bi.MatGuid,
                                   ( Sum(bi.Qty) + Sum(bi.BonusQnt) ) AS Qty,
                                   bi.StoreGuid
                            FROM   bi000 AS bi
                                   INNER JOIN bu000 AS bu
                                           ON bi.ParentGuid = bu.Guid
                                   INNER JOIN bt000 AS bt
                                           ON bu.TypeGuid = bt.Guid
                                   INNER JOIN #StoreTbl AS st
                                           ON st.StoreGuid = bi.StoreGuid
                            WHERE  ( bt.bIsInput = 0 )
                                   AND ( bt.Type NOT IN ( 5, 6 ) )
                                   AND ( bu.[IsPosted] = 1 )
                                   AND ( bu.[Date] <= @EndDate ) --����������� ��� / ��� �����
                            GROUP  BY bi.MatGuid,
                                      bi.StoreGuid) AS bb
                        ON bb.MatGuid = mt.MatGuid

          -----------------------------------------------------------------------------------------	     
          INSERT INTO #MSQtys
          SELECT inDetailed.MatGuid,
                 ISNULL(inDetailed.Qty, 0) - ISNULL(outDetailed.Qty, 0),
                 ( CASE
                     WHEN ( outDetailed.StoreGuid = 0x00
                            AND inDetailed.StoreGuid = 0x00 ) THEN 0x00
                     ELSE
                       CASE
                         WHEN outDetailed.StoreGuid <> 0x00 THEN outDetailed.StoreGuid
                         ELSE inDetailed.StoreGuid
                       END
                   END ) AS StoreGuid
          FROM   #inDetailed AS inDetailed
                 LEFT JOIN #outDetailed AS outDetailed
                        ON inDetailed.MatGuid = outDetailed.MatGuid
                           AND inDetailed.StoreGuid = outDetailed.StoreGuid

          SELECT bi.MatGuid,
                 0 AS Qty,
                 bi.StoreGuid
          INTO   #tmp0
          FROM   bi000 AS bi
                 INNER JOIN bu000 AS bu
                         ON bi.ParentGuid = bu.Guid
                 INNER JOIN bt000 AS bt
                         ON bu.TypeGuid = bt.Guid
                 INNER JOIN #MatTbl AS mt
                         ON bi.MatGuid = mt.MatGuid
                 INNER JOIN #StoreTbl AS st
                         ON st.StoreGuid = bi.StoreGuid
          WHERE  ( bt.Type IN ( 5, 6 ) )
                 AND ( bu.[Date] <= @EndDate ) --����������� ��� / ��� �����

          SELECT DISTINCT *
          INTO   #tmp1
          FROM   #tmp0 t0
          WHERE  (SELECT Count(*)
                  FROM   #MSQtys
                  WHERE  t0.MatGuid = MatGuid
                         AND t0.StoreGuid = StoreGuid) = 0

          INSERT INTO #MSQtys
          SELECT *
          FROM   #tmp1
      END

    -----------------------------------------------------------------------------------------    
    INSERT INTO [#EndResult]
    SELECT DISTINCT mt.guid,
                    0,
                    0,
                    0,
                    [Unity],
                    [Unit2],
                    [Unit3],
                    CASE @UseUnit
                      WHEN 1 THEN 1
                      WHEN 2 THEN [Unit2Fact]
                      WHEN 3 THEN [Unit3Fact]
                      ELSE ( CASE DefUnit
                               WHEN 2 THEN [Unit2Fact]
                               WHEN 3 THEN [Unit3Fact]
                               ELSE 1
                             END )
                    END,
                   (CASE @Lang WHEN 0 THEN mt.[Name] ELSE (CASE mt.[LatinName] WHEN N'' THEN mt.[Name] ELSE mt.[LatinName] END) END ),
                    mt.[Code],
                    mt.[LatinName],
                    mt.[Unit2Fact],
                    mt.[Unit3Fact],
                    CASE @UseUnit
                      WHEN 1 THEN [Unity]
                      WHEN 2 THEN [Unit2]
                      WHEN 3 THEN [Unit3]
                      ELSE
                        CASE DefUnit
                          WHEN 2 THEN [Unit2]
                          WHEN 3 THEN [Unit3]
                          ELSE Unity
                        END
                    END,
                    [GroupGuid],
                    0x00,
                    high,
                    Low,
                    OrderLimit
    FROM   vwExtended_bi AS vw
           INNER JOIN #MatTbl
                   ON [vw].[biMatptr] = #MatTbl.[MatGUID]
           INNER JOIN mt000 AS mt
                   ON #MatTbl.[MatGUID] = mt.guid
           INNER JOIN #CostTbl AS co
                   ON co.CostGUID = vw.buCostptr
           INNER JOIN #StoreTbl AS st
                   ON st.StoreGUID = vw.biStorePtr
    ORDER  BY mt.Guid

    -----------------------------------------------------------------------------------------     
    -- ���� ������ ������� �� �������   
    IF @DetailsStores = 0
      BEGIN
          SELECT bi.MatGuid,
                 Sum(bi.Qty)      AS Qty,
                 Sum(bi.BonusQnt) AS BonusQty,
                 bt.type          AS OrderType
          INTO   #Ordered
          FROM   bi000 AS bi
                 INNER JOIN bu000 AS bu
                         ON bi.parentguid = bu.guid
                 INNER JOIN #MatTbl AS mt
                         ON bi.MatGuid = mt.MatGuid
                 INNER JOIN #OrderedTypesTbl AS bt
                         ON bt.TypeGuid = bu.TypeGuid
                 INNER JOIN #OrderCond OrCond
                         ON OrCond.OrderGuid = bu.Guid
                 INNER JOIN #CustTbl cu
                         ON bu.CustGuid = cu.Guid
                 INNER JOIN OrAddInfo000 info
                         ON bu.guid = info.ParentGuid
          WHERE  bu.[Date] BETWEEN @StartDate AND @EndDate
                 AND info.finished = 0
                 AND info.add1 = '0'
          GROUP  BY bi.MatGuid,
                    bt.type
          ORDER  BY bi.MatGuid
      END
    ELSE -- @DetailsStores = 1 
      BEGIN
          -- ���� ������ ������� �� ������� ��� ����������        
          SELECT bi.MatGuid,
                 Sum(bi.Qty)      AS Qty,
                 Sum(bi.BonusQnt) AS BonusQty,
                 bt.type          AS OrderType,
                 bi.StoreGuid
          INTO   #OrderedStore
          FROM   bi000 AS bi
                 INNER JOIN bu000 AS bu
                         ON bi.parentguid = bu.guid
                 INNER JOIN #MatTbl AS mt
                         ON bi.MatGuid = mt.MatGuid
                 INNER JOIN #OrderedTypesTbl AS bt
                         ON bt.TypeGuid = bu.TypeGuid
                 INNER JOIN #OrderCond OrCond
                         ON OrCond.OrderGuid = bu.Guid
                 INNER JOIN #CustTbl cu
                         ON bu.CustGuid = cu.Guid
                 INNER JOIN #StoreTbl st
                         ON st.StoreGUID = bi.StoreGuid
                 INNER JOIN OrAddInfo000 info
                         ON bu.guid = info.ParentGuid
          WHERE  bu.[Date] BETWEEN @StartDate AND @EndDate
                 AND info.finished = 0
                 AND info.add1 = '0'
          GROUP  BY bi.MatGuid,
                    bt.type,
                    bi.StoreGuid
          ORDER  BY bi.MatGuid,
                    bi.StoreGuid,
                    bt.type
      END

    -----------------------------------------------------------------------------------------     
    -- ���� ������ �������� �� �������       
    IF @DetailsStores = 0
      BEGIN
          SELECT bi.MatGuid,
                 Sum(CASE
                       WHEN oit.Operation = 1
                            AND ori.BuGuid <> 0x0
                            AND oit.QtyStageCompleted <> 0 THEN ori.Qty
                       ELSE 0
                     END)                AS Qty,
                 Sum(ori.BonusPostedQty) AS BonusPostedQty,
                 bt.type                 AS OrderType
          INTO   #retrieved
          FROM   ori000 AS ori
                 INNER JOIN oit000 AS oit
                         ON ori.typeguid = oit.guid
                 INNER JOIN bi000 AS bi
                         ON bi.guid = ori.poiguid
                 INNER JOIN bu000 AS bu
                         ON bu.guid = bi.parentguid
                 INNER JOIN #OrderedTypesTbl AS bt
                         ON bt.TypeGuid = bu.TypeGuid
                 INNER JOIN #MatTbl AS mt
                         ON mt.MatGuid = bi.MatGuid
                 INNER JOIN #OrderCond OrCond
                         ON OrCond.OrderGuid = bu.Guid
                 INNER JOIN #CustTbl cu
                         ON bu.CustGuid = cu.Guid
                 INNER JOIN OrAddInfo000 info
                         ON bu.guid = info.ParentGuid
          WHERE  ori.Qty > 0
                 AND ori.Date BETWEEN @StartDate AND @EndDate
                 AND info.finished = 0
                 AND info.add1 = '0'
          GROUP  BY bi.MatGuid,
                    bt.Type
          ORDER  BY bi.MatGuid
      END
    ELSE -- @DetailsStores = 1 
      BEGIN
          -- ���� ������ �������� �� ������� ��� ����������	
          SELECT bi.MatGuid,
                 Sum(CASE oit.Operation
                       WHEN 1 THEN ori.Qty
                       ELSE 0
                     END)                AS Qty,
                 Sum(ori.BonusPostedQty) AS BonusPostedQty,
                 bt.type                 AS OrderType,
                 bi.StoreGuid
          INTO   #retrievedStore
          FROM   ori000 AS ori
                 INNER JOIN oit000 AS oit
                         ON ori.typeguid = oit.guid
                 INNER JOIN bi000 AS bi
                         ON bi.guid = ori.poiguid
                 INNER JOIN bu000 AS bu
                         ON bu.guid = bi.parentguid
                 INNER JOIN #OrderedTypesTbl AS bt
                         ON bt.TypeGuid = bu.TypeGuid
                 INNER JOIN #MatTbl AS mt
                         ON mt.MatGuid = bi.MatGuid
                 INNER JOIN #OrderCond OrCond
                         ON OrCond.OrderGuid = bu.Guid
                 INNER JOIN #CustTbl cu
                         ON bu.CustGuid = cu.Guid
                 INNER JOIN #StoreTbl st
                         ON st.StoreGUID = bi.StoreGuid
                 INNER JOIN OrAddInfo000 info
                         ON bu.guid = info.ParentGuid
          WHERE  ori.Qty > 0
                 AND ori.Date BETWEEN @StartDate AND @EndDate
                 AND info.finished = 0
                 AND info.add1 = '0'
          GROUP  BY bi.MatGuid,
                    bt.Type,
                    bi.StoreGuid
          ORDER  BY bi.MatGuid,
                    bi.StoreGuid
      END

    -----------------------------------------------------------------------------------------    
    IF @Collect1 = 0
      EXEC GetMatFlds
        @MatFldsFlag,
        @MatCFlds

    -----------------------------------------------------------------------------------------   
    DECLARE @col1 NVARCHAR(100)

    SET @col1 = dbo.fnGetMatCollectedFieldName(@Collect1, DEFAULT)

    DECLARE @col2 NVARCHAR(100)

    SET @col2 = dbo.fnGetMatCollectedFieldName(@Collect2, DEFAULT)

    DECLARE @col3 NVARCHAR(100)

    SET @col3 = dbo.fnGetMatCollectedFieldName(@Collect3, DEFAULT)

    --handling the case of 11 which produces bug if any of passed @CollectX = 11
    DECLARE @Bug11 BIT

    SET @Bug11 = ( CASE
                     WHEN ( ( @Collect1 = 11 )
                             OR ( @Collect2 = 11 )
                             OR ( @Collect3 = 11 ) ) THEN 1
                     ELSE 0
                   END )
    SET @col1 = ( CASE
                    WHEN ( ( @Collect1 = 9 )
                            OR ( @Collect1 = 10 ) ) THEN 'mt.'
                    ELSE ''
                  END ) + @col1
    SET @col2 = ( CASE
                    WHEN ( ( @Collect2 = 9 )
                            OR ( @Collect2 = 10 ) ) THEN 'mt.'
                    ELSE ''
                  END ) + @col2
    SET @col3 = ( CASE
                    WHEN ( ( @Collect3 = 9 )
                            OR ( @Collect3 = 10 ) ) THEN 'mt.'
                    ELSE ''
                  END ) + @col3

    -----------------------------------------------------------------------------------------    
    DECLARE @ss NVARCHAR(max)

	CREATE TABLE #OrderedMatsDtls
	(
		 [MatGuid]              [UNIQUEIDENTIFIER],
         [MatName]              [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [inOrdered]            FLOAT DEFAULT 0,
         [outOrdered]           FLOAT DEFAULT 0,
         [inOrderedBonus]       FLOAT DEFAULT 0,
         [outOrderedBonus]      FLOAT DEFAULT 0,
         [inRetrieved]          FLOAT DEFAULT 0,
         [outRetrieved]         FLOAT DEFAULT 0,
         [inRetrievedBonus]     FLOAT DEFAULT 0,
         [outRetrievedBonus]    FLOAT DEFAULT 0,
         [inRemainder]          FLOAT DEFAULT 0,
         [outRemainder]         FLOAT DEFAULT 0,
         [inRemainedBonus]      FLOAT DEFAULT 0,
         [outRemainedBonus]     FLOAT DEFAULT 0,
         [StoreQty]             FLOAT DEFAULT 0,
         [unit]                 NVARCHAR(255) COLLATE ARABIC_CI_AI,
         [High]                 FLOAT DEFAULT 0,
         [Low]                  FLOAT DEFAULT 0,
         [OrderLimit]           FLOAT DEFAULT 0,
         [StoreGuid]            [UNIQUEIDENTIFIER],
         [StoreName]            [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [Col1]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col2]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col3]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI			
	)

    -- statement minified (spaces reduced) to avoid exceeding the border of 8000 chars 
    SET @ss = 'INSERT INTO #OrderedMatsDtls SELECT result.MatGuid , result.mtName  MatName , '
               + '
				SUM(CASE Ordered.OrderType
				WHEN 6 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Ordered.Qty
				WHEN 2 THEN Ordered.Qty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Ordered.Qty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Ordered.Qty / mtDefUnitFact
				END)ELSE 0 END
				) inOrdered,
				SUM(CASE Ordered.OrderType
				WHEN 5 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Ordered.Qty
				WHEN 2 THEN Ordered.Qty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Ordered.Qty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Ordered.Qty / mtDefUnitFact
				END)ELSE 0 END
				) outOrdered,
				SUM(CASE Ordered.OrderType
				WHEN 6 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Ordered.BonusQty
				WHEN 2 THEN Ordered.BonusQty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Ordered.BonusQty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Ordered.BonusQty / mtDefUnitFact
				END)ELSE 0 END
				) inOrderedBonus,
				SUM(CASE Ordered.OrderType
				WHEN 5 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Ordered.BonusQty
				WHEN 2 THEN Ordered.BonusQty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Ordered.BonusQty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Ordered.BonusQty / mtDefUnitFact
				END)ELSE 0 END
				) outOrderedBonus,
				SUM(CASE Ordered.OrderType
				WHEN 6 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Retrieved.Qty
				WHEN 2 THEN Retrieved.Qty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Retrieved.Qty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Retrieved.Qty / mtDefUnitFact
				END)ELSE 0 END
				) inRetrieved,
				SUM(CASE Ordered.OrderType
				WHEN 5 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Retrieved.Qty
				WHEN 2 THEN Retrieved.Qty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Retrieved.Qty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Retrieved.Qty / mtDefUnitFact
				END)ELSE 0 END
				) outRetrieved,
				SUM(CASE Ordered.OrderType
				WHEN 6 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Retrieved.BonusPostedQty
				WHEN 2 THEN Retrieved.BonusPostedQty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Retrieved.BonusPostedQty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Retrieved.BonusPostedQty / mtDefUnitFact
				END)ELSE 0 END
				) inRetrievedBonus,
				SUM(CASE Ordered.OrderType
				WHEN 5 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN Retrieved.BonusPostedQty    
				WHEN 2 THEN Retrieved.BonusPostedQty / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN Retrieved.BonusPostedQty / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE Retrieved.BonusPostedQty / mtDefUnitFact
				END)ELSE 0 END
				) outRetrievedBonus,
				SUM(CASE Ordered.OrderType
				WHEN 6 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0))
				WHEN 2 THEN (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0)) / (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0)) / (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0)) / mtDefUnitFact
				END)ELSE 0 END
				) inRemainder,
				SUM(CASE Ordered.OrderType WHEN 5 THEN
				(CASE  ' + Cast(@useUnit AS NVARCHAR(10))
				              + '
				WHEN 1 THEN (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0))
				WHEN 2 THEN (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0)) / (CASE result.mtUnit2Fact WHEN 0 THEN 1 ELSE result.mtUnit2Fact END)
				WHEN 3 THEN (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0)) / (CASE result.mtUnit3Fact WHEN 0 THEN 1 ELSE result.mtUnit3Fact END)
				ELSE (ISNULL(Ordered.Qty,0) - ISNULL(Retrieved.Qty,0)) / result.mtDefUnitFact
				END)ELSE 0 END
				) outRemainder, '
    -- SET statement must not exceed 4000 Chars, or it will be truncated, so separating SET assignment solve the problem.
    SET @ss = @ss + ' 
					SUM(CASE Ordered.OrderType WHEN 6 THEN
					(CASE  '
					              + Cast(@useUnit AS NVARCHAR(10)) + '
					WHEN 1 THEN (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0))
					WHEN 2 THEN (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0)) / (CASE result.mtUnit2Fact WHEN 0 THEN 1 ELSE result.mtUnit2Fact END)
					WHEN 3 THEN (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0)) / (CASE result.mtUnit3Fact WHEN 0 THEN 1 ELSE result.mtUnit3Fact END)
					ELSE (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0)) / result.mtDefUnitFact
					END)ELSE 0 END
					) inRemainedBonus,
					SUM(CASE Ordered.OrderType WHEN 5 THEN
					(CASE  '
					              + Cast(@useUnit AS NVARCHAR(10))
					              + '
					WHEN 1 THEN (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0))
					WHEN 2 THEN (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0)) / (CASE result.mtUnit2Fact WHEN 0 THEN 1 ELSE result.mtUnit2Fact END)
					WHEN 3 THEN (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0)) / (CASE result.mtUnit3Fact WHEN 0 THEN 1 ELSE result.mtUnit3Fact END)
					ELSE (ISNULL(Ordered.BonusQty,0) - ISNULL(Retrieved.BonusPostedQty,0)) / result.mtDefUnitFact
					END)ELSE 0 END
					) outRemainedBonus,
					MIN(CASE  '
					              + Cast(@useUnit AS NVARCHAR(10)) + '
					WHEN 1 then matQtys.Qty
					WHEN 2 then matQtys.Qty / (CASE mtUnit2Fact WHEN 0 then 1 ELSE mtUnit2Fact END)
					WHEN 3 then matQtys.Qty / (CASE mtUnit3Fact WHEN 0 then 1 ELSE mtUnit3Fact END)
					ELSE  matQtys.Qty / mtDefUnitFact END
					) StoreQty,
					(CASE  '
					              + Cast(@useUnit AS NVARCHAR(10)) + '
					WHEN 1 then result.mtUnity
					WHEN 2 then (CASE mtUnit2Fact WHEN 0 then result.mtUnity ELSE result.mtUnit2 END)
					WHEN 3 then (CASE mtUnit3Fact WHEN 0 then result.mtUnity ELSE result.mtUnit3 END)
					ELSE result.mtDefUnitName END
					) unit '
					              + CASE @Col1 WHEN '' THEN ' , result.High, result.Low, result.OrderLimit ' ELSE '' END + + CASE @DetailsStores WHEN 1 THEN
					              ' , matQtys.StoreGuid AS StoreGuid, st.Code + ''-'' + st.Name AS StoreName'
					              ELSE ' ,CAST(0x00 AS UNIQUEIDENTIFIER) AS StoreGuid, '' '' AS StoreName' END + ( CASE @Col1
					                                                                                                 WHEN '' THEN ', '' '' AS col1'
					                                                                                                 ELSE ',' + @Col1 + ' AS col1  '
					                                                                                               END ) + ( CASE @Col2
					                                                                                                           WHEN '' THEN ', '' '' AS col2'
					                                                                                                           ELSE ',' + @Col2 + ' AS col2  '
					                                                                                                         END ) + ( CASE @Col3
					                                                                                                                     WHEN '' THEN ', '' '' AS col3'
					                                                                                                                     ELSE ',' + @Col3 + ' AS col3  '
					                                                                                                                   END ) + ' 
					  FROM ' + CASE @DetailsStores
					                WHEN 1 THEN ' #OrderedStore '
					                ELSE ' #Ordered'
					           END + ' AS Ordered
					  INNER JOIN   #EndResult AS result ON Ordered.MatGuid = result.matguid
					  INNER JOIN ' + CASE @DetailsStores
					                      WHEN 1 THEN ' #retrievedStore'
					                      ELSE ' #retrieved'
					                 END + ' AS Retrieved ON Retrieved.MatGuid = result.MatGuid AND Retrieved.OrderType = Ordered.OrderType' + CASE @DetailsStores
																																				    WHEN 1 THEN ' AND Retrieved.StoreGuid = Ordered.StoreGuid'
																																				    ELSE ''
																																			   END + ' 
					  INNER JOIN ' + CASE @DetailsStores
					                      WHEN 1 THEN ' #MSQtys '
					                      ELSE ' #MQtys'
					                 END + ' AS matQtys ON  (matQtys.MatGuid = result.MatGuid)' + CASE @DetailsStores
																									   WHEN 1 THEN ' AND (matQtys.StoreGuid = Ordered.StoreGuid) '
																									   ELSE ''
																								  END + CASE @DetailsStores
																											 WHEN 1 THEN ' INNER JOIN st000 AS st ON matQtys.StoreGuid = st.guid '
																											 ELSE ( CASE @Col1
																														 WHEN '' THEN ' INNER JOIN ##MatFlds M ON M.MatFldGuid = Ordered.MatGuid'
																														 ELSE ''
																											        END )
					                                                                              END + ' 
					  INNER JOIN mt000 AS mt ON mt.Guid = result.MatGuid ' + CASE @DetailsStores
					                                                              WHEN 1 THEN dbo.fnGetInnerJoinGroup(CASE
					                                                                                                      WHEN ( ( @Collect1 = 11 )
					                                                                                                              OR ( @Collect2 = 11 )
					                                                                                                              OR ( @Collect3 = 11 ) ) THEN 1
					                                                                                                      ELSE 0
					                                                                                                  END, 'GroupGuid')
					                                                              ELSE ' INNER JOIN vwgr gr ON gr.grGUID = mt.GroupGUID '
					                                                         END + ' 
					  GROUP BY ' + @Col1 + ( CASE @Col1
					                              WHEN '' THEN ''
					                              ELSE ' , '
					                         END ) + @Col2 + ( CASE @Col2
					                                                WHEN '' THEN ''
					                                                ELSE ' , '
					                                            END ) + @Col3 + ( CASE @Col3
					                                                                   WHEN '' THEN ''
					                                                                   ELSE ' , '
					                                                              END ) + 'result.matguid , result.mtName, ' + CASE @DetailsStores
					                                                                                                                WHEN 1 THEN ' matQtys.StoreGuid, st.Code + ''-'' + st.Name, '
					                                                                                                                ELSE ''
					                                                                                                           END + '(CASE  ' + Cast(@useUnit AS NVARCHAR(10)) +
					                ' WHEN 1 then result.mtUnity
					  	WHEN 2 then (CASE mtUnit2Fact WHEN 0 then result.mtUnity ELSE result.mtUnit2 END)
					  	WHEN 3 then (CASE mtUnit3Fact WHEN 0 then result.mtUnity ELSE result.mtUnit3 END)
					  	ELSE result.mtDefUnitName END) ' +
					                CASE @Col1
					                            WHEN '' THEN ' , result.High, result.Low, result.OrderLimit ORDER BY result.mtName	'
					                            ELSE ''
					                          END

    EXEC (@ss)

    --finding QtyAfterSatisfyOrders using the formula
    -- ( (inRemainder+inRemainedBonus) - (outRemainder+outRemainedBonus) ) + StoreQty
  
	CREATE TABLE #Satisfy
	(
		[MatGuid]              [UNIQUEIDENTIFIER],
        [MatName]              [NVARCHAR](255) COLLATE ARABIC_CI_AI,      
        [inRemainedTotal]      FLOAT DEFAULT 0,
        [outRemainedTotal]     FLOAT DEFAULT 0,
        [StoreQty]             FLOAT DEFAULT 0,       
        [Satisfied]           FLOAT DEFAULT 0,
        [StoreGuid]            [UNIQUEIDENTIFIER],
        [StoreName]            [NVARCHAR](255) COLLATE ARABIC_CI_AI       
	)

    SET @ss = 'INSERT INTO #Satisfy
				SELECT DISTINCT t1.MatGuid , t1.MatName, '
				 + '   SUM(t1.inRemainder + t1.inRemainedBonus) AS inRemainedTotal,
					   SUM(t1.outRemainder + t1.outRemainedBonus) AS outRemainedTotal,
					   t1.StoreQty,
					   (SUM(t1.inRemainder + t1.inRemainedBonus) - SUM(t1.outRemainder + t1.outRemainedBonus) + t1.StoreQty) AS Satisfied'
					   + CASE @DetailsStores 
							  WHEN 1 THEN ', t1.StoreGuid, t1.StoreName ' 
							  ELSE ', CAST(0x00 AS UNIQUEIDENTIFIER) AS StoreGuid, '' '' AS StoreName' 
					     END + '
	FROM
		#OrderedMatsDtls t1'
              --+CASE @DetailsStores WHEN 1 THEN ' INNER JOIN st000 AS st ON st.[GUID] = t1.StoreGuid ' ELSE '' END
              + ' GROUP BY t1.MatGuid, t1.MatName, t1.StoreQty'
              + CASE @DetailsStores WHEN 1 THEN ', t1.StoreGuid, t1.StoreName ' ELSE '' END

    EXEC (@ss)

    --select 'satisfy',* from ##Satisfy
    --Adding Unordered Materials to ##t1 if @ShowUnavailable 

	CREATE TABLE #UnorderedMaterialsDetails
	(
		 [MatGuid]              [UNIQUEIDENTIFIER],
         [MatName]              [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [inOrdered]            FLOAT DEFAULT 0,
         [outOrdered]           FLOAT DEFAULT 0,
         [inOrderedBonus]       FLOAT DEFAULT 0,
         [outOrderedBonus]      FLOAT DEFAULT 0,
         [inRetrieved]          FLOAT DEFAULT 0,
         [outRetrieved]         FLOAT DEFAULT 0,
         [inRetrievedBonus]     FLOAT DEFAULT 0,
         [outRetrievedBonus]    FLOAT DEFAULT 0,
         [inRemainder]          FLOAT DEFAULT 0,
         [outRemainder]         FLOAT DEFAULT 0,
         [inRemainedBonus]      FLOAT DEFAULT 0,
         [outRemainedBonus]     FLOAT DEFAULT 0,
         [StoreQty]             FLOAT DEFAULT 0,
         [Unit]                 NVARCHAR(255) COLLATE ARABIC_CI_AI,
         [High]                 FLOAT DEFAULT 0,
         [Low]                  FLOAT DEFAULT 0,
         [OrderLimit]           FLOAT DEFAULT 0,
         [StoreGuid]            [UNIQUEIDENTIFIER],
         [StoreName]            [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [Col1]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col2]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col3]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI			
	)

    SET @ss = 'INSERT INTO #UnorderedMaterialsDetails
			   SELECT uno.MatGuid,
			   		  mt.Name AS MatName,
			   		  0 AS inOrdered,
			   		  0 AS outOrdered,
			   		  0 AS inOrderedBonus,
			   		  0 AS outOrderedBonus,
			   		  0 AS inRetrieved,
			   		  0 AS outRetrieved,
			   		  0 AS inRetrievedBonus,
			   		  0 AS outRetrievedBonus,
			   		  0 AS inRemainder,
			   		  0 AS outRemainder,
			   		  0 AS inRemainedBonus,
			   		  0 AS outRemainedBonus,
			   		  (CASE  '+ Cast(@useUnit AS NVARCHAR(10))
					          + '
			   			      WHEN 1 THEN MQty.Qty
			   			      WHEN 2 THEN MQty.Qty / (CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END)
			   			      WHEN 3 THEN MQty.Qty / (CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END)
			   			      ELSE MQty.Qty / mt.DefUnit 
			   		   END) AS StoreQty,
			   		  (CASE  '+ Cast(@useUnit AS NVARCHAR(10))
							  + '
			   		  		  WHEN 1 THEN mt.Unity
			   		  		  WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0 THEN mt.Unity ELSE mt.Unit2 END)
			   		  		  WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0 THEN mt.Unity ELSE mt.Unit3 END)
			   		  		  ELSE (CASE mt.DefUnit WHEN 1 THEN mt.Unity
			   		  		  					WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0 THEN mt.Unity ELSE mt.Unit2 END)
			   		  		  					WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0 THEN mt.Unity ELSE mt.Unit3 END)
			   		  		  					ELSE mt.Unity END)
			   		  END) AS Unit
			   		  , 0 AS High, 0 AS Low, 0 AS OrderLimit'
					        + CASE @DetailsStores WHEN 1 THEN ',st.[Guid] AS StoreGuid , st.Code + ''-'' + st.Name AS StoreName ' ELSE ' ,CAST(0x00 AS UNIQUEIDENTIFIER) AS StoreGuid, '' '' AS StoreName ' END + CASE
					        @Col1 WHEN '' THEN ', '' '' AS col1' ELSE ',' + @Col1 + ' AS col1 ' END + + CASE @Col2 WHEN '' THEN ', '' '' AS col2' ELSE ',' + @Col2 + ' AS col2 ' END + + CASE @Col3 WHEN '' THEN
					        ', '' '' AS col3' ELSE ',' + @Col3 + ' AS col3 ' END + '	
			   FROM 
			   		#MatUnordered AS uno
			   		INNER JOIN mt000 AS mt ON mt.[GUID] = uno.MatGuid
			   		INNER JOIN vwgr AS gr ON mt.[GroupGUID] = gr.grGuid
			   		INNER JOIN ' + CASE @DetailsStores WHEN 1 THEN ' #MSQtys ' ELSE ' #MQtys ' END
			          + ' AS MQty ON MQty.MatGuid = uno.MatGuid'
			          + CASE @DetailsStores WHEN 1 THEN ' INNER JOIN st000 AS st ON st.[Guid] = MQty.StoreGuid ' ELSE '' END

    EXEC (@ss)
    --
    --unifying #OrderedMatsDtls and #UnorderedMaterialsDetails in one table if @ShowUnordered = 1
    CREATE TABLE #OrderedUnOrderedMaterialsDetails
      (
         [MatGuid]              [UNIQUEIDENTIFIER],
         [MatName]              [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [inOrdered]            FLOAT DEFAULT 0,
         [outOrdered]           FLOAT DEFAULT 0,
         [inOrderedBonus]       FLOAT DEFAULT 0,
         [outOrderedBonus]      FLOAT DEFAULT 0,
         [inRetrieved]          FLOAT DEFAULT 0,
         [outRetrieved]         FLOAT DEFAULT 0,
         [inRetrievedBonus]     FLOAT DEFAULT 0,
         [outRetrievedBonus]    FLOAT DEFAULT 0,
         [inRemainder]          FLOAT DEFAULT 0,
         [outRemainder]         FLOAT DEFAULT 0,
         [inRemainedBonus]      FLOAT DEFAULT 0,
         [outRemainedBonus]     FLOAT DEFAULT 0,
         [StoreQty]             FLOAT DEFAULT 0,
         [QtyAfterSatisfyOrder] FLOAT DEFAULT 0,
         [Unit]                 NVARCHAR(255) COLLATE ARABIC_CI_AI,
         [High]                 FLOAT DEFAULT 0,
         [Low]                  FLOAT DEFAULT 0,
         [OrderLimit]           FLOAT DEFAULT 0,
         [StoreGuid]            [UNIQUEIDENTIFIER],
         [StoreName]            [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [Col1]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col2]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col3]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI
      )

    SET @ss = 'INSERT INTO #OrderedUnOrderedMaterialsDetails 
		SELECT DISTINCT xyz.* 
		FROM
		(SELECT DISTINCT ' + CASE @Col1 WHEN '' THEN ' t1.MatGuid, t1.MatName, ' ELSE ' CAST(0x00 AS UNIQUEIDENTIFIER) AS MatGuid, '''' AS MatName, ' END + '
			t1.inOrdered,
			t1.outOrdered,
			t1.inOrderedBonus,
			t1.outOrderedBonus,
			t1.inRetrieved,
			t1.outRetrieved,
			t1.inRetrievedBonus,
			t1.outRetrievedBonus,
			t1.inRemainder,
			t1.outRemainder,
			t1.inRemainedBonus,
			t1.outRemainedBonus,
			t1.StoreQty,
			ISNULL(sts.Satisfied, t1.StoreQty)  QtyAfterSatisfyOrder, 
			t1.Unit' + CASE @Col1 WHEN ''
              THEN
              ' ,t1.High, t1.Low, t1.OrderLimit' ELSE ' , 0 AS High, 0 AS Low, 0 AS OrderLimit' END
              + ' 
			,t1.StoreGuid
			,t1.StoreName' + CASE @Col1 WHEN '' THEN ', '' '' AS Col1' ELSE ', t1.Col1  AS Col1' END + CASE @Col2 WHEN '' THEN ', '' '' AS Col2' ELSE ', t1.Col2  AS Col2' END + CASE @Col3 WHEN
              ''
              THEN ', '' '' AS Col3' ELSE ', t1.Col3  AS Col3' END
              + '
		FROM #OrderedMatsDtls t1
		INNER JOIN #Satisfy sts ON sts.MatGuid = t1.MatGuid AND'
              + --sts.col1 = t1.col1 AND
              '  sts.StoreGuid = t1.StoreGuid
		WHERE ((sts.Satisfied > 0) AND ('
              + Cast(@ShowAvailable AS NVARCHAR(1))
              + '=1))
			OR ((sts.Satisfied = 0) AND ('
              + Cast(@ShowBalanced AS NVARCHAR(1))
              + '=1))
			OR ((sts.Satisfied < 0) AND ('
              + Cast(@ShowUnavailable AS NVARCHAR(1))
              + '=1))' + CASE WHEN (@ShowUnordered = 1) THEN ' UNION
		SELECT DISTINCT ' +CASE @Col1 WHEN '' THEN ' t2.MatGuid, t2.MatName, ' ELSE
              ' CAST(0x00 AS UNIQUEIDENTIFIER) AS MatGuid, '''' AS MatName, '
              END +'
			t2.inOrdered,
			t2.outOrdered,
			t2.inOrderedBonus,
			t2.outOrderedBonus,
			t2.inRetrieved,
			t2.outRetrieved,
			t2.inRetrievedBonus,
			t2.outRetrievedBonus,
			t2.inRemainder,
			t2.outRemainder,
			t2.inRemainedBonus,
			t2.outRemainedBonus,
			t2.StoreQty,
			t2.StoreQty AS QtyAfterSatisfyOrder,
			t2.Unit' +CASE @Col1 WHEN '' THEN ' ,t2.High, t2.Low, t2.OrderLimit' ELSE ' , 0 AS High, 0 AS Low, 0 AS OrderLimit' END +' 
			,t2.StoreGuid
			,t2.StoreName' +CASE @Col1 WHEN '' THEN
              ', '' '' AS Col1'
              ELSE ', t2.Col1  AS Col1' END +CASE @Col2 WHEN '' THEN ', '' '' AS Col2' ELSE ', t2.Col2  AS Col2' END +CASE @Col3 WHEN '' THEN ', '' '' AS Col3' ELSE ', t2.Col3  AS Col3' END
              --+CASE @Col1 WHEN ''	THEN ', '' '' AS Col1' ELSE ', t2.Col1 ' END
              --+CASE @Col2 WHEN ''	THEN ', '' '' AS Col2' ELSE ', t2.Col2 ' END
              --+CASE @Col3 WHEN ''	THEN ', '' '' AS Col3' ELSE ', t2.Col3 ' END
              +'
		FROM #UnorderedMaterialsDetails t2
		WHERE ((t2.StoreQty > 0) AND ('+Cast(@ShowUnordered AS NVARCHAR(1))+' = 1) AND ('+Cast(@ShowAvailable AS NVARCHAR(1))+' = 1))
			OR ((t2.StoreQty = 0) AND ('+Cast(@ShowUnordered AS NVARCHAR(1
              ))+
              ' = 1) AND ('+Cast(@ShowBalanced AS NVARCHAR(1))+'=1))
			OR ((t2.StoreQty < 0) AND ('+Cast(@ShowUnordered AS NVARCHAR(1))+' = 1) AND ('+Cast(@ShowUnavailable AS NVARCHAR(1))+'=1))
		 ) xyz ' ELSE
    ') xyz ' END

    EXEC (@ss)

    CREATE TABLE #finalResult
      (
         [MatGuid]              [UNIQUEIDENTIFIER],
         [MatName]              [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [inOrdered]            FLOAT DEFAULT 0,
         [outOrdered]           FLOAT DEFAULT 0,
         [inOrderedBonus]       FLOAT DEFAULT 0,
         [outOrderedBonus]      FLOAT DEFAULT 0,
         [inRetrieved]          FLOAT DEFAULT 0,
         [outRetrieved]         FLOAT DEFAULT 0,
         [inRetrievedBonus]     FLOAT DEFAULT 0,
         [outRetrievedBonus]    FLOAT DEFAULT 0,
         [inRemainder]          FLOAT DEFAULT 0,
         [outRemainder]         FLOAT DEFAULT 0,
         [inRemainedBonus]      FLOAT DEFAULT 0,
         [outRemainedBonus]     FLOAT DEFAULT 0,
         [StoreQty]             FLOAT DEFAULT 0,
         [QtyAfterSatisfyOrder] FLOAT DEFAULT 0,
         [Unit]                 NVARCHAR(255) COLLATE ARABIC_CI_AI,
         [High]                 FLOAT DEFAULT 0,
         [Low]                  FLOAT DEFAULT 0,
         [OrderLimit]           FLOAT DEFAULT 0,
         [StoreGuid]            [UNIQUEIDENTIFIER],
         [StoreName]            [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [Col1]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col2]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI,
         [Col3]                 [NVARCHAR](100) COLLATE ARABIC_CI_AI
      )

    IF @Col1 = ''
      BEGIN
          SET @ss = 'INSERT INTO #finalResult SELECT *FROM #OrderedUnOrderedMaterialsDetails'
      END
    ELSE
      BEGIN
          SET @ss = 'INSERT INTO #finalResult
		SELECT '+ + CASE @Col1 WHEN '' THEN ' tt.MatGuid, tt.MatName, ' ELSE ' CAST(0x00 AS UNIQUEIDENTIFIER) AS MatGuid, '''' AS MatName, ' END + '
			SUM(inOrdered) AS inOrdered,
			SUM(outOrdered) AS outOrdered,
			SUM(inOrderedBonus) AS inOrderedBonus,
			SUM(outOrderedBonus) AS outOrderedBonus,
			SUM(inRetrieved) AS inRetrieved,
			SUM(outRetrieved) AS outRetrieved,
			SUM(inRetrievedBonus) AS inRetrievedBonus,
			SUM(outRetrievedBonus) AS outRetrievedBonus,
			SUM(inRemainder) AS inRemainder,
			SUM(outRemainder) AS outRemainder,
			SUM(inRemainedBonus) AS inRemainedBonus,
			SUM(outRemainedBonus) AS outRemainedBonus,
			SUM(StoreQty) AS StoreQty,
			SUM(QtyAfterSatisfyOrder) AS QtyAfterSatisfyOrder,
			unit' + CASE @Col1 WHEN '' THEN
                    ' ,tt.High, tt.Low, tt.OrderLimit' ELSE ' , 0 AS High, 0 AS Low, 0 AS OrderLimit' END + ' 
			,StoreGuid 
			,StoreName'
                    + CASE @Col1 WHEN '' THEN ', '' '' AS Col1' ELSE ', tt.Col1  AS Col1' END + CASE @Col2 WHEN '' THEN ', '' '' AS Col2' ELSE ', tt.Col2  AS Col2' END + CASE @Col3 WHEN '' THEN
                    ', '' '' AS Col3' ELSE ', tt.Col3  AS Col3' END + '
		FROM #OrderedUnOrderedMaterialsDetails tt
		GROUP BY 
			col1, col2, col3, 
			unit,
			StoreGuid, 
			StoreName'
      END

    EXEC (@ss)

    IF @Col1 = ''
      SET @ss = ' SELECT DISTINCT tt.*, M.*
		FROM #finalResult tt 
		INNER JOIN ##MatFlds M ON M.MatFldGuid = tt.MatGuid
			ORDER BY tt.MatName'
    ELSE
      SET @ss = ' SELECT DISTINCT tt.*
		FROM #finalResult tt 
		 ORDER BY  tt.Col1,
				    tt.Col2,
				    tt.Col3'

    EXEC (@ss)
  
    SELECT *
    FROM   #SecViol 
#########################################################################
#END