#################################################
CREATE  VIEW vtabd
AS 
	SELECT * FROM abd000
#################################################
CREATE  VIEW vbabd
AS 
	SELECT * FROM vtabd
#################################################
CREATE  VIEW vcabd
AS 
	SELECT * FROM vbabd
#################################################
CREATE VIEW vcab
AS
	SELECT * FROM dbo.ab000 WHERE  GUID IN (SELECT DISTINCT [PARENTGUID] FROM [vcabd])
#################################################
CREATE PROCEDURE repAccCostBudget
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@AccGUID 			[UNIQUEIDENTIFIER], 
	@CostGUID 			[UNIQUEIDENTIFIER], 
	@CurGUID			[UNIQUEIDENTIFIER], 
	@CurVal				[FLOAT], 
	@VrtAxis 			[INT], 
	@HrzAxis 			[INT], 
	@CostLevel          [INT]	= 0, 
	@AccLevel           [INT]	= 0, 
	@MainAxis 			[INT]	= 2, 
	@Lang				[BIT] = 0, 
	@grpBranches		[BIT] = 0, 
	@UnPosted			[BIT] = 0, 
	@DontShwEmpty		[BIT] = 0,
	@AddaccNoBug		[BIT] = 0,
	@CostaccNoBug		[BIT] = 0,
	@StartPeriod 		[DATETIME] = '1/1/1980', 
	@EndPeriod  		[DATETIME] = '1/1/1980',
	@ShowMainAcc		[BIT] = 0,
	@ShowMainCost		[BIT] = 0
