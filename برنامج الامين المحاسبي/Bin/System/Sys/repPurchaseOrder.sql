#########################################################
CREATE PROCEDURE repPurchaseOrder @Acc            [UNIQUEIDENTIFIER],
                                  @Cost           [UNIQUEIDENTIFIER],
                                  @Mt             AS [UNIQUEIDENTIFIER],
                                  @Gr             AS [UNIQUEIDENTIFIER],
                                  @Store          AS [UNIQUEIDENTIFIER],
                                  @StartDate      [DATETIME],
                                  @EndDate        [DATETIME],
                                  @CurGUID        [UNIQUEIDENTIFIER],
                                  @CurVal         [FLOAT],
                                  @TypeGuid       [UNIQUEIDENTIFIER],
                                  @Src            AS [UNIQUEIDENTIFIER],
                                  @Unity          AS [INT],
                                  @isFinished     BIT = 0,
                                  @isCancled      BIT = 0,
                                  @isActive       BIT = 0,
                                  @MatCond        UNIQUEIDENTIFIER = 0x00,
                                  @CustCondGuid   UNIQUEIDENTIFIER = 0x00,
                                  @OrderCond      UNIQUEIDENTIFIER = 0x00,
                                  @OrderNumber    INT = 0,
                                  @ShowOrderState BIT = 1
