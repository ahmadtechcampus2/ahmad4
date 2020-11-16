###########################################################################
CREATE PROCEDURE repCustActiveByEntry
	@AccPtr 	[UNIQUEIDENTIFIER],			--Customers Acc
	@StartDate	[DATETIME],
	@EndDate 	[DATETIME],
	@CurGUID 	[UNIQUEIDENTIFIER],
	@SrcGuid	[UNIQUEIDENTIFIER],
	@CostGUID 	[UNIQUEIDENTIFIER],
	@Class	 	[NVARCHAR](255),
	@CustCond	[UNIQUEIDENTIFIER] = 0X00,
	@CustGUID	[UNIQUEIDENTIFIER]
AS
	/*
	This proceddure
		- returns Customers Balance According To Entry Type
	*/
	SET NOCOUNT ON; 
	DECLARE
		@UserGUID		[UNIQUEIDENTIFIER],
		@UserEntrySec	[INT],
		@NormalEntry	[INT]
	DECLARE @Sec INT 
	SET @Sec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](),0X00) 
	
	CREATE TABLE [#SecViol]		( [Type] [INT], [Cnt] [INT])
	CREATE TABLE [#AccTbl]		( [Acc] [UNIQUEIDENTIFIER])
	CREATE TABLE [#CostTbl]		( [Cost] [UNIQUEIDENTIFIER], [CostSec] [INT])
	CREATE TABLE [#CustTbl]		( [CustPtr] [UNIQUEIDENTIFIER], [CustSec] [INT])
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#NotesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#ClctNotesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#Result](
		[CustGUID]		[UNIQUEIDENTIFIER],
		[CustSecurity]	[INT],
		[CostGUID] 		[UNIQUEIDENTIFIER],
		[Security]		[INT],
		[User_Security]	[INT], 
		[Balance]		[FLOAT],
		[TypeGUID]		[UNIQUEIDENTIFIER],
		[SubId]			[INT],
		[TypeName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[TypeLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[IsManualEntry]	[BIT])
	-- fill the variable with data
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	SET @NormalEntry = [dbo].[fnIsNormalEntry]( @SrcGuid) -- , @UserGUID)
	SET @UserEntrySec = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, DEFAULT)

	INSERT INTO [#AccTbl] SELECT [GUID] From [dbo].[fnGetAcDescList]( @AccPtr)
	INSERT INTO [#CustTbl] EXEC [dbo].[prcGetCustsList] @CustGUID, @AccPtr, @CustCond
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#ClctNotesTbl] EXEC [prcGetCollectNotesTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	INSERT INTO [#Result]
	SELECT
		[cu].[cuGUID],
		ISNULL( [cuSecurity], 0),
		[co].[Cost],
		[ceSecurity],
		@UserEntrySec,
		[FixedEnDebit] - [FixedEnCredit],
		[ch].[chType], 
		[er].[erParentType],
		nt.ntName,
		nt.ntLatinName,
		0
	FROM
		[dbo].[fnExtended_En_Fixed]( @CurGUID) AS [f]
		INNER JOIN [#AccTbl] AS [Ac] ON [Ac].[Acc] = [f].[enAccount]
		INNER JOIN [vwEr] AS [er] ON [f].[ceGuid] = [er].[erEntryGuid]
		INNER JOIN [vwch] AS [ch] ON [er].[erParentGuid] = [ch].[chGuid]
		INNER JOIN [#NotesTbl] AS [t] ON [ch].[chType] = [t].[Type]
		INNER JOIN vwnt nt ON nt.ntGUID = t.Type
		INNER JOIN [#CustTbl] AS [cust] ON [cust].[CustPtr] = [f].[enCustomerGUID]		
		INNER JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [f].[enCustomerGUID] AND [cu].[cuAccount] = [f].[enAccount]
		LEFT JOIN [#CostTbl] AS [co] ON [co].[Cost] = [f].[enCostPoint]
	WHERE
		[er].[erParentType] = 5 AND
		(( @Class = '') OR ( [f].[enClass] = @Class))AND
		(( ISNULL( @CostGUID, 0x0) = 0x0) OR ( EXISTS( SELECT [Cost] From [#CostTbl] WHERE [f].[enCostPoint] = [Cost])))AND
		(( ISNULL( @CustCond, 0X0) = 0X0) OR ( EXISTS( SELECT [CustPtr] From [#CustTbl] WHERE [cu].[cuGUID] = [CustPtr])))AND
		[enDate] BETWEEN @StartDate AND @EndDate
	-- 	INSERT ENTRY MOVE OF COLLECT NOTES
	INSERT INTO [#Result]
	SELECT
		[cu].[cuGUID],
		ISNULL( [cuSecurity], 0),
		[co].[Cost],
		[ceSecurity],
		@UserEntrySec,
		[FixedEnDebit] - [FixedEnCredit],
		[ch].[chType],
		[er].[erParentType],
		nt.ntName,
		nt.ntLatinName,
		0
	FROM
		[dbo].[fnExtended_En_Fixed]( @CurGUID) AS [f]
		INNER JOIN [#AccTbl] AS [Ac] ON [Ac].[Acc] = [f].[enAccount]
		INNER JOIN [vwEr] AS [er] ON [f].[ceGuid] = [er].[erEntryGuid]
		INNER JOIN [vwch] AS [ch] ON [er].[erParentGuid] = [ch].[chGuid]
		INNER JOIN [#ClctNotesTbl] AS [t] ON [ch].[chType] = [t].[Type]
		INNER JOIN vwnt nt ON nt.ntGUID = t.Type
		INNER JOIN [#CustTbl] AS [cust] ON [cust].[CustPtr] = [f].[enCustomerGUID]
		INNER JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [f].[enCustomerGUID] AND [cu].[cuAccount] = [f].[enAccount]
		LEFT JOIN [#CostTbl] AS [co] ON [co].[Cost] = [f].[enCostPoint]
	WHERE
		[er].[erParentType] = 6 AND
		(( @Class = '') OR ( [f].[enClass] = @Class))AND
		(( ISNULL( @CostGUID, 0x0) = 0x0) OR ( EXISTS( SELECT [Cost] From [#CostTbl] WHERE [f].[enCostPoint] = [Cost])))AND
		(( ISNULL( @CustCond , 0x0) = 0x0) OR ( EXISTS( SELECT [CustPtr] From [#CustTbl] WHERE [cu].[cuGUID] = [CustPtr])))AND
		[enDate] BETWEEN @StartDate AND @EndDate
	-- 	INSERT ENTRY MOVE OF Payment
	INSERT INTO [#Result]
	SELECT
		[cu].[cuGUID],
		ISNULL( [cuSecurity], 0),	
		[co].[Cost],
		--ISNULL( CostSec, 0),
		[ceSecurity],
		@UserEntrySec,
		[FixedEnDebit] - [FixedEnCredit],
		[py].[TypeGuid],
		[er].[erParentType],
		[et].etName,
		[et].etLatinName,
		0
	FROM
		[dbo].[fnExtended_En_Fixed]( @CurGUID) AS [f]
		INNER JOIN [#AccTbl] AS [Ac] ON [Ac].[Acc] = [f].[enAccount]
		INNER JOIN [vwEr] AS [er] ON [f].[ceGuid] = [er].[erEntryGuid]
		INNER JOIN [Py000] AS [py] ON [er].[erParentGuid] = [py].[Guid]
		INNER JOIN [#EntryTbl] AS [t] ON [py].[TypeGuid] = [t].[Type]
		INNER JOIN vwet et ON et.etGUID = t.Type
		INNER JOIN [#CustTbl] AS [cust] ON [cust].[CustPtr] = [f].[enCustomerGUID]		
		INNER JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [f].[enCustomerGUID] AND [cu].[cuAccount] = [f].[enAccount]
		LEFT JOIN [#CostTbl] AS [co] ON [co].[Cost] = [f].[enCostPoint]
	WHERE
		(( @Class = '') OR ( [f].[enClass] = @Class))AND
		(( ISNULL( @CostGUID, 0x0) = 0x0) OR ( EXISTS( SELECT [Cost] From [#CostTbl] WHERE [f].[enCostPoint] = [Cost])))AND
		(( ISNULL( @CustCond, 0x0) = 0x0) OR ( EXISTS( SELECT [CustPtr] From [#CustTbl] WHERE [cu].[cuGUID] = [CustPtr])))AND
		[enDate] BETWEEN @StartDate AND @EndDate
		AND [f].[ceSecurity] <= ISNULL([t].[Security],@Sec)
	-- 	INSERT Normal Entry Move
	IF( @NormalEntry <> 0)
	BEGIN
		INSERT INTO [#Result]
		SELECT
			[cu].[cuGUID],
			ISNULL( [cuSecurity], 0),
			[co].[Cost],
			--ISNULL( CostSec, 0),
			[ceSecurity],
			@UserEntrySec,
			[FixedEnDebit] - [FixedEnCredit],
			0x0,
			0,
			'',
			'',
			1
		FROM
			[dbo].[fnExtended_En_Fixed]( @CurGUID) AS [f]
			INNER JOIN [#AccTbl] AS [Ac] ON [Ac].[Acc] = [f].[enAccount]
			INNER JOIN [#CustTbl] AS [cust] ON [cust].[CustPtr] = [f].[enCustomerGUID]
			INNER JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [f].[enCustomerGUID] AND [cu].[cuAccount] = [f].[enAccount]
			LEFT JOIN [#CostTbl] AS [co] ON [co].[Cost] = [f].[enCostPoint]
			--LEFT JOIN vwEr AS er ON f.ceGuid = er.erEntryGuid
		WHERE
			ISNULL ( [ceTypeGuid], 0x0) = 0x0 AND 
			(( @Class = '') OR ( [f].[enClass] = @Class))AND
			(( ISNULL( @CostGUID, 0x0) = 0x0) OR ( EXISTS( SELECT [Cost] From [#CostTbl] WHERE [f].[enCostPoint] = [Cost])))AND
			(( ISNULL( @CustCond, 0x0) = 0x0) OR ( EXISTS( SELECT [CustPtr] From [#CustTbl] WHERE [cu].[cuGUID] = [CustPtr])))AND
			[enDate] BETWEEN @StartDate AND @EndDate
	END
	EXEC [prcCheckSecurity] @UserGuid
	SELECT
		ISNULL([CustGUID], 0x0) AS [CustGUID],
		SUM([Balance]) AS [Balance],
		[TypeGUID], 
		[SubId],
		[TypeName],
		[TypeLatinName],
		[IsManualEntry],
		[cu].[cuCustomerName] AS [CustName],
		[cu].[cuLatinName]	  AS [CustLatinName]
	FROM
		[#Result] LEFT JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [CustGUID]
	GROUP BY
		[CustGUID],
		[TypeGUID], 
		[SubId],
		[TypeName],
		[TypeLatinName],
		[IsManualEntry],
		[cu].[cuCustomerName],
		[cu].[cuLatinName]	 
	ORDER BY [cu].[cuCustomerName]

	SELECT * FROM [#SecViol] 
###########################################################################
#END
