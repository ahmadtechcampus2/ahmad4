########################################################################
CREATE Proc repHosPatientTree
		@StartDate DateTime,
		@EndDate   DateTime
AS
SET NOCOUNT ON 
Create Table #Result	
		(
		type 			INT,
		Guid			UNIQUEIDENTIFIER,
		ParentGuid 		UNIQUEIDENTIFIER,
		[Name]			NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		FileCode		NVARCHAR(255) COLLATE ARABIC_CI_AI,
		Gender			INT,	
		PatientNation   NVARCHAR(255) COLLATE ARABIC_CI_AI,
		DateIn 			DATETIME,
		DateOut			DATETIME,	
		DocGuid 		UNIQUEIDENTIFIER,
		DocName			NVARCHAR(255) COLLATE ARABIC_CI_AI,
		CostGuid		UNIQUEIDENTIFIER,		
		AccGuid			UNIQUEIDENTIFIER
		--[Path] NVARCHAR(8000) COLLATE ARABIC_CI_AI
		)

Create Table #TreeTable 
	(
		GUID UNIQUEIDENTIFIER, 
		Type INT,[Level] INT DEFAULT 0, 
		[Path] NVARCHAR(max) COLLATE ARABIC_CI_AI
	)


INSERT into #TreeTable
	SELECT * FROM fnHosPatientTree(@StartDate,@EndDate)

--fill parents (Patients)  first
INSERT into #Result 
	SELECT
		t.type, -- parent	
		p.Guid,	--  this guid is for patientguid 
		0x0,	--p.Guid ,
		p.[Name],		
		p.code, --patient code 
		p.Gender,
		p.PatientNation,
		NULL, 	--'1800',--act.DateIn,
		Null,	--act.DateOut,
		0x0,	--act.DocGuid,
		'',		--act.[DocName],
		0x0,	--,act.CostGuid,
		0x0		--act.AccGuid,
		--t.path
		FROM
		#TreeTable As t INNER JOIN vwHosPatient AS P ON p.Guid = t.Guid
		where 
			t.type = 0

INSERT into #Result
	SELECT
		t.type,
		act.FileGuid,
		act.PatientGuid,
		act.[Name],		
		act.Filecode,
		act.Gender,
		act.PatientNation,
		act.DateIn,
		act.DateOut,
		act.DocGuid,
		act.[DocName],
		act.CostGuid,
		act.AccGuid
		--t.path
		FROM
		hosPatientAction (@StartDate, @EndDate) As act
		INNER JOIN  #TreeTable AS t ON  t.Guid = act.FileGuid 
		where type = 1
select * from #Result
order by [Name], [DateIn]


########################################################################
#END