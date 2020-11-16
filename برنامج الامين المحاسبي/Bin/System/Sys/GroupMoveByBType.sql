##############################################
CREATE PROCEDURE rep_GroupMoveByBType
	@StartDate 		[DATETIME],  
	@EndDate		[DATETIME],  
	@GroupGUID 		[UNIQUEIDENTIFIER],  
	@StoreGUID  	[UNIQUEIDENTIFIER],  
	@CostGUID 		[UNIQUEIDENTIFIER],
	@PostedValue    [INT],--0 isnotposted ,1 is posted,-1 for both  
	@SrcTypesguid	[UNIQUEIDENTIFIER],  
	@CurrencyGUID 	[UNIQUEIDENTIFIER],  
	@MatType 		[INT], --0 Service 1 Stored -1 all  
	@UseUnit 		[INT], --1 First 2 Seccound 3 Third   
	@ShowGroups		[INT] =0,  
	@SepPautype		[INT] = 0,  
	@PayType		[INT] = -1,  
	@GrLevel		[INT] = 0,  
	@NotesContain 	[NVARCHAR](256) = '',-- NULL or Contain Text  
	@NotesNotContain[NVARCHAR](256) = '',  
	@ShowVal		[INT] = 0,  
	@PriceType 		[INT] = 2,  
	@PricePolicy 	[INT] = 121,  
	@CByGrp			[INT] = 0,  
	@MatCondGuid	[UNIQUEIDENTIFIER] = 0X00,  
	@Is_Summury		[bit] = 0 
