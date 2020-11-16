################################################################################
CREATE PROCEDURE repGetAssembleMaterials
	@MatGUID			UNIQUEIDENTIFIER = 0x0,
	@GroupGUID			UNIQUEIDENTIFIER = 0x0,
	@MatCondGUID		UNIQUEIDENTIFIER = 0x0,
	@CurrencyGUID		UNIQUEIDENTIFIER = 0X0,
	@PriceType			INT = 2 ,
	@PricePolicy		INT = 121
AS 
	SET NOCOUNT ON
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MatGUID, @GroupGUID, -1, @MatCondGUID
	CREATE TABLE [#Result]
	(
		[MatGuid] 			[UNIQUEIDENTIFIER],  
		[MatSecurity]		[INT]
	)
	
	INSERT INTO [#Result]
	SELECT 
		[mt].[mtGuid],
		[mt].[mtSecurity]
	FROM 
		[vwmt] [mt]
		INNER JOIN [#MatTbl] [tbl] ON [tbl].[MatGuid] = [mt].[mtGuid]
		INNER JOIN [mt000] [m] ON [m].[Guid] = [mt].[mtGuid]
	WHERE 
		[m].[Assemble] = 1

	EXEC [prcCheckSecurity]

	CREATE TABLE [#DetailsResult]
	(  
		[mtMasterGuid]			UNIQUEIDENTIFIER,
		[mtDetailsGUID]			UNIQUEIDENTIFIER,
		[mtDetailsCode]			NVARCHAR(100),
		[mtDetailsName]			NVARCHAR(250),
		[mtDetailsQty]			FLOAT,
		[mtDetailsUsedUnit]		INT,
		[mtDetailsUnity]		NVARCHAR(100),
		[mtDetailsFlexible]		INT,
		[mtDetailsRequired]		INT,
	) 	
	
	INSERT INTO [#DetailsResult] ([mtMasterGuid], [mtDetailsGUID], [mtDetailsCode], [mtDetailsName], [mtDetailsQty], [mtDetailsUsedUnit], [mtDetailsUnity], [mtDetailsFlexible], [mtDetailsRequired])
	SELECT 
		[r].[MatGuid] AS [mtMasterGuid],
		[md].[MatGUID] AS [mtDetailsGUID],
		[mt].[mtCode] AS [mtDetailsCode],
		(CASE [dbo].[fnConnections_GetLanguage]() 
			WHEN 0 THEN [mt].[mtName] 
			ELSE [mt].[mtLatinName] 
		END) AS [mtDetailsName],
		[md].[Qty] AS [mtDetailsQty],	

		[md].[Unity] - 1 AS [mtDetailsUsedUnit],	
		(CASE [md].[Unity]
			WHEN 2 THEN [mt].[mtUnit2] 
			WHEN 3 THEN [mt].[mtUnit3]
			ELSE [mt].[mtUnity]
		END) AS [mtDetailsUnity],
		[md].[bFlexible] AS [mtDetailsFlexible],
		[md].[bRequired] AS [mtDetailsRequired]  	 
	FROM 
		[#Result] [r]
		INNER JOIN [md000] [md] ON [md].[ParentGuid] = [r].[MatGuid]
		INNER JOIN [vwmt] [mt] ON [mt].[mtGuid] = [md].[MatGuid]
	ORDER BY
		[md].[Number]

	CREATE TABLE [#MasterResult_NoPrice]
	(  
		[mtMasterGuid] 			UNIQUEIDENTIFIER,  
		[mtMasterCode]			NVARCHAR(100),
		[mtMasterName]			NVARCHAR(250)
	) 	
	
	INSERT INTO [#MasterResult_NoPrice]
	SELECT 
		[r].[MatGuid] AS [mtMasterGuid],
		[m].[mtCode] AS [mtMasterCode],	
		(CASE [dbo].[fnConnections_GetLanguage]() 
			WHEN 0 THEN [m].[mtName] 
			ELSE [m].[mtLatinName] 
		END) AS [mtMasterName]  	 
	FROM 
		[#Result] [r]
		INNER JOIN [vwmt] [m] ON [m].[mtGuid] = [r].[MatGuid]
	ORDER BY
		[m].[mtCode]
		
	DECLARE @CurVal float 

	SELECT TOP 1 @CurVal = [CurrencyVal] FROM [mh000] WHERE [CurrencyGUID] = @CurrencyGUID AND [Date] <= GETDATE() ORDER BY [Date] DESC
	IF (ISNULL(@CurVal, 0) = 0)
	SELECT @CurVal = [CurrencyVal] FROM [my000] WHERE [GUID] = @CurrencyGUID

	CREATE TABLE [#t_Prices] 
	( 
		[MatGUID] 	[UNIQUEIDENTIFIER],
		[mtDetailsPrice] 	[FLOAT],
		[unit]				[INT]
	) 

	DECLARE @Count [INT]
	SET @Count = 0
	WHILE (@Count < 3)
	BEGIN
		Delete from [#MatTbl]
		INSERT INTO [#MatTbl]
		SELECT [mtDetailsGUID], [mtSecurity]
		FROM [#DetailsResult] [d] INNER JOIN [vwmt] [m] ON [m].[mtGuid] = [d].[mtDetailsGUID]
		WHERE [d].mtDetailsUsedUnit = @Count
		IF (@@rowcount > 0) 
		BEGIN
			INSERT INTO [#t_Prices]
			Select [mtGUID], [fixedPrice], @count from dbo.fnExtended_mt_fixed (@PriceType, @PricePolicy, @Count, @CurrencyGUID, DEFAULT)
		END
		SET @Count = @Count + 1
	END
	SELECT 		
		[mtMasterGuid],
		[mtDetailsGUID],
		[mtDetailsCode],
		[mtDetailsName],
		[mtDetailsQty],
		[mtDetailsUsedUnit],
		[mtDetailsUnity],
		[mtDetailsFlexible],
		[mtDetailsRequired],
		[mtDetailsPrice],
		[mtDetailsQty]*[mtDetailsPrice] AS [mtDetailsValue]
	FROM
 		[#t_Prices] 
		INNER JOIN [#DetailsResult] ON [MatGUID] = [mtDetailsGUID] AND [unit] = mtDetailsUsedUnit

	SELECT 
		[m].[mtMasterGuid],
		[mtMasterCode],
		[mtMasterName],
		SUM([mtDetailsQty] * [mtDetailsPrice]) mtTotalValue
	FROM
		[#DetailsResult] [d] 
		INNER JOIN [#MasterResult_NoPrice] [m] ON [d].[mtMasterGuid] = [m].[mtMasterGuid] 
		INNER JOIN [#t_Prices] [p] ON [d].[mtDetailsGUID] = [p].[MatGUID] AND [unit] = mtDetailsUsedUnit
	GROUP BY
		[m].[mtMasterGuid],
		[mtMasterCode],
		[mtMasterName]
	
	SELECT * FROM [#SecViol]
###################################################################################
#END
