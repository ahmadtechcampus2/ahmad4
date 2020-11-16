#########################################################
CREATE VIEW vwMnMiMt
AS
	SELECT
		[mn].[mnType],
		[mn].[mnNumber],
		[mn].[mnGUID],
		[mn].[mnFormGUID],
		[mn].[mnQty],
		[mn].[mnDate],
		[mn].[mnInDate],
		[mn].[mnOutDate],
		[mn].[mnInStore],
		[mn].[mnOutStore],
		[mn].[mnInAccount],
		[mn].[mnOutAccount],
		[mn].[mnNotes],
		[mn].[mnSecurity],
		[mn].[mnInCost],
		[mn].[mnOutCost],
		[mn].[mnPriceType],
		[mn].[mnUnitPrice],
		[mn].[mnTotalPrice],
		[mn].[mnInTempAcc],
		[mn].[mnOutTempAcc],
		[mn].[mnCurrencyGUID],
		[mn].[mnCurrencyVal],
		[mn].[mnStepCost],
		[mn].[mnLOT],
		[mn].[mnProductionTime],
		[mn].[mnPhaseNumber],
		[mi].[miType],
		[mi].[miNumber],
		[mi].[miGUID],
		[mi].[miMatGUID],
		(CASE [mi].[miUnity]
			WHEN 1 THEN [mi].[miQty] / ISNULL( CASE [mt].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END, 1)
			WHEN 2 THEN [mi].[miQty] / ISNULL( CASE [mt].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END, 1)
			ELSE [mi].[miQty] / ISNULL( CASE [mt].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END, 1)
		END) AS [miQty],
		[mi].[miUnity],
		[mi].[miPrice],
		[mi].[miPercentage],
		[mi].[miStoreGUID],
		[mi].[miCostGUID],
		[mi].[miCurrencyGUID],
		[mi].[miCurrencyVal],

		[mt].[mtName],
		[mt].[mtCode],
		[mt].[mtLatinName],
		[mt].[mtDefUnitFact],
		[mt].[mtDefUnit],
		[mt].[mtUnit2Fact],
		[mt].[mtUnit3Fact],
		[mt].[mtType],
		[mt].[mtsecurity],
		[mt].[mtDefUnitName],
		case [mi].[miUnity]
			WHEN 1 THEN 1 
			WHEN 2 THEN [mt].[mtUnit2Fact] 
			WHEN 3 THEN [mt].[mtUnit3Fact] 
		END AS [miUnitFact]
	FROM
		[vwMn] AS [mn] INNER JOIN [vwMi] AS [mi]
		ON /*mn.mntype = 1 AND */[mn].[mnGUID] = [mi].[miParent]	--1:Normal Manuf
		INNER JOIN [vwmt] AS [mt]
		ON [mi].[miMatGUID] = [mt].[mtGUID]

#########################################################
CREATE VIEW vwMnMiMt_ManufacturedMaterials
AS
SELECT * FROM vwMnMiMt
WHERE mnType = 1 AND miType = 0
#########################################################
#END