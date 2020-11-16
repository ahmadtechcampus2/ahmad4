################################################################################
CREATE PROCEDURE repJournal
	@StartNum 				[INT],        
	@EndNum 				[INT],        
	@StartDate 				[DATETIME],        
	@EndDate 				[DATETIME],        
	@CurGUID				[UNIQUEIDENTIFIER],     
	@ShowPosted				[INT],        
	@ShowUnPosted 			[INT],       
	@SourceTypes 			[UNIQUEIDENTIFIER],     
	@OperationMode			[INT],
	@OperationType			[INT],
	@Val1					[FLOAT],     
	@Val2					[FLOAT],
	@NotesContain 			[NVARCHAR](1000),-- NULL or Contain Text  
	@NotesNotContain		[NVARCHAR](1000), -- NULL or Not Contain  
	@CostGuid				[UNIQUEIDENTIFIER],
	@ShowFromTo				[INT] = 0,
	@ShowMainAcc			[INT] = 0,
	@EntryUserGuid			[UNIQUEIDENTIFIER] = 0X00,
	@shwUser				[BIT] = 0,
	@FromPostDate 			[DATETIME],         
	@ToPostDate 			[DATETIME],
	@ShowAudited			[BIT] = 0,
	@ShowNoneAudited		[BIT] = 0,
	@CheckForUsers			[BIT] = 0,
	@Rid					[FLOAT] = 0,
	@ShowMatData			[BIT] = 1,
	@ShowDetails			[BIT] = 1,
	@IsSummarizeAccInEntry	[BIT] = 0,
	@IsGroupedByCost		[BIT] = 0,
	@IsGroupedByClass		[BIT] = 0,
	@IsGroupedByContraAccount [BIT] = 0,
	@ShowDoc				[BIT] = 0,
	@NoAccessStr			[NVARCHAR](256)
