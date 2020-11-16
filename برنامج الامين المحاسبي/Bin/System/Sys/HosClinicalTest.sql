###############################################################################
CREATE  FUNCTION fnHosMiniCard (@Type INT)
RETURNS @Table TABLE 
(
	Number float,
	Guid UNIQUEIDENTIFIER,
	Code NVARCHAR(100),
	Name NVARCHAR(250) COLLATE Arabic_CI_AI ,
	LatinName NVARCHAR(250),
	Notes NVARCHAR(250),
	Security int,
	Type int
)
AS
BEGIN 
	INSERT INTO @Table SELECT * FROM HosMiniCard000 WHERE TYPE = @Type
	ORDER BY Code
    RETURN
END
###############################################################################
CREATE PROC prcHosClinicalTests (@FileGuid UNIQUEIDENTIFIER)
AS
	SET NOCOUNT ON 
	CREATE TABLE  [#Table]
	(
		Guid UNIQUEIDENTIFIER, 
		FileGuid UNIQUEIDENTIFIER, 
		DoctorGuid UNIQUEIDENTIFIER, 
		DoctorCode NVARCHAR(100)COLLATE ARABIC_CI_AI, 
		DoctorName NVARCHAR(250)COLLATE ARABIC_CI_AI, 
		DoctorLatinName NVARCHAR(250)COLLATE ARABIC_CI_AI, 
		TestGuid UNIQUEIDENTIFIER, 
		TestCode NVARCHAR(100)COLLATE ARABIC_CI_AI, 
		TestName NVARCHAR(250)COLLATE ARABIC_CI_AI, 
		TestLatinName NVARCHAR(250)COLLATE ARABIC_CI_AI, 
		Result NVARCHAR(250)COLLATE ARABIC_CI_AI
	)
	INSERT INTO [#Table]
	SELECT
		0x0 Guid,
		0x0 FileGuid,
		0x0 DoctorGuid,
		'' DoctorCode,
		'' DoctorName,
		'' DoctorLatinName,
		Guid TestGuid,
		Code TestCode,
		[Name] TestName,
		LatinName TestLatinName,
		'' Result
	FROM fnHosMiniCard(2)

	UPDATE  [#Table] SET 
		Guid = ISNULL(CT.Guid, 0x0),
		FileGuid = ISNULL(Ct.FileGuid, 0x0),
		DoctorGuid = ISNULL(Doc.Guid, 0x0),
		DoctorCode = ISNULL(Doc.Code, ''),
		DoctorName = ISNULL(Doc.Name, ''),
		DoctorLatinName = ISNULL(Doc.LatinName, '') ,
		Result = ISNULL(Ct.Result, '') 
	FROM #Table   	 fn	LEFT JOIN  HosClinicalTests000 CT ON	CT.TestGuid  = fn.TestGuid
						LEFT JOIN vwHosDoctor Doc ON	Doc.Guid = Ct.DoctorGuid
	WHERE (CT.FileGuid =  @FileGuid)
  	SELECT * FROM [#Table]
  	DROP TABLE [#Table]
###############################################################################
CREATE PROC prcHosPatientHabits (@PatientGuid UNIQUEIDENTIFIER) 
AS 
	SET NOCOUNT ON 
	CREATE TABLE  [#Table] 
	( 
		Guid UNIQUEIDENTIFIER, 
		Name NVARCHAR(250), 
		LatinName NVARCHAR(250), 
		PatientGuid UNIQUEIDENTIFIER,
		Checked bit
	) 
	INSERT INTO [#Table] 
	SELECT 
		Guid, 
		[Name], 
		LatinName, 
		0x0,
		0 
	FROM fnHosMiniCard(1) 

	UPDATE  [#Table] SET  	
		PatientGuid = Pt.Guid,
		Checked = CASE Pt.PatientGuid when 0x0 then 0 else 1 end
	FROM hosPatientHabits000 Pt LEFT JOIN #Table  Ht	ON	Pt.HabitGuid   = Ht.Guid 
	WHERE (Pt.PatientGuid =  @PatientGuid) 
 	SELECT * FROM [#Table] 
 	DROP TABLE [#Table] 
###############################################################################
#End

