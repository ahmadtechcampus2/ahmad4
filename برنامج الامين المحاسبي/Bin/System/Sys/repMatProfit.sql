###########################################
CREATE PROCEDURE repMatProfit
	@StartDate 		[DATETIME], 
	@EndDate 		[DATETIME], 
	@SrcTypesguid	[UNIQUEIDENTIFIER], 
	@GroupGUID 		[UNIQUEIDENTIFIER], 
	@CostGUID 		[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs  
	@CurrencyGUID 	[UNIQUEIDENTIFIER], 
	@MatCondGuid 	[UNIQUEIDENTIFIER] = 0X00, 
	@UseUnit		[INT] = 3, 
	@profitWithTax  [BIT] = 0
AS 
	SET NOCOUNT ON 
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#MatTbl2] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] INT, [mtCode] NVARCHAR(256),
				[mtName] NVARCHAR(500), [mtLatinName] NVARCHAR(500), [UnitFact] FLOAT, [UnitName] NVARCHAR(256))
	--Filling temporary tables 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		0x0/*@MatGUID*/, @GroupGUID,-1,@MatCondGuid 
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	@SrcTypesguid--, @UserGuid 
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID 
	IF @CostGUID = 0X00 
		INSERT INTO [#CostTbl] VALUES(0X00,0) 
	INSERT INTO [#MatTbl2] 
	SELECT [MatGUID], [mtSecurity],[Code] AS [mtCode],[Name] AS [mtName], [LatinName], 
	CASE @UseUnit  
		WHEN 0 THEN 1  
		WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END 
		WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END 
		ELSE  
			CASE [DefUnit] 
				WHEN 1 THEN 1  
				WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END 
				ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
			END 
		END AS [UnitFact] 
	, 
	CASE @UseUnit  
		WHEN 0 THEN Unity  
		WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN Unity ELSE [Unit2] END 
		WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN Unity ELSE [Unit3] END 
		ELSE  
			CASE [DefUnit] 
				WHEN 1 THEN Unity  
				WHEN 2 THEN [Unit2] 
				WHEN 3 THEN [Unit3] 
			END 
		END AS [UnitName] 
	FROM [#MatTbl] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [m].[MatGUID] 
	 
	CREATE TABLE [#Result] 
	( 	 
		[matGUID]				[UNIQUEIDENTIFIER],	 
		[matCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[matName]				[NVARCHAR](500) COLLATE ARABIC_CI_AI, 
		[matLatinName]			[NVARCHAR](500) COLLATE ARABIC_CI_AI, 
		[FixedBiProfits]		[FLOAT], 
		[Security]				[INT], 
		[UserSecurity] 			[INT], 
		[UserReadPriceSecurity]	[INT], 
		[MatSecurity]			[INT], 
		[QTY]					[FLOAT], 
		[UnitName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI  
	) 
	DECLARE @VAT INT
	DECLARE @TTC INT
	SET @VAT = 1
	SET @TTC = 2
	INSERT INTO [#Result] 
	SELECT  
		[rv].[biMatPtr], 
		[mtTbl].[mtCode], 
		[mtTbl].[mtName], 
		[mtTbl].[mtLatinName], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN (CASE @profitWithTax WHEN 1 THEN 
		                                                                               [rv].[FixedBiProfits] + [rv].[FixedBiVAT]
																					ELSE
																					   [rv].[FixedBiProfits] END) * (-[rv].[buDirection]) ELSE 0 END AS [FixedBiProfits],  
		[rv].[buSecurity], 
	 
		CASE [rv].[buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnPostedSecurity] END, 
		[bt].[UserReadPriceSecurity], 
		[mtTbl].[mtSecurity], 
		[biQty]*(-[rv].[buDirection]) / [UnitFact],[UnitName] 
	FROM 
		[dbo].[fn_bubi_Fixed]( @CurrencyGUID) AS [rv] 
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [rv].[buType] = [bt].[TypeGUID] 
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGuid] 
		INNER JOIN [#CostTbl] AS [co] ON [rv].[BiCostPtr]  = [co].[CostGUID] 
	WHERE 
		([rv].[Budate] BETWEEN @StartDate AND @EndDate) 
	 
	---check sec 
	EXEC [prcCheckSecurity] 
	--- return result set 
	SELECT 
		[rv].[matGUID], 		
		[rv].[matCode], 
		[rv].[matName], 
		[rv].[matLatinName], 
		SUM( [rv].[FixedBiProfits]) AS [SumBiProfits], 
		CASE SUM([QTY]) WHEN 0 THEN 0 ELSE SUM( [rv].[FixedBiProfits]) /SUM([QTY]) END AS [UnitProfits], 
		[UnitName] 
	FROM 
		[#Result] AS [rv] 
	WHERE 
		[UserSecurity] >= [Security] 
	GROUP BY 
		[rv].[matGUID], 
		[rv].[matCode], 
		[rv].[matName], 
		[rv].[matLatinName], 
		[UnitName] 
	ORDER BY 
		[SumBiProfits] DESC 

	SELECT * FROM [#SecViol] 
/* 
prcConnections_add2 '„œÌ—' 
exec [RepMatProfit] '8/28/2007', '9/27/2007', '215110bd-7413-4867-a285-2c6b8312477b', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '04b7552d-3d32-47db-b041-50119e80dd52', 1.000000, '00000000-0000-0000-0000-000000000000', 0 
*/ 
##############################
#END