AS    
	SET NOCOUNT ON    
	--- 1 posted, 0 unposted -1 both      
	DECLARE @PostedType AS  [INT]     
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 0) )		        
		SET @PostedType = 1     
	IF( (@ShowPosted = 0) AND (@ShowUnPosted = 1))        
		SET @PostedType = 0     
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 1))        
		SET @PostedType = -1     
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserSec [INT]
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)  
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#SecViol]( [Type] [INT],[Cnt] [INT])     
	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList] 		@CostGuid 
	
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SourceTypes, @UserGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SourceTypes, @UserGUID       
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])  
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SourceTypes, @UserGUID
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]   
	
	CREATE TABLE [#Cost] ([CostGuid] UNIQUEIDENTIFIER, [CoCode] NVARCHAR(256), [CoName] NVARCHAR(500), [Security] INT)
	INSERT INTO [#Cost] SELECT [CostGuid],[Code] AS [CoCode],[Name] AS [CoName],[c].[Security] FROM [#CostTbl] AS [c] INNER JOIN [co000] AS [co] ON [co].[Guid] = [CostGuid]
	IF ISNULL(@CostGuid,0X00) = 0X00
		INSERT INTO [#Cost] VALUES (0X00,'','',0) 
	CREATE TABLE [#Result]
	(     
		[CeDate]			[DATETIME],
		[PostDate]			[DATETIME],
		[CeIsPosted]		[INT],
		[CeGuid]			[UNIQUEIDENTIFIER],  
		[CeNumber]			[INT],     
		[CeNotes]			[NVARCHAR](1000) COLLATE ARABIC_CI_AI,		     
		[EnGUID]			[UNIQUEIDENTIFIER],  
		[EnNumber]			[INT],		  
		[EnCurName]			[NVARCHAR](256) ,     
		[EnCurVal]			[FLOAT],     
		[EnClass]			[NVARCHAR](256) ,     
		[EnCostName]		[NVARCHAR](256) , 
		[enContraAcc]		[NVARCHAR](256) , 
		[EnContraGuid]		[UNIQUEIDENTIFIER],     
		[EnDebit]			[FLOAT],     
		[EnCredit]			[FLOAT],     
		[EnAccount]			[UNIQUEIDENTIFIER],  
		[AccCode]			[NVARCHAR](500) COLLATE ARABIC_CI_AI,     
		[AccName]			[NVARCHAR](512) COLLATE ARABIC_CI_AI,     
		[AccLatinName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,   
		[EnCustomerGUID]	[UNIQUEIDENTIFIER],  
		[EnNotes]			[NVARCHAR](1000) COLLATE ARABIC_CI_AI,     
		[acCurrencyPtr]		[UNIQUEIDENTIFIER], 
		[CurCardDeBIT]		[FLOAT],     
		[CurCardCredit]		[FLOAT], 		  
		[Security]	   		[INT],  
		[ParentGUID] 		[UNIQUEIDENTIFIER],   
		[ParentType] 		[INT],  
		[ParentTypeNum] 	[INT],  
		[UserSecurity]		[INT], 
		[EnAccSecurity]		[INT],
		[ceBranch]			[UNIQUEIDENTIFIER],
		[ceBranchName]		[NVARCHAR](256) ,
		[EnBalFC]			[FLOAT],
		[acParentGuid]		[UNIQUEIDENTIFIER], 
		[EnNumer2]			[INT],
		[DebitinCurr]		[FLOAT],
		[CrerditinCurr]		[FLOAT],
		[Flag]				[bit],
		[IsDebit]			[bit],
		Num					[VARCHAR](256) , 
		[IsDetailAccount]	[BIT] DEFAULT 1,
		[IsChecked]			[BIT] DEFAULT 0,
		[MatName]			[NVARCHAR](256),
		[MatQuantity]		[FLOAT],
		[MatUnityName]		[NVARCHAR](256),
		[IsSummarized]		BIT DEFAULT 0,
		EnDate				DATETIME
	) 
	
	CREATE TABLE #MATS
	(
		AccGUID UNIQUEIDENTIFIER,
		MatGroup  UNIQUEIDENTIFIER,
		MatGUID UNIQUEIDENTIFIER,
		MatName NVARCHAR(256), 
		MatQuantity FLOAT,
		MatUnityName NVARCHAR(256),
		EntryGUID UNIQUEIDENTIFIER,
		EnGUID UNIQUEIDENTIFIER,
		BiGUID UNIQUEIDENTIFIER
	)
	IF @ShowMatData = 1
	BEGIN
		INSERT INTO [#MATS]
		SELECT
			AccGUID,
			MatGroup,
			MatGUID,
			MatName, 
			MatQuantity,
			MatUnityName,
			EntryGUID,
			EnGUID,
			BiGUID
		FROM 
			fnGetMatDataByRelatedEntry()
	END
	ELSE
	BEGIN
		INSERT INTO [#MATS] 
		SELECT
			0x0 AS AccGUID,
			0x0 AS MatGroup,
			0x0 AS MatGUID,
			'' AS MatName, 
			0 AS MatQuantity,
			'' AS MatUnityName,
			0x0 AS EntryGUID,
			0x0 AS EnGUID,
			0x0 AS BiGUID
	END
	INSERT INTO [#Result]
		SELECT        
			[ceDate],
			[cePostDate],
			[ceIsPosted],        
			[ceGuid],  
			[ceNumber],        
			[ceNotes],
			r.[enGUID],
			[EnNumber],  
			[myCode]  AS [CurName],  
			[EnCurrencyVal],     
			[EnClass],     
			CASE [EnCostPoint]      
				WHEN 0x0 THEN '' ELSE [coCode] +'-'+ [coName]
			END, -- cost name
			
			(ContraAc.acCode+'-'+ ContraAc.[acName]),  
			enContraAcc,
			[FixedEnDeBIT],        
			[FixedEnCredit],       
			[enAccount],        
			[r].[acCode],
			[r].[acName],
			[r].[acLatinName],
			r.enCustomerGUID,
			[enNotes],   
			r.[acCurrencyPtr] , 
			--MyCode AS AcCurCode,     
			[enDebit], 
			[EnCredit], 		  
			[ceSecurity],  
			[ParentGUID],  
			[erparenttype],  
			[ceParentNumber], 
			ISNULL(src.[Security], @UserSec),
			[r].[acSecurity], 
			[ceBranch],
			ISNULL([brName], ''),
			[EnDeBIT] - [EnCredit],
			r.[acParent], 
			1,
			[enDebit]/[enCurrencyVal],
			[EnCredit]/[enCurrencyVal],0,case when [endebit] > 0 then 1 else 0 end,
			'',
			1, 
			0,
			ISNULL(mt.MatName, ''),
			ISNULL(mt.MatQuantity, 0),
			ISNULL(mt.MatUnityName, ''),
			0,
			r.[enDate]
		FROM        
			[fnExtended_En_Fixed_src] (@SourceTypes, @CurGUID) AS [r]  
			INNER JOIN [vwMy] ON [myGUID] = [EnCurrencyPtr]
			INNER JOIN [#Cost] AS [co] ON   [EnCostPoint] =  [CostGuid]
			LEFT JOIN [#EntryTbl] src ON r.ParentTypeGuid = src.[Type] 
			LEFT JOIN [vwBr] On [brGUID] = [CeBranch]
			LEFT JOIN [#MATS] mt ON (r.enBiGUID = mt.BiGUID) AND (r.enGUID = mt.EnGUID)
			LEFT JOIN vwAc AS ContraAc ON ContraAc.acGUID = r.enContraAcc
		WHERE
			(@ShowFromTo = 0 OR [ceNumber] BETWEEN @StartNum AND @EndNum )     
			AND [ceDate] BETWEEN @StartDate AND @EndDate     
			AND (ceIsPosted = 0 OR (ceIsPosted = 1 AND [cePostDate]	BETWEEN @FromPostDate	AND @ToPostDate))
			AND( (ISNULL(@NotesContain, '') = '')	OR ([CeNotes] LIKE '%'+ @NotesContain + '%') OR ( [EnNotes] LIKE '%' + @NotesContain + '%'))  
			AND( (ISNULL(@NotesNotContain, '') ='')	OR (([CeNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([EnNotes] NOT LIKE '%'+ @NotesNotContain + '%')))	  
	-- LessThan ------------------------------------------------------------------------
			AND( 
				(@OperationMode = 0) 
				OR
				( 
					(@OperationMode = 1) 
					AND
					(	
						(@Val1 > CASE @OperationType 
								WHEN 0 THEN  CASE [FixedEnDeBIT] WHEN 0 THEN @Val1 ELSE [FixedEnDeBIT] END-- Operation on DeBIT
								WHEN 1 THEN  CASE [FixedEnCredit] WHEN 0 THEN @Val1 ELSE [FixedEnCredit] END-- Operation on Credit
								WHEN 2 THEN  CASE [FixedEnDeBIT]	WHEN 0 THEN @Val1 ELSE [FixedEnDeBIT] END
							END
						) 
						OR
						(@Val1 > CASE @OperationType 
								WHEN 2 THEN CASE [FixedEnCredit] WHEN 0 THEN @Val1 ELSE [FixedEnCredit] END
								ELSE @Val1
							END
						) 
					) 
				)
	-- GreaterThan ---------------------------------------------------------------------
				OR( 
					(@OperationMode = 2) 
					AND
					( 
						(@Val1 < CASE @OperationType 
								WHEN 0 THEN  [FixedEnDeBIT] -- Operation on DeBIT
								WHEN 1 THEN  [FixedEnCredit] -- Operation on Credit
								WHEN 2 THEN  [FixedEnDeBIT]	
							END
						) 
						OR 
						(@Val1 < CASE @OperationType 
								WHEN 2 THEN [FixedEnCredit] 
								ELSE @Val1   
							END
						) 					
					)
				)	
	--EqualTo --------------------------------------------------------------------------
				OR( 
					(@OperationMode = 3) 
					AND
					( 
						(@Val1 = CASE @OperationType 
								WHEN 0 THEN  [FixedEnDeBIT]  -- Operation on DeBIT
								WHEN 1 THEN  [FixedEnCredit] -- Operation on Credit
								WHEN 2 THEN  [FixedEnDeBIT]	
							END
						) 
						OR
						(@Val1 = CASE @OperationType 
								WHEN 2 THEN [FixedEnCredit] 
								ELSE @Val1 +1
							END
						) 
					) 
				)
	-- LessOREQualThan ------------------------------------------------------------------------
				OR
				( 
					(@OperationMode = 5) 
					AND
					(	
						(@Val1 >= CASE @OperationType 
								WHEN 0 THEN  CASE [FixedEnDeBIT] WHEN 0 THEN (@Val1+1) ELSE [FixedEnDeBIT] END-- Operation on DeBIT
								WHEN 1 THEN  CASE [FixedEnCredit] WHEN 0 THEN (@Val1+1) ELSE [FixedEnCredit] END-- Operation on Credit
								WHEN 2 THEN  CASE [FixedEnDeBIT]	WHEN 0 THEN (@Val1+1) ELSE [FixedEnDeBIT] END
							END
						) 
						OR 
						(@Val1 >= CASE @OperationType 
								WHEN 2 THEN CASE [FixedEnCredit] WHEN 0 THEN (@Val1+1) ELSE [FixedEnCredit] END
								ELSE (@Val1 + 1) 
							END
						) 
					) 
				)
	-- select ennumber,endeBIT,encredit  from vwen where (100000 >= endeBIT) or (10000 >= )
	-- GreaterThan ---------------------------------------------------------------------
				OR( 
					(@OperationMode = 6) 
					AND
					( 
						(@Val1 <= CASE @OperationType 
								WHEN 0 THEN  [FixedEnDeBIT]  -- Operation on DeBIT
								WHEN 1 THEN  [FixedEnCredit] -- Operation on Credit
								WHEN 2 THEN  [FixedEnDeBIT]	
							END
						) 
						OR
						(@Val1 <= CASE @OperationType 
								WHEN 2 THEN [FixedEnCredit] 
								ELSE (@Val1 - 1)  
							END
						) 					
					)
				)	
	--Between Two Values ----------------------------------------------------------------
	--Exp. When OperationType = 0 ( deBIT >= Val1 && deBIT <= Val2
	--Exp. When OperationType = 2 ( ( (deBIT >= Val1) && (deBIT <= Val2)) || (Credit >= Val1 && Credit <= Val2) )
				OR( 
					(@OperationMode = 4) 
					AND( 
						(
							( @Val1 <= 
								CASE @OperationType 
									WHEN 0 THEN  [FixedEnDeBIT]  -- Operation on DeBIT
									WHEN 1 THEN  [FixedEnCredit] -- Operation on Credit
									WHEN 2 THEN  [FixedEnDeBIT]	
								END
							) 
				 			AND
							( @Val2 >= 
								CASE @OperationType 																
									WHEN 0 THEN  [FixedEnDeBIT]  -- Operation on DeBIT
									WHEN 1 THEN  [FixedEnCredit] -- Operation on Credit
									WHEN 2 THEN  [FixedEnDeBIT]
								END
							)
						)
						OR
						(
							( @Val1 <= 
								CASE @OperationType 
									WHEN 2 THEN [FixedEnCredit] 
									ELSE @Val1 +1
								END
							) 
							AND
							( @Val2 >= 
								CASE @OperationType 
									WHEN 2 THEN [FixedEnCredit] 
									ELSE @Val2+1  
								END
							)
						)
					)
				) 
			)
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND [ceIsPosted] = 1)      
				OR (@PostedType = 0 AND [ceIsPosted] = 0) )
	
	UPDATE R set Num = ch.num FROM [#Result] R INNER JOIN ch000 ch on ch.Guid = r.[ParentGUID] where [ParentType] in (5,6,7,8) --
	
	-- Auditing -------------------------------------------------------------------
	IF @ShowAudited = 1 OR @ShowNoneAudited = 1
	BEGIN   
		UPDATE R
		SET    
			IsChecked = 1
		FROM    
			#Result AS R JOIN rch000 AS A ON R.CeGuid = A.ObjGUID
		WHERE
			A.Type = @Rid AND ((@CheckForUsers = 1) OR (A.UserGuid = @UserGuid))  
		DELETE #Result 
		WHERE 
			((@ShowAudited = 0) AND (IsChecked = 1))
			OR 
			((@ShowNoneAudited = 0) AND (IsChecked = 0))
	END   
	
	IF (@EntryUserGuid <> 0X00 )
		DELETE r FROM #Result r LEFT JOIN (SELECT [EntryGuid]FROM [ER000] AS [er] INNER JOIN [LOG000] AS [Lg] ON [Lg].[RecGuid] = [er].[ParentGuid] WHERE [lg].[USerGuid] = @EntryUserGuid UNION ALL SELECT [RecGuid] FROM [LOG000] WHERE [USerGuid] = @EntryUserGuid AND [RecGuid] <> 0X00 ) Q ON q.[EntryGuid] = [r].[ceGuid]  WHERE q.[EntryGuid] IS NULL
	IF @IsSummarizeAccInEntry = 1
	BEGIN
		INSERT INTO [#Result]( [CeDate],[PostDate],[CeIsPosted],[CeGuid],[CeNumber],[CeNotes], [EnGUID], [EnNumber],		  
			[EnCurName],[EnCurVal],			
			[EnClass],[EnCostName],[enContraAcc],[EnContraGuid],		
			[EnDeBIT],[EnCredit],[EnAccount],			
			[AccCode], [AccName],[AccLatinName],[EnNotes],[acCurrencyPtr],		
			[CurCardDeBIT],[CurCardCredit],[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	
			[UserSecurity],	[EnAccSecurity],[ceBranch],			
			[ceBranchName], [acParentGuid], [EnBalFC],[EnNumer2],			
			[IsDetailAccount],
			[IsChecked],
			[IsSummarized]
		) 
		SELECT 
			[CeDate],
			[PostDate],
			[CeIsPosted],
			[CeGuid],
			[CeNumber],
			[CeNotes],
			0x0,
			Max([EnNumber]),
			'',
			1,
			CASE @IsSummarizeAccInEntry 
				WHEN 1 THEN CASE @IsGroupedByClass WHEN 1 THEN [EnClass] ELSE '' END
				ELSE [EnClass] 
			END,
			CASE @IsSummarizeAccInEntry 
				WHEN 1 THEN CASE @IsGroupedByCost WHEN 1 THEN [EnCostName] ELSE '' END
				ELSE [EnCostName] 
			END,
			 CASE  @IsSummarizeAccInEntry
				WHEN 1 THEN CASE @IsGroupedByContraAccount WHEN 1 THEN [enContraAcc] ELSE '' END
				ELSE [enContraAcc] 
			END
				,
			0X00,
			SUM([EnDeBIT]),
			SUM([EnCredit]),
			[EnAccount],        
			[AccCode],
			[AccName],
			[AccLatinName],
			'', 
			[acCurrencyPtr],
			0,  
			0, 
			[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	
			[UserSecurity],	[EnAccSecurity],[ceBranch],			
			[ceBranchName],[acParentGuid], Sum([EnBalFC]),Min([EnNumber]),
			1, [IsChecked], 1
		FROM [#Result]
		GROUP BY [CeDate],[PostDate],[CeIsPosted],[CeGuid],[CeNumber],[CeNotes],
		CASE @IsSummarizeAccInEntry 
				WHEN 1 THEN CASE @IsGroupedByClass WHEN 1 THEN [EnClass] ELSE '' END
				ELSE [EnClass] 
			END,
			CASE @IsSummarizeAccInEntry 
				WHEN 1 THEN CASE @IsGroupedByCost WHEN 1 THEN [EnCostName] ELSE '' END
				ELSE [EnCostName] 
			END,
			CASE @IsSummarizeAccInEntry 
				WHEN 1 THEN CASE @IsGroupedByContraAccount WHEN 1 THEN [enContraAcc] ELSE '' END
				ELSE [enContraAcc]
				end
			 ,
			[EnAccount],
			[AccCode],[AccName],[AccLatinName],[acCurrencyPtr],
			[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	
			[UserSecurity],	[EnAccSecurity], [ceBranch],			
			[ceBranchName],[acParentGuid], [FLAG], [IsChecked]
		DELETE [#Result] WHERE [IsSummarized] = 0 
	END 
	IF @ShowMainAcc > 0
	BEGIN
		INSERT INTO [#Result]( [CeDate],[PostDate],[CeIsPosted],[CeGuid],[CeNumber],[CeNotes],[EnGUID], [EnNumber],		  
			[EnCurName],[EnCurVal],			
			[EnClass],[EnCostName],[EnContraGuid],		
			[EnDeBIT],[EnCredit],[EnAccount],			
			[AccCode], [AccName],[AccLatinName],[EnNotes],[acCurrencyPtr],		
			[CurCardDeBIT],[CurCardCredit],[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	
			[UserSecurity],	[EnAccSecurity],[ceBranch],			
			[ceBranchName],[EnBalFC],[EnNumer2],			
			[IsDetailAccount]	
		) 
		SELECT 
			[CeDate],
			[PostDate],
			[CeIsPosted],
			[CeGuid],
			[CeNumber],
			[CeNotes],
			0x0,
			0,
			'',
			1,
			'',
			[EnCostName],
			0X00,
			SUM([EnDeBIT]),SUM([EnCredit]),[ac].[acGuid],        
			[ac].[acCode],
			[ac].[acName],
			[ac].[acLatinName],
			'', [ac].[acCurrencyPtr],
			0,  0, 
			[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	
			[UserSecurity],	[ac].[AcSecurity],[ceBranch],			
			[ceBranchName],Sum([EnBalFC]),Min([EnNumber]),
			0 -- IsDetailAccount
		FROM [#Result] AS [r] 
		INNER JOIN [vwac] AS [ac] ON [ac].[acGuid] = [r].[acParentGuid]
		GROUP BY [CeDate],[PostDate],[CeIsPosted],[CeGuid],[CeNumber],[CeNotes],[EnCostName],[ac].[acGuid],[ac].[acCode],[ac].[acName],[ac].[acLatinName],[ac].[acCurrencyPtr],
			[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	
			[UserSecurity],	[ac].[AcSecurity],[ceBranch],			
			[ceBranchName],[FLAG]
		UPDATE [r] 
		SET [EnNumer2] = rr.MinNumber
		FROM 
			[#Result] r
			INNER JOIN(SELECT [CeGuid], [EnAccount], MIN(EnNumer2) OVER (PARTITION BY [CeGuid], [EnAccount]) AS MinNumber FROM [#Result] WHERE IsDetailAccount = 0) rr
				ON r.EnAccount = rr.EnAccount AND [rr].[CeGuid] = [r].[CeGuid]
		UPDATE [r] 
		SET [EnNumer2] = [rr].[EnNumer2] 
		FROM  
			[#Result] AS [r] 
			INNER JOIN [#Result] AS [rr] ON [rr].[EnAccount] = [r].[acParentGuid] AND [rr].[CeGuid] = [r].[CeGuid]			  
	END 
	-----------------------------------------------------------------
	Exec [prcCheckSecurity] @UserGUID  
	DECLARE @browseAccSec INT = [dbo].[fnGetUserAccountSec_Browse]([dbo].[fnGetCurrentUserGUID]())
	UPDATE #Result SET 
		AccCode = @NoAccessStr, AccName = @NoAccessStr, AccLatinName = @NoAccessStr,
		EnGUID = 0x0, EnAccount = 0x0, EnDate = '',
		EnCurName = '', [EnCurVal] = 0, [EnClass] = '', [EnCostName] = '',
		[EnDebit] = 0, [EnCredit] = 0,
		[EnNotes] = '', [CurCardDeBIT] = 0, [CurCardCredit] = 0,
		[MatName] = '', [MatQuantity] = 0, [MatUnityName] = '', [EnBalFC] = 0, 
		EnContraGuid = 0x0, [DebitinCurr] = 0, [CrerditinCurr] = 0
	WHERE 
		#Result.EnAccSecurity > @browseAccSec
	-----------------------------------------------------------------
	CREATE TABLE [#MasterResult] (
		[CeDate]			[DATETIME],
		[PostDate]			[DATETIME],
		[CeIsPosted]		[INT],
		[CeGuid]			[UNIQUEIDENTIFIER],  
		[CeNumber]			[INT],     
		[CeNotes]			[NVARCHAR](1000) COLLATE ARABIC_CI_AI,		     
		[Security]	   		[INT],  
		[ParentGUID] 		[UNIQUEIDENTIFIER],   
		[ParentType] 		[INT],  
		[ParentTypeNum] 	[INT],  
		[ceBranch]			[UNIQUEIDENTIFIER],
		[ceBranchName]		[NVARCHAR](256) ,
		[IsChecked]			[bit],
		Num					[NVARCHAR](256) , 
		[Debit]				[FLOAT],
		[Credit]			[FLOAT],
		[Document]			[NVARCHAR](520),
		HasDocuments		INT DEFAULT (0)) 
	INSERT INTO [#MasterResult]
	SELECT 
		[CeDate],
		[PostDate],
		[CeIsPosted],
		[CeGuid],
		[CeNumber],
		[CeNotes],
		[Security],
		[ParentGUID],
		[ParentType],
		[ParentTypeNum],
		[ceBranch],
		[ceBranchName],
		[IsChecked],
		Num,
		SUM([EnDebiT]),
		SUM([EnCredit]), 
		'',
		0
	FROM 
		[#Result]
	WHERE 
		IsDetailAccount = 1
	GROUP BY 
		[CeDate],
		[PostDate],
		[CeIsPosted],
		[CeGuid],
		[CeNumber],
		[CeNotes],
		[Security],
		[ParentGUID],
		[ParentType],
		[ParentTypeNum],
		[ceBranch],
		[ceBranchName],
		Num,
		[IsChecked]
	
	IF @ShowDoc = 1
	BEGIN
		UPDATE res
		SET [Document] = (CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [bt].[Abbrev] ELSE (CASE [bt].[LatinAbbrev] WHEN '' THEN [bt].[Abbrev] ELSE [bt].[LatinAbbrev] END) END) + 
							+ ': ' + CAST(bu.Number AS VARCHAR(10)) 
		FROM   
			[#MasterResult] AS [res] 
			INNER JOIN [bu000] AS [bu] ON [res].[ParentGUID] = [bu].[GUID]  
			INNER JOIN [bt000] AS [bt] ON [bu].[TypeGUID] = [bt].[Guid]  
		UPDATE res
		SET [Document] = (CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [et].[Abbrev] ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] ELSE [et].[LatinAbbrev] END) END) + 
							+ ': ' + CAST(py.Number AS VARCHAR(10)) 
		FROM   
			[#MasterResult] AS [res] 
			INNER JOIN [py000] AS [py] ON [res].[ParentGUID] = [py].[GUID]  
			INNER JOIN [et000] AS [et] ON [py].[TypeGUID] = [et].[Guid]  
		UPDATE res
		SET [Document] = (CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [nt].[Abbrev] ELSE (CASE [nt].[LatinAbbrev] WHEN '' THEN [nt].[Abbrev] ELSE [nt].[LatinAbbrev] END) END) + 
							+ ': ' + CAST(ch.Number AS VARCHAR(10)) + (CASE ISNULL(res.Num, '') WHEN '' THEN '' ELSE ': ' + CAST(res.Num AS VARCHAR(10)) END)
		FROM   
			[#MasterResult] AS [res] 
			INNER JOIN [ch000] AS [ch] ON [res].[ParentGUID] = [ch].[GUID]  
			INNER JOIN [nt000] AS [nt] ON [ch].[TypeGUID] = [nt].[Guid]  
	END
	-------------------------------------------------------------------------
	UPDATE res
		SET HasDocuments = 
			CASE WHEN parentDoc.Guid IS NULL THEN 
				CASE WHEN ceDoc.Guid IS NULL THEN 0 ELSE 1 END 
			ELSE 1 END 
	FROM   
		[#MasterResult] AS res
		LEFT JOIN vwObjectRelatedDocument ceDoc ON res.CeGuid = ceDoc.Guid
        LEFT JOIN vwObjectRelatedDocument parentDoc ON res.ParentGUID = parentDoc.Guid
	-------------------------------------------------------------------------
	IF @shwUser = 1
	BEGIN 
		CREATE TABLE #Us([RecGuid] UNIQUEIDENTIFIER, [UserName] [NVARCHAR](256) ) 
		CREATE TABLE #UserEntries(EntryGUID UNIQUEIDENTIFIER, UserName NVARCHAR(500))
		INSERT INTO #Us
		SELECT a.[RecGuid], [LoginName] FROM LOG000 a JOIN
		(
			SELECT MAX(logTime) AS logTime, [RecGuid] from [LOG000] WHERE [RecGuid] <> 0X00 /*AND DrvRID = -1*/ 
			GROUP BY [RecGuid]) b ON a.[RecGuid] = b.[RecGuid] 
		INNER JOIN us000 u ON [USerGuid] = u.Guid
		WHERE a.logTime = b.logTime    
		INSERT INTO #UserEntries
		SELECT 
			er.[EntryGUID], 
			lg.[UserName] 
		FROM 
			[er000] AS [er] 
			INNER JOIN #us AS [Lg] ON [Lg].[RecGuid] = [er].[ParentGuid]
			INNER JOIN [#MasterResult] AS m ON m.CeGuid = [er].[EntryGUID]
		UNION ALL 
		SELECT 
			us.[RecGuid], 
			us.[UserName] 
		FROM 
			#us us
			INNER JOIN [#MasterResult] AS m ON m.CeGuid = us.RecGuid
	END 
	DECLARE @SQL VARCHAR(MAX)
	SET @SQL = ' SELECT mr.* ' 
	IF @shwUser = 1
		SET @SQL = @SQL + ', ISNULL([UserName],'''') AS [UserName] '
	ELSE 
		SET @SQL = @SQL + ', '''' AS [UserName] '
	SET @SQL = @SQL + ' FROM [#MasterResult] mr '
	IF @shwUser = 1
	BEGIN		
		SET @SQL = @SQL + ' LEFT JOIN (SELECT [EntryGUID], MAX([UserName]) AS UserName FROM #UserEntries us GROUP BY [EntryGUID]) AS q ON q.EntryGuid = mr.[CeGuid] '
	END 
	SET @SQL = @SQL + ' ORDER BY [ceBranch], [ceNumber], [ParentTypeNum], [ceDate]'
	
	EXEC (@SQL)
	
	IF @ShowDetails = 1
	BEGIN 
			
		SELECT 
			[ceGuid], [CeDate], [CeNumber], [EnGUID], [EnNumber], [EnNumer2], 
			[EnCurName], [EnCurVal], [EnClass], [EnCostName], EnDate,
			[EnDebit], [EnCredit], [EnAccount], [AccCode], CU.cuCustomerName AS EnCustomerName,
			CASE AccCode WHEN @NoAccessStr THEN @NoAccessStr ELSE [AccCode] + '-' + [AccName] END [AccName], 
			CASE AccCode WHEN @NoAccessStr THEN @NoAccessStr ELSE [AccCode] + '-' + [AccLatinName] END [AccLatinName],
			[EnNotes], [r].[acCurrencyPtr], [CurCardDeBIT], [CurCardCredit], r.[IsDetailAccount], 
			r.[EnAccSecurity], [MatName], [MatQuantity], [MatUnityName], [EnContraGuid], [EnBalFC], 
			CASE WHEN ac.acCode IS NULL THEN ''
				WHEN ac.acSecurity > @browseAccSec THEN @NoAccessStr 
				ELSE [ac].[acCode] + '-' + [ac].[acName] END [EnContraAccName],
			CASE WHEN ac.acCode IS NULL THEN ''
				WHEN ac.acSecurity > @browseAccSec THEN @NoAccessStr 
				ELSE [ac].[acCode] + '-' + [ac].[acLatinName] END [EnContraLatinAcc],
			ISNULL([DebitinCurr], 0) AS [DebitinCurr], ISNULL([CrerditinCurr], 0) AS [CrerditinCurr], 
			ISNULL([DebitinCurr], 0) - ISNULL([CrerditinCurr], 0) AS [CurCardBalance] 
		FROM 
			[#Result] AS [r]
			LEFT JOIN [vwAc] AS [ac] ON [ac].[acGUID] = [EnContraGuid]
			LEFT JOIN vwCu AS CU ON CU.cuGUID = r.EnCustomerGUID
		ORDER BY 
			[enNumer2], [enNumber], r.[IsDetailAccount], [CeDate], [CeNumber], [ac].[acCode], [EnDebit], [EnCredit]
	END       
	SELECT * FROM  [#SecViol] 
################################################################################
#END