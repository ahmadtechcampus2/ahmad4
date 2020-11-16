############################################################## 
CREATE PROCEDURE prcCallQnt 
      @StartDate                    [DATETIME], 
      @EndDate                      [DATETIME], 
      @MatGUID                      [UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
      @GroupGUID                    [UNIQUEIDENTIFIER], 
      @StoreGUID                    [UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores 
      @CostGUID                     [UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
      @MatType                      [INT], -- 0 Store or 1 Service or -1 ALL 
      @CurrencyGUID                 [UNIQUEIDENTIFIER], 
      @CurrencyVal                  [FLOAT], 
      @DetailsStores                [INT], -- 1 show details 0 no details 
      @ShowEmpty                    [INT], --1 Show Empty 0 don't Show Empty 
      @SrcTypesguid                 [UNIQUEIDENTIFIER], 
      @PriceType                    [INT], 
      @PricePolicy                  [INT], 
      @SortType                     [INT] = 0, -- 0 NONE, 1 matCode, 2MatName, 3Store 
      @ShowUnLinked                 [INT] = 0, 
      @ShowGroups                   [INT] = 0, -- if 1 add 3 new  columns for groups 
      @CalcPrices                   [INT] = 1, 
      @UseUnit                      [INT], 
      @ShowMtFldsFlag               [BIGINT] = 0, 
      @StLevel                      [INT] = 0, 
      @DetCostPrice                 [INT] = 0, 
      @Lang                         [INT] =0, 
      @ClassDtails                  [BIT] = 0, 
      @ShowPrice                    [BIT] = 1, 
      @MatCondGuid                  [UNIQUEIDENTIFIER] = 0x00, 
      @ShowBalancedMat        [BIT] = 1, 
      @VeiwCFlds                    NVARCHAR (max) = '',    -- New Parameter to check veiwing of Custom Fields                            
      @Class                              NVARCHAR(255) = ''       
AS  
      SET NOCOUNT ON  
      DECLARE @Zero FLOAT 
      SET @Zero = dbo.fnGetZeroValueQTY() 
      -- Creating temporary tables  
      CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
      CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
      CREATE TABLE [#StoreTbl](     [StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
      CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER])  
      CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
      CREATE TABLE [#t_Prices2]  
      (  
            [mtNumber] [UNIQUEIDENTIFIER],  
            [APrice]    [FLOAT],  
            [stNumber]  [UNIQUEIDENTIFIER]  
      )  
      CREATE TABLE [#t_Prices]  
      (  
            [mtNumber] [UNIQUEIDENTIFIER],  
            [APrice]    [FLOAT]  
      )  
	  CREATE TABLE [#GR] ([Guid] [UNIQUEIDENTIFIER])  
      --Filling temporary tables  
      INSERT INTO [#MatTbl]         EXEC [prcGetMatsList]         @MatGUID, @GroupGUID, @MatType,@MatCondGuid  
      INSERT INTO [#StoreTbl]       EXEC [prcGetStoresList]       @StoreGUID  
      INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList]     @SrcTypesguid  
      INSERT INTO [#CostTbl]        EXEC [prcGetCostsList]        @CostGUID  
      DECLARE @MatSecBal INT   
      SET @MatSecBal = [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]())  
      if @MatSecBal <= 0  
            RETURN  
      DECLARE @Admin [INT], @MinSec [INT],@UserGuid [UNIQUEIDENTIFIER],@cnt [INT]  
      SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()  
      SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )  
      IF @Admin = 0  
      BEGIN  
            SET @MinSec = [dbo].[fnGetMinSecurityLevel]()  
            INSERT INTO [#GR] SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)  
            DELETE [r] FROM [#GR] AS [r] INNER JOIN fnGroup_HSecList() AS [f] ON [r].[gUID] = [f].[GUID] where [f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)  
            DELETE [m] FROM [#MatTbl] AS [m]  
            INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid]   
            WHERE [mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid)   
            OR [Groupguid] NOT IN (SELECT [Guid] FRoM [#Gr])  
            SET @cnt = @@ROWCOUNT  
            IF @cnt > 0  
                  INSERT INTO [#SecViol] values(7,@cnt)  
              
      END     
      CREATE TABLE [#SResult]  
      (  
            [biMatPtr]              [UNIQUEIDENTIFIER],  
            [biQty]                 [FLOAT],  
            [biQty2]                [FLOAT],  
            [biQty3]                [FLOAT],  
            [biStorePtr]            [UNIQUEIDENTIFIER],  
            [Security]              [INT],  
            [UserSecurity]          [INT],  
            [MtSecurity]            [INT],  
            [biClassPtr]            [NVARCHAR](255) COLLATE Arabic_CI_AI,  
            [APrice]                [FLOAT],  
            [StSecurity]            [INT] , 
            [bMove]                       [TINYINT] 
      )  

            INSERT INTO [#SResult]  
            SELECT  
                  [r].[biMatPtr],  
                  SUM(([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection]),  
                  SUM([r].[biQty2]* [r].[buDirection]),  
                  SUM([r].[biQty3]* [r].[buDirection]),  
                  CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,  
                  [r].[buSecurity],  
                  [bt].[UserSecurity],  
                  [mtTbl].[MtSecurity],  
                  CASE @ClassDtails WHEN 1 THEN [biClassPtr] ELSE '' END,0,  
                  [st].[Security],1 
            FROM  
                  [vwbubi] AS [r]  
                  INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]  
                  INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
                  INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]  
            WHERE  
                  [budate] BETWEEN @StartDate AND @EndDate  
                  AND((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))  
                  AND [buIsPosted] > 0  
                  AND ( @Class = '' OR @Class =[biClassPtr] )  
            GROUP BY  
                  [r].[biMatPtr],  
                  CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,  
                  [r].[buSecurity],  
                  [bt].[UserSecurity],  
                  [mtTbl].[MtSecurity],  
                  CASE @ClassDtails WHEN 1 THEN [biClassPtr] ELSE '' END,  
                  [st].[Security]  
       
               
            IF @Admin = 0  
                  UPDATE [#SResult] SET   [Security]  = @MinSec  
            IF @ShowUnLinked = 1  
                  UPDATE [bi] SET   
                        [biQty2] = (CASE [mt].[Unit2FactFlag] WHEN 0 THEN CASE [mt].[Unit2Fact] WHEN 0 THEN 0 ELSE [bi].[biQty] /  [mt].[Unit2Fact] END ELSE [bi].[biQty2] END),  
                        [biQty3] = (CASE [mt].[Unit3FactFlag] WHEN 0 THEN CASE [mt].[Unit3Fact] WHEN 0 THEN 0 ELSE [bi].[biQty] /  [mt].[Unit3Fact] END ELSE [bi].[biQty3] END)  
                  FROM [#SResult] AS [bi] INNER JOIN [mt000] AS [mt]  ON  [mt].[Guid] = [bi].[biMatPtr]  
                    
      
 
      IF    @ShowBalancedMat = 0 
            DELETE  [#SResult] WHERE ABS([biQty]) < @Zero AND [bMove] = 1 
      
      EXEC [prcCheckSecurity] @Result = '#SResult'  
      
      CREATE TABLE [#R]  
      (  
            [StoreGUID]       [UNIQUEIDENTIFIER],  
            [mtNumber]        [UNIQUEIDENTIFIER],  
            [mtQty]                 [FLOAT],  
            [Qnt2]                  [FLOAT],  
            [Qnt3]                  [FLOAT],  
            [APrice]          [FLOAT],  
            [StCode]          [NVARCHAR](255) COLLATE ARABIC_CI_AI,  
            [StName]          [NVARCHAR](255) COLLATE ARABIC_CI_AI,  
            [stLevel]         [INT],  
            [ClassPtr]        [NVARCHAR](255) COLLATE ARABIC_CI_AI,  
            [id]              [INT] DEFAULT 0,  
            [mtUnitFact]      [FLOAT] DEFAULT 1,  
            [MtGroup]         [UNIQUEIDENTIFIER],  
            [RecType]         [NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
            [grLevel]         [INT],  
            [mtName]          [NVARCHAR](255) COLLATE ARABIC_CI_AI,  
            [mtCode]          [NVARCHAR](255) COLLATE ARABIC_CI_AI,  
            [mtLatinName]           [NVARCHAR](255) COLLATE ARABIC_CI_AI,  
             
            [Move]            INT 
              
      )  

      IF @ShowPrice > 0  
      BEGIN  
            IF @MatType >= 3  
                  SET @MatType = -1  
            IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
            BEGIN  
                  EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,    @CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0  
            END  
            ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
            BEGIN  
                  EXEC [prcGetMaxPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,    @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, 0  
            END  
            ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @DetCostPrice = 0 -- COST And AvgPrice NO STORE DETAILS  
            BEGIN  
                  EXEC [prcGetAvgPrice]   @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,  @ShowUnLinked, 0  
            END  
            ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @DetCostPrice = 1 -- COST And AvgPrice  STORE DETAILS  
            BEGIN  
                  EXEC [prcGetAvgPrice_WithDetailStore]     @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,      @ShowUnLinked, 0  
            END  
            ELSE IF @PriceType = -1  
                  INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]  
              
            ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount  
            BEGIN  
                  EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,    @CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, 0 /*@CalcLastCost*/,      1 /*@ProcessExtra*/  
            END  
            ELSE IF @PriceType = 2 AND @PricePolicy = 125  
                  EXEC [prcGetFirstInFirstOutPrise] @StartDate , @EndDate,@CurrencyGUID     
            ELSE IF @PriceType = 2 AND @PricePolicy = 130  
            BEGIN  
                  INSERT INTO [#t_Prices]  
                  SELECT   
                        [r].[biMatPtr],SUM([FixedBiTotal])/SUM([biQty] + [biBonusQnt])  
                  FROM  
                        [fnExtended_bi_Fixed](@CurrencyGUID) AS [r]  
                        INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]  
                        INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
                        INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]  
                  WHERE  
                        [budate] BETWEEN @StartDate AND @EndDate AND [BtBillType] = 0  
                        AND((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))  
                        AND [buIsPosted] > 0   
                  GROUP BY [r].[biMatPtr]  
            END  
            ELSE  
            BEGIN  
                  DECLARE @UnitType INT 
                  SET @UnitType = CASE @UseUnit WHEN 5 THEN 0 ELSE @UseUnit END 
                  EXEC [prcGetMtPrice] @MatGUID,      @GroupGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, @ShowUnLinked, @UnitType 
            END  
              
            IF (@DetCostPrice = 1)  
                  UPDATE [r] SET [APrice] = [p].[APrice] FROM [#SResult] AS [r] INNER JOIN [#t_Prices2] AS [p] ON [stNumber]= [biStorePtr] AND [mtNumber] =[biMatPtr]  
            ELSE  
                  UPDATE [r] SET [APrice] = [p].[APrice] FROM [#SResult] AS [r] INNER JOIN [#t_Prices] AS [p] ON [mtNumber] =[biMatPtr]  
      END  
       
      INSERT INTO [#R] ([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[StCode],[StName],[stLevel],[ClassPtr],[id],[Move])        
            SELECT [biStorePtr],[biMatPtr],SUM([biQty]),SUM([biQty2]),SUM([biQty3]),ISNULL([APrice],0),ISNULL([stCode],''),ISNULL([stName],''),0,[biClassPtr],0,MAX([bMove])  
            FROM [#SResult] AS [r] LEFT JOIN  
            (SELECT [Guid],[Code] AS [stCode], CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [stName] FROM [st000]) AS [st] ON [st].[Guid] = [biStorePtr]  
            GROUP BY [biStorePtr], [biMatPtr], [APrice], ISNULL([stCode],''), ISNULL([stName],''), [biClassPtr]  
      IF @ShowBalancedMat = 0 
            DELETE [#R] WHERE ABS([mtQty])< @Zero AND [Move] > 0 
       
      DECLARE @Level [INT]  
      DECLARE @FldStr [NVARCHAR](3000)  
      SET @FldStr = ''  
      DECLARE @SqlStr [NVARCHAR](4000)  
      DECLARE @Str [NVARCHAR](3000)  
      
       SELECT SUM(
      r.mtQty/
      (
            CASE @UseUnit 
                  WHEN 0 THEN CASE mtunitFact WHEN 0 THEN 1 ELSE  mtunitFact END
                  WHEN 1 THEN CASE mtunit2Fact WHEN 0 THEN 1 ELSE  mtunit2Fact END
                  WHEN 2 THEN CASE mtunit3Fact WHEN 0 THEN 1 ELSE  mtunit3Fact END  
                  WHEN 3 THEN CASE mtunitFact WHEN 0 THEN 1 ELSE  mtunitFact END
            END 
            )
            ) Qnt, SUM(APrice*r.mtQty) Price
      
       from  [#R] AS [r] INNER JOIN [vwmtgr] AS [v_mt] ON [r].[mtNumber] = [v_mt].[mtGUID] 
       
      -----------------------------------------------------

        
/*  
prcConnections_add2 '?I??'  
EXEC  [prcCallPricesProcs2] '1/1/2010 0:0:0.0', '3/9/2010 23:59:41.398', '00000000-0000-0000-0000-000000000000', 'fabcf3a7-ea80-410b-809b-25940491636d', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, '4d5ef24b-7b12-41c0-abcf-e701fb5dfd40', 1.000000, 1, 1, '00000000-0000-0000-0000-000000000000', 2, 122, 0, 0, 1, 1, 3, 498, 5, 0, 0, 0, 1, '62752976-04e5-4546-becc-b9be08ab239b', 1, '', '' 
*/  

############################################################## 
#END