###############################################################################
CREATE PROCEDURE repAccDebitCreditMonthlyTree 
	@AccGUID				[UNIQUEIDENTIFIER],
    @CostGuid				[UNIQUEIDENTIFIER] = 0X0,
    @StartDate				[DATETIME],
    @EndDate				[DATETIME],
    @CurrencyGUID			[UNIQUEIDENTIFIER],
    @CurrencyVal			[FLOAT],
    @SrcGuid				[UNIQUEIDENTIFIER] = 0X0,
    @Str					[NVARCHAR](max) = '',
    @Lang					[BIT] = 0,
    @PostedVal				[INT] = -1,-- 1 posted or 0 unposted -1 all posted & unposted
    @MaxLevel				[INT] = 0,
    @ShowEmptyAcc			[BIT] = 0,
    @ShowBaseAcc			[BIT] = 0,
    @ShowComposeAcc			[BIT] = 0,
	@CustomerGUID			[UNIQUEIDENTIFIER] = 0X0,
	@DetailOnlyAccCustomers	BIT = 0,
	@DetailByCustomer		BIT = 0
AS
	SET NOCOUNT ON 
	
	DECLARE @SecViol_IsLocal [BIT]

	IF [dbo].[fnObjectExists]('#SecViol') = 0 
	BEGIN
		SET @SecViol_IsLocal = 1
      END
    ELSE
		SET @SecViol_IsLocal = 0 

    DECLARE @PDate TABLE
      (
         [StartDate] [DATETIME] DEFAULT '1/1/1980',
         [EndDate]   [DATETIME]
      )
	  
	CREATE TABLE [#CostTbl]([CostGUID] [UNIQUEIDENTIFIER])
	INSERT INTO [#CostTbl] SELECT * FROM dbo.fnGetCostsList(@CostGuid)
	IF @CostGUID = 0x0
		INSERT INTO [#CostTbl] VALUES(0x0) 

    INSERT INTO @PDate
    SELECT *
    FROM   [fnGetStrToPeriod](@STR)

    CREATE TABLE [#AccTable]
      (
         [Guid]  [UNIQUEIDENTIFIER],
         [Level] [INT],
         [Path]  NVARCHAR(2000)
      )

    INSERT INTO [#AccTable]
    SELECT *
    FROM   dbo.fnGetAccountsList(@AccGuid, 1)

	IF @AccGuid = 0x0
      INSERT INTO [#AccTable]
                  (GUID,
                   Level)
      VALUES      (0x0,
                   0)
		
    DECLARE @Level     [INT],
			@ZeroValue [FLOAT],  
            @MinLevel  [INTEGER],
            @Cnt       [INT]

	SET @ZeroValue = [dbo].[fnGetZeroValuePrice](); 

	CREATE TABLE [#EndResult]
	( 
		[ceGUID]        [UNIQUEIDENTIFIER],--this field is important to multi years to exclude entries
		[enDate]        [DATETIME],
		[acGUID]        [UNIQUEIDENTIFIER],
		[enCostPoint]   [UNIQUEIDENTIFIER],
		[acName]        [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acCode]        [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acParentGuid]  [UNIQUEIDENTIFIER],
		[acType]        [INT],
		[acNSons]       [INT],
		[acNumber]      [INT],
		[acLevel]       [INT],
		[acPath]        NVARCHAR(2000),
		[FixedEnDebit]  [FLOAT],
		[FixedEnCredit] [FLOAT],
		[PrevDebit]     [FLOAT] DEFAULT 0,
		[PrevCredit]    [FLOAT] DEFAULT 0,
		[TotalDebit]    [FLOAT] DEFAULT 0,
		[TotalCredit]   [FLOAT] DEFAULT 0,
		[haveBalance]   [INT],-- null indicates empty account while 0 indicates balanced account, and 1 not balanced
		[ceSecurity]    [INT],
		[acSecurity]    [INT],
		[ceIsPosted]    [INT],
		[CustomerGUID]	[UNIQUEIDENTIFIER]
	) 

		--«·‘Ã—… ﬂ«„·…
	INSERT INTO [#EndResult](
		[acGUID],
		[acCode],
		[acName],
		[acParentGUID],
		[acType],
		[acNumber],
		[acNSons],
		[acLevel],
		[acPath],
		[acSecurity],
		[enDate],
		[ceGUID],
		[ceSecurity],
		[enCostPoint],
		[FixedEnDebit],
		[FixedEnCredit],
		[ceIsPosted],
		[CustomerGUID])
	SELECT 
		[ac].[GUID],
		[Code],
			CASE @Lang
				WHEN 0 THEN [Name]
				ELSE
				CASE [LatinName]
					WHEN '' THEN [Name]
					ELSE [LatinName]
				END
			END,
		[ac2].[ParentGuid],
		[Type],
		[Number],
		[ac2].[NSons],
		[Level],
		[Path],
		[AC2].[Security],
		[enDate],
		[ceGUID],
		[ceSecurity],
		[enCostPoint],
		dl.[FixedEnDebit],
		dl.[FixedEnCredit],
		[ceIsPosted],
		dl.enCustomerGUID
	FROM   [#AccTable] [ac]
			FULL JOIN [dbo].[fnExtended_En_Fixed_src](@SrcGuid, @CurrencyGUID) dl
					ON [ac].[GUID] = [AcGUID]
			INNER JOIN ac000 AS [AC2]
					ON [ac2].[guid] = [ac].[GUID]
			LEFT JOIN [#CostTbl] AS [co]
					ON [co].[CostGUID] = [enCostPoint]
	WHERE 
		(@CostGuid = 0x0
		OR 
		([Type] != 1)
		OR 
		(([Type] = 1) AND ([co].[CostGUID] IS NOT NULL)))
		AND
		((@CustomerGUID = 0x0) OR ((dl.enCustomerGUID = @CustomerGUID) OR (dl.enCustomerGUID IS NULL)))

	--Õ–› «·Õ”«»«  «·Œ «„Ì… Ê «· Ê“Ì⁄Ì… „‰ «·‘Ã—…
	DELETE FROM #EndResult
	WHERE  acType = 8
			OR acType = 2

	--  „—«⁄«… „’«œ— «· ﬁ—Ì—
	DELETE FROM #EndResult
	WHERE  [acType] = 1
			AND ( @PostedVal <> -1
					AND [ceIsPosted] <> @PostedVal )

	--«·›· —… ⁄·Ï „—ﬂ“ «·ﬂ·›…
	--DELETE FROM #EndResult 
	--   WHERE  
	--[acType] = 1
	--          AND ( enCostPoint <> @CostGuid
	--                AND @CostGuid <> 0x0 )

	-- check security
	EXEC [prcCheckSecurity]
		@result = '#EndResult'

	--Õ”«» «·„œÌ‰ Ê «·œ«∆‰ Œ·«·  «·› —… «·„ÿ·Ê»… »«· ﬁ—Ì—
	CREATE TABLE [#MainRes]
	(
			[acGUID]		[UNIQUEIDENTIFIER],
			[acName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[acCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[StartDate]		[DATETIME] DEFAULT '1/1/1980',
			[TotalDebit]	[FLOAT],
			[TotalCredit]	[FLOAT],
			[enDate]		[DATETIME],
			[acPath]		NVARCHAR(2000),
			CustomerGUID	[UNIQUEIDENTIFIER]	
	) 

	--·Õ”«» «·„œÌ‰ Ê «·œ«∆‰ «·”«»ﬁÌ‰
	CREATE TABLE [#PrevRes]
	( 
			[acGUID]		[UNIQUEIDENTIFIER],
			[acName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[acCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[StartDate]		[DATETIME] DEFAULT '1/1/1980',
			[PrevDebit]		[FLOAT],
			[PrevCredit]	[FLOAT],
			CustomerGUID	[UNIQUEIDENTIFIER]
	)
	
	IF @DetailByCustomer = 0
	BEGIN 
		IF @DetailOnlyAccCustomers = 1
		BEGIN 
			UPDATE e
			SET CustomerGUID = 0x0
			FROM 
				[#EndResult] e
				INNER JOIN ac000 ac ON ac.GUID = e.[acGUID]
				LEFT JOIN cu000 cu ON cu.GUID = e.CustomerGUID AND cu.AccountGUID = e.[acGUID]
			WHERE 
				(cu.GUID IS NULL) 
				AND 
				(e.CustomerGUID != 0x0)
		END ELSE 
			UPDATE [#EndResult]
			SET CustomerGUID = 0x0
			WHERE 
				CustomerGUID != 0x0
	END 

	INSERT INTO [#MainRes] (
		[acGUID],
		[acName], 
		[acCode], 
		[StartDate], 
		[TotalDebit], 
		[TotalCredit],
		[enDate],
		[acPath],
		CustomerGUID)
	SELECT 
		[acGUID],
		[acName], 
		[acCode], 
		[p].[StartDate],
		Sum(r.[FixedEnDebit]),
		Sum(r.[FixedEnCredit]),
		[enDate],
		[acPath],
		CustomerGUID
	FROM   
		[#EndResult] AS [r]
		INNER JOIN @PDate AS [p]
			ON [r].[enDate] BETWEEN [p].[STARTDATE] AND [p].[ENDDATE]
	WHERE [enDate] BETWEEN @StartDate AND @EndDate
	GROUP BY 
		[acGUID],
		Month([r].[enDate]),
		[acName], 
		[acCode],
		[enDate],
		[acPath],
		[p].[StartDate],
		CustomerGUID
	
	INSERT INTO [#PrevRes] (
		[acGUID],
		[acName], 
		[acCode],
		[StartDate],
		[PrevDebit], 
		[PrevCredit],
		CustomerGUID)
	SELECT 
		[acGUID],
		[acName], 
		[acCode],
		[enDate],
		Sum([FixedEnDebit]),
		Sum([FixedEnCredit]),
		CustomerGUID
	FROM   [#EndResult]
	WHERE  [enDate] < @StartDate
	GROUP BY 
		[acGUID],
		[acName], 
		[acCode],
		[enDate],
		CustomerGUID
	
	-- ÕœÌÀ  ”ÿÊ— «·Õ”«» «·„ Õ—ﬂ ⁄œ… Õ—ﬂ«  »«·‘Â— ‰›”Â »ﬁÌ„… «·„Ã„Ê⁄
	UPDATE #EndResult
	SET    [TotalDebit] = ISNULL([r].[TotalDebit], 0),
			[TotalCredit] = ISNULL([r].[TotalCredit], 0),
			[PrevDebit] = 0,
			[PrevCredit] = 0
	FROM   #EndResult [e]
			INNER JOIN (SELECT acGuid, CustomerGUID,
								Sum(er.[FixedEnDebit])  [TotalDebit],
								Sum(er.[FixedEnCredit]) [TotalCredit],
								DAY(enDate)				DayDate,
								Month(enDate)           MothenDate,
								Year(endate)            YearenDate
						FROM   [#EndResult] AS [er]
								INNER JOIN @PDate AS [p]
										ON [er].[enDate] BETWEEN [p].[STARTDATE] AND [p].[ENDDATE]
						GROUP  BY [acGuid], CustomerGUID,
									DAY([enDate]),
									Month([enDate]),
									Year(endate))[r]
					ON 
						e.[acGUID] = [r].[acGUID]
						AND e.CustomerGUID = r.CustomerGUID
						AND DAY(e.endate) = r.DayDate
						AND Month(e.endate) = r.MothenDate
						AND Year(endate) = r.YearenDate
			
	
	IF EXISTS(SELECT * FROM #PrevRes)
		UPDATE #EndResult 
		SET PrevCredit = pre.PrevCredit,
			PrevDebit = pre.PrevDebit
		FROM #EndResult AS en 
		INNER JOIN (SELECT 
						SUM(PrevCredit) AS PrevCredit,
						SUM(PrevDebit) AS PrevDebit,
						acGUID,
						StartDate 
					FROM #PrevRes
					GROUP BY 
						acGUID,
						StartDate) AS Pre ON Pre.acGUID = en.acGUID AND pre.StartDate = en.enDate
		WHERE en.enDate < @StartDate

	UPDATE [#EndResult]     
	SET    [haveBalance] = CASE
								WHEN Abs(( [TotalDebit] + [PrevDebit] ) - ( [TotalCredit] + [PrevCredit] )) < @ZeroValue
									AND ( [TotalDebit] + [PrevDebit] ) + ( [TotalCredit] + [PrevCredit] ) > @ZeroValue THEN 0
								WHEN Abs(( [TotalDebit] + [PrevDebit] ) - ( [TotalCredit] + [PrevCredit] )) > @ZeroValue
									AND ( [TotalDebit] + [PrevDebit] ) + ( [TotalCredit] + [PrevCredit] ) > @ZeroValue THEN 1
								ELSE NULL
							END
	--Delete duplicated rows
	;

	WITH CTE
			AS (SELECT r.*,
					RN = ROW_NUMBER()
							OVER(
								PARTITION BY acGuid, CustomerGUID, DAY(enDate), Month([endate]), Year([enDate])
								ORDER BY endate, acGuid, CustomerGUID)
				FROM   #EndResult r)

	DELETE FROM CTE
	WHERE RN > 1;

	--fill parentguid from ci000 for composite accounts
	IF @ShowComposeAcc = 1 
	BEGIN
		UPDATE r
		SET    [acParentGUID] = [parentGUID]
		FROM   [#EndResult] [r]
				INNER JOIN ci000 [ci]
						ON [ci].[songuid] = [r].[acguid]
		WHERE  [acGuid] IN (SELECT [SonGUID]
							FROM   ci000)
	END

	--update levels
	DECLARE @UserGuid [UNIQUEIDENTIFIER] = [dbo].[fnGetCurrentUserGUID]() 
	   
	DELETE [#EndResult]
	WHERE  [acSecurity] > [dbo].[fnGetUserAccountSec_Browse](@UserGuid)

	SET @Level = @@RowCount  

	IF EXISTS(SELECT *
				FROM   [#SecViol]
				WHERE  [Type] = 5)
		INSERT INTO [#SecViol]
		VALUES     (@Level,
					5)

		IF @ShowBaseAcc = 1 
		BEGIN  
			WHILE @Level > 0  
			BEGIN  
				UPDATE [r] 
				SET    [acLevel] = [r].[acLevel] - 1,
					[acParentGUID] = [ac].[ParentGUID]  
				FROM   [#EndResult] AS [r]
						INNER JOIN [ac000] AS [ac]
								ON [r].[acParentGUID] = [ac].[Guid]
						LEFT JOIN [#EndResult] AS [r1]
								ON [r1].[acGUID] = [ac].[Guid]
				WHERE  ISNULL([r].[acParentGUID], 0X00) <> @AccGuid
						AND [r].[acGUID] <> @AccGuid
						AND [r].[acLevel] <> ( ISNULL([r1].[acLevel], -2) + 1 )
				
				SET @Level = @@RowCount  
			END  
		END 
		
		IF @AccGuid IN (SELECT [GUID]
						FROM   [AC000]
						WHERE  [Type] = 4)
		BEGIN  
			  SET @Cnt = (SELECT Count(*)
						  FROM   [#EndResult]
						  WHERE  [acType] = 4)
		
			WHILE @Cnt > 0  
			BEGIN  
				UPDATE [#EndResult] 
					SET    [acLEVEL] = [acLEVEL] - 1
					WHERE  [acGUID] IN (SELECT [SonGuid]
										FROM   ci000 [ci]
											   INNER JOIN [#EndResult] [b]
													   ON [b].[acGuid] = [ci].[ParentGuid]
										WHERE  [b].[acLevel] >= @Cnt - 1)
							OR [acGUID] IN (SELECT [acGUID]
											FROM   [#EndResult] [er]
											WHERE  [er].[acParentGUID] IN (SELECT [SonGuid]
																		   FROM   ci000 [A]
																				  INNER JOIN [#EndResult] [b]
																						  ON b.[acGuid] = [a].[ParentGuid]
																		   WHERE  [b].[acLevel] >= @Cnt - 1))

				SET @Cnt = @Cnt - 1
			END 
		END
	 
		IF @ShowBaseAcc = 1 OR @ShowComposeAcc = 1
		BEGIN  
			  SET @Level = (SELECT Max([acLevel])
							FROM   [#EndResult])

			WHILE @Level >= 0   
			BEGIN 
						INSERT INTO #EndResult
						SELECT Father.ceGuid,
							   Cast(Cast(sons.YearenDate AS VARCHAR) + '-'
									+ Cast(sons.MothenDate AS VARCHAR) + '-'
									+ Cast(1 AS VARCHAR) AS DATETIME),
						Father.acGuid,
						Father.enCostPoint,
						Father.acName,
						Father.acCode,
						Father.acParentGuid,
						Father.acType,
						Father.acNsons,
						Father.acNumber,
						Father.acLevel,
						Father.acPath,
						Father.FixedEnDebit,
						Father.FixedEnCredit,
						sons.PrevDebit,
						sons.PrevCredit,
						sons.[TotalDebit],
						sons.[TotalCredit],
						sons.SumHaveBalance,
						Father.ceSecurity,
						Father.acSecurity,
						Father.[ceIsPosted],
						0x0 -- CustomerGUID 
						FROM   #EndResult [Father]
							   INNER JOIN (SELECT [acParentGuid],
												  Sum(er.[TotalDebit])  [TotalDebit],
												  Sum(er.[TotalCredit]) [TotalCredit],
												  Sum(er.PrevDebit)     [PrevDebit],
												  Sum(er.PrevCredit)    [PrevCredit],
												  Sum([haveBalance])    [SumHaveBalance],
												  Month(enDate)         MothenDate,
												  Year(endate)          YearenDate
										   FROM   [#EndResult] AS [er]
										   WHERE  [acLevel] = @Level
												  AND [haveBalance] IS NOT NULL
										   GROUP  BY [acParentGuid],
													 Month([enDate]),
													 Year(endate))[sons] --sum of sons
						ON [Father].[acGUID] = [sons].[acParentGUID] 

					SET @Level = @Level - 1  
				END  
			END 
	
	IF @ShowComposeAcc = 1 AND @ShowBaseAcc = 0
	BEGIN
		--update parent to grandparent
		UPDATE r
		SET    [r].[acParentGUID] = [ci].[parentGUID]
		FROM   #EndResult [r]
				INNER JOIN ci000 [ci]
						ON [ci].[songuid] = [r].[acParentGuid]
				INNER JOIN ac000 [ac]
						ON [ac].[guid] = [ci].[SonGUID]
		WHERE  [r].[acParentGuid] IN (SELECT SonGUID
									FROM   ci000)
				AND [ac].[Type] <> 4
				AND [r].[acNSONS] = 0
	END

	--Õ–› «·Õ—ﬂ«  Œ«—Ã «·› —… «·„ÿ·Ê»…
	DELETE FROM #EndResult
	WHERE  enDate > @EndDate
		AND acNSons = 0
	
	IF @showcomposeAcc = 0
	BEGIN 
		DELETE FROM [#EndResult]
		WHERE [AcType] = 4
	END

	IF @ShowEmptyAcc = 0 
	BEGIN 
		DELETE r 
		FROM   [#EndResult] [r]
		WHERE  
			[haveBalance] IS NULL
			AND [enDate] IS NULL 
	END

	--return result
	SELECT 
		[e].[acGUID] 								AS [RecordGUID],
		[e].[acGUID] 								AS [acNumber],
		[e].[acName] 								AS [acName],    
		[e].[acCode] 								AS [acCode],  
		[e].[acType] 								AS [acType],
		[e].[acNSons] 								AS [acNSons],
		[e].[acPath]								AS [acPath],
		[e].[TotalDebit] 							AS [enTotalDebit],   
		[e].[TotalCredit] 							AS [enTotalCredit],
		[e].[PrevDebit] 							AS [enPrevDebit],   
		[e].[PrevCredit] 							AS [enPrevCredit],
		[e].[endate]								AS [enDate],
		[e].[acParentGuid]							AS [acParentGuid],
		[e].CustomerGUID							AS [CustomerGUID],
		ISNULL(cu.CustomerName, '')					AS [CustomerName],
		ISNULL(cu.LatinName, '')					AS [CustomerLatinName]
	FROM   
		[#EndResult] [e]
		LEFT JOIN [cu000] cu ON cu.GUID = e.CustomerGUID 
	WHERE  
		(([acLevel] < @MaxLevel AND @ShowBaseAcc = 1) OR @MaxLevel = 0 OR @ShowBaseAcc = 0)--   „ „⁄«·Ã… «·„” ÊÏ ›ﬁÿ »Õ«·… ŸÂÊ— «·Õ”«»«  «·—∆Ì”Ì… 
		AND (@ShowBaseAcc = 1 OR  [acNSons] = 0)  
	ORDER BY
		[acPath]
#########################################################
#END