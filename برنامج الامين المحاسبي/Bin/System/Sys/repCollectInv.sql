###########################################################
CREATE PROCEDURE repCollectInv
	@StartDate 		    [DATETIME],
	@EndDate 			[DATETIME],
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
	@GroupGUID			[UNIQUEIDENTIFIER],
	@StoreGUID			[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores 
	@CostGUID			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@UseUnit 			[INT], --1 , 2, 3, 4 for [DefUnit]
	@MainAxis			[INT], -- 1Model
	@VrtAxis 			[INT],-- 1 MatName, 2 Latin, 3Spec,4GrpName,5Store,6Dim,7Origin, 8Pos,9Compny
	@HrzAxis 			[INT], --   4 Store,5Dim, 6Origin, 7 Pos, 8 Company
	@Level       		[INT] = 0, --Level Of Store
	@EptyType			[INT] = 1, --Empty Type
	@CondGuid			[UNIQUEIDENTIFIER] = 0x00,
	@Order			    [INT] = 1
AS  
	--IA_NAME,  0 
	--IA_LATINNAME, 1 
	--IA_SPEC, 2 
	--IA_GROUP, 3 
	--IA_STORE, 4 
	--IA_SIZE,  5 Dim 
	--IA_LOCATION, 6Pos 
	--IA_ORIGIN, 	7 
	--IA_COMPANY};8 
	----------------------------------------  
	SET NOCOUNT ON 
	DECLARE @stName [NVARCHAR](255),@stLatinName [NVARCHAR](255),@Guid [UNIQUEIDENTIFIER]
	DECLARE @c CURSOR
	DECLARE @s [NVARCHAR](max) 
	DECLARE @cnt INT 
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER]
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], mtSecurity [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#GR2]([Guid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#MatTbl2]( 
		[MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] INT,[mtCode] NVARCHAR(250), [MtName] NVARCHAR(250), 
		[mtLatinName] NVARCHAR(250), [mtSpec] NVARCHAR(1000),[grCode] NVARCHAR(250), [grName] NVARCHAR(250), 
		[grNumber] INT, [mtDim] NVARCHAR(250), [mtPos] NVARCHAR(250), [mtOrigin] NVARCHAR(250), 
		[mtCompany] NVARCHAR(250), [mtColor] NVARCHAR(250), [mtModel] NVARCHAR(250),[MtQuality] NVARCHAR(250), 
		[mtProvenance] NVARCHAR(250),[mtUnit2Fact] FLOAT, [mtUnit3Fact] FLOAT, [mtDefUnitFact] FLOAT
 	)
	CREATE TABLE [#StoreTbl2]([StoreGUID] [UNIQUEIDENTIFIER], [Security] INT ,
				[Name] NVARCHAR(250), [LatinName] NVARCHAR(250))
	CREATE TABLE [#TStore] ([Guid] [UNIQUEIDENTIFIER], [Level] INT, [Name] NVARCHAR(250), [LatinName] NVARCHAR(250))
	--Filling temporary tables 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID ,-1,@CondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	@SrcTypesguid 
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGUID 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )
	
	IF @Admin = 0
	BEGIN
		INSERT INTO [#GR2] SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)
		DELETE [r] FROM [#GR2] AS [r] INNER JOIN fnGroup_HSecList() AS [f] ON [r].[gUID] = [f].[GUID] where [f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
		DELETE [m] FROM [#MatTbl] AS [m]
		INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid] 
		WHERE [mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid) 
		OR [Groupguid] NOT IN (SELECT [Guid] FRoM [#Gr2])
		SET @cnt = @@ROWCOUNT
		IF @cnt > 0
			INSERT INTO [#SecViol] values(7,@cnt)
		
	END
	INSERT INTO [#MatTbl2]
	SELECT 
		[MatGUID] , [mtSecurity],
		[mt].[Code] AS [mtCode],
		[mt].[Name] AS [MtName], 
		[mt].[LatinName] AS [mtLatinName], 
		[Spec] AS [mtSpec],
		[gr].[Code] AS [grCode], 
		[gr].[Name] AS [grName], 
		[gr].[Number] AS [grNumber], 
		[Dim] AS [mtDim], 
		[Pos] AS [mtPos], 
		[Origin] AS [mtOrigin], 
		[Company] AS [mtCompany], 
		[Color] AS [mtColor], 
		[Model] AS [mtModel],
		[Quality] AS [MtQuality], 
		[Provenance] AS [mtProvenance],
		[Unit2Fact] AS [mtUnit2Fact], 
		[Unit3Fact] AS [mtUnit3Fact], 
		CASE [DefUnit] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END AS [mtDefUnitFact]
	FROM [#MatTbl] AS [m] 
	INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [m].[MatGUID]
	INNER JOIN [gr000] AS [gr] ON [mt].[GroupGUID] =[gr].[Guid]
	CREATE CLUSTERED INDEX [rpcmtinv] ON [#MatTbl2]([MatGUID])
	DECLARE @ReadMalBal [INT]
	SET @ReadMalBal =[dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]())
	IF @ReadMalBal > 0 
		UPDATE [#BillsTypesTbl] set [userSecurity] = [dbo].[fnGetMaxSecurityLevel]() 
	IF (@CostGUID = 0X00)
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	CREATE TABLE [#Result] 
	( 
		[BuType] 				[UNIQUEIDENTIFIER],
		[MtCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[MtName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[biMatPtr]				[UNIQUEIDENTIFIER], 
		[mtLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtSpec]				[NVARCHAR](2000) COLLATE ARABIC_CI_AI, 
		[grCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[grName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[grNumber]				[INT], 
		[biStorePtr]			[UNIQUEIDENTIFIER], 
		[stName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[stLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtDim]					[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtPos]					[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtOrigin]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtCompany]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtColor]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtModel]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[MtQuality]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtProvenance]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[btDirection]			[INT], 
		[biQty]					[FLOAT], 
		[BiBonusQnt]			[FLOAT], 
		[mtUnit2Fact]			[FLOAT], 
		[mtUnit3Fact]			[FLOAT], 
		[mtDefUnitFact]			[FLOAT], 
		[Security]				[INT], 
		[UserSecurity] 			[INT], 
		[UserReadPriceSecurity]	[INT], 
		[MtSecurity]			[INT] 
	) 
	INSERT INTO [#StoreTbl2] SELECT [StoreGUID] , [st1].[Security] ,[Name],[LatinName] FROM [#StoreTbl] AS [st1] INNER JOIN [st000] AS [st] ON [st1].[StoreGUID] = [st].[Guid]
	INSERT INTO [#Result] 
	SELECT 
		[BuType],
		[MtCode], 
		[MtName], 
		[biMatPtr], 
		[mtLatinName], 
		[mtSpec],
		[grCode], 
		[grName], 
		[grNumber], 
		[biStorePtr], 
		[st].[Name], 
		[st].[LatinName],
		[mtDim], 
		[mtPos], 
		[mtOrigin], 
		[mtCompany], 
		[mtColor], 
		[mtModel],
		[MtQuality], 
		[mtProvenance],
		[btDirection], 
		SUM([biQty]), 
		SUM([BiBonusQnt]), 
		[mtUnit2Fact], 
		[mtUnit3Fact], 
		[mtDefUnitFact], 
		[r].[buSecurity], 
		[bt].[UserSecurity], 
		[bt].[UserReadPriceSecurity], 
		[mtTbl].[MtSecurity] 
	FROM 
		[vwbubi] AS [r] 
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGUID] = [r].[biStorePtr]
		INNER JOIN [#CostTbl] AS [co] ON [CostGUID] = [BiCostPtr]
	WHERE 
		[Budate] BETWEEN @StartDate AND @EndDate 
		AND [BuIsPosted] = 1 
	GROUP BY
		[BuType],
		[MtCode],  
		[MtName], 
		[biMatPtr], 
		[mtLatinName], 
		[mtSpec],
		[grCode], 
		[grName], 
		[grNumber], 
		[biStorePtr], 
		[st].[Name], 
		[st].[LatinName],
		[mtDim], 
		[mtPos], 
		[mtOrigin], 
		[mtCompany], 
		[mtColor], 
		[mtModel],
		[MtQuality], 
		[mtProvenance],
		[btDirection], 
		[mtUnit2Fact], 
		[mtUnit3Fact], 
		[mtDefUnitFact], 
		[r].[buSecurity], 
		[bt].[UserSecurity], 
		[bt].[UserReadPriceSecurity], 
		[mtTbl].[MtSecurity] 
	
	 
	EXEC [prcCheckSecurity] 
	 
	IF (@Level<>0) 
	BEGIN
		SET @Cnt = (SELECT MAX([LEVEL]) FROM [fnGetStoresListByLevel](@StoreGUID,0 )) 
		INSERT INTO [#TStore] SELECT [f].[Guid], [Level], [Name],[LatinName] FROM [fnGetStoresListByLevel](@StoreGUID, @Level) AS [f] INNER JOIN [st000] AS [St] ON [st].[GUID] = [f].[Guid]
		
		WHILE @Cnt != 0
		BEGIN
			UPDATE [#RESULT]	SET [biStorePtr] = [st].[ParentGuid] ,[stName] = ''
				FROM [#Result] AS [T] INNER JOIN [st000] AS [st] ON [st].[Guid] = [T].[biStorePtr]
				WHERE [biStorePtr] NOT IN (SELECT [GUID] FROM [#TStore])
			
			SET @Cnt = @Cnt -1 
		END
		UPDATE [#RESULT]	SET [stName] = [st].[Name], [stLatinName] = [st].[LatinName]
		FROM [#Result] AS [T] INNER JOIN [st000] AS [st] ON [st].[Guid] = [T].[biStorePtr]
		WHERE [T].[stName] = ''
		SET @c=CURSOR FAST_FORWARD FOR  SELECT [GUID], [Name] ,[LatinName] FROM [#TStore] WHERE [LEVEL] < @Level ORDER BY [LEVEL] DESC
		OPEN @c
		FETCH @c INTO @Guid,@stName,@stLatinName
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			
			INSERT INTO [#Result]   
				SELECT 
					[BuType],[MtCode],[MtName],[biMatPtr],[mtLatinName],[mtSpec],[grCode],[grName],[grNumber] 
					,@Guid,@stName,@stLatinName,[mtDim],[mtPos],[mtOrigin],[mtCompany],[mtColor],[mtModel],[MtQuality],[mtProvenance]  ,[btDirection], 
					SUM( [biQty] ),SUM( [BiBonusQnt] ), 
					[mtUnit2Fact], 
					[mtUnit3Fact], 
					[mtDefUnitFact], 
		  			0,0,0,0 
				FROM [#Result] INNER JOIN [vwSt] [st] ON [st].[stGuid] = [biStorePtr]
				WHERE [st].[stParent] =@Guid   
				GROUP BY [buType],[MtCode],[MtName],[biMatPtr],[mtLatinName],[mtSpec],[grCode],[grName],[grNumber] 
					,[mtDim],[mtPos],[mtOrigin],[mtCompany],[mtColor],[mtModel],[MtQuality],[mtProvenance],[btDirection],[mtUnit2Fact],[mtUnit3Fact],[mtDefUnitFact]
			FETCH  FROM @c INTO @Guid,@stName ,@stLatinName
	     END 
		CLOSE @c DEALLOCATE @c
	END
	IF (@HrzAxis = 4) AND (@Level<>0)
		SELECT DISTINCT  [st].[Name] AS [stName],[st].[Code] AS [stCode],[st].[LatinName],[Path] AS [stLatinName] ,[Level] + 1 AS [Level] FROM [fnGetStoresListTree](0x00,0) AS [f] INNER JOIN [st000] AS [st] ON [st].[Guid] = [f].[Guid] INNER JOIN [#result] AS [r] ON [ST].[GUID] = [r].[biStorePtr] ORDER BY [Path]
	SET @s = ' SELECT ' 
		 
	IF @MainAxis = 10 
		SET @s = @s + '	[mtModel],' 
	IF @MainAxis = 4 
		SET @s = @s + ' [biStorePtr], [stName],[stLatinName], '
	IF (@MainAxis = 4) AND (@Level<>0)
		SET @s = @s + ' [ST].[LEVEL], [ST1].[PATH], '  
	IF @MainAxis = 5 
		SET @s = @s + ' [mtDim], ' 
	IF @MainAxis = 6 
		SET @s = @s + ' [mtPos], ' 
	IF @MainAxis = 7 
		SET @s = @s + ' [mtOrigin], ' 
	IF @MainAxis = 8 
		SET @s = @s + ' [mtCompany], ' 
	IF @MainAxis = 9 
		SET @s = @s + ' [mtColor], ' 
	IF @MainAxis = 11 
		SET @s = @s + '	[MtQuality],' 
	IF @MainAxis = 12 
		SET @s = @s + '	[mtProvenance],' 
		 
	IF @VrtAxis = 0 
		SET @s = @s + '	[MtName], [biMatPtr],' 
	IF @VrtAxis = 1 
		SET @s = @s + '	[mtLatinName], [biMatPtr], ' 
	IF @VrtAxis = 2 
		SET @s = @s + '	[mtSpec], ' 
	IF @VrtAxis = 3 
		SET @s = @s + '	[grName], [grNumber],' 
	IF @VrtAxis = 4 
		SET @s = @s + '	[biStorePtr], [stName],[stLatinName], ' 
	IF (@VrtAxis = 4) AND (@Level<>0)
		SET @s = @s + ' [ST].[LEVEL], [ST1].[PATH], ' 
	IF @VrtAxis = 5 
		SET @s = @s + '	[mtDim], ' 
	IF @VrtAxis = 6 
		SET @s = @s + '	[mtPos], ' 
	IF @VrtAxis = 7 
		SET @s = @s + '	[mtOrigin], ' 
	IF @VrtAxis = 8 
		SET @s = @s + '	[mtCompany], ' 
	IF @VrtAxis = 9 
		SET @s = @s + '	[mtColor], ' 
		
	IF @VrtAxis = 10 
		SET @s = @s + '	[mtModel], ' 
	IF @VrtAxis = 11 
		SET @s = @s + '	[MtQuality],' 
	IF @VrtAxis = 12 
		SET @s = @s + '	[mtProvenance],' 
	IF @HrzAxis = 0 
		SET @s = @s + '	[MtName], [biMatPtr],' 
	
	IF @HrzAxis = 1 
		SET @s = @s + '	[mtLatinName], [biMatPtr],' 
	IF @HrzAxis = 2 
		SET @s = @s + '	[mtSpec], ' 
	IF @HrzAxis = 3 
		SET @s = @s + '	[grName], [grNumber],'  
	IF @HrzAxis = 4 
		SET @s = @s + ' [biStorePtr], [stName],[stLatinName], ' 
	IF (@HrzAxis = 4) AND (@Level<>0)
		SET @s = @s + ' [ST].[LEVEL], [ST1].[PATH], ' 
	IF @HrzAxis = 5 
		SET @s = @s + ' [mtDim], ' 
	IF @HrzAxis = 6 
		SET @s = @s + ' [mtPos], ' 
	IF @HrzAxis = 7 
		SET @s = @s + ' [mtOrigin], ' 
	IF @HrzAxis = 8 
		SET @s = @s + ' [mtCompany], ' 
	IF @HrzAxis = 9 
		SET @s = @s + ' [mtColor], ' 
	IF @HrzAxis = 10 
		SET @s = @s + ' [mtModel], ' 
	IF @HrzAxis = 11 
		SET @s = @s + '	[MtQuality],' 
	IF @HrzAxis = 12 
		SET @s = @s + '	[mtProvenance],' 	 
	IF @UseUnit	= 0 
		SET @s = @s + ' SUM( [btDirection] * [biQty] )AS [SumQty], 
						SUM( [btDirection] * [BiBonusQnt] )AS [SumBonusQty] ' 
	IF @UseUnit	= 1 
		SET @s = @s + '	SUM( [btDirection] * [biQty] / (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END))AS [SumQty],  
						SUM( [btDirection] * [BiBonusQnt] /( CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END))AS [SumBonusQty] ' 
	IF @UseUnit	= 2 
		SET @s = @s + '	SUM( [btDirection] * [biQty] / (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END ))AS [SumQty], 
						SUM( [btDirection] * [BiBonusQnt] /  (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END ))AS [SumBonusQty] ' 
	IF @UseUnit	= 3 
		SET @s = @s + '	SUM( [btDirection] * [biQty] / (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END))AS [SumQty],  
						SUM( [btDirection] * [BiBonusQnt] / ( CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END))AS [SumBonusQty] ' 
	IF (@VrtAxis = 4 OR @MainAxis = 4 OR @HrzAxis = 4) AND (@Level<>0) 
		SET @s = @s + '   FROM [#Result] AS [r] INNER JOIN [fnGetStoresListByLevel](0X0,0)  AS [ST] ON [ST].[GUID] = [r].[biStorePtr] INNER JOIN [fnGetStoresListTree]( 0X0,0) AS [ST1] ON [ST1].[Guid] = [ST].[GUID] '   
	ELSE
		SET @s = @s + ' FROM [#Result] ' 
	SET @s = @s + 'WHERE 
			[UserSecurity] >= [Security] '
	IF @EptyType = 0
	BEGIN
		IF @MainAxis = 10 
			SET @s = @s + 'AND	[mtModel] <>' + '''' + '''' + ' ' 
		IF @MainAxis = 5 
			SET @s = @s + 'AND [mtDim] <>' + '''' + '''' + ' ' 
		IF @MainAxis = 6 
			SET @s = @s + 'AND [mtPos] <>' + '''' + '''' + ' ' 
		IF @MainAxis = 7 
			SET @s = @s + 'AND [mtOrigin] <>' + '''' + '''' + ' ' 
		IF @MainAxis = 8 
			SET @s = @s + 'AND [mtCompany] <>' + '''' + '''' + ' ' 
		IF @MainAxis = 9 
			SET @s = @s + 'AND [mtColor] <>' + '''' + '''' + ' ' 
		IF @MainAxis = 11 
			SET @s = @s + 'AND [MtQuality] <>' + '''' + '''' + ' ' 
		IF @MainAxis = 12 
			SET @s = @s + 'AND [MtProvenance] <>' + '''' + '''' + ' '  
		IF @VrtAxis = 1 
			SET @s = @s + 'AND	[mtLatinName] <>' + '''' + '''' + ' '
		IF @VrtAxis = 2 
			SET @s = @s + 'AND	[mtSpec] <>' + '''' + '''' + ' '
		IF @VrtAxis = 5 
			SET @s = @s + 'AND	[mtDim] <>' + '''' + '''' + ' ' 
		IF @VrtAxis = 6 
			SET @s = @s + 'AND	[mtPos] <>' + '''' + '''' + ' ' 
		IF @VrtAxis = 7 
			SET @s = @s + 'AND	[mtOrigin] <>' + '''' + '''' + ' ' 
		IF @VrtAxis = 8 
			SET @s = @s + 'AND	[mtCompany] <>' + '''' + '''' + ' '
		IF @VrtAxis = 9 
			SET @s = @s + 'AND	[mtColor] <>' + '''' + '''' + ' '
		IF @VrtAxis = 10 
			SET @s = @s + 'AND [mtModel] <>' + '''' + '''' + ' '
		IF @VrtAxis = 11 
			SET @s = @s + 'AND [MtQuality] <>' + '''' + '''' + ' ' 
		IF @VrtAxis = 12 
			SET @s = @s + 'AND [MtProvenance] <>' + '''' + '''' + ' ' 
		IF @HrzAxis = 1 
			SET @s = @s + 'AND [mtLatinName] <>' + '''' + '''' + ' ' 
		IF @HrzAxis = 2 
			SET @s = @s + 'AND [mtSpec] <>' + '''' + '''' + ' '
		IF @HrzAxis = 5 
			SET @s = @s + 'AND [mtDim] <>' + '''' + '''' + ' '
		IF @HrzAxis = 6 
			SET @s = @s + 'AND [mtPos] <>' + '''' + '''' + ' '
		IF @HrzAxis = 7 
			SET @s = @s + 'AND [mtOrigin] <>' + '''' + '''' + ' '
		IF @HrzAxis = 8 
			SET @s = @s + 'AND [mtCompany] <>' + '''' + '''' + ' ' 
		IF @HrzAxis = 9 
			SET @s = @s + 'AND [mtColor] <>' + '''' + '''' + ' ' 
		IF @HrzAxis = 10 
			SET @s = @s + 'AND [mtModel] <>' + '''' + '''' + ' '  
		IF @HrzAxis = 11 
			SET @s = @s + 'AND [MtQuality] <>' + '''' + '''' + ' '
		IF @HrzAxis = 12 
			SET @s = @s + 'AND [MtProvenance] <>' + '''' + '''' + ' '  
	
	END
	SET @s = @s + '	GROUP BY ' 
		 
	IF @MainAxis = 10 
		SET @s = @s + '	[mtModel],' 
	IF @MainAxis = 4 
		SET @s = @s + ' [biStorePtr], [stName],[stLatinName], ' 
	IF (@MainAxis = 4) AND (@Level<>0)
		SET @s = @s + ' [ST].[LEVEL], [ST1].[PATH], ' 
	IF @MainAxis = 5 
		SET @s = @s + ' [mtDim], ' 
	IF @MainAxis = 6 
		SET @s = @s + ' [mtPos], ' 
	IF @MainAxis = 7 
		SET @s = @s + ' [mtOrigin], ' 
	IF @MainAxis = 8 
		SET @s = @s + ' [mtCompany], ' 
	IF @MainAxis = 9 
		SET @s = @s + ' [mtColor], ' 
	IF @MainAxis = 11 
		SET @s = @s + '	[MtQuality],' 
	IF @MainAxis = 12 
		SET @s = @s + '	[mtProvenance],' 	 
	IF @VrtAxis = 0 
		SET @s = @s + '	[MtName], [biMatPtr],[MtCode],' 
	IF @VrtAxis = 1 
		SET @s = @s + '	[mtLatinName], [biMatPtr],' 
	IF @VrtAxis = 2 
		SET @s = @s + '	[mtSpec], ' 
	IF @VrtAxis = 3 
		SET @s = @s + '	[grName], [grNumber],[grCode],' 
	IF @VrtAxis = 4 
		SET @s = @s + '	[biStorePtr], [stName],[stLatinName], '
	IF (@VrtAxis = 4) AND (@Level<>0)
		SET @s = @s + ' [ST].[LEVEL], [ST1].[PATH], '  
	IF @VrtAxis = 5 
		SET @s = @s + '	[mtDim], ' 
	IF @VrtAxis = 6 
		SET @s = @s + '	[mtPos], ' 
	IF @VrtAxis = 7 
		SET @s = @s + '	[mtOrigin], ' 
	IF @VrtAxis = 8 
		SET @s = @s + '	[mtCompany], ' 
	IF @VrtAxis = 9 
		SET @s = @s + '	[mtColor], ' 
	IF @VrtAxis = 10 
		SET @s = @s + ' [mtModel], '
	IF @VrtAxis = 11 
		SET @s = @s + '	[MtQuality],' 
	IF @VrtAxis = 12 
		SET @s = @s + '	[mtProvenance],'  
	IF @HrzAxis = 0 
		SET @s = @s + '	[MtName], [biMatPtr]' 
		
	IF @HrzAxis = 1 
		SET @s = @s + '	[mtLatinName], [biMatPtr]' 
	IF @HrzAxis = 2 
		SET @s = @s + '	[mtSpec] ' 
	IF @HrzAxis = 3 
		SET @s = @s + '	[grName], [grNumber]' 
		 
	IF @HrzAxis = 4 
		SET @s = @s + ' [biStorePtr] , [stName],[stLatinName] ' 
	IF (@HrzAxis = 4) AND (@Level<>0)
		SET @s = @s + ' , [ST].[LEVEL], [ST1].[PATH] ' 
	IF @HrzAxis = 5 
		SET @s = @s + ' [mtDim] ' 
	IF @HrzAxis = 6 
		SET @s = @s + ' [mtPos] ' 
	IF @HrzAxis = 7 
		SET @s = @s + ' [mtOrigin] ' 
	IF @HrzAxis = 8 
		SET @s = @s + ' [mtCompany] ' 
	IF @HrzAxis = 9 
		SET @s = @s + ' [mtColor] ' 
	IF @HrzAxis = 10 
		SET @s = @s + ' [mtModel] '
	IF @HrzAxis = 11 
		SET @s = @s + '	[MtQuality]' 
	IF @HrzAxis = 12 
		SET @s = @s + '	[mtProvenance]'  
	
	IF @EptyType = 0
   		SET @s = @s + ' HAVING (SUM( [btDirection] * [biQty]) + SUM( [btDirection] * [BiBonusQnt] )) <> 0 '
	 
	 IF (@HrzAxis = 4) AND (@Level<>0)
			SET @s = @s + ' ORDER BY [ST1].[PATH] ' 
	ELSE 
	BEGIN
	IF (@VrtAxis = 4) AND (@Level<>0)
			SET @s = @s + ' ORDER BY [ST1].[PATH] ' 
	ELSE 
	BEGIN
		SET @s = @s + ' ORDER BY '
		IF @VrtAxis = 0 
		BEGIN
			IF (@Order = 0)
				SET @s = @s + '	[MtCode]' 
			ELSE
				SET @s = @s + '	[MtName]' 
		END
		IF @VrtAxis = 1 
			SET @s = @s + '	[mtLatinName]' 
		IF @VrtAxis = 2 
			SET @s = @s + '	[mtSpec]' 
		IF @VrtAxis = 3 
		BEGIN
			IF (@Order = 0)
				SET @s = @s + ' [grCode]' 
			ELSE
				SET @s = @s + '	[grName]' 
			
		END
		IF @VrtAxis = 4 
			SET @s = @s + ' [stName],[stLatinName] '
		IF @VrtAxis = 5 
			SET @s = @s + '	[mtDim] ' 
		IF @VrtAxis = 6 
			SET @s = @s + '	[mtPos] ' 
		IF @VrtAxis = 7 
			SET @s = @s + '	[mtOrigin] ' 
		IF @VrtAxis = 8 
			SET @s = @s + '	[mtCompany] ' 
		IF @VrtAxis = 9 
			SET @s = @s + '	[mtColor] ' 
		IF @VrtAxis = 10 
			SET @s = @s + ' [mtModel] '
		IF @VrtAxis = 11 
			SET @s = @s + '	[MtQuality]' 
		IF @VrtAxis = 12 
			SET @s = @s + '	[mtProvenance]'
		
	END
	
	
	IF @MainAxis = 4
	BEGIN
		IF (@Level<>0)
			SET @s = @s + ' ORDER BY [ST1].[PATH] '
		ELSE
			SET @s = @s + ' ,[stName],[stLatinName] '
	END
	IF @MainAxis = 5 
		SET @s = @s + ',[mtDim] ' 
	IF @MainAxis = 6 
		SET @s = @s + ',[mtPos] ' 
	IF @MainAxis = 7 
		SET @s = @s + ',[mtOrigin] ' 
	IF @MainAxis = 8 
		SET @s = @s + ',[mtCompany] ' 
	IF @MainAxis = 9
		SET @s = @s + ',[mtColor] ' 
	IF @MainAxis = 10 
		SET @s = @s + ',[mtModel] '
	IF @MainAxis = 11 
		SET @s = @s + ',[MtQuality]' 
	IF @MainAxis = 12 
		SET @s = @s + ',[mtProvenance]' 
		END
	--PRINT @S
	EXECUTE (@s)  
	SELECT * FROM [#SecViol]  
/*
prcConnections_add2 '„œÌ— '
 EXEC [repCollectInv] '1/1/2006', '7/19/2006', '383b0bb4-5e66-4bdf-ad22-567917700da3', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 1, 0, 0, 4, 0, 0, '00000000-0000-0000-0000-000000000000'
exec [repCollectInv] '1/1/2006', '7/19/2006', '85dbf290-ee3f-4e5f-87a8-91c612d3f958', 'a017db5c-d9a8-4953-a8cb-db3c4f01ca08', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 1, 0, 0, 4, 2, 0, '00000000-0000-0000-0000-000000000000'
*/

############################################################
#END