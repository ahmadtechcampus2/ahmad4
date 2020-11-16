#########################################################################
## ≈Ã—«¡ „‰ √Ã· Õ—ﬂ… ’‰œÊﬁ
## -----------------------------------------------------
CREATE PROCEDURE repCashActive  
				@AccGUID AS UNIQUEIDENTIFIER,-- ??? ??????  
				@CurGUID AS UNIQUEIDENTIFIER,-- ??????  
				@CurVal AS FLOAT,-- ???????  
				@Date AS DATETIME, -- ???????  
				@PrevGuid UNIQUEIDENTIFIER = 0X00				
AS 
	SET NOCOUNT ON 
	DECLARE @UserGUID UNIQUEIDENTIFIER, @UserSec INT
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	DECLARE @IsAdmin INT
	SET @IsAdmin = dbo.fnIsAdmin(@UserGUID)
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, DEFAULT)
	
	-- CREATE TABLE #EntryTbl( Type INT, Security INT)
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])
	CREATE TABLE #Result (
		[Number]		[INT],
		[GUID]			[UNIQUEIDENTIFIER],
		[Date]			[DATETIME],
		[ParentType]	[INT],
		[ParentNum]		[UNIQUEIDENTIFIER],
		[ceNotes]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[CurVal]		[FLOAT],
		[CurPtr]		[UNIQUEIDENTIFIER],
		[Post]			[INT],
		[State]			[INT],
		[Security]		[INT],
		[UserSecurity] 	[INT],
		[enNumber]		[INT],
		[enAccount]		[UNIQUEIDENTIFIER],
		enCustomerGUID	[UNIQUEIDENTIFIER],
		[enDebit]		[FLOAT],
		[enCredit]		[FLOAT],
		[enCurrencyVal]	[FLOAT],
		[enCurrencyPtr]	[UNIQUEIDENTIFIER],
		[enCostPtr]		[UNIQUEIDENTIFIER],
		[enClass]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[enDate]		[DATETIME],
		[enNotes] 		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[BrGuid]		[UNIQUEIDENTIFIER] DEFAULT 0X00,
		[enContraAcc] [UNIQUEIDENTIFIER],
		[acSecurity]	[BIT],
		[AccSecLevel]   [INT])
	
	IF (@PrevGuid <> 0X00)
			EXEC repCash_PrevBalance @AccGUID,@CurGUID,@CurVal,@Date,@PrevGuid
	
	INSERT INTO #Result 
		SELECT  DISTINCT
			[fn].[ceNumber],
			[fn].[ceGUID],
			[fn].[enDate],
			ISNULL( [er].[erParentType], 1),
			[er].[erParentGUID],
			[fn].[ceNotes],
			[fn].[ceCurrencyVal],
			[fn].[ceCurrencyPtr],
			[fn].[ceIsPosted],
			[fn].[ceState],
			[fn].[ceSecurity],
			@UserSec,
			[fn].[enNumber],
			[fn].[enAccount],
			[fn].[enCustomerGUID],
			[fn].[FixedEnDebit],
			[fn].[FixedEnCredit],
			[fn].[enCurrencyVal],
			[fn].[enCurrencyPtr],
			[fn].[enCostPoint],
			[fn].[enClass],
			[fn].[enDate],
			[fn].[enNotes],
			[fn].[ceBranch],
			[fn].[enContraAcc],
			CASE @IsAdmin 
				WHEN 0 THEN 
					CASE WHEN [ac].[Security] <= @UserSec THEN 0 ELSE 1 END 
				ELSE 1 END,
			[ac].[Security]
		FROM  
			[dbo].[fnCeEn_Fixed]( @CurGUID) As fn
			INNER JOIN [vwCeEn] as [ce] ON [fn].[ceGUID] = [ce].[ceGUID]
			LEFT  JOIN vwEr As er ON fn.ceGUID = er.erEntryGuid
			INNER JOIN ac000 AS ac ON fn.enAccount = ac.Guid
		WHERE [ce].[enAccount] =  @AccGUID 
		AND CONVERT(date, [ce].[enDate]) = @Date 
	
	EXEC [prcCheckSecurity] @UserGUID
	
	UPDATE #Result SET
		 [enClass] = (SELECT MAX ([enClass])FROM [#Result] [B] WHERE [B].[GUID]=[A].[GUID] AND [A].[enDebit] = [B].[enCredit] AND A.enCredit =B.enDebit  )
		FROM #RESULT A
	
	SELECT * FROM #Result ORDER BY Number,[BrGuid]
	SELECT * FROM #SecViol
#########################################################################
## ≈Ã—«¡ ·≈Õ÷«— «·—’Ìœ «·”«»ﬁ
## -----------------------------------------------------
CREATE PROCEDURE repCash_PrevBalance
		@AccGUID UNIQUEIDENTIFIER,
		@CurGUID	UNIQUEIDENTIFIER,
		@CurVal	FLOAT,
		@ToDate	DATETIME,
		@PrevGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserSec [INT],@Balance	FLOAT
	SET @UserGUID = dbo.fnGetCurrentUserGUID()
	SET @UserSec = dbo.fnGetUserEntrySec_Browse( @UserGUID, NULL)
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])
	CREATE TABLE #t_Result (
		[Security]		[INT],
		[UserSecurity] 	[INT],
		[Balance]		[FLOAT])

		INSERT INTO #t_Result
			SELECT
				[ceSecurity],
				@UserSec,
				SUM([FixedEnDebit] - [FixedEnCredit])
			FROM
				[dbo].[fnCeEn_Fixed]( @CurGUID) 
			WHERE
				[enAccount] =  @AccGUID
				AND [enDate] < @ToDate
			GROUP BY  [ceSecurity]

	EXEC [prcCheckSecurity] @UserGUID,@Result = '#t_Result'
	SELECT @Balance = ISNULL( SUM( [Balance]), 0) FROM #t_Result
	INSERT INTO #RESULT([Number],[GUID],[ParentType],enDebit,enCredit,[enAccount],[Date])
		VALUES(-1,@PrevGuid,1,CASE WHEN @Balance > 0 THEN @Balance ELSE 0 END,CASE WHEN @Balance < 0 THEN -@Balance ELSE 0 END,@AccGUID,DATEADD(dd,-1,@ToDate))
#########################################################################
#END