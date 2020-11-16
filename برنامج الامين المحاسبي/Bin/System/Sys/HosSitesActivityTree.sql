########################################################################
CREATE procedure HosSiteTodayTree
		(
		@Lang		INT = 0 , 
		@StartDate DateTime,
		@EndDate   DateTime,
		@Status    INT, -- 0 ALL , 1 Stay, 2 Reserv, 4 empty
		@SiteType UNIQUEIDENTIFIER	
		)
as 
SET NOCOUNT ON 
create Table #Result
	(  
	SiteGuid		UNIQUEIDENTIFIER,    
	ParentGuid 		UNIQUEIDENTIFIER,
	TypeGuid 		UNIQUEIDENTIFIER,
	PatientGuid		UNIQUEIDENTIFIER,
	FileGuid		UNIQUEIDENTIFIER,
	Code			NVARCHAR(255) COLLATE ARABIC_CI_AI,    
	[Name]			NVARCHAR(255) COLLATE ARABIC_CI_AI,    
	[LatinName]		NVARCHAR(255) COLLATE ARABIC_CI_AI,    
	[PersonName]	NVARCHAR(255) COLLATE ARABIC_CI_AI,    
	Type 			INT, ----- 0 Sites ,1 Stay , 2 Reservations  
	Number			FLOAT,    
	SiteSecurity	INT,
	PatientSecurity INT,----  Patient Security  
	FileSecurity    INT,---- File Security 
	StartDate		DateTime,
	EndDate   		DateTime,
	[Level] 		INT,    
	[Path] 			NVARCHAR(max) COLLATE ARABIC_CI_AI    
	)  

	--exec HosSetCurrentDate
	CREATE TABLE #SiteTree(    
				GUID 		UNIQUEIDENTIFIER,
				Type 		INT,
				[Level] 	INT,    
				[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI    
				)    

	INSERT INTO #SiteTree
	SELECT * from dbo.fnHosSitesActivityTree(0x0, @StartDate, @EndDate, @Status, @SiteType,0) 

	CREATE TABLE #Activities(    
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
	INSERT INTO #Activities
	SELECT * from 
	dbo.FnHosTodayActivity(@StartDate, @EndDate) 

	
	INSERT INTO #Result	
		SELECT  

			site.Guid,
			ISNull(site.ParentGUID , 0x0) AS ParentGuid,
			ISNull(site.TypeGuid, 0x0) AS TypeGuid ,
			ISNull(act.PatientGuid, 0x0) AS PatientGuid ,
			ISNull(act.FileGuid, 0x0) AS FileGuid ,
			site.code,
			site.[Name],
			site.LatinName,
			IsNull(act.[name],'') AS PersonName,
			ISNull(act.type,4) AS type,
			site.Number,
			Site.Security,
			IsNull(act.PatientSecurity,0) AS PatientSecurity,
			IsNull(act.FileSecurity,0) AS FileSecurity,
			IsNull(act.startDate,'') AS startDate,
			IsNull(act.EndDate,'') AS EndDate,
			tree.[level],
			tree.[path]	
			FROM
				#SiteTree as tree 
				INNER join vwHosSite as site ON tree.Guid = site.Guid
				left join #Activities as act ON act.SiteGuid = site.Guid

select
			r.SiteGuid,
			r.ParentGuid,
			r.TypeGuid ,
			r.PatientGuid ,
			r.FileGuid ,
			r.code,
			r.[Name],
			r.LatinName,
			r.[personname],
			r.type,
			r.Number,
			r.SiteSecurity,
			r.PatientSecurity,
			r.FileSecurity,
			r.startDate,
			r.EndDate,
			r.[level],
			r.[path]	

 from #Result as r 


########################################################################
CREATE FUNCTION fnHosSitesActivityTree(    
			@SiteGUID UNIQUEIDENTIFIER,   
			@StartDate DateTime,
			@EndDate   DateTime,
			@Status    INT,
			@SiteType UNIQUEIDENTIFIER,			
			@Sorted INT = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)   
		RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER, Type INT,[Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI)

