##################################################################################
CREATE FUNCTION fnGetAnalysisList(@AnalysisGUID UNIQUEIDENTIFIER) 
	RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER) 
AS 
BEGIN 
	DECLARE @FatherBuf TABLE(GUID UNIQUEIDENTIFIER, OK BIT DEFAULT 0) 
	DECLARE @SonsBuf TABLE (GUID UNIQUEIDENTIFIER) 
	DECLARE @Continue INT 
	SET @AnalysisGUID = ISNULL(@AnalysisGUID, 0x0) 
   	IF @AnalysisGUID = 0x0 
   	BEGIN 
			INSERT INTO @Result SELECT GUID FROM vwHosAnalysisAll
		RETURN 
	END 
	INSERT INTO @FatherBuf SELECT GUID, 0 FROM vwHosAnalysisAll WHERE GUID = @AnalysisGUID 
	SET @Continue = @@ROWCOUNT 
	WHILE @Continue <> 0 
	BEGIN 
		INSERT INTO @SonsBuf 
			SELECT A.GUID 
			FROM vwHosAnalysisAll AS A INNER JOIN @FatherBuf AS fb ON A.ParentGUID = fb.GUID 
			WHERE fb.OK = 0 
		SET @Continue = @@ROWCOUNT 
		UPDATE @FatherBuf SET OK = 1 WHERE OK = 0 
		INSERT INTO @FatherBuf SELECT GUID, 0 FROM @SonsBuf 
		DELETE FROM @SonsBuf 
	END 
	INSERT INTO @Result SELECT GUID FROM @FatherBuf
	RETURN 
END
##################################################################################
CREATE FUNCTION fnHosAllAnalysis(    
			@AnaGUID UNIQUEIDENTIFIER,   
			@Sorted INT = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)   
		RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER, [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI)    
AS BEGIN   
	DECLARE @FatherBuf TABLE( GUID UNIQUEIDENTIFIER, [Level] INT, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI, ID INT IDENTITY( 1, 1))    
	DECLARE @Continue INT, @Level INT     
	SET @Level = 0      
	  
	IF ISNULL( @AnaGUID, 0x0) = 0x0 
		INSERT INTO @FatherBuf ( GUID, Level, [Path])   
			SELECT GUID, @Level, ''  
			FROM 	 vwHosAnalysisAll
			WHERE  ISNULL( ParentGUID, 0x0) = 0x0  AND	TYPE <>3
			ORDER BY CASE @Sorted WHEN 1 THEN Code ELSE [Name] END  
	ELSE    
		INSERT INTO @FatherBuf ( GUID, Level, [Path])   
			SELECT GUID, @Level, '' FROM vwHosAnalysisAll WHERE GUID = @AnaGUID 
	   
	UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40))    
	SET @Continue = 1    
	---/////////////////////////////////////////////////////////////    
	WHILE @Continue <> 0 
	BEGIN    
		SET @Level = @Level + 1      
		INSERT INTO @FatherBuf( GUID, Level, [Path])    
			SELECT Ana.GUID, @Level, fb.[Path]   
				FROM vwHosAnalysisAll AS Ana INNER JOIN @FatherBuf AS fb ON Ana.ParentGUID = fb.GUID 
				WHERE fb.Level = @Level - 1  
				ORDER BY CASE @Sorted WHEN 1 THEN Code ELSE [Name] END   
			SET @Continue = @@ROWCOUNT      
			UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level      
	END   
	INSERT INTO @Result SELECT GUID, [Level], [Path] FROM @FatherBuf GROUP BY GUID, [Level], [Path] ORDER BY [Path]  
	RETURN   
END
##################################################################################
CREATE PROCEDURE RepHosAllAnalysis
	@Lang		INT = 0 
AS  
	SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result(  
			Guid		UNIQUEIDENTIFIER,  
			ParentGuid 	UNIQUEIDENTIFIER,  
			Code		NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			[Name]	NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			[LatinName]	NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			Number		FLOAT,  
			Security INT,  
			Type 		INT, 
			[Level] 	INT,  
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI  
		   	)  
	  
	INSERT INTO #Result   
	SELECT   
			ana.Guid,   
			ISNull(ana.ParentGUID , 0x0) AS Parent,  
			ana.Code,   
			Ana.Name, 
			Ana.LatinName, 
			ana.Number,  
			ana.Security,  
			ana.Type, 
			fn.[Level], 
			fn.Path  
		FROM 	 
			vwHosAnalysisAll as ana INNER JOIN dbo.fnHosAllAnalysis( 0x0, 1) AS fn  
			ON ana.Guid = fn.Guid 
		WHERE Type <>3
	EXEC prcCheckSecurity  
	SELECT * FROM #Result ORDER BY Path  
	SELECT * FROM #SecViol 
