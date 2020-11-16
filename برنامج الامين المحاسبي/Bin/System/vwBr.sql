#########################################################
CREATE VIEW vtBr
AS
	SELECT *, [dbo].[fnPowerOf2]([Number] - 1) AS [branchMask] FROM [br000]

#########################################################
CREATE View vbBr
AS
	SELECT [v].*
	FROM [vtBr] AS [v]
	WHERE [v].[branchMask] & [dbo].[fnConnections_getBranchMask]() <> 0

#########################################################
CREATE VIEW vcBr
AS
	SELECT *
	FROM [vtBr]
	WHERE [branchMask] & [dbo].[fnBranch_getCurrentUserReadMask_scalar](0) <> 0

#########################################################
CREATE VIEW vdBr
AS
	SELECT * FROM [vbBr]

#########################################################
CREATE VIEW vwBr
AS
	SELECT
		[GUID] AS [brGUID],
		[Number] AS [brNumber],
		[Code] AS [brCode],
		[Name] AS [brName],
		[LatinName] AS [brLatinName],
		[Phone1] AS [brPhone1],
		[Phone2] AS [brPhone2],
		[Address] AS [brAddress],
		[Notes] AS [brNotes],
		[Security] AS [brSecurity],
		[branchMask] AS [brBranchMask],
		[ParentGUID] AS [brParentGUID]
	 FROM
		[vbBr]
#########################################################
CREATE VIEW vfBr
AS 
	SELECT [v].* 
	FROM [vtBr] AS [v] 
		INNER JOIN [fnBranch_GetCurrentUserReadMask](0) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0 
#########################################################

CREATE VIEW veBr
AS 
	SELECT *	FROM [vfBr]
	UNION ALL 
	SELECT  * FROM [vtBr] WHERE [NUMBER] = 0
#########################################################
#END