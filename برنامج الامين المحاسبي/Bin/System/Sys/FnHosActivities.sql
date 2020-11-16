##################################################################################
CREATE  FUNCTION fnHos_Res_Stay_Table 
				(
					@StartDate DateTime = '1900',
					@EndDate DateTime = '2100'
				)
RETURNS  @res TABLE
		(
			Guid 			UNIQUEIDENTIFIER,
			SiteGuid		UNIQUEIDENTIFIER,
			PatientGuid		UNIQUEIDENTIFIER,
			FileGuid		UNIQUEIDENTIFIER,
			Name			NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			LatinName		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			Type 			INT,
			PatientSecurity INT,
			FileSecurity    INT,
			StartDate 		DATETIME,
			EndDate			DATETIME	
		)
AS
BEGIN
	INSERT INTO @res
	 SELECT
			Stay.guid,
			Site.Guid,
			Patient.Guid,
			PFile.Guid,
			person.[name],
			person.LatinName,
			1,
			patient.security,
			PFile.security ,
			Stay.StartDate,
			Stay.EndDate
	FROM
	 hospatient000 AS patient 
	 INNER	JOIN hosperson000 AS person 
		 ON person.Guid = patient.PersonGuid
  	 INNER JOIN hospfile000 AS PFile
		 ON PFile.PatientGuid = Patient.Guid
	 INNER JOIN HosStay000 AS Stay
		 ON Stay.FileGuid = PFile.Guid
	 INNER 	JOIN Hossite000 AS Site  
		 ON  Site.Guid  = Stay.SiteGuid 
  	 WHERE
		 (@StartDate BETWEEN  Stay.StartDate and Stay.EndDate)
		OR
		 (@EndDate BETWEEN  Stay.StartDate and  Stay.EndDate)	
		OR
		 (Stay.StartDate BETWEEN  @StartDate AND @EndDate)
		OR
		 (@StartDate >= Stay.StartDate AND  @EndDate <= Stay.EndDate)	
	
 
	INSERT INTO @res
	 SELECT
			ReservDetail.guid,
			Site.Guid,
			Patient.Guid,
			ISNULL(PFile.Guid, 0x0) AS FileGuid,
			person.[name],
			person.LatinName,
			2,
			patient.security,
			PFile.security ,
			ReservDetail.FromDate,
			ReservDetail.ToDate
		FROM 
		 hospatient000 AS patient 
		 INNER	JOIN hosperson000 AS person 
			 ON person.Guid = patient.PersonGuid
		 INNER 	JOIN HosReservationDetails000 AS ReservDetail  
			 ON patient.Guid = ReservDetail.PatientGuid
		 INNER 	JOIN Hossite000 AS Site  
			 ON  Site.Guid  = ReservDetail.SiteGuid 
		LEFT JOIN hosPFile000 AS Pfile 
			 ON PFile.Guid =  ReservDetail.FileGuid 	
		 WHERE
			(@StartDate BETWEEN  ReservDetail.FromDate and ReservDetail.ToDate)
	        	OR
			  (@EndDate BETWEEN  ReservDetail.FromDate and  ReservDetail.ToDate)	
			OR
			  (ReservDetail.FromDate BETWEEN  @StartDate AND @EndDate)
			OR
			  (@StartDate >= ReservDetail.FromDate AND  @EndDate <= ReservDetail.ToDate)	
			  

	INSERT INTO @res
	 SELECT
			guid,
			SiteGuid,
			0x0,--Patient.Guid,
			0x0,--FileGuid,
			'',--person.[name],
			'',--person.LatinName,
			5,
			1,--patient.security,
			1,--PFile.security ,
			StartDate,
			EndDate
		FROM 
		 HosSiteOut000 AS patient 
		 WHERE
			(@StartDate BETWEEN  StartDate and EndDate)
	        	OR
			  (@EndDate BETWEEN  StartDate and  EndDate)	
			OR
			  (StartDate BETWEEN  @StartDate AND @EndDate)
			OR
			  (@StartDate >= StartDate AND  @EndDate <= EndDate)	
