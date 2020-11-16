##########################################################################
CREATE PROCEDURE repGetBillPrint
	@BillType	[UNIQUEIDENTIFIER],
	@CustGuid	[UNIQUEIDENTIFIER],
	@StoreGuid	[UNIQUEIDENTIFIER],
	@CostGuid	[UNIQUEIDENTIFIER],
	@BranchGuid	[UNIQUEIDENTIFIER],
	@StartDate	[DATETIME],
	@EndtDate	[DATETIME]	,
	@StartNum	[INT],
	@EndNum		[INT],
	@SearchByDate [BIT]
	
AS
	SET NOCOUNT ON
	
	DECLARE @UserGuid [UNIQUEIDENTIFIER]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SELECT 
		[GUID],
		[BrowsePostSec], 
		[ReadPriceSec],
		[BrowseUnPostSec]
	INTO [#Bt]
	FROM 
		[vwBt] AS [b]
	INNER JOIN  [dbo].[fnGetUserBillsSec2](@UserGuid) AS [fn] ON [fn].[GUID] = [b].[btGUID]
	WHERE [Guid] = @BillType
	
	DECLARE @CurrentLanguage BIT = 0
    SET @CurrentLanguage = (SELECT dbo.fnConnections_GetLanguage())

	IF @SearchByDate = 0
	BEGIN
		SELECT  
				[bu].[Guid]					Guid,
				[bu].[Number]				Number,
				[bu].[Total] 				Total,
				[bu].[Date] 				BillDate,
				CASE @CurrentLanguage
                    WHEN 0 THEN [cu].[CustomerName]
                    ELSE [cu].[LatinName]
                END 						CustName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [co].[Name]
                    ELSE [co].[LatinName]
                END							CostName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [st].[Name]
                    ELSE [st].[LatinName]
                END 						StoreName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [br].[Name]
                    ELSE [cu].[LatinName]
                END							BranchName
		FROM [vcbu]  AS [bu] INNER JOIN [#Bt] AS [bt] ON [bu].[TypeGuid] = [bt].[GUID]
		LEFT JOIN [cu000] cu ON [cu].GUID = [bu].[CustGUID] 
		LEFT JOIN [co000] co ON [co].GUID = [bu].[CostGUID]
		LEFT JOIN [st000] st ON [st].GUID = [bu].[StoreGUID]
		LEFT JOIN [br000] br ON [br].GUID = [bu].[Branch]

		WHERE [TypeGuid] = @BillType
			AND [bu].[Number] BETWEEN  @StartNum AND @EndNum
			AND ([CustGUID] = @CustGuid OR @CustGuid = 0X0)
			AND ([StoreGUID] = @StoreGuid OR @StoreGuid = 0X0)
			AND ([bu].[CostGUID] = @CostGuid OR @CostGuid = 0X0)
			AND ([Branch] = @BranchGuid OR @BranchGuid = 0X0)
  			AND [bu].[Security] <= CASE [IsPosted] WHEN 0 THEN [BrowseUnPostSec] ELSE [BrowsePostSec] END
		ORDER BY [bu].[Date],[bu].[Number]
	END
	ELSE
	BEGIN
		SELECT 
				[bu].[Guid]					Guid,
				[bu].[Number]				Number,
				[bu].[Total] 				Total,
				[bu].[Date] 				BillDate,
				CASE @CurrentLanguage
                    WHEN 0 THEN [cu].[CustomerName]
                    ELSE [cu].[LatinName]
                END 						CustName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [co].[Name]
                    ELSE [co].[LatinName]
                END							CostName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [st].[Name]
                    ELSE [st].[LatinName]
                END 						StoreName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [br].[Name]
                    ELSE [cu].[LatinName]
                END							BranchName
		FROM [vcbu]  AS [bu] INNER JOIN [#Bt] AS [bt] ON [bu].[TypeGuid] = [bt].[GUID]
		LEFT JOIN [cu000] cu ON [cu].GUID = [bu].[CustGUID] 
		LEFT JOIN [co000] co ON [co].GUID = [bu].[CostGUID]
		LEFT JOIN [st000] st ON [st].GUID = [bu].[StoreGUID]
		LEFT JOIN [br000] br ON [br].GUID = [bu].[Branch]

		WHERE [TypeGuid] = @BillType
			AND [bu].[Date] BETWEEN  @StartDate AND @EndtDate
			AND ([CustGUID] = @CustGuid OR @CustGuid = 0X0)
			AND ([StoreGUID] = @StoreGuid OR @StoreGuid = 0X0)
			AND ([bu].[CostGUID] = @CostGuid OR @CostGuid = 0X0)
			AND ([Branch] = @BranchGuid OR @BranchGuid = 0X0)
  			AND [bu].[Security] <= CASE [IsPosted] WHEN 0 THEN [BrowseUnPostSec] ELSE [BrowsePostSec] END
		ORDER BY [bu].[Date],[bu].[Number]

	END
###############################################################################
CREATE PROCEDURE repGetTransPrint
	@TransType	[UNIQUEIDENTIFIER],
	@InAccGuid	[UNIQUEIDENTIFIER],
	@OutAccGuid	[UNIQUEIDENTIFIER],
	@InStoreGuid	[UNIQUEIDENTIFIER],
	@OutStoreGuid	[UNIQUEIDENTIFIER],
	@InCostGuid	[UNIQUEIDENTIFIER],
	@OutCostGuid	[UNIQUEIDENTIFIER],
	@BranchGuid	[UNIQUEIDENTIFIER],
	@StartDate	[DATETIME],
	@EndtDate	[DATETIME]	,
	@StartNum	[INT],
	@EndNum		[INT],
	@SearchByDate [BIT]
	
AS
	SET NOCOUNT ON
	
	DECLARE @UserGuid [UNIQUEIDENTIFIER]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SELECT 
		[tt].[GUID] [TransTypeGuid],
		[Inb].[btGuid] [InbtGuid],
		[Outb].[btGuid] [OutbtGuid],
		[BrowsePostSec], 
		[ReadPriceSec],
		[BrowseUnPostSec]
	INTO [#Bt]
	FROM 
		[vwBt] AS [Inb]
	INNER JOIN  [dbo].[fnGetUserBillsSec2](@UserGuid) AS [fn] ON [fn].[GUID] = [Inb].[btGUID]
	INNER JOIN [tt000] tt ON [tt].[InTypeGUID] = [Inb].[btGUID]
	INNER JOIN [vwBt] OutB ON [tt].[OutTypeGUID] = [OutB].[btGUID]
	WHERE [tt].[Guid] = @TransType
	
	DECLARE @CurrentLanguage BIT = 0
    SET @CurrentLanguage = (SELECT dbo.fnConnections_GetLanguage())

	IF @SearchByDate = 0
	BEGIN

		SELECT	
				[ts].[GUID]				Guid,
				[InBu].[Number]			Number,
				[Inbu].[Total]			Total,
				[InBu].[Date]			TransDate,
				CASE @CurrentLanguage
                    WHEN 0 THEN [InAcc].[Name]
                    ELSE [InAcc].[LatinName]
                END 						InAccName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [OutAcc].[Name]
                    ELSE [OutAcc].[LatinName]
                END 						OutAccName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [InSt].[Name]
                    ELSE [InSt].[LatinName]
                END 						InStoreName,
				CASE @CurrentLanguage
                   WHEN 0 THEN [OutSt].[Name]
                    ELSE [OutSt].[LatinName]
                END 						OutStoreName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [Inco].[Name]
                    ELSE [Inco].[LatinName]
                END 						InCostName,
				CASE @CurrentLanguage
                   WHEN 0 THEN [Outco].[Name]
                    ELSE [Outco].[LatinName]
                END 						OutCostName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [br].[Name]
                    ELSE [br].[LatinName]
                END							BranchName
		FROM [ts000] ts
		INNER JOIN [vcbu] InBu ON InBu.GUID = ts.InBillGUID
		INNER JOIN [vcbu] OutBu ON OutBu.GUID = ts.OutBillGUID
		INNER JOIN [#Bt] AS [Inbt] ON [Inbu].[TypeGuid] = [Inbt].[InbtGUID]
		INNER JOIN [#Bt] AS [Outbt] ON [Outbu].[TypeGuid] = [Outbt].[OutbtGUID]
		INNER JOIN [tt000] AS [tt] ON [tt].[InTypeGUID] = [Inbt].[InbtGUID]
		LEFT JOIN [co000] Inco ON [Inco].GUID = [InBu].[CostGUID]
		LEFT JOIN [co000] Outco ON [Outco].GUID = [OutBu].[CostGUID]
		LEFT JOIN [st000] InSt ON [InSt].GUID = [InBu].[StoreGUID]
		LEFT JOIN [st000] OutSt ON [OutSt].GUID = [OutBu].[StoreGUID]
		LEFT JOIN [ac000] InAcc ON [InAcc].GUID = [InBu].[MatAccGUID]
		LEFT JOIN [ac000] OutAcc ON [OutAcc].GUID = [OutBu].[MatAccGUID]
		LEFT JOIN [br000] br ON [br].GUID = [Inbu].[Branch]
		WHERE [tt].[GUID] = @TransType
			AND ([InBu].[Number] BETWEEN  @StartNum AND @EndNum)
			AND ([Inbu].[CostGUID] = @InCostGuid OR @InCostGuid = 0X0)
			AND ([Outbu].[CostGUID] = @OutCostGuid OR @OutCostGuid = 0X0)
			AND ([InBu].[StoreGUID] = @InStoreGuid OR @InStoreGuid = 0X0)
			AND ([OutBu].[StoreGUID] = @OutStoreGuid OR @OutStoreGuid = 0X0)
			AND ([InBu].[MatAccGUID] = @InAccGuid OR @InAccGuid = 0X0)
			AND ([OutBu].[MatAccGUID] = @OutAccGuid OR @OutAccGuid = 0X0)
			AND ([InBu].[Branch] = @BranchGuid OR @BranchGuid = 0X0)
  			AND [Inbu].[Security] <= CASE [InBu].[IsPosted] WHEN 0 THEN [Inbt].[BrowseUnPostSec] ELSE [Inbt].[BrowsePostSec] END
		ORDER BY [Inbu].[Date],[Inbu].[Number]
		
	END
	ELSE
	BEGIN
	
			SELECT	
				[ts].[GUID]				Guid,
				[InBu].[Number]			Number,
				[Inbu].[Total]			Total,
				[InBu].[Date]			TransDate,
				CASE @CurrentLanguage
                    WHEN 0 THEN [InAcc].[Name]
                    ELSE [InAcc].[LatinName]
                END 						InAccName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [OutAcc].[Name]
                    ELSE [OutAcc].[LatinName]
                END 						OutAccName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [InSt].[Name]
                    ELSE [InSt].[LatinName]
                END 						InStoreName,
				CASE @CurrentLanguage
                   WHEN 0 THEN [OutSt].[Name]
                    ELSE [OutSt].[LatinName]
                END 						OutStoreName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [Inco].[Name]
                    ELSE [Inco].[LatinName]
                END 						InCostName,
				CASE @CurrentLanguage
                   WHEN 0 THEN [Outco].[Name]
                    ELSE [Outco].[LatinName]
                END 						OutCostName,
				CASE @CurrentLanguage
                    WHEN 0 THEN [br].[Name]
                    ELSE [br].[LatinName]
                END							BranchName
		FROM [ts000] ts
		INNER JOIN [vcbu] InBu ON InBu.GUID = ts.InBillGUID
		INNER JOIN [vcbu] OutBu ON OutBu.GUID = ts.OutBillGUID
		INNER JOIN [#Bt] AS [Inbt] ON [Inbu].[TypeGuid] = [Inbt].[InbtGUID]
		INNER JOIN [#Bt] AS [Outbt] ON [Outbu].[TypeGuid] = [Outbt].[OutbtGUID]
		INNER JOIN [tt000] AS [tt] ON [tt].[InTypeGUID] = [Inbt].[InbtGUID]
		LEFT JOIN [co000] Inco ON [Inco].GUID = [InBu].[CostGUID]
		LEFT JOIN [co000] Outco ON [Outco].GUID = [OutBu].[CostGUID]
		LEFT JOIN [st000] InSt ON [InSt].GUID = [InBu].[StoreGUID]
		LEFT JOIN [st000] OutSt ON [OutSt].GUID = [OutBu].[StoreGUID]
		LEFT JOIN [ac000] InAcc ON [InAcc].GUID = [InBu].[MatAccGUID]
		LEFT JOIN [ac000] OutAcc ON [OutAcc].GUID = [OutBu].[MatAccGUID]
		LEFT JOIN [br000] br ON [br].GUID = [Inbu].[Branch]
		WHERE [tt].[GUID] = @TransType
			AND(([InBu].[Date] BETWEEN  @StartDate AND @EndtDate))
			AND ([Inbu].[CostGUID] = @InCostGuid OR @InCostGuid = 0X0)
			AND ([Outbu].[CostGUID] = @OutCostGuid OR @OutCostGuid = 0X0)
			AND ([InBu].[StoreGUID] = @InStoreGuid OR @InStoreGuid = 0X0)
			AND ([OutBu].[StoreGUID] = @OutStoreGuid OR @OutStoreGuid = 0X0)
			AND ([InBu].[MatAccGUID] = @InAccGuid OR @InAccGuid = 0X0)
			AND ([OutBu].[MatAccGUID] = @OutAccGuid OR @OutAccGuid = 0X0)
			AND ([InBu].[Branch] = @BranchGuid OR @BranchGuid = 0X0)
  			AND [Inbu].[Security] <= CASE [InBu].[IsPosted] WHEN 0 THEN [Inbt].[BrowseUnPostSec] ELSE [Inbt].[BrowsePostSec] END
		ORDER BY [Inbu].[Date],[Inbu].[Number]
	END

###############################################################################
#END