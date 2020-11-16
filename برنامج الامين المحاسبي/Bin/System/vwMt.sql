#########################################################
CREATE VIEW vtMt
AS
	SELECT * FROM [mt000]

#########################################################
CREATE VIEW vbMt
AS
	SELECT [v].*
	FROM [vtMt] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcMt
AS
	SELECT * FROM vbMt

#########################################################
CREATE VIEW vdMt
AS
	SELECT 
		[mt].*, 
		[gr].[Code] AS [grCode], 
		[gr].[Name] AS [grName], 
		[gr].[LatinName] AS [grLatinName]
	FROM 
		[vbMt] AS [mt] INNER JOIN [vbGr] AS [gr] ON [mt].[GroupGUID] = [gr].[GUID] 

#########################################################
CREATE VIEW vdMt2
AS
	SELECT 
		[mt].*, 
		[dbo].[fnMaterial_getQty_withUnPosted]([mt].[guid]) AS [Qty0]
	FROM 
		[vdMt] AS [mt] INNER JOIN [vbGr] AS [gr] ON [mt].[GroupGUID] = [gr].[GUID] 
#########################################################
CREATE VIEW vdMt3
AS
SELECT 
	mt.[Number],
	mt.[Name] ,
	mt.[Code] ,
	mt.[LatinName],
	mt.[CompositionName],
	mt.[CompositionLatinName],
	mx.[BarCode] AS BarCode,--CASE mx.MatUnit WHEN 1 THEN mx.[BarCode] ELSE '' END AS BarCode ,
	[CodedCode] ,
	mt.[Unity] AS  Unity,
	[Spec],
	[Qty],
	[High],
	[Low],
	[Whole],
	[Half],
	[Retail],
	[EndUser],
	[Export],
	[Vendor],
	[MaxPrice],
	[AvgPrice] ,
	[LastPrice] ,
	[PriceType],
	[SellType] ,
	[BonusOne],
	[CurrencyVal],
	[UseFlag],
	[Origin] ,
	[Company],
	mt.[Type] ,
	mt.[Security],
	[LastPriceDate],
	[Bonus],
	[Unit2] ,
	[Unit2Fact],
	[Unit3] ,
	[Unit3Fact],
	[Flag] ,
	[Pos] ,
	[Dim],
	[ExpireFlag],
	[ProductionFlag],
	[Unit2FactFlag],
	[Unit3FactFlag],
	mx.[BarCode] AS BarCode2,--CASE mx.MatUnit WHEN 2 THEN mx.[BarCode] ELSE '' END AS BarCode2,
	mx.[BarCode] AS BarCode3,--CASE mx.MatUnit WHEN 3 THEN mx.[BarCode] ELSE '' END AS BarCode3,
	[SNFlag] ,
	[ForceInSN] ,
	[ForceOutSN],
	mt.[VAT] ,
	[Color],
	[Provenance] ,
	[Quality],
	[Model] ,
	[Whole2],
	[Half2] ,
	[Retail2] ,
	[EndUser2] ,
	[Export2] ,
	[Vendor2],
	[MaxPrice2],
	[LastPrice2],
	[Whole3] ,
	[Half3] ,
	[Retail3] ,
	[EndUser3],
	[Export3] ,
	[Vendor3],
	[MaxPrice3] ,
	[LastPrice3] ,
	mt.[GUID],
	[GroupGUID] ,
	mt.[PictureGUID],
	[CurrencyGUID],
	[DefUnit] ,
	[bHide] ,
	mt.[branchMask] ,
	[OldGUID] ,
	[NewGUID] ,
	[Assemble]  ,
	[OrderLimit]  ,
	[CalPriceFromDetail],
	[ForceInExpire] ,
	[ForceOutExpire] ,
	[CreateDate],
	[IsIntegerQuantity],
	[gr].[Code] AS [grCode], 
	[gr].[Name] AS [grName], 
	[gr].[LatinName] AS [grLatinName],
	ISNULL(mx.MatUnit, mt.DefUnit) AS Unit,
	mt.[HasSegments]
 FROM 
	[mt000] [mt] LEFT JOIN [MatExBarcode000] mx ON [mt].Guid = mx.MatGuid  
	INNER JOIN [vbGr] AS [gr] ON [mt].[GroupGUID] = [gr].[GUID] 
