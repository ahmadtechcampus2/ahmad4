################################################################################
CREATE PROCEDURE repCurGL
	@StartDate		[DATETIME],  
	@EndDate		[DATETIME], 
	@AccGUID		[UNIQUEIDENTIFIER],   
	@CurGUID1		[UNIQUEIDENTIFIER],     
	@CurGUID2		[UNIQUEIDENTIFIER],     
	@Class			[NVARCHAR](256),  
	@ShowPosted 	[INT],	
	@ShowUnPosted 	[INT],	
	@RptType		[BIT],
	@ShowText		[NVARCHAR](256),
	@ConsolidateAcc	[INT],			-- =0 if not consolidate		  
	@CurrentUserGuid		[UNIQUEIDENTIFIER] = 0X00,
	@ShwInLocalCurr	[BIT] = 0,
	@CostGuid		[UNIQUEIDENTIFIER] = 0X00,
	@PrevBal		BIT = 0	,
	@FromPostDate AS [DATETIME],
	@ToPostDate AS [DATETIME],
	@SrcGuid		    [UNIQUEIDENTIFIER] = 0X0,
	@ShowTwoCurr [BIT] = 0
AS   
	SET NOCOUNT ON

	DECLARE @Lang INT
	EXEC @Lang = [dbo].fnConnections_GetLanguage;

	--- 1 posted, 0 unposted -1 both       
	DECLARE @PostedType AS  [INT]      
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 0) )		         
		SET @PostedType = 1      
	IF( (@ShowPosted = 0) AND (@ShowUnPosted = 1))         
		SET @PostedType = 0      
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 1))         
		SET @PostedType = -1      
	-- @RptType = 0 view two cur. separetly, =1  view two Cur. togather
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserSec [INT]
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)
	-- Security Table ----------------------------------------------------------------
	CREATE TABLE [#SecViol]
	(   
		[Type] 	[INT],   
		[Cnt] 	[INT]   
	)   
	-- Accounts Table ---------------------------------------------------------------
	CREATE TABLE [#AccountsList]
	(
		[GUID]		[UNIQUEIDENTIFIER],
		[Security]	[INT],
		[level]		[INT]
	)
	DECLARE @StDate DATETIME
	IF @PrevBal = 0
		SET @StDate = @StartDate
	ELSE
		SET @StDate = '1/1/1980'
	CREATE TABLE [#CostTbl]		( [Cost] [UNIQUEIDENTIFIER], [CostSec] [INT])
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	INSERT INTO [#AccountsList] EXEC [prcGetAccountsList] @AccGUID,0
	CREATE CLUSTERED INDEX [accInd] ON [#AccountsList]([GUID])
	---------------------------------------------------
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])        
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])    
DECLARE  @UserId [UNIQUEIDENTIFIER],@HosGuid [UNIQUEIDENTIFIER]  
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()  
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID 
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID        
      
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID        
	    
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]    
	DECLARE @str NVARCHAR(1000) 
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
		-----------------------------------------------------------------
		CREATE TABLE [#Result]
	(
		[enDate]		[DATETIME],
		[PostDate]		[DATETIME], 
		[IsPosted]      [BIT], 
		[CeGUID]		[UNIQUEIDENTIFIER],
		[CeNumber]		[INT],
		[Security]		[INT],
		[Cur1Debit]		[FLOAT],
		[Cur1Credit]	[FLOAT],
		[Cur2Debit]		[FLOAT],
		[Cur2Credit]	[FLOAT],
		[enCurPtr]		[UNIQUEIDENTIFIER],
		[enNotes]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI,		   
		[enNumber]		[INT],
		[AccName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,		 
		[AccLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[AccGUID]		[UNIQUEIDENTIFIER],
		[AccSecurity] 	[INT],	
		[UserSecurity] 	[INT],
		[ParentGUID] 	[UNIQUEIDENTIFIER],
		[ParentType]	[INT],
		[CurrGuid]		[UNIQUEIDENTIFIER],
		[Debit]			[FLOAT],
		[Credit]		[FLOAT],
		[Class]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[CostName]      [NVARCHAR](500) COLLATE ARABIC_CI_AI,		 
		[ContraAccName] [NVARCHAR](500) COLLATE ARABIC_CI_AI,		 
		[BranchName]        [NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[enCurrencyVal]	 	[FLOAT],
					
	)   
	DECLARE @MyCurVal1 AS [FLOAT]
	DECLARE @MyCurVal2 AS [FLOAT]
	SET @MyCurVal1 = (SELECT [MyCurrencyVal] FROM [vwMy] WHERE [MyGUID] = @CurGUID1)
	SET @MyCurVal2 = (SELECT [MyCurrencyVal] FROM [vwMy] WHERE [MyGUID] = @CurGUID2)
	INSERT INTO [#Result]
		SELECT 
			[en].[enDate], 
			CASE [en].[ceIsPosted] WHEN 1 THEN [en].[cePostDate] ELSE '1980-1-1' END, 
			[en].[ceIsPosted],
			[en].[CeGUID],
			[en].[CeNumber],  
			[en].[ceSecurity],
			--	Debit1
			CASE 
				WHEN [en].[EnCurrencyPtr]  = @CurGUID1 OR  @CurGUID1 = 0X00 THEN ISNULL([en].[enDebit] /(CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END),0)
				ELSE
					CASE @RptType 
						WHEN 0 THEN	0
						ELSE ISNULL([en].[enDebit] / (CASE @MyCurVal1 WHEN 0 THEN 1 ELSE @MyCurVal1 END), 0)
					END
			END,
			--	Credit1
			CASE  
				WHEN [en].[EnCurrencyPtr] = @CurGUID1 OR @CurGUID1 = 0X00 THEN ISNULL([en].[enCredit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END) ,0)
				ELSE
					CASE @RptType 
						WHEN 0 THEN	0
						ELSE ISNULL([en].[enCredit] / (CASE @MyCurVal1 WHEN 0 THEN 1 ELSE @MyCurVal1 END), 0)
					END
			END,
			--	Debit2
			CASE [en].[EnCurrencyPtr]
				WHEN @CurGUID2 THEN ISNULL([en].[enDebit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END) ,0)
				ELSE
					CASE @RptType 
						WHEN 0 THEN	0
						ELSE ISNULL([en].[enDebit] / (CASE @MyCurVal2 WHEN 0 THEN 1 ELSE @MyCurVal2 END),0)
					END
			END,
			--	Credit2
			CASE [en].[EnCurrencyPtr] 
				WHEN @CurGUID2 THEN ISNULL([en].[enCredit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END), 0)
			ELSE
				CASE @RptType 
					WHEN 0 THEN	0
					ELSE ISNULL([en].[enCredit] / (CASE @MyCurVal2 WHEN 0 THEN 1 ELSE @MyCurVal2 END), 0)
				END
			END,
			[en].[EnCurrencyPtr],
			[enNotes],
			[enNumber],
			[en].[acCode] + '-' +[en].[acName],  
			[en].[acCode] + '-' +[en].[acLatinName], 
			[en].[acGUID],
			[ac].[Security],
			@UserSec,
			ISNULL([er].[ParentGUID],0X0),
			[er].[ParentType],
			CASE @CurGUID1 WHEN 0X00 THEN [en].[EnCurrencyPtr] ELSE 0X00 END,
			[en].[enDebit],[en].[enCredit],[enClass] ,
			[co1].[Code] + '-' +[co1].[Name],
		    [ac1].[Code] + '-' +[ac1].[Name],
			[br].[code] + '-' +[br].[Name],
			[en].[enCurrencyVal]
			
		FROM
	-- ãä ÇÌá äæÚ ÇáÓäÏ
			[fnExtended_En_Fixed]( @CurGUID1) AS [En]
			LEFT JOIN ac000 ac1 on ac1.guid = [en].enContraAcc
			LEFT join co000 co1 on co1.guid = en.enCostPoint
			LEFT JOIN br000 br on br.guid = en.cebranch
			INNER JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]
			INNER JOIN [#AccountsList] AS [ac]  ON [acGUID] = [ac].[GUID]
			INNER JOIN [#CostTbl] [co] ON [enCostPoint] = [Cost]
			LEFT JOIN  er000 [er] ON er.[EntryGuid] = [en].[ceGuid]
		WHERE   
			[endate] BETWEEN @StDate AND @EndDate
			AND (ceIsPosted = 0 OR (ceIsPosted = 1  AND [cePostDate] BETWEEN @FromPostDate AND @ToPostDate ))
			AND [cePostDate] BETWEEN @FromPostDate AND @ToPostDate
			AND( /*(@CurGUID2 = 0x00) OR */( (@CurGUID1 = 0x00) OR ([EnCurrencyPtr] = @CurGUID1) OR ([EnCurrencyPtr] = @CurGUID2) ) )  -- íÚÑÖ ÚãáÊíä  
			AND( (@Class = '') OR ([enClass] = @Class)	)			 		
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND [ceIsPosted] = 1) 
				OR (@PostedType = 0 AND [ceIsPosted] = 0) )      
			AND( (@CurrentUserGuid  = 0X00) OR CASE [er].[ParentGuid] WHEN 0X00 THEN [ceGuid] ELSE [er].[ParentGuid] END IN (SELECT [RecGUID] FROM [lg000] WHERE [UserGuid] = @CurrentUserGuid) )	-- ÅÙåÇÑ ÇáÓäÏÇÊ ÇáÛíÑ ãÑÍáÉ  
	EXEC [prcCheckSecurity]
	IF @PrevBal > 0
	BEGIN
		SELECT  [enCurPtr], 
				[CurrGuid], 
				SUM([Cur1Debit]) [Cur1Debit] ,
				SUM([Cur1Credit]) [Cur1Credit],
				SUM([Cur2Debit]) [Cur2Debit],
				SUM([Cur2Credit]) [Cur2Credit],
				SUM([Debit]) [Debit],
				SUM([Credit]) [Credit], CostName, ContraAccName, BranchName
		FROM [#Result] 
		WHERE [enDate] < @StartDate
		GROUP BY [enCurPtr],[CurrGuid], CostName, ContraAccName, BranchName
		DELETE [#Result] WHERE [enDate] < @StartDate AND [enDate] > '1/1/1980'			
	END
	IF @ShowTwoCurr = 0
	BEGIN
		IF @CurGUID1 = 0X00
			SELECT [Guid],[Code],[Name]
			FROM [my000] WHERE [Guid] IN (SELECT DISTINCT [CurrGuid] FROM [#RESULT])
		ELSE
			SELECT [Guid],[Code],[Name]
			FROM my000 WHERE [GUID] = @CurGUID1 
	END
	ELSE
	BEGIN
		IF @CurGUID1 = 0X00
			SELECT [Guid],[Code],[Name]
			FROM [my000] WHERE [Guid] IN (SELECT DISTINCT [CurrGuid] FROM [#RESULT])
	END
	IF( @ConsolidateAcc = 1)
	BEGIN
		SELECT 
			[enDate],
			[r].[PostDate] AS [PostDate],
			[r].[IsPosted] AS [IsPosted],
			[CeGUID],
			[CeNumber], 
			NULL AS [Security],
			ISNULL(SUM([Cur1Debit]), 0) AS [Cur1Debit], 
			ISNULL(SUM([Cur1Credit]), 0) AS [Cur1Credit], 
			ISNULL(SUM([Cur2Debit]), 0) AS [Cur2Debit], 
			ISNULL(SUM([Cur2Credit]), 0) AS [Cur2Credit], 
			[enCurPtr], 
			CASE COUNT(*) 
				WHEN 1 THEN (SELECT TOP 1 [enNotes] FROM [vwEn] AS [en] WHERE [enParent] = [CeGUID] AND [enAccount] = [AccGUID] AND [en].[enCurrencyptr] = [r].[enCurPtr] )  
				ELSE @ShowText 
			END AS [enNotes],
			NULL AS [enNumber],
			[AccName],		  
			[AccLatinName],	 
			[AccGUID], 
			NULL AS [AccSecurity],
			NULL AS [UserSecurity],
			[r].[ParentGUID], 
			[r].[ParentType],
			[CurrGuid],
			NULL AS [Debit],			
			NULL AS [Credit],		
			NULL AS [Class],
			NULL AS [CostName],
			NULL AS [ContraAccName],
			BranchName,
			[r].[enCurrencyVal],

			((CASE ISNULL(BT.Guid, 0x0) WHEN 0x0 
			THEN  
				CASE ISNULL(ET.Guid, 0x0) WHEN 0x0
				THEN 
					CASE ISNULL(NT.Guid, 0x0) WHEN 0x0 	
					THEN
						N''
					ELSE 
						CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN N'' THEN NT.Abbrev ELSE NT.LatinAbbrev END END   
					END

				ELSE
					CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN N'' THEN ET.Abbrev ELSE ET.LatinAbbrev END END   
				END
			ELSE 
				CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN N'' THEN BT.Abbrev ELSE BT.LatinAbbrev END END   
			END)
				+ ': ' + CONVERT(nvarchar(10), ER.ParentNumber))  AS [DocumentOrigin]

		FROM   
			[#Result] AS [r]
			INNER JOIN ce000 CE ON [r].[ceGuid] = CE.GUID
			LEFT JOIN er000 ER ON ER.EntryGUID = CE.GUID
			LEFT JOIN bt000 BT ON CE.TypeGUID = BT.GUID
			LEFT JOIN et000 ET ON CE.TypeGUID = ET.GUID
			LEFT JOIN nt000 NT ON CE.TypeGUID = NT.GUID
		GROUP BY 
			[enDate],
			[r].[PostDate],   
			[CeGUID],
			((CASE ISNULL(BT.Guid, 0x0) WHEN 0x0 
			THEN  
				CASE ISNULL(ET.Guid, 0x0) WHEN 0x0
				THEN 
					CASE ISNULL(NT.Guid, 0x0) WHEN 0x0 	
					THEN
						N''
					ELSE 
						CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN N'' THEN NT.Abbrev ELSE NT.LatinAbbrev END END   
					END

				ELSE
					CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN N'' THEN ET.Abbrev ELSE ET.LatinAbbrev END END   
				END
			ELSE 
				CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN N'' THEN BT.Abbrev ELSE BT.LatinAbbrev END END   
			END)
				+ ': ' + CONVERT(nvarchar(10), ER.ParentNumber)),
			[CeNumber],
			[enCurPtr],
			[AccName],	
			[AccLatinName],	 
			[AccGUID],
			[r].[ParentGUID],
			[r].[ParentType],
			[CurrGuid],
			[BranchName],
			[r].[IsPosted],
			[r].[enCurrencyVal]
		ORDER BY  
			[CurrGuid],[enDate], [ParentType], [CeNumber]
	END
	ELSE
	BEGIN
		SELECT  [r].*,

			((CASE ISNULL(BT.Guid, 0x0) WHEN 0x0 
			THEN  
				CASE ISNULL(ET.Guid, 0x0) WHEN 0x0
				THEN 
					CASE ISNULL(NT.Guid, 0x0) WHEN 0x0 	
					THEN
						N''
					ELSE 
						CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN N'' THEN NT.Abbrev ELSE NT.LatinAbbrev END END   
					END

				ELSE
					CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN N'' THEN ET.Abbrev ELSE ET.LatinAbbrev END END   
				END
			ELSE 
				CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN N'' THEN BT.Abbrev ELSE BT.LatinAbbrev END END   
			END)
				+ ': ' + CONVERT(nvarchar(10), ER.ParentNumber))  AS [DocumentOrigin]
		FROM   
			[#Result] AS [r]
			INNER JOIN ce000 CE ON [r].[ceGuid] = CE.GUID
			LEFT JOIN er000 ER ON ER.EntryGUID = CE.GUID
			LEFT JOIN bt000 BT ON CE.TypeGUID = BT.GUID
			LEFT JOIN et000 ET ON CE.TypeGUID = ET.GUID
			LEFT JOIN nt000 NT ON CE.TypeGUID = NT.GUID
		ORDER BY  
			[CurrGuid],[enDate], 
			[ParentType], 
			((CASE ISNULL(BT.Guid, 0x0) WHEN 0x0 
			THEN  
				CASE ISNULL(ET.Guid, 0x0) WHEN 0x0
				THEN 
					CASE ISNULL(NT.Guid, 0x0) WHEN 0x0 	
					THEN
						N''
					ELSE 
						CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN N'' THEN NT.Abbrev ELSE NT.LatinAbbrev END END   
					END

				ELSE
					CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN N'' THEN ET.Abbrev ELSE ET.LatinAbbrev END END   
				END
			ELSE 
				CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN N'' THEN BT.Abbrev ELSE BT.LatinAbbrev END END   
			END)
				+ ': ' + CONVERT(nvarchar(10), ER.ParentNumber)),
			[CeNumber], 
			[enNumber]
	END
	
	DECLARE @LCurrCodeName NVARCHAR(2000)
	SELECT @LCurrCodeName =  myName FROM vwmy WHERE myNumber = 1
	SELECT @LCurrCodeName AS LCurrCodeName,SUM([Debit]) AS [Debit],SUM([Credit]) AS [Credit] FROM [#Result]
	SELECT * FROM  [#SecViol]
################################################################################
#END