#########################################################
CREATE VIEW vtMy
AS
	SELECT * FROM [my000]

#########################################################
CREATE VIEW vbMy
AS
	SELECT [v].*
	FROM [vtMy] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcMy
AS
	SELECT * FROM [vbMy]

#########################################################
CREATE VIEW vdMy
AS
	SELECT * FROM [vbMy]

#########################################################
CREATE VIEW vwMy
AS  
	SELECT  
		[Number] AS [myNumber],  
		[Code] AS [myCode],  
		[Name] AS [myName],  
		[LatinName] AS [myLatinName],
		[CurrencyVal] AS [myCurrencyVal],  
		[PartName] AS [myPartName],  
		[PartPrecision] AS [myPartPrecision],		  
		[Date] AS [myDate],  
		[Security] AS [mySecurity],  
		[GUID]	AS	[myGUID],
		[branchMask]
	FROM  
		[vbMy]

#########################################################
#END