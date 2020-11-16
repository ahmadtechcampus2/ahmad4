################################################################################
CREATE VIEW vwPOSSDDriver
AS
	SELECT 
		[GUID], 
		CAST ([Number] AS NVARCHAR) AS Number,
		[Name],
		[LatinName],
		[IsWorking],
		[ExtraAccountGUID],
		[MinusAccountGUID],
		[ReceiveAccountGUID],
		[Mobile],
		[Email],
		[Address],
		[Security]
	FROM POSSDDriver000
	WHERE IsWorking = 1
################################################################################
#END
