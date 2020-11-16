#########################################################
CREATE VIEW vwPatient
AS
	SELECT
		P.Number, 
		P.GUID, 
		P.PersonGUID PersonGUID, 
		P.Code, 
		P.weight, 
		P.length, 
		P.skull, 
		P.Blood, 
		P.MedSens, 
		P.AlmSens, 
		P.Brothers, 
		P.OtherRelations, 
		P.PrevJob, 
		P.Smoke, 
		P.Drink, 
		P.Habits,
		P.Security,
		S.Name [Name], 
		S.LatinName LatinName,
		S.FatherName PatientFather,
		S.MotherName PatientMother,
		S.Nation PatientNation, 
		S.Job PatientJob, 
		S.Tel1 PatientTel1, 
		S.Tel2 PatientTel2, 
		S.Tel3 PatientTel3, 
		S.Address PatientAddress, 
		S.IdCard PatientIDCard, 
		S.IdDate PatientIDCardDate, 
		S.IdPlace PatientIDPlace, 
		S.BirthDay PatientBirthDay, 
		S.BirthPlace PatientBirthPlace, 
		S.WebSite PatientWebSite, 
		S.Email PatientEmail,
		S.Note
	FROM 
		hospatient000 P LEFT JOIN hosPerson000 S ON P.PersonGUID = S.GUID 		

#########################################################
#END