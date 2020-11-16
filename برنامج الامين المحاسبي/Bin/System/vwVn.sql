#########################################################
CREATE VIEW vwVn
AS 
	SELECT  
		[Type] AS [vnType],
		[Number] AS [vnNumber], 
		[GUID] AS [vnGUID],
		[Code] AS [vnCode],
		[Name] AS [vnName],
		[LatinName] AS [vnLatinName],
		[AccountGUID] AS [vnAccount],
		[Phone] AS [vnPhone],
		[Address] AS [vnAddress],
		[Cirtificate] AS [vnCirtificate],
		[Date] AS [vnDate],
		[Work] AS [vnWork],
		[Notes] AS [vnNotes],
		[Security] AS [vnSecurity]
	FROM
		[vn000]

#########################################################
#END