##################################################################################
CREATE VIEW vwHosToDoAnalysis
AS
	SELECT
			B.[Code] AS AnalysisCode,
			B.[Name]+'-'+B.[LatinName] AnalysisName, 
			A.AnalysisGUID,
			A.AnalysisOrderGUID,
			CAST( CAST (DatePart( yyyy, C.[Date]) AS NVARCHAR) + '/' + CAST ( DatePart( mm, C.[Date] ) AS NVARCHAR ) + '/'+CAST( DatePart( dd, C.[Date] )AS NVARCHAR) AS datetime) AS [Date], 
			--C.[Date], 
			C.PatientGUID, 
		   	C.AccGUID,
			C.FileGUID,
			D.[Name] PatientName,
			E.[Name] PFileName
FROM
		HosToDoAnalysis000 A 
		INNER JOIN vwhosAnalysis  B 		ON A.AnalysisGUID = B.GUID
		INNER JOIN HosAnalysisOrder000 C 	ON A.AnalysisOrderGUID = C.GUID
		LEFT JOIN vwHosPatient D 			ON C.PatientGUID = D.GUID
		LEFT JOIN vwHosFile		E 			ON C.FileGUID = E.GUID 

##################################################################################
CREATE FUNCTION fnGetAnalysisOrderList(@OrderGUID UNIQUEIDENTIFIER = 0x0)
	RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER)
AS BEGIN 
	DECLARE @c CURSOR 
	DECLARE @Guid UNIQUEIDENTIFIER
	SET @c= CURSOR FAST_FORWARD FOR
		SELECT  AnalysisGUID	
		FROM vwhosTodoAnalysis 
		WHERE (AnalysisOrderGUID = @OrderGUID) OR  (@OrderGUID = 0x0)
	OPEN @c
	FETCH @c INTO @Guid
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		INSERT INTO @Result
		SELECT  GUID
		FROM  dbo.fnGetAnalysisList(@Guid)
		FETCH @c INTO @Guid
	END
	CLOSE @c
	DEALLOCATE @c
	RETURN 	
END

##################################################################################
CREATE FUNCTION fnHosAnalysisToDo(    
			@OrderGUID UNIQUEIDENTIFIER,
			@Sorted INT = 0) 
		RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER, [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI)    
BEGIN
 INSERT INTO  @Result
 SELECT 
	 f2.* 
 FROM  dbo.fnGetAnalysisOrderList(@OrderGUID) f1 
 INNER JOIN  [dbo].fnGetAnalysisListSorted(0x0 ,1) f2 	ON  f1.GUID = f2.GUID
 RETURN 
END
##################################################################################
CREATE FUNCTION fnHosGetUnitMaxMinAnalysis
				( @ItemGUID 		UNIQUEIDENTIFIER,
					@OrderGUID  	UNIQUEIDENTIFIER,
					@Type  			INT,
					@CurDate 		DATETIME
			     )
RETURNS NVARCHAR(100) 
BEGIN
	DECLARE
			@PatientGUID 	UNIQUEIDENTIFIER,
			@FileGUID 		UNIQUEIDENTIFIER,
			@PersonGUID 	UNIQUEIDENTIFIER,
			@Unit 			NVARCHAR(255) ,
			@Max 			NVARCHAR(255),
			@Res 			NVARCHAR(255),
			@Min 			NVARCHAR(255),
			@Gender			BIT,
			@Age			FLOAT,
			@Now			DATETIME

-- select * from vwHosAnalysisOrder
	 SELECT
			@PatientGUID = PatientGUID,
			@FileGUID = FileGUID
	 FROM
			vwHosAnalysisOrder 
	 WHERE 
			GUID = @OrderGUID

	SELECT
			@Gender	= Gender, -- Gender, --≈÷«›… Õﬁ· —ﬁ„Ì ··Ã‰” ›Ì »ÿ«ﬁ… «·„—Ì÷ 
			@PersonGUID = PersonGuid
	FROM
		HosPatient000
	WHERE GUID = @PatientGUID

	-- SELECT @Now = GetDate()

	SELECT
		@Age	= DATEDIFF( Year, BirthDay, @CurDate)
	FROM
		HosPerson000
	WHERE
		Guid = @PersonGUID
		
