############################################################
CREATE Function fnHosSitesGrid
			( 
			@StartDate DateTime , 
			@EndDate   DateTime	, 
			@CurrentDate	DateTime, 
			@SiteType  UNIQUEIDENTIFIER, 
			@GroupSiteGuid UNIQUEIDENTIFIER, 
			@PartDay  INT = 4,	 
			@sort	INT = 0		  
			) 
Returns  
	@Result Table   
	(  
		[SiteGuid]		UNIQUEIDENTIFIER,    
		Name			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Type			Int,  
		Fromtime		Int,  
		toTime			Int,  
		PersonGuid		UNIQUEIDENTIFIER,  
		FileGuid		UNIQUEIDENTIFIER,  
		StayGuid		UNIQUEIDENTIFIER,
		FileNotes  		NVARCHAR(1000) COLLATE ARABIC_CI_AI
	)  
As  
begin  
	declare @Temp Table  
	(  
		[SiteGuid]		UNIQUEIDENTIFIER,    
		Name			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Type			Int,  
		Fromtime		Int,  
		toTime			Int,  
		PersonGuid		UNIQUEIDENTIFIER,  
		FileGuid		UNIQUEIDENTIFIER,  
		StayGuid		UNIQUEIDENTIFIER,
		FileNotes  		NVARCHAR(1000) COLLATE ARABIC_CI_AI  
	)  
	  
	Declare	@Num_Days int, @Num_Part int  
	-- ⁄œœ «··√Ì«„ ÷„‰ «· «—ÌŒÌ‰  
	Set @Num_Days = DATEDIFF(day,@StartDate,  @EndDate) +  1  
	-- ⁄œœ «·√Ã“«¡ ÷„‰ «· «—ÌŒÌ‰  
	Set @Num_Part = @Num_Days * @PartDay   
	Declare @hour_Num_InPart Int   
	Set @hour_Num_InPart = (24 / @PartDay)  
	 
	INSERT INTO @Temp  
		Select   
			ResSite.Guid,			  
			ResSite.Name,	  
			ResSite.Code,	  
			Act.Type,	  
			CASE  When (Act.[From] < @StartDate  )     then 0  
			      else	  
				Day(Act.[From]) * @PartDay +  
				(DATEPART (hh,Act.[From]) /*+ (DATEPART(minute,Act.[From]) / 30)*/) / @hour_Num_InPart  
			      END  
			AS Fromtime,  
			CASE  When (dbo.IsDate2100(Act.[To], @Currentdate) > @EndDate  )   then @Num_Part  
			      else	  
				case when (Act.[To] = '2100') then day( @CurrentDate) * @PartDay  
				else  
				case when (DATEPART(hh,Act.[To]) = 0  )  
					then   
					day(DATEADD(dd, -1, dbo.IsDate2100(Act.[To], @CurrentDate) )) * @PartDay   
					--DATEPART (hh,DATEADD(dd, -1,Act.[To]) )/ @hour_Num_InPart  
					else	  
					Day(Act.[To]) * @PartDay +  
					(DATEPART (hh,Act.[To]) /*+ ( DATEPART (minute,Act.[To]) / 30)*/) / @hour_Num_InPart	  
				END	  
				END  
			END  
			AS Totime,  
			Act.PatientGuid,  
			IsNull(PFile.Guid, 0x0) AS FileGuid,  
			Act.StayGuid,
			PFile.FileNotes
			From hossite000 as ResSite  
			INNER JOIN FnHosAllActivities(0x0, @StartDate, @EndDate, 0) AS Act -- just not confirm   
				ON Act.SiteGuid = ResSite.Guid   
			INNER JOIN hosGroupSite000 AS g ON ResSite.parentguid = g.guid 
			Left Join hosPFile000 AS PFile   
				ON PFile.Guid = Act.FileGuid  
   				--ON PFile.PatientGuid  = Act.PatientGuid  
			Where   
			      (@SiteType = 0x0 OR ResSite.TypeGuid  = @SiteType) 
			       AND  
			       (@GroupSiteGuid = 0x0 OR ResSite.parentGuid = @GroupSiteGuid)	  
			       And  
			       (  
					(Act.[To] <> '2100')  
					OR  
					--(Act.[To] = '2100' and 	 @CurrentDate between @Startdate and @EndDate)			  
					(Act.[To] = '2100' and 	 @CurrentDate >=  @Startdate)  
			       )  
			  
			  
			       --(Act.[To]	<> '')  
				  
	If  (@sort = 0)  
	   begin  
	    Insert into @Result  
	    Select * from @Temp  
	    Order By [Name] , FromTime  
	   END  
		  
	--If  (@sort = 1)  
	else  
	   begin  
	    Insert into @Result  
	    Select * from @Temp  
	    Order By Code , FromTime  
	   END   
