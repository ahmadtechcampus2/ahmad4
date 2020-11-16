################################################################################
CREATE VIEW vwPOSSDSalesman
AS
	SELECT 
		[GUID], 
		CAST ([Number] AS NVARCHAR) AS Number,
		[Name],
		[LatinName], 
		[CostCenterGUID],
		[Mobile],
		[Email],
		[Address],
		[Department],
		[Security]
	FROM POSSDSalesman000
	WHERE IsWorking = 1
################################################################################
#END