-- select DATEDIFF( Year, '1/1/1976', GetDate() )
-- select * from HosAnaDet000

	SELECT
			@Unit = h.Unit,
			@Max = case WHEN h.MaxNormalValue = '' THEN (case WHEN d.NormalTo = '' THEN '' ELSE d.NormalTo END) ELSE h.MaxNormalValue END,
			@Min = case when h.MinNormalValue = '' then (case when d.NormalFrom = '' THEN '' ELSE d.NormalFrom END) ELSE h.MinNormalValue END
	FROM
		HosAnalysisItems000 AS h 
		LEFT JOIN HosAnaDet000 AS d 
		ON h.GUID = d.ParentGuid AND d.Gender = @Gender AND @Age BETWEEN d.FromAge AND d.ToAge
	WHERE
		h.GUID = @ItemGUID

	SET @Res = CASE @Type
		WHEN  1	 THEN @Unit
		WHEN  2	 THEN @Max
		WHEN  3	 THEN @Min
	END
 RETURN @Res
END

/*
	SELECT * -- Unit , MaxNormalValue, MinNormalValue
	FROM HosAnalysisItems000 
--  WHERE GUID = @ItemGUID

	SELECT * from HosAnaDet000
	SELECT * from HosAnalysisOrder000

select dbo.fnHosGetUnitMaxMinAnalysis
				( 'C9435361-CD78-4187-BE38-F7216BF5A8A6', -- '51E835A6-B524-4E5C-B7A6-A76AEFF7E78A',
					'DEF244E5-A9FB-49E0-AA9C-4A5A54841CB4',
					2,
					GetDate())

*/
##################################################################################
CREATE PROCEDURE RepHosAllAnalysisToDo
		@OrderGUID UNIQUEIDENTIFIER,
		@Lang		INT = 0 
AS  
	SET NOCOUNT ON 
	DECLARE @Date DATETIME ,
						@PatientGUID UNIQUEIDENTIFIER,
						@FileGUID UNIQUEIDENTIFIER

	SELECT @Date = [Date] , 
				@PatientGUID = PatientGUID,	
				@FileGUID = FileGUID
	FROM vwHosAnalysisOrder 
	WHERE GUID = @OrderGUID

	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result(  
			Guid		UNIQUEIDENTIFIER,  
			ParentGuid 	UNIQUEIDENTIFIER,  
			Code		NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			[Name]		NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			[LatinName]	NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			[Result]	NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			[LastResult]	NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			[Unit]	NVARCHAR(255) COLLATE ARABIC_CI_AI,  
			Number		FLOAT,  
			Security INT,  
			Type 		INT, 
			MinNormalValue NVARCHAR(255) COLLATE ARABIC_CI_AI,
			MaxNormalValue NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			[Level] 	INT,  
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI  
			)  
		
	INSERT INTO #Result
	SELECT
			ana.Guid,
			ISNull(ana.ParentGUID , 0x0) AS Parent,
			ana.Code,
			Ana.Name,
			Ana.LatinName,
			isNull(R.Result,''),
			LastResult = '',
			CASE 	ana.Type
				WHEN 3 THEN   dbo.fnHosGetUnitMaxMinAnalysis(ana.Guid, @OrderGUID, 1, GetDate() )
				ELSE ''
			END AS Unit,
			ana.Number,
			ana.Security,
			ana.Type,
			CASE 	ana.Type
				WHEN 3 THEN   ISNULL( dbo.fnHosGetUnitMaxMinAnalysis(ana.Guid, @OrderGUID, 2,  GetDate() ), 0)
				ELSE ''
			END AS MinNormalValue,
			CASE 	ana.Type
				WHEN 3 THEN   ISNULL( dbo.fnHosGetUnitMaxMinAnalysis(ana.Guid, @OrderGUID, 3 , GetDate()), 0)
				ELSE ''
			END AS MaxNormalValue,
			fn.[Level],
			fn.Path
		FROM
			vwHosAnalysisAll as ana INNER JOIN dbo.fnHosAnalysisToDo(@OrderGUID,1) AS fn  ON ana.Guid = fn.Guid
									LEFT  JOIN HosAnalysisResults000 R   ON  R.ItemGUID = ana.Guid and R.AnalysisOrderGUID = @OrderGUID



		CREATE TABLE #LastResult ( 
					  ItemGUID UNIQUEIDENTIFIER, 
					  LastResult NVARCHAR(255) COLLATE ARABIC_CI_AI
					  )
		
		INSERT INTO #LastResult
		SELECT ItemGUID, Result
		FROM HosAnalysisResults000  R	
			INNER JOIN vwHosAnalysisOrder O ON R.AnalysisOrderGuid = O.GUID
			INNER JOIN vwHosAnalysisAll A ON A.GUID = R.ItemGUID
		WHERE 
			(
				( PatientGUID =  @PatientGUID AND  @PatientGUID <> 0x0 )
				OR
				( FileGUID =  @FileGUID AND  @FileGUID <> 0x0 )
			)
			AND 
				[Date] =  dbo.fnHosGetMaxAnalysisDate( @PatientGUID,	ItemGUID ,@Date)
			AND 
				A.Type = 3
	ORDER By [Date]

	UPDATE  #Result   
	SET  		LastResult = #LastResult.LastResult 
	FROM 		#LastResult 
	WHERE 	#LastResult.ItemGUID = #Result.GUID

	EXEC prcCheckSecurity  
	SELECT * FROM #Result ORDER BY Path  
	SELECT * FROM #SecViol