RETURN   
END  

########################################################################################
CREATE function hosGetVacantTable  
		(
			@StartDate DateTime,
			@EndDate   DateTime,
			---Â«„‘ «·Êﬁ  »«·”«⁄…
			@HourMargin INT = 2
			--@sort	INT = 0	
		)
Returns @result Table
	(
		[SiteGuid]		UNIQUEIDENTIFIER,  
		Fromtime		DateTime,
		toTime			DateTime,
		Type			Int
	)
as 
begin
	
	DECLARE 
		@Guid			UNIQUEIDENTIFIER,
		@SiteGuid		UNIQUEIDENTIFIER,
		@From			DateTime,
		@To				DateTime,
		@Old_From		DateTime,
		@Old_To			DateTime,
		@Temp_From		DateTime,
		@Temp_To		DateTime


	DECLARE	st CURSOR FOR
		SELECT GUID
		FROM HosSite000
	
	OPEN st
	FETCH NEXT 
	FROM st
	INTO @Guid
	WHILE @@FETCH_STATUS = 0
	   BEGIN
		
		DECLARE	c CURSOR FOR
			select
				Act.SiteGuid,			
				Act.[From], 
				Act.[To]
			From	FnHosAllActivities(@Guid, @StartDate, @EndDate, -1) AS Act
				
			
		set @Old_From = @StartDate
		set @Old_To = @StartDate

		OPEN c
		FETCH NEXT 	FROM c
		INTO @SiteGuid, @From, @To
		IF (@SiteGuid IS NULL)
			insert into @result values (@Guid, @StartDate, @EndDate, 13) --completely empty
		Else
		   Begin
			WHILE @@FETCH_STATUS = 0
			 BEGIN
			     set @Temp_To = DATEADD(hour, @HourMargin, @Old_To)
			     if ( @From >  @Temp_To )
			        begin insert into @result values (@SiteGuid, @Old_To, @From, 4) END
			     set @Old_From = @From 
	  		     set @Old_To   = @To	
			     FETCH NEXT 	
			     FROM c
			     INTO @SiteGuid, @From, @To

		 	  END -- while 2 
		
			  if (@SiteGuid is not Null)
			    begin
			      set @Temp_To = DATEADD(hour, @HourMargin, @Old_To)
   	  	 	     if ( @EndDate >  @Temp_To )
				begin  insert into @result values (@SiteGuid, @Old_To, @From, 4)  END
								        
			   END --  if	
			END -- else
		CLOSE		c
		DEALLOCATE	c
	
	FETCH NEXT 
	FROM st
	INTO @Guid
       End--- while 1

	CLOSE st
	DEALLOCATE st


return
end
########################################################################################
CREATE function fnHos_Curr_SitesActivities
		( 
			@currentDate DateTime , 
			@SiteType  UNIQUEIDENTIFIER = 0x0, 
			@SiteGuid  UNIQUEIDENTIFIER = 0x0 , 
			@GroupSiteGuid  UNIQUEIDENTIFIER  = 0x0, 
			@Status	   INT = 0, --- 0 All , 1 stay, 2 stay, 13 empty 
			@sortby INT = 0 --- name 
		) 
