#########################################################
CREATE VIEW vwBiMt
AS
	SELECT
		[bi].[biGUID],
		[bi].[biParent],
		[bi].[biNumber],
		[bi].[biStorePtr],
		[bi].[biNotes],
		[bi].[biUnity],
		[bi].[biMatPtr],
		[bi].[biPrice],
		[bi].[biCurrencyPtr],
		[bi].[biCurrencyVal],
		[bi].[biDiscount],
		[bi].[biBonusDisc],
		[bi].[biExtra],
		[bi].[biVAT],
		[bi].[biVATr],
		[bi].[biQty],
		(CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN [bi].[biQty] / (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END) ELSE [bi].[biQty2] END) AS [biQty2],
		(CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN [bi].[biQty] / (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END) ELSE [bi].[biQty3] END) AS [biQty3],
		(CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 0 ELSE [bi].[biQty] / [mt].[mtUnit2Fact] END) ELSE [bi].[biQty2] END) AS [biCalculatedQty2], -- this should be deleted
		(CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE [bi].[biQty] / [mt].[mtUnit3Fact] END) ELSE [bi].[biQty3] END) AS [biCalculatedQty3], -- this should be deleted
		[bi].[biBonusQnt],
		[bi].[biProfits],
		[bi].[biUnitCostPrice],
		[bi].[biExpireDate],
		[bi].[biProductionDate],
		[bi].[biCostPtr],
		[bi].[biClassPtr],
		[bi].[biLength],
		[bi].[biWidth],
		[bi].[biHeight],
		[bi].[biCount],
		[bi].[biSOType],
		[bi].[biSOGuid],
		bi.biTotalDiscountPercent,
		bi.biTotalExtraPercent,
		bi.biTaxCode,
		bi.biExciseTaxVal,
		bi.biExciseTaxPercent,
		bi.biPurchaseVal,
		bi.biReversChargeVal,
		bi.biExciseTaxCode,
		bi.biLCDisc,
		bi.biLCExtra,
		bi.biCustomsRate,
		bi.[biTotalTaxValue],
		[bi].[biOrginalTaxCode],
		(CASE [biUnity]
			WHEN 2 THEN [bi].[biQty] / (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END)
			WHEN 3 THEN [bi].[biQty] / (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END)
			ELSE [bi].[biQty]
		END) AS [biBillQty],
		(CASE [biUnity]
			WHEN 2 THEN [bi].[biBonusQnt] / (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END)
			WHEN 3 THEN [bi].[biBonusQnt] / (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END)
			ELSE [bi].[biBonusQnt]
		END) AS [biBillBonusQnt],
		(CASE [bi].[biUnity]
				WHEN 2 THEN (CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN [mt].[mtUnit2Fact] ELSE [biQty] / (CASE [biQty2] WHEN 0 THEN 1 ELSE [biQty2] END) END)
				WHEN 3 THEN (CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN [mt].[mtUnit3Fact] ELSE [biQty] / (CASE [biQty3] WHEN 0 THEN 1 ELSE [biQty3] END) END)
				ELSE 1
		END) AS [mtUnitFact],
		(CASE [bi].[biUnity]
			WHEN 2 THEN [mt].[mtUnit2]
			WHEN 3 THEN [mt].[mtUnit3]
			ELSE [mt].[mtUnity]
		END) AS [mtUnityName],
		[mt].[mtName],
		[mt].[mtCode],
		[mt].[mtLatinName],
		[mt].[mtSecurity],
		[mt].[mtFlag],
		[mt].[mtUnit2Fact],
		[mt].[mtUnit3Fact],
		[mt].[mtBarCode],
		[mt].[mtGroup],
		[mt].[mtSpec],
		[mt].[mtDim],
		[mt].[mtOrigin],
		[mt].[mtPos],
		[mt].[mtCompany],
		[mt].[mtColor],
		[mt].[mtProvenance],
		[mt].[mtQuality],
		[mt].[mtModel],
		[mt].[mttype],
		[mt].[mtUnity],
		[mt].[mtUnit2],
		[mt].[mtUnit3],
		[mt].[mtDefUnitFact],
		[mt].[mtDefUnit],
		[mt].[mtDefUnitName],
		[mt].[mtCodedCode],
		[mt].[mtHigh],
		[mt].[mtLow],
		[mt].[mtWhole],
		[mt].[mtHalf],
		[mt].[mtRetail], 
		[mt].[mtEndUser],
		[mt].[mtExport],
		[mt].[mtVendor],
		[mt].[mtWhole2],
		[mt].[mtHalf2],
		[mt].[mtRetail2],
		[mt].[mtEndUser2],
		[mt].[mtExport2],
		[mt].[mtVendor2],
		[mt].[mtLastPrice2],
		[mt].[mtWhole3],
		[mt].[mtHalf3],
		[mt].[mtRetail3],
		[mt].[mtEndUser3],
		[mt].[mtExport3],
		[mt].[mtVendor3],
		[mt].[mtLastPrice3],
		[mt].[mtMaxPrice],
		[mt].[mtAvgPrice],
		[mt].[mtLastPrice],
		[mt].[mtQty],
		[mt].[mtPriceType],
		[mt].[mtSellType],
		[mt].[mtBonusOne],
		[mt].[mtPicture], 
		[mt].[mtCurrencyVal],
		[mt].[mtCurrencyPtr],
		[mt].[mtUseFlag],
		[mt].[mtLastPriceDate],
		[mt].[mtBonus],
		[mt].[mtExpireFlag],
		[mt].[mtProductionFlag],
		[mt].[mtUnit2FactFlag],
		[mt].[mtUnit3FactFlag],
		[mt].[mtBarCode2],
		[mt].[mtBarCode3],
		[mt].[mtSNFlag],
		[mt].[mtForceInSN],
		[mt].[mtForceOutSN],
		[mt].[mtHide],
		[mt].[mtParent],
		[mt].[mtHasSegments],
		[mt].[mtCompositionName],
		[mt].[mtCompositionLatinName]
		
	FROM
		[vwbi] AS [bi] INNER JOIN [vwmt] AS [mt] ON
		[bi].[biMatPtr] = [mt].[mtGUID]
	
#########################################################
CREATE VIEW vwBiMtBills
AS
	SELECT bi.* FROM vwBiMt bi
	INNER JOIN vwBuBills bu ON bu.buGUID = bi.biParent
#########################################################
#END