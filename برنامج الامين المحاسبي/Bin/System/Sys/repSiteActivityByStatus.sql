##########################################
CREATE PROCEDURE repSiteActivityByStatus
	@SiteGUID				UNIQUEIDENTIFIER = 0x0,  
	@Status					INT = 5,  
	@SiteType				UNIQUEIDENTIFIER = 0x0,  
	@StartDate				DATETIME,  
	@EndDate				DATETIME,  
	@useStartReserveDate	INT = 0,  
	@useEndReserveDate		INT = 0,  
	@ShowEmptyPeriods		INT = 1,  
	@EmptyExactInPeriod		INT = 0 ---- 1 EmptyExact,  2 EmptyPartial,   0 All Activity  
AS  
SET NOCOUNT ON 
	--DECLARE @RepType AS INT  
	CREATE TABLE #Result  
	(  
		[SiteGuid]		UNIQUEIDENTIFIER,  
		[SiteName]		NVARCHAR(256) 	COLLATE Arabic_CI_AI, 
		[From]			DATETIME, 
		[To]			DATETIME,  
		[Status]		INT,  
		[CurStatusName]		NVARCHAR(250) 	COLLATE Arabic_CI_AI , 
		[StatusName]		NVARCHAR(250) 	COLLATE Arabic_CI_AI ,  
		[PatientName]		NVARCHAR(250)	COLLATE Arabic_CI_AI , 
		[Owner]			NVARCHAR(250)	COLLATE Arabic_CI_AI  
	)  
	CREATE TABLE #SecondResult  
	(  
		[SiteGuid]		UNIQUEIDENTIFIER,  
		[SiteName]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[From]			DATETIME,  
		[To]			DATETIME,  
		[Status]		INT,  
		[CurStatusName]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[StatusName]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[PatientName]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[Owner]			NVARCHAR(250) COLLATE ARABIC_CI_AI-- ÕÇÍÈ ÇáÍÌÒ  
	)  
	DECLARE @TheNotes NVARCHAR(256) 
	SELECT  @TheNotes = ' :ÅÖÈÇÑÉ ' --CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'dossier: ' ELSE ' :ÅÖÈÇÑÉ ' END	  
	---/// SITE STATUS NUMBER 
	DECLARE  @AutoBlock INT 
        DECLARE  @ManualBlock INT 
        DECLARE  @Occupied INT 
	DECLARE  @Vacant INT 
	DECLARE  @OuOfOrder INT 
	DECLARE  @AllStatus INT 
	SET  @AutoBlock = 0 
        SET  @ManualBlock = 1 
        SET  @Occupied = 2 
	SET  @Vacant = 3 
	SET  @OuOfOrder = 4 
	SET  @AllStatus = 5 
	---/// SITE STATUS NAME 
	 
	DECLARE  @AutoBlock_Name NVARCHAR(256) 
	DECLARE  @ManualBlock_Name  NVARCHAR(256) 
	DECLARE  @Occupied_Name  NVARCHAR(256) 
	DECLARE  @Vacant_Name  NVARCHAR(256) 
	DECLARE  @OuOfOrder_Name  NVARCHAR(256) 
	 
	SELECT @AutoBlock_Name = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'AutoBlock' ELSE 'ãÍÌæÒÉ ãÄÞÊÇð' END	 
	SELECT @ManualBlock_Name  = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'ManualBlock' ELSE 'ãÍÌæÒÉ' END	 
	SELECT @Occupied_Name = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'ManualBlock' ELSE 'ãÔÛæáÉ' END	 
	SELECT @Vacant_Name = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Vacant' ELSE 'ÝÇÑÛÉ' END	 
	SELECT @OuOfOrder_Name = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'OuOfOrder' ELSE 'ÎÇÑÌ ÇáÎÏãÉ' END	 
	IF @Status	=  @Occupied OR @Status = @AllStatus 
	BEGIN  
	-- @RepType = 1 ÇáãæÇÞÚ ÇáãÔÛæáÉ ÝÚáíÇð  
		INSERT INTO #Result  
		SELECT  
			d.[SiteGUID],  
			d.[SiteCode]+'-'+d.[SiteName],  
			d.[StayStartDate],  
			d.[StayEndDate],  
			d.[SiteState],  
			d.[SiteStatus], 
			@Occupied_Name, 
			F.[Name], -- patientName  
			''  
		FROM  
			[VwHosStay] AS d LEFT JOIN [vwHosFile] AS F ON d.[StayFileGuid] = F.[Guid]  
		WHERE  
			( @SiteGUID = 0x0 OR  @SiteGUID = d.[SiteGuid] )  
			AND ( @SiteType = 0x0  OR  @SiteType = d.[SiteTypeGuid])  
			AND ( ( @useStartReserveDate = 0)   
				OR (( d.[StayStartDate] >= @StartDate ) AND ( (@EmptyExactInPeriod = 0) OR ( d.[StayEndDate] <= @EndDate) ))  
				OR ( ( d.[StayEndDate] >= @StartDate) AND (@EmptyExactInPeriod = 0))  
				)  
			AND ( @useEndReserveDate = 0 OR  d.[StayEndDate] <= @EndDate )  
	END  
	IF @Status = @Vacant OR @Status = @AllStatus 
	BEGIN  
		print '2'  
	-- @RepType = 2 ÇáãæÇÞÚ ÇáÝÇÑÛÉ ÇáÊí ÍÇáÊåÇ ÝÇÑÛÉ  
		INSERT INTO #Result  
		SELECT  
			s.[GUID],  
			s.[Name],  
			t.[StartDate],  
			t.[EndDate],  
			s.[State],  
			S.Status,  
			@Vacant_Name,  
			'', -- patient	  
			'' -- owner  
		FROM fnHosSite(0x0) AS s LEFT JOIN [HosStay000] AS t  
			ON s.[Guid] = t.[SiteGuid]  
		WHERE  
			(  @SiteGUID = 0x0  OR @SiteGUID = t.[SiteGuid])  
			AND ( @SiteType = 0x0  OR @SiteType = s.[TypeGuid])  
			AND ( @useStartReserveDate = 0 OR t.[StartDate] >= @StartDate )  
			AND ( @useEndReserveDate = 0 OR  t.[EndDate] <= @EndDate )  
			AND s.[Guid] Is NULL  
	END  
	IF @Status= @ManualBlock OR @Status = @AllStatus 
	BEGIN  
	-- @RepType = 3 ÇáãæÇÞÚ ÇáãÍÌæÒÉ  
		print '3'  
		INSERT INTO #Result  
		SELECT  
			d.[SiteGUID],  
			d.[SiteName],  
			d.[FromDate],  
			d.[ToDate],  
			s.[State],  
			s.[Status],  
			@ManualBlock_Name,  
			d.PatientName,  
			r.AcName  
		FROM   
			[vwHosReservationDetails] AS d  
				INNER JOIN [vwHosReservation] AS r ON d.[ParentGuid] = r.[Guid]  
				INNER JOIN fnHosSite(0x0) AS s ON d.[SiteGUID] = s.[GUID]  
		WHERE  
			( @SiteGUID = 0x0 OR @SiteGUID = d.[SiteGuid])  
			AND ( @SiteType = 0x0 OR @SiteType = s.[TypeGuid])  
			AND ( @useStartReserveDate = 0 OR  d.[FromDate] >= @StartDate)  OR d.[ToDate] >= @StartDate 
			AND ( @useEndReserveDate = 0 OR d.[ToDate] <= @EndDate)  
	END  
	IF (@ShowEmptyPeriods = 1 )  
	BEGIN  
		print '4'  
		-- Add Empty Sites which are empty between reservation and busy  
		DECLARE		@PrevSiteGuid_c			UNIQUEIDENTIFIER  
		DECLARE		@PrevSiteName_c			NVARCHAR(256)  
		DECLARE		@PrevFrom_c				DATETIME  
		DECLARE		@PrevTo_c				DATETIME  
		DECLARE		@PrevStatus_c		INT  
		DECLARE		@PrevCurStatusName_c	NVARCHAR(250)  
		DECLARE		@PrevStatusName_c		NVARCHAR(250)  
		DECLARE		@SiteGuid_c				UNIQUEIDENTIFIER  
		DECLARE		@SiteName_c				NVARCHAR(256)  
		DECLARE		@From_c					DATETIME  
		DECLARE		@To_c					DATETIME  
		DECLARE		@Status_c			INT  
		DECLARE		@CurStatusName_c		NVARCHAR(250)  
		DECLARE		@StatusName_c			NVARCHAR(250)  
		DECLARE		@PatientName_c			NVARCHAR(250)  
		DECLARE		@AccName_c				NVARCHAR(250)  
	  
		DECLARE cr CURSOR FOR SELECT * FROM #Result ORDER BY [SiteGuid], [From], [To]  
		OPEN cr  
		FETCH NEXT FROM cr INTO @SiteGuid_c, @SiteName_c, @From_c, @To_c, @Status_c, @CurStatusName_c, @StatusName_c, @PatientName_c, @AccName_c  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			SET @PrevSiteGuid_c			= @SiteGuid_c  
			SET @PrevSiteName_c 		= @SiteName_c  
			SET @PrevFrom_c 			= @From_c  
			SET @PrevTo_c 				= @To_c  
			SET @PrevStatus_c 		= @Status_c  
			SET @PrevCurStatusName_c 	= @CurStatusName_c  
			SET @PrevStatusName_c 		= @StatusName_c  
			  
			FETCH NEXT FROM cr INTO @SiteGuid_c, @SiteName_c, @From_c, @To_c, @Status_c, @CurStatusName_c, @StatusName_c, @PatientName_c, @AccName_c  
	  
			IF (@SiteGuid_c = @PrevSiteGuid_c) AND (@PrevTo_c < @From_c)  
				INSERT INTO #SecondResult VALUES ( @PrevSiteGuid_c, @PrevSiteName_c, @PrevTo_c, @From_c, 0x0 , @PrevCurStatusName_c, 'ÝÇÑÛ', '', '')-- @StatusName_c  
			ELSE IF (@SiteGuid_c <> @PrevSiteGuid_c OR @@FETCH_STATUS <> 0) AND ( @PrevTo_c < @EndDate)  
				INSERT INTO #SecondResult VALUES ( @PrevSiteGuid_c, @PrevSiteName_c, @PrevTo_c, @EndDate, 0x0 , @PrevCurStatusName_c, 'ÝÇÑÛ', '', '')-- @StatusName_c  
		END  
		CLOSE cr  
		DEALLOCATE cr  
	  
		-- Fill Result With Empty Ranges of Sites founded in #Result  
		INSERT INTO #Result  SELECT * FROM #SecondResult  
	END  
	--- ÅÖÇÝÉ ÇáãæÇÞÚ ÇáÊí áíÓ ÚáíåÇ ÍÑßÉ Èíä ÊÇÑíÎíä  
	--- ÅÍÖÇÑ ÇáãæÇÞÚ ÇáÊí áíÓ ÚáåÇ ÍÑßÉ ÃÕáÇð Ãí ÝÇÑÛÉ ÈÇáÃÕá  
	-- Add Empty Sites which was not Added to #Result  
	IF (@ShowEmptyPeriods = 1 ) 
		INSERT INTO #Result  
		SELECT  
			s.[GUID],  
			s.[Name],  
			@StartDate,  
			@EndDate,  
			s.[State],  
			s.[Status],  
			@Vacant_Name,  
			'',  
			''  
		FROM  
			fnHosSite(0x0) AS s LEFT JOIN #Result AS t ON s.[GUID] = t.[SiteGuid]  
		WHERE  
			(t.[SiteGUID] IS NULL)  
			AND ( @SiteGUID = 0x0 OR @SiteGUID = s.[Guid] OR s.[stGuid] = 0x0)  
			AND ( @SiteType = 0x0 OR @SiteType = s.[TypeGuid])  
	SELECT * FROM #Result ORDER BY [SiteGuid], [From], [To]  
####################################################
#END