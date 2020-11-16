################################################################
CREATE   PROC  repHosSurgeryStatistics
	@Operation	UNIQUEIDENTIFIER,  
	@Doctor		UNIQUEIDENTIFIER,  
	@Patient	UNIQUEIDENTIFIER,  
	@Gender 		INT,   -- -1  
	@Nationality 	NVARCHAR(32) ,  ---''    
	@StartDate	DATETIME,  
	@EndDate	DATETIME,
	@SortBy 	INT = 0 -- 0 date, 1 name, 2 code , 3 operation name
	
AS  
SET NOCOUNT ON 
	CREATE TABLE #SecViol  
	(  
		Type	INT,   
		Cnt 	INTEGER  
	) 
  
	CREATE TABLE #Result   
	(  
		OperationGuid	UNIQUEIDENTIFIER, 
		SurgeryGuid		UNIQUEIDENTIFIER, 
		OperationName	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		FileCode		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		PatientName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		DoctorName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		BeginDate		DATETIME,  
		EndDate			DATETIME,  
		RoomCost		FLOAT, 
		DoctorCost		FLOAT, 
		WorkerCost		FLOAT, 
		SurgeryCost		FLOAT, 
		PatientCost		FLOAT, 
		Gender			NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		Age		INT, 
		Nationality	NVARCHAR(100), 
	)  
 	
CREATE TABLE #Result2
	(   
		OperationGuid 	UNIQUEIDENTIFIER, 
		SurgeryGuid 	UNIQUEIDENTIFIER, 
		OperationName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		FileCode		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		PatientName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		BeginDate  		DATETIME,
		EndDate			DATETIME, 
		SurgeryCost 	FLOAT,
		PatientCost		FLOAT, 
		DoctorName 		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		Gender 			NVARCHAR(10) COLLATE ARABIC_CI_AI,
		Age 			INT,
		Nationality		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		DoctorCost		FLOAT, 	 
		RoomCost 		FLOAT, 
		TotalCost		FLOAT
	)	 

	Declare @CurrentDate DateTime  
	Set 	@CurrentDate = GetDate() 
	INSERT INTO #Result  
		    SELECT 
			sur.opGuid, 
			sur.SurgeryGuid, 
			sur.[OpName],	 
			F.[Code],
			F.[Name], 
			CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  Sur.DocLatinName ELSE Sur.DocName END  DoctorName ,		  
			Sur.SurgeryBeginDate, 
			Sur.SurgeryEndDate,  
			IsNull(S.RoomCost,0) AS RoomCost,   
			isnull(W.Income, 0) as Income,
			0,--W.Income, 
			ISNULL(bu1.Total, 0) as surgery , -- surgery cost 
			ISNULL(bu2.Total, 0)  as patientCost,	--patientCost 
			CASE F.Gender WHEN 1 THEN  '–ﬂ—' ELSE '√‰ÀÏ' END Gender,    
			DateDiff(Year, F.PatientBirthDay, @CurrentDate) AS Age ,  
			F.PatientNation 
		FROM  
			vwHosFile F  
			INNER JOIN HosFSurgery000 S ON F.GUID = S.FileGUID  
			INNER JOIN vwHosSurgery sur ON sur.SurgeryGuid = S.GUID	 
			left JOIN HosSurgeryWorker000 W ON Sur.surgeryGuid = w.parentGuid 
			left JOIN bu000 bu1 On S.SurgeryBillGuid = bu1.Guid 
			left JOIN bu000 bu2 On S.PatientBillGuid = bu2.Guid 
		WHERE  
			(W.WorkerGuid = sur.DocGuid OR   sur.DocGuid Is Null)
			AND 
			(@Patient = 0x0 OR F.PatientGUID = @Patient)  
			AND 
			(@Gender = -1 OR @Gender = F.Gender) 
			AND 
			(@Nationality = '' OR F.PatientNation LIKE '%' + @Nationality + '%') 
			AND  
			(@Doctor = 0x0 OR Sur.DocGUID = @Doctor)  
			AND
			(@Operation = 0x0 OR @Operation = sur.OpGuid)   
			AND
			(Sur.SurgeryBeginDate BETWEEN @StartDate AND @EndDate)		 
			AND 
			(Sur.SurgeryEndDate  BETWEEN @StartDate AND @EndDate)		 
		ORDER BY  
			Sur.[OpName],  Sur.SurgeryBeginDate,/*F.[Name],*/Sur.SurgeryEndDate, S.RoomCost  
	/*
		select * from vwHosSurgery
		select * from HosSurgeryWorker000
		select * from vwhosfile where guid ='2C4D60C9-5819-4B3D-8B84-4ED049C57E33'
		select * from #result
	*/
	EXEC [prcCheckSecurity]  


	/*IF @ReportType = 0  
		 SELECT 
			S.OperationGuid, 
			op.[Name], 
			sum (S.RoomCost) + sum (bu1.Total) + sum(bu2.Total) AS TotalCost 
			FROM  
			HosFSurgery000 S  
			INNER JOIN hosoperation000 op ON S.OperationGuid = op.GUID	 
			LEFT JOIN bu000 bu1 On S.SurgeryBillGuid = bu1.Guid 
			LEFT JOIN bu000 bu2 On S.PatientBillGuid = bu2.Guid 
		group by S.OperationGuid,op.[Name] 
	ELSE */ 
	Declare @Surgery_Cost INT		 
	set @Surgery_Cost = (select Value from op000 where name = 'HosCfg_SurgeryCost') 
	INSERT into #Result2
	SELECT  
		OperationGuid,
		SurgeryGuid,
		OperationName,
		FileCode,	 
		PatientName, 
		BeginDate,  
		EndDate, 
		SurgeryCost, 
		PatientCost,	 
		DoctorName, Gender, Age, Nationality, 
		DoctorCost,	 
		RoomCost, 
		case @Surgery_Cost  
			WHEN  1 THEN 
				SurgeryCost + PatientCost + RoomCost  
			ELSE 
				PatientCost + RoomCost   
			END 
		AS TotalCost 
	FROM  
		#Result R 
		--order by BeginDate, OperationName, PatientName
	if (@SortBy = 0)
		select * from #result2
			order by BeginDate	
	else
	if (@SortBy = 1)
		select * from #result2
			order by PatientName
	else
	if (@SortBy = 2)
		select * from #result2
			order by FileCode	

	else
	if (@SortBy = 3)
		select * from #result2
			order by OperationName	

	SELECT * FROM #SecViol	  

################################################################
#END