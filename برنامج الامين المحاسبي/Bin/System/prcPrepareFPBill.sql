#########################################################
CREATE  PROCEDURE prcTrMatSN
AS
	DECLARE @CNT INT
	
	CREATE TABLE [#Result]
	(
		--[SN] 						[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[Id]						[INT] IDENTITY(1,1),
		[MatPtr]					[UNIQUEIDENTIFIER] ,
		[MtName]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[biStorePtr]				[UNIQUEIDENTIFIER] ,
		[stName]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buNumber]					[UNIQUEIDENTIFIER] ,
		[biPrice]					[FLOAT],
		[Security]					[INT],
		[UserSecurity] 				[INT],
		[UserReadPriceSecurity]		[INT],
		[BillNumber]				[FLOAT],
		[buDate]					[DATETIME],
		[buType]					[UNIQUEIDENTIFIER],
		[buBranch]					[UNIQUEIDENTIFIER],
		[buCust_Name]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buCustPtr]					[UNIQUEIDENTIFIER],
		[biCostPtr]					[UNIQUEIDENTIFIER],
		[MatSecurity] 				[INT],
		[biGuid]					[UNIQUEIDENTIFIER],
		[buDirection]				[INT],
		[Type]						TINYINT
	)
	SELECT [StoreGuid], [s].[Security], [st].[Name]  [stName] INTO [#StoreTbl2] FROM [#StoreTbl] AS [s] INNER JOIN  [st000] AS [st] ON  [st].[Guid] = 	[StoreGuid]
	SELECT [MatGuid]  , [m].[mtSecurity],[mt].[Name] AS [MtName],[mt].[Type]  INTO [#MatTbl2] FROM [#MatTbl] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [MatGuid] WHERE [mt].[snFlag] = 1
	
	INSERT INTO [#Result]
	(
		[MatPtr],[MtName],[biStorePtr],[stName],[buNumber],				
		[biPrice],[Security],[UserSecurity],			
		[UserReadPriceSecurity],[BillNumber],			
		[buDate],[buType],[buBranch],[buCust_Name],			
		[buCustPtr],[biCostPtr],[MatSecurity],[biGuid],[buDirection],[Type]			
	)
	SELECT
		--[sn].[SN],
		[mtTbl].[MatGuid],
		[mtTbl].[MtName],
		[bu].[biStorePtr],
		[st].[stName],
		[bu].[buGUID],
		CASE WHEN [UserReadPriceSecurity] >= [bu].[BuSecurity] THEN [bu].[biPrice] ELSE 0 END,
		[buSecurity],
		[bt].[UserSecurity],
		[bt].[UserReadPriceSecurity],
		[buNumber],
		[buDate],
		[buType],
		[buBranch],
		[buCust_Name],
		0X00,
		[biCostPtr],
		[mtTbl].[mtSecurity],[biGuid],[buDirection],[Type]
	FROM
		--[SN000] AS [sn] 
		[vwBUbi] AS [bu] --ON [bu].[biGUID] = [sn].[InGuid]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [bu].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [bu].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGuid] = [bu].[biStorePtr]
	WHERE
		 [bu].[buIsPosted] != 0
	ORDER BY
		[buDate],[buSortFlag],[buNumber]
	---check sec
	
	SELECT  MAX(CASE [buDirection] WHEN -1 then 0 else [Id] end) AS [ID] ,SUM([buDirection]) AS cnt ,[SN],[MatPtr],[r].[biStorePtr]
	INTO [#Isn] 
	FROM [vcSNs] AS [sn] INNER JOIN [#Result] [r] ON [sn].[biGuid] = [r].[biGuid]
	GROUP BY [SN],[MatPtr],[r].[biStorePtr]
	HAVING SUM([buDirection]) > 0
	
	IF EXISTS(SELECT * FROM [#Isn] WHERE [cnt] > 1)
	BEGIN
		SET @CNT = 1 
		WHILE (@CNT > 0)
		BEGIN
			INSERT INTO [#Isn] SELECT  MAX([R].[Id]) ,1 ,[sn].[SN],[R].[MatPtr],[R].[biStorePtr]  FROM [vcSNs] AS [sn] 
			INNER JOIN [#Result] [R] ON [sn].[biGuid] = [R].[biGuid] 
			INNER JOIN [#Isn] I ON [sn].[SN] = [I].[SN]  AND [R].[MatPtr] = [i].[MatPtr] AND [i].[biStorePtr] = [r].[biStorePtr]
			WHERE [R].[ID] NOT IN ( SELECT [ID] FROM [#Isn]) and [cnt] > 1
			GROUP BY [sn].[SN],[R].[MatPtr],[r].[biStorePtr]
			UPDATE [#Isn] SET [cnt] = [cnt] - 1 WHERE [cnt] > 1
			SET @CNT = @@ROWCOUNT
			
		END
	END
	INSERT INTO [#Isn] 
	SELECT  MAX(CASE [buDirection] WHEN 1 then 0 else [Id] end) AS [ID] ,SUM([buDirection]) AS cnt ,[SN],[MatPtr],[r].[biStorePtr]
	FROM [vcSNs] AS [sn] INNER JOIN [#Result] [r] ON [sn].[biGuid] = [r].[biGuid]
	WHERE [Type] = 2
	GROUP BY [SN],[MatPtr],[r].[biStorePtr]
	HAVING SUM([buDirection]) < 0
	
	--- Return first Result Set -- needed data
	SELECT
		[SN].[SN],
		[r].[MatPtr],
		[r].[MtName],
		[r].[biStorePtr],
		[r].[StName],
		[r].[buType],
		[r].[buNumber],
		[r].[buCust_Name],
		[r].[buDate],
		[r].[biPrice],
		[r].[BillNumber],
		[r].[buBranch],
		[r].[biCostPtr],
		cnt
	FROM
		[#Result] AS [r] INNER JOIN [#ISN] AS [SN] ON [sn].[Id] = [r].[Id]
	ORDER BY
		[r].[MatPtr],
		LEN([sn].[SN]),
		[sn].[SN]
#########################################################
CREATE PROCEDURE prcPrepareFPBill
	@ProcessExpireDate		[INT], 
	@EveryBranchHasBill		[INT], 
	@EveryBranchHasPrice	[INT], 
	@CurrencyGUID 			[UNIQUEIDENTIFIER], 
	@CurrencyVal 			[FLOAT], 
	@PriceType 				[INT], 
	@PricePolicy 			[INT],
	@PriceForStore			[INT] = 0, 
	@CostAsset				[BIT] = 0, 
	@HaveCost				[BIT] = 0, 
	@InBillSNPrice			[BIT] = 0 ,
	@DetailCategory			[BIT] = 0
AS  
-- بضاعة أول المدة لكل فرع معالجة في حالة تاريخ صلاحية  
-- سعر وسطي لكل فرع   
	SET NOCOUNT ON  
	CREATE TABLE [#MatTbl]([MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], Security [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])  
	CREATE TABLE [#t_Prices]( [mtNumber] [UNIQUEIDENTIFIER], [Branch] [UNIQUEIDENTIFIER], [APrice] [FLOAT],[StNumber] [UNIQUEIDENTIFIER])  
	CREATE TABLE [#t_Prices2]([mtNumber] [UNIQUEIDENTIFIER],[APrice] 	[FLOAT],[stNumber]	[UNIQUEIDENTIFIER])  
	  
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 			0x0/*@MatGUID*/, 0x0/*@GroupGUID*/, -1/*@MatType*/  
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 			0x0/*@CostGUID*/  
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		0x0/*@StoreGUID*/  
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	0x0/*@SrcTypesguid*/  
	 
	DECLARE @CurrentDate [DATETIME]  
	SELECT @CurrentDate = CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_EPDate'   
	  
	DECLARE @UserGUID 	[UNIQUEIDENTIFIER],  
			@BrGuid		[UNIQUEIDENTIFIER], 
			@CoGuid		[UNIQUEIDENTIFIER] 
	DECLARE @c	Cursor  
	SELECT @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	CREATE TABLE [#TRSN] 
	( 
		[SN] 			[NVARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[MatPtr]		[UNIQUEIDENTIFIER] , 
		[MtName]		[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		--[MtClassPtr]		[NVARCHAR] (256) COLLATE ARABIC_CI_AI,----------------------------- 
		[biStorePtr]	[UNIQUEIDENTIFIER], 
		[StName]	[NVARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buType]	[UNIQUEIDENTIFIER], 
		[buNumber]	[UNIQUEIDENTIFIER], 
		[buCust_Name]	[NVARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buDate]	[DATETIME], 
		[biPrice]	[FLOAT], 
		[BillNumber][FLOAT], 
		[buBranch]	[UNIQUEIDENTIFIER], 
		[biCostPtr][UNIQUEIDENTIFIER], 
		[CNT]		INT 
	) 
	CREATE TABLE [#BranchesQty]  
	(  
		[biMatPtr]				[UNIQUEIDENTIFIER],  
		[biStorePtr]			[UNIQUEIDENTIFIER],  
		[buBranch]				[UNIQUEIDENTIFIER],  
		[biExpireDate]			[DATETIME],  
		[mtExpireFlag]			[INT],  
		[Qnt]					[FLOAT],  
		[Qnt2]					[FLOAT],  
		[Qnt3]					[FLOAT],
		[MtClassPtr]		[NVARCHAR] (256) COLLATE ARABIC_CI_AI,----------------------------- 
		[CostGuid]				UNIQUEIDENTIFIER 
	)  
	  
	CREATE TABLE [#R]  
	(  
		[biMatPtr]				[UNIQUEIDENTIFIER],  
		[biStorePtr]			[UNIQUEIDENTIFIER],  
		[buBranch]				[UNIQUEIDENTIFIER],  
		[biExpireDate]			[DATETIME],  
		[mtExpireFlag]			[INT],  
		[Qnt]					[FLOAT],  
		[Qnt2]					[FLOAT],  
		[Qnt3]					[FLOAT],
		[MtClassPtr]		[NVARCHAR] (256) COLLATE ARABIC_CI_AI,-----------------------------  
		[CostGuid]				UNIQUEIDENTIFIER 
	)  
	CREATE TABLE [#Res]  
	(  
		[biMatPtr]			[UNIQUEIDENTIFIER],  
		[biStorePtr]		[UNIQUEIDENTIFIER],  
		[buBranch]			[UNIQUEIDENTIFIER],  
		[biExpireDate]		[DATETIME],  
		[Qnt]				[FLOAT],  
		[Qnt2]				[FLOAT],  
		[Qnt3]				[FLOAT],
		[MtClassPtr]		[NVARCHAR] (256) COLLATE ARABIC_CI_AI,-----------------------------  
		[FPAcc]				[UNIQUEIDENTIFIER],  
		[EPAcc]				[UNIQUEIDENTIFIER],  
		[AssPrice]			[FLOAT] DEFAULT 0,  
		[AssbiPrice]			[FLOAT] DEFAULT 0,  
		[Flag]				[INT] DEFAULT 0, 
		[CoGuid]			[UNIQUEIDENTIFIER]   
	)  
	CREATE TABLE [#TransferErrTbl]  
	(  
		[BillNum]		[UNIQUEIDENTIFIER],  
		[MatPtr]		[UNIQUEIDENTIFIER],  
		[StorePtr]		[UNIQUEIDENTIFIER],  
		[ExPireDate]	[DATETIME],  
		[Remaining]		[FLOAT],  
		[Qty]			[FLOAT], 
		[coGuid]		UNIQUEIDENTIFIER 
	)  
	  
	IF @EveryBranchHasBill = 1  
	BEGIN  
		INSERT INTO [#BranchesQty]  
		(  
			[biMatPtr],  
			[biStorePtr],  
			[buBranch],  
			[biExpireDate],  
			[mtExpireFlag],  
			[Qnt],  
			[Qnt2],  
			[Qnt3],
			[MtClassPtr],
			 
			[CostGuid]  
		)  
		SELECT   
			[biMatPtr],  
			[biStorePtr],  
			[buBranch],  
			'1/1/1980',  
			[mtExpireFlag],  
			ISNULL( SUM(([biQty] + [biBonusQnt])* [buDirection]), 0) ,  
			--SUM( BiQty /*biBiBillQty*/),  
			ISNULL( SUM( [biQty2] * [buDirection]), 0),  
			ISNULL( SUM( [biQty3] * [buDirection]), 0),
			--[biClassPtr],
			CASE @DetailCategory WHEN 1 THEN [biClassPtr] ELSE '' END,
			CASE @HaveCost WHEN 0 THEN 0X00 ELSE [biCostPtr] END  
		FROM   
			[vwExtended_bi]  
		WHERE   
			[buIsPosted] > 0 AND [mtType] = 0  AND ISNULL([biStoreptr], 0X0) <> 0X0 
			AND (@InBillSNPrice = 0 OR NOT( [mtSNFlag] = 1  AND [mtForceInSN] = 1))  
		GROUP BY  
			[biMatPtr],
			CASE @DetailCategory WHEN 1 THEN [biClassPtr] ELSE '' END, 
			[biStorePtr],  
			[buBranch],  
			[mtExpireFlag], 
			CASE @HaveCost WHEN 0 THEN 0X00 ELSE [biCostPtr] END   
		  
	END  
	IF @ProcessExpireDate = 1  
	BEGIN  
		CREATE TABLE [#ExpireMats]  
		(  
			[ID]			[INT],  
			[MatPtr]		[UNIQUEIDENTIFIER],  
			[MatCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[MatName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[Price]			[FLOAT],  
			[Qty]			[FLOAT],  
			[Qty2]			[FLOAT],  
			[Qty3]			[FLOAT],
			[MtClassPtr]	[NVARCHAR] (256) COLLATE ARABIC_CI_AI, ---------- 
			[ExpireDate]	[DATETIME],  
			[DATE]			[DATETIME],  
			[StorePtr]		[UNIQUEIDENTIFIER],  
			[Remaining]		[FLOAT],  
			[Remaining2]	[FLOAT],  
			[Remaining3]	[FLOAT],  
			[MatUnitName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[BillType]		[UNIQUEIDENTIFIER],  
			[BillNum]		[UNIQUEIDENTIFIER],  
			[BillNotes]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[Age]			[INT], 
			[coGuid]		UNIQUEIDENTIFIER  DEFAULT 0X00 
		)  
		IF @EveryBranchHasBill = 1  
			INSERT INTO [#R] SELECT * FROM [#BranchesQty] WHERE [mtExpireFlag] = 0  
		ELSE  
		BEGIN  
			INSERT INTO [#R]  
			SELECT  
				[biMatPtr],  
				[biStorePtr],  
				0x0,--buBranch,  
				'1/1/1980',  
				[mtExpireFlag],  
				ISNULL( SUM(([biQty] + [biBonusQnt])* [buDirection]), 0) ,  
				--ISNULL(SUM( biQty * buDirection), 0) AS Qnt,  
				ISNULL( SUM( bi.[biQty2] * [buDirection]), 0) ,  
				ISNULL( SUM( bi.[biQty3] * [buDirection]), 0) ,
				--[biClassPtr],
				CASE @DetailCategory WHEN 1 THEN [biClassPtr] ELSE '' END,
				
				CASE @HaveCost WHEN 0 THEN 0X00 ELSE [biCostPtr] END   
			FROM  
				[vwExtended_bi] AS [bi]  
			WHERE  
				[mtExpireFlag] = 0  
				AND [bi].[buIsPosted] > 0   
				AND [mtType] = 0  
				AND ISNULL([biStoreptr], 0X0) <> 0X0  
				AND (@InBillSNPrice = 0 OR NOT( [bi].[mtSNFlag] = 1  AND [bi].[mtForceInSN] = 1)) 
			GROUP BY  
				[BiMatPtr],
				CASE @DetailCategory WHEN 1 THEN [biClassPtr] ELSE '' END, 
				[biStorePtr],  
				--buBranch,  
				[mtExpireFlag], 
				CASE @HaveCost WHEN 0 THEN 0X00 ELSE [biCostPtr] END  
		END  
	  
		DECLARE @UntilDate [DATETIME]  
	--	SELECT @UntilDate = MAX( biExpireDate) FROM vwbi  
		SELECT @UntilDate = GETDATE()  
		CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT],[UnPostedSec] [INT])  
		INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] 0x0 -- ALL --@BillTypes  
		CREATE TABLE [#Mat] ( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
		CREATE TABLE [#Store] ( [Number] [UNIQUEIDENTIFIER])   
		------------------  
		IF NOT(EXISTS(SELECT [Qnt] FROM [#R] WHERE [Qnt] < 0))  
		BEGIN  
			INSERT INTO [#Mat] EXEC [prcGetMatsList]  0X0, 0x0/*@MatGroup*/  
			INSERT INTO [#Store] SELECT [GUID] FROM [fnGetStoresList]( 0X0)  
			IF (@EveryBranchHasBill = 0)   
			BEGIN 
				IF @HaveCost = 0 
				BEGIN	  
					INSERT INTO [#ExpireMats] 
					([ID],[MatPtr],[MatCode],[MatName],[Price],[Qty],[Qty2],[Qty3],		 
					[ExpireDate],[DATE],[StorePtr],[Remaining],[Remaining2],[Remaining3], 
					[MatUnitName],[BillType],[BillNum],[BillNotes],[Age],[MtClassPtr]) 
					EXEC [repMatExpireDate2]  
						@UntilDate,  
						1,--@ShowBonus  
						0,--@UseUnit  
						@CurrencyGUID,--@CurrencyPtr   
						1,--@CurrencyVal   
						'1/1/1980',--StartDate  
						0,--flag  
						1,--Posted  
						0x00,0--Branch  
						,0x00,0,@HaveCost, @DetailCategory 
				END 
				ELSE 
				BEGIN 
					INSERT INTO [#ExpireMats] 
					([ID],[MatPtr],[MatCode],[MatName],[Price],[Qty],[Qty2],[Qty3],		 
					[ExpireDate],[DATE],[StorePtr],[Remaining],[Remaining2],[Remaining3], 
					[MatUnitName],[BillType],[BillNum],[BillNotes],[Age],[MtClassPtr],[coGuid])	 
						EXEC [repMatExpireDate2]  
						@UntilDate,  
						1,--@ShowBonus  
						1,--@UseUnit  
						@CurrencyGUID,--@CurrencyPtr   
						1,--@CurrencyVal   
						'1/1/1980',--StartDate  
						0,--flag  
						1,--Posted  
						0x00,0--Branch  
						,0x00,0,@HaveCost
						
				END 
			END  
			ELSE  
			BEGIN  
				SET @c =  CURSOR FAST_FORWARD FOR SELECT [Guid],0x00 FROM [br000]  
				 
				OPEN @c FETCH FROM @c INTO @brGuid,@coGuid 
				WHILE @@FETCH_STATUS = 0  
				BEGIN  
					IF (@HaveCost = 0) 
                            INSERT INTO [#ExpireMats]  
                            ([ID],[MatPtr],[MatCode],[MatName],[Price],[Qty],[Qty2],[Qty3],                              
                            [ExpireDate],[DATE],[StorePtr],[Remaining],[Remaining2],[Remaining3],  
                            [MatUnitName],[BillType],[BillNum],[BillNotes],[Age],[MtClassPtr])  
                                            EXEC [repMatExpireDate2]   
                                            @UntilDate,   
                                            1,--@ShowBonus   
                                            1,--@UseUnit   
                                            @CurrencyGUID,--@CurrencyPtr    
                                            1,--@CurrencyVal    
                                            '1/1/1980',--StartDate   
                                            0,--flag   
                                            1,--Posted   
                                            @brGuid--Branch   
                                            ,0,0X00,0,@HaveCost , @DetailCategory
            ELSE 
                            INSERT INTO [#ExpireMats]  
                            ([ID],[MatPtr],[MatCode],[MatName],[Price],[Qty],[Qty2],[Qty3],                              
                            [ExpireDate],[DATE],[StorePtr],[Remaining],[Remaining2],[Remaining3],  
                            [MatUnitName],[BillType],[BillNum],[BillNotes],[Age],[MtClassPtr],[coGuid])               
                                            EXEC [repMatExpireDate2]   
                                            @UntilDate,   
                                            1,--@ShowBonus   
                                            1,--@UseUnit   
                                            @CurrencyGUID,--@CurrencyPtr    
                                            1,--@CurrencyVal    
                                            '1/1/1980',--StartDate   
                                            0,--flag   
                                            1,--Posted   
                                            @brGuid--Branch   
                                            ,0,0X00,0,@HaveCost  
						UPDATE [#ExpireMats] SET  [BillNum] = @brGuid WHERE [BillNum] = 0X00  
						 
						FETCH NEXT FROM @c INTO @brGuid,@coGuid 
				END
				CLOSE @c
				DEALLOCATE @c
			END  
		END  
			IF @EveryBranchHasBill =1  
				INSERT INTO #R  
				(  
					[biMatPtr],  
					[biStorePtr],  
					[buBranch],  
					[biExpireDate],  
					[Qnt],  
					[Qnt2],  
					[Qnt3],
					
					[MtClassPtr],
					[CostGuid]  
				)-- select * from ms000  
				SELECT  
					[MatPtr],  
					[StorePtr],  
					CASE @EveryBranchHasBill WHEN 1 THEN [BillNum] ELSE 0X00 END,--MEANS Branch   
					[ExpireDate],  
					SUM([Remaining]),  
					SUM([Remaining2]),  
					SUM([Remaining3]),[MtClassPtr],[CoGuid]  
				FROM  
					[#ExpireMats]  
			--	WHERE   
			--		Remaining > 0  
				GROUP BY  
					[MatPtr],
					[MtClassPtr],  
					[StorePtr],  
					CASE @EveryBranchHasBill WHEN 1 THEN [BillNum] ELSE 0X00 END,  
					[ExpireDate] ,[CoGuid] 
				HAVING  
					SUM([Remaining])>0  
		ELSE  
			INSERT INTO [#R]  
				(  
					[biMatPtr],  
					[biStorePtr],  
					[biExpireDate],  
					[Qnt],  
					[Qnt2],  
					[Qnt3],
					[MtClassPtr],
					
					  
					[mtExpireFlag],[CostGuid]  
				)-- select * from ms000  
				SELECT  
					[MatPtr],  
					[StorePtr],  
					[ExpireDate],  
					SUM([Remaining]),  
					SUM([Remaining2]),  
					SUM([Remaining3]),  
					[MtClassPtr],1,[CoGuid] 
				FROM  
					[#ExpireMats]  
			--	WHERE   
			--		Remaining > 0  
				GROUP BY  
					[MatPtr],[MtClassPtr],  
					[StorePtr],  
					[ExpireDate],[CoGuid] 
				HAVING  
					SUM([Remaining])>0  
		  
			  
				-- and @buBranch branch  
		IF @EveryBranchHasBill =1  
			INSERT INTO #TransferErrTbl  
			(  
				[BillNum],  
				[MatPtr],  
				[StorePtr],  
				[ExpireDate],  
				[Remaining],  
				[Qty], 
				[coGuid] 
			)  
			SELECT  
				[BillNum],  
				[MatPtr],  
				[StorePtr],  
				[ExpireDate],  
				SUM([Remaining]),  
				SUM([Qty]),[coGuid] 
			FROM  
				[#ExpireMats]  
			GROUP BY  
				[MatPtr],  
				[StorePtr],  
				[ExpireDate],  
				[BillNum],[coGuid]  
			HAVING  
				SUM([Remaining]) < 0   
		  
		ELSE  
			INSERT INTO [#TransferErrTbl]  
			(  
				[BillNum],  
				[MatPtr],  
				[StorePtr],  
				[ExpireDate],  
				[Remaining],  
				[Qty] ,[coGuid] 
			)  
			SELECT  
				0x00,  
				[MatPtr],  
				[StorePtr],  
				[ExpireDate],  
				SUM([Remaining]),  
				SUM([Qty]),[coGuid] 
			FROM  
				[#ExpireMats]  
			GROUP BY  
				[MatPtr],  
				[StorePtr],  
				[ExpireDate],[coGuid] 
			HAVING  
				SUM([Remaining]) < 0   
		DROP TABLE [#Src]  
		DROP TABLE [#Mat]  
		DROP TABLE [#Store]  
		--DROP TABLE #ExpireMats  
		--- select * from vwExtended_bi  
	END  
	ELSE  
	BEGIN  
		IF @EveryBranchHasBill = 1  
			INSERT INTO [#R] SELECT * FROM [#BranchesQty]  
		ELSE	  
		BEGIN  
			INSERT INTO [#R]  
			SELECT  
				[biMatPtr],  
				[biStorePtr],  
				0x0,--buBranch,  
				'1/1/1980' AS [biExpireDate],  
				[mtExpireFlag],  
				ISNULL( SUM(([bi].[biQty] + [bi].[biBonusQnt]) * [buDirection]), 0) ,  
				-- ISNULL(SUM( biQty * buDirection), 0) AS Qnt,  
				ISNULL( SUM( [bi].[biQty2] * [buDirection]), 0) ,  
				ISNULL( SUM( [bi].[biQty3] * [buDirection]), 0),
				--[biClassPtr],
				CASE @DetailCategory WHEN 1 THEN [biClassPtr] ELSE '' END,
				CASE @HaveCost WHEN 0 THEN 0X00 ELSE [biCostPtr] END    
			  
			FROM  
				[vwExtended_bi] AS [bi]  
			WHERE [bi].[buIsPosted] > 0 AND [mtType] = 0  AND ISNULL([biStoreptr], 0X0) <> 0X0  
				AND (@InBillSNPrice = 0 OR NOT( [bi].[mtSNFlag] = 1  AND [bi].[mtForceInSN] = 1)) 
			GROUP BY  
				[BiMatPtr],
				CASE @DetailCategory WHEN 1 THEN [biClassPtr] ELSE '' END,  
				[biStorePtr],  
				[mtExpireFlag], 
				CASE @HaveCost WHEN 0 THEN 0X00 ELSE [biCostPtr] END    
		END  
	END  
	  
	SELECT  [ma].[objGUID], [ma].[MatAccGUID] AS [FPAcc]  
	INTO [#ma1]  
	FROM   
		[ma000] AS [ma] INNER JOIN [bt000] AS [bt] ON [ma].[BillTypeGUID] = [bt].[GUID]  
	WHERE   
		[ma].[Type] = 1   
		AND [bt].[Type] = 2   
		AND [bt].[SortNum] = 1  
		AND ISNULL([ma].[MatAccGuid], 0x0) <> 0x0  
	  
	SELECT  [ma].[objGUID], [ma].[MatAccGUID] AS [EPAcc]  
	INTO [#ma2]  
	FROM   
		[ma000] AS [ma] INNER JOIN [bt000] AS [bt] ON [ma].[BillTypeGUID] = [bt].[GUID]  
	  
	WHERE   
		[ma].[Type] = 1   
		AND [bt].[Type] = 2   
		AND [bt].[SortNum] = 2  
		AND ISNULL([ma].[MatAccGuid], 0x0) <> 0x0  
	CREATE TABLE #ma   
	(   
		[MatGUID]	[UNIQUEIDENTIFIER],   
		[FPAcc]		[UNIQUEIDENTIFIER],   
		[EPAcc]		[UNIQUEIDENTIFIER]   
	)   
	INSERT INTO [#ma]  
	(   
		[MatGUID],   
		[FPAcc],   
		[EPAcc]   
	)   
	SELECT   
		ISNULL ([ma1].[objGUID], [ma2].[objGUID]),   
		/* type = 2 and sortnum =1 or 2*/   
		ISNULL([FPAcc], 0X0),  
		ISNULL([EPAcc], 0X0)  
	FROM   
		[#ma1] AS [ma1] FULL JOIN [#ma2] AS [ma2] ON [ma1].[objGUID] = [ma2].[objGUID]  
	-- GROUP BY  
	--	ma.MatGUID  
	--- calc FPAcc For DefAcc  
	INSERT INTO [#Res]  
	SELECT  
		[r].[biMatPtr],  
		[r].[biStorePtr],  
		[r].[buBranch],  
		[r].[biExpireDate],  
		[r].[Qnt],  
		[r].[Qnt2],  
		[r].[Qnt3],
		--[r].[MtClassPtr],
		CASE @DetailCategory WHEN 1 THEN [r].[MtClassPtr] ELSE '' END,
		  
		ISNULL( [ma].[FPAcc], 0x0) AS [FPAcc],  
		ISNULL( [ma].[EPAcc], 0x0) AS [EPAcc],  
		0,  
		0,  
		0, 
		[CostGuid] 
	FROM  
		[#R] AS [r] LEFT JOIN [#ma] AS [ma] ON [r].[biMatPtr] = [ma].[MatGUID]  
	  
	--- select * from ma000  
	UPDATE [#Res]  
	SET  
		[FPAcc] = [bt].[DefBillAccGUID]  
	FROM  
		[bt000] AS [bt]  
	WHERE  
		[bt].[Type] = 2 And [bt].[SortNum] = 1  
		AND [#Res].[FPAcc] = 0x0  
	  
	UPDATE [#Res]  
	SET  
		[EPAcc] = [bt].[DefBillAccGUID]  
	FROM  
		[bt000] AS [bt]  
	WHERE  
		[bt].[Type] = 2 And [bt].[SortNum] = 2  
		AND [#Res].[EPAcc] = 0x0  
	UPDATE [r] SET [Flag] = CASE [ForceInSN] WHEN 1 THEN -2 ELSE  -1 END FROM  [#Res] AS [r] INNER JOIN [mt000] AS [mt] ON [biMatPtr] = [mt].[Guid] WHERE [snFlag] = 1	  
	INSERT INTO [#TRSN]	EXEC prcTrMatSN 
	IF EXISTS (SELECT [ParentGuid] FROM [as000]) OR (@InBillSNPrice = 1) 
	BEGIN 
		UPDATE [s] SET [biPrice] = [dbo].[fnCurrency_fix]( [InVal],[InCurrencyGUID] ,[InCurrencyVal], @CurrencyGUID, [InDate])  
		FROM [#TRSN][s] 
		INNER JOIN 
			(	
				SELECT 
				ad.sn, 
				[as].ParentGuid, 
				ad.InVal,
				ad.InCurrencyGUID,
				ad.InCurrencyVal,
				ad.InDate 
				FROM [Ad000] [ad] 
				LEFT JOIN as000 AS [as] ON ad.ParentGUID = [as].GUID
			) AS adAs ON adAs.SN = s.SN AND adAs.ParentGUID = s.MatPtr 
		INNER JOIN [mt000] [mt] ON [mt].[Guid] =[adAs].[ParentGuid] 
		WHERE [mt].[Type] = 2 
		SELECT   
			--- return first result set  
			[MatPtr] AS [biMatPtr],  
			[biStorePtr],  
			CASE @EveryBranchHasBill WHEN 0 THEN 0X00 ELSE [buBranch] END as [buBranch] ,  
			sum(cnt) AS SNQty ,  
			[biPrice]  [FixedBiTotal],  
			[BiPrice], 
			CASE @CostAsset WHEN 0 THEN 0X00 ELSE [biCostPtr] END AS [biCostPtr]  
		INTO #RES2 
		FROM [#TRSN] INNER JOIN [mt000] m on m.Guid = [MatPtr]  
		WHERE (m.Type = 2) OR (m.Type = 0 AND SNFlag = 1 AND ForceInSN = 1 AND @InBillSNPrice = 1) 
		 
		GROUP BY   
			[MatPtr] ,  
			[biStorePtr],  
			CASE @EveryBranchHasBill WHEN 0 THEN 0X00 ELSE [buBranch] END,  
			[biPrice],  
			 
			[BiPrice], 
			CASE @CostAsset WHEN 0 THEN 0X00 ELSE [biCostPtr] END 
			 
			INSERT INTO [#Res]   
		SELECT   
			--- return first result set  
			[biMatPtr],  
			[biStorePtr],  
			[buBranch],  
			'1/1/1980',  
			SUM([SNQty]) ,  
			0,  
			0,  
			'', 
			0x00,  
			0x00,  
			SUM([FixedBiTotal]*[SNQty])/SUM([SNQty]),  
			[BiPrice],  
			CASE WHEN SUM([SNQTY]) > 0 THEN 1 ELSE -5 END , 
			[biCostPtr]  
		FROM [#RES2] 
		GROUP BY  
			[biMatPtr],  
			[biStorePtr],  
			[buBranch], 
			[BiPrice], 
			[biCostPtr] 
		HAVING SUM([SNQTY]) <> 0 
	 
		 
	END  
	  
	DECLARE @s [NVARCHAR](2000)  
	SET @s = '   
			SELECT  
				[r].[biMatPtr],
				[r].[MtClassPtr],
				[r].[biStorePtr],   
				ISNULL([r].[buBranch],0X00) AS [buBranch] ,  
				[r].[biExpireDate],  
				[r].[Qnt],  
				[r].[Qnt2],  
				[r].[Qnt3],  
				[r].[FPAcc],  
				[r].[EPAcc],   
				[r].[AssPrice],  
				[r].[AssbiPrice],  
				[r].[Flag],[r].[CoGuid], '  
	 
	IF ((@EveryBranchHasPrice = 0) OR  NOT (@PriceType = 2 AND @PricePolicy = 121))  
	BEGIN  
		ALTER TABLE       
				[#t_Prices]  
			DROP COLUMN    
				[StNumber]  
	END  
	IF( @EveryBranchHasPrice = 1 )AND (@PriceType = 2) AND  
		( @PricePolicy = 122 OR @PricePolicy = 120 OR @PricePolicy = 121)   
	BEGIN  
		CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
		  
	  
		DECLARE @FPDate [DATETIME]  
		DECLARE @EPDate	[DATETIME]  
		DECLARE @PrcName [NVARCHAR](50)  
		-- SELECT VALUE FROM op000 WHERE NAME = 'AmnCfg_FPDate'  
		SELECT @FPDate = [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM [op000] WHERE [NAME] = 'AmnCfg_FPDate'  
		SELECT @EPDate = [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM [op000] WHERE [NAME] = 'AmnCfg_EPDate'  
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
			SET @PrcName = ' [prcGetLastPriceByBranch]'  
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
			SET @PrcName = ' [prcGetMaxPriceByBranch]'  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice  
			SET @PrcName = ' [prcGetAvgPriceByBranch]'  
		DECLARE @str [NVARCHAR]( 2000)  
		SET @str = ' EXEC ' + @PrcName  
		SET @str = @str + '''' + CAST( @FPDate AS NVARCHAR) + ''', '  
		+ '''' + CAST( @EPDate AS NVARCHAR) + ''', '  
		+ ' 0x0, 0x0, 0x0, 0x0, -1, '   
		+ '''' + CONVERT( [NVARCHAR](1000), @CurrencyGUID) + ''''  
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
			SET @str = @str + ' , 0x0, 0, 0, 0 '  
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
			SET @str = @str + ' ,' + CAST( @CurrencyVal AS NVARCHAR)  
								+ ' , 0x0, 0, 0'  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice  
		BEGIN  
			SET @str = @str + ' ,' + CAST( @CurrencyVal AS NVARCHAR)  
							+ ' , 0x0, 0, 0 '  
			IF @PriceForStore = 1   
				SET @str = @str + ',1 '  
		END  
	  
		EXECUTE( @str)  
		SET @s = @s + ' ISNULL(( CASE WHEN ' + CAST ( @CurrencyVal AS NVARCHAR) + ' <> 0 THEN [f].[APrice] / ' +   
							CAST( @CurrencyVal AS NVARCHAR) + ' ELSE [f].[APrice] END), 0)AS [APrice] '  
		SET @s = @s + ' FROM  
				[#Res] AS [r] LEFT JOIN [#t_Prices] AS [f]  
				ON [r].[biMatPtr] = [f].[mtNumber]  AND [r].[buBranch] = [f].[Branch] '  
		IF @PriceForStore = 1   
			SET @s = @s + ' AND [r].[biStorePtr] = [f].[stNumber] '  
		  
		DROP TABLE [#StoreTbl]  
		DROP TABLE [#BillsTypesTbl]  
		DROP TABLE [#CostTbl]  
		DROP TABLE [#MatTbl]  
		--DROP TABLE #t_Prices  
		-- DROP TABLE #SecViol  
	END  
	ELSE  
	BEGIN  
		ALTER TABLE       
			[#t_Prices]  
		DROP COLUMN    
			[BRANCH]  
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
		BEGIN  
			EXEC [prcGetLastPrice]  '1/1/1980', @CurrentDate ,  0X0,  0X0,  0X0, 0X0, -1,	@CurrencyGUID, '00000000-0000-0000-0000-000000000000', 0, 0  
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
		BEGIN  
			EXEC [prcGetMaxPrice] '1/1/1980' , @CurrentDate , 0X0,  0X0,  0X0, 0X0, -1,	@CurrencyGUID, @CurrencyVal,  '00000000-0000-0000-0000-000000000000', 0, 0  
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @PriceForStore = 0 -- COST And AvgPrice  
		BEGIN  
			EXEC [prcGetAvgPrice]	'1/1/1980',	@CurrentDate,  0X0,  0X0,  0X0, 0X0, -1, @CurrencyGUID, @CurrencyVal,  '00000000-0000-0000-0000-000000000000',	0, 0  
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @PriceForStore = 1 -- COST And AvgPrice  
		BEGIN  
			EXEC [prcGetAvgPrice_WithDetailStore]	'1/1/1980',	@CurrentDate,  0X0,  0X0,  0X0, 0X0, -1, @CurrencyGUID, @CurrencyVal,  '00000000-0000-0000-0000-000000000000',	0, 0  
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount  
		BEGIN  
			EXEC [prcGetLastPrice] '1/1/1980', @CurrentDate , 0X0, 0X0, 0X0, 0X0, -1,	@CurrencyGUID, '00000000-0000-0000-0000-000000000000', 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/  
		END 
		ELSE IF @PriceType = 2 AND @PricePolicy = 125 
			EXEC [prcGetFirstInFirstOutPrise] '1/1/1980', @CurrentDate,@CurrencyGUID	  
		ELSE IF @PriceType = 0x8000
		BEGIN
			INSERT INTO #t_Prices
			SELECT
				MatGuid,
				ISNULL([dbo].[fnCurrency_Fix]([dbo].[fnGetOutbalanceAveragePrice](MatGuid, @CurrentDate), mat.CurrencyGuid, mat.CurrencyVal, @CurrencyGUID, @CurrentDate), 0)
			FROM 
				#MatTbl mt
				JOIN mt000 mat ON mt.MatGuid = mat.[Guid]
		END
		ELSE  
		BEGIN  
			EXEC [prcGetMtPrice]  0X0,	 0X0, -1, @CurrencyGUID, @CurrencyVal, 0X0,  @PriceType, @PricePolicy, 0, 0  
		END  
		SET @s = @s + '[APRICE] AS [APrice] '  
		SET @s = @s +  ' FROM  
				[#Res] AS [r]  LEFT JOIN '  
		IF @PriceType = 2 AND @PricePolicy = 121 AND @PriceForStore = 1  
			SET @s = @s + '[#t_Prices2]'  
		ELSE  
			SET @s = @s + '[#t_Prices]'  
		SET @s = @s + ' AS [f]  
				ON [r].[biMatPtr] = [f].[mtNumber]   '   
		IF @PriceType = 2 AND @PricePolicy = 121 AND @PriceForStore = 1  
			SET @s = @s + ' AND [r].[biStorePtr] = [f].[stNumber]   '    
	END  
	SET @s = @s + ' WHERE ABS([r].[Qnt])> [dbo].[fnGetZeroValueQTY]() '  
	SET @s = @s + ' ORDER BY  
						[r].[biStorePtr],  
						[r].[buBranch],  
						[r].[biMatPtr], 
						[r].[MtClassPtr] '
						
	print @s						 
	EXECUTE( @s)  
	---- return Second Result set Serial Numbers  
	select * from [#TRSN] ORDER BY [MatPtr],Len([SN]),[SN] 
	  
	--SELECT * FROM #SnTbl  
	  
	---return Third result set Err Tbl  
	SELECT  ISNULL([BillNum], 0x0) AS [BillNum]	, [m].[Code] AS [MatCode], [s].[Name] AS [StoreName] ,ABS([Remaining]/CASE [DefUnit] WHEN 2 THEN [Unit2Fact] WHEN 3 THEN [Unit3Fact] ELSE 1 END) AS [QTY],[ExPireDate] ,ISNULL([br].[Name],'') AS [BrName],ISNULL(co.Code,'') coCode,ISNULL(co.Name,'') coName 
	FROM [#TransferErrTbl]  
	INNER JOIN [mt000] AS [m] ON [MatPtr] = [m].[Guid]  
	INNER JOIN [st000]  AS [s] ON [StorePtr] = [S].[Guid]  
	LEFT JOIN [br000] AS [br] ON [br].[Guid] = [BillNum]  
	LEFT JOIN co000 co ON co.Guid = [coGuid] 
	ORDER BY [BillNum]  
	 

-----
--DROP TABLE #R
/*
prcConnections_add2 'مدير'
EXEC  [prcPrepareFPBill] 1, 0, 0, '63c52cdd-c6d7-44bd-bf6b-82e6ca7aea21', 1, 2, 121, 0, 1,1
*/
#########################################################
CREATE PROC prcFixSortNumColIssue @Correct INT = 0
AS
DECLARE @counter		INT = 1, 
		@i				INT = 0,
		@end			INT,
		@currentType	INT

DECLARE @ids TABLE(idx INT IDENTITY(1,1), [Type] INT)


INSERT INTO @ids
SELECT DISTINCT [Type]
FROM bt000
WHERE SortNum = 0

SET @end = (SELECT COUNT([TYPE]) FROM @ids)

 
WHILE @counter <= @end
BEGIN
	SET @currentType = (SELECT [Type] from @ids where idx = @counter)
    UPDATE bt
	SET SortNum = @i,
		@i = @i + 1
	FROM bt000 AS bt
	WHERE [Type] = @currentType

    SET @counter = @counter + 1
	SET @i = 0
END
#########################################################
#END
