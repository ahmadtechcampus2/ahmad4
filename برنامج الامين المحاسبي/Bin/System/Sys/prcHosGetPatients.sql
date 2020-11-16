##############################################
CREATE   proc prcHosGetPatients
			@Name NVARCHAR(250), 
			@Nation NVARCHAR(250), 
			@FatherName NVARCHAR(250), 
			@MotherName NVARCHAR(250), 
			@IdentityNo NVARCHAR(250), 
			@Phone  NVARCHAR(250)  
AS 
	SET NOCOUNT ON 
	SELECT  
		GUID, 
		PersonGuid, 
		Code, 
		[Name], 
		PatientNation, 
		PatientTel1, 
		Gender, 
		PatientFather, 
		PatientMother 
	FROM VwHosPatient 
	Where  
		[Name] LIKE '%' + @Name + '%'  
		AND PatientNation LIKE '%' + @Nation + '%'  
		AND PatientFather LIKE '%' + @FatherName + '%'  
  		AND PatientMother LIKE '%' + @MotherName + '%' 
		--AND PatientMother LIKE '%' + @MotherName + '%' 
		AND ( 
			[PatientTel1] LIKE '%' + @Phone + '%'  
			OR  
			[PatientTel2] LIKE '%' + @Phone + '%'  
			OR 
			[PatientTel3] LIKE '%' + @Phone + '%'  
		) 
	ORDER BY [Name] 
##############################################
#END