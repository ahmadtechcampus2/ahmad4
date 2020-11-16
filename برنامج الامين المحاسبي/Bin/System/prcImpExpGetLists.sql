##################################################################
CREATE PROCEDURE prcImpExpGetLists
	@SrcGuid			[UNIQUEIDENTIFIER],
	@UseDates			[INT],
	@StartDate			[DATETIME],
	@EndDate			[DATETIME],
	@Type				[INT], -- 0 stores , 1 costs, 2 Acc, 3 Customers, 4 Materials, 5 groups
	@StGuid				[UNIQUEIDENTIFIER] = 0X00
AS
	SET NOCOUNT ON
	DECLARE @CurPtr [UNIQUEIDENTIFIER]
	DECLARE @Date [DATETIME]
	
	CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#Bills]
	(
		[Guid]		[UNIQUEIDENTIFIER]
	)

	CREATE TABLE [#Return]
	(
		[Guid]		[UNIQUEIDENTIFIER]
	)
	CREATE TABLE [#ItemsReturn]
	(
		[Guid]		[UNIQUEIDENTIFIER]
	)
	
	INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList]	@StGuid  
	IF @UseDates = 1
		INSERT INTO [#Bills] SELECT [buGuid] FROM [vwbu] AS [bu] INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType]  WHERE [buDate] BETWEEN @StartDate AND @EndDate  AND ((@StGuid = 0x00)OR([buStorePtr] IN (SELECT [StoreGUID] FROM [#StoreTbl] ))) AND [r].[IdTbl] = @SrcGuid
	ELSE
		INSERT INTO [#Bills] SELECT [buGuid] FROM [vwbu] AS [bu] INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType]  WHERE [buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]  AND ((@StGuid = 0x00)OR([buStorePtr] IN (SELECT [StoreGUID] FROM [#StoreTbl] ))) AND [r].[IdTbl] = @SrcGuid

	IF @Type = 0 -- stores
	BEGIN
		IF EXISTS(SELECT * FROM dbo.sysobjects AS [so] INNER JOIN dbo.sysusers AS [su] ON  [so].[uid] = [su].[uid] WHERE [so].[Name] = 'FM2' AND [su].[Name] = 'dbo')
			DROP TABLE [dbo].[FM2]
		IF EXISTS(SELECT * FROM dbo.sysobjects AS [so] INNER JOIN dbo.sysusers AS [su] ON  [so].[uid] = [su].[uid] WHERE [so].[Name] = 'mb2' AND [su].[Name] = 'dbo')
			DROP TABLE [dbo].[mb2]
		INSERT INTO [#Return] SELECT DISTINCT [StoreGuid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#ItemsReturn] SELECT DISTINCT [bi].[StoreGuid] FROM ([bi000] AS [bi] INNER JOIN [#Bills] AS [bl] ON [bi].[ParentGuid] = [bl].[Guid]) 
		CREATE TABLE [dbo].[FM2] ([Guid]		[UNIQUEIDENTIFIER])
		INSERT INTO [dbo].[FM2] SELECT DISTINCT [FormGuid] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
		INSERT INTO [#Return] 
				SELECT [InStoreGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
				UNION ALL
				SELECT [OutStoreGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
				UNION ALL
				SELECT [InStoreGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0
				UNION ALL
				SELECT [OutStoreGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0
		SELECT [mb].* INTO [DBO].[mb2] FROM [MB000] AS [mb] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
	END
	ELSE IF @Type = 1 --costs
	BEGIN
		INSERT INTO [#Return] SELECT DISTINCT [CostGuid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#ItemsReturn]([Guid]) SELECT DISTINCT [CostGuid] FROM [bi000] AS [bi] INNER JOIN [#Bills] AS [bl] ON [bi].[ParentGuid] = [bl].[Guid]

		INSERT INTO [#Return] SELECT DISTINCT [ch].[Cost1Guid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
												INNER JOIN [ch000] AS [ch] ON [ch].[ParentGuid] = [bu].[GUID]
												WHERE [bu].[PayTYpe] > 1
		
		INSERT INTO [#Return] SELECT DISTINCT [ch].[Cost2Guid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
												INNER JOIN [ch000] AS [ch] ON [ch].[ParentGuid] = [bu].[GUID]
												WHERE [bu].[PayTYpe] > 1
			
	INSERT INTO [#Return] 
		SELECT [InCostGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
		UNION ALL
		SELECT [OutCostGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
		UNION ALL
		SELECT [InCostGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0
		UNION ALL
		SELECT [OutCostGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0

	END
	ELSE IF @Type = 2 --accounts
	BEGIN
		INSERT INTO [#Return] SELECT DISTINCT [CustAccGuid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [MatAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [FPayAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [ItemsDiscAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [BonusDiscAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [ItemsExtraAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [CostAccGUID]	 FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [StockAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [BonusAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [BonusContraAccGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] SELECT DISTINCT [VATAccGUID]  FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
	
		INSERT INTO [#Return] SELECT DISTINCT [cu].[AccountGuid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
																	INNER JOIN [cu000] AS [cu] ON [cu].[Guid] = [bu].[CustGUID]
		-- from di000
		INSERT INTO [#Return] SELECT DISTINCT [di].[AccountGuid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
																	INNER JOIN [di000] AS [di] ON [di].[ParentGuid] = [bu].[GUID]
		
		INSERT INTO [#Return] SELECT DISTINCT [ch].[AccountGuid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
																	INNER JOIN [ch000] AS [ch] ON [ch].[ParentGuid] = [bu].[GUID]

		INSERT INTO [#Return] SELECT DISTINCT [ch].[Account2Guid] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
																	INNER JOIN [ch000] AS [ch] ON [ch].[ParentGuid] = [bu].[GUID]
		INSERT INTO [#Return] SELECT DISTINCT [ce].[enaccount] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
																	INNER JOIN [ch000] AS [ch] ON [ch].[ParentGuid] = [bu].[GUID]
																	INNER JOIN [er000] AS [er] ON [er].[ParentGuid] = [ch].[Guid]
																	INNER JOIN [vwceen] AS [ce] ON [ce].[ceGuid] = [er].[EntryGuid]
																	WHERE [ch].[State] <> 0
		INSERT INTO [#Return] 
			SELECT [InAccountGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
			UNION ALL
			SELECT [OutAccountGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
			UNION ALL
			SELECT [InTempAccGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]
			UNION ALL
			SELECT [OutTempAccGUID] FROM [MN000] AS [mn] INNER JOIN [MB000] AS [mb] ON [mb].[ManGuid] = [mn].[Guid] INNER JOIN [#Bills] AS [bl] ON [mb].[BillGuid] = [bl].[Guid]	
			UNION ALL
			SELECT [InAccountGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0
			UNION ALL
			SELECT [OutAccountGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0
			UNION ALL
			SELECT [InTempAccGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0
			UNION ALL
			SELECT [OutTempAccGUID] FROM [MN000] AS [mn] INNER JOIN [FM2] AS [fm] ON [fm].[Guid] = [mn].[FormGuid] WHERE [Type] = 0
	END
	ELSE IF @Type = 3 -- Customers
	BEGIN
		INSERT INTO [#Return] SELECT DISTINCT [CustGUID] FROM [bu000] AS [bu] INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
		INSERT INTO [#Return] 
		SELECT DISTINCT 
			[CustomerGUID] 
		FROM 
			en000 AS EN 
			JOIN ce000 AS CE ON CE.GUID = EN.ParentGUID
			JOIN [RepSrcs] AS R ON R.IdType = CE.TypeGUID
			JOIN [cu000] AS cu ON cu.GUID = en.CustomerGUID
		WHERE 
			R.IdTbl = @SrcGuid
			AND [CustomerGUID] <> 0x
			AND en.CustomerGUID NOT IN (SELECT GUID FROM #Return)
	END
	ELSE IF @Type = 4 -- Materials
	BEGIN
		INSERT INTO [#ItemsReturn]([Guid]) SELECT DISTINCT [MatGUID] FROM [bi000] AS [bi] INNER JOIN [#Bills] AS [bl] ON [bi].[ParentGuid] = [bl].[Guid]
		INSERT INTO [#ItemsReturn]([Guid]) SELECT DISTINCT [mt].[Parent] FROM [mt000] AS [mt] INNER JOIN [#ItemsReturn] AS [ir] ON [ir].[Guid] = [mt].[Guid]
	--	INSERT INTO #Return SELECT DISTINCT MatGUID FROM bu000 AS bu INNER JOIN #Bills AS bl ON bu.Guid = bl.Guid
	END
	ELSE IF @Type = 5 -- Groups
	BEGIN
		INSERT INTO [#ItemsReturn]([Guid]) SELECT DISTINCT [mt].[GroupGuid] FROM [bi000] AS [bi] INNER JOIN [#Bills] AS [bl] ON [bi].[ParentGuid] = [bl].[Guid]
																		INNER JOIN [mt000] AS [mt] ON [mt].[guid] = [bi].[MatGuid]
	--	INSERT INTO #Return SELECT DISTINCT MatGUID FROM bu000 AS bu INNER JOIN #Bills AS bl ON bu.Guid = bl.Guid
	END
	ELSE IF @Type = 6 -- dISCOUNTcARD
		INSERT INTO [#Return] SELECT a.GUID FROM SCPurchases000 A INNER JOIN BillRel000 B ON b.Parentguid = a.guid INNER JOIN [#Bills] C ON B.BillGUID = c.[Guid]
	ELSE IF @Type = 7 -- CustAddress
	BEGIN
		INSERT INTO [#Return] 
		SELECT DISTINCT 
			[CA].[GUID] 
		FROM 
			[bu000] AS [bu] 
			INNER JOIN [#Bills] AS [bl] ON [bu].[Guid] = [bl].[Guid]
			INNER JOIN cu000 As Cu ON [bu].[CustGUID] = [Cu].[Guid]
			INNER JOIN CustAddress000 As CA ON [CA].CustomerGUID = [CU].[Guid]
		INSERT INTO [#Return] 
		SELECT DISTINCT 
			[CA].[GUID] 
		FROM 
			en000 AS EN 
			INNER JOIN ce000 AS CE ON CE.GUID = EN.ParentGUID
			INNER JOIN [RepSrcs] AS R ON R.IdType = CE.TypeGUID
			INNER JOIN [cu000] AS cu ON cu.GUID = en.CustomerGUID
			INNER JOIN CustAddress000 As CA ON [CA].CustomerGUID = [CU].[Guid]
	END
	--- return data
	SELECT DISTINCT ISNULL( [s].[Guid], [si].[Guid])AS [Guid] FROM [#Return] AS [s] FULL JOIN [#ItemsReturn] AS [si] ON [s].[Guid] = [si].[Guid]

/*

prcConnections_Add2 '„œÌ—'
EXEC [prcImpExpGetLists] '89040089-d402-4a9c-9f39-c4a9a35f32df', 136, 136, 0, '1/1/2005', '12/25/2005', 0, 0, '00000000-0000-0000-0000-000000000000'

*/
##################################################################
CREATE PROCEDURE prcGetDiscAccList
	@StartDate				[DATETIME] = NULL,
	@EndDate				[DATETIME] = NULL,
	@SrcGuid				[UNIQUEIDENTIFIER] = NULL
AS
	SET NOCOUNT ON
	CREATE TABLE [#res]
	(
		[buType] 		[UNIQUEIDENTIFIER],
		[Branch]		[UNIQUEIDENTIFIER],
		[Guid]			[UNIQUEIDENTIFIER],
		[buCustAccGuid] 	[UNIQUEIDENTIFIER]
	)
	
	SELECT 
				DISTINCT [AccountGUID] 
	FROM [di000] AS [di] INNER JOIN [vwbu] AS [bu] ON [bu].[buGuid] = [di].[ParentGuid]
					INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType] 
					--INNER JOIN [#RES] AS [re] ON [bu].[buType] = [re].[buType] AND [bu].[buBranch] = [re].[Branch] AND [bu].[buCustAcc] = [re].[buCustAccGuid]
	WHERE 
		([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]) OR ([buDate] BETWEEN @StartDate AND @EndDate)
		AND (([r].[IdTbl] = @SrcGuid) OR ( [r].[IdTbl] = NULL))
##################################################################
CREATE PROCEDURE prcGetManifactoring
AS
	SET NOCOUNT ON

	SELECT * FROM [FM000] 
	SELECT * FROM [MN000] 
	 
	SELECT * FROM [MI000]
	SELECT * FROM [MX000]
	SELECT * FROM [MB000] 
	 
	IF OBJECT_ID('dbo.FM2', 'U') IS NOT NULL 
	BEGIN
		DROP TABLE [dbo].[FM2]
	END

	IF OBJECT_ID('dbo.mb2', 'U') IS NOT NULL 
	BEGIN
		DROP TABLE [dbo].[mb2]
	END
#################################################################
#END