AS BEGIN   
	DECLARE @FatherBuf TABLE( GUID UNIQUEIDENTIFIER, Type INT,[Level] INT, [Path] NVARCHAR(max), ID INT IDENTITY( 1, 1))    
	DECLARE @Continue INT, @Level INT     
	SET @Level = 0      
	  
	IF ISNULL( @SiteGUID, 0x0) = 0x0 
		INSERT INTO @FatherBuf ( GUID,Type, Level, [Path])   
			SELECT GUID, 0 ,@Level, ''  
			FROM 	 vwHosSite AS site
				WHERE   ISNULL( ParentGUID, 0x0) = 0x0  
					AND 
					(@SiteType = 0x0 OR @SiteType = site.TypeGuid)

			ORDER BY CASE @Sorted WHEN 1 THEN Code ELSE [Name] END  
	ELSE    
		INSERT INTO @FatherBuf ( GUID, Level, [Path])   
			SELECT GUID, @Level, '' FROM vwHosSite WHERE GUID = @SiteGUID 
	   
	UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40))    
	SET @Continue = 1    
	---/////////////////////////////////////////////////////////////    
	WHILE @Continue <> 0 
	BEGIN    
		SET @Level = @Level + 1      

		INSERT INTO @FatherBuf( GUID, Type,Level, [Path])    

			SELECT 
				Ana.GUID,
				Ana.Type,
				@Level,
				fb.[Path]   
				FROM fnViewHosActions(@StartDate, @EndDate, @Status, @SiteType) AS Ana
			        INNER JOIN @FatherBuf AS fb ON Ana.ParentGUID = fb.GUID 
				WHERE fb.Level = @Level - 1  
				ORDER BY
				  CASE @Sorted 
					WHEN 1 THEN Code 
					ELSE [Name] 
				  END   
			SET @Continue = @@ROWCOUNT      
			UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level      
	
	END   
	INSERT INTO @Result SELECT GUID,Type,[Level], [Path] FROM @FatherBuf /*GROUP BY GUID ,[Level], [Path] */ORDER BY/* Type ,*/[Path]  
	RETURN   
END 
################################################################################################
CREATE  PROCEDURE HosSitesActivityTree
		@Lang		INT = 0 , 
		--@Guid		UNIQUEIDENTIFIER = 0x0,
		@StartDate DateTime,
		@EndDate   DateTime,
		@Status    INT,-- 0 ALL , 1 Stay, 2 Reserv
		@SiteType UNIQUEIDENTIFIER,	
		@Sort 		INT  = 0
AS    
SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT)    
	
	CREATE TABLE #Result(    
			Guid		UNIQUEIDENTIFIER,    
			ParentGuid 	UNIQUEIDENTIFIER,
			--- patient guid contain site type guid if record is site
			PatientGuid 	UNIQUEIDENTIFIER,
			FileGuid	UNIQUEIDENTIFIER,
			Code		NVARCHAR(255) COLLATE ARABIC_CI_AI,    
			[Name]		NVARCHAR(1023) COLLATE ARABIC_CI_AI,    
			[LatinName]	NVARCHAR(255) COLLATE ARABIC_CI_AI,    
			Type 		INT, ----- 0 Sites ,1 Stay , 2 Reservations  
			Number		FLOAT,    
			Security	INT,----  Patient Security  
			FileSecurity    INT,---- File Security 
			StartDate DateTime,
			EndDate   DateTime,
			[Level] 	INT,    
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI    
			)    
	CREATE TABLE #SiteTree(    
			GUID 		UNIQUEIDENTIFIER,
			Type 		INT,
			[Level] 	INT,    
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI    
			)    

	--exec HosSetCurrentDate
	INSERT INTO #SiteTree
	SELECT * from dbo.fnHosSitesActivityTree(0x0, @StartDate, @EndDate, @Status, @SiteType,@Sort) 


	CREATE TABLE #Activities(    
			Guid 		UNIQUEIDENTIFIER,
			SiteGuid	UNIQUEIDENTIFIER,
			PatientGuid 	UNIQUEIDENTIFIER,
			FileGuid	UNIQUEIDENTIFIER,
			---PatientCode	NVARCHAR(255) COLLATE ARABIC_CI_AI,
			---FileCode	NVARCHAR(255) COLLATE ARABIC_CI_AI,
			Name		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			LatinName	NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			---PatientNumber   Float,
			---FileNumber   	Float, 
			Type 		INT,
			PatientSecurity INT,
			FileSecurity    INT,
			StartDate 	DATETIME,
			EndDate		DATETIME	
			)


	INSERT INTO #Activities
	SELECT * from dbo.fnHos_Res_Stay_Table(@StartDate, @EndDate)

