#########################################################
CREATE VIEW vwMtPrices
AS
	SELECT
		[mtGUID],
		[mtNumber],
		[mtName],
		[mtCode],
		[mtLatinName],
		[mtBarCode],
		[mtCodedCode],
		[mtGroup],
		[mtUnity],
		[mtSpec],
		[mtQty],
		[mtHigh],
		[mtLow], 
		(CASE [mtPriceType]
					WHEN 15 THEN [mtWhole] --حقيقي
					WHEN 120 THEN [mtMaxPrice] *(1 + [mtWhole] / 100) --أعظمي
					WHEN 121 THEN [mtAvgPrice] *(1 + [mtWhole] / 100) --وسطي
					WHEN 122 THEN [mtLastPrice] *(1 + [mtWhole] / 100) --آخر شراء
					ELSE [mtMaxPrice] *(1 + [mtWhole] / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					--WHEN 128 THEN mtMaxPrice *(1 + mtWhole / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					END) AS [mtWhole],
		(CASE [mtPriceType]
					WHEN 15 THEN [mtHalf] --حقيقي
					WHEN 120 THEN [mtMaxPrice] *(1 + [mtHalf] / 100) --أعظمي
					WHEN 121 THEN [mtAvgPrice] *(1 + [mtHalf] / 100) --وسطي
					WHEN 122 THEN [mtLastPrice] *(1 + [mtHalf] / 100) --آخر شراء
					ELSE [mtMaxPrice] *(1 + [mtHalf] / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					--WHEN 128 THEN mtMaxPrice *(1 + mtHalf / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					END) AS [mtHalf],
		(CASE [mtPriceType]
					WHEN 15 THEN [mtRetail] --حقيقي
					WHEN 120 THEN [mtMaxPrice] *(1 + [mtRetail] / 100) --أعظمي
					WHEN 121 THEN [mtAvgPrice] *(1 + [mtRetail] / 100) --وسطي
					WHEN 122 THEN [mtLastPrice] *(1 + [mtRetail] / 100) --آخر شراء
					ELSE [mtMaxPrice] *(1 + [mtRetail] / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					--WHEN 128 THEN mtMaxPrice *(1 + mtRetail / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					END) AS [mtRetail],
		(CASE [mtPriceType]
					WHEN 15 THEN [mtEndUser] --حقيقي
					WHEN 120 THEN [mtMaxPrice] *(1 + [mtEndUser] / 100) --أعظمي
					WHEN 121 THEN [mtAvgPrice] *(1 + [mtEndUser] / 100) --وسطي
					WHEN 122 THEN [mtLastPrice] *(1 + [mtEndUser] / 100) --آخر شراء
					ELSE [mtMaxPrice] *(1 + [mtEndUser] / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					--WHEN 128 THEN mtMaxPrice *(1 + mtEndUser / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					END) AS [mtEndUser],
		(CASE [mtPriceType]
					WHEN 15 THEN [mtExport] --حقيقي
					WHEN 120 THEN [mtMaxPrice] *(1 + [mtExport] / 100) --أعظمي
					WHEN 121 THEN [mtAvgPrice] *(1 + [mtExport] / 100) --وسطي
					WHEN 122 THEN [mtLastPrice] *(1 + [mtExport] / 100) --آخر شراء
					ELSE [mtMaxPrice] *(1 + [mtExport] / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					--WHEN 128 THEN mtMaxPrice *(1 + mtExport / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					END) AS [mtExport],
		(CASE [mtPriceType]
					WHEN 15 THEN [mtVendor] --حقيقي
					WHEN 120 THEN [mtMaxPrice] *(1 + [mtVendor] / 100) --أعظمي
					WHEN 121 THEN [mtAvgPrice] *(1 + [mtVendor] / 100) --وسطي
					WHEN 122 THEN [mtLastPrice] *(1 + [mtVendor] / 100) --آخر شراء
					ELSE [mtMaxPrice] *(1 + [mtVendor] / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					--WHEN 128 THEN mtMaxPrice *(1 + mtVendor / 100) --افتراضي --مخزن في sdfلذلك نعيد الأعظمي
					END) AS [mtVendor],
		[mtMaxPrice],
		[mtAvgPrice],
		[mtLastPrice],
		[mtPriceType],
		[mtSellType],
		[mtBonusOne],
		[mtPicture],
		[mtCurrencyVal],
		[mtCurrencyPtr],
		[mtUseFlag],
		[mtOrigin],
		[mtCompany],
		[mtType],
		[mtSecurity],
		[mtLastPriceDate],
		[mtBonus],
		[mtUnit2],
		[mtUnit2Fact],
		[mtUnit3],
		[mtUnit3Fact],
		[mtFlag],
		[mtPos],
		[mtDim],
		[mtDefUnitFact],
		[mtDefUnitName],
		[mtDefUnit],
		[grName]
	FROM
		[vwMtGr]
		
#########################################################
#END