#########################################################
CREATE VIEW vtFm
AS
	-- noting that the relation between Fm and Mn from Fm point of view is One2One
	SELECT
		[fm].*,
		[mn].[Date],
		[mn].[Notes],
		[mn].[Security],
		[mn].[Flags],
		[mn].[CurrencyVal],
		[mn].[GUID] AS [mnGUID],
		[mn].[InStoreGUID],
		[mn].[OutStoreGUID],
		[mn].[InCostGUID],
		[mn].[OutCostGUID],
		[mn].[CurrencyGUID],
		[mn].[InAccountGuid],
		[mn].[OutAccountGuid] ,
		[mn].[InTempAccGuid],
		[mn].[OutTempAccGuid],
		[mn].[PhaseNumber]
	FROM
		[Fm000] AS [fm] INNER JOIN [vtMn] AS [mn]
			ON [fm].[GUID] = [mn].[FormGUID]
	WHERE [Type] = 0 
#########################################################
CREATE VIEW vbFm
AS
	SELECT [v].*
	FROM [vtfm] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask]<> 0
#########################################################
CREATE VIEW vdFm
As
	SELECT * FROM [vbFm]
#########################################################
CREATE VIEW vcFm
AS
	SELECT * FROM [vbFm]
#########################################################
CREATE  VIEW vwFm
AS 
	SELECT
		[Number] AS [fmNumber],
		[Code] AS [fmCode],
		[Name] AS [fmName],
		[LatinName] AS [fmLatinName],
		[Designer] AS [fmDesigner],
		[GUID] AS [fmGUID],
		[Date] AS [fmDate],
		[Notes] AS [fmNotes],
		[Security] AS [fmSecurity],
		[Flags] AS [fmFlags],
		[CurrencyVal] AS [fmCurrencyVal],
		[mnGUID] AS [mnGUID],
		[InStoreGUID] AS [fmInStoreGUID],
		[OutStoreGUID] AS [fmOutStoreGUID],
		[InCostGUID] AS [fmInCostGUID],
		[OutCostGUID] AS [fmOutCostGUID],
		[CurrencyGUID] AS [fmCurrencyGUID],
		[branchMask] AS [fmBranchMask],
		[IsHideForm] AS [IsHideForm]
	FROM
		[vbFm]
#########################################################
CREATE  VIEW vwMnPlanCode
AS 
		SELECT 
			MNPS.Guid,
			MNPS.Code
		FROM MNPS000 AS MNPS
		INNER JOIN PSI000 AS PSI ON PSI.ParentGuid = MNPS.GUID AND PSI.State = 0
#########################################################
CREATE VIEW vwFmSearch
AS 
	SELECT
		[fmNumber] AS [Number],
		[fmCode] AS [Code], 
		[fmName] AS [Name], 
		[fmLatinName] AS [LatinName], 
		[fmGUID] AS [GUID], 
		[fmSecurity] AS [Security]
	FROM 
		[vwFm]
#########################################################
CREATE VIEW vwFmSearch2
AS 
	SELECT
		[fmNumber] AS [Number],
		[fmCode] AS [Code], 
		[fmName] AS [Name], 
		[fmLatinName] AS [LatinName], 
		[fmGUID] AS [GUID], 
		[fmSecurity] AS [Security],
		[IsHideForm] AS [IsHideForm]
	FROM 
		[vwFm]
	WHERE IsHideForm =0
#########################################################
CREATE  VIEW VWPlanWithCommitedPsi
AS
	SELECT  DISTINCT
			MNPS.GUID AS Guid,
			MNPS.Code
		FROM MNPS000 AS MNPS
		INNER JOIN PSI000 AS PSI ON PSI.ParentGuid = MNPS.GUID AND MNPS.State = 0 
#########################################################
#END