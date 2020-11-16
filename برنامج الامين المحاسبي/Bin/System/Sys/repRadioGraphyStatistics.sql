####################################
CREATE PROCEDURE repRadioGraphyStatistics
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@PatientGuid		UNIQUEIDENTIFIER = 0x0,
	@RadioGraphyGuid	UNIQUEIDENTIFIER = 0x0,
	@ShowDetails		INT = 0,
	@PatientType		INT = -1,  ---- 0 internal , 1 Extermal , -1 ALL,
	@DoctorGuid		UNIQUEIDENTIFIER= 0x0,
	@TypeGuid		UNIQUEIDENTIFIER = 0x0,
	@AccGuid		UNIQUEIDENTIFIER = 0x0,
	@Sort			Int = 0 -- Date, RadioCode, RadioName, PatientName, FileCode  
AS 
SET NOCOUNT ON 
CREATE TABLE #Result
	(
		[RGCode]		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[RGName]		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[Price]			FLOAT,
		[Cnt]			INT

	)
/*
exec  [repRadioGraphyStatistics]
 '1/1/2007  0:0:0:0', '5/30/2007  0:0:0:0', 0x0, 0x0, 1, 1, 0x0, 0x0 
*/
	--INSERT INTO #Result
if @ShowDetails = 1 
BEGIN
	SELECT
		O.Number as OrderNumber,
		O.CODE as OrderCode,
		R.[Code] as RGCode,
		R.[Name] as RGName,
		O.[Date],
		P.[GUID] as PatientGuid,
		P.[Name] as PatientName,
		IsNull(F.Guid, 0x0) as FileGuid,
		ISNull(F.Code, '') as FileCode,
		CASE P.Gender WHEN 1 THEN  '–ﬂ—' ELSE '√‰ÀÏ' END gender,  
		P.patientNation,
		Ac.[Name] as AccName,
		D.RESULT,
		D.Notes,	
		D.PRICE,
		1 as Cnt
		--Count(*)
	into #temp 
	FROM
	
	[HosRadioGraphyOrderDetail000] AS D
	INNER JOIN [hosRadioGraphyOrder000] AS O ON D.ParentGuid = O.Guid 
	INNER JOIN [hosRadioGraphy000] AS R ON R.GUID = D.RadioGraphyGUID
	INNER JOIN vwHosPatient P ON O.PatientGUID =  P.GUID  
	inner join AC000 AS AC on AC.Guid = O.AccGuid
	LEFT join HosPfile000 AS F on O.[FileGUID] = F.[GUID]

	WHERE
		O.[Date] BETWEEN @StartDate AND @EndDate
		AND ( (O.[PatientGUID] = @PatientGUID)  OR ( @PatientGUID = 0x0))
		AND ( (@RadioGraphyGuid = 0x0) OR ( @RadioGraphyGuid = R.Guid))
		--AND ( (@TypeGUID = 0x0) OR ( @TypeGUID = O.TypeGUID))
		AND ( (@DoctorGuid = 0x0) OR ( @DoctorGuid = O.DoctorGuid))
		AND ( 
				(@PatientType = -1 ) 
				OR ( @PatientType = 0 AND ISNULL(O.[FileGUID], 0X0) <> 0x0) 
				OR ( @PatientType = 1 AND ISNULL(O.[FILEGUID], 0X0) = 0X0)
			)
		AND ( (@AccGuid = 0x0 )	 OR (@AccGuid = O.AccGuid))
	
	if (@Sort = 0)
		select * from #temp
		order by [Date], OrderNumber
	else
	if (@Sort = 1)
		select * from #temp
		order by  RGCode, [Date]
	else
	if (@Sort = 2)
		select * from #temp
		order by  RGName, [Date]
	else
	if (@Sort = 3)
		select * from #temp
		order by  PatientName, [Date]
	if (@Sort = 4)
		select * from #temp
		order by  FileCode, [Date]		
END	
	/*GROUP BY
		R.[Code],
		R.[Name],
		O.[Date],
		P.[Guid],
		P.[Name],
		F.[GUID],
		F.CODE,
		P.GENDER,
		AC.[NAME],		
		D.RESULT,
		D.Notes,	
		D.PRICE
	*/
	--IF @ShowDetails = 1 
		--SELECT * FROM #Result
	ELSE
	BEGIN 
		INSERT INTO #Result
		SELECT
			R.[Code] as RGCode ,
			R.[Name] as RGName ,
			D.PRICE,
			1 as Cnt
		FROM
		
		[HosRadioGraphyOrderDetail000] AS D
		INNER JOIN [hosRadioGraphyOrder000] AS O ON D.ParentGuid = O.Guid 
		INNER JOIN [hosRadioGraphy000] AS R ON R.GUID = D.RadioGraphyGUID
		INNER JOIN vwHosPatient P ON O.PatientGUID =  P.GUID  

		WHERE
			O.[Date] BETWEEN @StartDate AND @EndDate
			AND ( (O.[PatientGUID] = @PatientGUID)  OR ( @PatientGUID = 0x0))
			AND ( (@RadioGraphyGuid = 0x0) OR ( @RadioGraphyGuid = R.Guid))
			--AND ( (@TypeGUID = 0x0) OR ( @TypeGUID = O.TypeGUID))
			AND ( (@DoctorGuid = 0x0) OR ( @DoctorGuid = O.DoctorGuid))
			AND ( 
					(@PatientType = -1 ) 
					OR ( @PatientType = 0 AND ISNULL(O.[FileGUID], 0X0) <> 0x0) 
					OR ( @PatientType = 1 AND ISNULL(O.[FILEGUID], 0X0) = 0X0)
				)
			AND ( (R.[TypeGuid] = @TypeGuid)  OR (@TypeGuid = 0x0)) 
		SELECT
			[RGCode],
			[RGName],
			sum(price) as price,
			SUM(Cnt) AS Cnt
			FROM
				#Result
			GROUP BY
				[RGCode],
				[RGName]
			ORDER BY CASE @Sort WHEN 1 THEN RGCode ELSE RGName END 
			
	END

####################################
#END