RETURN 
END
###################################################################
CREATE  FUNCTION FnHosAllActivities
	(
		@SiteGuid		UNIQUEIDENTIFIER,
		@StartDate		DateTime,
		@EndDate		DateTime,
		@IsResConfirm	INT = 0
		 -- 2 not confirm and not gen file, 0 not confirm and gen file, 1 confirm and gen file
		 -- -1 all 
		)

RETURNS @Result TABLE    
	(  
		[SiteGuid]		UNIQUEIDENTIFIER,  
		[SiteName]		NVARCHAR(250) COLLATE Arabic_CI_AI, 
		[PatientGuid]	UNIQUEIDENTIFIER,
		[FILEGUID]		UNIQUEIDENTIFIER,
		[PatientName]	NVARCHAR(250) COLLATE Arabic_CI_AI , 
		[FROM]			DATETIME, 
		[To]			DATETIME,  
		[Type]			INT,  
		[StatusName]	NVARCHAR(250) COLLATE Arabic_CI_AI,  
		[StayGuid]		UNIQUEIDENTIFIER,
		-- Stay or Reservation  
		[StayType]		INT
		-- 1 stay , 2 reserv
	)  
  AS
BEGIN	
	declare 	@TempResult TABLE
	(  
		[SiteGuid]		UNIQUEIDENTIFIER,  
		[SiteName]		NVARCHAR(250) COLLATE Arabic_CI_AI, 
		[PatientGuid]	UNIQUEIDENTIFIER,
		[FILEGUID]		UNIQUEIDENTIFIER,
		[PatientName]	NVARCHAR(250) COLLATE Arabic_CI_AI , 
		[FROM]			DATETIME, 
		[To]			DATETIME,  
		[Type]			INT,  
		[StatusName]	NVARCHAR(250) COLLATE Arabic_CI_AI ,  
		[StayGuid]		UNIQUEIDENTIFIER,
		-- Stay or Reservation  
		[StayType]		INT
		-- 1 stay , 2 reserv
	) 

