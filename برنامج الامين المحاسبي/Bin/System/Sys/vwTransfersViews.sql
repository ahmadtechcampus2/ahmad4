#########################################################
CREATE VIEW vtTrnBranch
AS
	SELECT * FROM TrnBranch000
#########################################################
CREATE VIEW viewbrTrnBranch
AS
    SELECT v.*
	FROM 
		vtTrnBranch AS v 
    INNER JOIN fnBranch_GetCurrentUserReadMask(DEFAULT) AS f ON v.branchMask & f.Mask <> 0
#########################################################
CREATE VIEW vbTrnBranch
AS
    --SELECT [TrnBranch].*
    --FROM [vtTrnBranch] AS [TrnBranch] INNER JOIN [vwBr] AS [br] ON [TrnBranch].[AmnBranchGUID] = [br].[brGUID]

    SELECT v.*
    FROM vtTrnBranch AS v 
    INNER JOIN fnBranch_GetCurrentUserReadMask(DEFAULT) AS f ON v.branchMask & f.Mask <> 0
######################################################
CREATE VIEW vcTrnBranch
As
	SELECT * FROM viewbrTrnBranch
##################################################################################
CREATE VIEW vwTrnBranch
As
	SELECT * FROM viewbrTrnBranch
###############################################################################
CREATE FUNCTION fbTrnSubBranches ()
	RETURNS TABLE
	AS
		RETURN (SELECT * FROM vwTrnBranch AS st WHERE st.Number <> 0)
##################################################################################
CREATE  VIEW vwTrnSendRec
AS
	SELECT * FROM TrnSenderReceiver000
##################################################################################
CREATE VIEW vwTrnWages
AS
	SELECT	
		w.Number wNumber,
		w.GUID wGUID,
		w.[Name] wName,
		w.Type	wType,	 	
		w.CurrencyGUID wCurrencyGuid,
		w.CurrencyVal wCurrencyVal,
		w.UseRange wUseRange,
		w.UsePercent wUsePercent,
		w.LowWages wLowWages,
		w.Ratio wRatio,
		w.RatioType wRatioType,
		w.Security wSecurity,
		wi.Number wiNumber,
		wi.GUID wiGUID,
		wi.ParentGUID wiParentGUID,
		wi.MinAmount wiMinAmount,
		wi.MaxAmount wiMaxAmount,
		wi.CurrencyGUID wiCurrencyGUID,
		wi.CurrencyVal wiCurrencyVal,
		wi.Wage wiWage,
		wi.WageCurrencyGUID wiWageCurrencyGUID,
		wi.WageCurrencyVal wiWageCurrencyVal,
		wi.Ratio wiRatio
	FROM
		TrnWages000 w LEFT JOIN TrnWagesItem000 wi
		ON w.Guid = wi.ParentGuid	 
###################################################################

#END
