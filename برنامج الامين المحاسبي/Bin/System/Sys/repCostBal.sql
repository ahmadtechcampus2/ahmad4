#######################################################
CREATE PROCEDURE repCostBal
	@CostGUID 			[UNIQUEIDENTIFIER],
	@AccGUID 			[UNIQUEIDENTIFIER],
	@StartDate			[DATETIME],
	@EndDate			[DATETIME],
	@PostedVal 			[INT] = -1 ,-- 1 posted or 0 unposted -1 all posted & unposted
	@CurGUID			[UNIQUEIDENTIFIER],
	@CurVal				[FLOAT],
	@ShowBalancedAcc	[INT] =0,
	@ShowEmptyCost		[INT] =0,
	@SrcGuid		    [UNIQUEIDENTIFIER] = 0X0,
	@NotAssembleSubCostCenInMainCostCen [float] = 0,
	@Sorted 			[INT] = 0 -- 0: without sort, 1:Sort By Code, 2:Sort By Name
	
AS
	SET NOCOUNT ON
	DECLARE	@ZeroValue [FLOAT],@str NVARCHAR(2000),@UserId UNIQUEIDENTIFIER,@HosGuid UNIQUEIDENTIFIER
	SET @HosGuid = NEWID()
	SET @ZeroValue = [dbo].[fnGetZeroValuePrice]()
	DECLARE @Level [INT]
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER]
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT])
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])    
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])    
	
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()     
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID    
	
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID    
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID 
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]
	IF [dbo].[fnObjectExists]( 'prcGetTransfersTypesList') <> 0	
		INSERT INTO [#EntryTbl]	EXEC [prcGetTransfersTypesList] 	@SrcGuid
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
	INSERT INTO [#AccTbl] SELECT * FROM [dbo].[fnGetAcDescList]( @AccGUID)
	
	CREATE TABLE [#Result]
	(
		[enCostPoint]		[UNIQUEIDENTIFIER],
		[FixedEnDebit]		[FLOAT],
		[FixedEnCredit]		[FLOAT],
		[enDate]			[DATETIME],
		[ceNumber]			[INT],
		[ceSecurity]		[INT]
	)
	CREATE TABLE [#t_Result]
	(
		[GUID]			[UNIQUEIDENTIFIER],
		[PrevDebit]		[FLOAT] DEFAULT 0,
		[PrevCredit]	[FLOAT] DEFAULT 0,
		[PrevBalDebit]	[FLOAT] DEFAULT 0,
		[PrevBalCredit]	[FLOAT] DEFAULT 0,		 
		[TotalDebit]	[FLOAT] DEFAULT 0,
		[TotalCredit]	[FLOAT] DEFAULT 0,
		[BalDebit]		[FLOAT] DEFAULT 0,
		[BalCredit]		[FLOAT] DEFAULT 0,
		[EndBalDebit]	[FLOAT] DEFAULT 0,
		[EndBalCredit]	[FLOAT] DEFAULT 0,
		[ParentGUID]	[UNIQUEIDENTIFIER],
		[NSons]			[INT], 
		[Level]			[INT] DEFAULT 0,
		[Balanced]		[INT],
		[Security]		[INT] 
	)
	CREATE TABLE [#t_Bal]
	(
		[GUID] 			[UNIQUEIDENTIFIER],
		[TotalDebit]	[FLOAT],
		[TotalCredit]	[FLOAT]
	)
	-- report footer data:
	CREATE TABLE [#Totals]
	(
		[TotalPrevDebit] [FLOAT] DEFAULT 0,
		[TotalPrevCredit] [FLOAT] DEFAULT 0,
		[TotalDebitTotal] [FLOAT] DEFAULT 0,
		[TotalCreditTotal] [FLOAT] DEFAULT 0,
		[TotalDebitBalance] [FLOAT] DEFAULT 0,
		[TotalCreditBalance] [FLOAT] DEFAULT 0,
		[TotalPrevBalDebit] [FLOAT] DEFAULT 0,
		[TotalPrevBalCredit] [FLOAT] DEFAULT 0
	)
	INSERT INTO [#Result]
	(
		[enCostPoint],
		[FixedEnDebit],
		[FixedEnCredit],
		[enDate],
		[ceNumber],
		[ceSecurity]
	)
	SELECT
		[enCostPoint],
		[FixedEnDebit],
		[FixedEnCredit],
		[enDate],
		[ceNumber],
		[ceSecurity]
	FROM
		[dbo].[fnCeEn_Fixed](@CurGUID) AS [f]
		INNER JOIN [#AccTbl] AS [ac] ON [f].[enAccount] = [ac].[GUID]
		INNER JOIN [#EntryTbl] AS [t]  ON [f].[ceTypeGuid] = [t].[Type]   
	WHERE
		((@PostedVal = -1) OR ( [ceIsPosted] = @PostedVal))
		--(enDate BETWEEN @StartDate AND @EndDate)
--CREATE CLUSTERED INDEX [rINd] ON [#Result]([enCostPoint],[enDate])
--- check sec
	EXEC [prcCheckSecurity]
	--select * from #Result
	INSERT INTO [#t_Bal]
		SELECT
			[enCostPoint],
			SUM( [FixedEnDebit]) AS [TotalDebit],
			SUM( [FixedEnCredit]) AS [TotalCredit]
		FROM
			[#Result] AS [fn1]
		WHERE
			[fn1].[enDate] BETWEEN @StartDate AND @EndDate
		GROUP BY
			[enCostPoint]
	CREATE TABLE [#t_PrevBal]
	(
		[GUID] 		[UNIQUEIDENTIFIER],
		[PrevDebit]	[FLOAT],
		[PrevCredit][FLOAT]
	)
	INSERT INTO [#t_PrevBal]
		SELECT
			[enCostPoint],
			SUM( [FixedEnDebit]) AS [PrevDebit],
			SUM( [FixedEnCredit]) AS [PrevCredit]
		FROM
			[#Result] AS [fn1]
		WHERE
			[fn1].[enDate] < @StartDate --BETWEEN @PrevStartDate AND @PrevEndDate
		GROUP BY
			[enCostPoint]
	--- fill #t_Result
	INSERT INTO [#t_Result]
	(
		[GUID],
		[ParentGUID],
		[Level],
		[Security]
	)
	SELECT
		[f].[GUID],
		[co].[coParent],
		[f].[Level],
		[co].[coSecurity]
	FROM
		[dbo].[fnGetCostsListWithLevel]( @CostGUID, @Sorted) AS [f]
		INNER JOIN [vwCo] AS [co] ON [f].[GUID] = [co].[coGUID]
-- select * from #t_Result
--- select * from dbo.fnGetCostsListWithLevel( 0x0, 0)  as v inner join vwco as c on v.guid = c.coguid
	UPDATE [#t_Result] SET
		[TotalDebit] = ISNULL( [bl].[TotalDebit], 0),
		[TotalCredit] = ISNULL( [bl].[TotalCredit],	0),
		[PrevDebit]	= ISNULL( [bl].[PrevDebit], 0),
		[PrevCredit] = ISNULL( [bl].[PrevCredit], 0)
	FROM
		[#t_Result] AS [tr] INNER JOIN
		(SELECT			-- this is the balances result set
			ISNULL([rs1].[GUID], [rs2].[GUID]) AS [GUID],
			[rs1].[TotalDebit],
			[rs1].[TotalCredit],
			[rs2].[PrevDebit],
			[rs2].[PrevCredit]
		FROM
			(
			SELECT	-- this is the Totals result set
				[GUID],
				[TotalDebit],
				[TotalCredit]
			FROM
				[#t_Bal]
			) AS [rs1]
			FULL JOIN -- between Totals and Prevs
			(
			SELECT	-- this is the Prevs result set
				[GUID],
				[PrevDebit],
				[PrevCredit]
			FROM
				[#t_PrevBal]
			) AS [rs2]
			ON [rs1].[GUID] = [rs2].[GUID] -- continuing balances full join.
			--ON rs1.Number = rs2.Number -- continuing balances full join.
		) AS [bl] -- balances result set
	ON [tr].[GUID] = [bl].[GUID] -- continuing original result set
--	select * from dbo.fnExtended_En_Fixed_src(DEFAULT, DEFAULT)
	-- SELECT * FROM #Result
	UPDATE [#t_Result] SET [Balanced] = CASE WHEN ABS(([TotalDebit] - [TotalCredit])+( [PrevDebit] - [PrevCredit])) < @ZeroValue AND (([TotalDebit] + [TotalCredit])+( [PrevDebit] + [PrevCredit])) > @ZeroValue THEN 0  WHEN ABS(([TotalDebit] - [TotalCredit])+( [PrevDebit] - [PrevCredit])) > @ZeroValue THEN 1  ELSE NULL END
	UPDATE [#t_Result] SET
		[BalDebit] = ( [TotalDebit] - [TotalCredit]),
		[BalCredit] = ( [TotalDebit] - [TotalCredit]),  
		[PrevBalDebit] = ( [PrevDebit] - [PrevCredit]), 
		[PrevBalCredit] = ( [PrevDebit] - [PrevCredit]) 
	
	UPDATE [#t_Result] SET  
		[BalDebit] = CASE WHEN [BalDebit] < 0 THEN 0 ELSE [BalDebit] END,  
		[BalCredit] = CASE WHEN [BalCredit] < 0 THEN - [BalCredit] ELSE 0 END,  
		[PrevBalDebit] = CASE WHEN [PrevBalDebit] < 0 THEN 0 ELSE [PrevBalDebit] END, 
		[PrevBalCredit] = CASE WHEN [PrevBalCredit] < 0 THEN - [PrevBalCredit] ELSE 0 END 
		
	
--SELECT *FROM #t_Result
	---- Calc Totals 
	INSERT INTO [#Totals]
	(
		[TotalPrevDebit], 
		[TotalPrevCredit], 
		[TotalDebitTotal], 	
		[TotalCreditTotal], 
		[TotalDebitBalance], 
		[TotalCreditBalance], 
		[TotalPrevBalDebit], 
		[TotalPrevBalCredit]
	) 
	SELECT 
		SUM( [PrevDebit]),
		SUM( [PrevCredit]),
		SUM( [TotalDebit]),
		SUM( [TotalCredit]),
		SUM( [BalDebit]),
		SUM( [BalCredit]),
		SUM( [PrevBalDebit]),
		SUM( [PrevBalCredit])
	FROM
		[#t_Result]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )
	IF @Admin = 0
	BEGIN
		DECLARE @CoSecurity [INT]	
		SET @CoSecurity = [dbo].[fnGetUserCostSec_Browse](@UserGuid)
		SET @Level = 1
		WHILE @Level > 0
		BEGIN
			UPDATE [co] SET [ParentGuid] = [c].[ParentGuid],[Level] = [co].[Level] -1 FROM [#t_Result] AS [co] INNER JOIN [#t_Result] AS [c] ON [co].[ParentGuid] = [c].[Guid] WHERE [c].[Security] > @CoSecurity
			SET @Level = @@RowCount
		END
		DELETE [#t_Result] WHERE [Security] > @CoSecurity
	END
-- 3rd. step: update parents balances:
	IF @NotAssembleSubCostCenInMainCostCen = 0 	
	BEGIN
		SET @Level = (SELECT MAX([Level]) FROM [#t_Result])
		WHILE @Level >= 0
		BEGIN
			UPDATE [#t_Result] SET
				[PrevDebit]	= [PrevDebit] + [SumPrevDebit],
				[PrevCredit] = [PrevCredit] + [SumPrevCredit],
				[TotalDebit] = [TotalDebit] + [SumTotalDebit],
				[TotalCredit] = [TotalCredit] + [SumTotalCredit],
				[BalDebit]	= [BalDebit] + [SumBalDebit],
				[BalCredit]	= [BalCredit] + [SumBalCredit],
		 
				[PrevBalDebit] = [PrevBalDebit] + [SumPrevBalDebit],
				[PrevBalCredit] = [PrevBalCredit] + [SumPrevBalCredit],
				[Balanced] = CASE WHEN [Balanced] > 0 THEN [Balanced] ELSE  [SumBalanced] END
			FROM
				[#t_Result] AS [Father] INNER JOIN
					(
					SELECT
						[ParentGUID],
						SUM([PrevDebit]) AS [SumPrevDebit],
						SUM([PrevCredit]) AS [SumPrevCredit],
						SUM([TotalDebit]) AS [SumTotalDebit],
						SUM([TotalCredit]) AS [SumTotalCredit],
						SUM([BalDebit]) AS [SumBalDebit],
						SUM([BalCredit]) AS [SumBalCredit],
						SUM([PrevBalDebit]) AS [SumPrevBalDebit],
						SUM([PrevBalCredit]) AS [SumPrevBalCredit],
						SUM([Balanced]) AS [SumBalanced]
					FROM
						[#t_Result]
					WHERE
						[Level] = @Level
					GROUP BY
						[ParentGUID]
					) AS [Sons] -- sum sons
				ON [Father].[GUID] = [Sons].[ParentGUID]
		SET @Level = @Level - 1
		END
	END
-----------+++
	IF @ShowBalancedAcc = 0
		DELETE [#t_Result] WHERE [Balanced] = 0 
	IF @ShowEmptyCost = 0
		DELETE [#t_Result] WHERE [Balanced] IS NULL 
	IF @NotAssembleSubCostCenInMainCostCen <> 0 	
	BEGIN
		UPDATE [#t_Result] 
			SET [ParentGUID]  = 0x0
			WHERE [ParentGUID] NOT IN (SELECT [Guid] FROM #t_Result )
	END	 
	-- return result set	
	SELECT 
		[r].[GUID] AS [enCostPoint],
		[co].[coName],
		[co].[coCode],
		[r].[PrevDebit],
		[r].[PrevCredit],
		[r].[PrevBalDebit],
		[r].[PrevBalCredit],
		[r].[TotalDebit],
		[r].[TotalCredit],
		[r].[BalDebit],
		[r].[BalCredit],
		[r].[EndBalDebit],
		[r].[EndBalCredit],
		[r].[ParentGUID],
		[r].[Level]
	 FROM 
		[#t_Result] AS [r] INNER JOIN [vwCo] AS [co] ON [r].[GUID] = [co].[coGUID]
		
	IF (@@Rowcount = 0)
		DELETE [#Totals]

	SELECT * FROM [#Totals]
	SELECT * FROM [#SecViol]	
/*
	prcConnections_add2 '„œÌ—'
	exec  [repCostBal] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '1/1/2008', '4/28/2008', 1, '6c87bc9f-94c1-4382-a3fd-664f8e029126', 1.000000, 0, 0, 'c1606720-9757-459b-9377-67cb80318495', 1
*/
###########################################################
#END