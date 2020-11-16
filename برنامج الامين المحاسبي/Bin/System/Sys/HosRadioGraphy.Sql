###########################################################
CREATE VIEW vwHosRadioGraphyMats
AS
SELECT R.*,
			 M.mtCode,
			 M.mtName,
			 M.mtLatinName,
			 ( case R.Unity WHEN 1 THEN 1
						 WHEN 2 THEN M.mtUnit2Fact
						 WHEN 3	THEN M.mtUnit3Fact
						 ELSE M.mtDefUnitFact END) AS mtUnitFact,
			[dbo].[fnItemSecViol]( 0x0, [R].[matGuid], [R].[storeGuid], 0x0 /*[R].[costGuid]*/) as [SecViol]
FROM 
	HosRadioGraphyMats000 R INNER JOIN VWMT M  ON R.MatGUID = M.mtGUID
###########################################################
CREATE PROCEDURE PrcHosGetRGMat(	@ParentGUID UNIQUEIDENTIFIER,	@GRIDTYPE INT	)
AS
SET NOCOUNT ON 
IF ( @GRIDTYPE = 0 ) 
BEGIN
	SELECT * 
	FROM vwHosRadioGraphyMats 
	WHERE TYPE = 0  AND ParentGUID = @ParentGUID
END
ELSE
BEGIN
	IF EXISTS ( SELECT * FROM  HosRadioGraphyMats000 WHERE  ParentGUID = @ParentGUID )
	BEGIN 
		SELECT * 
		FROM vwHosRadioGraphyMats 
		WHERE TYPE = 1  AND ParentGUID = @ParentGUID
	END
	ELSE
	BEGIN
		SELECT * FROM vwHosRadioGraphyMats
		WHERE 
		ParentGUID IN 
		(
			SELECT 
				D.RadioGraphyGUID 
			FROM 
				HosRadioGraphyOrderDetail000 D	
					INNER JOIN HosRadioGraphy000 C ON   C.GUID = D.RadioGraphyGUID
			WHERE D.ParentGUID = @ParentGUID
		)
	END
END
###########################################################
CREATE FUNCTION fnHosConverStrToLines (@Guid UNIQUEIDENTIFIER, @Str NVARCHAR(max))
RETURNS @Res TABLE (Guid UNIQUEIDENTIFIER,  Result NVARCHAR(250) COLLATE ARABIC_CI_AI)
BEGIN
	DECLARE 	@Pos INT,
						@LineStr NVARCHAR(max)
	SET  @LineStr = @Str
	Set @Pos = CHARINDEX(CHAR(13), @LineStr)
	WHILE (	@Pos > 0 )
	BEGIN
		INSERT INTO @Res VALUES (@GUID, SUBSTRING ( @LineStr , 1 , @Pos-1 ))				
		Set 	@LineStr = SUBSTRING ( @LineStr , @Pos+2 , LEN(@LineStr) ) 
		Set 	@Pos = CHARINDEX(CHAR(13), @LineStr)
	END
	INSERT INTO @Res VALUES(@GUID, @LineStr)
	RETURN
END
###########################################################
CREATE PROCEDURE RepHosRadioGraphy
		@OrderGUID UNIQUEIDENTIFIER = 0x0,
		@Lang		INT = 0 
AS  
SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result(  
			Guid		UNIQUEIDENTIFIER,  
			Code 		NVARCHAR(100)COLLATE ARABIC_CI_AI,  
			[Name] 		NVARCHAR(100)COLLATE ARABIC_CI_AI,  
			[LatinName] 		NVARCHAR(100)COLLATE ARABIC_CI_AI,  
			ItemGUID UNIQUEIDENTIFIER,  
			Result		NVARCHAR(max) COLLATE ARABIC_CI_AI,  
			Notes	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
	   	)
	
  CREATE TABLE #Lines (GUID UNIQUEIDENTIFIER,Result NVARCHAR(250)   )

	DECLARE @C CURSOR,
					@ItemGUID UNIQUEIDENTIFIER,
					@Result NVARCHAR(max)
		SET @C = CURSOR FAST_FORWARD FOR 
		SELECT   
				D.GUID,
				D.Result
		FROM 	 
				vwHosRadioGraphyOrder R	
					INNER JOIN hosRadioGraphyOrderDetail000 D ON R.GUID = D.ParentGUID
		WHERE R.GUID = @OrderGUID

		OPEN @C
		FETCH @C INTO @ItemGUID, @Result
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			--print @Result
			INSERT INTO #Lines
			SELECT Guid, Result
			FROM  fnHosConverStrToLines (@ItemGuid, @Result)
			FETCH @c INTO @ItemGUID, @Result
		END
		CLOSE @C
		DEALLOCATE @C

	INSERT INTO #Result   
	SELECT   
			R.Guid,
			I.Code,	
			I.[Name],   
			I.LatinName,   
			D.GUID,
			L.Result,
			R.Notes
		FROM 	 
			vwHosRadioGraphyOrder R
			LEFT JOIN hosRadioGraphyOrderDetail000 D ON R.GUID = D.ParentGUID
			LEFT JOIN #Lines 			L ON L.GUID = D.GUID 
			LEFT JOIN  hosRadioGraphy000 I ON I.GUID = D.RadioGraphyGUID 
	WHERE  R.GUID = @OrderGUID OR  @OrderGUID = 0x0

	EXEC prcCheckSecurity  
	SELECT * FROM #Result 
###########################################################
#END