AS  
	SET NOCOUNT ON  
	DECLARE @Level [INT] ,@StDate DATETIME,@EnDate DATETIME 
	DECLARE @c CURSOR,@Guid UNIQUEIDENTIFIER,@HaveSons BIT  
	 
	IF (@StartPeriod > '1/1/1980') 
	BEGIN 
		SET @StDate = @StartPeriod 
		SET @EnDate = @EndPeriod 
	END 
	ELSE 
	BEGIN 
		SET @StDate = @StartDate 
		SET @EnDate = @EndDate 
	END 
	SET @HaveSons = 0  
	-- Creating temporary tables   
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])   
	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT])   
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])   
	CREATE TABLE [#CostTbl2]([CostGUID] [UNIQUEIDENTIFIER], [Security] INT, [coCode] NVARCHAR(250), [coName] NVARCHAR(250))   
	CREATE TABLE [#AccTbl2]([GUID] [UNIQUEIDENTIFIER], [Security] INT, [Level] INT, [acCode] NVARCHAR(250), [acName] NVARCHAR(250), [CurrencyGUID] UNIQUEIDENTIFIER, bhaveSonsn BIT)
	CREATE TABLE #abd (CostGuid [UNIQUEIDENTIFIER], PeriodGuid [UNIQUEIDENTIFIER], Debit FLOAT, Credit FLOAT, ParentGUID [UNIQUEIDENTIFIER], Branch [UNIQUEIDENTIFIER]) 
	CREATE TABLE #abd2 (CostGuid [UNIQUEIDENTIFIER], PeriodGuid [UNIQUEIDENTIFIER], Debit FLOAT, Credit FLOAT, ParentGUID [UNIQUEIDENTIFIER], Branch [UNIQUEIDENTIFIER]) 
	CREATE TABLE [#B] ([StartDate] DATETIME, [EndDate] DATETIME, [CostGuid] [UNIQUEIDENTIFIER], [AccGuid] [UNIQUEIDENTIFIER], [PeriodGuid] [UNIQUEIDENTIFIER], [Branch] [UNIQUEIDENTIFIER]) 
	CREATE TABLE [#B_RESULT]([enAccount] [UNIQUEIDENTIFIER], [enCostPoint] [UNIQUEIDENTIFIER], [FixedenDebit] FLOAT, [FixedenCredit] FLOAT,  
		[CeSecurity] INT, [PeriodGuid] [UNIQUEIDENTIFIER], [Branch] [UNIQUEIDENTIFIER])  
	CREATE TABLE [#CostParents] ([GUID] [UNIQUEIDENTIFIER], [Path] VARCHAR(8000), [Level] INT, [coCode] NVARCHAR(250), [coName] NVARCHAR(250))   
	CREATE TABLE [#AccParents] ([GUID] [UNIQUEIDENTIFIER], [Level] INT , [Path] VARCHAR(8000), [acCode] NVARCHAR(250), [acName] NVARCHAR(250)) 
	  
	-- Filling temporary tables   
	INSERT INTO [#AccTbl] SELECT * FROM [dbo].[fnGetAcDescList]( @AccGUID)   
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID   
	
	INSERT INTO [#CostTbl2] 
	SELECT [c].[CostGUID], [co].[Security],[co].[Code] AS [coCode],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [coName]   
	FROM 
		[#CostTbl] AS [c] 
		INNER JOIN [co000] AS [co] ON [co].[Guid] = [c].[CostGUID] 
	 
	INSERT INTO [#AccTbl2] 
	SELECT [a].[GUID], [ac].[Security], [a].[Level],[Code] AS [acCode],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [acName], ac.[CurrencyGUID], CASE WHEN NSons > 0 THEN 1 ELSE 0 END bhaveSonsn 	 
	FROM 
		[#AccTbl] AS [a] 
		INNER JOIN [ac000] AS [ac] ON [a].[GUID] = [ac].[Guid]   

	DECLARE @cnt INT ,@d DATETIME
	DECLARE @bdp TABLE(GUID UNIQUEIDENTIFIER, StartDate SMALLDATETIME, EndDate SMALLDATETIME) 
	
	INSERT INTO @bdp 
	SELECT 
		GUID, StartDate, EndDate  
	FROM [bdp000]   
	WHERE  
		(StartDate >= @StDate AND EndDate <= @EnDate ) and [GUID] not in (select ParentGuid from [bdp000])
	UNION ALL
	SELECT 0X00 ,@StDate, @EnDate 
	
	DECLARE @ab TABLE (
		acc			UNIQUEIDENTIFIER,
		bug			UNIQUEIDENTIFIER, 
		[acName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[acCode]	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[CurrencyGUID] UNIQUEIDENTIFIER,
		[Security]	TINYINT,
		[Sec]		TINYINT,
		bhaveSonsn	BIT) 

	INSERT INTO @ab SELECT a.AccGuid,a.GUID,[acName],[acCode],ac.[CurrencyGUID],AC.[Security],a.[Security],bhaveSonsn   FROM ab000 a INNER JOIN [#AccTbl2] ac ON ac.[GUID] = a.AccGuid 
	IF ISNULL(@CostGUID,0X00) = 0X00  
		INSERT INTO [#CostTbl2] VALUES(0X00, 0, '', '') 

	DECLARE @absons TABLE(ACC UNIQUEIDENTIFIER,[Level] INT,nsons int,ACC2 UNIQUEIDENTIFIER)
	DECLARE @cnt2 INT,@Level2 INT

	IF  EXISTS(SELECT * FROM @ab WHERE bhaveSonsn > 0)
	BEGIN 
		INSERT INTO @absons SELECT acc,0,1,acc FROM @ab WHERE bhaveSonsn > 0
		SET @cnt2 = 1
		SET @Level2 = 0
		WHILE @cnt2 > 0
		BEGIN
			INSERT @absons SELECT Guid,@Level2 + 1,ac.NSons,Acc2 FROM ac000 ac INNER JOIN @absons A ON acc = AC.ParentGUID WHERE a.[Level] = @Level2
			SET @cnt2 = @@ROWCOUNT 
			SET @Level2 = @Level2 + 1
		END
	END
	
	IF (@AddaccNoBug > 0) 
	BEGIN
	
		INSERT INTO @ab SELECT ac.[GUID],NEWID() ,[acName],[acCode],ac.[CurrencyGUID],AC.[Security] ,a.Security ,0 
		FROM ab000 a RIGHT JOIN [#AccTbl2] ac ON ac.[GUID] = a.AccGuid 
		WHERE a.GUID IS NULL AND bhaveSonsn = 0 AND ac.[GUID] NOT IN (SELECT DISTINCT Acc FROM @absons WHERE NSons = 1)

		INSERT INTO #abd 
		SELECT A.CostGuid, a.PeriodGuid,a.Debit,a.Credit,isnull(a.ParentGUID,ab.bug),CASE @grpBranches WHEN 0 THEN 0X00 ELSE a.Branch END Branch
		FROM 
			vcabd a 
		RIGHT JOIN @ab ab ON a.parentGuid = bug
		LEFT JOIN [#CostTbl2] co on co.CostGUID = a.CostGUID

	END

	ELSE 
	BEGIN
	INSERT INTO #abd 
		SELECT A.CostGuid, a.PeriodGuid,a.Debit,a.Credit,a.ParentGUID,CASE @grpBranches WHEN 0 THEN 0X00 ELSE a.Branch END Branch
		FROM 
			vcabd a 
		INNER JOIN @ab ab ON a.parentGuid = bug
		INNER JOIN [#CostTbl2] co on co.CostGUID = a.CostGUID
	END
	
	IF @CostaccNoBug = 0
		DELETE c FROM [#CostTbl2] c LEFT JOIN #abd b ON c.[CostGUID] = b.[CostGUID] WHERE b.[CostGUID] IS NULL

	IF (@CostGUID <> 0X00) 
	BEGIN 
		DELETE @ab WHERE BUG NOT IN (SELECT DISTINCT BUG FROM @ab AB inner join #abd abd ON abd.ParentGuid = AB.Bug INNER JOIN [#CostTbl] cc ON cc.[CostGuid] =  abd.CostGuid) 
	END	
	INSERT INTO #abd2 
	SELECT A.CostGuid,a.PeriodGuid,SUM(a.Debit) Debit,SUM(a.Credit) Credit,a.ParentGUID,a.Branch 
	FROM #abd A
	GROUP BY a.CostGuid, a.PeriodGuid, a.ParentGUID, a.Branch 

	DECLARE @BCost TABLE ( 
		[acc]			UNIQUEIDENTIFIER,  
		[Branch]		UNIQUEIDENTIFIER,  
		[CostGUID]		UNIQUEIDENTIFIER,  
		[coCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[coName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[Debit]			FLOAT,   
		[Credit]		FLOAT,  
		[PeriodGuid]	UNIQUEIDENTIFIER,  
		[coSecurity]	TINYINT, 
		[acName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[acCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[CurrencyGUID]	UNIQUEIDENTIFIER,
		[acSecurity]	TINYINT, 
		[Sec]			TINYINT, 
		bhaveSonsn		SMALLINT, 
		StartDate		SMALLDATETIME, 
		EndDate			SMALLDATETIME)
	INSERT INTO @BCost  
	SELECT   
		[acc],  
		[Branch],  
		[co].[CostGUID],  
		[co].[coCode] ,  
		[co].[coName],  
		[d].[Debit],   
		 [d].[Credit],  
		[d].[PeriodGuid],  
		[co].[Security], 
		[acName],   
		[acCode], 
		[CurrencyGUID],
		bb.Security ,bb.Sec,bhaveSonsn,StartDate,EndDate  
	FROM 
		#abd2 [d] 
		LEFT JOIN [#CostTbl2] AS [co] ON [co].[CostGUID] = [d].[CostGuid]  
		INNER JOIN @ab bb ON bb.bug = [d].[ParentGuid] 
		LEFT JOIN @bdp PP ON pp.Guid = [d].[PeriodGuid] 
	-- For process Main Acc Contains budget
	IF  EXISTS(SELECT * FROM @BCost WHERE bhaveSonsn > 0)
	BEGIN  
	   IF (@HaveSons = 0)  
			SET @HaveSons = 1 
		SET @c = CURSOR FAST_FORWARD FOR SELECT DISTINCT [Acc] FROM @BCost WHERE bhaveSonsn > 0  
		OPEN @c FETCH FROM @c INTO @GUID  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			INSERT INTO @BCost (
				[acc],
				[Branch],
				[CostGUID],
				[coCode],
				[coName],
				[Debit],
				[Credit],
				[PeriodGuid],
				[coSecurity],
				[acName],
				[acCode],
				[CurrencyGUID],
				[acSecurity],
				[Sec],
				bhaveSonsn,
				StartDate,
				EndDate) 
			SELECT  
				Ac.[GUID],
				[Branch],
				B.[CostGUID],
				[coCode],
				[coName],
				0,
				0,
				[PeriodGuid],
				[coSecurity],
				[ac].[Name],
				[ac].[Code],
				[ac].[CurrencyGUID],
				[ac].[Security],
				[Sec],
				-1,
				StartDate,
				EndDate 
			FROM 
				@BCost B,
				(
					select 
						v.* 
					FROM  
						@absons c INNER JOIN ac000 v ON v.Guid = c.acc  
					WHERE 
						v.NSons = 0 AND c.acc2 = @GUID
				) ac 
			WHERE 
				B.[acc]= @GUID 
			  
			FETCH FROM @c INTO @GUID 
		END CLOSE @c 
		DEALLOCATE @c
	END  
	 
	INSERT INTO [#B] 
	SELECT DISTINCT [StartDate] AS [StartDate], [EndDate][EndDate], [CostGuid], [Acc] [AccGuid],[PeriodGuid] ,CASE @grpBranches WHEN 0 THEN 0X00 ELSE [Branch] END AS [Branch]    
	FROM @BCost WHERE bhaveSonsn <= 0 
	
	CREATE TABLE [#Result]  
	(   
		[AccGuid]				[UNIQUEIDENTIFIER],   
		[acName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[acCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[CostGuid]				[UNIQUEIDENTIFIER],   
		[CostCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[CostName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[TotalDebit]			[FLOAT],   
		[TotalCredit]			[FLOAT],   
	 	[ceSecurity]			[INT],  
	 	[acSecurity]			[INT],  
	 	[coSecurity]			[INT],  
		[Flag]					[INT] DEFAULT 0,  
	 	[PeriodPtr]				[UNIQUEIDENTIFIER],  
	 	[Branch]				[UNIQUEIDENTIFIER]  
	)   
	CREATE TABLE #result2 
	(   
		[AccGuid]				[UNIQUEIDENTIFIER],   
		[acName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[acCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[CostGuid]				[UNIQUEIDENTIFIER],   
		[CostCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[CostName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[TotalDebit]			[FLOAT],   
		[TotalCredit]			[FLOAT],   
	 	[ceSecurity]			[INT],  
	 	[acSecurity]			[INT],  
	 	[coSecurity]			[INT],  
		[Flag]					[INT] DEFAULT 0,  
	 	[PeriodPtr]				[UNIQUEIDENTIFIER],  
	 	[Branch]				[UNIQUEIDENTIFIER]  
	)
	CREATE TABLE [#RB_RESULT]  
	(  
		[enAccount]		[UNIQUEIDENTIFIER],  
		[enCostPoint]	[UNIQUEIDENTIFIER],  
		[RealDebit]		[FLOAT],  
		[RealCredit]	[FLOAT],  
		[PeriodGuid]	[UNIQUEIDENTIFIER],  
		[Branch]				[UNIQUEIDENTIFIER]  
	)  
	
	IF (@CurVal = 0)  
		SET @CurVal = 1  

	INSERT INTO [#Result]  
	(  
		[AccGuid],  
		[acName],  
		[acCode],  
		[CostGuid],  
		[CostCode],  
		[CostName],  
		[TotalDebit],  
		[TotalCredit],  
	 	[ceSecurity],  
	 	[acSecurity],  
	 	[coSecurity],  
		[PeriodPtr],  
		[Branch]  
	)  
	SELECT   
		[Acc],  
		[acName],  
		[acCode],  
		[CostGuid],  
		[coCode] ,  
		[coName],  
		SUM( ([Debit]/ @CurVal) *  dbo.fnGetCurVal(CurrencyGUID,GETDATE()) ),   
		SUM( ([Credit]/ @CurVal) * dbo.fnGetCurVal(CurrencyGUID,GETDATE()) ),   
		sec,  
		[acSecurity],  
		[coSecurity],  
		[PeriodGuid],  
		CASE @grpBranches WHEN 0 THEN 0X00 ELSE [Branch] END  
	FROM   
		@BCost WHERE bhaveSonsn <= 0 
	GROUP BY  
		[Acc],  
		[acName],  
		[acCode],  
		[CostGuid],  
		[coCode] ,  
		[coName],  
		sec,  
		[acSecurity],  
		[coSecurity],  
		[PeriodGuid],  
		CASE @grpBranches WHEN 0 THEN 0X00 ELSE [Branch] END 
	
	EXEC [prcCheckSecurity]  
 
	INSERT INTO [#B_RESULT]
	SELECT  
		[enAccount],  
		[enCostPoint],  
		SUM([FixedenDebit]) AS [FixedenDebit] ,  
		SUM([FixedenCredit]) AS [FixedenCredit],  
		[CeSecurity],  
		ISNULL([PeriodGuid], 0X00) AS [PeriodGuid],  
		CASE @grpBranches WHEN 0 THEN 0X00 ELSE [cebranch] END  AS [Branch]  
	FROM  
		[fnCeEn_Fixed](@CurGUID) AS [a]  
		INNER JOIN [#AccTbl2] AS [ac2] ON [a].[enAccount] = [ac2].[GUID]  
		LEFT JOIN [#B] AS [b] ON [a].[enDate] BETWEEN [b].[StartDate] AND [b].[EndDate]  AND ISNULL([enCostPoint], 0X0) = ISNULL([CostGuid], 0X0) AND [enAccount] = [AccGuid] AND (@grpBranches  = 0 OR ISNULL([b].[Branch] ,0X00) =  [cebranch])  
	WHERE   
		([enDate] BETWEEN @StartDate AND @EndDate) 
		AND ((@CostGUID = 0x0) OR ([enCostPoint] IN (SELECT [CostGUID] FROM [#CostTbl])))  
		AND (@UnPosted > 0 OR [ceIsposted] > 0 )  
	GROUP BY  
		 [enAccount],  
		 [enCostPoint],  
		 [CeSecurity],  
		ISNULL([PeriodGuid], 0X0),  
		 CASE @grpBranches WHEN 0 THEN 0X00 ELSE [cebranch] END   
	  
	EXEC [prcCheckSecurity] @Result='#B_RESULT'  
	
	INSERT INTO [#RB_RESULT]		   
		SELECT  
		    [enAccount],  
			ISNULL([enCostPoint], 0X0),  
			SUM ([FixedenDebit]) ,  
			SUM ([FixedenCredit]) ,  
			[PeriodGuid],
			[Branch]  
		FROM  
			[#B_RESULT]   
		GROUP BY   
			[enAccount],  
			[enCostPoint],  
			[PeriodGuid],
			[Branch]  
	
	IF @ShowMainCost <> 0
	BEGIN 
		INSERT INTO [#CostParents] 
		SELECT  [f].[GUID],[f].[Path],[f].[Level],[co].[Code] AS [coCode],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [coName]   
		FROM 
			[fnGetCostsListWithLevel](@CostGUID, 1) AS [f]  
			INNER JOIN [co000] [co] ON [f].[GUID] = [co].[GUID] 

		IF EXISTS (SELECT * FROM [#RESULT] WHERE [CostGuid] <> 0X00)  
		BEGIN  
			SELECT @Level = MAX([Level]) FROM [#CostParents]  

			CREATE CLUSTERED INDEX 	[indCostParents] ON [#CostParents]([GUID])  
			DECLARE @MaxLevel INT  
			SET @MaxLevel = @Level  
			WHILE @Level > 0   
			BEGIN  
				INSERT INTO [#RB_RESULT]		   
				SELECT  
					[enAccount],  
					[cp].[Guid],  
					SUM ([RealDebit]) ,  
					SUM ([RealCredit]) ,  
					[PeriodGuid],[Branch]  
				FROM  
					[#RB_RESULT]   
					INNER JOIN [co000] AS [co] ON [co].[Guid] = [enCostPoint]  
					INNER JOIN [#CostParents] AS [cp] ON [co].[ParentGUID] = [cp].[Guid]  
				WHERE 
					[cp].[Level] = (@Level -1) AND [enCostPoint] <> 0X00  
				GROUP BY   
					[cp].[Guid],  
					[enAccount],  
					[PeriodGuid],[Branch]  

				IF (@HaveSons > 0) 	  
					INSERT @BCost([acc],[Branch],[CostGUID],[coCode],[coName],[Debit],[Credit], 
					[PeriodGuid],[coSecurity],[acName],[acCode],[acSecurity],[Sec],bhaveSonsn,StartDate,EndDate) 
					SELECT  
						c.[acc],[Branch],[co].[ParentGUID],c.[coCode],c.[coName],c.[Debit],c.[Credit], 
						c.[PeriodGuid],c.[coSecurity],c.[acName],c.[acCode],c.[acSecurity],c.[Sec],c.bhaveSonsn,c.StartDate,c.EndDate 
					FROM 
						@BCost C  
						INNER JOIN [co000] AS [co] ON [co].[Guid] =[CostGUID] 
						INNER JOIN [#CostParents] AS [cp] ON [co].[ParentGUID] = [cp].[Guid]  
					WHERE 
						[cp].[Level] = (@Level -1) AND bhaveSonsn > 0 
	 
				INSERT INTO [#Result]  
				(  
					[AccGuid],  
					[acName],  
					[acCode],  
					[CostGuid],  
					[CostCode],  
					[CostName],  
					[TotalDebit],  
					[TotalCredit],  
	 				[ceSecurity],  
	 				[acSecurity],  
	 				[coSecurity],  
					[PeriodPtr],  
					[Branch]  
				)  
				SELECT   
					r.[AccGuid],  
					r.[acName],  
					r.[acCode],  
					[co].[ParentGUID],  
					[co2].[Code],  
					[co2].[Name],  
					SUM(r.[TotalDebit]),  
					SUM(r.[TotalCredit]),  
	 				r.[ceSecurity],  
	 				r.[acSecurity],  
	 				r.[coSecurity],  
					r.[PeriodPtr],  
					r.[Branch]  
				FROM [#RESULT] r  
					INNER JOIN [co000] AS [co] ON [co].[Guid] = [CostGuid]  
					INNER JOIN [#CostParents] AS [cp] ON [co].[ParentGUID] = [cp].[Guid]  
					INNER JOIN [co000] AS [co2] ON [co2].[Guid] = [cp].[Guid]  
					WHERE [cp].[Level] = (@Level -1) AND [CostGuid] <> 0X00    
			GROUP BY  
				r.[AccGuid],  
				r.[acName],  
				r.[acCode],  
				[co].[ParentGUID],  
				[co2].[Code],  
				[co2].[Name],  
				r.[ceSecurity],  
 				r.[acSecurity],  
 				r.[coSecurity],  
				r.[PeriodPtr],  
				r.[Branch]  
			  
				SET @Level = @Level -1  
			END  
		END  

		INSERT INTO #result2 
		SELECT   
			[AccGuid],[acName],	[acCode],[CostGuid],  
					[CostCode],	[CostName],SUM([TotalDebit]) AS [TotalDebit],SUM([TotalCredit]) AS [TotalCredit],[ceSecurity],  
	 				[acSecurity],[coSecurity],[Flag]	,[PeriodPtr],  
					[Branch]  
		FROM #result  
		GROUP BY   
			[AccGuid],[acName],	[acCode],[CostGuid],  
					[CostCode],	[CostName],[ceSecurity],  
	 				[acSecurity],[coSecurity],[PeriodPtr],  
					[Branch],[Flag]	  
	
		TRUNCATE TABLE #result 
	
		INSERT INTO #result SELECT * FROM #result2  
		IF (@CostLevel <> 0)  
		BEGIN  
			SELECT @Level = MAX([Level]) FROM [#CostParents]  
			WHILE @Level > 0   
			BEGIN  
				IF (@Level = @CostLevel )  
				BEGIN  
					DELETE [r] FROM [#RESULT] AS [r] INNER JOIN [#CostParents] AS [a] ON [a].[Guid] = [CostGuid] WHERE [a].[Level] >= @Level  
					DELETE [r] FROM [#RB_RESULT] AS [r] INNER JOIN [#CostParents] AS [a] ON [a].[Guid] = [enCostPoint] WHERE [a].[Level] >= @Level   
				END  
					SET @Level = @Level -1	   
			END  
		END  
	END

	IF (@ShowMainAcc <> 0) -- AND ((@AccLevel <> 0) OR (@HaveSons > 0))
	BEGIN  
		INSERT INTO [#AccParents] SELECT  [f].[GUID],[f].[Level],[f].[Path],[Code] AS [acCode],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [acName]    
		FROM [fnGetAccountsList](@AccGUID,1) AS [f]  
		INNER JOIN [ac000] AS [ac] ON [ac].[GUID] = [f].[GUID]  
		  
		CREATE CLUSTERED INDEX [IndAccParents] ON [#AccParents]([GUID])  
		SELECT @Level = MAX([Level]) FROM [#AccParents]  
		WHILE @Level > 0   
		BEGIN  
		  
			INSERT INTO [#RB_RESULT]	   
			SELECT [ap].[Guid],  
				[enCostPoint],  
				SUM ([RealDebit]) ,  
				SUM ([RealCredit]) ,  
				[PeriodGuid],[Branch]  
			FROM  [#RB_RESULT]   
			INNER JOIN [ac000] AS [Ac] ON [ac].[Guid] = [enAccount]  
			INNER JOIN [#AccParents] AS [ap] ON [ap].[Guid] = [ParentGuid]  
			WHERE [ap].[Level] = (@Level -1)  
			GROUP BY   
				[ap].[Guid],  
				[enCostPoint],  
				[PeriodGuid],[Branch]  
			INSERT INTO  [#RESULT] ([AccGuid],[acName],[acCode],[CostGuid],[CostCode],[CostName],[TotalDebit],[TotalCredit],[ceSecurity],[Flag],[PeriodPtr],[Branch])  
				SELECT [ap].[Guid],[ap].[acName],[ap].[acCode],[r].[CostGuid], [CostCode],[CostName],SUM([TotalDebit]),SUM([TotalCredit]),0,0,[PeriodPtr],[Branch]  
						FROM [#RESULT] AS [r]  
						INNER JOIN [ac000] AS [Ac] ON [ac].[Guid] = [AccGuid]  
						INNER JOIN [#AccParents] AS [ap] ON [ap].[Guid] = [ParentGuid]  
						WHERE [ap].[Level] = (@Level -1)  
						GROUP BY [ap].[Guid],[ap].[acName],[ap].[acCode],[r].[CostGuid], [CostCode],[CostName], [PeriodPtr],[Branch]  
			IF (@HaveSons > 0) 
			BEGIN
				UPDATE r
				SET 
					[TotalDebit] = b.Debit,
					[TotalCredit] = b.Credit 
				FROM 
					[#RESULT] r
					INNER JOIN @BCost b ON  CAST(b.acc AS NVARCHAR(36)) + CAST(b.CostGUID AS NVARCHAR(36)) + CAST(b.PeriodGuid AS NVARCHAR(36)) + CAST(b.Branch AS NVARCHAR(36)) =  CAST(r.AccGuid AS NVARCHAR(36)) + CAST(r.CostGuid AS NVARCHAR(36)) + CAST(r.PeriodPtr AS NVARCHAR(36)) + CAST(r.Branch AS NVARCHAR(36)) 
					INNER JOIN [#AccParents] AS [a] ON [a].[Guid] = [AccGuid]
				WHERE
					[a].[Level] = (@Level - 1)
					AND
					B.bhaveSonsn > 0
				
			END			 
			
			IF ( @AccLevel != 0 ) AND ( @Level = @AccLevel )  
			BEGIN
				DELETE [r] FROM [#RESULT] AS [r] INNER JOIN [#AccParents] AS [a] ON [a].[Guid] = [AccGuid] WHERE [a].[Level] >= @Level  
				DELETE [r] FROM [#RB_RESULT] AS [r] INNER JOIN [#AccParents] AS [a] ON [a].[Guid] = [enAccount] WHERE [a].[Level] >= @Level   
			END  
			SET @Level = @Level -1		   
		END 
	END 

	DECLARE @s [NVARCHAR](max)  
	SET @s = ' SELECT '  
	IF @VrtAxis = 0  
	BEGIN  
		SET @s = @s + '	[Flag],[CostGuid], [CostName], [CostCode], '  
	END  
	IF @VrtAxis = 1  
	BEGIN  
			SET @s = @s + '	[Flag], [AccGuid], [r].[acName], [r].[acCode],'  
	END  
	IF @VrtAxis = 2  
	BEGIN  
		SET @s = @s + ' [Flag], ISNULL([p].[Guid],0X0) AS [PGuid] ,'  
		IF @Lang = 0  
			SET @s = @s + 'ISNULL([p].[Name],' +''''+''''+') AS [PName],'  
		ELSE  
			SET @s = @s +  'CASE ISNULL( [p].[LatinName],' +''''+''''+') WHEN ' + '''' + '''' +' THEN ISNULL( [p].[Name],' +''''+''''+') ELSE ISNULL( [p].[LatinName],' +''''+''''+') END AS [PName],'  
		SET @s = @s + 'ISNULL([p].[Code],' +''''+''''+')  AS [PCode],  '  
	END  
	  
	IF @HrzAxis = 0  
	BEGIN  
		SET @s = @s + '	[CostGuid], [CostName], [CostCode], '  
	END  
	IF @HrzAxis = 1  
	BEGIN  
		SET @s = @s + '	 [AccGuid], [r].[acName], [r].[acCode],'  
	END  
	IF @HrzAxis = 2  
	BEGIN  
		SET @s = @s + ' ISNULL([p].[Guid],0X00) AS [PGuid] ,'  
		IF @Lang = 0  
			SET @s = @s + 'ISNULL([p].[Name],' +''''+''''+') AS [PName],'  
		ELSE  
			SET @s = @s +  'CASE ISNULL( [p].[LatinName],' +''''+''''+') WHEN ' + '''' + '''' +' THEN ISNULL( [p].[Name],' +''''+''''+') ELSE ISNULL( [p].[LatinName],' +''''+''''+') END AS [PName],'  
		SET @s = @s + 'ISNULL([p].[Code],' +''''+''''+')  AS [PCode],  '  
	END  
	SET @s = @s + '	SUM( ISNULL( [TotalDebit], 0)) AS [TotalDebit],  
			SUM(ISNULL( [TotalCredit], 0)) AS [TotalCredit]'  
		  
	SET @s = @s + '	,SUM(ISNULL([RealDebit], 0)) AS [RealDebit] ,SUM(ISNULL([RealCredit], 0)) AS [RealCredit] '   

	IF (@ShowMainAcc <> 0) /*AND (@AccLevel <> 0)*/ AND (@HrzAxis = 1)  
		SET @s = @s + ' ,ISNULL([facc].[Level], 0) AS [LEVEL]'  
	ELSE IF (@ShowMainCost <> 0) AND (@HrzAxis = 0)  
		SET @s = @s + ' ,ISNULL([fco].[Level], 0) AS [LEVEL]'  
	ELSE  
		SET @s = @s + ' ,0 AS [LEVEL]'  
	  
	IF (@ShowMainAcc <> 0) /*AND ((@AccLevel <> 0) OR (@HaveSons <> 0))*/ AND ((@VrtAxis = 1) OR (@MainAxis = 1))
		SET @s = @s + ' ,ISNULL([facc].[Level], 0) AS VALevel '
	ELSE 
		SET @s = @s + ' ,0 AS VALevel '

	IF (@ShowMainCost <> 0) AND ((@VrtAxis = 0) OR (@MainAxis = 0))
		SET @s = @s + ' ,ISNULL([fco].[Level], 0) AS VCLevel '  
	ELSE  
		SET @s = @s + ' ,0 AS VCLevel '

	IF (@ShowMainAcc <> 0) -- AND ((@AccLevel <> 0) OR (@HaveSons <> 0)) 
	BEGIN 
		SET @s = @s + ' ,[facc].[Path] '
		SET @s = @s + ' ,[AC].[acNsons] '
	END	 

	IF (@ShowMainCost <> 0) AND (@CostLevel <> 0)   
		SET @s = @s + ' ,[fco].[Path] '  
	
	IF @MainAxis = 0  
	BEGIN  
		SET @s = @s + '	,[CostGuid], [CostName], [CostCode] '  
	END  
	IF @MainAxis = 1  
	BEGIN  
		SET @s = @s + '	,[AccGuid], [r].[acName], [r].[acCode]'  
	END  
	IF @MainAxis = 2  
	BEGIN  
		SET @s = @s + ' ,ISNULL([p].[Guid],0X00) AS [PGuid] '  
		IF @Lang = 0  
			SET @s = @s + ',ISNULL([p].[Name],' +''''+''''+') AS [PName],'  
		ELSE  
			SET @s = @s +  ',CASE ISNULL( [p].[LatinName],' +''''+''''+') WHEN ' + '''' + '''' +' THEN ISNULL( [p].[Name],' +''''+''''+') ELSE ISNULL( [p].[LatinName],' +''''+''''+') END AS [PName],'  
		SET @s = @s + 'ISNULL([p].[Code],' +''''+''''+')  AS [PCode]  '  
	END  
	IF (@grpBranches > 0)  
		SET @s = @s + ',ISNULL(CASE ' + CAST (@Lang AS NVARCHAR(2)) + ' WHEN 0 THEN [br2].[Name] ELSE CASE [br2].[LatinName] WHEN '''' THEN [br2].[Name] ELSE [br2].[LatinName] END END ,' + '''' + '''' + ') AS [brName]'  
	  
	SET @s = @s + ' FROM [#Result] AS [r] '  
	IF (@DontShwEmpty > 0)  
		SET @s = @s + ' INNER '  
	ELSE  
		SET @s = @s + ' LEFT '  
	SET @s = @s + ' JOIN [#RB_RESULT] AS [br] ON [br].[enAccount] = [r].[AccGuid] AND [br].[enCostPoint] = [r].[CostGuid] AND [r].[PeriodPtr] = [br].[PeriodGuid] AND [r].[Branch] = [br].[Branch] '   
	IF (@grpBranches > 0)  
		SET @s = @s + ' LEFT JOIN [br000] AS [br2] ON [BR2].[Guid] = [r].[Branch] '   

	IF (@ShowMainAcc <> 0) -- AND ((@AccLevel <> 0) OR (@HaveSons <> 0))
		SET @s = @s + ' INNER JOIN [#AccParents] AS [facc] ON [facc].[Guid] = [AccGuid] JOIN vwAc AC ON AC.acGuid = [facc].[Guid] '
	IF (@ShowMainCost <> 0) -- AND ((@CostLevel <> 0) OR (@HrzAxis = 0) OR (@VrtAxis = 0))
		SET @s = @s + '  LEFT JOIN [#CostParents] AS [fco] ON [fco].[Guid] = [CostGuid]'  
		  
	SET @s = @s + '  LEFT JOIN [bdp000] AS [p] ON [p].[Guid] = [r].[PeriodPtr]  '  
	SET @s = @s + ' GROUP BY [Flag],'  
	IF @MainAxis = 0  
		SET @s = @s + ' [CostGuid],[CostName], [CostCode], '  
	IF @MainAxis = 1  
		SET @s = @s + '	 [AccGuid],[r].[acName], [r].[acCode],'  
	IF @MainAxis = 2  
		SET @s = @s + ' [p].[Guid] ,[p].[Name] ,[p].[LatinName],[p].[Code], '  

	IF @VrtAxis = 0  
		SET @s = @s + '	[CostGuid], [CostName], [CostCode], '  
	IF @VrtAxis = 1  
		SET @s = @s + '	[AccGuid], [r].[acName], [r].[acCode],'  
	IF @VrtAxis = 2  
		SET @s = @s + ' [p].[Guid] ,[p].[Name] ,[p].[LatinName],[p].[Code], '  

	IF @HrzAxis = 0  
		SET @s = @s + '	[CostGuid], [CostName], [CostCode] '  
	IF @HrzAxis = 1  
		SET @s = @s + '	[AccGuid], [r].[acName], [r].[acCode] '  
	IF @HrzAxis = 2  
		SET @s = @s + ' [p].[Guid] ,[p].[Name] ,[p].[LatinName],[p].[Code] '  

	 IF (@ShowMainCost <> 0) AND ((@HrzAxis = 0) OR (@VrtAxis = 0) OR (@CostLevel <> 0) OR (@MainAxis = 0))  
		SET @s = @s + ' ,[fco].[Level]'  
	  
	IF (@ShowMainAcc <> 0) /*AND ((@AccLevel <> 0) OR (@HaveSons <> 0))*/ AND ((@VrtAxis = 1) OR (@MainAxis = 1) OR (@HrzAxis = 1))  
		SET @s = @s + ' ,[facc].[Level]'  

	IF (@ShowMainAcc <> 0) -- AND ((@AccLevel <> 0) OR (@HaveSons <> 0)) 
	BEGIN
		SET @s = @s + ' ,[facc].[Path] ' 
		SET @s = @s + ' ,[AC].[acNsons] ' 
	END

	IF (@ShowMainCost <> 0) AND (@CostLevel <> 0)   
		SET @s = @s + ' ,[fco].[Path] '  
	
	IF (@grpBranches > 0)  
		SET @s = @s + ',ISNULL(CASE ' + CAST (@Lang AS NVARCHAR(2)) + ' WHEN 0 THEN [br2].[Name] ELSE CASE [br2].[LatinName] WHEN '''' THEN [br2].[Name] ELSE [br2].[LatinName]  END END,'''') '  
	SET @s = @s + ' ORDER BY [FLAG]'  
	IF @VrtAxis = 0   
	BEGIN   
		IF (@ShowMainCost <> 0) AND (@CostLevel <> 0)   
			SET @s = @s + ',[fco].[Path]'  
		ELSE  
			SET @s = @s + ',[CostCode]'  
	END  
	ELSE IF @VrtAxis = 1  
	BEGIN   
		IF (@ShowMainAcc <> 0) -- AND (@AccLevel <> 0)   
			SET @s = @s + ',[facc].[Path]'  
		ELSE  
			SET @s = @s + ', [r].[AcCode]'  
	END   
	ELSE IF @VrtAxis = 2   
		SET @s = @s + ', ISNULL([p].[Code],'+ '''' + '''' +')'  
		  
	IF @MainAxis = 0   
	BEGIN   
		IF (@ShowMainCost <> 0) AND (@CostLevel <> 0)   
			SET @s = @s + ',[fco].[Path]'  
		ELSE  
			SET @s = @s + ',[CostCode]'  
	END  
	ELSE IF @MainAxis = 1  
	BEGIN   
		IF (@ShowMainAcc <> 0) -- AND (@AccLevel <> 0)   
			SET @s = @s + ',[facc].[Path]'  
		ELSE  
			SET @s = @s + ',[r].[AcCode]'  
	END   
	ELSE IF  @MainAxis = 2   
		SET @s = @s + ',ISNULL([p].[Code],'+ '''' + '''' +')'  
		  
	IF @HrzAxis = 0   
	BEGIN   
		IF (@ShowMainCost <> 0) AND (@CostLevel <> 0)   
			SET @s = @s + ',[fco].[Path]'  
		ELSE  
			SET @s = @s + ',[CostCode]'  
	END  
	ELSE IF @HrzAxis = 1  
	BEGIN   
		IF (@ShowMainAcc <> 0) -- AND (@AccLevel <> 0)   
			SET @s = @s + ',[facc].[Path]'  
		ELSE  
			SET @s = @s + ',[r].[AcCode]'  
	END   
	ELSE IF  @HrzAxis = 2  
		SET @s = @s + ',ISNULL([p].[Code],'+ '''' + '''' +')'  

	IF (@grpBranches > 0)  
		SET @s = @s + ',ISNULL(CASE ' + CAST (@Lang AS NVARCHAR(2)) + ' WHEN 0 THEN [br2].[Name] ELSE CASE [br2].[LatinName] WHEN '''' THEN [br2].[Name] ELSE [br2].[LatinName]  END END,'''') '  
	EXECUTE ( @s)  

	SELECT *FROM [#SecViol] 
#################################################
CREATE PROCEDURE GetBugetCard
	@CardGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE @haveAllBranche INT
	SELECT @haveAllBranche = (SELECT count(*) from  vwbr) - (SELECT count(*) from br000) 
	SELECT *,@haveAllBranche AS  haveAllBranche FROM ab000 where [guid] = @CardGuid
	SELECT * FROM vcabd WHERE [parentGuid] = @CardGuid

#################################################
CREATE  VIEW vwCostBudget
AS 
	SELECT DISTINCT ISNULL([co].[coNumber], 0) + 1 AS [Number],ISNULL([co].[coGuid], '05eaff12-9713-46de-a29a-ecba1b144260') AS [Guid],ISNULL([co].[coCode], '') AS [coCode],ISNULL([co].[coName], '') AS [coName],ISNULL([co].[coLatinName], '') AS [coLatinName],ISNULL([coSecurity],1) AS [Security] 
	FROM [dbo].[vcabd] AS [ab] LEFT JOIN [vwCo] AS [co] ON [co].[coGUID] = [ab].[CostGuid]
######################################################################
CREATE PROCEDURE repAccBudgetRelRep 
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@AccGUID 			[UNIQUEIDENTIFIER], 
	@CostGUID 			[UNIQUEIDENTIFIER], 
	@CurGUID			[UNIQUEIDENTIFIER], 
	--@Lang				[BIT] = 0, 
	@grpBranches		[BIT] = 0, 
	@UnPosted			[BIT] = 0, 
	@AddaccCostNoBug	[TINYINT] = 0, --  ���� �������� 0      1 ��� ������      2 ��� ��� ������  
	@StartPeriod 		[DATETIME] = '1/1/1980', 
	@EndPeriod  		[DATETIME] = '1/1/1980',
	@ShwMainAcc			[BIT] = 0,
	@Sorted			    [TINYINT] = 1   -- 0: without sort, 1:Sort By Code, 2:Sort By Name 
AS 
	SET NOCOUNT ON  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])	
	DECLARE @StDate DATETIME,@EnDate DATETIME 
	IF (@StartPeriod > '1/1/1980') 
		BEGIN 
			SET @StDate = @StartPeriod 
			SET @EnDate = @EndPeriod 
		END 
		ELSE 
		BEGIN 
			SET @StDate = @StartDate 
			SET @EnDate = @EndDate 
		END 
		
	DECLARE @acc TABLE(
					   [Guid] UNIQUEIDENTIFIER,
					   [AccName] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
					   [AccCode] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
					   [CurrencyGUID] UNIQUEIDENTIFIER,
					   Security TINYINT,
					   ParentGuid UNIQUEIDENTIFIER,
					   NSons INT,
					   PRIMARY KEY CLUSTERED
					   ([GUID] ASC)
					  )
	INSERT INTO @acc 
				SELECT DISTINCT ac.GUID,ac.Name, ac.Code, CurrencyGUID, ac.[Security], ac.ParentGUID, NSons 
						FROM dbo.fnGetAccountsList(@AccGUID,0) f 
						INNER JOIN ac000 ac
						ON ac.GUID = f.GUID
						WHERE ac.Type = 1
						
	DECLARE @Cost TABLE(
						 [Guid] UNIQUEIDENTIFIER,
						 [Name] NVARCHAR(255) COLLATE ARABIC_CI_AI,
						 [Code] NVARCHAR(255) COLLATE ARABIC_CI_AI,
						 Security TINYINT,
						 ParentGuid UNIQUEIDENTIFIER,
						 PRIMARY KEY CLUSTERED ([GUID] ASC)
					   )
	INSERT INTO @Cost 
						SELECT co. GUID,co.Name, co.Code, co.[Security], co.ParentGUID
							 FROM dbo.fnGetCostsList(@CostGUID) f INNER JOIN co000 co
							 ON co.GUID = f.GUID
	IF(@CostGUID = 0X00)
	BEGIN
		INSERT INTO @Cost VALUES(0X00,'','',0,0X00)
	END

	DECLARE   @Preiods TABLE
	(
		  [Guid] UNIQUEIDENTIFIER,
		  [Code] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		  [Name]  NVARCHAR(255)COLLATE ARABIC_CI_AI,
		  [StartDate]   DATETIME,
		  [EndDate]    DATETIME,
		  PRIMARY KEY CLUSTERED(Guid,StartDate ASC,EndDate ASC)
	)
	INSERT INTO @Preiods 
		   SELECT Guid, Code, Name, StartDate, EndDate
			   FROM bdp000 WHERE (StartDate >= @StDate AND EndDate <= @EnDate ) and GUID not in (SELECT ParentGuid  FROM bdp000)
			   UNION ALL  SELECT 0X00 , '', '', @StDate, @EnDate 
	 --select * from @Preiods 
	CREATE TABLE #Budget
	(
		  AccountGuid UNIQUEIDENTIFIER,
		  ParentAcc   UNIQUEIDENTIFIER,
		  NSons       INT,
		  CostGuid    UNIQUEIDENTIFIER,
		  ParentCost  UNIQUEIDENTIFIER,
		  [Debit]     FLOAT,
		  [Credit]    FLOAT,
		  [Preid]     UNIQUEIDENTIFIER,
		  [Branch]    UNIQUEIDENTIFIER,
		  LINK        NVARCHAR(300) 
	)

	INSERT INTO #Budget
	SELECT ac.Guid, ac.ParentGuid, ac.NSons , co.Guid, co.ParentGuid, 
	SUM( (abd.[Debit]) *  dbo.fnGetCurVal(CurrencyGUID,GETDATE()) ),   
	SUM( (abd.[Credit]) * dbo.fnGetCurVal(CurrencyGUID,GETDATE()) ), 
	ISNULL(abd.PeriodGuid ,0X00),
			   CASE @grpBranches WHEN 0 THEN abd.Branch ELSE 0X00 END , ''
		  FROM ab000  ab INNER JOIN @acc ac ON ac.Guid = ab.AccGuid 
			   INNER JOIN abd000 abd ON abd.ParentGUID = ab.GUID 
			   INNER JOIN @Cost co on co.Guid = abd.CostGuid
			   LEFT JOIN @Preiods P ON P.Guid = abd.PeriodGuid 
		GROUP BY 
			 ac.Guid, ac.ParentGuid, ac.NSons , co.Guid, co.ParentGuid, ISNULL(abd.PeriodGuid ,0X00),
			   CASE @grpBranches WHEN 0 THEN abd.Branch ELSE 0X00 END 
	DECLARE @cnt INT
	INSERT INTO #Budget
	 SELECT ac.[Guid], AccountGuid, CASE ac.NSons WHEN 0 THEN 0 ELSE -1 END , CostGuid, ParentCost, 0, 0, [Preid], [Branch], ''
		   FROM #Budget b INNER JOIN @acc ac ON ac.ParentGuid = AccountGuid
		   WHERE b.Nsons > 0
	SET @cnt = @@ROWCOUNT
	DECLARE @level INT
	SET @level = -1
	WHILE @cnt > 0
	BEGIN
		INSERT INTO #Budget
		SELECT ac.[Guid], AccountGuid, CASE ac.NSons WHEN 0 THEN 0 ELSE @level -1 END, CostGuid, ParentCost, 0, 0, [Preid], [Branch], ''
			  FROM #Budget b INNER JOIN @acc ac ON ac.ParentGuid = AccountGuid
			  WHERE b.Nsons = @level
		SET @cnt = @@ROWCOUNT
		SET @level = @level -1 
	END
	DELETE #Budget WHERE NSons < 0
	UPDATE  #Budget SET LINK = CAST(AccountGuid AS NVARCHAR(36)) + CAST(CostGuid  AS NVARCHAR(36)) + CAST([Preid]  AS NVARCHAR(36)) + CAST(Branch  AS NVARCHAR(36))
	CREATE TABLE [#Result]  
		(   
			[AccountGuid]				[UNIQUEIDENTIFIER], 
			--[ParentAcc]             [UNIQUEIDENTIFIER],  
			[CostGuid]				[UNIQUEIDENTIFIER],   
			--[CostCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
			[TotalDebit]			[FLOAT],   
			[TotalCredit]			[FLOAT],   
	 		[ceSecurity]			[INT],  
	 		[acSecurity]			[INT],  
	 		[coSecurity]			[INT],  
			[Flag]					[INT] DEFAULT 0,  
	 		[PeriodPtr]				[UNIQUEIDENTIFIER],  
	 		[Branch]				[UNIQUEIDENTIFIER],
	 		[Link]                  [NVARCHAR] (300)
		)  
		
	INSERT INTO [#Result] 
	SELECT       enaccount,
				 enCostPoint,
				 SUM( CASE WHEN ce.ceDate BETWEEN P.StartDate AND p.EndDate then ce.FixedEnDebit ELSE 0 END),
				 SUM( CASE WHEN ce.ceDate BETWEEN P.StartDate AND p.EndDate then ce.FixedEnCredit ELSE 0 END),
				 ce.ceSecurity , 
				 ac.Security,
				 co.Security,
				 0, 
				 ISNULL(P.Guid,0x00),
				 CASE @grpBranches WHEN 0 THEN CEBranch ELSE 0X00 END,
				 '' 
		   FROM fnCeEn_Fixed(@CurGUID) ce 
				INNER JOIN @acc ac ON ac.Guid = ce.enAccount 
				INNER JOIN @Cost co ON enCostPoint = co.Guid
				LEFT JOIN @Preiods P ON EndDate BETWEEN P.StartDate AND p.EndDate
		   WHERE (@UnPosted > 0 OR [ceIsposted] > 0 )  --  C????I U?? C?????E
		  GROUP BY enaccount,
			  co.Guid,
			  ac.Security,
			  ISNULL(P.Guid,0x00),
			  enCostPoint,
			  co.Security,
			  ceSecurity,
			  CASE @grpBranches WHEN 0 THEN CEBranch ELSE 0X00 END 
			  
	UPDATE  [#Result] SET LINK = CAST([AccountGuid] AS NVARCHAR(36)) + CAST([CostGuid]  AS NVARCHAR(36)) + CAST([PeriodPtr]  AS NVARCHAR(36)) + CAST([Branch]  AS NVARCHAR(36))
	--EXEC [prcCheckSecurity]
	  
	CREATE TABLE #BGr(
					  [AccGuid]		[UNIQUEIDENTIFIER],
					  [ParentAcc]   [UNIQUEIDENTIFIER],
					  [CostGuid]	[UNIQUEIDENTIFIER],
					  [TotalDebit]	[FLOAT],   
					  [TotalCredit]	[FLOAT],  
					  [RealDebit]   FLOAT,
					  [RealCredit]  FLOAT,
					  [PeriodPtr]	[UNIQUEIDENTIFIER],  
	 				  [Branch]		[UNIQUEIDENTIFIER],
					  [Flag]		[TINYINT] DEFAULT 0
	 				  )
	INSERT INTO #BGr 
	select 
					 ISNULL(B.AccountGuid,R.[AccountGuid])   [AccGuid],		                 
					 ISNULL(B.ParentAcc,0x00)	          [ParentAcc]   ,
					 ISNULL(B.CostGuid,R.CostGuid)		[CostGuid],	
					 ISNULL(SUM(R.[TotalDebit]),0)		 [TotalDebit],
					 ISNULL(SUM(R.[TotalCredit]),0)	[TotalCredit],	
					 ISNULL(SUM(B.[Debit]),0)		[RealDebit],   
					 ISNULL(SUM(B.[Credit]),0)		[RealCredit],  
					 ISNULL([PeriodPtr],0X00) AS 	[PeriodPtr],	
					 ISNULL(B.[Branch],R.[Branch])	[Branch],		
					 CASE WHEN B.AccountGuid IS NULL THEN 1 WHEN R.[AccountGuid] IS NULL THEN 2 ELSE 3 END		   [Flag]		
					 
					
	FROM #Budget B  FULL OUTER JOIN [#Result] R ON B.Link = R.Link --R.AccountGuid = B.AccountGuid
	GROUP BY         ISNULL(B.AccountGuid,R.[AccountGuid]),		
					 ISNULL(B.AccountGuid,R.[AccountGuid]),		                 
					 ISNULL(B.ParentAcc,0x00) ,
					 ISNULL(B.CostGuid,R.CostGuid),
					 ISNULL([PeriodPtr],0X00),	
					 ISNULL(B.[Branch],R.[Branch]),		
					 CASE WHEN B.AccountGuid IS NULL THEN 1 WHEN R.[AccountGuid] IS NULL THEN 2 ELSE 3 END	
				
			
	 DELETE FROM #BGr WHERE Flag=1 AND [AccGuid] IN (SELECT [AccGuid] FROM [ab000])
	--DELETE   #BGr WHERE Flag = 2 --  C???CECE C??C?UE 
	CREATE TABLE #BGr2(
					  [UniqueGUID]	[UNIQUEIDENTIFIER],
					  [AccGuid]		[UNIQUEIDENTIFIER],
					  [AccName]     [NVARCHAR](256) COLLATE ARABIC_CI_AI,    
					  [AccCode]     [NVARCHAR](256) COLLATE ARABIC_CI_AI,
					  [ParentAcc]   [UNIQUEIDENTIFIER],
					  [ParentAcc2]   [UNIQUEIDENTIFIER],
					  [CostGuid]	[UNIQUEIDENTIFIER],
					  [CostName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
					  [CostCode]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
					  [TotalDebit]	[FLOAT],   
					  [TotalCredit]	[FLOAT],  
					  [RealDebit]   FLOAT,
					  [RealCredit]  FLOAT,
					  [PeriodPtr]	[UNIQUEIDENTIFIER],
					  [PeriodName]  [NVARCHAR](256) COLLATE ARABIC_CI_AI,   
					  [PeriodCode]  [NVARCHAR](256) COLLATE ARABIC_CI_AI , 
	 				  [Branch]		[UNIQUEIDENTIFIER],
	 				  [BranchName]  [NVARCHAR](256) COLLATE ARABIC_CI_AI, --
					  [Flag]		[TINYINT] DEFAULT 0,
					  AccLevel		SMALLINT,
					  CostLevel		SMALLINT  
	 				  )
	INSERT INTO #BGr2 
	select            NEWID(),
					  bgr.[AccGuid],
					  acc.AccName,
					  acc.AccCode,
					  bgr.[ParentAcc], 
					  acc.ParentGuid,  
					  bgr.[CostGuid],	
					  cost.Name,	
					  cost.Code,	
					  SUM(bgr.[TotalDebit]),
					  SUM(bgr.[TotalCredit]),
					  SUM( bgr.[RealDebit]),   	   
					  SUM(bgr.[RealCredit]), 
					  bgr.[PeriodPtr],	
					  p.Name,  
					  p.Code,   
	 				  bgr.[Branch],
	 				  br.Name,--		
					  bgr.[Flag],0,0
	From #BGr bgr INNER JOIN  @acc acc ON bgr.AccGuid = acc.Guid INNER JOIN @Cost cost ON bgr.CostGuid = cost.Guid
	 INNER JOIN @Preiods p  ON bgr.PeriodPtr = p.Guid LEFT JOIN br000  br ON bgr.Branch = br.GUID ---
	GROUP BY bgr.[AccGuid],		
					  bgr.[AccGuid],		
					  acc.AccName,         
					  acc.AccCode,     
					  bgr.[ParentAcc], 
					  acc.ParentGuid,  
					  bgr.[CostGuid],	
					  cost.Name,	
					  cost.Code,
					  bgr.[PeriodPtr],	
					  p.Name,  
					  p.Code,   
	 				  bgr.[Branch],
	 				  br.Name,--		
					  bgr.[Flag]		
					 
	 IF @ShwMainAcc = 0   -- ?U?C? C???CECE C?????E
	 BEGIN 
	 INSERT INTO #BGr2
	 SELECT 
		NEWID(),
		b.[AccGuid],		
		b.[AccName],     
		b.[AccCode],     
		0x00 ,
		b.[ParentAcc] ,  
		a.[CostGuid],	
		a.[CostName],	
		a.[CostCode],	
		SUM(b.[TotalDebit]),	
		SUM(b.[TotalCredit]),	
		SUM(b.[RealDebit]) ,  
		SUM(b.[RealCredit]),  
		b.[PeriodPtr],	
		b.[PeriodName], 
		b.[PeriodCode],  
		b.Branch,
		b.BranchName,--		
		b.[Flag],		
		b.AccLevel,		
		b.CostLevel
		FROM #BGr2 B INNER JOIN 	 #BGr2 A ON b.[ParentAcc]  = a.[AccGuid]	WHERE a.[CostGuid] = B.[CostGuid] AND a.[PeriodPtr]	= b.[PeriodPtr] AND a.Branch = b.Branch
		GROUP BY b.[AccGuid],		
			b.[AccName],     
			b.[AccCode],     
			b.[ParentAcc] ,  
			a.[CostGuid],	
			a.[CostName],	
			a.[CostCode],
			b.[PeriodPtr],	
			b.[PeriodName], 
			b.[PeriodCode],  
			b.Branch,
			b.BranchName,--		
			b.[Flag],		
			b.AccLevel,		
			b.CostLevel
	 END
	 ELSE
	 BEGIN
		SET @cnt = 2
		SET @level = 0
		WHILE (@cnt > 0)
		BEGIN
		INSERT INTO #BGr2 
		SELECT 
		NEWID(),
		b.[AccGuid],		
		b.[AccName],     
		b.[AccCode],     
		0x00 ,
		b.[ParentAcc] ,  
		a.[CostGuid],	
		a.[CostName],	
		a.[CostCode],	
		SUM(b.[TotalDebit]),	
		SUM(b.[TotalCredit]),	
		SUM(b.[RealDebit]) ,  
		SUM(b.[RealCredit]),  
		b.[PeriodPtr],	
		b.[PeriodName], 
		b.[PeriodCode],  
		b.Branch,
		b.BranchName,--		
		b.[Flag],		
		b.AccLevel,		
		b.CostLevel
		FROM #BGr2 B INNER JOIN 	 #BGr2 A ON b.[ParentAcc2] = a.[AccGuid]	WHERE b.aCClEVEL = @level
		GROUP BY b.[AccGuid],		
			b.[AccName],     
			b.[AccCode],     
			b.[ParentAcc] ,  
			a.[CostGuid],	
			a.[CostName],	
			a.[CostCode],
			b.[PeriodPtr],	
			b.[PeriodName], 
			b.[PeriodCode],  
			b.Branch,
			b.BranchName,--		
			b.[Flag],		
			b.AccLevel,		
			b.CostLevel
		SET @cnt = @@ROWCOUNT 
		SET @level = @level - 1
		END
		-- add parent accounts info to the result [for tree view]
		------ Start
		CREATE TABLE #ParentGuid (
		[GUID] UNIQUEIDENTIFIER,
		[AccGuid] [UNIQUEIDENTIFIER],
		[AccName] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[AccCode] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[ParentAcc2] UNIQUEIDENTIFIER,
		[Flag] [TINYINT] DEFAULT 0,
		[TotalDebit] [FLOAT],
		[TotalCredit] [FLOAT],
		[RealDebit] [FLOAT],
		[RealCredit] [FLOAT],
		[Level] INt DEFAULT 0)
		-- get direct parents
		INSERT INTO #ParentGuid([GUID], [AccGuid], [AccName], [AccCode], [ParentAcc2], [Flag], [TotalDebit], [TotalCredit], [RealDebit], [RealCredit] )
		SELECT DISTINCT ParentAcc2, ParentAcc2, [ParentAcc].[Name], [ParentAcc].[Code], [ParentAcc].[ParentGUID], 1, 0, 0, 0, 0 FROM #BGr2
		INNER JOIN ac000 AS [ParentAcc] ON [ParentAcc2] = [ParentAcc].[GUID]
		WHERE ParentAcc2 NOT IN (SELECT AccGuid FROM #BGr2)
		-- get parents of parents
		DECLARE @lvl INT = 0;
		DECLARE @RowCount INT SET @RowCount = 10
		WHILE @RowCount > 0
		BEGIN
			INSERT INTO #ParentGuid ( [GUID], [AccGuid], [AccName], [AccCode], [ParentAcc2], [Flag], [TotalDebit], [TotalCredit], [RealDebit], [RealCredit], [Level])
			SELECT DISTINCT [GUID], [GUID], [Name], [Code], [ParentGUID], 1, 0, 0, 0, 0, @lvl+1 FROM ac000
			WHERE
			[GUID] IN (SELECT [#ParentGuid].[ParentAcc2] FROM #ParentGuid WHERE [#ParentGuid].[Level] = @lvl )
			AND [GUID] NOT IN (SELECT [#ParentGuid].[GUID] FROM #ParentGuid)
			
			SET @RowCount = @@ROWCOUNT
			SET @lvl = @lvl + 1
		END

		INSERT INTO #BGr2 ([UniqueGUID], [AccGuid], [AccName], [AccCode], [ParentAcc2], [Flag], [TotalDebit], [TotalCredit], [RealDebit], [RealCredit])
		SELECT [GUID], [AccGuid], [AccName], [AccCode], [ParentAcc2], [Flag], [TotalDebit], [TotalCredit], [RealDebit], [RealCredit] FROM #ParentGuid
		------ End

	 END
	
	IF @AddaccCostNoBug = 1
	BEGIN
		DELETE FROM #BGr2 
		WHERE #BGr2.ParentAcc =0x0 AND (SELECT COUNT(Temp.AccGuid) FROM #BGr2 AS Temp WHERE Temp.AccGuid = #BGr2.AccGuid) > 1;
	END

	;WITH T AS 
	(
	SELECT
		ParentAcc,
		CostGuid,
		SUM(TotalDebit) AS SumDebit,
		SUM(TotalCredit) AS SumCredit
	FROM
		#BGr2
	GROUP BY 
		ParentAcc,
		CostGuid
	)
	UPDATE B
	SET 
		TotalCredit = TotalCredit + T.SumCredit,
		TotalDebit = TotalDebit + T.SumDebit
	FROM #BGr2 AS B JOIN T ON B.AccGuid = T.ParentAcc AND B.CostGuid = T.CostGuid 
	
	IF @Sorted = 2  
		 IF @AddaccCostNoBug = 1   
		   SELECT * FROM  #BGr2    
			 WHERE Flag = 3 OR Flag = 2
			 ORDER BY 
					  [AccCode],     
					  [CostName],	
					  [CostCode],
					  [PeriodName],
					  [PeriodCode],
					  [BranchName]	
		 ELSE IF @AddaccCostNoBug = 2 
				 SELECT * FROM  #BGr2    
				 WHERE Flag = 1
				 ORDER BY     
					  [AccName],     
					  [AccCode],     
					  [CostName],	
					  [CostCode],
					  [PeriodName],
					  [PeriodCode],
					  [BranchName]
		ELSE
			 SELECT * FROM  #BGr2
			 ORDER BY [Flag] desc,
					  [AccName],     
					  [AccCode],     
					  [CostName],	
					  [CostCode],
					  [PeriodName],
					  [PeriodCode],
					  [BranchName]
	ELSE
		 IF @AddaccCostNoBug = 1   
		   SELECT * FROM  #BGr2    
			 WHERE Flag = 3 OR Flag = 2
			 ORDER BY [AccCode],
					  [AccName],     
					  [CostCode],   
					  [CostName],	
					  [PeriodCode],
					  [PeriodName],
					  [BranchName]	
		 ELSE IF @AddaccCostNoBug = 2 
				 SELECT * FROM  #BGr2    
				 WHERE Flag = 1
				 ORDER BY     
					  [AccCode],
					  [AccName],     
					  [CostCode],   
					  [CostName],	
					  [PeriodCode],
					  [PeriodName],
					  [BranchName]	
		ELSE
			 SELECT * FROM  #BGr2
			 ORDER BY [Flag] desc,
					  [AccCode],
					  [AccName],     
					  [CostCode],   
					  [CostName],	
					  [PeriodCode],
					  [PeriodName],
					  [BranchName]					  	
		  	
	SELECT *FROM [#SecViol]
/*
EXEC [repAccBudgetRelRep] '1/1/2006 0:0:0.0', '10/2/2010 23:59:24.276', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '08267a47-99fe-11d9-bee1-00e07dc0d524'
EXEC [repAccBudgetRelRep] '1/1/2006 0:0:0.0', '10/3/2010 23:59:23.667', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '08267a47-99fe-11d9-bee1-00e07dc0d524', 0, 2, 1, '1/1/1980', '1/1/1980 0:0:0.0',1
EXECUTE[repAccBudgetRelRep] '1/1/2006 0:0:0.0', '10/4/2010 23:59:17.394', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '08267a47-99fe-11d9-bee1-00e07dc0d524',0, 0, 0, '1/1/1980', '1/1/1980 0:0:0.0', 1
EXECUTE  [repAccBudgetRelRep] '1/1/2010 0:0:0.0', '10/6/2010 23:59:34.234', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'b34da689-d4a5-437e-871e-c37915c93d3b', 0, 0, 2, '1/1/1980', '1/1/1980 0:0:0.0', 0
EXECUTE  [repAccBudgetRelRep] '1/1/2010 0:0:0.0', '10/6/2010 23:59:18.543', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'b34da689-d4a5-437e-871e-c37915c93d3b', 0, 0, 2, '1/1/1980', '1/1/1980 0:0:0.0', 0, 2
*/
######################################################################
#END