--Declare @CurrentDate DateTime
--SELECT @CurrentDate = CurrentDate FROM HosCurrentDate000
	INSERT INTO @TempResult
		    SELECT
			Site.Guid,
			Site.Name,
			patient.guid,
			PFile.guid,
			person.[name],
			Stay.StartDate,
			--dbo.IsDate2100( Stay.EndDate, Stay.StartDate) AS EndDate,
			Stay.EndDate,
			1,
			'ãÔÛæá',
			Stay.Guid,
			1
			
	FROM
	HosStay000 AS Stay
	INNER JOIN hospfile000 AS PFile
		 ON Stay.FileGuid = PFile.Guid
	INNER JOIN hospatient000 AS patient 
		ON	patient.guid = PFile.patientGuid
	INNER	JOIN hosperson000 AS person 
		 ON person.Guid = patient.PersonGuid
	 INNER 	JOIN Hossite000 AS Site  
		 ON  Site.Guid  = Stay.SiteGuid 
	 WHERE
		(site.guid = @SiteGuid  OR @SiteGuid = 0x0)
		AND
		(
		  --(@StartDate BETWEEN  Stay.StartDate and dbo.IsDate2100(Stay.EndDate, @CurrentDate))
		  (@StartDate BETWEEN  Stay.StartDate and  Stay.EndDate)
	        OR
		  --(@EndDate BETWEEN  Stay.StartDate and  dbo.IsDate2100(Stay.EndDate, @CurrentDate))	
		  (@EndDate BETWEEN  Stay.StartDate and   Stay.EndDate)	
		OR
		  (Stay.StartDate BETWEEN  @StartDate AND @EndDate)
		OR
		  --(@StartDate >= Stay.StartDate AND  @EndDate <= dbo.IsDate2100(Stay.EndDate, @CurrentDate))
		  (@StartDate >= Stay.StartDate AND  @EndDate <= Stay.EndDate)
		)
	INSERT INTO @TempResult
	    SELECT
			Site.Guid,
			Site.Name,
			patient.guid,
			ISNULL(PFile.guid, 0x0) AS FILEGUID,
			person.[name],
			ReservDetail.FromDate,
			ReservDetail.ToDate,
			2,
			'ãÍÌæÒ',
			ReservDetail.Guid,
			0

		FROM 
		HosReservationDetails000 AS ReservDetail  
		INNER JOIN	 hospatient000 AS patient 
			 ON patient.Guid = ReservDetail.PatientGuid
		 INNER	JOIN hosperson000 AS person 
			 ON person.Guid = patient.PersonGuid
		 INNER 	JOIN Hossite000 AS Site  
			 ON  Site.Guid  = ReservDetail.SiteGuid 
		LEFT JOIN hospfile000 AS PFile
			 ON ReservDetail.FileGuid = PFile.Guid
		WHERE
			(site.guid = @SiteGuid  OR @SiteGuid = 0x0)
			AND
			(@IsResConfirm = -1 OR ReservDetail.ISconfirm =  @IsResConfirm)
			AND
			(
			  (@StartDate BETWEEN  ReservDetail.FromDate and ReservDetail.ToDate)
	        	OR
			  (@EndDate BETWEEN  ReservDetail.FromDate and  ReservDetail.ToDate)	
			OR
			  (ReservDetail.FromDate BETWEEN  @StartDate AND @EndDate)
			OR
			  (@StartDate >= ReservDetail.FromDate AND  @EndDate <= ReservDetail.ToDate)	
			)


	INSERT INTO @TempResult
	    SELECT
			Site.Guid,
			Site.Name,
			0x0,--''patient.guid,
			0x0,--ISNULL(PFile.guid, 0x0) AS FILEGUID,
			'',--person.[name],
			StartDate,
			EndDate,
			5,
			'ÎÇÑÌ ÇáÎÏãÉ',
			siteout.Guid,
			0

		FROM 
		hosSiteout000 AS siteOut
		 INNER 	JOIN Hossite000 AS Site  
			 ON  Site.Guid  = siteOut.SiteGuid 
		WHERE
			(site.guid = @SiteGuid  OR @SiteGuid = 0x0)
			AND
			(
			  (@StartDate BETWEEN  StartDate and EndDate)
	        	OR
			  (@EndDate BETWEEN  StartDate and  EndDate)	
			OR
			  (StartDate BETWEEN  @StartDate AND @EndDate)
			OR
			  (@StartDate >= StartDate AND  @EndDate <= EndDate)	
			)
	INSERT INTO @Result
	SELECT * FROM @TempResult
		order BY SiteName,[FROM]
	--SELECT * FROM @Result 
	
		--order BY SiteName,[FROM]
RETURN 	
END
########################################################################
CREATE FUNCTION FnHosTodayActivity
		(
		@StartDate DateTime,
		@EndDate   DateTime
		)


RETURNS @Result TABLE    
	(  
		Guid 			UNIQUEIDENTIFIER,
		[SiteGuid]		UNIQUEIDENTIFIER,  
		[PatientGuid]	UNIQUEIDENTIFIER,
		FileGuid		UNIQUEIDENTIFIER,
		[Name]			NVARCHAR(250) COLLATE Arabic_CI_AI, 
		LatinName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[Type]			INT,  
		PatientSecurity INT,
		FileSecurity    INT,
		StartDate 		DATETIME,
		EndDate			DATETIME	
	)  
AS
	BEGIN	
	Declare  @TempResult TABLE
	(
		Guid 			UNIQUEIDENTIFIER,
		[SiteGuid]		UNIQUEIDENTIFIER,  
		[PatientGuid]	UNIQUEIDENTIFIER,
		FileGuid		UNIQUEIDENTIFIER,
		[Name]			NVARCHAR(250) COLLATE Arabic_CI_AI, 
		LatinName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[Type]			INT,  
		PatientSecurity INT,
		FileSecurity    INT,
		StartDate 		DATETIME,
		EndDate			DATETIME	
	)
	Declare @ToDate_ReservationStays TABLE 
	(
		EndDate		DATETIME,  
		SiteGuid	UNIQUEIDENTIFIER
	)

	INSERT INTO @TempResult
	SELECT * FROM 	fnHos_Res_Stay_Table(@StartDate, @EndDate)
	
	
	INSERT INTO @ToDate_ReservationStays
		SELECT  distinct Max (t.EndDate) AS EndDate, t.SiteGuid 
		FROM @TempResult AS t
	       		GROUP BY t.SiteGuid

	INSERT INTO @Result	
		SELECT  t1.Guid, t1.SiteGuid, t1.PatientGuid,t1.FileGuid,
			t1.Name, t1.LatinName,t1.Type,t1. PatientSecurity, 
			t1.FileSecurity, t1.StartDate, t1.EndDate
		FROM @TempResult AS t1 INNER JOIN @ToDate_ReservationStays AS toDate
		       ON toDate.SiteGuid = t1.SiteGuid  	
		WHERE 
			t1.EndDate = toDate.EndDate
		
