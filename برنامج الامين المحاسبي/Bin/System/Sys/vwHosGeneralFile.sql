#########################################################
CREATE VIEW vwHosGeneralFile 
As 
SELECT  
	F.Number,  
	F.GUID,  
	F.Code,  
	F.SiteGUID,  
	F.BedGUID, 
	F.CostGUID,  
	F.PatientGUID,  
	F.DoctorGUID,  
	F.AccGUID, 
	F.Class,  
	F.MealType,  
	F.DateIn,  
	F.DateOut,  
	F.InitDiag,  
	F.EntranceType,  
	F.Accompanying,  
	F.PoliceNo,  
	F.PoliceDate,  
	F.GuarantorGUID,  
	F.GRelation,  
	F.Status,  
	F.Security, 
	F.ReservationGuid, 
	ISNULL( Pt.[Name], '') [Name], 
	ISNULL( Pt.[LatinName], '') [LatinName], 
	ISNULL( pr.[Name], '') GName, 
	ISNULL( pr.LatinName, '') GLatinName, 
	ISNULL( pr.Tel1, '') GTel1, 
	ISNULL( pr.Tel2, '') GTel2, 
	ISNULL( pr.Address, '') GAddress, 
	ISNULL( pr.IDCard, '') GIDCard, 
	ISNULL(	pr.IDDate, getDate()) GIDDate,
	F.FileNotes AS Note
FROM HosPFile000 F 
	LEFT JOIN vwHosPatient   Pt ON F.PatientGUID  =   Pt.GUID 
	LEFT JOIN HosPerson000  Pr ON F.GuarantorGUID=   Pr.GUID 	
#########################################################
#END