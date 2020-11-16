#########################################################
CREATE VIEW vtMn
AS
	SELECT * FROM [mn000]
#########################################################
CREATE VIEW vbMn
AS
	SELECT [mn].*
	FROM [vtMn] AS [mn] INNER JOIN [vwBr] AS [br] ON [mn].[BranchGUID] = [br].[brGUID]

#########################################################
CREATE  VIEW vcMn 
AS 
	SELECT *
	/*
		Number,
		GUID,
		FormGuid,
		Notes,
		LOT,
		ProductionTime,
		InStoreGUID,
		OutStoreGUID,
		InCostGUID,
		OutCostGUID,
		InAccountGUID,
		OutAccountGUID,
		InTempAccGUID,
		OutTempAccGUID
		*/
	FROM [vbMn] WHERE [Type] = 1
	
#########################################################

CREATE VIEW vwMn
AS
	SELECT
		[mn].[Type] AS [mnType],
		[mn].[Number] AS [mnNumber],
		[mn].[Date] AS [mnDate],
		[mn].[InDate] AS [mnInDate],
		[mn].[OutDate] AS [mnOutDate],
		[mn].[Qty] AS [mnQty],
		[mn].[Notes] AS [mnNotes],
		[mn].[Security] AS [mnSecurity],
		[mn].[Flags] AS [mnFlags],
		[mn].[PriceType] AS [mnPriceType],
		[mn].[CurrencyVal] AS [mnCurrencyVal],
		[mn].[UnitPrice] AS [mnUnitPrice],
		[mn].[TotalPrice] AS [mnTotalPrice],
		[mn].[GUID] AS [mnGUID],
		[mn].[FormGUID] AS [mnFormGUID],
		[mn].[InStoreGUID] AS [mnInStore],
		[mn].[OutStoreGUID] AS [mnOutStore],
		[mn].[InAccountGUID] AS [mnInAccount],
		[mn].[OutAccountGUID] AS [mnOutAccount],
		[mn].[InCostGUID] AS [mnInCost],
		[mn].[OutCostGUID] AS [mnOutCost],
		[mn].[InTempAccGUID] AS [mnInTempAcc],
		[mn].[OutTempAccGUID] AS [mnOutTempAcc],
		[mn].[CurrencyGUID] AS [mnCurrencyGUID],
		[mn].[LOT]	AS [mnLOT],
		[mn].[ProductionTime] AS [mnProductionTime],
		[mn].[StepCost] AS [mnStepCost],
		[mn].[PhaseNumber] AS [mnPhaseNumber]
	FROM
		[vbMn] AS [mn]

#########################################################
CREATE VIEW vtMnPs
AS 
--add by huzifa terkawi 7-8-2006 for manufatcuring plan branches
SELECT * from MNPS000
#########################################################
CREATE VIEW vbMNPS
AS
SELECT * FROM MNPS000
##########################################################
CREATE VIEW vcMNPS
AS
SELECT * FROM MNPS000
##########################################################
#END