RETURN 	
END


########################################################################
CREATE FUNCTION fnViewHosActions
		(
		@StartDate	DateTime,
		@EndDate	DateTime,
		@SiteStatus INT ,-- 0 ALL, 1 Stay, 2 Reserv
		@SiteType	UNIQUEIDENTIFIER
		)
RETURNS @Result TABLE
	(
	[Guid]			UNIQUEIDENTIFIER,  
	[ParentGuid]	UNIQUEIDENTIFIER,
	[Type]			INT,
	[Name]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
	[Code]			NVARCHAR(250) COLLATE ARABIC_CI_AI
	--[ActDate]	DATETIME		
	)
AS
  BEGIN 
	INSERT INTO @Result
		SELECT 
			Guid,
			ParentGuid,
			0,
			Name,
			Code
			--''
			FROM hossite000  AS site
			WHERE @SiteType = 0x0 OR  @SiteType = Site.TypeGuid

	INSERT INTO @Result
		SELECT 
			Act.StayGuid,
			ResSite.Guid,
			Act.Type,
			ResSite.Name,
			ResSite.Code
			--Act.[FROM]
			FROM @Result AS ResSite
			INNER JOIN FnHosAllActivities(0x0, @StartDate, @EndDate, -1) AS Act
				ON Act.SiteGuid = ResSite.Guid 
			WHERE (@SiteStatus = 0 OR  @SiteStatus = Act.Type) 
			Order BY Act.[FROM]
			
RETURN 
END
############################################################
CREATE   FUNCTION FnHosAllTypectivities 
		( 
		@TypeGuid  UNIQUEIDENTIFIER, 
		@StartDate DateTime, 
		@EndDate   DateTime 
		) 
RETURNS @Result TABLE     
	(   
		[SiteGuid]		UNIQUEIDENTIFIER,   
		[SiteName]		NVARCHAR(250) COLLATE Arabic_CI_AI,  
		[PatientGuid]	UNIQUEIDENTIFIER, 
		[PatientName]	NVARCHAR(250) COLLATE Arabic_CI_AI ,  
		[FROM]			DATETIME,  
		[To]			DATETIME,   
		[Type]			INT,   
		[StatusName]	NVARCHAR(250) COLLATE Arabic_CI_AI ,   
		[StayGuid]		UNIQUEIDENTIFIER, 
		-- Stay or Reservation   
		[StayType]		INT 
		-- 1 stay , 2 reserv 
	)   
  AS 
