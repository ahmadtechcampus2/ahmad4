##############################################################  
CREATE PROCEDURE repSummuryOfDialyMove
    @StartDate          [DateTime] ,  
    @EndDate            [DateTime] ,  
    @SrcTypesGuid [UNIQUEIDENTIFIER] ,  
    @StoreGuid          [UNIQUEIDENTIFIER] ,  
    @CurrPtr            [UNIQUEIDENTIFIER] ,  
    @PostedValue  [int] = -1,  --0,1,-1  
    @TypeGroup          [INT]=0, --0,1,2  
    @Str              [NVARCHAR] (max) = '',  
    @UseUnit          [INT]  = 0,  
    @GroupGUID        [UNIQUEIDENTIFIER] = 0X00,  
    @CostGUID         [UNIQUEIDENTIFIER] = 0X00,  
    @PriceType        [INT] = 2 ,  
    @PricePolicy      [INT] = 121,
    @CurVal                 [FLOAT] = 1,
    @MATCOND          [UNIQUEIDENTIFIER] = 0x00,
    @BILLCOND         [UNIQUEIDENTIFIER] = 0x00,
    @USERGuid         [UNIQUEIDENTIFIER] = 0x00,
    @MaterialGuid   UNIQUEIDENTIFIER = 0x00,
    @ShowPrev       [int]
