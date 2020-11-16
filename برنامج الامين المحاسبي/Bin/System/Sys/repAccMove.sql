##################################################################
CREATE PROCEDURE repAccMove
	@AccGUID		AS [UNIQUEIDENTIFIER], 
	@CurGUID		AS [UNIQUEIDENTIFIER], 
	@startDate		AS [DATETIME], 
	@EndDate		AS [DATETIME], 
	@PeriodType		AS [INT],-- 1 Daily, 2 Weekly, 3 Monthly, 4 Quarter, 5 Yearly 
	@bDebitType		AS [BIT],
	@bCreditType	AS [BIT],
	@bBalType		AS [BIT],
	@ShowCost		AS [BIT],	-- 0 don't display cost , 1 display the cost 
	@CostGUID		AS [UNIQUEIDENTIFIER] = 0x0,
	@Src			AS [UNIQUEIDENTIFIER] = 0X00,
	@PeriodStr		AS [NVARCHAR](max) = '',
	@ShowEmptyPeriod AS [BIT] = 0,
	@CustGUID		AS [UNIQUEIDENTIFIER] = 0X00 

AS 
	SET NOCOUNT ON
	
	--DECLARING VARIABLES 
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @EntrySec [INT] 
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SET @EntrySec = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, DEFAULT) 
	--#Tables for resources check security.
	DECLARE @Sec INT 
	SET @Sec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](),0X00) 
	
	CREATE TABLE [#BillTbl]([Type] [UNIQUEIDENTIFIER], [Security] SMALLINT, [ReadPriceSecurity] SMALLINT)
	CREATE TABLE [#EntryTbl]([Type] [UNIQUEIDENTIFIER], [Security] SMALLINT)      
	
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @Src, @UserGUID      
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @Src, @UserGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @Src, @UserGUID   
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]  
	
	IF [dbo].[fnObjectExists]('prcGetTransfersTypesList') <> 0	  
		INSERT INTO [#EntryTbl]	EXEC [prcGetTransfersTypesList] @Src  
	
	DECLARE @SQL [VARCHAR](8000)  
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0  
	BEGIN		  
		SET @SQL = '
		INSERT INTO [#EntryTbl]  
		SELECT  
			[IdType],  
			[dbo].[fnGetUserSec](''' + CAST(@UserGUID AS VARCHAR(36)) + ''', 0X2000F200, [IdType], 1, 1)  
		FROM
			[dbo].[RepSrcs] AS [r]   
			INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid]
		WHERE
			[IdTbl] = ''' + CAST(@Src AS VARCHAR(36)) + ''''
		EXEC(@SQL)
	END

	IF [dbo].[fnObjectExists]('vwTrnExchangeTypes') <> 0
	BEGIN		  
		SET @SQL = '
		INSERT INTO [#EntryTbl]  
		SELECT
			[IdType],  
			[dbo].[fnGetUserSec](''' + CAST(@UserGUID AS VARCHAR(36)) + ''', 0X2000F200, [IdType], 1, 1)  
		FROM  
			[dbo].[RepSrcs] AS [r]   
			INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid]  
		WHERE  
			[IdTbl] = ''' + CAST(@Src AS VARCHAR(36)) + ''''  
		EXEC(@SQL)  
	END 				  
	--END OF #Tables for resources check security.
	--CREATING TEMP TABLES 
	CREATE TABLE [#FinalResult] ( [id] [INT], [StartDate] [DATETIME], [EndDate] [DATETIME], [Debit] [FLOAT], [Credit] [FLOAT], [Val] [FLOAT], [CostGUID] [UNIQUEIDENTIFIER], [coName] [NVARCHAR](250) COLLATE ARABIC_CI_AI)  
	CREATE TABLE [#Result] ([Security] [INT], [User_Security] [INT], [coSecurity] [INT], [enDate] [DATETIME], [Debit] [FLOAT], [Credit] [FLOAT], [CostGUID] [UNIQUEIDENTIFIER])  
	CREATE TABLE [#hlpTbl]( [Id] [UNIQUEIDENTIFIER], [enCostPoint] [UNIQUEIDENTIFIER], [Debit] [FLOAT], [Credit] [FLOAT], [Val] [FLOAT]) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	--FILLING THE TABLES 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	DECLARE @PERIOD TABLE  ([ID] [UNIQUEIDENTIFIER], [Period] [INT], [StartDate] [DATETIME], [EndDate] [DATETIME]) 
	IF @PeriodType <> 3 
		INSERT INTO @PERIOD SELECT NEWID(), [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod]( @PeriodType, @StartDate, @EndDate)
	ELSE
		INSERT INTO @PERIOD SELECT NEWID(), 0,[StartDate],[EndDate] FROM [dbo].[fnGetStrToPeriod] ( @PeriodStr )
	INSERT INTO [#Result]
	SELECT
		[e].[CESecurity], @EntrySec,
		[co].[Security],
		[e].[enDate],
		[e].[FixedenDebit],
		[e].[FixedenCredit],
		CASE  @ShowCost WHEN 1 THEN [e].[enCostPoint] ELSE 0x0 END
	FROM
		[dbo].[fnExtended_En_Fixed_Src]( @Src,@CurGUID )AS [e]
		INNER JOIN [fnGetAcDescList](@AccGUID ) AS [f]
			ON [e].[enAccount] = [f].[GUID] 
		INNER JOIN [#CostTbl] [co] on [co].[CostGuid] = [e].[enCostPoint] 			
		LEFT JOIN [#EntryTbl] AS [t]  ON [e].[ParentTypeGUID] = [t].[Type]
	WHERE 
		[e].[endate] BETWEEN @StartDate  AND  @EndDate
		AND [e].[ceSecurity] <= ISNULL([t].[Security],@Sec)
		AND e.enCustomerGUID = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN @CustGUID ELSE e.enCustomerGUID END 
	---	
	EXEC [prcCheckSecurity]  

	INSERT INTO [#hlpTbl] 
	SELECT  
		[f].[ID], 
		CASE WHEN (SUM( [r].[Debit]) <> 0) OR (SUM( [r].[Credit]) <> 0) THEN [r].[CostGUID] 
			ELSE 0X0 
			END, 
		CASE WHEN @bDebitType = 1 THEN SUM ([r].[Debit]) ELSE 0 END,
		CASE WHEN @bCreditType = 1 THEN SUM( [r].[Credit]) ELSE 0 END,
		CASE WHEN @bBalType = 1 THEN SUM( [r].[Debit] - [r].[Credit]) ELSE 0 END
	FROM 
		[#Result] AS [r] INNER JOIN @period As [f]
		ON [r].[enDate] between [f].[StartDate] and [f].[EndDate]
	GROUP BY 
		[f].[ID], [r].[CostGUID]
	
	INSERT INTO [#FinalResult]
		SELECT
			[P].[Period], 
			[P].[StartDate], 
			[P].[EndDate], 
			ISNULL([h].[Debit], 0), 
			ISNULL([h].[Credit], 0), 
			ISNULL([h].[val], 0), 
			ISNULL([Co].[coGUID], 0x0),
			ISNULL([Co].[coName], '')
		FROM
			@period AS [P]
			LEFT JOIN [#hlpTbl] AS [h] ON [P].[Id] = [h].[Id]
			LEFT JOIN [vwCo] AS [Co] On [h].[enCostPoint] = [Co].[coGUID]
		WHERE 
			( @ShowEmptyPeriod = 0 
							AND ([h].[Debit] <> 0 OR [h].[Credit] <> 0 OR [h].[val] <> 0)
			) OR @ShowEmptyPeriod = 1
		
	SELECT * FROM [#FinalResult]
	SELECT * FROM [#SecViol] 
			
/*
	prcConnections_Add2 'Œ«·œ' 
	[repAccMove] '0293ac7f-ad37-4319-9265-eaf8d69754f3', 'ca6b758d-1d20-480e-bf4c-ab55bc2c3302', 1.000000, '1/1/2013 0:0:0.0', '5/21/2013 23:59:59.157', 3, 1, 1, 1, 1, '00000000-0000-0000-0000-000000000000', '54d0e4d0-6f54-4ad5-ae51-ba56526f5d50', '1-1-2013 0:0,1-31-2013 23:59,2-1-2013 0:0,2-28-2013 23:59,3-1-2013 0:0,3-31-2013 23:59,4-1-2013 0:0,4-30-2013 23:59,5-1-2013 0:0,5-21-2013 23:59', 0
*/
###########################################################
#END