BEGIN	 
	declare 	@TempResult TABLE 
	(   
		[SiteGuid]		UNIQUEIDENTIFIER,   
		[SiteName]		NVARCHAR(256) COLLATE Arabic_CI_AI,  
		[PatientGuid]	UNIQUEIDENTIFIER, 
		[PatientName]	NVARCHAR(250)COLLATE Arabic_CI_AI ,  
		[FROM]			DATETIME,  
		[To]			DATETIME,   
		[Type]			INT,   
		[StatusName]	NVARCHAR(250) COLLATE Arabic_CI_AI ,   
		[StayGuid]		UNIQUEIDENTIFIER, 
		-- Stay or Reservation   
		[StayType]		INT 
		-- 1 stay , 2 reserv 
	)  
	INSERT INTO @TempResult 
		    SELECT 
			Site.Guid, 
			Site.Name, 
			patient.guid, 
			person.[name], 
			Stay.StartDate, 
			Stay.EndDate, 
			1, 
			'ãÔÛæá', 
			Stay.Guid, 
			1 

	FROM 
	 hospatient000 AS patient  
	 INNER	JOIN hosperson000 AS person  
		 ON person.Guid = patient.PersonGuid 
  	 INNER JOIN hospfile000 AS PFile 
		 ON PFile.PatientGuid = Patient.Guid 
	 INNER JOIN HosStay000 AS Stay 
		 ON Stay.FileGuid = PFile.Guid 
	 INNER 	JOIN Hossite000 AS Site   
		 ON  Site.Guid  = Stay.SiteGuid  
	 WHERE 
		(site.TypeGuid = @TypeGuid  OR @TypeGuid = 0x0) 
		AND 
		( 
		  (@StartDate BETWEEN  Stay.StartDate and Stay.EndDate) 
	        OR 
		  (@EndDate BETWEEN  Stay.StartDate and  Stay.EndDate)	 
		OR 
		  (Stay.StartDate BETWEEN  @StartDate AND @EndDate) 
		OR 
		  (@StartDate >= Stay.StartDate AND  @EndDate <= Stay.EndDate)	 
		) 
	INSERT INTO @TempResult 
	    SELECT 
			Site.Guid, 
			Site.Name, 
			patient.guid, 
			person.[name], 
			ReservDetail.FromDate, 
			ReservDetail.ToDate, 
			2, 
			'ãÍÌæÒ', 
			ReservDetail.Guid, 
			0 
		FROM  
		 hospatient000 AS patient  
		 INNER	JOIN hosperson000 AS person  
			 ON person.Guid = patient.PersonGuid 
		 INNER 	JOIN HosReservationDetails000 AS ReservDetail   
			 ON patient.Guid = ReservDetail.PatientGuid 
		 INNER 	JOIN Hossite000 AS Site   
			 ON  Site.Guid  = ReservDetail.SiteGuid  
		WHERE 
			(site.TypeGuid = @TypeGuid  OR @TypeGuid = 0x0) 
			AND 
			( 
			  (@StartDate BETWEEN  ReservDetail.FromDate and ReservDetail.ToDate) 
	        	OR 
			  (@EndDate BETWEEN  ReservDetail.FromDate and  ReservDetail.ToDate)	 
			OR 
			  (ReservDetail.FromDate BETWEEN  @StartDate AND @EndDate) 
			OR 
			  (@StartDate >= ReservDetail.FromDate AND  @EndDate <= ReservDetail.ToDate)	 
			) 
	INSERT INTO @Result 
	SELECT * FROM @TempResult 
		order BY SiteName,[FROM] 
	--SELECT * FROM @Result  
	 
		--order BY SiteName,[FROM] 
RETURN 	 
END
#######################################################
create proc hosGetSitesStatus
			@FromDate	DATETIME,
			@ToDate		DATETIME
AS
Declare @currentDate DateTime
set @CurrentDate = GetDate()
Declare @date DateTime
Create TABLE #temp 
		(
		SiteGuid UNIQUEIDENTIFIER,
		Status	INT-- 0 empty ,
		)
	
	INSERT  INTO #temp
	SELECT
		distinct(Stay.SiteGuid),
		1
	FROM HosStay000 AS Stay
	WHERE
		StartDate BETWEEN @FromDate AND @ToDate 
	OR				
		dbo.IsDate2100(EndDate, @currentDate)  BETWEEN @FromDate AND @ToDate 
	OR
		@FromDate BETWEEN StartDate AND EndDate
		
	SELECT 	
		s.[Guid],
		s.[code],
		s.[name],
		s.[LatinName],
		type.[Name],
		type.bMultiPatient,	
		ISNULL(t.Status, 0 ) AS Status,
		S.[Security]
	FROM HosSite000 AS s
	INNER JOIN hosSiteType000 AS type ON Type.Guid =  s.TypeGuid
	LEFT JOIN #temp AS t ON s.Guid = t.SiteGuid
########################################################
CREATE FUNCTION  fnHosGetSitesStatus
	(
		@FromDate		DATETIME,
		@ToDate			DATETIME,
		@CurrentDate 	DATETIME -- IS DATE UNDIFINED SET THIS DATE  	
	)