#########################################################
CREATE VIEW vwMt 
AS 
	SELECT 
		[GUID] as [mtGUID], 
		[Number] AS [mtNumber], 
		[Name] AS [mtName], 
		[Code] AS [mtCode], 
		[LatinName] AS [mtLatinName], 
		[BarCode] AS [mtBarCode], 
		[CodedCode] AS [mtCodedCode], 
		[GroupGUID] AS [mtGroup], 
		[Unity] AS [mtUnity], 
		[Spec] AS [mtSpec], 
		[Qty] AS [mtQty], 
		[High] AS [mtHigh], 
		[Low] AS [mtLow], 
		[OrderLimit] AS [mtOrder], 
		[Whole] AS [mtWhole], 
		[Half] AS [mtHalf], 
		[Vendor] AS [mtVendor], 
		[Export] AS [mtExport], 
		[Retail]	AS [mtRetail], 
		[EndUser] AS [mtEndUser], 
		[MaxPrice] AS [mtMaxPrice], 
		[AvgPrice] AS [mtAvgPrice], 
		[LastPrice] AS [mtLastPrice], 
		[Whole2] AS [mtWhole2], 
		[Half2] AS [mtHalf2], 
		[Vendor2]	AS [mtVendor2], 
		[Export2] AS [mtExport2], 
		[Retail2]	AS [mtRetail2], 
		[EndUser2] AS [mtEndUser2], 
		[MaxPrice2] AS [mtMaxPrice2], 
		[LastPrice2] AS [mtLastPrice2], 
		[Whole3] AS [mtWhole3], 
		[Half3] AS [mtHalf3], 
		[Vendor3]	AS [mtVendor3], 
		[Export3] AS [mtExport3], 
		[Retail3]	AS [mtRetail3], 
		[EndUser3] AS [mtEndUser3], 
		[MaxPrice3] AS [mtMaxPrice3], 
		[LastPrice3] AS [mtLastPrice3],		 
		[PriceType] AS [mtPriceType], 
		[SellType] AS [mtSellType], 
		[BonusOne] AS [mtBonusOne], 
		[PictureGUID] AS [mtPicture], 
		[CurrencyVal] AS [mtCurrencyVal], 
		[CurrencyGUID] AS [mtCurrencyPtr], 
		[UseFlag] AS [mtUseFlag], 
		[Origin] AS [mtOrigin], 
		[Company] AS [mtCompany], 
		[Type] AS [mtType], 
		[Security] AS [mtSecurity], 
		[LastPriceDate] AS [mtLastPriceDate], 
		[Bonus] AS [mtBonus], 
		[Unit2] AS [mtUnit2], 
		[Unit2Fact] AS [mtUnit2Fact], 
		[Unit3] AS [mtUnit3], 
		[Unit3Fact] AS [mtUnit3Fact], 
		[Flag] AS [mtFlag], 
		[Pos] AS [mtPos], 
		[Dim] AS [mtDim], 
		(CASE [DefUnit] 
			WHEN 2 THEN [Unit2Fact] 
			WHEN 3 THEN [Unit3Fact] 
			ELSE 1 
		END) AS [mtDefUnitFact], 
		(CASE [DefUnit] 
			WHEN 2 THEN [Unit2] 
			WHEN 3 THEN [Unit3] 
			ELSE [Unity] 
		END) AS [mtDefUnitName], 
		[DefUnit] AS [mtDefUnit], 
		[ExpireFlag] AS [mtExpireFlag], 
		[ProductionFlag] AS [mtProductionFlag], 
		[Unit2FactFlag] AS [mtUnit2FactFlag], 
		[Unit3FactFlag] AS [mtUnit3FactFlag], 
		[BarCode2] AS [mtBarCode2], 
		[BarCode3] AS [mtBarCode3], 
		[SNFlag] AS [mtSNFlag], 
		[ForceInSN] AS [mtForceInSN], 
		[ForceOutSN] AS [mtForceOutSN], 
		[VAT] AS [mtVat], 
		[Color] AS [mtColor], 
		[Provenance] AS [mtProvenance], 
		[Quality] AS [mtQuality], 
		[Model] AS [mtModel],
		[branchMask] AS [brBranchMask],
		[IsIntegerQuantity],
		DisableLastPrice AS mtDisableLastPrice,
		LastPriceCurVal AS mtLastPriceCurVal,
		FirstCostDate AS FirstCostDate,
		bHide AS mtHide,
		
		HasSegments AS mtHasSegments,
		Parent AS mtParent,
		CompositionName AS mtCompositionName,
		CompositionLatinName AS mtCompositionLatinName
	FROM 
		[vbMt]
#########################################################
CREATE VIEW vwMaterials
AS
	SELECT * FROM [vcMt] WHERE ISNULL(Parent, 0x0) = 0x0
#########################################################
CREATE VIEW vwMatSegManagementDetails
AS
	SELECT
		[sg].*,
		[ms].SegmentId
	FROM 
		MaterialsSegmentsManagement000 AS ms inner join Segments000 as sg on sg.Id = SegmentId
#########################################################

#END
