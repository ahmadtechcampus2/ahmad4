#########################################################
CREATE VIEW vwTb 
AS 
	SELECT  
		[Number] AS [tbNumber], 
		[GUID] AS [tbGUID],
		[Code] AS [tbCode],
		[Cover] AS [tbCover],
		[DepartGUID] AS [tbDepartment],
		[Security] AS [tbSecurity]
	FROM 
		[tb000]

#########################################################
#END