RETURNS @Result TABLE
	(
		[Guid]			UNIQUEIDENTIFIER,
		[ActGuid]		UNIQUEIDENTIFIER,
		[code]			NVARCHAR(250) COLLATE Arabic_CI_AI,
		[name]			NVARCHAR(250) COLLATE Arabic_CI_AI,
		[LatinName]		NVARCHAR(250) COLLATE Arabic_CI_AI,
		[typeName]		NVARCHAR(250) COLLATE Arabic_CI_AI,
		[bMultiPatient] INT,	
		[Status]		INT, 
		[Security]		INT
	)
AS 
BEGIN 
DECLARE @temp TABLE 
		(
		SiteGuid UNIQUEIDENTIFIER,
		ActGuid  UNIQUEIDENTIFIER,
		Status	INT-- 0 empty ,
		)
	
	INSERT  INTO @temp
	SELECT
		Stay.SiteGuid,
		FileGuid,	
		1
	FROM HosStay000 AS Stay
	WHERE
		StartDate BETWEEN @FromDate AND @ToDate 
	OR				
		dbo.IsDate2100(EndDate, @currentDate)  BETWEEN @FromDate AND @ToDate 
	OR
		@FromDate BETWEEN StartDate AND EndDate
		
	INSERT  INTO @temp
	SELECT
		res.SiteGuid,
		FileGuid,
		2
		/*
		SELECT * FROM HosReservationDetails000
		*/
	FROM HosReservationDetails000 AS Res
	WHERE
		(IsConfirm = 0)
	AND	
		( 
			FromDate BETWEEN @FromDate AND @ToDate 
		OR				
			ToDate  BETWEEN @FromDate AND @ToDate 
		OR
			@FromDate BETWEEN FromDate AND ToDate
		)

	INSERT  INTO @temp
	SELECT
		SiteGuid,
		Guid,
		5
	FROM HosSiteout000 
	WHERE
		StartDate BETWEEN @FromDate AND @ToDate 
	OR				
		EndDate  BETWEEN @FromDate AND @ToDate 
	OR
		@FromDate BETWEEN StartDate AND EndDate

	INSERT INTO @Result
	SELECT 	
		s.[Guid],
		ISNULL(t.ActGuid, 0x0) AS ActGuid,
		s.[code],
		s.[name],
		s.[LatinName],
		type.[Name],
		type.bMultiPatient,
		ISNULL(t.Status, 0 ) AS Status,
		S.[Security]
	FROM HosSite000 AS s
	INNER JOIN hosSiteType000 AS type ON Type.Guid =  s.TypeGuid
	LEFT JOIN @temp AS t ON s.Guid = t.SiteGuid
	
	order BY  t.Status --desc
RETURN 
END
############################################################
CREATE FUNCTION IsSiteFree	  
		( 
			@SiteGuid 		UNIQUEIDENTIFIER,	 
			@FromDate		DATETIME, 
			@EndDate		DATETIME, 
			@IgnoredActGuid	UNIQUEIDENTIFIER = 0x0	
			-- when modefiy action card we ignore old one 
		) 
RETURNS [INT]  
-- 0 free, otherwise not free, 1 busy, 2 reserved, 5 out (offduty), 70 VARIOS ACTIONS
AS 
BEGIN 

DECLARE @TEMP TABLE
	(
		[Status] INT
	)
	DECLARE @Multipatient [INT] --, @Status [INT] 
	DECLARE @all INT, @Res [INT],  @Bus [INT], @out [INT]
	
	/*SELECT  
		@Multipatient = bMultiPatient, 
		@Status = Status 
		FROM fnHosGetSitesStatus(@FromDate, @EndDate, @EndDate) 
	WHERE @SiteGuid = Guid 
	*/
	INSERT INTO @TEMP 
	SELECT  Status
	FROM fnHosGetSitesStatus(@FromDate, @EndDate, @EndDate) 
	WHERE GUID = @SiteGuid and @IgnoredActGuid <> ActGuid
	
	SELECT @all = COUNT(*) FROM @TEMP

	IF (@all = 0)
		RETURN 0 

	IF (@all = 1)
	BEGIN
		DECLARE @S INT 
		SELECT @S = Status FROM @TEMP
		IF (@S = 0)
			RETURN 	0
	END
	SELECT @bus = COUNT(*) FROM  @TEMP
	WHERE Status = 1
	
	IF (@bus = @all)
	BEGIN
		DECLARE @IsMultiPatient INT
		SELECT @IsMultiPatient =  bMultiPatient 
			FROM HosSite000 AS s 
			INNER JOIN hosSitetype000 AS T  ON t.guid = s.typeguid 
			WHERE s.guid =  @SiteGuid
		IF (@IsMultiPatient = 1)  --stay @ multi patients  
			RETURN 0
		RETURN 1
	END
	
	SELECT @Res = COUNT(*) FROM @TEMP
	WHERE Status = 2
	
	IF (@res = @all)
		RETURN 2
	
	SELECT @out = COUNT(*) FROM @TEMP
	WHERE Status = 5

	IF (@out = @all)
		RETURN 5
	
	RETURN 70