AS
      SET NOCOUNT ON
      CREATE TABLE [#SecViol]([Type] [INT],[Cnt] [INTEGER])    
      CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER] ,[UserSecurity] [INTEGER],[UserReadPriceSecurity] [INT],[UnPostedSecurity] [INTEGER])    
      CREATE TABLE [#StoreTbl] ([StoreGUID] [UNIQUEIDENTIFIER] ,[Security] [INT])    
      CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])    
      CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])    
      CREATE TABLE [#mt]   
      (   
            [MatGUID] [UNIQUEIDENTIFIER],   
            [mtSecurity] [INT],   
            [mtUnitFact] [FLOAT],   
            [Unit2Fact] [FLOAT],   
            [Unit3Fact] [FLOAT],   
            [DefUint]   [INT]   
      )   
      CREATE TABLE #QTYS   
      (   
            [Qty]       FLOAT,   
            [Bonus]           FLOAT,   
            [Price]           FLOAT,   
            [MatGUID] [UNIQUEIDENTIFIER],   
            [stGUID] [UNIQUEIDENTIFIER],
			[TotalDiscountPercent] FLOAT,
			[TotalExtraPercent] FLOAT    
      )    
      INSERT INTO  [#BillsTypesTbl] EXEC  [prcGetBillsTypesList2]       @SrcTypesguid    
      INSERT INTO  [#StoreTbl] EXEC [prcGetStoresList]            @StoreGUID    
      INSERT INTO [#MatTbl]   EXEC [prcGetMatsList] @MaterialGuid, @GroupGUID, -1, @MATCOND  
      INSERT INTO [#CostTbl]        EXEC [prcGetCostsList]        @CostGUID    
      IF (@CostGUID = 0X00)   
            INSERT INTO [#CostTbl] VALUES(0X00,0)   
      INSERT INTO [#mt]   
            SELECT [MatGUID],[mtSecurity],   
                  CASE @UseUnit    
                        WHEN 0 THEN 1    
                        WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END   
                        WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END   
                        WHEN 3 THEN   
                              CASE [DefUnit]    
                                    WHEN 1 THEN 1    
                                    WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END   
                                    WHEN 3 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END   
                              END   
                  END,   
                  CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END ,   
                  CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END,   
                  CASE @UseUnit    
                        WHEN 0 THEN 1    
                        WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE 2 END   
                        WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE 3 END   
                        ELSE   
                              [DefUnit]    
                  END   
            FROM [#MatTbl] AS [mt1] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [mt1].[MatGUID]    
         
	  Declare @Period Table([StartDate] [DATETIME], [EndDate] [DATETIME])

	  IF @TypeGroup = 1 -- weekly:
		INSERT INTO @Period SELECT [StartDate],[EndDate] FROM [dbo].[fnGetPeriod]( 2, @StartDate, @EndDate)

      CREATE TABLE #BILL (  
            [FixedCurrencyFactor]   FLOAT,  
            [biCostPtr]             UNIQUEIDENTIFIER,  
            [biPrice]         FLOAT,  
            [biUnity]         FLOAT,  
            [biStoreptr]            UNIQUEIDENTIFIER,  
            [btBillType]            INT,  
            [buSecurity]            INT,  
            [BtType]          INT,  
            [buIsPosted]            INT,  
            [biQty]           FLOAT,  
            [biBonusQnt]            FLOAT,  
            [biExtra]         FLOAT,  
            [biDiscount]            FLOAT,  
            [biBonusDisc]           FLOAT,  
            [biVat]           FLOAT,  
            [buExtra]         FLOAT,  
            [buDiscount]            FLOAT,  
            [buVat]           FLOAT,  
            [buDate]          DATETIME,  
            [buType]          UNIQUEIDENTIFIER,  
            [buGuid]          UNIQUEIDENTIFIER,  
            [biMatPtr]        UNIQUEIDENTIFIER,  
            [discExtra]             FLOAT,  
            [btSec]           INT,  
            [ReadPrc]         INT, 
            [UserGuid]        UNIQUEIDENTIFIER,
			[TotalDiscountPercent] FLOAT,
			[TotalExtraPercent] FLOAT);  
      DECLARE @Criteria NVARCHAR(2000);  
      DECLARE @Sql        NVARCHAR(4000);  
      SET @Criteria = ''  
      Set @Sql = 'insert #BILL  
                        SELECT  
                                    [FixedCurrencyFactor],[biCostPtr],[biPrice],[biUnity],[biStoreptr], 
                                    [btBillType],[buSecurity],[BtType],[buIsPosted],   
                                    [biQty],[biBonusQnt],[biExtra],[biDiscount],[biBonusDisc],[biTotalTaxValue], 
                                    [buTotalExtra], [buTotalDisc], [buTotalTaxValue],  
                                    CAST ([buDate] as Date) as buDate,[buType],[buGuid],[biMatPtr],  
                                    CASE [buTotal] WHEN 0 THEN 0 ELSE ISNULL((SELECT SUM([diExtra] - [diDiscount]) FROM [vwdi] AS [di]   
                                    WHERE [di].[diParent] = [buGuid]),0)/[buTotal] END AS [discExtra],  
                                    CASE [buIsPosted] WHEN 1 THEN [Bt].[UserSecurity] ELSE [UnPostedSecurity] END  AS [btSec] ,  
                                    CASE WHEN  [bt].[UserReadPriceSecurity] >= [bu].[buSecurity] THEN 1 ELSE 0 END ReadPrc,[buUserGuid] , [FixedTotalDiscountPercent] , [FixedTotalExtraPercent]
                              FROM       [fn_bubi_Fixed]         (''' + Convert(NVARCHAR(40), @CurrPTR)      + ''') as [bu]  
                              INNER JOIN [#BillsTypesTbl] [Bt] ON [bu].[buType]   = [Bt].[TypeGuid]   
                              INNER JOIN [#CostTbl]       [co] ON [co].[CostGUID] = [biCostPtr] '  
                                
      IF @BillCond <> 0X00  
      BEGIN  
            DECLARE @CurrencyGUID UNIQUEIDENTIFIER  
            SET @Criteria = [dbo].[fnGetBillConditionStr](NULL, @BillCond, @CurrPTR)  
            IF @Criteria <> '' AND RIGHT ( RTRIM (@Criteria) , 4 ) ='<<>>'  
            BEGIN   
                  SET @Criteria = REPLACE(@Criteria ,'<<>>','')           
                  DECLARE @CFTableName NVARCHAR(255)  
                  Set @CFTableName = (SELECT CFGroup_Table From CFMapping000 Where Orginal_Table = 'bu000' )  
                  SET @SQL = @SQL + ' INNER JOIN ['+ @CFTableName +'] ON [bu].[buGuid] = ['+ @CFTableName +'].[Orginal_Guid] '                 
            END  
      END  
      SET @Sql = @Sql + ' WHERE   
                  [buDate] BETWEEN ''' + Convert(NVARCHAR(40), @StartDate) + ''' AND ''' + Convert(NVARCHAR(40), @EndDate) + '''  
                  AND ([bu].[buIsPosted] = ' + Convert(NVARCHAR(40), @PostedValue) + ' OR ' + Convert(NVARCHAR(40), @PostedValue) + ' = -1)'  
      IF @Criteria <> ''   
      BEGIN  
            SET @Criteria = ' AND (' + @Criteria + ')'  
            SET @Sql = @Sql + @Criteria  
      END  
      EXEC (@Sql)  
        
      CREATE TABLE [#T_Result](   
                        [TypeGuid]        [UNIQUEIDENTIFIER] ,   
                        [btName]          [NVARCHAR](256) COLLATE ARABIC_CI_AI,    
                        [btLatinName]     [NVARCHAR](256) COLLATE ARABIC_CI_AI,    
                        [buBillType] [int],    
                        [buDate] [DateTime] ,[StartDate] [DateTime] ,[EndDate] [DateTime] ,    
                        [buTotal] [FLOAT],  
                        [buExtra] [FLOAT],  
                        [buDiscount] [FLOAT],  
                        [buVat] [FLOAT],  
                        [Security] [INT],[UserSecurity] [INT] ,[btType] [INT],[stSecurity] [INT],[MatSecurity]     [INT],[Qty] [FLOAT],[FLAG] [INT],[USER]   [UNIQUEIDENTIFIER])    
      DECLARE @Type     UNIQUEIDENTIFIER   
      SELECT @Type = b.[TypeGuid] FROM [#BillsTypesTbl] [b] INNER JOIN [bt000] bt ON b.[TypeGuid] = bt.Guid AND bt.Type = 2 AND [SortNum] = 2   
      IF @Type IS NOT NULL   
      BEGIN   
            EXEC prcCalcEPBill @StartDate,@EndDate,@CurrPtr,@CostGUID,@StoreGuid,@PriceType,@PricePolicy,@PostedValue,@CurVal,@UseUnit         
            INSERT INTO #bill([FixedCurrencyFactor],[biCostPtr],[biPrice] ,[biUnity],[biStoreptr],[btBillType],[buSecurity],[BtType],[buIsPosted],   
            [biQty],[biBonusQnt],[biExtra],[biDiscount],[biBonusDisc],[biVat], 
            [buExtra], [buDiscount], [buVat], 
            [buDate],[buType],[buGuid],[biMatPtr], [discExtra], [btSec],ReadPrc ,[TotalDiscountPercent], [TotalExtraPercent])   
            SELECT 1,0X00,q.[Price] * [mtUnitFact],M.[DefUint],[stGUID],5,0,2,0,q.qty,[Bonus],0,0,0,0, 0, 0, 0, @EndDate,@Type,0X00,m.[MatGUID],0,0,1 ,q.TotalDiscountPercent ,q.TotalExtraPercent   
            FROM    
            #QTYS q INNER JOIN [#mt] M ON m.[MatGUID] = q.[MatGUID]   
      END   
       
      CREATE TABLE #PERID2 (STARTDATE DATETIME, ENDDATE DATETIME) 
      DECLARE @DATE1 DATETIME, @DATE2 DATETIME 
      IF @TypeGroup = 0 
      BEGIN  
            SET @DATE1 = @STARTDATE 
            WHILE (@DATE1 <= @ENDDATE) 
            BEGIN 
                  SET @DATE2 = DATEADD(HH, 23, DATEADD(MI, 59, @DATE1)) 
                  IF @DATE2 > @ENDDATE 
                        SET @DATE2 = @ENDDATE 
                  INSERT INTO #PERID2 VALUES(@DATE1, @DATE2) 
                  SET @DATE1 = DATEADD(DD, 1, @DATE1) 
            END 
      END 
       
      IF @TypeGroup = 1
            INSERT INTO [#T_Result]([TypeGuid] ,[buBillType], [buDate],[StartDate],[EndDate], [buTotal], [buExtra], [buDiscount], [buVat], [Security],[UserSecurity],[btType],[stSecurity],[MatSecurity],[Qty],[FLAG],[USER] )     
                  SELECT       
                        [buType],[bu].[btBillType],[bu].[buDate],    
                        [P].[StartDate],
                        [P].[EndDate],
                        SUM([FixedCurrencyFactor] * ReadPrc * (([bu].[biPrice]*[bu].[biQty] /CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)  + [biExtra]- [biDiscount] - [biBonusDisc]) + [TotalExtraPercent]- [TotalDiscountPercent] ), 
                        SUM([FixedCurrencyFactor] * ReadPrc *[bu].[biExtra]),  
                        SUM([FixedCurrencyFactor] * ReadPrc * [bu].[biDiscount]),  
                        SUM([FixedCurrencyFactor] * ReadPrc * [bu].[biVat]), 
                        [bu].[buSecurity],btSec,   
                        [bu].[BtType],[st].[Security],[mt].[mtSecurity],SUM(([biQty] + [biBonusQnt])/[mt].[mtUnitFact]),0 , [bu].[UserGuid]    
                  FROM #bill AS  [bu]    
                  INNER JOIN [#StoreTbl] [ST] ON   [ST].[StoreGuid] = [bu].[biStoreptr]
                  INNER JOIN [#mt] AS [mt] ON [mt].[MatGUID] = [bu].[biMatPtr]
				  INNER JOIN @Period AS [P] ON [bu].[buDate] between [P].[StartDate] and [P].[EndDate]
                  GROUP BY     
                        [buType],[bu].[btBillType],[bu].[buDate],[P].[StartDate],[P].[EndDate],
                        [bu].[buSecurity],[BtSec],[bu].[BtType],[st].[Security],[mt].[mtSecurity],[bu].[buIsPosted], [bu].[UserGuid] 
          ELSE  IF @TypeGroup = 2                                     
            INSERT INTO [#T_Result] ([TypeGuid] ,[buBillType], [buDate],[StartDate],[EndDate] ,[buTotal], [buExtra], [buDiscount], [buVat], [Security],[UserSecurity],[btType],[stSecurity],[MatSecurity],[Qty],[FLAG],[USER] )     
                  SELECT       
                        [buType],[bu].[btBillType],[bu].[buDate],    
                        [p].[STARTDATE],   
                        [p].[ENDDATE],   
                        SUM([FixedCurrencyFactor]  * ReadPrc * (([bu].[biPrice]*[bu].[biQty] /CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)  + [biExtra] - [biDiscount] - [biBonusDisc] )+ [TotalExtraPercent]- [TotalDiscountPercent] ), 
                        SUM([FixedCurrencyFactor] * ReadPrc *[bu].[biExtra]),  
                        SUM([FixedCurrencyFactor] * ReadPrc * [bu].[biDiscount]),  
                        SUM([FixedCurrencyFactor] * ReadPrc * [bu].[biVat]), 
                        [bu].[buSecurity],btSec,   
                        [bu].[BtType],[st].[Security],[mt].[mtSecurity],SUM(([biQty] + [biBonusQnt])/[mt].[mtUnitFact]),0, [bu].[UserGuid]      
            FROM #bill AS [bu]   
                  INNER JOIN [fnGetStrToPeriod](@STR )AS [p] ON [buDate] BETWEEN [p].[STARTDATE] AND [p].[ENDDATE]   
                  INNER JOIN [#StoreTbl] [ST] ON   [ST].[StoreGuid] = [bu].[biStoreptr]   
                  INNER JOIN [#mt] AS [mt] ON [mt].[MatGUID] = [bu].[biMatPtr]    
                  WHERE     
                              [buDate] BETWEEN @StartDate AND @EndDate     
                              AND ([bu].[buIsPosted]=@PostedValue OR @PostedValue=-1)  
                  GROUP BY    [buType],[bu].[btBillType],[bu].[buDate],[BtType],   
                                    [p].[STARTDATE],   
                                    [p].[ENDDATE]   
                                    ,[bu].[buSecurity],[BtSec]     
                                    ,[st].[Security],[mt].[mtSecurity],[bu].[buIsPosted], [bu].[UserGuid]   
          ELSE     
                  INSERT INTO [#T_Result] ([TypeGuid] ,[buBillType],[StartDate],[EndDate] ,[buTotal], [buExtra], [buDiscount], [buVat], [Security],[UserSecurity],[btType],[stSecurity],[MatSecurity],[Qty],[FLAG],[USER] ) 
                        SELECT  
                              [buType], [bu].[btBillType], [PR].[STARTDATE], [PR].[ENDDATE], 
                              SUM([FixedCurrencyFactor]  * ReadPrc * (([bu].[biPrice]*[bu].[biQty] /CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)  + [biExtra] - [biDiscount] - [biBonusDisc] )+ [TotalExtraPercent]- [TotalDiscountPercent] ), 
                              SUM([FixedCurrencyFactor] * ReadPrc *[bu].[biExtra]),  
                              SUM([FixedCurrencyFactor] * ReadPrc * [bu].[biDiscount]),  
                              SUM([FixedCurrencyFactor] * ReadPrc * [bu].[biVat]), 
                              [bu].[buSecurity],[BtSec],   
                              [bu].[BtType],[st].[Security],[mt].[mtSecurity],SUM(([biQty] + [biBonusQnt])/[mt].[mtUnitFact]),0 , [bu].[UserGuid]    
                        FROM #bill AS [bu]   
                        INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGuid]=[bu].[biStoreptr]    
                        INNER JOIN [#mt]       AS [mt] ON [mt].[MatGUID] = [bu].[biMatPtr]    
                        INNER JOIN #PERID2     AS [PR] ON [BU].[BUDATE] BETWEEN [PR].[STARTDATE] AND [PR].[ENDDATE]  
                        GROUP BY [buType], [bu].[btBillType], [PR].[STARTDATE], [PR].[ENDDATE],  
                                     [bu].[buSecurity], [BtSec], [bu].[BtType], [st].[Security],  
                                     [mt].[mtSecurity],[bu].[buIsPosted], [bu].[UserGuid] 
         
      EXEC  [prcCheckSecurity] @Result = '#T_Result'   
       
      INSERT INTO [#T_Result]([TypeGuid],[btName],[btLatinName],[btType],[buBillType],[Flag])   
            SELECT DISTINCT [bt].[Guid],[Name],CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END,[Type],[BillType],-1    
            FROM [bt000] AS [bt] INNER JOIN [#T_Result] AS [r] ON [bt].[Guid] = [r].[TypeGuid]   
          
      UPDATE [#T_Result] SET [buBillType] = 6 WHERE ([btType] = 3) 
      UPDATE [#T_Result] SET [buBillType] = 7 WHERE ([btType] = 4) 
      SET ANSI_WARNINGS  OFF 
      IF (@USERGuid <> 0X00)  
      BEGIN 
            DELETE [#T_Result] WHERE [USER] <> @USERGuid 
      END 
       IF (@ShowPrev <> 0) 
    begin 
            declare  @PrvDate DateTime 
                  set @PrvDate = @StartDate-1 
                  --exec  prcCallQnt @PrvDate , @MaterialGuid , @GroupGUID , @StoreGuid , @StoreGuid ,@SrcTypesGuid ,@UseUnit 
                  
                  exec prcCallQnt '1/1/1980 0:0:0.0', --@StartDate
                             @PrvDate,--@PrvDate, --@EndDate
                             @MaterialGuid,  --@MatGUID
                              @GroupGUID, --@GroupGUID
                              @StoreGuid, --@StoreGUID
                              @CostGUID,
                              0, --@MatType 0 Store or 1 Service or -1 ALL 
                              @CurrPtr, --@CurrencyGUID
                              @CurVal, --@CurrencyVal
                              0, --@DetailsStores 1 show details 0 no details 
                              0,  --@ShowEmpty 1 Show Empty 0 don't Show Empty 
                              0x0,  --@SrcTypesguid
                              @PriceType, --@PriceType
                              @PricePolicy, --@PricePolicy
                              0,  --@SortType
                              0, --@ShowUnLinked
                              0, --@ShowGroups
                              0, --@CalcPrices
                              @UseUnit, --@UseUnit
                              498, --@ShowMtFldsFlag
                              0, --@StLevel
                              0, --@DetCostPrice
                              0, --@Lang
                              0, --@ClassDtails
                              1, --@ShowPrice
                              @MATCOND,  --@MatCondGuid
                              0, --@ShowBalancedMat
                              '',--@VeiwCFlds
                              '' --@Class
    end 
      SELECT  
                  [TypeGuid] [TypeGuid], 
                  [buBillType] [buBillType], 
                  SUM([buTotal]) [buTotal], 
                  SUM([Qty]) [buQty], 
                SUM([buExtra]) AS [buTotalExtra], 
                  SUM([buDiscount])  [buTotalDiscount], 
                  SUM([buVat]) [buTotalVat],  
                [StartDate]  [StartDate], 
                  [EndDate] AS [EndDate], 
                  [Flag] [Flag], 
                   [btName]  [btName], 
                   [btLatinName] [btLatinName] 
      FROM [#T_Result]    
      GROUP BY [Flag],[StartDate],[EndDate],[buBillType], [TypeGuid],[btName],[btLatinName]    
      ORDER BY [Flag],[StartDate],[buBillType],[TypeGuid]    
      SELECT * FROM [#SecViol]  
      SET ANSI_WARNINGS  ON 
/* 
      prcConnections_add2 '?I??' 
      exec  [repSummuryOfDialyMove] '12/31/2006', '1/1/2008', '3766ff97-a4b7-4e54-8bfb-033a3b2800f8', '00000000-0000-0000-0000-000000000000', 'e8e66a6e-2262-4dd2-bd71-e63fe58a8eba', 1, 0, '', 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000' 
*/ 
####################################################
#END