RETURNS @Result Table  
		(  
			[SiteGuid]		UNIQUEIDENTIFIER,  
			[Name]  		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[Code]			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[TypeGuid]		UNIQUEIDENTIFIER,  
			[Type]			INT,  
			[PersonGuid]	UNIQUEIDENTIFIER,  
			[FileGuid]		UNIQUEIDENTIFIER,  
			[StayGuid]		UNIQUEIDENTIFIER,
			[FileNotes]  	NVARCHAR(1000) COLLATE ARABIC_CI_AI  
		)  
AS  
BEGIN  
	declare @Temp table  
		(  
			[SiteGuid]		UNIQUEIDENTIFIER,  
			[Name]  		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[Code]			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[TypeGuid]		UNIQUEIDENTIFIER,  
			[Type]			INT,  
			[PersonGuid]	UNIQUEIDENTIFIER,  
			[FileGuid]		UNIQUEIDENTIFIER,  
			[StayGuid]		UNIQUEIDENTIFIER,
			[FileNotes]  		NVARCHAR(1000) COLLATE ARABIC_CI_AI  
		)  
		 
		INSERT INTO @Temp  
		SELECT  
			Site.Guid,  
			Site.[Name],  
			Site.[Code],  
			Site.TypeGUID,  
			1,  
			patient.guid,  
			PFile.Guid,  
			Stay.Guid,
			PFile.FileNotes 
		From HosStay000 as Stay  
			INNER JOIN hospfile000 as PFile  
				ON Stay.FileGuid = PFile.Guid  
			INNER JOIN hospatient000 as patient   
				ON	patient.guid = PFile.patientGuid  
			INNER	JOIN hosperson000 as person   
				ON person.Guid = patient.PersonGuid  
			INNER 	JOIN Hossite000 as Site    
				ON  Site.Guid  = Stay.SiteGuid   
		WHERE  
			(@currentDate between  Stay.StartDate and Stay.EndDate)  
	 
		 
		INSERT INTO @Temp  
		SELECT  
			Site.Guid,  
			Site.[Name],  
			Site.[Code],  
			Site.TypeGUID,  
			2,  
			patient.guid,  
			IsNull(PFile.Guid, 0x0) AS FileGuid,  
			ReservDetail.Guid ,
			PFile.FileNotes 
		FROM   
			HosReservationDetails000 as ReservDetail    
			INNER JOIN hospatient000 as patient   
				ON patient.Guid = ReservDetail.PatientGuid  
			INNER JOIN hosperson000 as person   
				ON person.Guid = patient.PersonGuid  
			INNER JOIN Hossite000 as Site    
				ON  Site.Guid  = ReservDetail.SiteGuid   
			LEFT JOIN hospfile000 as PFile  
				ON ReservDetail.FileGuid = PFile.Guid  
	 		WHERE   
				(@currentDate between  ReservDetail.FROMDate and ReservDetail.ToDate)  
			AND  
				(ReservDetail.IsConfirm = 0) -- just confirm    
			  
			 
			---fill empty sites  
			INSERT INTO @Temp  
			SELECT  
				Site.Guid,  
				Site.[Name],  
				Site.[Code],  
				Site.TypeGUID,  
				13,  
				0x0,  
				0x0,  
				0x0,
				''  
			From  hosSite000 AS site  
			where  not exists (select  siteguid from @Temp as t where t.siteguid = site.guid)	  
	 
			INSERT INTO @Result  
			SELECT  
				t.SiteGuid,  
				t.Name ,  
				t.Code,  
				t.TypeGuid ,  
				t.Type ,  
				t.PersonGuid ,  
				t.FileGuid ,  
				t.StayGuid,
				t.FileNotes  
			from  
				@Temp AS t 
				INNER JOIN hosSite000 AS s ON t.SiteGuid = s.guid 
				INNER JOIN hosGroupSite000 AS g ON s.parentguid = g.guid  
			where   
				(@SiteGuid = 0x0 OR @SiteGuid = t.SiteGuid)  
				AND  
				(@GroupSiteGuid = 0x0 OR s.parentGuid = @GroupSiteGuid) 
				AND  
				(@SiteType = 0x0 OR @SiteType = t.TypeGuid)  
				AND  
				(@Status = 0 OR @Status = t.Type)  
			  
			ORDER BY   
				Case WHEN @SortBy = 0  
					THEN	t.[Name]  
					ELSE   t.[Code]  
				END  
	RETURN  
