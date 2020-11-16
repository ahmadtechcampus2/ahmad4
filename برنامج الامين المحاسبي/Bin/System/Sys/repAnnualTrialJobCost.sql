##################################################################
CREATE PROCEDURE repAnnualTrialJobCost
	@CostGUID 		[UNIQUEIDENTIFIER],
	@AccGUID 		[UNIQUEIDENTIFIER],
	@StartDate		[DATETIME],
	@EndDate		[DATETIME],
	@PostedVal 		[INT] = -1 ,-- 1 posted or 0 unposted -1 all posted & unposted
	@CurGUID		[UNIQUEIDENTIFIER],
	@Type			[BIT] = 0, --1 Details 0 Summry
	@Sorted 		[INT] = 1,
	@Str			[NVARCHAR](max) = '',
	@CoLevel		[INT] = 0,
	@Lang			[BIT] = 0,
	@SrcGuid		UNIQUEIDENTIFIER = 0x00
AS
	SET NOCOUNT ON
	DECLARE @Level [INT],@str2 NVARCHAR(2000),@UserId UNIQUEIDENTIFIER,@HosGuid UNIQUEIDENTIFIER
	SET @HosGuid = NEWID()
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])    
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()     
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID    
	
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID    
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID 
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]
	IF [dbo].[fnObjectExists]( 'prcGetTransfersTypesList') <> 0	
		INSERT INTO [#EntryTbl]	EXEC [prcGetTransfersTypesList] 	@SrcGuid
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0
	BEGIN		
		SET @str2 = 'INSERT INTO [#EntryTbl]
		SELECT
					[IdType],
					[dbo].[fnGetUserSec](''' + CAST(@UserID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1)
				FROM
					[dbo].[RepSrcs] AS [r] 
					INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid]
				WHERE
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + ''''
		EXEC(@str2)
	END
	IF [dbo].[fnObjectExists]( 'vwTrnExchangeTypes') <> 0
	BEGIN		
		SET @str2 = 'INSERT INTO [#EntryTbl]
		SELECT
					[IdType],
					[dbo].[fnGetUserSec](''' + CAST(@UserID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1)
				FROM
					[dbo].[RepSrcs] AS [r] 
					INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid]
				WHERE
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + ''''
		EXEC(@str2)
	END 			
					
	IF EXISTS(SELECT * FROM [dbo].[RepSrcs] WHERE [IDSubType] = 303)
		INSERT INTO [#EntryTbl] VALUES(@HosGuid,0)
	INSERT INTO [#AccTbl] SELECT * FROM [dbo].[fnGetAcDescList]( @AccGUID)
	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList] 		@CostGUID 	
	    
	
	DECLARE @PDate TABLE  ([StartDate] [DATETIME] DEFAULT '1/1/1980',[EndDate] [DATETIME])
	INSERT INTO @PDate SELECT *  FROM [fnGetStrToPeriod]( @STR )
	INSERT INTO @PDate([EndDate]) VALUES(DATEADD(dd,-1,@StartDate))
	CREATE TABLE [#Result]
	(
		[enCostPoint]		[UNIQUEIDENTIFIER],
		[enAccount]		[UNIQUEIDENTIFIER],
		[FixedEnDebit]		[FLOAT],
		[FixedEnCredit]		[FLOAT],
		[StartDate]		[DATETIME],
		[EndDate]		[DATETIME],
		[acSecurity]		[INT],
		[ceSecurity]		[INT],
		[coSecurity]		[INT]
	)
	CREATE TABLE [#EndResult]
	(
		[ID]		[INT]	DEFAULT 0,
		[Name]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[Code]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Guid]		[UNIQUEIDENTIFIER],
		[CostGuid]		[UNIQUEIDENTIFIER],
		[FixedEnDebit]		[FLOAT],
		[FixedEnCredit]		[FLOAT],
		[StartDate]		[DATETIME],
		[EndDate]		[DATETIME],
		[Type]			[INT],
		[Level]			[INT] DEFAULT 0
	)
	CREATE TABLE [#Cost]
	(
		[ID]		[INT]	IDENTITY(1,1),
		[Name]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[Code]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Guid]		[UNIQUEIDENTIFIER],
		[ParentGuid]	[UNIQUEIDENTIFIER],
		[Level]		[INT] DEFAULT 0
	)
	INSERT INTO [#Result]
		SELECT 
			[enCostPoint],
			CASE @Type WHEN 1 THEN [enAccount] ELSE 0X00 END,
			SUM([FixedEnDebit]),
			SUM([FixedEnCredit]),
			[StartDate],
			[EndDate],
			[acc].[Security],
			[ceSecurity],
			[co].[Security]
		FROM [fnceen_fixed](@CurGUID) AS [f] 
		INNER JOIN [#AccTbl] AS [ac] ON [ac].[Guid] =  [enAccount]
		INNER JOIN ac000 acc on ac.guid =  acc.guid
		INNER JOIN [#CostTbl] AS [co] ON  [co].[CostGUID] = [enCostPoint]
		INNER JOIN [#EntryTbl] AS [t]  ON [f].[ceTypeGuid] = [t].[Type]   
		INNER JOIN @PDate AS p ON [enDate] BETWEEN [StartDate] AND [EndDate]
		WHERE
			((@PostedVal = -1) OR ( [ceIsPosted] = @PostedVal))
			AND [enDate] <= @EndDate
		GROUP BY
			[enCostPoint],
			CASE @Type WHEN 1 THEN [enAccount] ELSE 0X00 END,
			[StartDate],
			[EndDate],
			[acc].[Security],
			[ceSecurity],
			[co].[Security]

	EXEC [prcCheckSecurity]
	
	IF (@Type = 1)
		INSERT INTO [#EndResult]([Name],[Code], [Guid],[CostGuid],[FixedEnDebit],[FixedEnCredit],[StartDate],[EndDate],[Type])
			SELECT CASE @Lang WHEN 1 THEN [ac].[Name] ELSE CASE [ac].[LatinName] WHEN '' THEN [ac].[Name] ELSE [ac].[LatinName] END END ,[ac].[Code],
			[enAccount],[enCostPoint],SUM([FixedEnDebit]),SUM([FixedEnCredit]),[StartDate],[EndDate],1
			FROM [#Result] AS [r] INNER JOIN [ac000] AS [ac] ON [r].[enAccount] = [ac].[Guid]
			GROUP BY
				 CASE @Lang WHEN 1 THEN [ac].[Name] ELSE CASE  [ac].[LatinName] WHEN '' THEN [ac].[Name] ELSE [ac].[LatinName] END END,[ac].[Code],[enAccount],[enCostPoint],[StartDate],[EndDate]
			
	 
	IF (@Type = 1)
		INSERT INTO [#EndResult]([Name],[Code], [Guid],[CostGuid],[FixedEnDebit],[FixedEnCredit],[StartDate],[EndDate],[Type])
			SELECT  CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE  [co].[LatinName] WHEN '' THEN [co].[Name] ELSE [co].[LatinName] END END,[co].[Code],
			[CostGuid],[co].[ParentGuid],SUM([FixedEnDebit]),SUM([FixedEnCredit]),[StartDate],[EndDate],0
			FROM [#EndResult] AS [r] INNER JOIN [co000] AS [co] ON [r].[CostGuid] = [co].[Guid]
			GROUP BY
				CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE[co].[LatinName]  WHEN '' THEN [co].[Name] ELSE [co].[LatinName] END END,[co].[Code],[CostGuid],[co].[ParentGuid],[StartDate],[EndDate]	
	ELSE 
		INSERT INTO [#EndResult]([Name],[Code], [Guid],[CostGuid],[FixedEnDebit],[FixedEnCredit],[StartDate],[EndDate],[Type])
			SELECT [co].[Name],[co].[Code],
			[enCostPoint],[co].[ParentGuid],SUM([FixedEnDebit]),SUM([FixedEnCredit]),[StartDate],[EndDate],0
			FROM [#Result] AS [r] INNER JOIN [co000] AS [co] ON [r].[enCostPoint] = [co].[Guid]
			GROUP BY
				[co].[Name],[co].[Code],[enCostPoint],[co].[ParentGuid],[StartDate],[EndDate]	
		
		
	INSERT INTO [#Cost]([Name],[Code],[Guid],[ParentGuid],[Level])
		SELECT CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE [co].[LatinName]  WHEN ''  THEN [co].[Name] ELSE [co].[LatinName] END END,[co].[Code],[f].[Guid],[co].[ParentGuid],[Level]
		FROM [fnGetCostsListWithLevel](@CostGUID,@Sorted) AS [f] INNER JOIN [co000] AS [co] ON [co].[Guid] = [f].[Guid]
		ORDER BY [path]
	SELECT @Level = MAX([Level]) FROM [#Cost]
	IF (@Type = 0)
		UPDATE [r] SET [Id] = [co].[Id],[Level] = [co].[Level]  FROM [#EndResult] AS [r] INNER JOIN [#Cost] AS [co] ON [r].[Guid] = [co].[Guid] WHERE [r].[Type] = 0
	ELSE
		UPDATE [r] SET [Id] = [co].[Id]  FROM [#EndResult] AS [r] INNER JOIN [#Cost] AS [co] ON [r].[CostGuid] = [co].[Guid] 
	IF (@Type = 0)
	BEGIN
		WHILE (@Level > 0)
		BEGIN
			INSERT INTO [#EndResult]([Id],[Name],[Code], [Guid],[CostGuid],[FixedEnDebit],[FixedEnCredit],[StartDate],[EndDate],[Type],[Level])
				SELECT [co].[Id],[co].[Name],[co].[Code],
				[CostGuid],[co].[ParentGuid],SUM([FixedEnDebit]),SUM([FixedEnCredit]),[StartDate],[EndDate],0,[co].[Level]
				FROM [#EndResult] AS [r] INNER JOIN [#Cost] AS [co] ON [r].[CostGuid] = [co].[Guid]
				WHERE [r].[Level] = @Level AND [r].[Type] = 0
				GROUP BY
					[co].[Id],[co].[Name],[co].[Code],[CostGuid],[co].[ParentGuid],[StartDate],[EndDate],[co].[Level]
			IF (@Level  = @CoLevel)
				DELETE [#EndResult] WHERE [Level] >= @CoLevel
			SET @Level = @Level - 1
			
		END
	END
	SELECT DISTINCT [StartDate],[EndDate] FROM [#EndResult] ORDER BY [StartDate]
	SELECT
		[Name],  
		[Code], 
		[CostGuid] ,
		[Guid],
		[CostGuid] AS [ParentCost],
		SUM([FixedEnDebit]) AS [Debit],
		SUM([FixedEnCredit]) AS [Credit],
		[StartDate],
		[Type],
		[Level]	
	FROM [#EndResult]
	GROUP BY 
		[ID],
		[Name],  
		[Code], 
		[Guid],
		[CostGuid] ,
		[StartDate],
		[EndDate],
		[Type],
		[Level]
	ORDER BY	
		[ID],[Type],CASE @Sorted WHEN 1 THEN [Code] ELSE [Name] END ,[Guid],[StartDate]
	SELECT * FROM [#SecViol]
/*
	prcConnections_add2 '„œÌ—'
	exec repAnnualTrialJobCost 0x00,0x00, '5/1/2003', '4/30/2004',-1,'F042E739-956D-4BD4-BBAC-270E4159B60E',1,1,'5-1-2003,5-31-2003,6-1-2003,6-30-2003,7-1-2003,7-31-2003,8-1-2003,8-31-2003,9-1-2003,9-30-2003,10-1-2003,10-31-2003,11-1-2003,11-30-2003,12-1-2003,12-31-2003,1-1-2004,1-31-2004,2-1-2004,2-29-2004,3-1-2004,3-31-2004,4-1-2004,4-30-2004'
*/
###########################################################
#END


		