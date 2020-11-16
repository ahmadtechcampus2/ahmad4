###########################################################################
CREATE PROCEDURE RepCostGL
	@AccPtr AS [UNIQUEIDENTIFIER],
	@CostPtr AS [UNIQUEIDENTIFIER],
	@Class AS [NVARCHAR](256),
	@StartDate AS [DATETIME],
	@EndDate AS [DATETIME],
	@CurGUID AS [UNIQUEIDENTIFIER],
	@CurVal AS [FLOAT],
	@Lang AS [INT] = 0, 
	@EntryUserGuid AS [UNIQUEIDENTIFIER] = 0X00,
	@PrevBal AS	BIT = 0,
	@Posted	AS	INT = -1, 
	@SumCosts AS	INT = 0, --0 for showing the sum of cost center, 1 otherwise
	@FromPostDate AS [DATETIME]= '1980-1-1',
	@ToPostDate AS [DATETIME]  = '2100-1-1',
	@SrcGuid AS [UNIQUEIDENTIFIER] = 0X00,
	@DocumentStr  AS [NVARCHAR](256) = ''
AS 
	SET NOCOUNT ON 
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserEnSec [INT] 
	DECLARE @StDate [DATE], @FromPDate [DATE], @EdDate [DATE], @ToPDate [DATE];

	IF @PrevBal = 0 
	BEGIN 
		SET @StDate = @StartDate 
		SET @FromPDate = @FromPostDate
		SET @EdDate = @EndDate
		SET @ToPDate = @ToPostDate
	END 
	ELSE 
	BEGIN 
		SET @StDate = '1/1/1980'
		SET @FromPDate = '1/1/1980'
		SET @EdDate = DATEADD(second,-1,@StartDate)
		SET @ToPDate = DATEADD(second,-1,@FromPostDate)
	
	END 
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SET @UserEnSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#AccTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT]) 
	CREATE TABLE [#ContraAccTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT]) 
	CREATE TABLE [#CostTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#SumCosts] ([CostGuid] [UNIQUEIDENTIFIER], [SumDebit] [FLOAT], [SumCredit] [FLOAT], [SumBalance] [FLOAT])
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])        
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT) 
	INSERT INTO @Curr  
	SELECT DATE,CurrencyVal FROM mh000 WHERE CURRENCYGuid = @CurGUID  
	UNION ALL  
	SELECT  '1/1/1980',CurrencyVal FROM MY000 WHERE Guid = @CurGUID 
	CREATE TABLE [#Result] 
	(    
		[Id] 			[INT] IDENTITY(1,1), 
		[CostPoint]		[UNIQUEIDENTIFIER], 
		[CostCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[CostName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[CostSecurity]	[INT], 
		[Account]		[UNIQUEIDENTIFIER], 
		[AccCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[AccName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[AccSecurity]	[INT], 
		[ceGuid] 		[UNIQUEIDENTIFIER], 
		[ceStr]			[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[ceNumber] 		[INT], 
		[Date]			[DATETIME],
		[PostDate]		[DATETIME],
		[IsPosted]		[BIT],
		[Debit]			[FLOAT], 
		[Credit]		[FLOAT], 
		[Balance]		[FLOAT], 
		[Notes]			[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[Security]		[INT], 
		[UserSecurity]	[INT], 
		[Prv]			[BIT] DEFAULT 1,		--0 in case there will be previous balance values
		[SumDebit]		[FLOAT] DEFAULT 0,
		[SumCredit]		[FLOAT] DEFAULT 0,
		[SumBalance]	[FLOAT] DEFAULT 0,	
		[EntryNumber]	[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[Class] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[ContraAccGUID]  [UNIQUEIDENTIFIER], 
		[ContraAccCode]	 [NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[ContraAccName]  [NVARCHAR](255) COLLATE ARABIC_CI_AI 
		
	) 
	CREATE TABLE [#FinalResult] 
	(   
		[Id] 			[INT] IDENTITY(1,1), 
		[Guid]			[UNIQUEIDENTIFIER], 
		[Code]			[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[Name]			[NVARCHAR](255) COLLATE ARABIC_CI_AI, [groupGuid]			[UNIQUEIDENTIFIER], 
		[groupCode]			[NVARCHAR](255) COLLATE ARABIC_CI_AI, [groupName]			[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[Debit]			[FLOAT], 
		[Credit]		[FLOAT], 
	) 
	
	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccPtr 
	INSERT INTO [#ContraAccTbl] EXEC [prcGetAccountsList] 0x0 --@ContraAcc 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostPtr 
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID  
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID  
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]    
	DECLARE @str NVARCHAR(1000) , @HosGuid UNIQUEIDENTIFIER 
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
	SELECT [Code] AS [coCode],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [coName],[c].[Number] , [c].[Security] AS [CoSecurity]  
	INTO [#CostTbl2]  
	FROM [#CostTbl] AS [c] INNER JOIN [co000] AS [co] ON [c].[Number] = [co].[Guid] 
	IF @CostPtr = 0x00 
		INSERT INTO [#CostTbl2] VALUES ('','',0X00,0) 
	INSERT INTO [#Result] 
	(  
		[CostPoint],  
		[CostCode],  
		[CostName], 	 
		[CostSecurity],  
		[Account],  
		[AccCode],  
		[AccName],  
		[AccSecurity],  
		[ceGuid], 
		[ceStr],
		[ceNumber],  
		[Date],
		[PostDate],
		[IsPosted],
		[Debit],  
		[Credit], 
		[Balance], 
		[Notes], 
		[Class],
		[ContraAccGUID], 
		[ContraAccCode], 
		[ContraAccName], 
		[Security],  
		[UserSecurity]
	) 
	SELECT     
		[Ce].[enCostPoint],     
		[co].[coCode],   
		[co].[coName],  
		[co].[coSecurity],   
		[Ce].[enAccount],     
		[Ce].[acCode],   
		CASE @Lang WHEN 0 THEN [Ce].[acName] ELSE CASE [Ce].[acLatinName] WHEN '' THEN [Ce].[acName] ELSE [Ce].[acLatinName] END END,   
		[Ac].[Security],   
		[Ce].[ceGuid], 
		N'' ceStr,    
		[ce].[ceNumber], 
		[Ce].[enDate],
		[Ce].[cePostDate],
		[Ce].[ceIsPosted],
		[Ce].[FixedEnDebit],      
		[Ce].[FixedEnCredit],
		(([Ce].[enDebit]-[Ce].[enCredit]) * 
		(SELECT 1 / CASE WHEN ceCurrencyPtr = @CurGUID THEN ceCurrencyVal
				 ELSE
		(SELECT TOP 1 VAL FROM @Curr WHERE DATE <=  [Ce].endate  ORDER BY DATE DESC) END FACTOR 
		 )) Balance,
		[Ce].[enNotes],
		[Ce].[enClass],
		[Ce].[enContraAcc], 
		[ContraAcc].[acCode] as [ContraAccCode],
		CASE @Lang WHEN 0 THEN [ContraAcc].[acName] ELSE CASE [ContraAcc].[acLatinName] WHEN '' THEN [ContraAcc].[acName] ELSE [Ce].[acLatinName] END END as [ContraAccName],   
		[Ce].[ceSecurity],   
		@UserEnSec
		
	FROM     
		[dbo].[fnExtended_En_Fixed]( @CurGUID) As [Ce]    
		INNER JOIN [#AccTbl] AS [Ac] ON [ce].[enAccount] = [Ac].[Number]   
		INNER JOIN [#CostTbl2] AS [Co] On [ce].[enCostPoint] = [Co].[Number]  
		LEFT JOIN vwac ContraAcc ON ContraAcc.acGUID = [ce].enContraAcc
		INNER JOIN [#EntryTbl] enrtyTb ON enrtyTb.Type = [Ce].ceTypeGUID
	WHERE    
		( @Class = '' OR @Class = [enClass])
		 AND   
		--(([enDate] BETWEEN @StDate AND @EdDate AND (ceIsPosted = 1 AND ([cePostDate] BETWEEN @FromPDate AND @ToPDate ) OR 
		--		ceIsPosted = 0))
		--OR ([enDate] BETWEEN @StartDate AND @EndDate AND (ceIsPosted = 1 AND ([cePostDate] BETWEEN @FromPostDate AND @ToPostDate) OR 
		--		ceIsPosted = 0)))
		[enDate] BETWEEN @StDate AND @EndDate 
		AND (
				(ceIsPosted = 1 AND [cePostDate] BETWEEN @FromPostDate AND @ToPostDate) 
			OR 
				ceIsPosted = 0
			) 
		AND (
				@EntryUserGuid = 0X00 
				OR  
				[Ce].[ceGuid] IN 
				(
					 SELECT 
					   [EntryGuid]
					 FROM [ER000] AS [er] 
					   INNER JOIN [LG000] AS [Lg] ON [Lg].[RecGuid] = [er].[ParentGuid] 
					 WHERE [lg].[UserGuid] = @EntryUserGuid 
					 
					 UNION ALL 
					 
					 SELECT
					   [RecGuid] 
					 FROM [LG000] WHERE [USerGuid] = @EntryUserGuid AND [RecGuid] <> 0X00 
			    )
			) 
		AND (@Posted = -1 OR ceIsPosted = @Posted) 
	ORDER BY   
			[enDate], [co].[coCode], [Ce].[acCode]   
	EXEC [prcCheckSecurity] @UserGuid   
	
	IF @PrevBal > 0 
	BEGIN 
		INSERT INTO [#Result] 
		([CostPoint],[CostCode],[CostName],	[Account],  
			[AccCode],[AccName],[ceNumber],[Date], 	 
			[Debit],[Credit],[Notes],[Prv]) 
		SELECT 
			[CostPoint],[CostCode],[CostName],[Account],  
			[AccCode],[AccName],0,'1/1/1980', 	 
			SUM([Debit]),SUM([Credit]),'',0 
		FROM [#Result] 
		WHERE [Date] < @StartDate 
		GROUP BY [CostPoint],[CostCode],[CostName],	[Account],  
			[AccCode],[AccName] 
		
		IF (@@ROWCOUNT > 0) 
		BEGIN 
			DELETE [#Result] WHERE [Date] < @StartDate AND [Date] > '1/1/1980' 
		END 
	END 
	SELECT 
		[CostPoint], 
		[CostCode], 
		[CostName], 
		[ceGuid], 

		CASE Er.ParentType WHEN 600 THEN @DocumentStr
		ELSE
			(CASE ISNULL(BT.Guid, 0x0) WHEN 0x0 
			THEN  
				CASE ISNULL(ET.Guid, 0x0) WHEN 0x0
				THEN 
					CASE ISNULL(NT.Guid, 0x0) WHEN 0x0 	
					THEN
						N''
					ELSE 
						CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN '' THEN NT.Abbrev ELSE NT.LatinAbbrev END END   
					END

				ELSE
					CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN '' THEN ET.Abbrev ELSE ET.LatinAbbrev END END   
				END
			ELSE 
				CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN '' THEN BT.Abbrev ELSE BT.LatinAbbrev END END   
			END)
			 + ': ' + CONVERT(nvarchar(10), ER.ParentNumber) 
		END AS ceStr,
		--N'' ceStr,
		[ceNumber], 
		[Account], 
		[AccCode], 
		[AccName], 
		RES.[Date],
		RES.[PostDate],
		RES.[IsPosted],
		RES.[Debit], 
		RES.[Credit], 
		[Balance],
		RES.[Notes],
		[Class],
		[ContraAccGUID],
		[ContraAccName],
		[ContraAccCode]
	FROM 
		[#Result] RES
		INNER JOIN ce000 CE ON RES.[ceGuid] = CE.GUID
		LEFT JOIN er000 ER ON ER.EntryGUID = CE.GUID
		LEFT JOIN bt000 BT ON CE.TypeGUID = BT.GUID
		LEFT JOIN et000 ET ON CE.TypeGUID = ET.GUID
		LEFT JOIN nt000 NT ON CE.TypeGUID = NT.GUID
	ORDER BY 
		[AccCode], [CostCode],[prv],[id] 
	
	SELECT *, 1 AS [flag] FROM [#SecViol]  
