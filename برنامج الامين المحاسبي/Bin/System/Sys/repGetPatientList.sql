###############################
CREATE PROCEDURE repGetPatientList
	@PatientGUID		UNIQUEIDENTIFIER = 0x0,
	@FileStartDate		DATETIME,
	@FileEndDate		DATETIME,
	@BirthStartDate		DATETIME,
	@BirthEndDate		DATETIME,
	@UseFileDate		int,
	@UseBirthDate		int
AS
SET NOCOUNT ON 
	IF @UseFileDate = 1
	BEGIN
		-- Read From Dossier
		SELECT
			P.Number, P.GUID, P.PersonGUID, P.Code, P.weight, P.length, P.skull, P.Blood, P.MedSens, P.AlmSens, P.Brothers, 
			P.OtherRelations, P.PrevJob, P.Smoke, P.Drink, P.Habits, P.Security, P.Kind, P.Gender, P.PictureGuid, P.[Name], 
			P.LatinName, P.PatientFather, P.PatientMother,	P.PatientNation, P.PatientJob, P.PatientTel1, P.PatientTel2, 
			P.PatientTel3, P.PatientAddress, P.PatientIDCard, P.PatientIDCardDate, P.PatientIDPlace, P.PatientBirthDay, 
			P.PatientBirthPlace, P.PatientWebSite, P.PatientEmail, P.Note
		FROM
			vwHosPatient AS P INNER JOIN VwHosFile AS F ON P.Guid = F.PatientGUID
		WHERE
			((@PatientGUID = 0x0 ) OR ( @PatientGUID = P.Guid))
			AND (F.DateIn >= @FileStartDate AND F.DateOut <= @FileEndDate)
	END
	ELSE
	BEGIN
		-- Read FRom Patient Card
		SELECT
			P.Number, P.GUID, P.PersonGUID, P.Code, P.weight, P.length, P.skull, P.Blood, P.MedSens, P.AlmSens, P.Brothers, 
			P.OtherRelations, P.PrevJob, P.Smoke, P.Drink, P.Habits, P.Security, P.Kind, P.Gender, P.PictureGuid, P.[Name], 
			P.LatinName, P.PatientFather, P.PatientMother,	P.PatientNation, P.PatientJob, P.PatientTel1, P.PatientTel2, 
			P.PatientTel3, P.PatientAddress, P.PatientIDCard, P.PatientIDCardDate, P.PatientIDPlace, P.PatientBirthDay, 
			P.PatientBirthPlace, P.PatientWebSite, P.PatientEmail, P.Note
		FROM 
			vwHosPatient AS P
		WHERE
			((@PatientGUID = 0x0 ) OR ( @PatientGUID = Guid))
			AND ( ( @UseBirthDate = 0) OR ( P.PatientBirthDay BETWEEN @BirthStartDate AND @BirthEndDate))
	END


/*

	SELECT * FROM vwHosPatient AS P INNER JOIN VwHosFile AS F ON P.Guid = F.PatientGUID

	SELECT * FROM VwHosFile 
SELECT * FROM vwHosPatient 
EXEC repGetPatientList '33BADD68-FA79-4E32-B145-007B98537B88'


exec [repGetPatientList] 0x0, '11/12/2005', '11/12/2005', '5/8/2005', '5/8/2005', 0, 1

		SELECT * FROM
			vwHosPatient AS P
		WHERE
			((@PatientGUID = 0x0 ) OR ( @PatientGUID = Guid))
			AND ( ( @UseBirthDate = 0) OR ( P.PatientBirthDay BETWEEN '11/12/2005' AND '11/12/2005'))

*/

##########################################
#END