END  
########################################################################################
CREATE Function FnHosSitesGrid_All 
		( 
			@CurrentDate DateTime, 
			@StartDate DateTime ,  
			@EndDate   DateTime	,  
			@SiteType  UNIQUEIDENTIFIER, 
			@GroupSiteGuid  UNIQUEIDENTIFIER, 
			@PartDay  INT = 4,	 
			@sort	INT = 0	  
		) 
Returns @Result Table  
		(   
			[SiteGuid]		UNIQUEIDENTIFIER,     
			Name			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Type			Int,   
			Fromtime		Int,   
			toTime			Int,   
			PersonGuid		UNIQUEIDENTIFIER,   
			FileGuid		UNIQUEIDENTIFIER,   
			StayGuid		UNIQUEIDENTIFIER,
			FileNotes		NVARCHAR(1000) COLLATE ARABIC_CI_AI   
		)   
AS  
Begin  
	Declare @Temp Table  
	(   
		[SiteGuid]		UNIQUEIDENTIFIER,     
		Name			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Type			Int,   
		Fromtime		Int,   
		toTime			Int,   
		PersonGuid		UNIQUEIDENTIFIER,   
		FileGuid		UNIQUEIDENTIFIER,   
		StayGuid		UNIQUEIDENTIFIER,
		FileNotes		NVARCHAR(1000) COLLATE ARABIC_CI_AI   
	)   
  	 
  	INSERT INTO @Temp    
	SELECT * FROM fnHosSitesGrid(@StartDate, @EndDate, @CurrentDate,@SiteType, @GroupSiteGuid, @PartDay, @sort)   
		  
	INSERT INTO @Temp    
	SELECT  
		S.Guid,		   
		S.Name,   
	 	S.Code,   
		13,--IsNull(t.type,13) AS TYPE, -- completely empty   
		0,  --	Fromtime		Int,   
		0,  --toTime			Int,   
		0x0,--PersonGuid		UNIQUEIDENTIFIER,   
		0x0,--file guid   
		0x0,--StayGuid		UNIQUEIDENTIFIER  
 		''
	from hossite000 as s  
	INNER JOIN hosGroupSite000 AS g ON s.parentguid = g.guid 
	where   
		(@SiteType = 0x0 OR @SiteType = TypeGuid)  
		AND  
		(@GroupSiteGuid = 0x0 OR s.parentGuid = @GroupSiteGuid) 
		AND  
		not exists (select  siteguid from @Temp as t where t.siteguid = s.guid)	   
		   
	INSERT INTO @Temp    
	SELECT  
		cur.SiteGuid,		   
		cur.[Name],   
	 	cur.[Code],   
		cur.Type  ,--IsNull(t.type,13) AS TYPE, -- completely empty   
		-1,  --	Fromtime		Int,   
		-1,  --toTime			Int,   
		IsNull(cur.PersonGuid, 0x0) AS PersonGuid, --PersonGuid		UNIQUEIDENTIFIER,   
		IsNull(cur.FileGuid,0x0) AS FileGuid,--file guid   
		IsNull(cur.StayGuid,0x0) AS StayGuid,--StayGuid		UNIQUEIDENTIFIER   
		cur.FileNotes
	from fnHos_Curr_SitesActivities (@CurrentDate,@SiteType ,0x0,@GroupSiteGuid,0,@Sort) AS cur  
	 
	INSERT INTO @Result  
	SELECT * FROM @Temp    
	ORDER BY   
		CASE @Sort WHEN 0 THEN [Name]  ELSE [Code] END	   
		,FromTime   
	 
	RETURN 
