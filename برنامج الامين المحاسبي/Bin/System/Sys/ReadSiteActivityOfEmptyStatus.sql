################################################################################
CREATE PROCEDURE ReadSiteActivityOfEmptyStatus
	@SiteGUID				UNIQUEIDENTIFIER = 0x0, 
	@SiteType				UNIQUEIDENTIFIER = 0x0, 
	@StartDate				DATETIME= '1-1-2000', 
	@EndDate				DATETIME= '1-1-2020', 
	@useStartReserveDate	INT = 0, 
	@useEndReserveDate		INT = 0, 
	@ShowEmptyPeriods		INT = 1, 
	@EmptyExactInPeriod		INT = 0 ---- 1 EmptyExact,  2 EmptyPartial,   0 All Activity 
AS
SET NOCOUNT ON 
	CREATE TABLE #Result
	( 
		[SiteGuid]		UNIQUEIDENTIFIER, 
		[SiteName]		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		[From]			DATETIME, 
		[To]			DATETIME, 
		[Status]	NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[CurrentStatus]	NVARCHAR(256) COLLATE ARABIC_CI_AI
	) 
	CREATE TABLE #Exclude 
	( 
		[SiteGuid]		UNIQUEIDENTIFIER
	) 
	DELETE FROM #Exclude 
	DECLARE @TheNotes NVARCHAR(256) 
	SELECT @TheNotes = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN ' dossier: ' ELSE N' :إضبارة ' END	 
		
			--1)first read from stay 
			--2)second read from reservation 
			--3)third read from maintenance and cleaning 
		
		-- 1)first read from stay 
	IF @EmptyExactInPeriod = 1 --  EmptyExact
	BEGIN
		INSERT INTO #Exclude
			SELECT t.[SiteGUID] FROM [vwHosStay] AS t 
			WHERE 
				( @SiteGUID = 0x0 OR @SiteGUID = t.[StaySiteGuid] ) 
				AND ( @SiteType = 0x0 OR @SiteType = t.[SiteTypeGuid]) 
				AND 
				( 
					( t.[StayStartDate] >= @StartDate AND t.[StayEndDate] <= @EndDate) 
					OR ( t.[StayStartDate] >= @StartDate AND t.[StayEndDate] >= @EndDate AND t.[StayStartDate] <= @EndDate) 
					OR ( t.[StayStartDate] <= @StartDate AND t.[StayEndDate] <= @EndDate AND t.[StayEndDate] >= @StartDate) 
					OR ( t.[StayStartDate] <= @StartDate AND t.[StayEndDate] >= @EndDate) 
				) 
		-- 2)second read from reservation 
		INSERT INTO #Exclude 
			SELECT t.[SiteGUID] FROM [vwHosReservationDetails] AS t 
			WHERE 
				( @SiteGUID = 0x0 OR @SiteGUID = t.[SiteGuid] ) 
				AND ( @SiteType = 0x0 OR @SiteType = t.[SiteTypeGuid]) 
				AND 
				( 
					( t.[FromDate] >= @StartDate AND t.[ToDate] <= @EndDate) 
					OR ( t.[FromDate] >= @StartDate AND t.[ToDate] >= @EndDate AND t.[FromDate] <= @EndDate) 
					OR ( t.[FromDate] <= @StartDate AND t.[ToDate] <= @EndDate AND t.[ToDate] >= @StartDate) 
					OR ( t.[FromDate] <= @StartDate AND t.[ToDate] >= @EndDate) 
				) 
		--- fill all in #Result 
		INSERT INTO #Result 
		SELECT  
			s.[GUID], 
			s.Code + '-' + case [dbo].[fnConnections_GetLanguage]() when 1 then s.[LatinName] else s.[Name] end, 
			@StartDate,	 
			@EndDate, 
			s.[Status],
			s.[Status]
		FROM [dbo].[fnHosSite](@SiteGUID)AS s  
		WHERE 
			s.[GUID] NOT IN (SELECT [SiteGuid] FROM [#Exclude]) 
			AND ( @SiteType = 0x0 OR @SiteType = s.[TypeGuid]) 
	END
	ELSE IF @EmptyExactInPeriod = 2 OR @EmptyExactInPeriod = 0	-- EmptyPartial OR ALL Activities
	BEGIN
		INSERT INTO #Result
		SELECT
			s.[GUID],
			s.[Name],
			t.[StayStartDate],
			t.[StayEndDate],
			case [dbo].[fnConnections_GetLanguage]() when 1 then 'Occupied' else N'مشغول' end,
			s.Status
		FROM dbo.fnHosSite(@SiteGUID) AS s JOIN [vwHosStay] AS t ON s.[Guid] = t.[SiteGuid]
		WHERE
			( @SiteType = 0x0 OR @SiteType = t.[SiteTypeGuid])
			AND
			(
				(@EmptyExactInPeriod = 0)
				OR
				(
					(@EmptyExactInPeriod = 2)
					AND
						(
							( t.[StayStartDate] >= @StartDate AND t.[StayEndDate] <= @EndDate)
							OR ( t.[StayStartDate] >= @StartDate AND t.[StayEndDate] >= @EndDate AND t.[StayStartDate] <= @EndDate)
							OR ( t.[StayStartDate] <= @StartDate AND t.[StayEndDate] <= @EndDate AND t.[StayEndDate] >= @StartDate)
							OR ( t.[StayStartDate] <= @StartDate AND t.[StayEndDate] >= @EndDate)
						)
				)
			)
		--2)second read from reservation
		INSERT INTO #Result
		SELECT
			s.[GUID],
			s.[Name],
			t.[FromDate],
			t.[ToDate],
			case [dbo].[fnConnections_GetLanguage]() when 1 then 'RESERVED' else N'محجوز' end,
			s.Status
		FROM dbo.fnHosSite(@SiteGUID)  AS s JOIN [vwHosReservationDetails] AS t ON s.[Guid] = t.[SiteGuid]
		WHERE
			( @SiteType = 0x0 OR @SiteType = t.[SiteTypeGuid])
			AND
			(
				(@EmptyExactInPeriod = 0)
				OR
				(
					(@EmptyExactInPeriod = 2)
					AND
						(
							( t.[FromDate] >= @StartDate AND t.[ToDate] <= @EndDate)
							OR ( t.[FromDate] >= @StartDate AND t.[ToDate] >= @EndDate AND t.[FromDate] <= @EndDate)
							OR ( t.[FromDate] <= @StartDate AND t.[ToDate] <= @EndDate AND t.[ToDate] >= @StartDate)
							OR ( t.[FromDate] <= @StartDate AND t.[ToDate] >= @EndDate)
						)
				)
			)
	END
	SELECT * FROM #Result ORDER BY [SiteGuid], [From], [To]
################################################################################
#END