#############################################################################
CREATE PROCEDURE repBranchesMovement
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@AccGUID 			[UNIQUEIDENTIFIER],
	@CostGUID 			[UNIQUEIDENTIFIER],
	@BranchGUID 		[UNIQUEIDENTIFIER],
	@CurGUID			[UNIQUEIDENTIFIER],
	@CurVal				[FLOAT],
	@MainAxis			[INT],
	@VrtAxis 			[INT],
	@HrzAxis 			[INT],
	@Sorted				[INT] = 0, -- 0: without sort, 1:Sort By Code, 2:Sort By Name
	@CostLevel          [INT] = 0,
	@AccLevel           [INT] = 0,
	@PrNotPosted		[INT] = 0,
	@Lang				[INT] = 0,
	@shwEmptyAcc		BIT = 0,
	@shwEmptyCo			BIT = 0,
	@shwEmptyBr			BIT = 0,
	@SrcGuid		    [UNIQUEIDENTIFIER] = 0X0
AS 
--	IA_COST,	0 
--	IA_ACC, 	1 
--	IA_BRANCH, 	2 
----------------------------------------  
	SET NOCOUNT ON 
	DECLARE @Cnt [INT],@s [NVARCHAR](max)
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	
	-- select * from br000 
	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])      
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	-- Filling temporary tables 
	INSERT INTO [#AccTbl]
	SELECT AcList.[GUID], [Level], [Path] FROM [dbo].[fnGetAcDescList]( @AccGUID)  AS AcList
	INNER JOIN ac000 ON ac000.[GUID] = AcList.[GUID]
	WHERE [Type] = 1
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	INSERT INTO [#BranchTbl]	SELECT [f].[Guid], [Security] from [fnGetBranchesList](@BranchGUID) [f] inner join [br000] [br] on [f].[guid] = [Br].[Guid] 
	SELECT a.[GUID],a.[Security],a.[Level],Code acCode,CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [acName]  
	INTO [#AccTbl2]
	FROM [#AccTbl] a INNER JOIN [ac000] ac ON ac.Guid = a.Guid
	SELECT [CostGUID], [c].[Security],[co].[Code] AS [CoCode] ,
	CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE [co].[LatinName] WHEN '' THEN [co].[Name] ELSE [co].[LatinName] END END AS [CoName]
	INTO [#CostTbl2]
	FROM [#CostTbl] AS [c] INNER JOIN [co000] AS [co] ON [co].[Guid] = [CostGUID]
	
	IF @CostGUID = 0x00
		INSERT INTO [#CostTbl2] VALUES(0X00,0,'','')
	DECLARE  @UserId [UNIQUEIDENTIFIER],@HosGuid [UNIQUEIDENTIFIER]  
	SELECT [b].[GUID] , [b].[Security],[Code] AS [brCode],CASE @Lang WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '' THEN [br].[Name] ELSE [br].[LatinName] END END AS [brName]
	INTO [#BranchTbl2]
	FROM [#BranchTbl] AS [b] INNER JOIN [br000] AS [br] ON [br].[Guid] = [b].[GUID]
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()       
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID      
	  
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID      
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID   
	  
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]  
	DECLARE @str NVARCHAR(1000)
	IF [dbo].[fnObjectExists]( 'prcGetTransfersTypesList') <> 0	  
		INSERT INTO [#EntryTbl]	EXEC [prcGetTransfersTypesList] 	@SrcGuid  
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0  
	BEGIN		  
		SET @str = 'INSERT INTO [#EntryTbl]  
		SELECT  
					[IdType],  
					[dbo].[fnGetUserSec](''' + CAST(@UserID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1)  
				FROM  
					[dbo].[RepSrcs] AS [r]   
					INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid]  
				WHERE  
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + ''''  
		EXEC(@str)  
	END  
	IF [dbo].[fnObjectExists]( 'vwTrnExchangeTypes') <> 0  
	BEGIN		  
		SET @str = 'INSERT INTO [#EntryTbl]  
		SELECT  
					[IdType],  
					[dbo].[fnGetUserSec](''' + CAST(@UserID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1)  
				FROM  
					[dbo].[RepSrcs] AS [r]   
					INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid]  
				WHERE  
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + ''''  
		EXEC(@str)  
	END 			  
					  
	IF EXISTS(SELECT * FROM [dbo].[RepSrcs] WHERE [IDSubType] = 303)  
		INSERT INTO [#EntryTbl] VALUES(@HosGuid,0) 
	CREATE TABLE [#Result]
	( 
		[ceBranch]				[UNIQUEIDENTIFIER], 
		[BranchName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[BranchCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[acGuid]				[UNIQUEIDENTIFIER], 
		[acName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[acCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[enCostPoint]			[UNIQUEIDENTIFIER], 
		[CostName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[CostCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[FixedEnDebit]			[FLOAT], 
		[FixedEnCredit]			[FLOAT],
		[Security]				[INT],
	 	[acSecurity]			[INT],
	 	[coSecurity]			[INT],
	 	[brSecurity]			[INT],
	 	[acLevel]				[INT],
	 	[coLevel]				[INT],
	 	[MainAcc]				[UNIQUEIDENTIFIER] DEFAULT 0X00,
	 	[MainCost]				[UNIQUEIDENTIFIER] DEFAULT 0X00,
	 	[IdAcc]					[INT] DEFAULT 0,
	 	[IdCost]				[INT] DEFAULT 0,
	 	[Flag]					[INT] DEFAULT 0
	) 
	INSERT INTO [#Result] 
	SELECT 
		[r].[ceBranch], 
		[br].[brName], 
		[br].[brCode], 
		[r].enAccount, 
		[ac].[acName], 
		[ac].[acCode], 
		[r].[enCostPoint], 
		[co].[CoName], 
		[co].[CoCode], 
		SUM([r].[FixedEnDebit]), 
		SUM([r].[FixedEnCredit]),
		[r].[ceSecurity], 
		[ac].[Security],
		[co].[Security],
		[br].[Security],
		0,
		0,
		0x00,
		0x00,
		0,0,
		0
	FROM 
		[fnCeEn_Fixed]( @CurGUID) AS [r] 
		INNER JOIN [#AccTbl2] AS [ac] ON [r].enAccount = [ac].[GUID] 
		INNER JOIN [#CostTbl2] AS [co] ON [co].[costGUid] = [r].[enCostPoint] 
		INNER JOIN [#BranchTbl2] AS [br] ON [r].[ceBranch] = [br].[Guid] 
		LEFT JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]
		LEFT JOIN ER000 er ON er.EntryGuid = ceGuid 
	WHERE 
		[cedate] BETWEEN @StartDate AND @EndDate 
		AND ((@PrNotPosted = 1)		OR ( [r].[ceIsPosted] = 1))
		AND (([Type] IS NOT NULL) OR er.ParentType = 303)
	GROUP BY
		[r].[ceBranch], 
		[br].[brName], 
		[br].[brCode], 
		[r].enAccount, 
		[ac].[acName],
		[ac].[acCode], 
		[r].[enCostPoint], 
		[co].[CoName], 
		[co].[CoCode], 
		[r].[ceSecurity], 
		[ac].[Security],
		[co].[Security],
		[br].[Security]

	IF @shwEmptyAcc > 0 OR @shwEmptyCo > 0 OR @shwEmptyBr > 0
	BEGIN 
		SELECT TOP 1
			[br].[Guid] [ceBranch] ,[BrName] [BranchName],[BrCode] [BranchCode],ISNULL([acGuid],ac.Guid) [acGuid],
			ac.[acName],ac.[acCode],[ac].[Security] [acSecurity] ,[br].[Security] [brSecurity]
		INTO [#acBRPtr]
		FROM [#Result] r RIGHT JOIN [#AccTbl2] ac ON [acGuid] = ac.Guid	
		RIGHT JOIN [#BranchTbl2] AS [br] ON [r].[ceBranch] = [br].[Guid] 
		WHERE  [br].[Guid]  IS NOT NULL AND ac.Guid IS NOT NULL
		ORDER BY [ceBranch] DESC,	[acGuid] DESC 

		SELECT TOP 1
			ac.Guid	 [acGuid],[ac].[acName],[ac].[acCode],co.[CostGUID] [enCostPoint],	
			[CoName],[CoCode],[ac].[Security] [acSecurity],[co].[Security] [coSecurity]
		INTO #coacPtr
		FROM [#Result] r RIGHT JOIN [#CostTbl2] co ON co.[CostGUID] = [enCostPoint]
		RIGHT JOIN [#AccTbl2] ac ON [acGuid] = ac.Guid	
		WHERE ac.Guid IS NOT NULL AND [CostGUID] IS NOT NULL
		ORDER BY [enCostPoint]  DESC,	[acGuid] DESC 
		
		SELECT TOP 1
			[br].[Guid] [ceBranch] ,[BrName] [BranchName],[BrCode] [BranchCode],[br].[Security] [brSecurity],
			co.[CostGUID] [enCostPoint],[CoName],[CoCode],[acSecurity],[co].[Security] [coSecurity]
		INTO #coBrPtr
		FROM [#Result] r RIGHT JOIN [#CostTbl2] co ON co.[CostGUID] = [enCostPoint]
		RIGHT JOIN [#BranchTbl2] AS [br] ON [r].[ceBranch] = [br].[Guid]
		WHERE  co.[CostGUID] IS NOT NULL AND [br].[Guid] IS NOT NULL
		ORDER BY [enCostPoint]  DESC,[ceBranch] DESC 
		IF @shwEmptyCo > 0
			INSERT INTO [#Result]([ceBranch],[BranchName],[BranchCode],	
					[acGuid],[acName],[acCode],[enCostPoint],	
					[CostName],[CostCode],[FixedEnDebit],[FixedEnCredit],
					[Security],[acSecurity],[coSecurity],[brSecurity])	
			SELECT 
				[ceBranch],[BranchName],[BranchCode],	
					[acGuid],[acName],[acCode],[CostGUID],	
					[CoName],[CoCode],0,0,
					0,[acSecurity],[co].[Security],[brSecurity]
			FROM [#CostTbl2] CO , [#acBRPtr]
		IF @shwEmptyBr > 0
			INSERT INTO [#Result]([ceBranch],[BranchName],[BranchCode],	
					[acGuid],[acName],[acCode],[enCostPoint],	
					[CostName],[CostCode],[FixedEnDebit],[FixedEnCredit],
					[Security],[acSecurity],[coSecurity],[brSecurity])	
			SELECT
				[br].[Guid],[BrName] ,[BrCode],
				[acGuid],[acName],[acCode],[enCostPoint],	
					[CoName],[CoCode],0,0,
					0,[acSecurity],[coSecurity],[br].[Security]
			FROM #coacPtr C ,[#BranchTbl2] br
		IF @shwEmptyAcc > 0 	
			INSERT INTO [#Result]([ceBranch],[BranchName],[BranchCode],	
					[acGuid],[acName],[acCode],[enCostPoint],	
					[CostName],[CostCode],[FixedEnDebit],[FixedEnCredit],
					[Security],[acSecurity],[coSecurity],[brSecurity])	
			SELECT
				[ceBranch],[BranchName],[BranchCode],	
					[ac].[Guid],ac.[acName],ac.[acCode],[enCostPoint],	
					[CoName],[CoCode],0,0,
					0,[ac].[Security],[coSecurity],[brSecurity]
	 
			FROM #coBrPtr A,[#AccTbl2] ac
	END
	EXEC [prcCheckSecurity] 
	IF @shwEmptyAcc > 0 OR @shwEmptyCo > 0 OR @shwEmptyBr > 0
	BEGIN 
		IF @shwEmptyAcc = 0 
			DELETE r FROM [#Result] r INNER JOIN (SELECT [acGuid] FROM [#Result] GROUP BY [acGuid] HAVING SUM([FixedEnDebit]) = 0 AND  SUM([FixedEnCredit]) = 0) a ON a.[acGuid] = r.[acGuid]
		IF  @shwEmptyCo = 0
			DELETE r FROM [#Result] r INNER JOIN (SELECT [enCostPoint] FROM [#Result] GROUP BY [enCostPoint] HAVING SUM([FixedEnDebit]) = 0 AND  SUM([FixedEnCredit]) = 0) a ON a.[enCostPoint] = r.[enCostPoint]
		IF @shwEmptyBr = 0
			DELETE r FROM [#Result] r INNER JOIN (SELECT [ceBranch] FROM [#Result] GROUP BY [ceBranch] HAVING SUM([FixedEnDebit]) = 0 AND  SUM([FixedEnCredit]) = 0) a ON a.[ceBranch] = r.[ceBranch]
	END
	--	IA_COST,	0 
	--	IA_ACC, 	1 
	--	IA_BRANCH, 	2 
	IF (@AccLevel <> 0)
	BEGIN
		CREATE TABLE [#TAcc]
		(
			[Id] [INT] IDENTITY(1,1),
			[Guid] [UNIQUEIDENTIFIER],
			[Level] [INT], 
			[acCode] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[acName] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[ParentGuid] [UNIQUEIDENTIFIER]
		)
		INSERT INTO [#TAcc]
		(
			[Guid] ,[Level],[acCode],[acName],[ParentGuid]
		)
		SELECT [f].[Guid],[LEVEL],[ac].[Code] AS [acCode],CASE @Lang WHEN 0 THEN [ac].[Name] ELSE CASE [ac].[LatinName] WHEN '' THEN [ac].[Name] ELSE [ac].[LatinName] END END ,[ParentGuid]
		FROM [fnGetAccountsList](@AccGUID,@Sorted) AS [f] INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [f].[Guid]
		ORDER BY [Path]
		
		UPDATE [r]
		SET 
		[acLevel] = [ac].[Level] ,	[MainAcc] = [ParentGuid],[IdAcc]= [ac].[Id]
		FROM [#Result] AS [r] INNER JOIN [#TAcc] AS [ac] ON [ac].[Guid] = [acGuid]
		
		SELECT @Cnt = MAX([acLevel]) FROM [#Result]
		WHILE  @Cnt > 0
		BEGIN
		INSERT INTO[#Result]
			( [ceBranch],[BranchName],[BranchCode],[acGuid],[acName],[acCode],[enCostPoint],[CostName], 
			[CostCode],	[FixedEnDebit],	[FixedEnCredit],[acLevel],[coLevel],[MainAcc],	[MainCost],[IdAcc],[IdCost],
	 		[Flag]) 
	 		SELECT  [ceBranch],[BranchName],[BranchCode],[ac].[Guid],[ac].[acName],[ac].[acCode]
			,[enCostPoint],[CostName], 
			[CostCode],	SUM([FixedEnDebit]),SUM([FixedEnCredit]),[ac].[Level],[coLevel],[ac].[ParentGuid],[MainCost],[ac].[Id],[IdCost],
	 		[Flag]
			FROM [#Result] AS [r] INNER JOIN [#TAcc] AS [ac] ON [ac].[Guid] = [MainAcc]
			WHERE [acLevel] = @Cnt
			GROUP BY
			[ceBranch],[BranchName],[BranchCode],[ac].[Guid],[ac].[acName],[ac].[acCode]
			,[enCostPoint],[CostName], 
			[CostCode],[ac].[Level],[coLevel],[ac].[ParentGuid],[MainCost],[ac].[Id],[IdCost],
	 		[Flag]
			SET @Cnt = @Cnt -1 
		END
		DELETE [#RESULT] 	WHERE [acLevel] >= (@AccLevel )
	END
	
	IF (@CostLevel<>0)
	BEGIN
		CREATE TABLE [#TCost]
		(
			[Id] [INT] IDENTITY(1,1),
			[Guid] [UNIQUEIDENTIFIER],
			[Level] [INT],  
			[coCode] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[coName] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[ParentGuid] [UNIQUEIDENTIFIER]
		)
		INSERT INTO [#TCost]
		(
			[Guid],[Level] ,[coCode],[coName],[ParentGuid]
		)
		SELECT [f].[Guid],[LEVEL],[co].[Code] AS [acCode],CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE [co].[LatinName] WHEN '' THEN [co].[Name] ELSE [co].[LatinName] END END ,[ParentGuid]
		FROM [fnGetCostsListWithLevel](@CostGUID,@Sorted) AS [f] INNER JOIN [co000] AS [co] ON [co].[Guid] = [f].[Guid]
		ORDER BY [Path]
		SET @Cnt = (SELECT MAX([LEVEL]) FROM [fnGetCostsListWithLevel](@CostGUID,1)  ) 
		
		UPDATE [r]
		SET 
		[coLevel] = [co].[Level] ,	[MainCost] = [ParentGuid],[IdCost]= [co].[Id]
		FROM [#Result] AS [r] INNER JOIN [#TCost] AS [co] ON [co].[Guid] = [enCostPoint]
		
		SELECT @Cnt = MAX([coLevel]) FROM [#Result]
		WHILE  @Cnt > 0
		BEGIN
		INSERT INTO[#Result]
			( [ceBranch],[BranchName],[BranchCode],[acGuid],[acName],[acCode],[enCostPoint],[CostName], 
			[CostCode],	[FixedEnDebit],	[FixedEnCredit],[acLevel],[coLevel],[MainAcc],	[MainCost],[IdAcc],[IdCost],
	 		[Flag]) 
	 		SELECT  [ceBranch],[BranchName],[BranchCode],[acGuid],[acName],[acCode],
			[co].[Guid],[co].[coName], 
			[co].[coCode],	SUM([FixedEnDebit]),SUM([FixedEnCredit]),[acLevel],[co].[Level],[co].[ParentGuid],[MainCost],[IdAcc],[co].[Id],
	 		[Flag]
			FROM [#Result] AS [r] INNER JOIN [#TCost] AS [co] ON [co].[Guid] = [MainCost]
			WHERE [coLevel] = @Cnt
			GROUP BY 
			[ceBranch],[BranchName],[BranchCode],[acGuid],[acName],[acCode],
			[co].[Guid],[co].[coName], 
			[co].[coCode],[acLevel],[co].[Level],[co].[ParentGuid],[MainCost],[IdAcc],[co].[Id],
	 		[Flag]
			SET @Cnt = @Cnt -1 
		END
		DELETE [#RESULT] 	WHERE [coLevel] >= (@CostLevel + 1)
	END

	IF @HrzAxis = 1 
	BEGIN
		
		INSERT INTO [#RESULT] ([enCostPoint], [CostName], [CostCode], [FLAG],[IdCost]) SELECT DISTINCT [enCostPoint], [CostName], [CostCode], -1,[IdCost] FROM [#RESULT] WHERE [enCostPoint] IS NOT NULL
	END
	IF @HrzAxis = 2 
		INSERT INTO [#RESULT] ([acGuid], [acName], [acCode], [FLAG],[IdAcc])   SELECT DISTINCT [acGuid], [acName], [acCode],-1,[IdAcc] FROM [#RESULT]
	
	IF @HrzAxis = 3 
		INSERT INTO [#RESULT] ([ceBranch], [BranchName], [BranchCode], [FLAG]) SELECT DISTINCT [ceBranch], [BranchName], [BranchCode], -1 FROM [#RESULT]
		 
	SET @s = ' SELECT ' 
	IF @MainAxis = 0 
		SET @s = @s + 'FLAG'   
	IF @MainAxis = 1 
		SET @s = @s + '	[enCostPoint], [CostName], [CostCode], [FLAG] ' 
	IF @MainAxis = 2 
		SET @s = @s + '	[acGuid], [acName], [acCode], [FLAG]' 
	IF @MainAxis = 3 
		SET @s = @s + '	[ceBranch], [BranchName], [BranchCode], [FLAG] ' 
	IF @VrtAxis = 1 
		SET @s = @s + '	,[enCostPoint], [CostName], [CostCode] ' 
	IF @VrtAxis = 2 
		SET @s = @s + '	,[acGuid], [acName], [acCode]' 
	IF @VrtAxis = 3 
		SET @s = @s + '	,[ceBranch], [BranchName], [BranchCode] ' 
	IF @HrzAxis = 1 
		SET @s = @s + '	,[enCostPoint], [CostName], [CostCode] ' 
	IF @HrzAxis = 2 
		SET @s = @s + '	,[acGuid], [acName], [acCode]' 
	IF @HrzAxis = 3 
		SET @s = @s + '	,[ceBranch], [BranchName], [BranchCode] ' 
	SET @s = @s + '	,SUM( ISNULL( [FixedEnDebit], 0) - ISNULL( [FixedEnCredit], 0)) AS [Bal]' 
	
	IF (@AccLevel<>0) AND (@MainAxis = 2)
		SET @s = @s + ',[acLevel] AS [MLevel]'
	ELSE IF (@CostLevel<>0) AND (@MainAxis = 1)
		SET @s = @s + ',ISNULL([coLevel], 0) AS [MLevel]'
	ELSE 
		SET @s = @s + ',0 AS [MLevel]'
	
	IF (@AccLevel<>0) AND (@HrzAxis = 2)
		SET @s = @s + ',[acLevel] AS [HLevel]'
	ELSE IF (@CostLevel<>0) AND (@HrzAxis = 1)
		SET @s = @s + ',ISNULL([coLevel], 0) AS [HLevel]'
	ELSE 
		SET @s = @s + ',0 AS [HLevel]'
	SET @s = @s + ' FROM [#Result] AS [r] ' 
	
	SET @s = @s + ' GROUP BY ' 
	IF @MainAxis = 0 
		SET @s = @s + '[FLAG] ' 
	IF @MainAxis = 1 
		SET @s = @s + '	[enCostPoint], [CostName], [CostCode], [FLAG] ' 
	IF @MainAxis = 2 
		SET @s = @s + '	[acGuid], [acName], [acCode], [FLAG]' 
	IF @MainAxis = 3 
		SET @s = @s + '	[ceBranch], [BranchName], [BranchCode], [FLAG] ' 
	IF @VrtAxis = 1 
		SET @s = @s + '	,[enCostPoint], [CostName], [CostCode] ' 
	IF @VrtAxis = 2 
		SET @s = @s + '	,[acGuid], [acName], [acCode]' 
	IF @VrtAxis = 3 
		SET @s = @s + '	,[ceBranch], [BranchName], [BranchCode] ' 
	IF @HrzAxis = 1 
		SET @s = @s + '	,[enCostPoint], [CostName], [CostCode] ' 
	IF @HrzAxis = 2 
		SET @s = @s + '	,[acGuid], [acName], [acCode] ' 
	IF @HrzAxis = 3 
		SET @s = @s + '	,[ceBranch], [BranchName], [BranchCode] ' 
	
	IF (@AccLevel<>0) AND (@MainAxis = 2)
		SET @s = @s +  ', [acLevel]'
	ELSE IF (@CostLevel<>0) AND (@MainAxis = 1)
		SET @s = @s + ',ISNULL([coLevel], 0) '
	IF (@AccLevel<>0) AND (@HrzAxis = 2)
		SET @s = @s + ', [acLevel]'
	ELSE IF (@CostLevel<>0) AND (@HrzAxis = 1)
		SET @s = @s + ',ISNULL([coLevel], 0) '
	
	IF (@AccLevel<>0)
		SET @s = @s + ',[idAcc]  '
	IF (@CostLevel<>0)
		SET @s = @s + ',[idCost]  '
	
	IF @MainAxis = 0 -- cost point 
	BEGIN
		IF (@VrtAxis = 2) AND (@AccLevel = 0) AND (@Sorted = 1) 
			SET @s = @s + '	 ORDER BY [FLAG], [acCode]' 
		IF (@VrtAxis = 2) AND (@AccLevel = 0) AND (@Sorted = 2) 
			SET @s = @s + '	 ORDER BY [FLAG], [acName]' 
		IF (@VrtAxis = 2) AND (@AccLevel <> 0)
			SET @s = @s + ' ORDER BY [FLAG], [idAcc]  '
		IF (@VrtAxis = 3) AND (@Sorted = 1)  
			SET @s = @s + '	ORDER BY [FLAG], [BranchCode] ' 
		IF (@VrtAxis = 3) AND (@Sorted = 2)  
			SET @s = @s + '	ORDER BY [FLAG], [BranchName] '
		IF (@VrtAxis = 1) AND (@CostLevel = 0) AND (@Sorted = 1)
			SET @s = @s + ' ORDER BY [FLAG], [CostCode] ' 
		IF (@VrtAxis = 1) AND (@CostLevel = 0) AND (@Sorted = 2)
			SET @s = @s + ' ORDER BY [FLAG], [CostName] ' 
		IF (@VrtAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' ORDER BY [FLAG], [idCost]  '
		IF (@HrzAxis = 2) AND (@AccLevel = 0) AND (@Sorted = 1)
			SET @s = @s + ',[acCode] ' 
		IF (@HrzAxis = 2) AND (@AccLevel = 0) AND (@Sorted = 2)
			SET @s = @s + ' ,[acName] ' 
		IF (@HrzAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ' ,[idAcc]  ' 
		IF (@HrzAxis = 1) AND (@CostLevel = 0) AND (@Sorted = 1)
			SET @s = @s + ' ,[CostCode] ' 
		IF (@HrzAxis = 1) AND (@CostLevel = 0) AND (@Sorted = 2)
			SET @s = @s + ' ,[CostName] ' 
		IF (@HrzAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' ,[idCost]  '
		IF (@HrzAxis = 3) AND (@Sorted = 1)  
			SET @s = @s + '	,[BranchCode] ' 
		IF (@HrzAxis = 3) AND (@Sorted = 2)  
			SET @s = @s + '	,[BranchName] '  
	END
	IF @MainAxis = 2 AND @Sorted = 1 -- Acc code 
	BEGIN
		IF (@AccLevel = 0)
			SET @s = @s + ' ORDER BY [FLAG], [acCode] ' 
		ELSE
			SET @s = @s + ' ORDER BY [FLAG], [idAcc]  ' 
		IF (@VrtAxis = 1) AND (@CostLevel = 0)
			SET @s = @s + ' ,[CostCode] ' 
		IF (@VrtAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' ,[idCost]  '
		IF (@VrtAxis = 3) 
			SET @s = @s + '	,[BranchCode] '
		IF (@HrzAxis = 1) AND (@CostLevel = 0) 
			SET @s = @s + ' ,[CostCode] '
		IF (@HrzAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ',[idCost]  ' 
		IF (@HrzAxis = 3) 
			SET @s = @s + '	,[BranchCode] '
		
	END
	IF @MainAxis = 2 AND @Sorted = 2 -- Acc name 
	BEGIN
		IF (@AccLevel = 0)
			SET @s = @s + ' ORDER BY [FLAG], [acName] '
		ELSE
			SET @s = @s + ' ORDER BY [FLAG], [idAcc]  '
		
		IF (@VrtAxis = 1) AND (@CostLevel = 0)
			SET @s = @s + ' ,[CostName] ' 
		IF (@VrtAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' ,[idCost]  '
		IF (@VrtAxis = 3) 
			SET @s = @s + '	,[BranchName] '
		IF (@HrzAxis = 1) AND (@CostLevel = 0)
			SET @s = @s + ' ,[CostName] ' 
		IF (@HrzAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' ,[idCost]  '
		IF (@HrzAxis = 3) 
			SET @s = @s + '	,[BranchName] '
	END
	
	IF @MainAxis = 1 AND @Sorted = 1 -- Acc code 
	BEGIN
		IF (@CostLevel = 0)
			SET @s = @s + ' ORDER BY [FLAG], [CostCode] ' 
		ELSE
			SET @s = @s + ' ORDER BY [FLAG], [idCost]  ' 
		IF (@VrtAxis = 2) AND (@AccLevel = 0)
			SET @s = @s + ' ,[acCode] ' 
		IF (@VrtAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ' ,[idAcc]  '
		IF (@VrtAxis = 1) AND (@CostLevel = 0)
			SET @s = @s + ' ,[CostCode] ' 
		IF (@VrtAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' ,[idCost]  '
		IF (@HrzAxis = 2) AND (@AccLevel = 0) 
			SET @s = @s + ' ,[acCode] '
		IF (@HrzAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ',[idAcc]  '
		IF (@HrzAxis = 3) 
			SET @s = @s + '	,[BranchCode] ' 
	END
	IF @MainAxis = 1 AND @Sorted = 2 -- Acc name 
	BEGIN
		IF (@CostLevel = 0)
			SET @s = @s + ' ORDER BY [FLAG], [CostName] '
		ELSE
			SET @s = @s + ' ORDER BY [FLAG], [idCost]  '
		IF (@VrtAxis = 2) AND (@AccLevel = 0)
			SET @s = @s + ' , [acName] ' 
		IF (@VrtAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ' , [idAcc]  '
		IF (@VrtAxis = 3) 
			SET @s = @s + '	,[BranchName] '
			
		IF (@HrzAxis = 2) AND (@AccLevel = 0) 
			SET @s = @s + ' ,[acName] '
		IF (@HrzAxis = 2) AND (@AccLevel <> 0)  
			SET @s = @s + ',[idAcc]  ' 
		IF (@HrzAxis = 3) 
			SET @s = @s + '	,[BranchName] '  
	END
	IF @MainAxis = 3 AND @Sorted = 1 -- branch code 
	BEGIN
		SET @s = @s + ' ORDER BY [FLAG], [BranchCode] '
		
		IF (@VrtAxis = 2) AND (@AccLevel = 0)
			SET @s = @s + ' ,[acCode] ' 
		IF (@VrtAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ' ,[idAcc]  '
		IF (@HrzAxis = 2) AND (@AccLevel = 0) AND (@Sorted = 1)
			SET @s = @s + ',[acCode] ' 
		IF (@HrzAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ' , [idAcc]  ' 
		IF (@HrzAxis = 1) AND (@CostLevel = 0) AND (@Sorted = 1)
			SET @s = @s + ' , [CostCode] ' 
		IF (@HrzAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' , [idCost]  '  
	END
	IF @MainAxis = 3 AND @Sorted = 2 -- branch name 
	BEGIN
		SET @s = @s + ' ORDER BY [FLAG], [BranchName] ' 
		--	SET @s = @s + ' ORDER BY mtModel '
		
		IF (@VrtAxis = 1) AND (@CostLevel = 0)
			SET @s = @s + ' ,[CostName] ' 
		IF (@VrtAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' ,[idCost]  '
		IF (@VrtAxis = 2) AND (@AccLevel = 0)
			SET @s = @s + ' ,[acName] ' 
		IF (@VrtAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ' ,[idAcc]  '	
		IF (@HrzAxis = 2) AND (@AccLevel = 0) 
			SET @s = @s + ', [acName] ' 
		IF (@HrzAxis = 2) AND (@AccLevel <> 0) 
			SET @s = @s + ' , [idAcc]  ' 
		IF (@HrzAxis = 1) AND (@CostLevel = 0) 
			SET @s = @s + ' , [CostName] ' 
		IF (@HrzAxis = 1) AND (@CostLevel <> 0) 
			SET @s = @s + ' , [idCost]  '   
	END
	EXECUTE ( @s) 

	SELECT * FROM [#SecViol]	
/*
	prcConnections_add2 '„œÌ—'
	EXEC [repBranchesMovement] '12/31/2007 0:0:0.0', '6/16/2008 23:59:59.998', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'e8e66a6e-2262-4dd2-bd71-e63fe58a8eba', 0.019608, 1, 3, 2, 1, 0, 0, 0, 0
*/
########################################################################
#END
