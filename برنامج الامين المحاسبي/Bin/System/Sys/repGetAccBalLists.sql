##########################################################################
CREATE PROC repGetAccBalLists
	@StartDate	[DATETIME], 
	@EndDate	[DATETIME], 
	@AccGUID	[UNIQUEIDENTIFIER], 
	@CostGUID	[UNIQUEIDENTIFIER] = 0x0, 
	@CurGUID	[UNIQUEIDENTIFIER], 
	@CurVal		[FLOAT],
	@CustGUID	[UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON;
	
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

	INSERT INTO [#AccountsList] EXEC [prcGetAccountsList] @AccGUID, 0 
	-- Customers Table --------------------------------------------------------------- 
	CREATE TABLE [#CustTbl] ([GUID] [UNIQUEIDENTIFIER], [Security] [INT])

	DECLARE @HasCust INT
	set @HasCust = (SELECT COUNT(GUID) FROM cu000 WHERE AccountGUID = @AccGUID)

	IF(@HasCust > 0 )
		INSERT INTO  [#CustTbl] EXEC [dbo].[prcGetCustsList] @CustGUID, @AccGUID, 0x0	
	ELSE
	BEGIN 
		INSERT INTO  [#CustTbl] EXEC [dbo].[prcGetCustsList] @CustGUID, 0x0, 0x0
		INSERT INTO  [#CustTbl] SELECT 0x0, 0
	END	 	

	IF( @CurGUID = 0x0 ) 
	BEGIN 
		SET @CurGUID = (SELECT [myGUID] FROM [vwMy] WHERE [myNumber] = 1) 
		SET @CurVal = (SELECT [myCurrencyVal] FROM [vwMy] WHERE [myNumber] = 1) 
	END 

/*
	delete [#AccountsList] 
	from [#AccountsList] [l] inner join [ac000] [ac] on [ac].[guid] = [l].[guid]
	where [ac].[nsons] <> 0
*/

	CREATE TABLE [#Result] 
	( 
		[acGUID]			[UNIQUEIDENTIFIER], 
		[CostGUID]			[UNIQUEIDENTIFIER], 
		[Debit]				[FLOAT], 
		[Credit]			[FLOAT], 
		[CeSecurity]		[INT], 
		[AccSecurity]		[INT], 
		[UserSecurity]		[INT],
		[CustGUID]			[UNIQUEIDENTIFIER],
		[CustSecurity]		[INT] 
	) 

	CREATE TABLE [#FinalResult] 
	( 
		[acGUID]			[UNIQUEIDENTIFIER], 
		[CostGUID]			[UNIQUEIDENTIFIER], 
		[Debit]				[FLOAT], 
		[Credit]			[FLOAT],
		[CustGUID]			[UNIQUEIDENTIFIER]
	) 

	IF ISNULL( @CostGUID, 0x0) = 0x0
		INSERT INTO [#Result] 
			SELECT  
				[ac].[GUID],
				0x0,				
				[fn].[FixedEnDebit],
				[fn].[FixedEnCredit],
				[fn].[CeSecurity],
				--@UserSec 
				[fn].[AcSecurity],
				[fn].[CeSecurity],
				CASE WHEN @HasCust = 0 THEN CASE WHEN [vwcu].[cuAccount] = [fn].[acGUID] AND [vwcu].[cuGUID] = [fn].[enCustomerGUID] THEN [cu].[GUID] ELSE 0x0 END ELSE [cu].[GUID] END,
				[cu].[Security]
			FROM  
				[#AccountsList] AS [ac] 
				/*LEFT*/ INNER JOIN [fnExtended_En_Fixed]( @CurGUID) [fn] ON [fn].[acGUID] = [ac].[GUID] 
				INNER JOIN [#CustTbl] AS [cu] ON [cu].[GUID] = [fn].[enCustomerGUID]
				LEFT JOIN [vwCu] [vwcu] ON [vwcu].[cuAccount] = [fn].[acGUID]  AND [vwcu].[cuGUID] = [fn].[enCustomerGUID]

			WHERE 
				([fn].[EnDate] BETWEEN @StartDate AND @EndDate) -- OR ([FixedEnDebit] IS NULL)
	ELSE 
		INSERT INTO [#Result] 
			SELECT  
				[ac].[GUID],
				[fn].[enCostPoint],
				[fn].[FixedEnDebit],
				[fn].[FixedEnCredit],
				[fn].[CeSecurity],
				--@UserSec 
				[fn].[AcSecurity],
				[fn].[CeSecurity],
				CASE WHEN @HasCust = 0 THEN CASE WHEN [vwcu].[cuAccount] = [fn].[acGUID] AND [vwcu].[cuGUID] = [fn].[enCustomerGUID] THEN [cu].[GUID] ELSE 0x0 END ELSE [cu].[GUID] END,
				[cu].[Security]
			FROM  
				[#AccountsList] AS [ac] /*LEFT*/ 
				INNER JOIN [fnExtended_En_Fixed]( @CurGUID) [fn] ON [fn].[acGUID] = [ac].[GUID] 
				INNER JOIN [vwCo] [co] ON [co].[coGUID] = [fn].[enCostPoint]
				INNER JOIN [#CustTbl] AS [cu] ON [cu].[GUID] = [fn].[enCustomerGUID]
				LEFT JOIN [vwCu] [vwcu] ON [vwcu].[cuAccount] = [fn].[acGUID] AND [vwcu].[cuGUID] = [fn].[enCustomerGUID]
			WHERE 
				([fn].[EnDate] BETWEEN @StartDate AND @EndDate) AND [co].[coGUID] = @CostGUID -- OR ([FixedEnDebit] IS NULL)

	EXEC [prcCheckSecurity] @UserGUID 

	INSERT INTO [#FinalResult]
	SELECT 
		[acGUID], 
		[CostGUID],
		ISNULL( SUM( [Debit]), 0),
 		ISNULL( SUM( [Credit]), 0),
		[CustGUID]
	FROM 
		[#Result] 
	GROUP BY 
		[acGUID],
		[CustGUID],
		[CostGUID]

	SELECT * FROM [#FinalResult]
	
	SELECT  * FROM [#SecViol] 
/*
prcConnections_add2 'Œ«·œ' 
[repGetAccBalLists] '2014-01-01', '3/21/2014 23:59:59.998', '0ea930b7-5f44-4a36-814d-b0263f6f50e6', '00000000-0000-0000-0000-000000000000', 'fa36e398-bea5-40d1-81f0-2c73c78598f1', 1.000000
*/
###############################################################################
#END
