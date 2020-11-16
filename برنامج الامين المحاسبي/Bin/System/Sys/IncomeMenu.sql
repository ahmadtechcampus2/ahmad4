################################################################################
CREATE PROCEDURE repGetIncomeMenue
	@SrcGuid			UNIQUEIDENTIFIER = 0X0,
	@StartDate 			DATETIME,  
	@EndDate 			DATETIME,     
	@CostGUID 			UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	
	@StGUID				UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	
	@Final				UNIQUEIDENTIFIER,
	@DetailSubStores	INT,	 -- 1 show details 0 no details  for Stores 
	@PriceType			INT,	 
	@PricePolicy		INT,      
	@Posted				INT,
	@Details			BIT = 0,
	@Level				INT = 0,
	@AccDetails			BIT = 0,   
	@CurPtr				UNIQUEIDENTIFIER,     
	@CurVal				FLOAT
AS
	SET NOCOUNT ON 
	
	DECLARE @UserSec [INT], @BalSec [INT], @Str NVARCHAR(1000), @HosGuid UNIQUEIDENTIFIER
	SET @HosGuid = NEWID()
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](), DEFAULT) 
	SET @BalSec = dbo.fnGetUserAccountSec_readBalance([dbo].[fnGetCurrentUserGUID]()) 
	DECLARE @UserGuid [UNIQUEIDENTIFIER] ,@Admin [BIT]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SELECT @Admin = [bAdmin] FROM [Us000] WHERE [Guid] = @UserGuid
	
	CREATE TABLE [#AccTbl]( [Guid] [UNIQUEIDENTIFIER], [Lvl] [INT], [Path] NVARCHAR(2000))  
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)  
	IF @CostGUID = 0X0
		INSERT INTO [#CostTbl] VALUES(0X0,0) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	
	-- Filling temporary tables 
	INSERT INTO [#AccTbl] SELECT * FROM dbo.fnGetAccountsList(0X00, 1)
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcGuid 
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid
	INSERT INTO [#EntryTbl] SELECT [TypeGUID] , [UserSecurity]  FROM [#BillsTypesTbl]
	
	SELECT  [acc].[Guid], [ac].[Security], [ac].[IncomeType], [ac].[ParentGuid], [ac].[Code], [ac].[Name], [ac].[LatinName], [Path]
	INTO [#AccTbl2]
	FROM [#AccTbl] AS [acc] 
	INNER JOIN [ac000] [ac] ON [acc].[Guid] = [ac].[Guid]
	INNER JOIN [ac000] [f] ON [ac].[FinalGuid] = [f].[Guid]
	where [f].IncomeType = 1
	
	DECLARE @CurLevel [INT]
	CREATE TABLE [#AccDetails]
	(  
		[Guid]					[UNIQUEIDENTIFIER],
		[ParentGuid]			[UNIQUEIDENTIFIER],
		[Code]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Name]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[LatinName]				NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Level]					[INT],
		[Balance]				[FLOAT],
		[Path]					NVARCHAR(4000),
		[IncomeType]			[INT] DEFAULT 0
	)
	
	CREATE TABLE [#RESULT]
	(
		[AccGuid]				[UNIQUEIDENTIFIER],
		[IncomeType]			[INT]	DEFAULT 0,
		[Name]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Code]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[LatinName]				NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Level]					[INT],
		[Balance]				[FLOAT],
		[Path]					NVARCHAR(4000),
		[Type]					[INT]
	)
	
	CREATE TABLE [#AccountResult]
	(
		[AccountGuid]				[UNIQUEIDENTIFIER],
		[Balance]					[FLOAT]
	)
	-------------------------------------------------------------------------------------------
	INSERT INTO #AccountResult (AccountGuid, Balance)
	SELECT 
		[AC].GUID,
		SUM([enDebit] - [enCredit]) / @CurVal
	FROM [vwCeEn] [FIXEN] 
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE [enDate] BETWEEN  @StartDate   AND @EndDate
		AND [AC].[IncomeType] > 0
		AND [FA].[IncomeType] = 1
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	GROUP BY [AC].GUID
	-------------------------------------------------------------------------------------------
	INSERT INTO [#RESULT]([IncomeType],[Type]) VALUES (1,1),(2,1),(3,1),(4,1),(5,1),(6,1),(7,1)
	-------------------------------------------------------------------------------------------
	
	UPDATE [#RESULT] 
	SET 
		Balance = G.Balance
	FROM
		(SELECT INCOMETYPE, SUM(BALANCE)BALANCE
		FROM
			#AccountResult [AR] 
			INNER JOIN ac000 [AC] ON [AC].GUID = [AR].AccountGuid
		GROUP BY [IncomeType]
		) G
	WHERE [#RESULT].IncomeType = G.IncomeType
	-------------------------------------------------------------------------------------------
	SET @Level = 10
	IF @Details > 0
	BEGIN
		INSERT INTO [#RESULT] ([Balance],[IncomeType],[AccGuid],[Name],[LatinName],[Type])
		SELECT SUM([AR].Balance),[AC].IncomeType,[BS].GUID,[BS].Name,[BS].LatinName,2
		FROM 
			#AccountResult [AR] 
			INNER JOIN ac000 [AC] ON [AC].GUID = [AR].AccountGuid
			LEFT JOIN BalSheet000 [BS] ON [BS].GUID = [AC].BalsheetGuid
		GROUP BY [AC].[IncomeType],[BS].GUID,[BS].Name,[BS].LatinName	
	END
	-------------------------------------------------------------------------------------------
	UPDATE [#RESULT] SET  Balance = -1 * Balance-- WHERE [IncomeType] BETWEEN 2 AND 4

	SELECT 
		ISNULL([AccGuid], 0x00) AS [AccGuid],
		ISNULL([IncomeType], 0) AS [IncomeType],
		ISNULL([Name], '') AS [Name],
		ISNULL([Code], '') AS [Code],
		ISNULL([LatinName], '') AS [LatinName],
		ISNULL([Level], 0) AS [Level],
		ISNULL([Balance], 0.0) AS [Balance],
		ISNULL([Path], '') AS [Path],
		ISNULL([Type], 0) AS [Type] 
	FROM [#RESULT] ORDER BY INCOMETYPE, type, Balance

	-------------------------------------------------------------------------------------------
	SELECT COUNT(*) count
	FROM ac000 [AC] INNER JOIN ac000 [FAC] ON [AC].FinalGUID = [FAC].GUID
	WHERE [FAC].IncomeType = 1 AND [AC].IncomeType = 0	AND [AC].NSons = 0
###################################################################################
CREATE PROCEDURE repOwnersEquityMenue
	@SrcGuid			UNIQUEIDENTIFIER = 0X0,
	@StartDate 			DATETIME,  
	@EndDate 			DATETIME,     
	@CostGUID 			UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	
	@StGUID				UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	
	@Final				UNIQUEIDENTIFIER,
	@DetailSubStores	INT,	 -- 1 show details 0 no details  for Stores 
	@PriceType			INT,	 
	@PricePolicy		INT,      
	@Posted				INT,
	@Details			BIT = 0,
	@Level				INT = 0,
	@AccDetails			BIT = 0,   
	@CurPtr				UNIQUEIDENTIFIER,     
	@CurVal				FLOAT = 1
AS
	SET NOCOUNT ON 
	
	DECLARE @UserSec [INT], @BalSec [INT], @Str NVARCHAR(1000), @HosGuid UNIQUEIDENTIFIER
	SET @HosGuid = NEWID()
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](), DEFAULT) 
	SET @BalSec = dbo.fnGetUserAccountSec_readBalance([dbo].[fnGetCurrentUserGUID]()) 
	DECLARE @UserGuid [UNIQUEIDENTIFIER] ,@Admin [BIT]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SELECT @Admin = [bAdmin] FROM [Us000] WHERE [Guid] = @UserGuid
	
	CREATE TABLE [#AccTbl]( [Guid] [UNIQUEIDENTIFIER], [Lvl] [INT], Path NVARCHAR(2000))  
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)  
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	
	-- Filling temporary tables 
	INSERT INTO [#AccTbl] SELECT * FROM dbo.fnGetAccountsList(0X00, 1)
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	IF @CostGUID = 0X0
		INSERT INTO [#CostTbl] VALUES(0X0,0) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcGuid 
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid
	INSERT INTO [#EntryTbl] SELECT [TypeGUID] , [UserSecurity]  FROM [#BillsTypesTbl]


	SELECT  [acc].[Guid], [ac].[Security], [ac].[IncomeType], [ac].[ParentGuid], [ac].[Code], [ac].[Name], [ac].[LatinName], [Path]
	INTO [#AccTbl2]
	FROM [#AccTbl] AS [acc] 
	INNER JOIN [ac000] [ac] ON [acc].[Guid] = [ac].[Guid]
	INNER JOIN [ac000] [f] ON [ac].[FinalGuid] = [f].[Guid]
	where [f].IncomeType = 2
	
	DECLARE @CurLevel [INT]
	CREATE TABLE [#AccDetails]
	(  
		[Guid]					[UNIQUEIDENTIFIER],
		[ParentGuid]			[UNIQUEIDENTIFIER],
		[Code]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Name]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[LatinName]				NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Level]					[INT],
		[Balance]				[FLOAT],
		[Path]					NVARCHAR(4000),
		[IncomeType]			[INT] DEFAULT 0
	)
	
	CREATE TABLE [#RESULT]
	(
		[AccGuid]				[UNIQUEIDENTIFIER],
		[IncomeType]			[INT]	DEFAULT 0,
		[Name]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Code]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[LatinName]				NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Level]					[INT],
		[Balance]				[FLOAT],
		[Path]					NVARCHAR(4000),
		[Type]					[INT]
	)
	
	CREATE TABLE [#AccountResult]
	(
		[AccountGuid]				[UNIQUEIDENTIFIER],
		[Balance]					[FLOAT]
	)
	
	-------------------------------------------------------------------------------------------
	DECLARE @netIncome FLOAT
	SET @netIncome = 
	(SELECT 
		SUM([enDebit] - [enCredit]) / @CurVal
	FROM [vwCeEn] [FIXEN]
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE [enDate] BETWEEN  @StartDate   AND @EndDate
		AND [AC].[IncomeType] > 0
		AND [FA].[IncomeType] = 1
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	)
	
	INSERT INTO [#RESULT]([IncomeType],[Type], [BALANCE]) VALUES (7, 3, @netIncome)
	---------------------------------------------------------------------------------------
	INSERT INTO #AccountResult (AccountGuid, Balance)
	SELECT 
		[AC].GUID,
		SUM([enDebit] - [enCredit]) / @CurVal
	FROM [vwCeEn] [FIXEN]
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE [enDate] BETWEEN  @StartDate   AND @EndDate
		AND [AC].[IncomeType] > 0
		AND [FA].[IncomeType] = 2
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	GROUP BY [AC].GUID
	-------------------------------------------------------------------------------------------
	INSERT INTO [#RESULT]([IncomeType],[Type]) VALUES (8,1),(9,1),(10,1),(11,1),(12,1)
	-------------------------------------------------------------------------------------------
	UPDATE [#RESULT] 
	SET 
		Balance = G.Balance
	FROM
		(SELECT INCOMETYPE, SUM(BALANCE)BALANCE
		FROM
			#AccountResult [AR] 
			INNER JOIN ac000 [AC] ON [AC].GUID = [AR].AccountGuid
		GROUP BY [IncomeType]
		) G
	WHERE [#RESULT].IncomeType = G.IncomeType
	-------------------------------------------------------------------------------------------
	
	IF @Details > 0
	BEGIN
		INSERT INTO [#RESULT] ([Balance],[IncomeType],[AccGuid],[Name],[LatinName],[Type])
		SELECT SUM([AR].Balance),[AC].IncomeType,[BS].GUID,[BS].Name,[BS].LatinName,2
		FROM 
			#AccountResult [AR] 
			INNER JOIN ac000 [AC] ON [AC].GUID = [AR].AccountGuid
			INNER JOIN BalSheet000 [BS] ON [BS].GUID = [AC].BalsheetGuid
		GROUP BY [AC].[IncomeType],[BS].GUID,[BS].Name,[BS].LatinName		
	END
	ELSE
	BEGIN 
		INSERT INTO [#RESULT] ([Balance],[IncomeType],[AccGuid],[Name],[LatinName],[Type])
		SELECT [AR].Balance, [AC].IncomeType, [AC].GUID, [AC].Name, [AC].LatinName, 2
		FROM 
			#AccountResult [AR] 
			INNER JOIN ac000 [AC] ON [AC].GUID = [AR].AccountGuid
	END
	---------------------------------------------------------------------------------------

	UPDATE [#RESULT] SET  Balance = -1 * Balance
	SELECT * FROM [#RESULT] ORDER BY INCOMETYPE, type,[Path] 
	---------------------------------------------------------------------------------------
	SELECT COUNT(*) COUNT
	FROM ac000 [AC] INNER JOIN ac000 [FAC] ON [AC].FinalGUID = [FAC].GUID
	WHERE [FAC].IncomeType <= 2 AND [AC].IncomeType = 0 AND [AC].NSons = 0
###################################################################################
CREATE PROCEDURE repBalanceSheetMenue
	@SrcGuid			UNIQUEIDENTIFIER = 0X0,
	@StartDate 			DATETIME,  
	@EndDate 			DATETIME,     
	@CostGUID 			UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	
	@StGUID				UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	
	@Final				UNIQUEIDENTIFIER,
	@DetailSubStores	INT,	 -- 1 show details 0 no details  for Stores 
	@PriceType			INT,	 
	@PricePolicy		INT,      
	@Posted				INT,
	@Details			BIT = 0,
	@Level				INT = 0,
	@AccDetails			BIT = 0,   
	@CurPtr				UNIQUEIDENTIFIER,     
	@CurVal				FLOAT = 1,
	@ShowOwnerShipDetails		BIT = 0
AS
	SET NOCOUNT ON 
	
	DECLARE @UserSec [INT], @BalSec [INT], @Str NVARCHAR(1000), @HosGuid UNIQUEIDENTIFIER
	SET @HosGuid = NEWID()
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](), DEFAULT) 
	SET @BalSec = dbo.fnGetUserAccountSec_readBalance([dbo].[fnGetCurrentUserGUID]()) 
	DECLARE @UserGuid [UNIQUEIDENTIFIER] ,@Admin [BIT]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SELECT @Admin = [bAdmin] FROM [Us000] WHERE [Guid] = @UserGuid
	
	CREATE TABLE [#AccTbl]( [Guid] [UNIQUEIDENTIFIER], [Lvl] [INT], Path NVARCHAR(2000))  
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	
	-- Filling temporary tables 
	INSERT INTO [#AccTbl] SELECT * FROM dbo.fnGetAccountsList(0X00, 1)
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	IF @CostGUID = 0X0
		INSERT INTO [#CostTbl] VALUES(0X0,0) 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcGuid 
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid
	INSERT INTO [#EntryTbl] SELECT [TypeGUID] , [UserSecurity]  FROM [#BillsTypesTbl]
	
	SELECT  [acc].[Guid], [ac].[Security], [ac].[IncomeType], [ac].[ParentGuid], [ac].[Code], [ac].[Name], [ac].[LatinName], [Path]
	INTO [#AccTbl2]
	FROM [#AccTbl] AS [acc] 
	INNER JOIN [ac000] [ac] ON [acc].[Guid] = [ac].[Guid]
	INNER JOIN [ac000] [f] ON [ac].[FinalGuid] = [f].[Guid]
	where [f].IncomeType = 3
	
	DECLARE @CurLevel [INT]
	CREATE TABLE [#AccDetails]
	(  
		[Guid]					[UNIQUEIDENTIFIER],
		[ParentGuid]			[UNIQUEIDENTIFIER],
		[Code]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Name]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[LatinName]				NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Level]					[INT],
		[Balance]				[FLOAT],
		[Path]					NVARCHAR(4000),
		[IncomeType]			[INT] DEFAULT 0
	)
	
	CREATE TABLE [#RESULT]
	(
		[AccGuid]				[UNIQUEIDENTIFIER],
		[IncomeType]			[INT]	DEFAULT 0,
		[Name]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Code]					NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[LatinName]				NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Level]					[INT],
		[Balance]				[FLOAT],
		[Path]					NVARCHAR(4000),
		[Type]					[INT]
	)
	
	CREATE TABLE [#AccountResult]
	(
		[AccountGuid]				[UNIQUEIDENTIFIER],
		[Balance]					[FLOAT]
	)
	-------------------------------------------------------------------------------------------
	INSERT INTO #AccountResult (AccountGuid, Balance)
	SELECT 
		[AC].GUID,
		SUM([enDebit] - [enCredit]) / @CurVal
	FROM [vwCeEn] [FIXEN]
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE [enDate] BETWEEN  @StartDate   AND @EndDate
		AND [AC].[IncomeType] > 0
		AND [FA].[IncomeType] = 3
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	GROUP BY [AC].GUID
	-------------------------------------------------------------------------------------------
	INSERT INTO [#RESULT]([IncomeType],[Type]) VALUES (13,1),(14,1),(15,1),(16,1),(17,1),(18,1)
	-------------------------------------------------------------------------------------------
	UPDATE [#RESULT] 
	SET 
		Balance = G.Balance
	FROM
		(SELECT INCOMETYPE, SUM(BALANCE)BALANCE
		FROM
			#AccountResult [AR] 
			INNER JOIN ac000 [AC] ON [AC].GUID = [AR].AccountGuid
		GROUP BY [IncomeType]
		) G
	WHERE [#RESULT].IncomeType = G.IncomeType
	-------------------------------------------------------------------------------------------
	SET @Level = 10
	IF @Details > 0
	BEGIN
		INSERT INTO [#RESULT] ([Balance],[IncomeType],[AccGuid],[Name],[LatinName],[Type])
		SELECT SUM([AR].Balance),[AC].IncomeType,[BS].GUID,[BS].Name,[BS].LatinName,2
		FROM 
			#AccountResult [AR] 
			INNER JOIN ac000 [AC] ON [AC].GUID = [AR].AccountGuid
			LEFT JOIN BalSheet000 [BS] ON [BS].GUID = [AC].BalsheetGuid
		GROUP BY [AC].[IncomeType],[BS].GUID,[BS].Name,[BS].LatinName		
	END
	-------------------------------------------------------------------------------------------
	DECLARE @OWNERSEQUITY FLOAT
	SET @OWNERSEQUITY = 
	(SELECT 
		SUM([enDebit] - [enCredit]) / @CurVal
	FROM [vwCeEn] [FIXEN]
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE [enDate] BETWEEN @StartDate AND @EndDate
		AND [AC].[IncomeType] > 0
		AND ([FA].[IncomeType] = 1 OR [FA].[IncomeType] = 2)
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	)
	
	INSERT INTO [#RESULT]([IncomeType],[Type], [BALANCE]) VALUES (20, 3, @OWNERSEQUITY )
	-------------------------------------------------------------------------------------------
	SELECT * FROM [#RESULT] ORDER BY INCOMETYPE, type,[Path] 
	---------------------------------------------------------------------------------------
	SELECT COUNT(*) COUNT
	FROM ac000 [AC] INNER JOIN ac000 [FAC] ON [AC].FinalGUID = [FAC].GUID
	WHERE [FAC].IncomeType <= 3 AND [AC].IncomeType = 0 AND [AC].NSons = 0
	---------------------------------------------------------------------------------------
	IF (@ShowOwnerShipDetails = 1)
	BEGIN
		EXEC [repOwnersEquityMenue] @SrcGuid, @StartDate, @EndDate, @CostGUID, @StGUID, @Final, @DetailSubStores, @PriceType, @PricePolicy, @Posted, @Details, @Level, @AccDetails,	@CurPtr, @CurVal	
	END
###################################################################################
#END