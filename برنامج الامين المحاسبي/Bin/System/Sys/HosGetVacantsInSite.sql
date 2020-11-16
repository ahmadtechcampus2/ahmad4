#############################################
CREATE  Proc  HosGetVacantsInSite
		@SiteGuid 		UNIQUEIDENTIFIER,
		@FromDate		DATETIME
		--@ToDate   		DATETIME
AS
SET NOCOUNT ON 
create table #vacant
	(
		Patient	UNIQUEIDENTIFIER,
		FromDate DATETIME,
		ToDate DATETIME
	)
	Declare @Patient UNIQUEIDENTIFIER
	Declare @From DATETIME
	Declare @To DATETIME
	Declare @Next_From DATETIME	
	Declare @CurrentDate DATETIME	
	--set 	@CurrentDate = GetDate()
	set @Next_From = '2100'
	
	DECLARE	st CURSOR FOR
	SELECT 
		PatientGuid ,
		[From] ,
		[To]
	FROM FnHosAllActivities(@SiteGuid, @FromDate, '2100', -1) 
	WHERE @SiteGuid = SiteGuid
	ORDER BY [To] DESC 

	OPEN st
	     FETCH NEXT 
		FROM st
		Into
		@Patient,
		@From,
		@To
	WHILE (@@FETCH_STATUS = 0 )--And @From > @CurrentDate)
	BEGIN
		if (@Next_From > @To)
			insert into #vacant Values (@Patient , @To, @Next_From)
		set @Next_From = @From
		
		--if  ( @From > @CurrentDate)	
			--Set @@FETCH_STATUS = 0
		FETCH NEXT 
		  FROM st Into
		  @Patient,
		  @From,
		  @To

	  End--- while 1
	CLOSE st
	DEALLOCATE st
	
	If Not Exists (select * from #vacant)
		INSERT INTO #vacant values (0x0, @FromDate, @Next_From)
select * from #vacant		
	ORDER BY FromDate 
####################################
#END