--------insert data related to  sites
	-------SITES-------
	INSERT INTO #Result     
	SELECT     
			[ana].[Guid],     
			ISNull(ana.ParentGUID , 0x0) AS ParentGuid,
			ISNull(ana.TypeGuid, 0x0) AS PatientGuid ,
			0x0,    
			ana.Code,     
			Ana.Name,   
			Ana.LatinName,   
			Tree.Type,   
			ana.Number,   
			ana.Security,    
			0,-- for file security , used in Reservations and stays 
			null,
			null,
			Tree.[Level],   
			Tree.Path    
		FROM 	   
			vwHosSite as ana INNER JOIN  #SiteTree AS Tree
  		           ON ana.Guid = Tree.Guid

--------insert data related to stayes AND RESERVATIONS 
		------- STAYES AND RESERVATIONS -------
	INSERT INTO #Result     
	SELECT     
			[Act].[Guid],     --Guid 
			Act.SiteGuid,     --parent guid
			Act.PatientGuid,  --patient guid     
			Act.FileGuid,	  --file guid
			'',		  --code	
			Act.Name,--dbo.HosConcatDescription(@Lang,Act.Type,Act.Name,Act.StartDate,Act.EndDate),   
			'',--Act.LatinName,   
			Act.Type,   
			0,-- number   
			Act.PatientSecurity,    
			Act.FileSecurity, 
			Act.StartDate,
			Act.EndDate,
			Tree.[Level],   
			Tree.Path    
		FROM 	   
			#SiteTree AS Tree INNER JOIN #Activities AS Act ON Tree.Guid = Act.guid

		CREATE TABLE #LastResult (   
					  ItemGUID UNIQUEIDENTIFIER,   
					  LastResult NVARCHAR(255))  

	--EXEC prcCheckSecurity    
	SELECT * FROM #Result ORDER BY Path  
	SELECT * FROM #SecViol 
##################################################################
CREATE Function HosConcatDescription
		(
		  @LANG INT,
		  @Type	INT, 			
		  @Name NVARCHAR(255),
		  @FromDate DateTime,
		  @ToDate DateTime
		)
   RETURNS  NVARCHAR(511)
AS
BEGIN
	DECLARE	@RESULT NVARCHAR(511)
	DECLARE @Reserv NVARCHAR(20)
	

	IF ( @LANG = 0) 
	  SET @Reserv ='„ÕÃÊ“… „‰ ﬁ»· '
	ELSE 
	  SET @Reserv = 'It Reserved From'
	
	DECLARE @Stay NVARCHAR(20)
	IF ( @LANG = 0) 
	  SET @Stay = '„‘€Ê·… „‰ ﬁ»· '
	ELSE 
	  SET  @Stay = 'It Occobied From'
	
	DECLARE @From NVARCHAR(20)
	IF ( @LANG = 0) 
	  SET @From = '„‰  «—ÌŒ'
	ELSE 
	  SET  @FROM =  'From Date'
		

	DECLARE @To NVARCHAR(20)
	IF ( @LANG = 0) 
	  SET @To = 'Ê·€«Ì…'
	ELSE 
	  SET @To = 'Until '


	IF (@Type = 1)
	   SET @RESULT = @Stay 
	ELSE
	   SET @RESULT = @Reserv
	

	SET @RESULT = @RESULT + @Name + ' ' + @FROM 

	SET @RESULT =  @RESULT  + ' ' + CAST( @FromDate AS NVARCHAR(100)) 

	SET @RESULT =  @RESULT + ' ' + @To 

	SET @RESULT = @RESULT  + ' ' + CAST( @ToDate AS NVARCHAR(100)) 
Return @RESULT
END
##################################################################
#END
