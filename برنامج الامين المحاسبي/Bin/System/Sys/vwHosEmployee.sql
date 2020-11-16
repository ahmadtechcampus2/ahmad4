#########################################################
CREATE   VIEW vwHosEmployee
AS
	SELECT
		E.Number, 
		E.GUID, 
		E.Code,
		E.PersonGUID, 
		E.Speciality, 
		E.Type, 
		E.AccGUID, 
		E.Security,
		E.WorkNature,
		p.Name [Name], 
		p.LatinName LatinName,
		p.FatherName Father,
		p.MotherName Mother,
		p.Nation Nation, 
		p.Job Job, 
		p.Tel1 Tel1, 
		p.Tel2 Tel2, 
		p.Tel3 Tel3, 
		p.Address Address, 
		p.IdCard IDCard, 
		p.IdDate IDCardDate, 
		p.IdPlace IDPlace, 
		p.BirthDay BirthDay, 
		p.BirthPlace BirthPlace, 
		p.WebSite WebSite, 
		p.Email Email,
		p.Note
	FROM 
		hosEmployee000 E LEFT JOIN hosPerson000 P ON  E.PersonGUID = P.GUID 
#########################################################
#END