END 
#############################################################
CREATE FUNCTION  VwHosSitesStatus
	(
		@FromDate		DATETIME,
		@ToDate			DATETIME,
		@CurrentDate 	DATETIME -- IS DATE UNDIFINED SET THIS DATE  	
	) 
RETURNS @Result TABLE	 
	( 
		[Guid]			UNIQUEIDENTIFIER, 
		[code]			NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[name]			NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[LatinName]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[typeName]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[bMultiPatient] NCHAR (1), 
		[Status]		NVARCHAR(20) COLLATE ARABIC_CI_AI,  
		[COUNT]			NCHAR(5),
		[Security] INT 
	) 
AS  
BEGIN  

INSERT INTO @Result 
SELECT 
	[Guid], 
	[code], 
	[name], 
	[LatinName], 
	[Name], 
	CAST([bMultiPatient] AS NCHAR(1))  bMultiPatient , 
	CAST(Status AS NCHAR(20))  Status , 
	'',
	[Security] 
FROM dbo.fnHosGetSitesStatus(@FromDate, @ToDate, @CurrentDate) 
WHERE  Status = 0 --- empty

declare @Stay TABLE (
	--code NVARCHAR(200),
	[Guid] UNIQUEIDENTIFIER,
	[COUNT] INT)
INSERT INTO @stay
SELECT 
	guid,
	--[guid], 
 	COUNT(status)
FROM dbo.fnHosGetSitesStatus(@FromDate, @ToDate, @CurrentDate) AS f
WHERE  Status = 1 --- stay 
GROUP BY guid
	
INSERT INTO @Result 
SELECT 
	distinct(f.[Guid]), 
	[code], 
	[name], 
	[LatinName], 
	[Name], 
	CAST([bMultiPatient] AS NCHAR(1))  bMultiPatient , 
	CAST(Status AS NCHAR(20))  Status , 
	CAST(s.[COUNT] AS NCHAR(20))  [COUNT] , 
	[Security] 
FROM	dbo.fnHosGetSitesStatus(@FromDate, @ToDate, @CurrentDate)  AS f
	INNER JOIN  @Stay AS s ON  s.guid = f.guid
	WHERE f.status = 1

INSERT INTO @Result 
SELECT 
	[Guid], 
	[code], 
	[name], 
	[LatinName], 
	[Name], 
	CAST([bMultiPatient] AS NCHAR(1))  bMultiPatient , 
	CAST(Status AS NCHAR(20))  Status , 
	'',--COUNT
	[Security] 
FROM dbo.fnHosGetSitesStatus(@FromDate, @ToDate, @CurrentDate) 
WHERE Status <> 0 and Status <> 1 

RETURN  
END 
#############################################################
CREATE FUNCTION  fnHosGetEmptySites
	(
		@FromDate		DATETIME,
		@ToDate			DATETIME,
		@CurrentDate 	DATETIME -- IS DATE UNDIFINED SET THIS DATE  	
	)
RETURNS @Result TABLE
	(
		[Guid]			UNIQUEIDENTIFIER,
		[ActGuid]		UNIQUEIDENTIFIER,
		[code]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[name]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[LatinName]		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[typeName]		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[bMultiPatient] INT,
		[Status]		INT,
		[Security]		INT
	)
AS 
BEGIN 
	INSERT INTO @Result 
	SELECT * FROM fnHosGetSitesStatus(@FromDate, @ToDate, @CurrentDate)
	WHERE Status = 0
	RETURN 
END
#######################################################
#END
