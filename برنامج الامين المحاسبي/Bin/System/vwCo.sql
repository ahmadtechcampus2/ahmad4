#########################################################
CREATE VIEW vtCo
AS
	SELECT * FROM [co000]

#########################################################
CREATE VIEW vbCo
AS
	SELECT [v].*
	FROM [vtCo] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcCo
AS
	SELECT * FROM [vbCo]

#########################################################
CREATE VIEW vdCo
AS
	SELECT * FROM [vbCo] 
#########################################################
CREATE VIEW vdCoNoSons
AS
	SELECT * FROM [vdCo] WHERE [Type] = 0 OR [Type] = 2
#########################################################
CREATE VIEW vwCo 
AS 
	SELECT 
		[GUID] as [coGUID], 
		[Number] AS [coNumber], 
		[Code] AS [coCode], 
		[Name] AS [coName], 
		[LatinName] as [coLatinName], 
		[ParentGUID] AS [coParent], 
		[Notes] AS [coNotes], 
		[Debit] AS [coDebit], 
		[Credit] AS [coCredit], 
		[Type] AS [coType], 
		[Security] AS [coSecurity], 
		[Num1] AS [coNum1], 
		[Num2] AS [coNum2],
		[branchMask] AS [coBranchMask]
	FROM 
		[vbCo]

#########################################################
CREATE VIEW vwNonMasterCosts 
AS
	SELECT * 
	FROM vbCo
	WHERE GUID NOT IN 
	(
	SELECT DISTINCT PARENTGUID 
	FROM CO000 
	WHERE PARENTGUID <> 0X00
	)

#########################################################
#END