AS  
	SET NOCOUNT ON  
	DECLARE @Level AS [INT]  
	DECLARE @CurrencyVal AS [INT]  
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER],@cnt [INT]  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])   
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])   
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])   
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#t_Prices]  
	(  
		[mtNumber] 	[UNIQUEIDENTIFIER],  
		[APrice] 	[FLOAT]  
	)  
	CREATE TABLE [#GR] ([Guid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#MatTbl2] ([mtdefUnitFact] FLOAT, [mtSecurity] INT, [mtGroup] [UNIQUEIDENTIFIER],
							[MatGUID] [UNIQUEIDENTIFIER], [mtUnitFact2] FLOAT)
	--Filling temporary tables   
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		0X0, @GroupGUID ,@MatType,@MatCondGuid  
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList] @SrcTypesguid--, @UserGuid   
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList]		@StoreGUID   
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID   
	  
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()  
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )  
	  
	IF @Admin = 0  
	BEGIN  
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
	CREATE TABLE [#T_Result]  
		 (	  
  		[btType] 			[INT] DEFAULT 11,		  
		[Type]				[INT],
		[btTypeGUID]		[UNIQUEIDENTIFIER],  
		[MatPtr] 			[UNIQUEIDENTIFIER],  
		[biStorePtr]		[UNIQUEIDENTIFIER] ,  
		[biQty]				[FLOAT] ,  
		[biQty2]			[FLOAT] ,  
		[biQty3] 			[FLOAT] ,  
		[biBounus]			[FLOAT] DEFAULT 0,  
		[FixedBiTotal]		[FLOAT] DEFAULT 0,  
		[FixedBiDiscount]	[FLOAT] DEFAULT 0,  
		[FixedBiExtra]		[FLOAT] DEFAULT 0,  
		[FixedBiVat]		[FLOAT] DEFAULT 0,  
		[MatSecurity] 		[INT],  
		[Security]			[INT],   
		[UserSecurity] 		[INT],  
		[buDirection]		[INT],  
		[GrpPtr] 			[UNIQUEIDENTIFIER],  
		[PayType]			[INT] DEFAULT  0 
		  
		)  
	IF @NotesContain IS NULL  
		SET @NotesContain = ''  
	IF @NotesNotContain IS NULL  
		SET @NotesNotContain = ''  
	INSERT INTO [#MatTbl2] SELECT [mt1].[mtdefUnitFact]/*,[mt1].[mtunit2Fact],[mt1].[mtunit3Fact]*/,[mt].[mtSecurity],[mt1].[mtGroup],[mt].[MatGUID],  
	CASE @UseUnit   
				WHEN 0 THEN 1  
				WHEN 1 THEN CASE [mt1].[mtunit2Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit2Fact] END   
				WHEN 2 THEN CASE [mt1].[mtunit3Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit3Fact] END    
				ELSE  [mt1].[mtdefUnitFact]  
			END [mtUnitFact2]  
	FROM [#MatTbl] AS [mt] INNER JOIN [vwmt] AS [mt1] ON [mt1].[mtGUID] = [mt].[MatGUID]   
	IF @CostGUID = 0X0  
		INSERT INTO [#CostTbl] VALUES(0X00,0)  
	  
	INSERT INTO [#T_Result]   
		SELECT   
		    [bi].[btBillType],  
			[bi].[btType], 
			[bi].[buType],  
			[bi].[biMatPtr],  
			[bi].[biStorePtr],  
			[bi].[biQty] / [mtUnitFact2],  
			[bi].[biCalculatedQty2],  
			[bi].[biCalculatedQty3],  
			[bi].[biBonusQnt]/[mtUnitFact2],  
			[FixedBiPrice] * ReadPrc  ,
			[DISC] * ReadPrc,  
			[EXTRA]  * ReadPrc,  
			[bi].[FixedBiVat],  
			[mt].[mtSecurity],  
			[bi].[buSecurity],  
			[bi].[UserSecurity],  
			[buDirection],  
			[mt].[mtGroup],  
			[buPayType]  
		FROM   
				(  
				SELECT   
				   CASE @Is_Summury
						WHEN 0 THEN [b].[btBillType]
						WHEN 1 THEN 
								CASE [b].[btType] 
									WHEN 1 THEN [b].[btBillType]
									WHEN 2 THEN [b].[btBillType]
									WHEN 3 THEN 6
									WHEN 4 THEN 7
									ELSE CASE b.btIsInput WHEN 0 THEN 4 ELSE 5 END
								END 
					END AS btBillType,
					[b].[btType],
			 		[b].[buType],  
					[b].[biMatPtr],  
					[b].[biStorePtr],  
					[b].[biCostPtr],  
					CASE [buPayType] WHEN 0 THEN 0 ELSE 1 END [buPayType],  
					SUM([b].[biQty]) [biQty],  
					SUM([b].[biCalculatedQty2]) [biCalculatedQty2],  
					SUM([b].[biCalculatedQty3]) [biCalculatedQty3],  
					SUM([b].[biBonusQnt]) [biBonusQnt] ,  
					CASE WHEN [bt].[UserReadPriceSecurity] >= [b].[buSecurity] THEN SUM(([FixedBiPrice] ) / [MtUnitFact] * ([b].[biQty] /*+[biBonusQnt]*/)) ELSE 0 END [FixedBiPrice], 
					CASE WHEN [bt].[UserReadPriceSecurity] >= [b].[buSecurity] THEN SUM(([biTotalDiscountPercent] * [FixedCurrencyFactor]) + [FixedBiDiscount] + ([BibonusDisc] * [FixedCurrencyFactor])) ELSE 0 END [DISC], 
					CASE WHEN [bt].[UserReadPriceSecurity] >= [b].[buSecurity] THEN SUM(FixedBiExtra + (biTotalExtraPercent * [FixedCurrencyFactor])) ELSE 0 END [EXTRA],
					CASE WHEN [bt].[UserReadPriceSecurity] >= [b].[buSecurity] THEN SUM([b].[FixedBiVat]) ELSE 0 END [FixedBiVat],  
					[b].[buSecurity],  
					[bt].[UserSecurity],  
					CASE WHEN  [bt].[UserReadPriceSecurity] >= [B].[buSecurity] THEN 1 ELSE 0 END ReadPrc,    
					[buDirection]  
					FROM [fnExtended_bi_Fixed](@CurrencyGUID)  b  
					INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [b].[buType]  
					WHERE   
						[buDate] BETWEEN @StartDate AND @EndDate   
						AND [buIsPosted] = @PostedValue OR @PostedValue = -1    
						AND (@PayType =-1 OR @PayType = CASE [buPayType] WHEN 0 THEN 0 ELSE 1 END )   
						AND( (@NotesContain = '')				OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [BiNotes] LIKE '%' + @NotesContain + '%'))  
						AND( (@NotesNotContain ='')				OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%')))   
					GROUP BY  
						[b].[btType],
						[b].[btBillType],  
						b.btIsInput,
						[b].[buType],  
						[b].[biMatPtr],  
						[b].[biStorePtr],  
						[b].[biCostPtr],  
						[b].[buSecurity],  
						[bt].[UserSecurity],  
						[bt].[UserReadPriceSecurity], 
						[buDirection],  
						CASE [buPayType] WHEN 0 THEN 0 ELSE 1 END,  
						CASE WHEN  [bt].[UserReadPriceSecurity] >= [B].[buSecurity] THEN 1 ELSE 0 END  
						  
				) AS [bi]  
				INNER JOIN vwbt AS bt ON [bt].[btGUID] = [bi].[buType] 
				INNER JOIN [#MatTbl2] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]  
				INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bi].[biStorePtr]  
				INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [bi].[biCostPtr]  
				WHERE  [bt].[btSortNum] <> 0
		  
	EXEC [prcCheckSecurity]  @result = '#T_Result'  
	IF @ShowVal = 1  
	BEGIN  
		SELECT @CurrencyVal = [CurrencyVal] FROM [my000] WHERE [GUID] = @CurrencyGUID  
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
		BEGIN  
			EXEC [prcGetLastPrice] @StartDate , @EndDate , 0X0, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, 0, @UseUnit  
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
		BEGIN  
			EXEC [prcGetMaxPrice] @StartDate , @EndDate , 0X0, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @CurrencyVal, @SrcTypesguid, 0, @UseUnit  
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice   
		BEGIN  
			DECLARE  @defCurr UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1)
			EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, 0X0, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @defCurr, 1, @SrcTypesguid,	0, @UseUnit 
			UPDATE P
				SET APrice =P.APrice/dbo.fnGetCurVal(@CurrencyGUID,@EndDate)
				FROM
					#t_Prices P		
		END   
		ELSE IF @PriceType = -1  
			INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]   
		  
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount  
		BEGIN  
			EXEC [prcGetLastPrice] @StartDate , @EndDate , 0X0, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, 0, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/  
		END  
		ELSE  
		BEGIN  
				EXEC [prcGetMtPrice] 0X0,	@GroupGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, 0, @UseUnit, @EndDate  
		END	  
	END  

	CREATE TABLE [#EndResult] (	  
				[btType] 		[INT] DEFAULT 11,
				[Type]			INT,
				[btTypeGUID]		[UNIQUEIDENTIFIER],  
				[GrpPtr] 		[UNIQUEIDENTIFIER] DEFAULT 0X00,  
				[GrName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,    
				[GrCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI  DEFAULT '',    
				[GrLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,    
				[Qty] 			[FLOAT] DEFAULT 0 ,  
				[Qty2]			[FLOAT] DEFAULT 0,  
				[Qty3] 			[FLOAT] DEFAULT 0,  
				[FixedBiTotal] 		[FLOAT] DEFAULT 0,  
				[FixedBiDiscount]	[FLOAT] DEFAULT 0,  
				[FixedBiExtra]		[FLOAT] DEFAULT 0,  
				[FixedBiVat]		[FLOAT] DEFAULT 0,  
				[Flag] 			[INT],  
				[buDirection]		[INT],  
				[PayType]		[INT],  
				[State]			[FLOAT] DEFAULT 0,  
				[ParentGroup] 		[UNIQUEIDENTIFIER] DEFAULT 0X00,  
				[Level]			[INT] DEFAULT 0  
			)  
	IF (@CByGrp = 0)  
	BEGIN  
		INSERT INTO [#EndResult]  
				SELECT   
					[btType],
					r.[Type],
					[btTypeGUID],  
					[GrpPtr],  
					[GrName],    
					[GrCode],    
					[GrLatinName],  
					SUM([biQty] + [biBounus]),  
					SUM([biQty2]) ,  
					SUM([biQty3]) ,  
					SUM([FixedBiTotal]),  
					SUM([FixedBiDiscount]),  
					SUM([FixedBiExtra]),  
					SUM([FixedBiVat]),  
					1,  
					[buDirection],  
					CASE @SepPautype WHEN 1 THEN [PayType] ELSE 0 END,  
					0,  
					[grParent],  
					0  
				FROM [#T_Result] AS [r] INNER JOIN [vwGr] ON [GrpPtr] = [grGuid]  
				GROUP BY   
					[btType],
					r.[Type],
					[btTypeGUID],  
					[GrpPtr],  
					[GrName],    
					[GrCode],    
					[GrLatinName],  
					[buDirection],  
					CASE @SepPautype WHEN 1 THEN [PayType] ELSE 0 END,  
					[grParent]  
	END  
	ELSE  
	BEGIN  
			INSERT INTO [#EndResult]  
				SELECT   
					[btType],		  
					r.[Type],
					[btTypeGUID],  
					[GrpPtr],  
					[GrName],    
					[GrCode],    
					[GrLatinName],  
					SUM([biQty] + [biBounus]),  
					SUM([biQty2]) ,  
					SUM([biQty3]) ,  
					SUM([FixedBiTotal]),  
					SUM([FixedBiDiscount]),  
					SUM([FixedBiExtra]),  
					SUM([FixedBiVat]),  
					1,  
					[buDirection],  
					CASE @SepPautype WHEN 1 THEN [PayType] ELSE 0 END,  
					[p].[APrice],  
					[grParent],  
					0  
				FROM [#T_Result] AS [r] INNER JOIN [vwGr] ON [GrpPtr] = [grGuid]  
				LEFT JOIN [#t_Prices] AS [p] ON [r].[MatPtr] = [p].[mtNumber]  
				GROUP BY   
					[btType],
					r.[Type],
					[btTypeGUID],  
					[GrpPtr],  
					[GrName],    
					[GrCode],    
					[GrLatinName],  
					[buDirection],  
					CASE @SepPautype WHEN 1 THEN [PayType] ELSE 0 END,  
					[p].[APrice],  
					[grParent]  
	  
	END  
	IF @ShowGroups = 1  
	BEGIN  
		CREATE TABLE [#GrLevel] ([GGuid] [UNIQUEIDENTIFIER], [Level] INT, [grName] NVARCHAR(256),
								[grCode] NVARCHAR(256), [grLatinName] NVARCHAR(256), [grParent] [UNIQUEIDENTIFIER])
		INSERT INTO [#GrLevel] SELECT [GUID] AS [GGuid],[Level],[grName],[grCode],[grLatinName],[grParent] FROM  [fnGetGroupsOfGroupSorted](@GroupGUID,1) INNER JOIN [vwGr] ON [GUID] = [grGuid]  
		UPDATE [#EndResult] SET [Level] = [gr].[Level] FROM [#EndResult] AS [er] INNER JOIN [#GrLevel] AS [gr] ON [GGUID] = [GrpPtr]  
		SELECT @Level = MAX([Level]) FROM  [#GrLevel]  
		WHILE (@Level > =0)  
		BEGIN  
			INSERT INTO [#EndResult]   
				SELECT  
					[r].[btType],		  
					[r].[Type],
					[btTypeGUID],  
					[GGuid],  
					[gr].[GrName],    
					[gr].[GrCode],    
					[gr].[GrLatinName],    
					SUM([Qty]) ,  
					SUM([Qty2]),  
					SUM([Qty3]),  
					SUM([FixedBiTotal]),  
					SUM([FixedBiDiscount]),  
					SUM([FixedBiExtra]),  
					SUM([FixedBiVat]),  
					1,  
					[buDirection],  
					[PayType],  
					0,  
					[gr].[grParent],  
					[gr].[Level]  
				FROM   
					[#EndResult] AS [r] INNER JOIN [#GrLevel] AS [gr] ON [r].[ParentGroup] = [gr].[GGuid]   
				WHERE  
					[r].[Level] = @Level   
				GROUP BY  
					[r].[btType],		  
					[r].[Type],
					[btTypeGUID],  
					[GGuid],  
					[gr].[GrName],    
					[gr].[GrCode],    
					[gr].[GrLatinName],    
					[buDirection],  
					[PayType],  
					[gr].[grParent],  
					[gr].[Level]	  
			SET @Level = @Level - 1  
					  
		END  
	END  
	 ---Add Bills Types 
	IF @Is_Summury = 0 
		INSERT INTO [#EndResult] ([btType],[btTypeGUID],[GrName],[GrLatinName],[Flag])  
			SELECT  [btBillType], [btGuid], [btName], CASE [btLatinName] WHEN '' THEN [btName] ELSE [btLatinName] END,-1	  
			FROM [vwBt]  INNER JOIN (select [btTypeGUID] from [#EndResult] GROUP BY [btTypeGUID]) r ON [btTypeGUID] = [btGuid]   
	ELSE BEGIN
		INSERT INTO [#EndResult] ([btType],[Flag])  
			SELECT  [btType],-1	  
			FROM [#EndResult] 
			GROUP BY [btType]  
	END

	SELECT   
			[btType],		  
			CASE @Is_Summury WHEN 1 THEN 0X00 ELSE [btTypeGUID] END [btTypeGUID],  
			[GrpPtr],  
			[GrName],    
			[GrCode],    
			[GrLatinName],    
			SUM([Qty]) AS [Qty],  
			SUM([Qty2]) AS [Qty2],  
			SUM([Qty3]) AS [Qty3],  
			SUM([FixedBiTotal]) AS [FixedBiTotal] ,  
			SUM([FixedBiDiscount]) AS [FixedBiDiscount],  
			SUM([FixedBiExtra]) AS [FixedBiExtra],  
			SUM([FixedBiVat]) [FixedBiVat],  
			[Flag],  
			ISNULL([buDirection], 0) as [buDirection],  
			ISNULL([PayType], 0) as [PayType],   
			[Level],  
			[State],  
			[ParentGroup]   
		FROM [#EndResult] AS [r]-- LEFT JOIN [fnGetGroupsOfGroupSorted](@GroupGUID,@Sort) ON [GUID] = GrpPtr  
		WHERE ISNULL([Level],0) < @GrLevel OR @GrLevel = 0  
		GROUP BY  
			[btType],		  
			CASE @Is_Summury WHEN 1 THEN 0X00 ELSE [btTypeGUID] END,  
			[GrpPtr],  
			[GrName],    
			[GrCode],    
			[GrLatinName],    
			[Flag],  
			[buDirection],  
			[PayType],  
			[Level],  
			[State],  
			[ParentGroup]   
		ORDER BY  
			[FLAG],  
			[GrpPtr],  
			[PayType],  
			[State],  
			[btType],		  
			CASE @Is_Summury WHEN 1 THEN 0X00 ELSE [btTypeGUID] END
	IF @ShowVal = 1  
	BEGIN  
		CREATE TABLE [#GRPPrice]([Val] FLOAT, [MatPtr] [UNIQUEIDENTIFIER], [GrpPtr] [UNIQUEIDENTIFIER], [PayType] INT, [APrice] FLOAT)
		CREATE TABLE [#GRPPrice2]([Val] FLOAT ,[GrpPtr] [UNIQUEIDENTIFIER], [PayType] INT, [State] FLOAT)

		INSERT INTO [#GRPPrice] SELECT SUM(([biQty] + [biBounus]) * [buDirection] *[mtUnitFact2]) * [APrice] AS [Val],[MatPtr],[GrpPtr],CASE @SepPautype  WHEN 0 THEN 0 ELSE [PayType] END AS [PayType],[APrice]  
		FROM [#T_Result] AS [r]   
		INNER JOIN [#t_Prices] AS [p] ON [p].[mtNumber] = [r].[MatPtr]  
		INNER JOIN [#MatTbl2] AS [mt] ON [mt].[MatGUID] = [p].[mtNumber]  
		GROUP BY [APrice], [MatPtr], [GrpPtr], CASE @SepPautype  WHEN 0 THEN 0 ELSE [PayType] END  
		  
		INSERT INTO [#GRPPrice2] SELECT SUM([Val]) AS [Val],[GrpPtr],[PayType],CASE @CByGrp WHEN 0 THEN 0 ELSE [APrice] END AS [State] FROM [#GRPPrice] GROUP BY [GrpPtr],[PayType],CASE @CByGrp WHEN 0 THEN 0 ELSE [APrice] END  
		IF @ShowGroups = 1  
		BEGIN  
			SELECT @Level = MAX([Level])-1 FROM  [#GrLevel]  
			WHILE (@Level > =0)  
			BEGIN  
				INSERT INTO [#GRPPrice2]   
					SELECT  
						SUM([Val]) ,  
						[GGuid],  
						[PayType],  
						[State]	  
					FROM   
						[#GRPPrice2] AS [r] , [#GrLevel] AS [gr]    
					WHERE  
						[GrpPtr] IN (SELECT [GUID] FROM [GR000] WHERE [PARENTGUID] = [GGuid]) AND [Level] = @Level   
					GROUP BY  
						[GGuid],  
						[PayType],  
						[State]	  
				SET @Level = @Level - 1  
			END  
		END  
		SELECT SUM([Val]) AS [Val],[GrpPtr],[PayType],[State] FROM [#GRPPrice2] GROUP BY [GrpPtr],[PayType],[State]  
	END  
	SELECT * FROM [#SecViol]  
/* 
prcConnections_add2 '„œÌ—' 
 [rep_GroupMoveByBType] '1/1/2009 0:0:0.0', '9/3/2009 23:59:34.220', 'c65d6e70-58f5-4cbf-9070-bd74b29d14e8', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'f5a67087-25ca-445e-9a86-f0d868b4f2ff', 'd04831d6-459c-4996-bbf6-7ac84f7a78a9', -1, 3, 0, 0, -1, 0, '', '', 1, 128, 120, 0, '00000000-0000-0000-0000-000000000000', 1;
 [rep_GroupMoveByBType] '1/1/2009 0:0:0.0', '9/3/2009 23:59:32.736', '16c99cd6-fe38-4518-902a-7851137151a7', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '76235860-c4f0-404f-9865-a66771628477', 'd04831d6-459c-4996-bbf6-7ac84f7a78a9', -1, 3, 0, 0, -1, 0, '', '', 1, 128, 120, 0, '00000000-0000-0000-0000-000000000000', 1
*/ 
####################################################
#END
