########################################
CREATE FUNCTION fnGetPeriodList( 
	@PeriodGuid UNIQUEIDENTIFIER,@Disc INT )
RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER,  [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI, [NSons] INT) 
AS BEGIN  
	DECLARE @Continue INT, @Level INT 
	SET @Level = 0 
	DECLARE @FatherBuf	TABLE(GUID UNIQUEIDENTIFIER, Level INT, [Path] NVARCHAR(max), ID INT IDENTITY( 1, 1),NSons INT DEFAULT 0)   
	IF @Disc = 0
	BEGIN
		IF @PeriodGuid = 0x0  
				INSERT INTO @FatherBuf (GUID , [Level], [Path],[NSons]) SELECT GUID, @Level,'',0 FROM vwPeriods WHERE ((ParentGuid IS NULL) OR (ParentGuid = 0x0)) ORDER BY StartDate
			ELSE  
				INSERT INTO @FatherBuf (GUID , [Level], [Path],[NSons]) SELECT GUID, @Level,'',0 FROM vwPeriods WHERE GUID = @PeriodGuid  ORDER BY StartDate
		UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40)) 
		SET @Continue = 1   
			 
		WHILE @Continue <> 0   
		BEGIN   
			SET @Level = @Level + 1   
			INSERT INTO @FatherBuf(GUID,Level,[Path],[NSons])  
				SELECT  
					pe.GUID, @Level,fb.[Path],0
				FROM  
					vwPeriods AS pe INNER JOIN @FatherBuf AS fb  
					ON pe.ParentGuid = fb.GUID   
					WHERE  
						fb.Level = @Level - 1 
					ORDER BY  
						StartDate 
			SET @Continue = @@ROWCOUNT   
			UPDATE  @FatherBuf SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level 
				  
		END
	END
	ELSE
	BEGIN
		IF @PeriodGuid = 0x0  
				INSERT INTO @FatherBuf (GUID , [Level], [Path],[NSons]) SELECT GUID, @Level,'',0 FROM vwPeriods WHERE ((ParentGuid IS NULL) OR (ParentGuid = 0x0)) ORDER BY StartDate DESC
			ELSE  
				INSERT INTO @FatherBuf (GUID , [Level], [Path],[NSons]) SELECT GUID, @Level,'',0 FROM vwPeriods WHERE GUID = @PeriodGuid  ORDER BY StartDate DESC
		UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40)) 
		SET @Continue = 1   
			 
		WHILE @Continue <> 0   
		BEGIN   
			SET @Level = @Level + 1   
			INSERT INTO @FatherBuf(GUID,Level,[Path],[NSons])  
				SELECT  
					pe.GUID, @Level,fb.[Path],0
				FROM  
					vwPeriods AS pe INNER JOIN @FatherBuf AS fb  
					ON pe.ParentGuid = fb.GUID   
					WHERE  
						fb.Level = @Level - 1 
					ORDER BY  
						StartDate dESC
			SET @Continue = @@ROWCOUNT   
			UPDATE  @FatherBuf SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level 
				  
		END
	END

	
	WHILE  (@Level >= 0)
	BEGIN
		UPDATE  @FatherBuf  SET NSONS = ISNULL((SELECT SUM(NSons+1) FROM vwPeriods AS p INNER JOIN @FatherBuf AS f1 ON	p.Guid = f1.Guid WHERE p.ParentGuid = f.Guid),0)
		FROM @FatherBuf AS f
		WHERE f.Level = @Level
		SET @Level = @Level - 1	
		
	END
	INSERT INTO @Result SELECT GUID, [Level],[Path],[NSons] FROM @FatherBuf GROUP BY GUID, [Level],[Path],[NSons]  ORDER BY [Path]
	RETURN 
END
#############################
CREATE FUNCTION fnDistGetDistsForCust 	( @CustGuid [UNIQUEIDENTIFIER] )  
RETURNS NVARCHAR(2000)
AS  
BEGIN
	DECLARE @Dists NVARCHAR(2000)
	SET @Dists = ''
	
	DECLARE @C	CURSOR,
		@Name	NVARCHAR(255)
	SET @C = CURSOR FAST_FORWARD FOR
		SELECT D.Name
		FROM DistDistributionLines000 AS Dl 
		INNER JOIN vwDistributor AS D ON D.Guid = Dl.DistGuid 
		WHERE CustGuid = @CustGuid
		ORDER BY D.Name
	OPEN @C FETCH FROM @C INTO @Name
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Dists = CASE ISNULL(@Dists,'') WHEN '' THEN @Name ELSE @Dists + '-' + @Name END
		FETCH FROM @C INTO @Name
	END	
	CLOSE @C DEALLOCATE @C	
		
	RETURN @Dists
END
#############################
CREATE FUNCTION fnDistGetMatTemplates (@TemplateGUID uniqueidentifier) 
RETURNS 
	@MatTemplates TABLE (MatGUID UNIQUEIDENTIFIER, GroupGUID UNIQUEIDENTIFIER, TemplateGUID UNIQUEIDENTIFIER) 
AS 
BEGIN 

	DECLARE	@C 	CURSOR,
		@GrGuid	UNIQUEIDENTIFIER, 
		@TeGuid	UNIQUEIDENTIFIER

	SET @C = CURSOR FAST_FORWARD FOR
		SELECT Guid, GroupGuid FROM DistMatTemplates000 WHERE Guid = @TemplateGuid OR @TemplateGuid = 0x00

	OPEN @C FETCH FROM @C INTO @TeGuid, @GrGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO @MatTemplates
			SELECT 	mtGuid, mtGroup, @TeGuid FROM dbo.fnGetMatsOfGroups(@GrGuid) 
		FETCH FROM @C INTO @TeGuid, @GrGuid
	END
	CLOSE @C DEALLOCATE @C
	RETURN 
END 
#############################
CREATE FUNCTION fnDistGetRelatedPeriods (@PeriodGuid UNIQUEIDENTIFIER)
RETURNS	@Periods TABLE 
	(
		Number		INT,
		Guid 		UNIQUEIDENTIFIER, 
		Name		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		StartDate	DATETIME,
		EndDate		DATETIME
	)
AS 
BEGIN
	DECLARE @StartDate	DATETIME,
		@EndDate	DATETIME 
	SELECT @StartDate = StartDate, @EndDate = EndDate FROM vwPeriods WHERE Guid = @PeriodGuid 

	INSERT INTO @Periods
	SELECT 
		Number, Guid, Name, StartDate, EndDate 
	FROM 	
		vwPeriods
	WHERE 	
		ParentGuid <> 0x00 AND
		(
			(Guid = @PeriodGuid)	OR
			( (StartDate BETWEEN @StartDate AND @EndDate) AND (EndDate BETWEEN @StartDate ANd @EndDate) ) OR
			( (@StartDate BETWEEN StartDate AND EndDate)  AND (@EndDate BETWEEN StartDate ANd EndDate)  )
		)
	ORDER BY Number	

	RETURN
END
#############################
#END