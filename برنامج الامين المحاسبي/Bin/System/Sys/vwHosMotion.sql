##################################################################################
CREATE VIEW vwHosMotion
AS
SELECT 
	Guid,
	FileGuid, 
	StartDate, 
	EndDate,
	SiteGuid,  
	1 Type 
FROM dbo.hosStay000
UNION ALL 
SELECT 
	Guid,
	0x0 FileGuid, 
	FromDate StartDate, 
	ToDate EndDate,
	SiteGuid,  
	2 Type 
FROM vwHosReservationDetails
UNION ALL 
SELECT 
	Guid,
	FileGuid,
	BeginDate StartDate, 
	EndDate EndDate,
	SiteGuid,  
	3 Type 
FROM vwHosFSurgery
##################################################################################
#END