End  
############################################################
CREATE procedure prcHosSitesGrid
	 		@StartDate DateTime ,  
			@EndDate   DateTime	,  
			@SiteType  UNIQUEIDENTIFIER,  
			@GroupSiteGuid UNIQUEIDENTIFIER,
			@PartDay  INT = 4,	  
			@Status  INT = 0,  
			@sort	INT = 0	  
AS			
SET NOCOUNT ON   
	Create Table  #All    
	(   
		[SiteGuid]		UNIQUEIDENTIFIER,     
		Name			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Type			Int,   
		Fromtime		Int,   
		toTime			Int,   
		PersonGuid		UNIQUEIDENTIFIER,   
		PersonName		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		FileGuid		UNIQUEIDENTIFIER,   
		StayGuid		UNIQUEIDENTIFIER,
		FileNotes		NVARCHAR(1000) COLLATE ARABIC_CI_AI     
	)   
	Create Table  #Temp    
	(   
		[SiteGuid]		UNIQUEIDENTIFIER,     
		Name			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		Type			Int,   
		Fromtime		Int,   
		toTime			Int,   
		PersonGuid		UNIQUEIDENTIFIER,   
		FileGuid		UNIQUEIDENTIFIER,   
		StayGuid		UNIQUEIDENTIFIER,
		FileNote		NVARCHAR(1000) COLLATE ARABIC_CI_AI     
	)   
	 
	declare  @today DateTime  
	set @today = GetDate()  
    
	--exec HosSetCurrentDate  
	insert into #All  
	select   
		fn.SiteGuid,  
		fn.[Name],  
		fn.[code],  
		fn.[Type],  
		fn.[FromTime],  
		fn.[ToTime],  
		fn.[PersonGuid],  
		ISNULL(patient.[Name], ''),  
		fn.[FileGuid],  
		fn.[StayGuid],
		fn.FileNotes
	from FnHosSitesGrid_All (@today, @StartDate, @EndDate, @SiteType, @GroupSiteGuid, @PartDay, @sort) as fn  
	left join vwHosPatient as patient ON Patient.Guid = fn.PersonGuid  
	 
	---  all    ,       empty  
    IF (@Status = 0 OR @Status = 4)   
 		select * from #All  
 			ORDER BY   
			CASE @Sort WHEN 0 THEN [Name]  ELSE [Code] END	   
			,FromTime   
    ELSE   
      BEGIN	  
		INSERT INTO #Temp    
   		select * from fnHosSitesGrid(@StartDate, @EndDate,@today ,@SiteType,@GroupSiteGuid, @PartDay, @sort)   
	  
	  
  		Create  Table #SiteGuid   
		(   
			Guid UNIQUEIDENTIFIER   
		)   
	  
		insert into #SiteGuid   
		select    
			distinct SiteGuid   
		from #Temp     
		where 	(@Status = type)		   
    
		SELECT    
			t.SiteGuid,   
			t.name,   
			t.code,   
			t.type,   
			t.FromTime,   
			t.toTime,   
			t.personGuid,  
			t.personName,   
			t.FileGuid,   
			t.stayGuid,
			t.FileNotes	   
		from    
			#All as t    
			inner join #SiteGuid as s on t.siteguid = s.guid   
		ORDER BY   
			CASE @Sort WHEN 0 THEN [Name]  ELSE [Code] END	   
			,FromTime   
	  END -- ELSE   

############################################################################
#END


