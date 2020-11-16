##################################################################################
CREATE   PROC repHosStatistics
	@PatientGuid UNIQUEIDENTIFIER  , 
	@Gender 		INT,   -- -1
	@Nationality 	NVARCHAR(32) , ---''  
	@FileDateIn 	DATETIME , -- 1900 
	@FileDateout 	DATETIME,  -- 2100
	@FromAge		FLOAT ,  
	@ToAge 			FLOAT , 
	@SurgeryGuid	UNIQUEIDENTIFIER , --0x0
	@DoctorGuid		UNIQUEIDENTIFIER , --0x0
	@EntranceType	INT , -- -1
	@Accompanying	INT , -- -1
	@Surgery_Begin_Date DateTime,  -- 1900
	@Surgery_End_Date   DateTime , -- 2100 
	@SortBy 		INT , --
	@FromFileNo		NVARCHAR(100), 
	@ToFileNo		NVARCHAR(100) ,
	@ShowNullSurgery INT = 0
AS  
SET NOCOUNT ON 
	
	select	
		IsNull(SurgeryGuid,0x0) AS SurgeryGuid, 
		F.Guid AS FileGuid,
		CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  [LatinName] ELSE [Name] END PatientName,
		Code PatientCode,
		CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  opLatinName ELSE opName END opName,
		opCode,
		CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  DocLatinName ELSE DocName END  DocName ,		
		DocCode,
		IsNull(SurgeryBeginDate,'') AS SurgeryBeginDate,
		IsNull(SurgeryEndDate,'') AS SurgeryEndDate,  
		DateDiff(MINUTE,SurgeryBeginDate,SurgeryEndDate) AS PeriodMinute,
 		F.DateIn FileDateIn,  
		F.DateOut FileDateout, 
		CASE F.Gender WHEN 1 THEN  'ÐßÑ' ELSE 'ÃäËì' END Gender,  
		F.PatientNation,
		CASE F.EntranceType WHEN 1 THEN 'ÚÇÏí' ELSE 'ÅÓÚÇÝí' END EntranceType,		 
		CASE F.Accompanying WHEN 1 THEN 'ãÚ ãÑÇÝÞ' ELSE 'ÈÏæä ãÑÇÝÞ' END  Accompanying	 
	into #TEMPHos
	FROM   
		VWHosFile F LEFT JOIN  vwHosSurgery S ON  F.Guid = S.FileGuid 
	WHERE  
		(@PatientGuid = 0x0 OR @PatientGuid = PatientGuid) 
		AND 
		(@Gender = -1 OR  @Gender = F.Gender ) 
		AND 
		(@Nationality = '' OR F.PatientNation LIKE '%' + @Nationality + '%' )
		AND 
		(F.DateIn >= @FileDateIn)
		AND
	 	(F.Dateout<= @FileDateOut ) 
		AND 
		((cast (GetDate() - F.PatientBirthDay as float)/365) >= @FromAge  AND  (cast (GetDate()- F.PatientBirthDay as float)/365) <= @ToAge) 
		AND	 
		(@EntranceType =-1 OR  @EntranceType = EntranceType ) 
		AND 
		(@Accompanying = -1 OR @Accompanying	= Accompanying) 
		AND 
		(
			(@FromFileNo = '-1' AND @ToFileNo = 'ZZZZZZZZZZ')
		OR	
			(Code  >=  @FromFileNo AND Code <=  @ToFileNo)
		)
		AND
		(@SurgeryGuid = 0x0 OR @SurgeryGuid = OpGuid) 
		AND 
		(@DoctorGuid = 0x0 OR @DoctorGuid = DocGuid) 
		AND			 
		(
		    (@ShowNullSurgery = 1) 
		    OR
		    (
			(SurgeryBeginDate BETWEEN @Surgery_Begin_Date AND @Surgery_End_Date)
			AND		
			(SurgeryEndDate BETWEEN  @Surgery_Begin_Date AND  @Surgery_End_Date)
		    )
		)

 if  (@SortBy = 0)
	begin
	 SELECT  * from #TempHos 
 	 ORDER BY PatientName, FileDateIn
	end
 else	
    if (@SortBy = 1)
	begin
	 SELECT  * from #TempHos
 	 ORDER BY PatientCode, FileDateIn
	end
 else	
    if (@SortBy = 2)
	begin
	 SELECT  * from #TempHos
	 ORDER BY FileDateIn
	end
 else	
     if (@SortBy = 3)
 	begin
 	 SELECT  * from #TempHos
  	 ORDER BY DocCode
 	end
 else	
     if (@SortBy = 4)
 	begin
 	 SELECT  * from #TempHos
  	 ORDER BY DocName
 	end
 else	
     if (@SortBy = 5)
 	begin
 	 SELECT  * from #TempHos
  	 ORDER BY SurgeryBeginDate
 	end
/*
select cast (code as int) floatcode from VWHosFile  where cast (code as int) >= 6010001 and cast (code as int) <= 6010011



		WHERE  
		PF.DateIn >= @FileStartDate AND PF.DateOut <= @FileEndDate AND 
		(@Gender = -1 OR T.Gender = @Gender) AND 
		(@Nationality = '' OR P.Nation = @Nationality) AND 
		(@UseBirthDate != 1 OR P.BirthDay BETWEEN @BirthStartDate AND @BirthEndDate) 

--	DECLARE @MaleStr NVARCHAR(100) 
--	SELECT @MaleStr = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'male' ELSE 'ÐßÑ' END 
	DECLARE @FemaleStr NVARCHAR(100) 
	SELECT @FemaleStr = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'female' ELSE 'ÃäËì' END 
exec repHosStatistics '6010001','6010010'
'6070442'
select * from vwhosFile order by  code 
= '6030570'
select Cast(getDate() -  getDate() as float)
select top 1  cast(GetDate()- '1-1-2000' as float) /365 def from vwhosPatient 
where 		((GetDate()- PatientBirthDay) >= 1 AND  (GetDate()- PatientBirthDay) <= 20)
*/

/*
select cast (code as int) floatcode from VWHosFile  where cast (code as int) >= 6010001 and cast (code as int) <= 6010011



		WHERE  
		PF.DateIn >= @FileStartDate AND PF.DateOut <= @FileEndDate AND 
		(@Gender = -1 OR T.Gender = @Gender) AND 
		(@Nationality = '' OR P.Nation = @Nationality) AND 
		(@UseBirthDate != 1 OR P.BirthDay BETWEEN @BirthStartDate AND @BirthEndDate) 

--	DECLARE @MaleStr NVARCHAR(100) 
--	SELECT @MaleStr = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'male' ELSE 'ÐßÑ' END 
	DECLARE @FemaleStr NVARCHAR(100) 
	SELECT @FemaleStr = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'female' ELSE 'ÃäËì' END 
exec repHosStatistics '6010001','6010010'
'6070442'
select * from vwhosFile order by  code 
= '6030570'
select Cast(getDate() -  getDate() as float)
select top 1  cast(GetDate()- '1-1-2000' as float) /365 def from vwhosPatient 
where 		((GetDate()- PatientBirthDay) >= 1 AND  (GetDate()- PatientBirthDay) <= 20)
*/

##################################################################################
#END
