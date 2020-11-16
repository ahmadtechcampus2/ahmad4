#########################################################
CREATE VIEW vtGr
AS
	SELECT * FROM [gr000]

#########################################################
CREATE VIEW vbGr
AS
	SELECT [v].*
	FROM [vtGr] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcGr
AS
	SELECT * FROM [vbGr]
	
#########################################################
CREATE VIEW vdGr
AS
	SELECT * FROM [vbGr]
#########################################################
CREATE VIEW vdGrNoSons
AS
	SELECT * FROM [vdGr] 
#########################################################
CREATE VIEW vwGr 
AS 
	SELECT 
		[GUID] AS [grGUID], 
		[Number] AS [grNumber], 
		[ParentGUID] AS [grParent], 
		[Code] AS [grCode], 
		[Name] AS [grName], 
		[LatinName] AS [grLatinName], 
		[Notes] AS [grNotes], 
		[Security] AS [grSecurity],
		[branchMask] AS [grBranchMask],
		[Kind] AS [grKind]
	FROM 
		[vbGr]

#########################################################
#END