/*

exec RepHosAllAnalysisToDo '401b9ad0-ae35-4be9-a8d0-074fc89e2c1b', 0 

select * from vwHosAnalysisAll as ana 
select dbo.fnHosGetUnitMaxMinAnalysis('C0514E62-9BB3-4CEC-98FF-4ED9A8A8AD1A', '401b9ad0-ae35-4be9-a8d0-074fc89e2c1b', 2 )


DECLARE @OrderGUID uniqueIdentifier
SET @OrderGUID = '401b9ad0-ae35-4be9-a8d0-074fc89e2c1b'

exec RepHosAllAnalysisToDo 'def244e5-a9fb-49e0-aa9c-4a5a54841cb4', 0

exec RepHosAllAnalysisToDo 'def244e5-a9fb-49e0-aa9c-4a5a54841cb4', 0 
*/
#######################################################
CREATE FUNCTION fnHosAnalysisTree(     
			@Sorted INT = 0)  
		RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER, [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI)     
BEGIN 
 INSERT INTO  @Result 
 SELECT  
	 *  
 FROM  dbo.fnGetAnalysisListSorted(0x0 ,1) 
 RETURN  
END 
#######################################################
CREATE PROCEDURE RepHosAllAnalysisTree
		@Lang		INT = 0,
		@Guid		[UNIQUEIDENTIFIER] = 0x00
AS   
	SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT)   
	CREATE TABLE #Result(   
			[Guid]		[UNIQUEIDENTIFIER],   
			ParentGuid 	UNIQUEIDENTIFIER,   
			Code		NVARCHAR(255) COLLATE ARABIC_CI_AI,   
			[Name]	NVARCHAR(255) COLLATE ARABIC_CI_AI,   
			[LatinName]	NVARCHAR(255) COLLATE ARABIC_CI_AI,   
			Number		FLOAT,   
			Security INT,   
			Type 		INT,  
			[Level] 	INT,   
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI   
			)   
		 
	INSERT INTO #Result    
	SELECT    
			ana.Guid,    
			ISNull(ana.ParentGUID , 0x0) AS Parent,   
			ana.Code,    
			Ana.Name,  
			Ana.LatinName,  
			ana.Number,  
			ana.Security,   
			ana.Type,  
			fn.[Level],  
			fn.Path   
		FROM 	  
			vwHosAnalysisAll as ana INNER JOIN dbo.fnHosAnalysisTree(@Lang) AS fn  ON ana.Guid = fn.Guid  
		WHERE @Guid = 0X00 OR @Guid	= [ana].[Guid]	
		CREATE TABLE #LastResult (  
					  ItemGUID UNIQUEIDENTIFIER,  
					  LastResult NVARCHAR(255) COLLATE ARABIC_CI_AI
					  ) 
		 
	EXEC prcCheckSecurity   
	SELECT * FROM #Result ORDER BY Path   
	SELECT * FROM #SecViol 	
##################################################################################
#END
