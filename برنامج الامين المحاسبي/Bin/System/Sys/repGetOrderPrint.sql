##################################################################################
CREATE PROCEDURE repGetOrderPrint
	@CustGuid	[UNIQUEIDENTIFIER],
	@StoreGuid	[UNIQUEIDENTIFIER],
	@CostGuid	[UNIQUEIDENTIFIER],
	@BranchGuid	[UNIQUEIDENTIFIER],
	@StartDate	[DATETIME],
	@EndtDate	[DATETIME]	,
	@StartNum	[INT],
	@EndNum		[INT],
	@OrderType	[BIT],
	@OrderState	[BIT],
	@SearchByDate [BIT]
	
AS
	SET NOCOUNT ON
	DECLARE @OType INT


	DECLARE @UserGuid [UNIQUEIDENTIFIER]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SELECT 
		[GUID],
		[BrowsePostSec], 
		[ReadPriceSec],
		[BrowseUnPostSec],
		[btType]
	INTO [#Bt]
	FROM 
		[vwBt] AS [b]
	INNER JOIN  [dbo].[fnGetUserBillsSec2](@UserGuid) AS [fn] ON [fn].[GUID] = [b].[btGUID]
	WHERE [btType] = CASE WHEN @OrderType = 0 THEN 5 WHEN @OrderType = 1 THEN 6 END
	
	DECLARE @CurrentLanguage BIT = 0
    SET @CurrentLanguage = (SELECT dbo.fnConnections_GetLanguage())
	IF @SearchByDate = 0
	BEGIN
		SELECT  
				[bu].[Guid]					Guid,
				[bu].[Number]				Number,
				[bu].[Total] 				Total,
				[bu].[Date] 				OrderDate,
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
		INNER JOIN [ORADDINFO000] info ON [info].[ParentGuid] = [bu].[GUID]
		WHERE [BT].[btType] = CASE WHEN @OrderType = 0 THEN 5 WHEN @OrderType = 1 THEN 6 END
			AND [bu].[Number] BETWEEN  @StartNum AND @EndNum
			AND ([CustGUID] = @CustGuid OR @CustGuid = 0X0)
			AND ([StoreGUID] = @StoreGuid OR @StoreGuid = 0X0)
			AND ([bu].[CostGUID] = @CostGuid OR @CostGuid = 0X0)
			AND ([Branch] = @BranchGuid OR @BranchGuid = 0X0)
			AND (info.Finished = CASE WHEN @OrderState = 0 THEN 0 WHEN @OrderState = 1 THEN 1 END)
		ORDER BY [bu].[Date],[bu].[Number]
	END
	ELSE
	BEGIN
		SELECT 
				[bu].[Guid]					Guid,
				[bu].[Number]				Number,
				[bu].[Total] 				Total,
				[bu].[Date] 				OrderDate,
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
		INNER JOIN [ORADDINFO000] info ON [info].[ParentGuid] = [bu].[GUID]
		WHERE [BT].[btType] = CASE WHEN @OrderType = 0 THEN 5 WHEN @OrderType = 1 THEN 6 END
			AND [bu].[Date] BETWEEN  @StartDate AND @EndtDate
			AND ([CustGUID] = @CustGuid OR @CustGuid = 0X0)
			AND ([StoreGUID] = @StoreGuid OR @StoreGuid = 0X0)
			AND ([bu].[CostGUID] = @CostGuid OR @CostGuid = 0X0)
			AND ([Branch] = @BranchGuid OR @BranchGuid = 0X0)
  			AND (info.Finished = CASE WHEN @OrderState = 0 THEN 0 WHEN @OrderState = 1 THEN 1 END)
		ORDER BY [bu].[Date],[bu].[Number]
	END
##################################################################################
#END
