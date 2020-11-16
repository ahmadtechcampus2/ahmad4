###################################################
CREATE PROC HosGetCanceledReservationsRep
	@SiteGUID UNIQUEIDENTIFIER = 0x0,
	@PersonGUID UNIQUEIDENTIFIER = 0x0,
	@From DATETIME = '',
	@To   DATETIME = '2100'
AS

SET NOCOUNT ON 

	CREATE TABLE #result
	(
		PersonName  NVARCHAR(250) COLLATE Arabic_CI_AI,
		PhoneNumber NVARCHAR(25) COLLATE Arabic_CI_AI,
		SiteName    NVARCHAR(250) COLLATE Arabic_CI_AI,
		CancledDate DATETIME
	)
	

	INSERT INTO #result
	SELECT 
		Person.Name,
		Person.Tel1,
		Site.Name,
		Res.CancleDate
	FROM 
		HosReservationDetails000 Res
	INNER JOIN 
		HosPatient000 Patient 
			ON Patient.GUID = Res.PatientGUID
	INNER JOIN 
		HosPerson000 Person
			ON Person.GUID = Patient.PersonGUID
	INNER JOIN 
		HosSite000 Site
			ON Site.GUID = Res.SiteGUID
	WHERE
		Res.IsConfirm = 2
		AND
		Res.CancleDate BETWEEN @From AND @To
		AND
		(Site.GUID = @SiteGUID OR @SiteGUID = 0x0) 
		AND 
		(Patient.GUID = @PersonGUID OR @PersonGUID = 0x0)
		
	SELECT * FROM #result
###########################################
#END