################################################################
CREATE PROC repHosSurgCollect
	@Operation		UNIQUEIDENTIFIER,  
	@Doctor			UNIQUEIDENTIFIER,  
	@Patient		UNIQUEIDENTIFIER,  
	@Gender 		INT,   -- -1  
	@Nationality	NVARCHAR(32) ,  ---''    
	@StartDate		DATETIME,  
	@EndDate		DATETIME  
as 
SET NOCOUNT ON 
	select 
		S.guid	AS Guid, 
 		S.OperationGuid AS OPGUID, 
		op.[Name] AS [NAME] 
	into #TEMP1		 
	FROM  
 		HosFSurgery000 S  
		INNER JOIN hosoperation000 op ON S.OperationGuid = op.GUID	 
	WHERE 
		(@Operation = 0x0 OR @Operation = S.OperationGuid) 
		AND   
		(S.BeginDate BETWEEN @StartDate AND @EndDate)		 
		AND 
		(S.EndDate  BETWEEN @StartDate AND @EndDate)		 
	
	SELECT  
		Sur.SurgeryGuid, 
		Sur.OpGuid 
		 
	into #TEMP2	 
	FROM	 
		vwHosSurgery Sur inner join vwHosFile F ON F.GUID = Sur.FileGUID  
	WHERE  
		(@Patient = 0x0 OR @Patient = F.PatientGUID) 
		AND 
		(@Gender = -1 OR @Gender = F.Gender) 
		AND 
		(@Nationality = '' OR F.PatientNation LIKE '%' + @Nationality + '%') 
		AND  
		(@Doctor = 0x0 OR Sur.DocGUID = @Doctor)  
	
	SELECT 
		S.OperationGuid, 
		op.[Name], 
		COUNT(T1.[NAME]) AS SurCount, 
		SUM(C.TotalCost ) AS TotalCost
	FROM  
		HosFSurgery000 S  
		INNER JOIN hosoperation000 op ON S.OperationGuid = op.GUID	 
		INNER JOIN #TEMP1 AS T1 ON T1.GUID = S.Guid 
		INNER JOIN vwHosSurgeryCost() AS C ON C.GUID = S.GUID
	WHERE 	 
		(S.Guid IN (SELECT SurgeryGuid FROM #TEMP2 )) 
	group by S.OperationGuid, op.[Name] 
################################################################
#END