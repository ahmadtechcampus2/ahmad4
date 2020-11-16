#########################################################
CREATE FUNCTION fnIsMatBonusUsed( @GUID UNIQUEIDENTIFIER)
	RETURNS BIT 
AS 
BEGIN 
	IF EXISTS( SELECT top 1 [guid] FROM [bi000] WHERE [soGuid] = @GUID)
		RETURN 1
	RETURN 0
END 

#########################################################
CREATE VIEW vtSm
AS
	SELECT * FROM [sm000]

#########################################################
CREATE VIEW vbSm
AS
	SELECT [v].*
	FROM [vtSm] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcSm
AS
	SELECT * FROM [vbSm]

#########################################################
CREATE VIEW vdSm
AS
	SELECT * FROM [vbSm]
	
#########################################################
CREATE VIEW vwSm
AS
	SELECT 
		[Type] AS [smType], 
		[Number] AS [smNumber], 
		[Qty] AS [smQty], 
		[Unity] AS [smUnity], 
		[StartDate] AS [smStartDate], 
		[bAddMain] AS [smbAddMain],
		[EndDate] AS [smEndDate], 
		[Notes] AS [smDescription], 
		[GUID] AS [smGUID], 
		[MatGUID] AS [smMatGUID], 
		[GroupGUID] AS [smGroupGUID], 
		[bIncludeGroups] AS [smIncludeGroups], 
		[PriceType] AS [smPriceType], 
		[Discount] AS [smDiscount], 
		[CustAccGUID] AS [smCustAccGUID], 
		[OfferAccGUID] AS [smOfferAccGUID], 
		[bAllBt] AS [smAllBillTypes], 
		[IOfferAccGUID] AS [smIOfferAccGUID],
		[MatCondGUID] AS [smMatCondGUID],
		[CustCondGUID] AS [smCustCondGUID],
		[CostGUID] AS [smCostGUID],
		[bActive] AS [smActive],
		[ClassStr] AS [smClassStr],
		[GroupStr] AS [smGroupStr],
		[dbo].[fnIsMatBonusUsed]( [GUID]) AS [IsUsed],
		[branchMask] AS [smBranchMask],
		[DiscountType] AS [smDiscountType]
	FROM  
		[vbSm]
	
#########################################################
CREATE VIEW vwSmSd
AS
	SELECT
		[sm].*,
		ISNULL([sd].[GUID], 0X0) AS [sdGUID],
		ISNULL([sd].[Item],0)  AS [sdItem],
		ISNULL([sd].[MatGUID], 0X0) AS [sdMatPtr],
		ISNULL([sd].[Qty], 0) AS [sdQty],
		ISNULL([sd].[Unity], 1) AS [sdUnity],
		ISNULL([sd].[Price], 0) AS [sdPrice],
		ISNULL([sd].[Notes], '') AS [sdNotes],
		ISNULL([sd].[PriceFlag], 0) AS [sdPriceFlag],
		ISNULL([sd].[CurrencyGUID], 0X0) AS [sdCurrencyPtr],
		ISNULL([sd].[CurrencyVal], 1) AS [sdCurrencyVal],
		ISNULL([sd].[PolicyType], 0) AS [sdPolicyType],
		ISNULL([sd].[bBonus], 0) AS [sdBonus]

	FROM
		[vwSm] [sm] 
		LEFT JOIN [sd000] as [sd] ON [sm].[smGUID] = [sd].[ParentGUID]


#########################################################
CREATE VIEW vwExtended_Sm
AS
	SELECT 
		[sm].*,
		ISNULL( [sd].[Item], 0) AS [sdOrder],
		ISNULL( [sd].[Qty], 0) AS [sdQty], 
		ISNULL( [sd].[Unity], 1) AS [sdUnity],
		ISNULL( [sd].[Price], 0) AS [sdPrice],
		ISNULL( [sd].[Notes], '') AS [sdNotes],
		ISNULL( [sd].[PriceFlag], 0) AS [sdPriceFlag],
		ISNULL( [sd].[CurrencyVal], 1) AS [sdCurrencyVal],
		ISNULL( [sd].[PolicyType], 0) AS [sdPolicyType],
		ISNULL( [sd].[MatGUID], 0x0) AS [sdMatGUID],
		ISNULL( [sd].[CurrencyGUID], 0x0) AS [sdCurrencyGUID],
		ISNULL( [sd].[bBonus], 0) AS [sdBonus],
		ISNULL( [mt].[Name], '') AS [mtName],
		ISNULL( [mt].[Code], '') AS [mtCode],
		( CASE ISNULL( [sd].[Unity], 0) 
			WHEN 0 THEN ''  
			WHEN 1 THEN ISNULL( [mt].[Unity], '')
			WHEN 2 THEN ISNULL( [mt].[Unit2], '')
			WHEN 3 THEN ISNULL( [mt].[Unit3], '')
		END) AS [mtUnitName]
	FROM 
		[vwSm] [sm]
		LEFT JOIN [sd000] [sd] ON [sm].[smGUID] = [sd].[ParentGUID]
		LEFT JOIN [mt000] [mt] ON [mt].[GUID] = [sd].[MatGUID] 

#########################################################
CREATE FUNCTION fnGetSpecialOffersTree()
	RETURNS TABLE
AS
	RETURN (
		SELECT 
			[GUID], 
			0x0 AS [ParentGUID], 
			'' AS [Code], 
			[Name], 
			[LatinName], 
			'sm000' AS [tableName], 
			0 AS [branchMask], 
			16 AS [SortNum], 
			141 AS [IconID], 
			'.' AS [Path], 
			0 AS [Level]  
		FROM 
			[brt] 
		WHERE 
			[tableName] = 'sm000'
		
		UNION ALL
		
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Notes],
			[t].[Notes],
			[t].[Notes],
			'sm000',
			[t].[branchMask],
			0,
			142,
			'.' AS [Path], 
			1 AS [Level]
		FROM	
			[sm000] AS [t] 
			INNER JOIN [brt] AS [b] ON [b].[tableName] = 'sm000')
#########################################################
CREATE FUNCTION fnGetPOSSpecialOffersTree()
	RETURNS TABLE
AS
	RETURN (
		SELECT 
			[GUID], 
			0x0 AS [ParentGUID], 
			' ' AS [Code], 
			[Name], 
			[LatinName], 
			'SpecialOffer000' AS [tableName], 
			0 AS [branchMask], 
			16 AS [SortNum], 
			141 AS [IconID], 
			'.' AS [Path], 
			0 AS [Level]  
		FROM 
			[brt] 
		WHERE 
			[tableName] = 'SpecialOffer000'
		
		UNION ALL
		
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			'' AS [Code],
			[t].[Name],
			[t].[Name],
			'SpecialOffer000',
			[t].[branchMask],
			0,
			142,
			'.' AS [Path], 
			1 AS [Level]
		FROM	
			SpecialOffer000 AS [t] 
			INNER JOIN [brt] AS [b] ON [b].[tableName] = 'SpecialOffer000')
#########################################################
#END
