#########################################################
CREATE VIEW vwBillItems
AS
	SELECT	 
		-- [b].TypeGUID AS BillType,
		m.Number AS matNumber,
		[b].[ParentGUID] AS [BillNumber], 
		[b].[Number] AS [ItemNumber], 
		[b].[MatGUID] AS [MatPtr], 
		[m].[Code] AS [MatCode], 
		[m].[Name] AS [MatName], 
		[m].[LatinName] AS [LatinName], 
		(CASE [b].[Unity] 
			WHEN 1 THEN 1 
			WHEN 2 THEN (CASE [m].[Unit2Fact] 
							WHEN 0 THEN 1
							WHEN NULL THEN 1
							ELSE [m].[Unit2Fact]
						END)
			WHEN 3 THEN (CASE [m].[Unit3Fact]
							WHEN 0 THEN 1
							WHEN NULL THEN 1
							ELSE [m].[Unit3Fact]
						END)
		END) AS 		[UnitFact], 
		-- [b].Qty / UnitFact, 
		-- [b].BonusQnt / UnitFact, 
		(CASE [b].[Unity] 
			WHEN 1 THEN [b].[Qty] 
			WHEN 2 THEN [b].[Qty] / (CASE [m].[Unit2Fact] 
									WHEN 0 THEN 1 
									WHEN NULL THEN 1 
									ELSE [m].[Unit2Fact]
								END) 
			WHEN 3 THEN [b].[Qty] / (CASE [m].[Unit3Fact]
									WHEN 0 THEN 1 
									WHEN NULL THEN 1 
									ELSE [m].[Unit3Fact] 
									END) 
			ELSE [b].[Qty]
		END) AS [Qty], 
		(CASE [b].[Unity] 
			WHEN 1 THEN [b].[BonusQnt] 
			WHEN 2 THEN [b].[BonusQnt] / (CASE [m].[Unit2Fact] 
									WHEN 0 THEN 1 
									WHEN NULL THEN 1 
									ELSE [m].[Unit2Fact] 
								END) 
			WHEN 3 THEN [b].[BonusQnt] / (CASE [m].[Unit3Fact] 
									WHEN 0 THEN 1 
									WHEN NULL THEN 1 
									ELSE [m].[Unit3Fact] 
									END) 
		END) AS [BonusQnt], 
		(CASE [b].[Unity]
			WHEN 1 THEN [m].[Unity] 
			WHEN 2 THEN [m].[Unit2] 
			WHEN 3 THEN [m].[Unit3] 
			ELSE '<?>'
		END) AS [UnityName], 
		[b].[Unity], 
		[b].[Price], 
		[s].[GUID] AS [StoreNumber], 
		[s].[Code] AS [StoreCode], 
		[s].[Name] AS [StoreName], 
		[s].[LatinName] AS [StoreLatinName],
		[b].[Notes], 
		[b].[Discount], 
		[b].[Extra],
		[b].[BonusDisc], 
		[b].[Profits], 
		[b].[Length], 
		[b].[Width], 
		[b].[Height], 
		[b].[Count],
		[b].[Qty2], 
		[b].[Qty3], 
		[b].[VATRatio] AS [VAT],  
		[b].[VAT] AS [VATValue],
		[b].[ProductionDate], 
		[b].[ExpireDate], 
		[b].[CostGUID] AS [CostPtr], 
		[b].[ClassPtr], 
		[b].[GUID], 
		[m].[ExpireFlag], 
		[m].[ProductionFlag], 
		[m].[Unit2FactFlag], 
		[m].[Unit3FactFlag], 
		[m].[SNFlag], 
		[m].[Dim] AS [MatDim],
		[m].[Origin] AS [MatOrigin],
		[m].[Pos] AS [MatPos],
		[m].[Company] AS [MatCompany],
		[m].[Color] AS [MatColor],
		[m].[Provenance] AS [MatProvenance],
		[m].[Quality] AS [MatQuality],
		[m].[Model] AS [MatModel],
		[m].[CurrencyGUID] AS [MatCurrencyGUID],
		[m].[ForceInSN], 
		[m].[ForceOutSN],
		[m].[Assemble], 
		[m].[IsIntegerQuantity], 
		[dbo].[fnItemSecViol](0x0, [b].[matGuid], [b].[storeGuid], [b].[costGuid]) as [SecViol],
		[b].[SOType],
		[b].[SOGUID],
		[b].[SOGroup],
		ISNULL([cb].[ContractItemGuid], 0x00)	AS ContractItemGuid,
		ISNULL([cb].[Discount], 0)	AS ContractDiscount,
		[m].[Vat] AS [MatVatRatio],
		b.ClassPrice,
		m.ClassFlag AS [MatClassFlag],
		[m].[Type] AS [MatType], 
		b.IsDiscountValue,
		b.IsExtraValue,
		b.TaxCode,
		b.ExciseTaxVal,
		b.ExciseTaxPercent,
		b.ExciseTaxCode,
		b.PurchaseVal,
		b.ReversChargeVal,
		b.RelatedTo,
		b.CustomsRate,
		b.OrginalTaxCode,
		[m].Parent AS Parent,
		[m].CompositionName,
		[m].CompositionLatinName
	FROM  
		[bi000] AS [b] INNER JOIN [vbmt] AS [m] ON [b].[MatGUID] = [m].[GUID]  
		INNER JOIN [st000] AS [s] ON [b].[StoreGUID] = [s].[GUID] 
		LEFT JOIN [ContractBillItems000]  AS [cb]	ON [cb].[BillItemGuid] = [b].[Guid]
#########################################################
CREATE VIEW vwBillItems_GCC
AS
	SELECT 
		vw.*,
		ISNULL(tax.mtVAT_TaxType, 0) AS mtVAT_TaxType, 
		ISNULL(tax.mtVAT_TaxCode, 0) AS mtVAT_TaxCode, 
		ISNULL(tax.mtVAT_Ratio, 0) AS mtVAT_Ratio, 
		ISNULL(tax.ProfitMargin, 0) AS ProfitMargin, 
		ISNULL(tax.mtExcise_TaxType, 0) AS mtExcise_TaxType,
		ISNULL(tax.mtExcise_TaxCode, 0) AS mtExcise_TaxCode,
		ISNULL(tax.mtExcise_Ratio, 0) AS mtExcise_Ratio,
		ISNULL(tax.IsCalcTaxForPUTaxCode, 0) AS IsCalcTaxForPUTaxCode
	FROM 
		vwBillItems vw
		OUTER APPLY dbo.fnGCC_GetMaterialTax(vw.[MatPtr]) tax
#########################################################
CREATE VIEW vwHBillItems
AS
	SELECT 
		[vw].*,
		[gr].[GUID] AS [GroupGuid],
		[gr].[Code] AS [GroupCode],
		[gr].[Name] AS [GroupName]
	FROM 
		[vwBillItems] [vw] 
		inner join [vbMt] [mt] on [vw].[MatPtr] = [mt].[guid]
		inner join [vbGr] [gr] on [gr].[guid] = [mt].[GroupGuid]
#########################################################
#END
