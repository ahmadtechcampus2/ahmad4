###########################################################################
CREATE  PROCEDURE RepCostTrial
	@AccGUID AS [UNIQUEIDENTIFIER],  
	@CostGUID AS [UNIQUEIDENTIFIER],  
	@Class AS [NVARCHAR](256),  
	@StartDate AS [DATETIME],  
	@EndDate AS [DATETIME],  
	@CurGUID AS [UNIQUEIDENTIFIER],  
	@CurVal AS [FLOAT], 
	@CostLevel AS [INT] =0, 
	@AcLevel AS [INT] =0, 
	@HrAxe		[INT] = 1, 
	@Lang		[INT] = 0, 
	@SrcGuid	[UNIQUEIDENTIFIER] = 0X0, 
	@ShwEmptyCost BIT = 0, 
	@ShwEmptyAcc BIT = 0,
	@ShwBalCost BIT = 0, 
	@ShwBalAcc BIT = 0,
	@ShwMainAcc BIT = 0,
	@ShowNoJobcostMovements BIT = 0
AS  
	DECLARE @Admin [INT] ,@ZeroValue [FLOAT]
	DECLARE	@str NVARCHAR(2000),@HosGuid UNIQUEIDENTIFIER 
	SET @HosGuid = NEWID() 
	SET NOCOUNT ON 
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserEnSec [INT]  
	--DECLARE @c CURSOR; تعريف بدون استخدام
	DECLARE @G [UNIQUEIDENTIFIER],@L [INT] 
	DECLARE @MaxLevel [INT] 
	SET @ZeroValue = [dbo].[fnGetZeroValuePrice]() 	 
	Set @UserGUID = [dbo].[fnGetCurrentUserGUID]()   
	Set @UserEnSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#AccTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT])   
	CREATE TABLE [#CostTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT])   
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])     
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])     
	CREATE TABLE [#Result] 
		(  
		[CostPoint]		[UNIQUEIDENTIFIER],  
		[CostSecurity]	[INT],  
		[Account]		[UNIQUEIDENTIFIER],  
		[AccSecurity]	[INT],  
		[Debit]			[FLOAT],  
		[Credit]		[FLOAT],  
		[Security]		[INT],   
		[UserSecurity]	[INT], 
		[coParent]		[UNIQUEIDENTIFIER],  
		[coPath]		[NVARCHAR](1000), 
		[coLevel]		[INT], 
		[acParent]		[UNIQUEIDENTIFIER],  
		[acPath]		[NVARCHAR](1000), 
		[acLevel]		[INT], 
		[Flag]			[INT] DEFAULT 0, 
		[Code]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[Name]		[NVARCHAR](256) COLLATE ARABIC_CI_AI 
		)  
	 
	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccGUID  
	 
	IF (@AccGUID <> 0X00) AND ((SELECT count(*) FROM AC000 WHERE GUID = @AccGUID AND TYPE = 4)<>0) 
	BEGIN 
		DECLARE @COL INT 
		SET @COL = 1 
		set @L = 0 
		CREATE TABLE #COL(g UNIQUEIDENTIFIER,Type INT,Level int) 
		INSERT INTO #COL SELECT SonGUID,ac.Type,@L FROM CI000 CI INNER JOIN ac000 AC ON ci.ParentGUID = ac.GUID WHERE ac.GUID =  @AccGUID 
		WHILE @COL > 0 
		BEGIN 
			set @L = @L + 1 
			INSERT INTO #COL SELECT SonGUID,ac.Type,@L FROM CI000 CI INNER JOIN ac000 AC ON ci.ParentGUID = ac.GUID inner join #COL col on ac.GUID = g WHERE Level = @L - 1 
			SET @COL = @@ROWCOUNT 
		END  
		UPDATE [#AccTbl]SET [Lvl] = 0 FROM [#AccTbl] INNER JOIN #COL ON G = [Number] 
		SET @COL = 1 
		WHILE  @COL > 0 
		BEGIN 
			 UPDATE a  SET [Lvl] = B.[Lvl] + 1 from [#AccTbl]a INNER JOIN AC000 ac ON a.Number = ac.Guid INNER JOIN  [#AccTbl] b ON b.NUMBER = ac.ParentGuid WHERE A.[Lvl] > (B.[Lvl] + 1) 
			  SET @COL = @@ROWCOUNT 
		END  
		 
		 
	END	 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID  
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID     
	 
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID     
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID  
	 
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl] 
	IF [dbo].[fnObjectExists]( 'prcGetTransfersTypesList') <> 0	 
		INSERT INTO [#EntryTbl]	EXEC [prcGetTransfersTypesList] 	@SrcGuid 
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0 
	BEGIN		 
		SET @str = 'INSERT INTO [#EntryTbl] 
		SELECT 
					[IdType], 
					[dbo].[fnGetUserSec](''' + CAST(@UserGUID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1) 
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
					[dbo].[fnGetUserSec](''' + CAST(@UserGUID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1) 
				FROM 
					[dbo].[RepSrcs] AS [r]  
					INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid] 
				WHERE 
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + '''' 
		EXEC(@str) 
	END 			 
					 
	IF EXISTS(SELECT * FROM [dbo].[RepSrcs] WHERE [IDSubType] = 303) 
		INSERT INTO [#EntryTbl] VALUES(@HosGuid,0) 
	CREATE TABLE [#CostTbl2]( [GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ParentGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#CostTbl2]
			SELECT [f].[GUID] AS [GUID], [Level],[Path],[ParentGuid],[co1].[Security]
				FROM [fnGetCostsListWithLevel](@CostGUID, 0) AS [f]  
				INNER JOIN [co000] AS [co] ON [co].[Guid] = [f].[Guid] 
				INNER JOIN [#CostTbl] AS [co1] ON [f].[Guid] = [co1].[Number]
	CREATE CLUSTERED INDEX [TRLCOcoInd] ON [#CostTbl2]([GUID]) 
	 
	SELECT [f].[GUID] AS [GUID],[ac1].[Lvl] [Level],[Path],[ParentGuid],[ac1].[Security],[ac].[NSons] 
	INTO [#AccTbl2] 
	FROM [fnGetAccountsList](@AccGUID, 0) AS [f]  
	INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [f].[Guid] 
	INNER JOIN [#AccTbl] AS [ac1] ON [ac1].[Number] = [ac].[Guid] 
	 
	CREATE CLUSTERED INDEX [TRLCOacInd] ON [#AccTbl2]([GUID]) 
IF @ShowNoJobcostMovements = 0
BEGIN	 	 
	INSERT INTO [#Result]  
		SELECT    
			[ce].[enCostPoint],  
			[co].[Security],  
			[ce].[enAccount],    
			[ac].[Security],  
			SUM([ce].[FixedEnDebit]),     
			SUM([ce].[FixedEnCredit]),  
			[ce].[ceSecurity],  
			@UserEnSec, 
			[co].[ParentGuid], 
			[co].[Path],[co].[Level],[ac].[ParentGuid],[ac].[Path],[ac].[Level],0,'','' 
		FROM   
			[dbo].[fnCeEn_Fixed]( @CurGUID) As [ce]   
			INNER JOIN [#CostTbl2] AS [co]     
			ON [ce].[enCostPoint] = [co].[GUID]  
			INNER JOIN [#AccTbl2] AS [ac]     
			ON [ce].[enAccount] = [ac].[GUID]  
			INNER JOIN [#EntryTbl] AS [t]  ON [ce].[ceTypeGuid] = [t].[Type]    
		WHERE   
		( @Class = '' OR [enClass] = @Class ) AND  
		[EnDate] BETWEEN @StartDate AND @EndDate   
		GROUP BY   
			[ce].[enCostPoint],  
			[co].[Security],  
			[ce].[enAccount],    
			[ac].[Security],  
			[ce].[ceSecurity],  
			[co].[ParentGuid], 
			[co].[Path],[co].[Level],[ac].[ParentGuid],[ac].[Path],[ac].[Level] 
END
ELSE
BEGIN
		INSERT INTO [#Result]  
		SELECT    
			[ce].[enCostPoint],  
			[co].[Security],  
			[ce].[enAccount],    
			[ac].[Security],  
			SUM([ce].[FixedEnDebit]),     
			SUM([ce].[FixedEnCredit]),  
			[ce].[ceSecurity],  
			@UserEnSec, 
			[co].[ParentGuid], 
			[co].[Path],[co].[Level],[ac].[ParentGuid],[ac].[Path],[ac].[Level],0,'','' 
		FROM   
			[dbo].[fnCeEn_Fixed]( @CurGUID) As [ce]   
			-- 99
			LEFT JOIN [#CostTbl2] AS [co] ON [ce].[enCostPoint] = [co].[GUID]  
			INNER JOIN [#AccTbl2] AS [ac] ON [ce].[enAccount] = [ac].[GUID]  
			INNER JOIN [#EntryTbl] AS [t]  ON [ce].[ceTypeGuid] = [t].[Type]    
		WHERE   
		( @Class = '' OR [enClass] = @Class ) AND  
		[EnDate] BETWEEN @StartDate AND @EndDate   
		GROUP BY   
			[ce].[enCostPoint],  
			[co].[Security],  
			[ce].[enAccount],    
			[ac].[Security],  
			[ce].[ceSecurity],  
			[co].[ParentGuid], 
			[co].[Path],[co].[Level],[ac].[ParentGuid],[ac].[Path],[ac].[Level] 
END
	IF @ShwEmptyCost > 0 OR @ShwEmptyAcc > 0 
	BEGIN 
		INSERT INTO [#Result] ([CostPoint],[CostSecurity],[Account],[AccSecurity],[Security],[UserSecurity],[coParent],[coPath],[coLevel],[acParent],[acPath],[acLevel],[Flag],[Code],[Name])  
		SELECT    
			[co].[GUID] ,  
			[co].[Security],  
			ac.Guid,    
			[ac].[Security],  
			  
			0, 
			0, 
			[co].[ParentGuid], 
			[co].[Path],[co].[Level],[ac].[ParentGuid],[ac].[Path],[ac].[Level],0,'','' 
		FROM   
			 [#CostTbl2] AS [co]  ,( SELECT  v.[GUID],v.[Security],v.[ParentGuid],v.[Path],v.[Level] FROM [#AccTbl2] v  where nsons = 0 ) ac 
		
	END	 
	 
	IF @ShwEmptyCost > 0 AND @ShwEmptyAcc = 0 
	BEGIN 
		DELETE r from [#Result] r INNER JOIN (SELECT [Account] FROM [#Result] GROUP BY [Account] HAVING SUM([Debit])  IS NULL AND SUM([Credit])IS NULL) v ON v.[Account] = r.[Account] 
	END 
	IF @ShwEmptyCost = 0 AND @ShwEmptyAcc > 0 
	BEGIN 
		DELETE r from [#Result] r INNER JOIN (SELECT [CostPoint] FROM [#Result] GROUP BY [CostPoint] HAVING SUM([Debit]) IS NULL AND SUM([Credit])IS NULL) v ON v.[CostPoint] = r.[CostPoint]   
	END 
	IF @ShwBalCost = 0 
	BEGIN 
		DELETE r from [#Result] r INNER JOIN (SELECT [CostPoint] FROM [#Result] GROUP BY [CostPoint] HAVING ABS (SUM([Debit]-[Credit]))<@ZeroValue ) v ON v.[CostPoint] = r.[CostPoint]
	END 
	IF  @ShwBalAcc = 0 
	BEGIN 
		DELETE r from [#Result] r INNER JOIN (SELECT [Account] FROM [#Result] GROUP BY [Account] HAVING ABS (SUM([Debit]-[Credit]))<@ZeroValue ) v ON v.[Account] = r.[Account]
	END
	
	EXEC [prcCheckSecurity] @UserGuid  
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) ) 
	IF @Admin = 0 
	BEGIN 
		DECLARE @CoSecurity [INT]	 
		SET @CoSecurity = [dbo].[fnGetUserCostSec_Browse](@UserGuid) 
		SET @MaxLevel = 1 
		WHILE @MaxLevel > 0 
		BEGIN 
			UPDATE [co] SET [ParentGuid] = [c].[ParentGuid],[Level] = [co].[Level] -1 FROM [#CostTbl2] AS [co] INNER JOIN [#CostTbl2] AS [c] ON [co].[ParentGuid] = [c].[Guid] WHERE [c].[Security] > @CoSecurity 
			SET @MaxLevel = @@RowCount 
		END 
		UPDATE [r] SET [coParent] = [co].[ParentGuid],[coLevel] = [co].[Level] + 1  FROM [#Result] AS [r]  INNER JOIN [#CostTbl2] AS [co] ON [r].[coParent] = [co].[Guid] 
		WHERE [co].[Security] > @CoSecurity  
		DELETE [#CostTbl2] WHERE [Security] > @CoSecurity 
		 
	END 
	SELECT @MaxLevel = MAX([Level]) FROM [#CostTbl2] 
	WHILE @MaxLevel >= 0 
	BEGIN 
		INSERT INTO [#Result]([CostPoint],[Account],[Debit],[Credit],[coParent],[coPath],[coLevel],[acParent],[acPath],[acLevel]) 
			SELECT [co].[Guid],[Account],SUM([Debit]),SUM([Credit]),[co].[ParentGuid],[co].[Path],[co].[Level],[acParent],[acPath],[acLevel] 
			FROM [#Result] AS [r] INNER JOIN [#CostTbl2] AS [co] ON [r].[coParent] = [co].[Guid] 
			WHERE [r].[coLevel] =  @MaxLevel 
			GROUP BY [co].[Guid],[Account],[co].[ParentGuid],[co].[Path],[co].[Level],[acParent],[acPath],[acLevel] 
		SET @MaxLevel = @MaxLevel - 1 
	END  
	IF @Admin = 0 
	BEGIN 
		DECLARE @AccSecurity [INT]	 
		SET @AccSecurity = [dbo].[fnGetUserAccountSec_Browse](@UserGuid) 
		SET @MaxLevel = 1 
		WHILE @MaxLevel > 0 
		BEGIN 
			UPDATE [ac] SET [ac].[ParentGuid] = [a].[ParentGuid],[Level] = [ac].[Level] -1 FROM [#AccTbl2] AS [ac] INNER JOIN [#AccTbl2] AS [a] ON [ac].[ParentGuid] = [a].[Guid] WHERE [a].[Security] > @AccSecurity 
			SET @MaxLevel = @@RowCount 
		END 
		UPDATE [r] SET [acParent] = [ac].[ParentGuid],[acLevel] = [ac].[Level] + 1  FROM [#Result] AS [r]  INNER JOIN [#AccTbl2] AS [ac] ON [r].[acParent] = [ac].[Guid] 
		WHERE [ac].[Security] > @AccSecurity  
		DELETE [#AccTbl2] WHERE [Security] > @AccSecurity 
		IF EXISTS(SELECT * FROM [#SecViol] WHERE [Type] = 5) 
			INSERT INTO [#SecViol] VALUES(@@RowCount,5) 
		 
	END 
	SELECT @MaxLevel = MAX([Level]) FROM [#AccTbl2]
	IF  @ShwMainAcc = 1 
	BEGIN 
		WHILE @MaxLevel >= 0 
		BEGIN 
			INSERT INTO [#Result]([CostPoint],[Account],[Debit],[Credit],[coParent],[coPath],[coLevel],[acParent],[acPath],[acLevel]) 
				SELECT [CostPoint],[ac].[Guid],SUM([Debit]),SUM([Credit]),[coParent],[coPath],[coLevel],[ac].[ParentGuid],[ac].[Path],[ac].[Level] 
				FROM [#Result] AS [r] INNER JOIN [#AccTbl2] AS [ac] ON [r].[acParent] = [ac].[Guid] 
				WHERE [r].[acLevel] =  @MaxLevel 
				GROUP BY [CostPoint],[ac].[Guid],[coParent],[coPath],[coLevel],[ac].[ParentGuid],[ac].[Path],[ac].[Level] 
			SET @MaxLevel = @MaxLevel - 1 
		END  
	END
	IF @HrAxe = 1 
	BEGIN 
		INSERT INTO #RESULT([CostPoint],[coPath],[coLevel],[Code],[Name],[Flag],[acLevel] ) 
			SELECT  [co2].[GUID],[co2].[Path], [co2].[Level],[co].[Code],CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE [co].[LAtinName] WHEN '' THEN  [co].[Name] ELSE [co].[LatinName] END  END , -1,0  
			FROM [#CostTbl2] AS [co2]  
			INNER JOIN [co000] AS [co] ON [co2].[Guid] =  [co].[Guid] 
			INNER JOIN [#RESULT] as [r] ON [r].[CostPoint] =  [co].[Guid] 
			
		UPDATE [r] SET [Name] = CASE @Lang WHEN 0 THEN [ac].[Name] ELSE CASE [ac].[LatinName] WHEN '' THEN  [ac].[Name] ELSE [ac].[LatinName] END  END ,[Code] = [ac].[Code] FROM [#Result] AS [r] INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [r].[Account] 
		IF @ShowNoJobcostMovements	<> 0 
		BEGIN
			IF ((SELECT COUNT(*) FROM #Result) > 0)
				INSERT INTO #RESULT([CostPoint],[coPath],[coLevel],[Code],[Name],[Flag],[acLevel] ) 
				VALUES(0x0, 0, 0, '', '', -1, 0 )	 
		END
	END 
	ELSE 
	BEGIN 
		INSERT INTO #RESULT([Account],[acPath],[acLevel],[Code],[Name],[Flag],[coLevel] ) 
			SELECT  [ac2].[GUID],[ac2].[Path], [ac2].[Level],[ac].[Code],CASE @Lang WHEN 0 THEN [ac].[Name] ELSE CASE [ac].[LatinName] WHEN '' THEN  [ac].[Name] ELSE [ac].[LatinName] END  END  , -1,0  
			FROM [#AccTbl2] AS [ac2]  
			INNER JOIN [ac000] AS [ac] ON [ac2].[Guid] =  [ac].[Guid] 
			INNER JOIN [#RESULT] as [r] ON [r].[Account] =  [ac].[Guid] 
		UPDATE [r] SET [Name] = CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE [co].[LAtinName] WHEN '' THEN  [co].[Name] ELSE [co].[LatinName] END  END,[Code] = [co].[Code] FROM [#Result] AS [r] INNER JOIN [co000] AS [co] ON [co].[Guid] = [r].[CostPoint] 
		 
	END 
	IF @HrAxe = 1
	BEGIN
		MERGE INTO [#Result] WITH (HOLDLOCK) AS target
		USING (SELECT ParentGUID, GUID FROM co000) AS source
			ON target.[CostPoint] = source.GUID AND target.[Flag] = -1
		WHEN MATCHED THEN 
			UPDATE SET target.coParent = source.ParentGUID;
	END
	ELSE
	BEGIN
		MERGE INTO [#Result] WITH (HOLDLOCK) AS target
		USING (SELECT ParentGUID, GUID FROM ac000) AS source
			ON target.[Account] = source.GUID AND target.[Flag] = -1
		WHEN MATCHED THEN 
			UPDATE SET target.[acParent] = source.ParentGUID;
	END
	IF (@HrAxe = 1)
		SELECT [r].[CostPoint], [r].[Account], [r].[acParent], [r].[coParent], 
		ISNULL(SUM([r].[Debit]), 0) AS [Debit], 
		ISNULL(SUM([r].[Credit]), 0) AS [Credit], 
		[coLevel], 
		[acLevel], 
		[r].[Code], 
		[r].[Name],
		ISNULL([r].[Code], '') + '-' + ISNULL([r].[Name], '') AS [CodeName],
		[Flag],
		CASE @HrAxe WHEN 1 THEN [acPath] ELSE  [coPath] END AS Path,
		ISNULL([ac].NSons, -1) AS NSons,
		ISNULL([CostChildren].DirectChildren, -1) AS DirectChildren,
		 ac.Type,
		CASE WHEN @ShwMainAcc = 1 THEN (CASE WHEN [acParent] = 0x0 THEN 1 ELSE 0 END) ELSE (CASE WHEN [NSons] = 0 THEN 1 ELSE 0 END) END AS [IsGeneralParent]
		FROM [#Result] AS [r]  
		LEFT JOIN [ac000] ac ON ac.GUID = [r].Account
		LEFT JOIN 
		(SELECT  c.GUID, (select count(*) from co000 c2 where c2.ParentGUID = c.GUID) as DirectChildren from    co000 c) AS CostChildren
		ON CostChildren.GUID = [r].CostPoint
		WHERE ([acLevel] < @AcLevel OR @AcLevel = 0) AND (@CostLevel =0  OR [coLevel] < @CostLevel ) 
		GROUP BY [r].[CostPoint], [r].[coParent], [r].[Account], [r].acParent, [coLevel], [acLevel],[coPath], [acPath],[r].[Code],[r].[Name],[Flag], [ac].NSons, [CostChildren].DirectChildren, ac.Type
		ORDER BY [Flag] , Account DESC
	ELSE
		SELECT [r].[CostPoint], [r].[Account], [r].[acParent], [r].[coParent], 
		ISNULL(SUM([r].[Debit]), 0) AS [Debit], 
		ISNULL(SUM([r].[Credit]), 0) AS [Credit], 
		[coLevel], 
		[acLevel], 
		[r].[Code], 
		[r].[Name],
		ISNULL([r].[Code], '') + '-' + ISNULL([r].[Name], '') AS [CodeName],
		[Flag],
		CASE @HrAxe WHEN 1 THEN [acPath] ELSE  [coPath] END AS Path,
		ISNULL([ac].NSons, -1) AS NSons,
		ISNULL([CostChildren].DirectChildren, -1) AS DirectChildren,
		 ac.Type,
		CASE WHEN @ShwMainAcc = 1 THEN (CASE WHEN [coParent] = 0x0 THEN 1 ELSE 0 END) ELSE (CASE WHEN [NSons] = 0 THEN 1 ELSE 0 END) END | CASE WHEN [CostPoint] = 0x0 THEN 1 ELSE 0 END AS [IsGeneralParent]
		FROM [#Result] AS [r]  
		LEFT JOIN [ac000] ac ON ac.GUID = [r].Account
		LEFT JOIN 
		(SELECT  c.GUID, (select count(*) from co000 c2 where c2.ParentGUID = c.GUID) as DirectChildren from    co000 c) AS CostChildren
		ON CostChildren.GUID = [r].CostPoint
		WHERE ([acLevel] < @AcLevel OR @AcLevel = 0) AND (@CostLevel =0  OR [coLevel] < @CostLevel ) 
		GROUP BY [r].[CostPoint], [r].[coParent], [r].[Account], [r].acParent, [coLevel], [acLevel],[coPath], [acPath],[r].[Code],[r].[Name],[Flag], [ac].NSons, [CostChildren].DirectChildren, ac.Type
		ORDER BY [Flag] , CostPoint DESC
	SELECT * FROM [#SecViol]  
/* 
	PRCcONNECTIONS_ADD2 'ãÏíÑ' 
	 [RepCostTrial] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '', '1/1/2009 0:0:0.0', '9/2/2009 23:59:16.48', 'd04831d6-459c-4996-bbf6-7ac84f7a78a9', 1.000000, 0, 0, 0, 0, 0, 0, 'dc75c345-6773-45c5-83f7-cda2f3641f8a', 0, 0, 0, 0, 0
*/ 

###########################################################################
#END