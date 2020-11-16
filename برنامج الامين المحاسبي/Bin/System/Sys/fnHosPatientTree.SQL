########################################################################
CREATE   Function hosPatientAction
		(
			@StartDate DATETIME,
			@EndDate   DATETIME
			--@Nationality
			--@Gender
		)
RETURNS @Result TABLE 
	( 
		FileGuid 		UNIQUEIDENTIFIER, 
		PatientGuid 	UNIQUEIDENTIFIER, 
		[Name]			NVARCHAR(255) COLLATE ARABIC_CI_AI,  
		FileCode		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		Gender			INT,	 
		PatientNation   NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		DateIn 			DATETIME, 
		DateOut			DATETIME,	 
		DocGuid 		UNIQUEIDENTIFIER, 
		DocName			NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		CostGuid		UNIQUEIDENTIFIER,		 
		AccGuid			UNIQUEIDENTIFIER, 
		FileSecurity    INT, 
		PatientSecurity INT
	) 
AS 
BEGIN	 
	INSERT INTO @Result  
	SELECT  
		F.Guid, 
		F.PatientGuid, 
		P.[Name],		 
		F.code, 
		P.Gender, 
		P.PatientNation, 
		F.DateIn, 
		F.DateOut, 
		F.DoctorGuid, 
		Doc.[Name], 
		F.CostGuid, 
		F.AccGuid, 
		F.Security, 
		P.Security
	FROM 
		hospfile000 AS F 
		INNER JOIN vwHosPatient AS P ON F.PatientGUID = P.GUID  
		LEFT JOIN vwHosDoctor AS Doc ON F.DoctorGuid = Doc.Guid 
	WHERE  
		(F.DateIn BETWEEN @StartDate AND @EndDate) 
		OR 
		(F.DateOut BETWEEN @StartDate AND @EndDate) 
		--OR	(@StartDate BETWEEN F.DateIn AND F.DateOut)
	ORDER By	 
		P.[Name], F.DateIn 
		 
RETURN 
END 
########################################################################
CREATE FUNCTION fnHosPatientTree
			(    
			--@SiteGUID UNIQUEIDENTIFIER,   
			@StartDate DATETIME,
			@EndDate   DATETIME
			--@Status    INT,
			--@SiteType UNIQUEIDENTIFIER,			
			--@Sorted INT = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)   
			)
RETURNS @Result TABLE 
	(
		GUID UNIQUEIDENTIFIER, 
		Type INT,[Level] INT DEFAULT 0, 
		[Path] NVARCHAR(max) COLLATE ARABIC_CI_AI
	)

AS 
BEGIN   
	DECLARE @FatherBuf TABLE
	(
		GUID UNIQUEIDENTIFIER, 
		Type INT,[Level] INT, 
		[Path] NVARCHAR(max), ID INT IDENTITY( 1, 1)
	)   
	DECLARE @Continue INT, @Level INT     
	SET @Level = 0      
--	  SELECT * FROM vwHosPatient
	--IF ISNULL( @SiteGUID, 0x0) = 0x0 
	/*INSERT INTO @hospatient
		--SELECT Guid,name FROM vwHosPatient
		SELECT Guid FROM vwHosPatient
		ORDER by [Name]*/
	DECLARE @TEMP TABLE
	(
		GUID UNIQUEIDENTIFIER, 
		Name NVARCHAR(255) COLLATE ARABIC_CI_AI
	)   

	INSERT INTO @TEMP
	SELECT DISTINCT p.GUID ,[Name]
	FROM vwHosPatient AS P INNER JOIN HosPFile000 AS f on F.PatientGUID = P.GUID
	WHERE  
	(F.DateIn BETWEEN @StartDate AND @EndDate) 
	OR 
	(F.DateOut BETWEEN @StartDate AND @EndDate) 
	--OR	(@StartDate BETWEEN F.DateIn AND F.DateOut)
	ORDER by [Name]
			
	INSERT INTO @FatherBuf ( GUID, Type,[Level], [Path])   
		SELECT 
		t.GUID,
		0,
		@Level,
		''
		FROM 	 @TEMP AS t
		ORDER BY t.[Name]
		--ORDER BY CASE @Sorted WHEN 1 THEN Code ELSE [Name] END  
		---ORDER BY  [P.Name] 

	UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40))    
	SET @Continue = 1    

	WHILE @Continue <> 0 
	BEGIN    
		SET @Level = @Level + 1      
		INSERT INTO @FatherBuf( GUID, Type,[Level], [Path])    
		SELECT 
			PatientAct.FILEGUID,
			1,
			@Level,
			fb.[Path]   
			FROM hosPatientAction(@StartDate, @EndDate) AS PatientAct
			INNER JOIN @FatherBuf AS fb ON PatientAct.PatientGuid = fb.GUID 
			
			WHERE fb.Level = @Level - 1  
			ORDER BY PatientAct.[Name],PatientAct.DateIn
				/*ORDER BY
				  CASE @Sorted 
					WHEN 1 THEN Code 
					ELSE [Name] 
				  END*/   
			SET @Continue = @@ROWCOUNT      
			UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level      
	
	END   
	INSERT INTO @Result 
	SELECT 
	GUID,
	Type,
	[Level],
	[Path] FROM @FatherBuf
	/*GROUP BY GUID ,[Level], [Path] */
	ORDER BY [Path]  /* Type ,*/
	RETURN   
END 



########################################################################
#END