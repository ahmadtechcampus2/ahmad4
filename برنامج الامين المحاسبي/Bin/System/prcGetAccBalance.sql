CREATE PROCEDURE prcGetAccBalance
	@StartDate	[DATETIME], 
	@EndDate	[DATETIME], 
	@AccGUID	[UNIQUEIDENTIFIER], 
	@CurGUID	[UNIQUEIDENTIFIER], 
	@CurVal		[FLOAT], 
	@ContraAcc	[UNIQUEIDENTIFIER] = 0x0,
	@ShowUnPostedEnt [INT] = 1  
AS 
	SET NOCOUNT ON 
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserSec [INT], @RecCnt [INT] 
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	-- User Security on entries 
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT) 
	-- Security Table ------------------------------------------------------------ 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	-- Accounts Table --------------------------------------------------------------- 
	CREATE TABLE [#AccountsList] 
	( 
		[GUID] [UNIQUEIDENTIFIER], 
		[Security] [INT], 
		[level]	 [INT] 
	) 
	INSERT INTO [#AccountsList] EXEC [prcGetAccountsList] @AccGUID,0 
	IF( @CurGUID = 0x0 ) 
	BEGIN 
		SET @CurGUID = (select [acCurrencyPtr] from [vwAc] WHERE [acGUID] = @AccGUID) 
		SET @CurVal = (select [acCurrencyVal] from [vwAc] WHERE [acGUID] = @AccGUID) 
	END 
	CREATE TABLE [#Result] 
	( 
		[acGUID]			[UNIQUEIDENTIFIER], 
		[Debit]				[FLOAT], 
		[Credit]			[FLOAT], 
		[CeSecurity]		[INT], 
		[AccSecurity]		[INT], 
		[UserSecurity]		[INT] 
	) 
	INSERT INTO [#Result] 
		SELECT  
			[acGUID], 
			[FixedEnDebit], 
			[FixedEnCredit], 
			[CeSecurity], 
			[AcSecurity], 
			@UserSec 
		FROM  
			[fnExtended_En_Fixed](@CurGUID) 
			INNER JOIN [#AccountsList] AS [ac] ON [acGUID] = [ac].[GUID] 
		WHERE 
			[EnDate] BETWEEN @StartDate AND @EndDate                
			AND( (@ContraAcc = 0x0) OR ([enContraAcc] = @ContraAcc) ) 
			AND ([ceIsPosted] = 1 OR @ShowUnPostedEnt = 1)
		 
	SET @RecCnt = @@ROWCOUNT 
	EXEC [prcCheckSecurity] @UserGUID 
	IF( @RecCnt = 0 ) 
	BEGIN 
		SELECT  
			[Debit],[Credit] 
		FROM  
			[#Result] 
	END 
	ELSE 
	BEGIN 
		SELECT 
			SUM([Debit]) AS [Debit], SUM([Credit]) AS [Credit] 
		FROM  
			[#Result] 
	END 
	SELECT  * FROM [#SecViol] 
	DROP Table [#Result] 
	DROP Table [#SecViol] 
--*/ 
/* 
exec prcGetAccBalance 
'1/1/2001',--	@StartDate	DATETIME, 
'10/2/2004',--	@EndDate	DATETIME, 
'B73854F2-A624-4CE4-9CB7-15F8784AA0CA',--	@AccGUID	UNIQUEIDENTIFIER, 
'C5439BB7-977A-4325-BB6B-B6AC409CFA2D',--	@CurGUID	UNIQUEIDENTIFIER, 
1,--	@CurVal		FLOAT 
0x0 
*/ 
