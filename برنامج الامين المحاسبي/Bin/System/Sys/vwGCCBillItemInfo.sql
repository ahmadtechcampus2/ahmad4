################################################################################
CREATE VIEW vwGCCBillItemInfo
AS 
	SELECT 
		ISNULL(CASE WHEN (bt.BillType = 1 OR bt.BillType = 3) AND cuLoc.Classification = 0 
					THEN (CASE ISNULL(buLoc.GUID, 0x0) WHEN 0x0 THEN cuLoc.GUID ELSE buLoc.GUID END)
					ELSE cuLoc.GUID 
			END, 0x0) AS LocationGuid,
		ISNULL(CASE WHEN (bt.BillType = 1 OR bt.BillType = 3) AND cuLoc.Classification = 0 
					THEN (CASE ISNULL(buLoc.GUID, 0x0) WHEN 0x0 THEN cuLoc.Number ELSE buLoc.Number END)
					ELSE cuLoc.Number 
			END, -1) AS LocationNumber,
		ISNULL(CASE WHEN (bt.BillType = 1 OR bt.BillType = 3) AND cuLoc.Classification = 0 
					THEN (CASE ISNULL(buLoc.GUID, 0x0) WHEN 0x0 THEN cuLoc.Name ELSE buLoc.Name END)
					ELSE cuLoc.Name 
			END, '') AS LocationName,
		ISNULL(CASE WHEN (bt.BillType = 1 OR bt.BillType = 3) AND cuLoc.Classification = 0 
					THEN (CASE ISNULL(buLoc.GUID, 0x0) WHEN 0x0 THEN cuLoc.LatinName ELSE buLoc.LatinName END)
					ELSE cuLoc.LatinName 
			END, '') AS LocationLatinName,
		cuLoc.Classification AS LocationClassification,
		bt.BillType AS BillType,
		bt.GUID AS BtGuid,
		CASE WHEN bt.bIsOutput = 1 THEN 1 ELSE 0 END AS BillTypeIsOutput,
		vw.biTaxCode AS BiTaxCode,
		biTax.Name AS BiTaxCodingName,
		biTax.LatinName AS BiTaxCodingLatinName,
		biTax.GUID AS BiTaxCodingGuid,
		vw.biGUID AS BiGuid,
		vw.buGUID AS BuGuid,
		vw.buCustPtr AS BuCustGUID,
		bu.Date AS BuDate,
		vw.biQty AS BiQty,
		vw.biPrice AS BiPrice,
		vw.biDiscount AS BiDiscount,
		vw.biExtra AS BiExtra,
		vw.biTotalDiscountPercent AS BiTotalDiscountPercent,
		vw.biTotalExtraPercent AS BiTotalExtraPercent,
		vw.biVAT AS BiVat,
		vw.biVATr AS BiVATRatio,
		vw.biExciseTaxCode AS BiExciseTaxCode,
		vw.biExciseTaxVal AS BiExciseTaxVal,
		vw.biExciseTaxPercent AS BiExciseTaxPercent,
		vw.biPurchaseVal AS BiPurchaseVal,
		vw.biReversChargeVal AS BiReversChargeVal,
		ISNULL(vw.biOrginalTaxCode, 0) AS BiOrginalTaxCode,
		en.GUID AS EnGuid,
		en.Type AS EnType,
		en.AccountGUID AS EnAccountGUID,
		en.Debit AS EnDebit,
		en.Credit AS EnCredit,
		(vw.biQty * (vw.biUnitPrice - vw.biUnitDiscount + vw.biUnitExtra)) AS BiNetPrice,
		bu.ImportViaCustoms,
		vw.biCustomsRate AS CustomsRate,
		vw.biNumber AS BiNumber,
		vw.biUnitDiscount AS BiUnitDiscount,
		vw.biUnitExtra AS BiUnitExtra,
		CASE [dbo].[fnConnections_GetLanguage]() 
			WHEN 0 THEN bt.Name 
			ELSE CASE bt.LatinName WHEN '' THEN bt.Name ELSE bt.LatinName END 
		END AS btLocalizedName,
		vw.biBillQty AS BiBillQty , 
		vw.biNotes AS biNotes 
	FROM 
		en000 en 
		INNER JOIN vwExtended_bi vw ON en.BiGUID = vw.biGUID AND en.Type BETWEEN 201 AND 208
		INNER JOIN bu000 bu ON bu.GUID = vw.buGUID
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
		INNER JOIN cu000 cu ON cu.Guid = bu.CustGUID
		INNER JOIN GCCCustLocations000 cuLoc ON cu.GCCLocationGUID = cuLoc.GUID
		LEFT JOIN GCCCustLocations000 buLoc ON buLoc.GUID = bu.GCCLocationGUID
		LEFT JOIN GCCTaxCoding000 biTax ON biTax.TaxCode = vw.biTaxCode 
	WHERE
		bt.BillType = 0 OR  bt.BillType = 1 OR  bt.BillType = 2 OR  bt.BillType = 3 
###################################################################################
#END
