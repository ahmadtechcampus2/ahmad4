################################################################################
CREATE VIEW vwPOSSDAllEmployees
AS
	SELECT 
		CAST([Number] AS NVARCHAR(50)) AS Number,
		[GUID], 
		[Name],
		[LatinName], 
		[Password], 
		[ExtraAccountGUID], 
		[MinusAccountGUID],
		[CanChangeTicketPrice], 
		[Mobile],
		[Email],
		[Address],
		[Department],
		[Security]
	FROM 
		POSSDEmployee000
	WHERE 
		IsWorking = 1
################################################################################
CREATE VIEW vwPOSSDEmployees
AS
	SELECT 
		CAST([Number] AS NVARCHAR(50)) AS Number,
		[GUID], 
		[Name],
		[LatinName], 
		[Password], 
		[ExtraAccountGUID], 
		[MinusAccountGUID],
		[CanChangeTicketPrice], 
		[Mobile],
		[Email],
		[Address],
		[Department],
		[Security]
	FROM 
		POSSDEmployee000
	WHERE 
		IsWorking = 1
		AND IsSuperVisor = 0
################################################################################
CREATE VIEW vwPOSSDSupervisors
AS
	SELECT 
		CAST([Number] AS NVARCHAR(50)) AS Number,
		[GUID], 
		[Name],
		[LatinName], 
		[Password], 
		[ExtraAccountGUID], 
		[MinusAccountGUID],
		[CanChangeTicketPrice], 
		[Mobile],
		[Email],
		[Address],
		[Department],
		[Security]
	FROM 
		POSSDEmployee000
	WHERE 
		IsWorking = 1
		AND IsSuperVisor = 1
################################################################################
#END