AS
  BEGIN
      SET NOCOUNT ON

      IF Object_id('tempdb..##Result3') IS NOT NULL
        DROP TABLE ##Result3

      DECLARE @Language BIT = dbo.fnConnections_GetLanguage();

      CREATE TABLE [#SecViol]
        (
           [Type] [INT],
           [Cnt]  [INT]
        )

      -------Bill Resource ---------------------------------------------------------         
      CREATE TABLE [#Src]
        (
           [Type]        [UNIQUEIDENTIFIER],
           [Sec]         [INT],
           [ReadPrice]   [INT],
           [UnPostedSec] [INT]
        )

      INSERT INTO [#Src]
      EXEC [prcGetBillsTypesList2]
        @Src

      -------------------------------------------------------------------         
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
      -------------------------------------------------------------------  
      --  ÌÏæá ÇáØáÈíÇÊ ãÚ ÊÍÍÞíÞ ÔÑæØ ÇáØáÈíÇÊ 
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
      -------------------------------------------------------------------      
      CREATE TABLE [#CustTbl]
        (
           [Number] [UNIQUEIDENTIFIER],
           [cuSec]  [INT]
        )
      INSERT INTO [#CustTbl]
      EXEC [prcGetCustsList]
        NULL,
        @Acc,
        @CustCondGuid

      IF ( ISNULL(@Acc, 0x0) = 0x00 )
         AND ( ISNULL(@CustCondGuid, 0x0) = 0x0 )
        BEGIN
            INSERT INTO [#CustTbl]
            VALUES      (0x0,
                         1)
        END

      -------Mat Table----------------------------------------------------------         
      CREATE TABLE [#MatTbl]
        (
           [mtNumber]   [UNIQUEIDENTIFIER],
           [mtSecurity] [INT]
        )

      INSERT INTO [#MatTbl]
      EXEC [prcGetMatsList]
        @Mt,
        @Gr,
        -1,
        @MatCond

      -------Store Table----------------------------------------------------------         
      DECLARE @StoreTbl TABLE
        (
           [Number] [UNIQUEIDENTIFIER],
           [Name]   NVARCHAR(255)
        )

      INSERT INTO @StoreTbl
      SELECT storetbl.[GUID],
             stnames.NAME AS NAME
      FROM   [fnGetStoresList](@Store) storetbl
             CROSS APPLY (SELECT CASE @Language
                                   WHEN 0 THEN NAME
                                   ELSE
                                     CASE ISNULL(LatinName, '')
                                       WHEN '' THEN NAME
                                       ELSE LatinName
                                     END
                                 END AS NAME
                          FROM   st000
                          WHERE  GUID = storetbl.[GUID]) AS stnames

      ------Cost Table----------------------------------------------------------         
      DECLARE @CostTbl TABLE
        (
           [Number] [UNIQUEIDENTIFIER],
           [Name]   NVARCHAR(255)
        )

      INSERT INTO @CostTbl
      SELECT [Guid],
             CostCenterNames.NAME
      FROM   [fnGetCostsList](@Cost) Costtbl
             CROSS APPLY (SELECT CASE @Language
                                   WHEN 0 THEN NAME
                                   ELSE
                                     CASE ISNULL(LatinName, '')
                                       WHEN '' THEN NAME
                                       ELSE LatinName
                                     END
                                 END AS NAME
                          FROM   co000
                          WHERE  GUID = Costtbl.[GUID]) AS CostCenterNames
     
	  IF ISNULL(@Cost, 0x0) = 0x0
        INSERT INTO @CostTbl
        VALUES      (0x0,
                     '')

      --------------------------------------------------------------------------
      CREATE TABLE #Result
        (
           [MtGUID]                UNIQUEIDENTIFIER,
           [buGuid]                UNIQUEIDENTIFIER,
           [CustGuid]              UNIQUEIDENTIFIER,
           [biGuid]                UNIQUEIDENTIFIER,
           [biPrice]               FLOAT,
           [billUnit]              INT,
           [billUnitFact]          FLOAT,
           [biQty]                 FLOAT,
           [buFormatedNumber]      NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [buLatinFormatedNumber] NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [buCust_Name]           NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [buDate]                DATETIME,
           [mtSecurity]            [INT],
           [buSecurity]            [INT],
           [UserSecurity]          [INT],
           [CostCenter]            NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [StoreName]             NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [IsCanceled]            BIT,
           [IsFinished]            BIT
        )

      INSERT INTO #Result
      SELECT [bu].[biMatPtr],
             [bu].[buGuid],
             [bu].[BuCustPtr],
             [bu].[biGuid],
             CASE
               WHEN ReadPrice < busecurity THEN 0
               ELSE
                  [FixedbiUnitPrice] * CASE @Unity
                                                      WHEN 2 THEN
                                                        CASE [bu].[mtUnit2Fact]
                                                          WHEN 0 THEN 1
                                                          ELSE [bu].[mtUnit2Fact]
                                                        END
                                                      WHEN 3 THEN
                                                        CASE [bu].[mtUnit3Fact]
                                                          WHEN 0 THEN 1
                                                          ELSE [bu].[mtUnit3Fact]
                                                        END
                                                      WHEN 4 THEN
                                                        CASE [bu].[mtDefUnitFact]
                                                          WHEN 0 THEN 1
                                                          ELSE [bu].[mtDefUnitFact]
                                                        END
                                                      ELSE 1
                                                    END
                 
                 
             END               AS [biPrice],
             CASE @Unity
               WHEN 2 THEN 2
               WHEN 3 THEN 3
               WHEN 4 THEN [bu].[mtDefUnit]
               ELSE 1
             END               AS [billUnit],
             [mtUnitFact] AS [billUnitFact],
             ( [biQty] / CASE @Unity
                           WHEN 2 THEN
                             CASE ISNULL([bu].[mtUnit2Fact], 0)
                               WHEN 0 THEN 1
                               ELSE [bu].[mtUnit2Fact]
                             END
                           WHEN 3 THEN
                             CASE ISNULL([bu].[mtUnit3Fact], 0)
                               WHEN 0 THEN 1
                               ELSE [bu].[mtUnit3Fact]
                             END
                           WHEN 4 THEN
                             CASE ISNULL([bu].[mtDefUnitFact], 0)
                               WHEN 0 THEN 1
                               ELSE [bu].[mtDefUnitFact]
                             END
                           ELSE 1
                         END ) AS [biQty],
             [buFormatedNumber],
             [buLatinFormatedNumber],
             [buCust_Name],
             [buDate],
             [bu].[mtSecurity],
             [bu].[buSecurity],
             CASE [bu].[buIsPosted]
               WHEN 1 THEN [Src].[Sec]
               ELSE [Src].[UnPostedSec]
             END,
             [co].[Name]       AS CostCenter,
             [ST].[Name]       AS StoreName,
             [OInfo].[Add1],
             [OInfo].[Finished]
      FROM   [dbo].[fnExtended_bi_Fixed](@CurGUID) AS [bu]
             INNER JOIN #OrderCond OrCond
                     ON OrCond.OrderGuid = bu.BuGuid
             INNER JOIN ORADDINFO000 OInfo
                     ON bu.buGuid = OInfo.ParentGuid
             INNER JOIN [#MatTbl] AS [mtTbl]
                     ON [mtTbl].[mtNumber] = [bu].[biMatPtr]
             INNER JOIN [#CustTbl] AS [CU]
                     ON [CU].[Number] = [bu].[BuCustPtr]
             INNER JOIN [#Src] AS [Src]
                     ON [Src].[Type] = [bu].[buType]
             INNER JOIN @CostTbl AS [CO]
                     ON [CO].[Number] = [bu].[biCostPtr]
             INNER JOIN @StoreTbl AS [ST]
                     ON [ST].[Number] = [bu].[biStorePtr]
      WHERE  bu.buNumber = @OrderNumber
              OR @OrderNumber = 0
      ---------------------------------------------------
      -- Filter Orders AS Report Option 
      IF ( @isActive = 0 )
        DELETE FROM #Result
        WHERE  [IsCanceled] = 0
               AND [IsFinished] = 0
      
	  IF ( @isCancled = 0 )
        DELETE FROM #Result
        WHERE  [IsCanceled] = 1
     
	  IF ( @isFinished = 0 )
        DELETE FROM #Result
        WHERE  [IsFinished] = 1

      ----------------------------------------   
      EXEC prcCheckSecurity

      ---------------------------------------------------------------  
      -- Operation Result  
	  CREATE TABLE #Result2
        (
           [biGuid]                UNIQUEIDENTIFIER,
           [MtGUID]                UNIQUEIDENTIFIER,
           [buGuid]                UNIQUEIDENTIFIER,
           [CustGuid]              UNIQUEIDENTIFIER,
           [oriTypeGuid]           UNIQUEIDENTIFIER,
           [oriTypeNUmber]         INT,
           [biPrice]               FLOAT,
           [billUnit]              INT,
           [billUnitFact]          FLOAT,
           [oriQty]                FLOAT,
           [biQty]                 FLOAT,
           [buFormatedNumber]      NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [buLatinFormatedNumber] NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [buCust_Name]           NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [buDate]                DATETIME,
           [oriDate]               DATETIME,
           [oriNotes]              NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [oriTypeName]           NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [oriTypeLatinName]      NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [oriNumber]             INT,
           [PreviousState]         UNIQUEIDENTIFIER,
           [PreviousStateName]     NVARCHAR(255) COLLATE ARABIC_CI_AI,
           [CostCenter]            NVARCHAR(255),
           [StoreName]             NVARCHAR(255),
           [IsCanceled]            BIT,
           [IsFinished]            BIT
        )
    
	  INSERT INTO #Result2
      SELECT  [bu].[biGuid]  AS [biGuid],
             [bu].[mtGUID],
              [bu].[buGuid]  AS [buGuid],
              [bu].[CustGuid] AS [CustGuid],
             [t].[Type],
             [t].[PostQty],
             [biPrice],
				[billUnit],
				[billUnitFact],
             Sum([oriQty] / CASE @Unity
                              WHEN 2 THEN
                                CASE ISNULL([mt].[mtUnit2Fact], 0)
                                  WHEN 0 THEN 1
                                  ELSE [mt].[mtUnit2Fact]
                                END
                              WHEN 3 THEN
                                CASE ISNULL([mt].[mtUnit3Fact], 0)
                                  WHEN 0 THEN 1
                                  ELSE [mt].[mtUnit3Fact]
                                END
                              WHEN 4 THEN
                                CASE ISNULL([mt].[mtDefUnitFact], 0)
                                  WHEN 0 THEN 1
                                  ELSE [mt].[mtDefUnitFact]
                                END
                              ELSE 1
                            END) AS [oriQty],
             Sum([bu].[biQty])   AS [biQty],
              [buFormatedNumber],
             [buLatinFormatedNumber],
              [buCust_Name],
             [buDate],
             [oriDate],
             [oriNotes],
             [t].[Name]          [oriTypeName],
             [t].[LatinName]     [oriTypeLatinName],
             [oriNumber]         AS oriNumber,
             [ori].[PreviousState],
             [ori].[PreviousStateName],
             ''                  AS CostCenter,
             ''                  AS StoreName,
             0                   AS IsCanceled,
             0                   AS IsFinished
      FROM   [#Result] AS [bu]
             INNER JOIN [vwMt] AS [mt]
                     ON [Bu].[mtGuid] = [mt].[mtGuid]
             INNER JOIN (SELECT [o].[oriPOIGuid],
                                [o].[oriTypeGuid],
                                [o].[oriPOGUID] AS [oriPOGuid],
                                Sum([o].[oriQty]) AS [oriQty],
                                [o].[oriDate] AS [oriDate],
                                 [o].[oriNotes]AS [oriNotes],
                                [oriNumber],
                                oit.GUID AS [PreviousState],
                                
                                    CASE @Language
                                      WHEN 0 THEN oit.NAME
                                      ELSE
                                        CASE ISNULL(oit.LatinName, '')
                                          WHEN '' THEN oit.NAME
                                          ELSE oit.LatinName
                                        END
                                    END AS [PreviousStateName]
                         FROM   [vwORI] [o]
                                LEFT JOIN ori000 previousState
                                       ON previousState.POIGUID = [o].oriPOIGuid
                                          AND previousState.Number = [o].oriNumber - 1
                                LEFT JOIN oit000 oit
                                       ON oit.[GUID] = previousState.TypeGuid
                         WHERE  oriQty > 0
                                AND o.oriDate BETWEEN @StartDate AND @ENDDate
                         GROUP  BY  [oriPOGUID],
                                   [oriPOIGuid],
                                   [o].[oriTypeGuid],
                                    [oriNumber],
                                   [o].[oriDate],
                                   [o].[oriNotes],
                                   
                                       CASE @Language
                                         WHEN 0 THEN oit.NAME
                                         ELSE
                                           CASE ISNULL(oit.LatinName, '')
                                             WHEN '' THEN oit.NAME
                                             ELSE oit.LatinName
                                           END
                                       END,
                                      oit.[GUID] )AS [ori]
                     ON [ori].[oriPOIGuid] = [bu].[biGuid]
             INNER JOIN @TypeTbl [t]
                     ON ISNULL([ori].[oriTypeGuid], 0x0) = [t].[Type]
      GROUP  BY [bu].[buGuid],
                [bu].[biGuid],
                [oriTypeGuid],
                [bu].[mtGUID],
                [bu].[CustGuid],
                [t].[Type],
                [t].[PostQty],
                [biPrice],
                [billUnit],
                [billUnitFact],
                [buFormatedNumber],
                [buLatinFormatedNumber],
               [buCust_Name],
                [buDate],
                [oriDate],
                [oriNumber],
                [oriNotes],
                [ori].[PreviousState],
                [ori].[PreviousStateName],
                [t].[Name],
                [t].[LatinName]

      ---------------------------------------------------------------------
      -- Update after operation for collecting orders
      
            UPDATE res2
            SET    res2.StoreName = res1.StoreName,
                   res2.CostCenter = res1.CostCenter,
                   res2.IsCanceled = res1.IsCanceled,
                   res2.IsFinished = res1.IsFinished
            FROM   #Result2 res2
                   INNER JOIN #Result res1
                           ON res1.buGuid = res2.buGuid
      ---------------------------------------------------------------------------
      DECLARE @SelectStr AS NVARCHAR(MAX)
      
	  SET @SelectStr = '
			SELECT    
				[Res].[biGuid],  
				[Res].[MtGUID],  
				[Res].[buGuid],  
				[Res].[CustGUID], 
				[Res].[oriTypeGuid],  
				[Res].[oriTypeNUmber],   
				[Res].[biPrice],   
				[Res].[billUnit],   
				[Res].[billUnitFact],   
				[Res].[oriQty],   
				[Res].[biQty],     
				[Res].[buFormatedNumber],  
				[Res].[buLatinFormatedNumber],  
				[Res].[buCust_Name],   
				[Res].[buDate],   
				[Res].[oriDate],   
				[Res].[oriNotes],   
				[Res].[oriTypeName],   
				[Res].[oriTypeLatinName], 
  				[Res].[oriNumber],
				ISNULL([Res].[PreviousState],0x0) AS PreviousState,
				ISNULL([Res].[PreviousStateName] ,'''') AS PreviousStateName,
				[Res].[CostCenter] AS CostCenter,
				[Res].[StoreName] AS StoreName,
				[Res].[IsCanceled] AS IsCanceled ,
				[Res].[IsFinished] AS IsFinished ,
				[mt].[MtCode],   
				[mt].[MtName] AS [MtName],   
				[mt].[MtLatinName] AS [MtLatinName],   
				[mt].[MtBarCode],      
				[mt].[MtBarCode2],      
				[mt].[MtBarCode3],'
      
	  IF @Unity = 2
        SET @SelectStr = @SelectStr
                         + '[mt].[MtUnit2] AS [MtDefUnitName],'
      ELSE IF @Unity = 3
        SET @SelectStr = @SelectStr
                         + '[mt].[MtUnit3] AS [MtDefUnitName],'
      ELSE IF @Unity = 4
        SET @SelectStr = @SelectStr
                         + '[mt].[MtDefUnitName] AS [MtDefUnitName],'
      ELSE
        SET @SelectStr = @SelectStr
                         + '[mt].[MtUnity] AS [MtDefUnitName],'
     
	  SET @SelectStr = @SelectStr + '[mt].[MtType],   
				[mt].[MtSpec],      
				[mt].[MtDim],      
				[mt].[MtOrigin],      
				[mt].[MtPos],      
				[mt].[MtGroup],      
				[mt].[grName] AS [MtGrpName],   
				[mt].[MtCompany],      
				[mt].[MtColor],      
				[mt].[MtProvenance],      
				[mt].[MtQuality],      
				[mt].[MtModel],      
				[mt].[MtQty] / '
      
	  IF @Unity = 2
        SET @SelectStr = @SelectStr
                         + 'CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END AS [MtQty]'
      ELSE IF @Unity = 3
        SET @SelectStr = @SelectStr
                         + 'CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END AS [MtQty]'
      ELSE IF @Unity = 4
        SET @SelectStr = @SelectStr
                         + 'CASE [mt].[MtDefUnitFact] WHEN 0 THEN 1 ELSE [mt].[MtDefUnitFact] END AS [MtQty]'
      ELSE
        SET @SelectStr = @SelectStr + '1 AS [MtQty]'
      
	  SET @SelectStr = @SelectStr
                       + ' INTO ##Result3
			 FROM    
				#Result2 [Res] INNER join [vwMtGr] [mt] ON [Res].[mtGuid] = [mt].[mtGuid]'
      
	  
	  SET @SelectStr = @SelectStr + 'ORDER BY      
				[mt].[MtName],      
				[Res].[budate], 
				[Res].[buFormatedNumber],   
				[Res].[oriDate], 
				[Res].[oriNumber] ASC'
     
	  EXEC (@SelectStr)

      -----------------------------------------------------------------------------------
      --Final Result
      SET @SelectStr = ' SELECT DISTINCT Res.* ' 
                       + ' FROM ##Result3 [Res]  ORDER BY '
     
      SET @SelectStr += ' [buFormatedNumber] , oriNumber  ASC'
     
      EXEC (@SelectStr)

      --------------------------------------------------------------------------
      --Show Orders States Quantities In Orders Details Show 
     -- IF @Unify = 1
        BEGIN
            DECLARE @StateQtyResult TABLE
              (
                 POIGUID   [UNIQUEIDENTIFIER],
                 StateGUID [UNIQUEIDENTIFIER],
                 ORINumber [INT],
                 Qty       FLOAT
              )
            DECLARE @c         CURSOR,
                    @OriNumber [INT],
                    @PoiGuid   UNIQUEIDENTIFIER,
                    @StateGuid UNIQUEIDENTIFIER
           
		    SET @c = CURSOR FAST_FORWARD
            FOR SELECT [biGuid],
                       [oriTypeGuid],
                       [oriNUmber]
                FROM   ##Result3

            OPEN @c

            FETCH FROM @c INTO @PoiGuid, @StateGuid, @OriNumber

            WHILE @@FETCH_STATUS = 0
              BEGIN
                  INSERT INTO @StateQtyResult
                  SELECT POIGUID,
                         TypeGuid,
                         @OriNumber,
                         Sum(Qty) StateQty
                  FROM   ori000 ori
                         INNER JOIN oit000 oit
                                 ON oit.[GUID] = ori.TypeGuid
                  WHERE  POIGUID = @PoiGuid
                         AND ori.number <= @OriNumber
                  GROUP  BY POGUID,
                            POIGUID,
                            [TypeGuid],
                            oit.NAME

                  FETCH FROM @c INTO @PoiGuid, @StateGuid, @OriNumber
              END

            CLOSE @c

            DEALLOCATE @c

            -----------------------------------------------
            --Get Orders States
            SELECT POIGUID,
                   StateGUID,
                   ORINumber,
                   Qty AS StateQty
            FROM   @StateQtyResult
            ORDER  BY ORINumber
        END

      DROP TABLE ##Result3
  END 
#################################################################
#END