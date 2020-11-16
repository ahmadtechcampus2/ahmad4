###########################################################################
CREATE  FUNCTION fnGetGroupAndParentsCond(@StartGUID [UNIQUEIDENTIFIER],@CondType [INT],@SearchStr NVARCHAR(3000),@Type [INT] = 1) 
	RETURNS [INT]
AS BEGIN 
/* 
This function: 
	- returns a list of group and parents which name has condition
	
*/ 
	DECLARE @ParentGUID [UNIQUEIDENTIFIER],@RowCnt [INT]
	DECLARE @Result TABLE([GUID] [UNIQUEIDENTIFIER], [grFilter] [NVARCHAR](256) COLLATE ARABIC_CI_AI) 
	INSERT INTO @Result
		SELECT [Guid], CASE @Type WHEN 0 THEN [Code] ELSE [Name] END FROM [gr000] WHERE [GUID] = @StartGUID
	SELECT @ParentGUID = [ParentGUID] FROM [gr000] WHERE [GUID] = @StartGUID 
	SET @RowCnt = @@ROWCOUNT
	IF @ParentGUID = 0X00
		SET @RowCnt = 0
	WHILE  @RowCnt <> 0 
	BEGIN 
		
		INSERT INTO @Result SELECT [Guid],CASE @Type WHEN 0 THEN [Code] ELSE [Name] END FROM [gr000] WHERE [GUID] = @ParentGUID
		SELECT @ParentGUID = [ParentGUID] FROM [gr000] WHERE [GUID] = @ParentGUID 
		SET @RowCnt = @@ROWCOUNT
		IF @ParentGUID = 0X00
			BREAK 
	END
	DECLARE @Cnt INT 
	SET @Cnt = 0

	IF @CondType = 0
		SELECT @Cnt = COUNT(*) FROM @Result
			WHERE [grFilter] LIKE '%' + @SearchStr + '%'
	 IF @CondType = 1	
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] NOT LIKE '%' + @SearchStr + '%'
	ELSE IF @CondType = 2	
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] LIKE  @SearchStr + '%'
	ELSE IF @CondType = 3	
		SELECT @Cnt = COUNT(*) FROM @Result 
		WHERE [grFilter] NOT LIKE  @SearchStr +'%' 
	ELSE IF @CondType = 4	
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] LIKE '%' + @SearchStr
	ELSE IF @CondType = 5
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] NOT LIKE '%' + @SearchStr 
	ELSE IF @CondType = 6
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] = @SearchStr 
	ELSE IF @CondType = 7
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] <> @SearchStr  
	ELSE IF @CondType = 8
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] > @SearchStr  
	ELSE IF @CondType = 9
		SELECT @Cnt= COUNT(*) FROM @Result 
			WHERE [grFilter] >= @SearchStr
	ELSE IF @CondType = 10
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] < @SearchStr 
	ELSE IF @CondType = 11
		SELECT @Cnt = COUNT(*) FROM @Result 
			WHERE [grFilter] <= @SearchStr  
		
	RETURN @Cnt
	end 
###########################################################################
CREATE FUNCTION fnGetPayTypeCond(@PayType [INT], @CondType [INT], @SearchStr NVARCHAR(3000),@PayTypeGUID UNIQUEIDENTIFIER)
	RETURNS [INT]
AS 
BEGIN 
	
	DECLARE @Result TABLE([NUM] [FLOAT], [NAME] [NVARCHAR](256) COLLATE ARABIC_CI_AI) 
	INSERT INTO @Result 
	SELECT NUM, NAME FROM 
	(  
		SELECT 0 NUM, 'äÞÏÇ' NAME  
		UNION ALL 
		SELECT 0 NUM, 'Cash' NAME 
		UNION ALL 
		SELECT 1 NUM, 'ÂÌá' NAME  
		UNION ALL 
		SELECT 1 NUM, 'Later' NAME 
		UNION ALL 
		SELECT SORTNUM + 1 NUM, NAME FROM NT000 WHERE GUID = @PayTypeGUID
		UNION ALL 
		SELECT SORTNUM + 1 NUM, LATINNAME NAME FROM NT000 WHERE GUID = @PayTypeGUID
	) X 
	WHERE NUM = @PayType
	
	DECLARE @Cnt INT 
	SET @Cnt = 0
	IF @CondType = 0
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] LIKE '%' + @SearchStr + '%'
	ELSE IF @CondType = 1	
		SELECT @Cnt = COUNT(*) -1 FROM @Result WHERE [Name] NOT LIKE '%' + @SearchStr + '%'
	ELSE IF @CondType = 2	
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] LIKE  @SearchStr + '%'
	ELSE IF @CondType = 3	
		SELECT @Cnt = COUNT(*) - 1 FROM @Result WHERE [Name] NOT LIKE  + @SearchStr + '%'
	ELSE IF @CondType = 4	
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] LIKE '%' + @SearchStr
	ELSE IF @CondType = 5
		SELECT @Cnt = COUNT(*) - 1 FROM @Result WHERE [Name] NOT LIKE '%' + @SearchStr 
	ELSE IF @CondType = 6
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] = @SearchStr 
	ELSE IF @CondType = 7
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] <> @SearchStr  
	ELSE IF @CondType = 8
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] > @SearchStr  
	ELSE IF @CondType = 9
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] >= @SearchStr
	ELSE IF @CondType = 10
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] < @SearchStr 
	ELSE IF @CondType = 11
		SELECT @Cnt = COUNT(*) FROM @Result WHERE [Name] <= @SearchStr  
		
	RETURN @Cnt
END
###########################################################################
CREATE  FUNCTION fnGetCustFld(@Fld INT, @CondType INT, @OrginalTable NVARCHAR(100))
RETURNS NVARCHAR(255) 
AS 
BEGIN 
	DECLARE @ID INT, 
			@CFTable NVARCHAR(100), 
			@FldName NVARCHAR(255), 
			@Type int 
						 
	-- 2000 : started calculated point 
	-- 3 : first index becuase,there are three field at beginning [Guid, Orginal_Guid, Orginal_Table] in any CF_Value Tables 
	SET @ID = @Fld - 2000 + 4 
	SET @CFTable = (Select CFGroup_Table from CFMapping000 where Orginal_Table = @OrginalTable ) 
	SET @FldName = (Select name from syscolumns where id = object_id( @CFTable )and colid=@ID) 
	SET @Type = (SELECT FldType from CFFlds000 INNER JOIN CFGroup000 ON CFGroup000.Guid = GGuid where CFGroup000.TableName =@CFTable and CFFlds000.ColumnName =@FldName) 
	 
	if @CondType > 5 
	BEGIN 
	SET @FldName =(Case @Type	WHEN 0  THEN  @CFTable  + '.'+@FldName 
					WHEN 1  THEN  'CAST(' + @CFTable  + '.'+@FldName+' AS NVARCHAR(256)) ' 
					WHEN 2  THEN  'CAST(' + @CFTable  + '.'+@FldName+' AS NVARCHAR(256)) ' 
					WHEN 3  THEN  'CAST(' + @CFTable  + '.'+@FldName+' AS NVARCHAR(256)) ' 
					WHEN 4  THEN  ' ' + @CFTable  + '.' + @FldName + ' '
					WHEN 5  THEN  @CFTable  + '.'+@FldName 
					WHEN 6  THEN  'CAST(' + @CFTable  + '.'+@FldName+' AS NVARCHAR(256)) '
					WHEN 7  THEN  ' ' + @CFTable + '.' + @FldName + ' ' 
			       END) 
	END 
	ELSE 
	BEGIN 
		if @Type = 4
		BEGIN
			SET @FldName =' CAST (DATEPART(dd,' + @CFTable + '.' + @FldName + ') AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,' + @CFTable + '.' + @FldName + ') AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,' + @CFTable + '.' + @FldName + ') AS NVARCHAR(4)) '
		END
		ELSE
		BEGIN
			SET @FldName =@CFTable  + '.'+@FldName 
		END
	END 
		 
	-- Return Name of CustomField Field 
	RETURN @FldName 
END 
###########################################################################
CREATE    FUNCTION fnGetCustFldType(@Fld INT,@OrginalTable NVARCHAR(100))
RETURNS int
AS
BEGIN
	DECLARE @ID INT,
			@CFTable NVARCHAR(100),
			@FldName NVARCHAR(100),
			@Type int 
						
	-- 2000 : started calculated point
	-- 3 : first index becuase,there are three field at beginning [Guid, Orginal_Guid, Orginal_Table] in any CF_Value Tables
	SET @ID = @Fld - 2000 + 4
	SET @CFTable = (Select CFGroup_Table from CFMapping000 where Orginal_Table = @OrginalTable )
	SET @FldName = (Select name from syscolumns where id = object_id( @CFTable )and colid=@ID)
	SET @Type = (SELECT FldType from CFFlds000 INNER JOIN CFGroup000 ON CFGroup000.Guid = GGuid where CFGroup000.TableName =@CFTable and CFFlds000.ColumnName =@FldName)
	-- Return Type of CustomField Field
	RETURN @Type
END

###########################################################################
CREATE FUNCTION fnGetCustFldCondStr(@Fld INT ,@CondType INT ,@SearchStr NVARCHAR(100) , @OrginalTable NVARCHAR(100))
RETURNS NVARCHAR(255)  
AS  
BEGIN  
	DECLARE @Type int , @CondStr NVARCHAR(255)  
						  
	-- Type [0, 4, 5] = [Text, Date  ,MultiText]  
	SET @Type = dbo.fnGetCustFldType(@Fld ,@OrginalTable ) 

-- Study Condition   
	IF( @CondType >= 6 AND @Type = 4)
	BEGIN
		DECLARE @I INT,@T INT,@D NVARCHAR(2) ,@M NVARCHAR(2) ,@Y NVARCHAR(5)    
		SET @I = 2   
		SET @T = 1   
		SET @D = ''   
		SET @M = ''   
		SET @Y = ''   
		WHILE @I < 15   
		BEGIN   
			IF SUBSTRING(@SearchStr,@I,1) = '-' OR SUBSTRING(@SearchStr,@I,1) = ''   
			BEGIN   
				IF (@D = '')   
				BEGIN   
					SET @D = SUBSTRING(@SearchStr,@T,@I -@T)   
					SET @T = @I + 1   
				END   
				ELSE if (@m = '')   
				BEGIN   
					SET @m = SUBSTRING(@SearchStr,@T,@I -@T)    
					SET @T = @I + 1   
				END   
				ELSE   
				BEGIN   
					SET @Y = SUBSTRING(@SearchStr,@T,@I -@T)    
					BREAK   
				END   
				   
			END   
			SET @I = @I + 1   
		END   
		SET @SearchStr =  @m + '-' +  @D + '-' + @Y    
	END  
----------------------------------------------------------------------------------------------- 
	SET @CondStr = (CASE @CondType  
		WHEN 0  THEN ' LIKE ''%' + @SearchStr + '%'''  
		WHEN 1  THEN ' NOT LIKE ''%' + @SearchStr + '%'''  
		WHEN 2  THEN ' LIKE ''' + @SearchStr + '%'''  
		WHEN 3  THEN ' NOT LIKE ''' + @SearchStr + '%'''  
		WHEN 4  THEN ' LIKE ''%' + @SearchStr + ''''  
		WHEN 5  THEN ' NOT LIKE ''%' + @SearchStr + ''''  
		WHEN 6  THEN CASE WHEN @Type = 0 OR @Type = 4 OR @Type = 5 OR @Type = 7 THEN ' = ''' + @SearchStr + '''' ELSE ' = ' + @SearchStr END  
		WHEN 7  THEN CASE WHEN @Type = 0 OR @Type = 4 OR @Type = 5 OR @Type = 7 THEN ' <> '''+ @SearchStr + '''' ELSE ' <> '+ @SearchStr END  
		WHEN 8  THEN CASE WHEN @Type = 0 OR @Type = 4 OR @Type = 5 OR @Type = 7 THEN ' > ''' + @SearchStr + '''' ELSE ' > ' + @SearchStr END  
		WHEN 9  THEN CASE WHEN @Type = 0 OR @Type = 4 OR @Type = 5 OR @Type = 7 THEN ' >= '''+ @SearchStr + '''' ELSE  ' >= '+ @SearchStr END  
		WHEN 10 THEN CASE WHEN @Type = 0 OR @Type = 4 OR @Type = 5 OR @Type = 7 THEN ' < ''' + @SearchStr + '''' ELSE ' < ' + @SearchStr END   
		WHEN 11 THEN CASE WHEN @Type = 0 OR @Type = 4 OR @Type = 5 OR @Type = 7 THEN ' <= '''+ @SearchStr + '''' ELSE ' <= '+ @SearchStr END  
	END)  


	-- Return Matched Condition of CustomField Field	  
	RETURN @CondStr  
END  
###########################################################################
CREATE FUNCTION fnGetConditionStr2(@ViewName AS [NVARCHAR](256) = NULL,@Guid AS [UNIQUEIDENTIFIER] = NULL)
	RETURNS [NVARCHAR](max)
AS BEGIN
/* 
This function: 
	- returns a string containing a criteria depending on mc000 
	- the return value should be used after a WHERE clause 
	- the caller is reponsible of inner joining with gr000 
*/ 
	DECLARE
		@c CURSOR,
		@SearchStr	[NVARCHAR](100),
		@FieldNum	[INT],
		@CondType	[INT],
		@Link		[INT],
		@FieldStr	[NVARCHAR](150),
		@CondStr	[NVARCHAR](150),
		@LinkStr	[NVARCHAR](50),
		@SQL		[NVARCHAR](max),
		@Criteria	[NVARCHAR](max),
		@HaveCustomFld	BIT,
		@CustomFldLowestVal	[INT],
		@SegmentFldLowestVal	[INT],
		@SegmentFldMidVal	[INT],
		@SegmentFldHighestVal	[INT],
		@CNT	[INT],
		@CNT_STR NVARCHAR(MAX)


	SET @CustomFldLowestVal = 2000
	SET @SegmentFldLowestVal = 3000
	SET @SegmentFldMidVal = 3500
	SET @SegmentFldHighestVal = 4000
	SET @HaveCustomFld = 0
	SET @c = CURSOR FAST_FORWARD FOR SELECT [SearchStr], [FieldNum], [CondType], [Link] FROM [dbo].[vwConditions] WHERE [cndGUID] = @Guid AND [cndType] = 17 ORDER BY  [Number] 
	OPEN @c FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link
	Set @Criteria = ''
	SET @CNT = 0
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Study FieldNum
		IF ( @FieldNum = 1000)
		BEGIN 
			SET @FieldStr = '('
			SET @CondStr = ''
			SET @LinkStr = '' 
		END
		ELSE IF ( @FieldNum = 1001)
		BEGIN
			SET @FieldStr = ')'
			SET @CondStr = ''
			IF @Link = 0
				SET @LinkStr = ' AND '
			ELSE IF @Link = 1
				SET @LinkStr = '  OR '
			ELSE
				SET @LinkStr = '' 
		END
		ELSE
		BEGIN
			Declare	@CFType as int
			IF @FieldNum >= @CustomFldLowestVal AND @FieldNum < @SegmentFldLowestVal AND @HaveCustomFld = 0
				SET @HaveCustomFld = 1
					
			SET @SearchStr = (CASE WHEN @FieldNum BETWEEN 14 and 34 THEN REPLACE( @SearchStr, ',', '') ELSE @SearchStr END)
			--SELECT @FieldStr
			IF @ViewName IS NOT NULL
				SET @FieldStr = (CASE @FieldNum
									WHEN 0  THEN @ViewName +'.[mtCode]'
									WHEN 1  THEN @ViewName +'.[mtName]'
									WHEN 2  THEN @ViewName +'.[mtLatinName]'
									WHEN 3  THEN @ViewName +'.[mtBarCode]'
									WHEN 4  THEN @ViewName +'.[mtSpec]'
									WHEN 5  THEN '[dbo].[fnGetGroupAndParentsCond](' + @ViewName + '.[grGuid],' +  CAST(@CondType AS [NVARCHAR](2))+ ','+ '''' + @SearchStr + '''' +',-1)' -- @ViewName +'.[grName]'
									WHEN 6  THEN @ViewName +'.[mtDim]'
									WHEN 7  THEN @ViewName +'.[mtOrigin]'
									WHEN 8  THEN @ViewName +'.[mtPos]'
									WHEN 9 THEN @ViewName +'.[mtCompany]'
									WHEN 10  THEN @ViewName +'.[mtModel]'
									WHEN 11  THEN @ViewName +'.[mtQuality]'
									WHEN 12  THEN @ViewName +'.[mtProvenance]'
									WHEN 13  THEN @ViewName +'.[mtColor]'
									WHEN 14  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtWhole]'  ELSE 'CAST(' + @ViewName  + '.[mtWhole] AS NVARCHAR(256)) 'END
									WHEN 15  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtHalf]'  ELSE 'CAST(' + @ViewName  + '.[mtHalf] AS NVARCHAR(256)) 'END
									WHEN 16  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtRetail]' ELSE 'CAST(' + @ViewName  + '.[mtRetail] AS NVARCHAR(256)) 'END
									WHEN 17  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtExport]' ELSE 'CAST(' + @ViewName  + '. [mtExport] AS NVARCHAR(256)) 'END
									WHEN 18  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtVendor]' ELSE 'CAST(' + @ViewName  + '.[mtVendor] AS NVARCHAR(256)) 'END
									WHEN 19  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtEndUser]'ELSE 'CAST(' + @ViewName  + '.[mtEndUser] AS NVARCHAR(256)) 'END
									WHEN 20  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtLow]' ELSE 'CAST(' + @ViewName  + '.[mtLow] AS NVARCHAR(256)) 'END
									WHEN 21  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtHigh]' ELSE 'CAST(' + @ViewName  + '.[mtHigh] AS NVARCHAR(256)) 'END
									WHEN 22  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtVat]' ELSE 'CAST(' + @ViewName  + '.[mtVat] AS NVARCHAR(256)) 'END
									WHEN 23  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtWhole2]'  ELSE 'CAST(' + @ViewName  + '.[mtWhole2] AS NVARCHAR(256)) 'END
									WHEN 24  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtHalf2]'  ELSE 'CAST(' + @ViewName  + '.[mtHalf2] AS NVARCHAR(256)) 'END
									WHEN 25  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtRetail2]' ELSE 'CAST(' + @ViewName  + '.[mtRetail2] AS NVARCHAR(256)) 'END
									WHEN 26  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtExport2]' ELSE 'CAST(' + @ViewName  + '. [mtExport2] AS NVARCHAR(256)) 'END
									WHEN 27  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtVendor2]' ELSE 'CAST(' + @ViewName  + '.[mtVendor2] AS NVARCHAR(256)) 'END
									WHEN 28  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtEndUser2]'ELSE 'CAST(' + @ViewName  + '.[mtEndUser2] AS NVARCHAR(256)) 'END
									WHEN 29  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtWhole3]'  ELSE 'CAST(' + @ViewName  + '.[mtWhole3] AS NVARCHAR(256)) 'END
									WHEN 30  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtHalf3]'  ELSE 'CAST(' + @ViewName  + '.[mtHalf3] AS NVARCHAR(256)) 'END
									WHEN 31  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtRetail3]' ELSE 'CAST(' + @ViewName  + '.[mtRetail3] AS NVARCHAR(256)) 'END
									WHEN 32  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtExport3]' ELSE 'CAST(' + @ViewName  + '. [mtExport3] AS NVARCHAR(256)) 'END
									WHEN 33  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtVendor3]' ELSE 'CAST(' + @ViewName  + '.[mtVendor3] AS NVARCHAR(256)) 'END
									WHEN 34  THEN CASE WHEN @CondType > 5 THEN @ViewName +'.[mtEndUser3]'ELSE 'CAST(' + @ViewName  + '.[mtEndUser3] AS NVARCHAR(256)) 'END
									WHEN 35  THEN @ViewName +'.[MtBarCode2]'
									WHEN 36  THEN @ViewName +'.[MtBarCode3]'
									WHEN 38  THEN '[dbo].[fnGetGroupAndParentsCond](' + @ViewName + '.[grGuid],' +  CAST(@CondType AS [NVARCHAR](2))+ ','+ '''' + @SearchStr + '''' +', 0)'
									ELSE
									CASE
										WHEN (@FieldNum < @SegmentFldLowestVal OR @FieldNum >= @SegmentFldHighestVal) THEN
											dbo.fnGetCustFld(@FieldNum, @CondType, 'mt000')
									END
								END)
			ELSE
				SET @FieldStr = (CASE @FieldNum
									WHEN 0  THEN '[MtCode]'
									WHEN 1  THEN '[MtName]'
									WHEN 2  THEN '[MtLatinName]'
									WHEN 3  THEN '[MtBarCode]'
									WHEN 4  THEN '[MtSpec]'
									WHEN 5  THEN '[dbo].[fnGetGroupAndParentsCond]([grGuid],' +  CAST(@CondType AS [NVARCHAR](2))+ ','+ '''' + @SearchStr + '''' +',-1)'--'[grName]'
									WHEN 6  THEN '[MtDim]'
									WHEN 7  THEN '[MtOrigin]'
									WHEN 8  THEN '[MtPos]'
									WHEN 9  THEN 'MtCompany'
									WHEN 10  THEN '[mtModel]'
									WHEN 11  THEN '[mtQuality]'
									WHEN 12  THEN '[mtProvenance]'
									WHEN 13  THEN '[mtColor]'
									WHEN 14  THEN CASE WHEN @CondType > 5 THEN '[mtWhole]' ELSE 'CAST( [mtWhole] AS NVARCHAR(256)) 'END
									WHEN 15  THEN CASE WHEN @CondType > 5 THEN '[mtHalf]' ELSE 'CAST( [mtHalf] AS NVARCHAR(256)) 'END
									WHEN 16  THEN CASE WHEN @CondType > 5 THEN '[mtRetail]' ELSE 'CAST( [mtRetail] AS NVARCHAR(256)) 'END
									WHEN 17  THEN CASE WHEN @CondType > 5 THEN '[mtExport]' ELSE 'CAST( [mtExport] AS NVARCHAR(256)) 'END
									WHEN 18  THEN CASE WHEN @CondType > 5 THEN '[mtVendor]' ELSE 'CAST( [mtVendor] AS NVARCHAR(256)) 'END
									WHEN 19  THEN CASE WHEN @CondType > 5 THEN '[mtEndUser]' ELSE 'CAST( [mtEndUser] AS NVARCHAR(256)) 'END
									WHEN 20  THEN CASE WHEN @CondType > 5 THEN '[mtLow]' ELSE 'CAST( [mtLow] AS NVARCHAR(256)) 'END
									WHEN 21  THEN CASE WHEN @CondType > 5 THEN '[mtHigh]' ELSE 'CAST( [mtHigh] AS NVARCHAR(256)) 'END
									WHEN 22  THEN CASE WHEN @CondType > 5 THEN '[mtVat]' ELSE 'CAST( [mtVat] AS NVARCHAR(256)) 'END
									WHEN 23  THEN CASE WHEN @CondType > 5 THEN '[mtWhole2]' ELSE 'CAST( [mtWhole2] AS NVARCHAR(256)) 'END
									WHEN 24  THEN CASE WHEN @CondType > 5 THEN '[mtHalf2]' ELSE 'CAST( [mtHalf2] AS NVARCHAR(256)) 'END
									WHEN 25  THEN CASE WHEN @CondType > 5 THEN '[mtRetail2]' ELSE 'CAST( [mtRetail2] AS NVARCHAR(256)) 'END
									WHEN 26  THEN CASE WHEN @CondType > 5 THEN '[mtExport2]' ELSE 'CAST( [mtExport2] AS NVARCHAR(256)) 'END
									WHEN 27  THEN CASE WHEN @CondType > 5 THEN '[mtVendor2]' ELSE 'CAST( [mtVendor2] AS NVARCHAR(256)) 'END
									WHEN 28  THEN CASE WHEN @CondType > 5 THEN '[mtEndUser2]' ELSE 'CAST( [mtEndUser2] AS NVARCHAR(256)) 'END
									WHEN 29  THEN CASE WHEN @CondType > 5 THEN '[mtWhole3]' ELSE 'CAST( [mtWhole3] AS NVARCHAR(256)) 'END
									WHEN 30  THEN CASE WHEN @CondType > 5 THEN '[mtHalf3]' ELSE 'CAST( [mtHalf3] AS NVARCHAR(256)) 'END
									WHEN 31  THEN CASE WHEN @CondType > 5 THEN '[mtRetail3]' ELSE 'CAST( [mtRetail3] AS NVARCHAR(256)) 'END
									WHEN 32  THEN CASE WHEN @CondType > 5 THEN '[mtExport3]' ELSE 'CAST( [mtExport3] AS NVARCHAR(256)) 'END
									WHEN 33  THEN CASE WHEN @CondType > 5 THEN '[mtVendor3]' ELSE 'CAST( [mtVendor3] AS NVARCHAR(256)) 'END
									WHEN 34  THEN CASE WHEN @CondType > 5 THEN '[mtEndUser3]' ELSE 'CAST( [mtEndUser3] AS NVARCHAR(256)) 'END
									WHEN 35  THEN '[MtBarCode2]'
									WHEN 36  THEN '[MtBarCode3]'
									WHEN 38  THEN '[dbo].[fnGetGroupAndParentsCond]([grGuid],' +  CAST(@CondType AS [NVARCHAR](2))+ ','+ '''' + @SearchStr + '''' +', 0)'
									ELSE
									CASE
										WHEN (@FieldNum < @SegmentFldLowestVal OR @FieldNum >= @SegmentFldHighestVal) THEN
										 dbo.fnGetCustFld(@FieldNum, @CondType, 'mt000')
									END
								END)
				-- Study Condition
				IF @FieldNum >= @CustomFldLowestVal AND @FieldNum < @SegmentFldLowestVal AND @HaveCustomFld = 1		
					-- Custom Field  Condition
					BEGIN
						SET @CondStr=  dbo.fnGetCustFldCondStr(@FieldNum ,@CondType ,@SearchStr , 'mt000' )
					END
				ELSE
					BEGIN 						
						SET @CondStr = (CASE @CondType
											WHEN 0  THEN ' LIKE N''%' + @SearchStr + '%'''
											WHEN 1  THEN ' NOT LIKE N''%' + @SearchStr + '%'''
											WHEN 2  THEN ' LIKE N''' + @SearchStr + '%'''
											WHEN 3  THEN ' NOT LIKE N''' + @SearchStr + '%'''
											WHEN 4  THEN ' LIKE N''%' + @SearchStr + ''''
											WHEN 5  THEN ' NOT LIKE N''%' + @SearchStr + ''''
											WHEN 6  THEN CASE WHEN (@FieldNum < 14) OR (@FieldNum >= @SegmentFldLowestVal AND @FieldNum < @SegmentFldHighestVal) THEN ' =  N''' + @SearchStr + '''' ELSE ' =  ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
											WHEN 7  THEN CASE WHEN (@FieldNum < 14) OR (@FieldNum >= @SegmentFldLowestVal AND @FieldNum < @SegmentFldHighestVal) THEN ' <> N''' + @SearchStr + '''' ELSE ' <> ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
											WHEN 8  THEN CASE WHEN (@FieldNum < 14) OR (@FieldNum >= @SegmentFldLowestVal AND @FieldNum < @SegmentFldHighestVal) THEN ' >  N''' + @SearchStr + '''' ELSE ' >  ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
											WHEN 9  THEN CASE WHEN (@FieldNum < 14) OR (@FieldNum >= @SegmentFldLowestVal AND @FieldNum < @SegmentFldHighestVal) THEN ' >= N''' + @SearchStr + '''' ELSE ' >= ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
											WHEN 10 THEN CASE WHEN (@FieldNum < 14) OR (@FieldNum >= @SegmentFldLowestVal AND @FieldNum < @SegmentFldHighestVal) THEN ' <  N''' + @SearchStr + '''' ELSE ' <  ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
											WHEN 11 THEN CASE WHEN (@FieldNum < 14) OR (@FieldNum >= @SegmentFldLowestVal AND @FieldNum < @SegmentFldHighestVal) THEN ' <= N''' + @SearchStr + '''' ELSE ' <= ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
					                    END)
					END

			IF @FieldNum = 5 OR @FieldNum = 38
				SET @CondStr = ' > 0'
				
			IF @Link = 0
				SET @LinkStr = ' AND '
			ELSE IF @Link = 1
				SET @LinkStr = '  OR '
			ELSE
				SET @LinkStr = '' 
		END
		-- Study link:
		SET @CNT = @CNT + 1
		SET @CNT_STR = CONVERT(NVARCHAR, @CNT) 
		IF @FieldNum >= @SegmentFldLowestVal AND @FieldNum < @SegmentFldMidVal
			SET @Criteria = @Criteria + ' (s' + @CNT_STR + '.Number = ' + CAST((@FieldNum - @SegmentFldLowestVal + 1) AS [NVARCHAR](150)) + ' AND s' + @CNT_STR + '.Name ' +  @CondStr + ') ' + @LinkStr
		ELSE IF @FieldNum >= @SegmentFldMidVal AND @FieldNum < @SegmentFldHighestVal
			SET @Criteria = @Criteria + ' (s' + @CNT_STR + '.Number = ' + CAST((@FieldNum - @SegmentFldMidVal + 1) AS [NVARCHAR](150)) + ' AND s' + @CNT_STR + '.Code ' +  @CondStr + ') ' + @LinkStr
		ELSE
			SET @Criteria = @Criteria + @FieldStr + @CondStr + @LinkStr

		FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link
	END
	CLOSE @c
	DEALLOCATE @c
	-- truncate the last @LinkStr
	DECLARE @Left [NVARCHAR](4) 
	SET @Left = RIGHT(@Criteria,  4)
	IF @Criteria <> '' AND (@Left = 'AND ' OR @Left = ' OR ')
		SET @Criteria = LEFT(@Criteria, LEN(@Criteria) - 3)
	IF @HaveCustomFld > 0
		SET @Criteria = @Criteria + '<<>>'
	RETURN @Criteria
	
END	
###########################################################################
CREATE FUNCTION fnGetCostConditionStr(@ViewName AS [NVARCHAR](256) = NULL,@Guid AS [UNIQUEIDENTIFIER] = NULL) 
	RETURNS [NVARCHAR](max) 
AS BEGIN 
/*   
This function:   
	- returns a string containing a criteria depending on mc000   
	- the return value should be used after a WHERE clause   
	- the caller is reponsible of inner joining with gr000   
*/   
	DECLARE  
		@c CURSOR,  
		@SearchStr	[NVARCHAR](100),  
		@FieldNum	[INT],  
		@CondType	[INT],  
		@Link		[INT],  
		@FieldStr	[NVARCHAR](250),  
		@CondStr	[NVARCHAR](200),  
		@LinkStr	[NVARCHAR](150),  
		@SQL		[NVARCHAR](max),  
		@Criteria	[NVARCHAR](max),  
		@HaveCustomFld	BIT -- to check existing Custom Fields , it must = 1  
	SET @HaveCustomFld = 0  
	DECLARE @I INT,@T INT,@D NVARCHAR(2) ,@M NVARCHAR(2) ,@Y NVARCHAR(5)  
	SET @c = CURSOR FAST_FORWARD FOR SELECT [SearchStr], [FieldNum], [CondType], [Link] FROM [dbo].[vwConditions] WHERE [cndGUID] = @Guid AND [cndType] = 50 ORDER BY  [Number]   
	OPEN @c FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link  
	Set @Criteria = ''  
	IF @ViewName != NULL AND @ViewName != ''
		SET @ViewName = @ViewName + '.'
	ELSE IF @ViewName = NULL
		SET @ViewName = ''
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		-- Study FieldNum  
		IF ( @FieldNum = 1000)  
		BEGIN   
			SET @FieldStr = '('  
			SET @CondStr = ''  
			SET @LinkStr = ''   
		END  
		ELSE IF ( @FieldNum = 1001)  
		BEGIN  
			SET @FieldStr = ')'  
			SET @CondStr = ''  
			IF @Link = 0  
				SET @LinkStr = ' AND '  
			ELSE IF @Link = 1  
				SET @LinkStr = '  OR '  
			ELSE  
				SET @LinkStr = ''   
		END  
		ELSE  
		BEGIN  
			IF @FieldNum >= 2000 AND @HaveCustomFld = 0  
				SET @HaveCustomFld = 1  
			SET @FieldStr = (CASE @FieldNum   
								WHEN 0  THEN @ViewName + 'coNUMBER '  
								WHEN 1  THEN @ViewName + 'coCODE '  
								WHEN 2  THEN @ViewName + 'coNAME '  
								WHEN 3  THEN @ViewName + 'coLATINNAME '  
								WHEN 4  THEN @ViewName + 'coDEBIT '  
								WHEN 5  THEN @ViewName + 'coCREDIT '  
								--ELSE  
								-- Custom Field  Condition	  
									--dbo.fnGetCustFld(@FieldNum, @CondType, 'co000')  
								END)  

			IF @FieldNum >= 2000 AND @HaveCustomFld = 1		  
			-- Custom Field  Condition  
			BEGIN  
				SET @CondStr = dbo.fnGetCustFldCondStr(@FieldNum ,@CondType ,@SearchStr , 'co000' )  
			END   
			ELSE  
			Begin 
				SET @CondStr = (CASE @CondType  
									WHEN 0  THEN ' LIKE ''%' + @SearchStr + '%'''  
									WHEN 1  THEN ' NOT LIKE ''%' + @SearchStr + '%'''  
									WHEN 2  THEN ' LIKE ''' + @SearchStr + '%'''  
									WHEN 3  THEN ' NOT LIKE ''' + @SearchStr + '%'''  
									WHEN 4  THEN ' LIKE ''%' + @SearchStr + ''''  
									WHEN 5  THEN ' NOT LIKE ''%' + @SearchStr + ''''  
									WHEN 6  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' = ''' + @SearchStr + '''' ELSE ' = ' + @SearchStr END  
									WHEN 7  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <> ''' + @SearchStr + '''' ELSE ' <> ' + @SearchStr END  
									WHEN 8  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' > ''' + @SearchStr + '''' ELSE ' > ' + @SearchStr END  
									WHEN 9  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN' >= ''' + @SearchStr + '''' ELSE ' >= ' + @SearchStr END  
									WHEN 10 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' < ''' + @SearchStr + '''' ELSE ' < ' + @SearchStr END  
									WHEN 11 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <= ''' + @SearchStr + '''' ELSE ' <= ' + @SearchStr END  
								END)  
			END 
		
			IF @Link = 0  
				SET @LinkStr = ' AND '  
			ELSE IF @Link = 1  
				SET @LinkStr = '  OR '  
			ELSE  
				SET @LinkStr = ''   
		END  
		-- Study link:  
		  
		SET @Criteria = @Criteria + @FieldStr + @CondStr + @LinkStr  
		FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link  
	END  
	CLOSE @c  
	DEALLOCATE @c  

	-- truncate the last @LinkStr  
	DECLARE @Left [NVARCHAR](4)   
	SET @Left = RIGHT(@Criteria,  4)  
	IF @Criteria <> '' AND (@Left = 'AND ' OR @Left = ' OR ')  
		SET @Criteria = LEFT(@Criteria, LEN(@Criteria) - 3)  
	IF @HaveCustomFld > 0  
		SET @Criteria = @Criteria + '<<>>' 
	RETURN @Criteria  
END  
###########################################################################
CREATE FUNCTION fnGetBillConditionStr(@ViewName AS [NVARCHAR](256) = NULL,@Guid AS [UNIQUEIDENTIFIER] = NULL,@CurrGuid UNIQUEIDENTIFIER = 0x00) 
	RETURNS [NVARCHAR](max) 
AS BEGIN 
/*   
This function:   
	- returns a string containing a criteria depending on mc000   
	- the return value should be used after a WHERE clause   
	- the caller is reponsible of inner joining with gr000   
*/ 
	DECLARE  
		@c CURSOR,  
		@SearchStr	[NVARCHAR](100),  
		@FieldNum	[INT],  
		@CondType	[INT],  
		@Link		[INT],  
		@FieldStr	[NVARCHAR](300),  
		@CondStr	[NVARCHAR](200),  
		@LinkStr	[NVARCHAR](150),  
		@SQL		[NVARCHAR](max),  
		@Criteria	[NVARCHAR](max),  
		@Curr		[Bit], 
		@HaveCustomFld	BIT -- to check existing Custom Fields , it must = 1  
	SET @HaveCustomFld = 0  
	DECLARE @I INT,@T INT,@D NVARCHAR(2) ,@M NVARCHAR(2) ,@Y NVARCHAR(5)  
	SET @c = CURSOR FAST_FORWARD FOR SELECT [SearchStr], [FieldNum], [CondType], [Link] FROM [dbo].[vwConditions] WHERE [cndGUID] = @Guid AND [cndType] = 40 ORDER BY  [Number]   
	OPEN @c FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link  
	Set @Criteria = ''  
	SET @Curr = 0  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		-- Study FieldNum  
		IF ( @FieldNum = 1000)  
		BEGIN   
			SET @FieldStr = '('  
			SET @CondStr = ''  
			SET @LinkStr = ''   
		END  
		ELSE IF ( @FieldNum = 1001)  
		BEGIN  
			SET @FieldStr = ')'  
			SET @CondStr = ''  
			IF @Link = 0  
				SET @LinkStr = ' AND '  
			ELSE IF @Link = 1  
				SET @LinkStr = '  OR '  
			ELSE  
				SET @LinkStr = ''   
		END  
		ELSE  
		BEGIN  
			IF @FieldNum >= 2000 AND @HaveCustomFld = 0  
				SET @HaveCustomFld = 1 
			IF @ViewName IS NOT NULL  
				SET @FieldStr = (CASE @FieldNum   
									WHEN 0  THEN @ViewName +'.[biCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE CODE '  
									WHEN 1  THEN @ViewName +'.[biCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE CODE '  
									WHEN 2  THEN @ViewName +'.[biClassPtr]'  
									WHEN 3  THEN CASE WHEN @CondType > 5 THEN @ViewName + '.[biExpireDate]' ELSE 'CAST (DATEPART(dd,' + @ViewName +'.[biExpireDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + 'CAST (DATEPART(mm,' + @ViewName +'.[biExpireDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,' + @ViewName +'.[biExpireDate]) AS NVARCHAR(4))' END  
									WHEN 4  THEN CASE WHEN @CondType > 5 THEN @ViewName + '.[biProductionDate]' ELSE 'CAST (DATEPART(dd,' + @ViewName +'.[biProductionDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + 'CAST (DATEPART(mm,' + @ViewName +'.[biProductionDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,' + @ViewName +'.[biProductionDate]) AS NVARCHAR(4))' END  
									WHEN 5  THEN @ViewName +'.[biWidth]'  
									WHEN 6  THEN @ViewName +'.[biLength]'  
									WHEN 7  THEN @ViewName +'.[biHeight]'  
									WHEN 8  THEN @ViewName +'.[buTextFld1]'  
									WHEN 9  THEN @ViewName +'.[buTextFld2]'  
									WHEN 10  THEN @ViewName +'.[buTextFld3]'  
									WHEN 11  THEN @ViewName +'.[buTextFld4]'  
									WHEN 12  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix]('+ @ViewName + '.biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''', [buDate])' ELSE 'STR([dbo].[fnCurrency_fix]('+ @ViewName + '.biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END  
									WHEN 13  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix]('+ @ViewName + '.biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix]('+ @ViewName + '.biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END  
									WHEN 14  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix]('+ @ViewName + '.biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix]('+ @ViewName + '.biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END  
									WHEN 15  THEN CASE WHEN @CondType > 5 THEN @ViewName + '.[BuSalesManPtr]' ELSE 'STR(' + @ViewName + '.[BuSalesManPtr])' END  
									WHEN 16  THEN CASE WHEN @CondType > 5 THEN @ViewName + '.[BuVendor]' ELSE 'STR('+ @ViewName + '.[BuVendor])' END  
									WHEN 17  THEN	' ISNULL((SELECT co2.Code FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '   
									WHEN 18  THEN	' ISNULL((SELECT co2.Name FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '   
									WHEN 19  THEN '([biPrice]/CASE biUnity WHEN 1 THEN 1 WHEN 2 THEN (SELECT Unit2Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) ELSE (SELECT Unit3Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) END * [dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]) )'
									WHEN 20  THEN '(CASE WHEN [biQty]*[biPrice] = 0 THEN 0 ELSE (biDiscount/([biQty]*[biPrice]/CASE biUnity WHEN 1 THEN 1 WHEN 2 THEN (SELECT Unit2Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) ELSE (SELECT Unit3Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) END)) END * 100)'
									WHEN 21  THEN @ViewName +'.[buNumber]'  
									WHEN 22  THEN @ViewName +'.[buVat]'
									WHEN 23  THEN '[dbo].[fnGetPayTypeCond](' + @ViewName + '[buPayType],' +  CAST(@CondType AS [NVARCHAR](2))+ ','+ '''' + @SearchStr + ''','+@ViewName +'.buCheckTypeGUID)'
									WHEN 24  THEN @ViewName + '.[AddressCountry]'
									WHEN 25  THEN @ViewName + '.[AddressCity]'
									WHEN 26  THEN @ViewName + '.[AddressArea]'
									WHEN 27  THEN @ViewName + '.[AddressStreet]'
									WHEN 28  THEN @ViewName + '.[AddressBulidingNumber]'
									WHEN 29  THEN @ViewName + '.[AddressFloorNumber]'
									WHEN 30  THEN @ViewName + '.[AddressPOBox]'
									WHEN 31  THEN @ViewName + '.[AddressZipCode]'
									ELSE  
									-- Custom Field  Condition	  
										dbo.fnGetCustFld(@FieldNum, @CondType, 'bu000')  
									END)  
			ELSE  
				SET @FieldStr = (CASE @FieldNum  
									WHEN 0  THEN '[biCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE [CODE] '  
									WHEN 1  THEN '[biCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE [Name] '  
									WHEN 2  THEN '[biClassPtr]'  
									WHEN 3  THEN CASE WHEN @CondType > 5 THEN '[biExpireDate]' ELSE 'CAST (DATEPART(dd,[biExpireDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,[biExpireDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,[biExpireDate]) AS NVARCHAR(4))' END  
									WHEN 4  THEN CASE WHEN @CondType > 5 THEN '[biProductionDate]' ELSE 'CAST (DATEPART(dd,[biProductionDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,[biProductionDate]) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,[biProductionDate]) AS NVARCHAR(4))' END  
									WHEN 5  THEN '[biWidth]'  
									WHEN 6  THEN '[biLength]'  
									WHEN 7  THEN '[biHeight]'  
									WHEN 8  THEN '[buTextFld1]'  
									WHEN 9  THEN '[buTextFld2]'  
									WHEN 10  THEN '[buTextFld3]'  
									WHEN 11  THEN  '[buTextFld4]'  
									WHEN 12  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix](biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix](biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END  
									WHEN 13  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix](biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''', [buDate])' ELSE 'STR([dbo].[fnCurrency_fix](biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END  
									WHEN 14  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix](biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix](biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END  
									WHEN 15  THEN CASE WHEN @CondType > 5 THEN '[BuSalesManPtr]' ELSE 'STR([BuSalesManPtr])' END  
									WHEN 16  THEN CASE WHEN @CondType > 5 THEN '[BuVendor]' ELSE 'STR([BuVendor])' END  
									WHEN 17  THEN	' ISNULL((SELECT co2.Code FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '   
									WHEN 18  THEN	' ISNULL((SELECT co2.Name FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '   
									WHEN 19  THEN '([biPrice]/CASE biUnity WHEN 1 THEN 1 WHEN 2 THEN (SELECT Unit2Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) ELSE (SELECT Unit3Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) END * [dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]) )'
									WHEN 20  THEN '(CASE WHEN [biQty]*[biPrice] = 0 THEN 0 ELSE (biDiscount/([biQty]*[biPrice]/CASE biUnity WHEN 1 THEN 1 WHEN 2 THEN (SELECT Unit2Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) ELSE (SELECT Unit3Fact FROM mt000 mtc WHERE mtc.Guid = biMatPtr) END)) END * 100)'
									WHEN 21  THEN '[buNumber]'  
									when 22  THEN '[buVat]'
									WHEN 23  THEN '[dbo].[fnGetPayTypeCond]([buPayType],' +  CAST(@CondType AS [NVARCHAR](2))+ ','+ '''' + @SearchStr + ''',buCheckTypeGUID)'
									WHEN 24  THEN '[AddressCountry]'
									WHEN 25  THEN '[AddressCity]'
									WHEN 26  THEN '[AddressArea]'
									WHEN 27  THEN '[AddressStreet]'
									WHEN 28  THEN '[AddressBulidingNumber]'
									WHEN 29  THEN '[AddressFloorNumber]'
									WHEN 30  THEN '[AddressPOBox]'
									WHEN 31  THEN '[AddressZipCode]'

									ELSE  
									-- Custom Field  Condition	  
										dbo.fnGetCustFld(@FieldNum, @CondType, 'bu000')  
									END)  
			 	   
			IF (@FieldNum = 1) OR (@FieldNum = 0)  
				SET @Curr = 1  
			ELSE  
				SET @Curr = 0  
			-- Study Condition  
			IF ((@CondType >= 6) AND ((@FieldNum = 3) OR (@FieldNum = 4)) )  
			BEGIN  
				SET @I = 2  
				SET @T = 1  
				SET @D = ''  
				SET @M = ''  
				SET @Y = ''  
				WHILE @I < 15  
				BEGIN  
					IF SUBSTRING(@SearchStr,@I,1) = '-' OR SUBSTRING(@SearchStr,@I,1) = ''  
					BEGIN  
						IF (@D = '')  
						BEGIN  
							SET @D = SUBSTRING(@SearchStr,@T,@I -@T)  
							SET @T = @I + 1  
						END  
						ELSE if (@m = '')  
						BEGIN  
							SET @m = SUBSTRING(@SearchStr,@T,@I -@T)   
							SET @T = @I + 1  
						END  
						ELSE  
						BEGIN  
							SET @Y = SUBSTRING(@SearchStr,@T,@I -@T)   
							BREAK  
						END  
						  
					END  
					SET @I = @I + 1  
				END
				IF (CONVERT(int, @m) BETWEEN 1 AND 12) AND (CONVERT(int, @D) BETWEEN 1 AND 31)
					SET @SearchStr =   @m + '/' +  @D + '/' + @Y  
				ELSE
					SET @SearchStr =  '1/1/1980' 
				 
			END  
			 
			IF @FieldNum >= 2000 AND @HaveCustomFld = 1		  
			-- Custom Field  Condition  
			BEGIN  
				SET @CondStr=    dbo.fnGetCustFldCondStr(@FieldNum ,@CondType ,@SearchStr , 'bu000' )  
			END   
			ELSE  
			Begin 
				SET @CondStr = (CASE @CondType  
									WHEN 0  THEN ' LIKE ''%' + @SearchStr + '%'''  
									WHEN 1  THEN ' NOT LIKE ''%' + @SearchStr + '%'''  
									WHEN 2  THEN ' LIKE ''' + @SearchStr + '%'''  
									WHEN 3  THEN ' NOT LIKE ''' + @SearchStr + '%'''  
									WHEN 4  THEN ' LIKE ''%' + @SearchStr + ''''  
									WHEN 5  THEN ' NOT LIKE ''%' + @SearchStr + ''''  
									WHEN 6  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' = '''  + REPLACE(@SearchStr, ',', '') + '''' ELSE ' = '  + REPLACE(@SearchStr, ',', '') END  
									WHEN 7  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <> ''' + REPLACE(@SearchStr, ',', '') + '''' ELSE ' <> ' + REPLACE(@SearchStr, ',', '') END  
									WHEN 8  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' > '''  + REPLACE(@SearchStr, ',', '') + '''' ELSE ' > '  + REPLACE(@SearchStr, ',', '') END  
									WHEN 9  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN' >= '''  + REPLACE(@SearchStr, ',', '') + '''' ELSE ' >= ' + REPLACE(@SearchStr, ',', '') END  
									WHEN 10 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' < '''  + REPLACE(@SearchStr, ',', '') + '''' ELSE ' < '  + REPLACE(@SearchStr, ',', '') END  
									WHEN 11 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <= ''' + REPLACE(@SearchStr, ',', '') + '''' ELSE ' <= ' + REPLACE(@SearchStr, ',', '') END  
								END)  
			END 
			IF @Curr > 0  
			BEGIN  
				SET @CondStr = @CondStr + ')'  
			END  
				  
			IF @Link = 0  
				SET @LinkStr = ' AND '  
			ELSE IF @Link = 1  
				SET @LinkStr = '  OR '  
			ELSE  
				SET @LinkStr = ''   
		END  
		
		--- Pay Type ---------------------------
		IF @FieldNum = 23
			SET @CondStr = ' > 0' 
		----------------------------------------
		
		-- Study link:  
		  
		SET @Criteria = @Criteria + @FieldStr + @CondStr + @LinkStr  
		FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link  
	END  
	CLOSE @c  
	DEALLOCATE @c  
	-- truncate the last @LinkStr  
	DECLARE @Left [NVARCHAR](4)   
	SET @Left = RIGHT(@Criteria,  4)  
	IF @Criteria <> '' AND (@Left = 'AND ' OR @Left = ' OR ')  
		SET @Criteria = LEFT(@Criteria, LEN(@Criteria) - 3)  
	IF @HaveCustomFld > 0  
		SET @Criteria = @Criteria + '<<>>' 
	RETURN @Criteria  
END  
###########################################################################
CREATE VIEW vwConditions
AS 
	SELECT  [cnd].[GUID] AS [cndGuid],[cnd].[Name] AS [cndName],[cnd].[State] AS [cndState], [cnd].[Date] AS [cndDate],[cnd].[Type] AS [cndType],
		[cndi].[SearchStr],[cndi].[FieldNum],[cndi].[CondType],[cndi].[Link],[cndi].[Number]
	FROM 	[dbo].[Cond000] AS [cnd] INNER JOIN [dbo].[CondItems000] AS [cndi]
	ON  [cnd].[GUID] = [cndi].[ParentGUID]
###########################################################################
CREATE PROCEDURE GetBillList
	 @StartDate	[DATETIME] = '1/1/1980',
	 @EndDate	[DATETIME] = '1/1/2010',
	 @Guid AS [UNIQUEIDENTIFIER] = NULL
AS
	DECLARE @Sql NVARCHAR(max),@Criteria NVARCHAR(max)
	SET @Criteria = ''
	SET @Sql = 'SELECT ' 
	IF (ISNULL(@Guid,0X00) <> 0X00)
		SET @Sql = @Sql + '[biGuid]'
	ELSE
		SET @Sql = @Sql + ' DISTINCT [buGuid] '
	SET @Sql = @Sql + 'FROM [vwBuBi_Address] WHERE [buDate] BETWEEN ' + '''' + CAST ( DATEPART(mm,@StartDate) AS NVARCHAR(2)) + '/' + CAST ( DATEPART(dd,@StartDate) AS NVARCHAR(2)) + '/' + CAST ( DATEPART(yyyy,@StartDate) AS NVARCHAR(4)) + '''' +  ' AND ' +  '''' + CAST ( DATEPART(mm,@EndDate) AS NVARCHAR(2)) + '/' + CAST ( DATEPART(dd,@EndDate) AS NVARCHAR(2)) + '/' + CAST ( DATEPART(yyyy,@EndDate) AS NVARCHAR(4)) + ''''
	SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@Guid,DEFAULT)
	IF @Criteria <> ''
		SET @Criteria = 'AND (' + @Criteria + ')'
	SET @Sql = @Sql + @Criteria
	EXEC (@Sql)
--EXEC GetBillList
###########################################################################
CREATE FUNCTION fnCondIsUsed(@guid UNIQUEIDENTIFIER)   
RETURNS BIT  
AS  
BEGIN
    IF EXISTS (SELECT * FROM (select custcondguid AS G from sm000 union all select matcondguid from sm000) A WHERE G = @guid)    
		RETURN 1   
	RETURN 0  
END
###########################################################################
CREATE FUNCTION fnGetEntryConditionStr
(
	@ViewName AS NVARCHAR(256) = NULL,
	@Guid AS UNIQUEIDENTIFIER = NULL,
	@CurrGuid UNIQUEIDENTIFIER = 0x00
)  
	RETURNS [NVARCHAR](max)  
AS 
BEGIN  
	DECLARE   
		@c CURSOR,   
		@SearchStr	[NVARCHAR](100),   
		@FieldNum	[INT],   
		@CondType	[INT],   
		@Link		[INT],   
		@FieldStr	[NVARCHAR](300),   
		@CondStr	[NVARCHAR](200),   
		@LinkStr	[NVARCHAR](150),   
		@SQL		[NVARCHAR](max),   
		@Criteria	[NVARCHAR](max),   
		@Curr		[Bit],  
		@HaveCustomFld	BIT -- to check existing Custom Fields , it must = 1   
	
	SET @HaveCustomFld = 0   
	
	DECLARE @I INT, @T INT, @D NVARCHAR(2), @M NVARCHAR(2), @Y NVARCHAR(5)   
	
	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT SearchStr, FieldNum, CondType, Link 
		FROM vwConditions 
		WHERE cndType = 70 AND cndGuid = @Guid
		ORDER BY Number
		
	OPEN @c FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link
	Set @Criteria = ''   
	SET @Curr = 0   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		-- Study FieldNum   
		IF (@FieldNum = 1000)   
		BEGIN    
			SET @FieldStr = '('   
			SET @CondStr = ''   
			SET @LinkStr = ''    
		END   
		ELSE IF (@FieldNum = 1001)   
		BEGIN   
			SET @FieldStr = ')'   
			SET @CondStr = ''   
			IF @Link = 0   
				SET @LinkStr = ' AND '   
			ELSE IF @Link = 1   
				SET @LinkStr = '  OR '   
			ELSE   
				SET @LinkStr = ''    
		END   
		ELSE   
		BEGIN   
			IF @FieldNum >= 2000 AND @HaveCustomFld = 0   
				SET @HaveCustomFld = 1  
				
			IF @ViewName IS NOT NULL   
				SET @FieldStr = (CASE @FieldNum    
									
										WHEN 0  -- currency code
										THEN @ViewName +'.[ceCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE CODE '   
										
										WHEN 1  -- currency name
										THEN @ViewName +'.[ceCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE Name '   
										
										WHEN 2  -- notes
										THEN @ViewName +'.[ceNotes]'
										
										WHEN 3 -- added value 
										THEN @ViewName +'.[ceAddedValue]' 

									
									ELSE   
									-- Custom Field  Condition	   
										dbo.fnGetCustFld(@FieldNum, @CondType, 'py000')   
									END)   
			ELSE   
				SET @FieldStr = (CASE @FieldNum     
									
										WHEN 0  -- currency code
										THEN @ViewName +'[ceCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE CODE '   
										
										WHEN 1  -- currency name
										THEN @ViewName +'[ceCurrencyPtr] IN (SELECT [GUID] FROM [vcmy] WHERE Name '   
										
										WHEN 2  -- notes
										THEN @ViewName +'[ceNotes]'

										WHEN 3 -- added value 
										THEN @ViewName +'[ceAddedValue]' 

									
									ELSE   
									-- Custom Field  Condition	   
										dbo.fnGetCustFld(@FieldNum, @CondType, 'py000')   
									END)   
			 	    
			IF (@FieldNum = 1) OR (@FieldNum = 0)   
				SET @Curr = 1   
			ELSE   
				SET @Curr = 0   
			-- Study Condition   
			--IF ((@CondType >= 6) AND ((@FieldNum = 3) OR (@FieldNum = 4)) )   
			--BEGIN   
			--	SET @I = 2   
			--	SET @T = 1   
			--	SET @D = ''   
			--	SET @M = ''   
			--	SET @Y = ''   
			--	WHILE @I < 15   
			--	BEGIN   
			--		IF SUBSTRING(@SearchStr,@I,1) = '-' OR SUBSTRING(@SearchStr,@I,1) = ''   
			--		BEGIN   
			--			IF (@D = '')   
			--			BEGIN   
			--				SET @D = SUBSTRING(@SearchStr,@T,@I -@T)   
			--				SET @T = @I + 1   
			--			END   
			--			ELSE if (@m = '')   
			--			BEGIN   
			--				SET @m = SUBSTRING(@SearchStr,@T,@I -@T)    
			--				SET @T = @I + 1   
			--			END   
			--			ELSE   
			--			BEGIN   
			--				SET @Y = SUBSTRING(@SearchStr,@T,@I -@T)    
			--				BREAK   
			--			END   
						   
			--		END   
			--		SET @I = @I + 1   
			--	END 
			--	IF (@m BETWEEN '1' AND '12') AND (@D BETWEEN '1' AND '31') 
			--		SET @SearchStr =   @m + '/' +  @D + '/' + @Y   
			--	ELSE 
			--		SET @SearchStr =  '1/1/1980'  
				  
			--END   
			  
			IF @FieldNum >= 2000 AND @HaveCustomFld = 1		   
			-- Custom Field  Condition   
			BEGIN   
				SET @CondStr = dbo.fnGetCustFldCondStr(@FieldNum ,@CondType ,@SearchStr , 'py000' )   
			END    
			ELSE   
			Begin  
				SET @CondStr = (CASE @CondType   
				
									WHEN 0  -- contains
									THEN ' LIKE ''%' + @SearchStr + '%'''   
									
									WHEN 1  -- not contain
									THEN ' NOT LIKE ''%' + @SearchStr + '%'''   
									
									WHEN 2  -- starts with
									THEN ' LIKE ''' + @SearchStr + '%'''   
									
									WHEN 3  -- not start with
									THEN ' NOT LIKE ''' + @SearchStr + '%'''   
									
									WHEN 4  -- ends with
									THEN ' LIKE ''%' + @SearchStr + ''''   
									
									WHEN 5  -- not end with
									THEN ' NOT LIKE ''%' + @SearchStr + ''''   
									
									WHEN 6  -- equals to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' = ''' + @SearchStr + '''' ELSE*/ ' = ' + @SearchStr --END   
									
									WHEN 7  -- not equal to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <> ''' + @SearchStr + '''' ELSE*/ ' <> ' + @SearchStr --END   
									
									WHEN 8  -- greater than
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' > ''' + @SearchStr + '''' ELSE*/ ' > ' + @SearchStr --END   
									
									WHEN 9  -- greater than or equal to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN' >= ''' + @SearchStr + '''' ELSE*/ ' >= ' + @SearchStr --END   
									
									WHEN 10 -- less than
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' < ''' + @SearchStr + '''' ELSE*/ ' < ' + @SearchStr --END   
									
									WHEN 11 -- less than or equal to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <= ''' + @SearchStr + '''' ELSE*/ ' <= ' + @SearchStr --END   
									
								END)   
			END  
			IF @Curr > 0   
			BEGIN   
				SET @CondStr = @CondStr + ')'   
			END   
				   
			IF @Link = 0   
				SET @LinkStr = ' AND '   
			ELSE IF @Link = 1   
				SET @LinkStr = '  OR '   
			ELSE   
				SET @LinkStr = ''    
		END		
		   
		SET @Criteria = @Criteria + @FieldStr + @CondStr + @LinkStr   
		FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link   
	END   
	CLOSE @c   
	DEALLOCATE @c   
	
	-- truncate the last @LinkStr   
	DECLARE @LastLinkStr [NVARCHAR](4)    
	SET @LastLinkStr = RIGHT(@Criteria,  4)	
	IF @Criteria <> '' AND (@LastLinkStr = 'AND ' OR @LastLinkStr = ' OR ')   
		SET @Criteria = LEFT(@Criteria, LEN(@Criteria) - 4)   
		
	IF @HaveCustomFld > 0   
		SET @Criteria = @Criteria + '<<>>'
		
	RETURN @Criteria   
END
###########################################################################
CREATE FUNCTION fnGetPKConditionStr
(
	@ViewName AS NVARCHAR(256) = NULL,
	@Guid AS UNIQUEIDENTIFIER = NULL
)  
	RETURNS [NVARCHAR](max)  
AS 
BEGIN  
	DECLARE   
		@c CURSOR,   
		@SearchStr	[NVARCHAR](100),   
		@FieldNum	[INT],   
		@CondType	[INT],   
		@Link		[INT],   
		@FieldStr	[NVARCHAR](300),   
		@CondStr	[NVARCHAR](200),   
		@LinkStr	[NVARCHAR](150),   
		@SQL		[NVARCHAR](max),   
		@Criteria	[NVARCHAR](max),   
		@Curr		[Bit],  
		@HaveCustomFld	BIT -- to check existing Custom Fields , it must = 1   
	
	SET @HaveCustomFld = 0   
	
	DECLARE @I INT, @T INT, @D NVARCHAR(2), @M NVARCHAR(2), @Y NVARCHAR(5)   
	
	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT SearchStr, FieldNum, CondType, Link 
		FROM vwConditions 
		WHERE cndType = 90 AND cndGuid = @Guid
		ORDER BY Number
		
	OPEN @c FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link
	Set @Criteria = ''   
	SET @Curr = 0   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		-- Study FieldNum   
		IF (@FieldNum = 1000)   
		BEGIN    
			SET @FieldStr = '('   
			SET @CondStr = ''   
			SET @LinkStr = ''    
		END   
		ELSE IF (@FieldNum = 1001)   
		BEGIN   
			SET @FieldStr = ')'   
			SET @CondStr = ''   
			IF @Link = 0   
				SET @LinkStr = ' AND '   
			ELSE IF @Link = 1   
				SET @LinkStr = '  OR '   
			ELSE   
				SET @LinkStr = ''    
		END   
		ELSE   
		BEGIN   
			IF @FieldNum >= 2000 AND @HaveCustomFld = 0   
				SET @HaveCustomFld = 1  
				
			IF @ViewName IS NOT NULL   
				SET @FieldStr = (CASE @FieldNum    
									
										WHEN 0  -- Name
										THEN @ViewName +'.[ContainerGUID] IN (SELECT [GUID] FROM [Containers000] WHERE Name '   
										

									
									ELSE   
									-- Custom Field  Condition	   
										dbo.fnGetCustFld(@FieldNum, @CondType, 'packingLists000')   
									END)   
			ELSE   
				SET @FieldStr = (CASE @FieldNum     
									
										WHEN 0  -- Name
										THEN @ViewName +'[ContainerGUID] IN (SELECT [GUID] FROM [Containers000] WHERE Name '   
										
									

									
									ELSE   
									-- Custom Field  Condition	   
										dbo.fnGetCustFld(@FieldNum, @CondType, 'packingLists000')   
									END)   
			 	    
			IF (@FieldNum = 1) OR (@FieldNum = 0)   
				SET @Curr = 1   
			ELSE   
				SET @Curr = 0   
		
			  
			IF @FieldNum >= 2000 AND @HaveCustomFld = 1		   
			-- Custom Field  Condition   
			BEGIN   
				SET @CondStr = dbo.fnGetCustFldCondStr(@FieldNum ,@CondType ,@SearchStr , 'packingLists000' )   
			END    
			ELSE   
			Begin  
				SET @CondStr = (CASE @CondType   
				
									WHEN 0  -- contains
									THEN ' LIKE ''%' + @SearchStr + '%'''   
									
									WHEN 1  -- not contain
									THEN ' NOT LIKE ''%' + @SearchStr + '%'''   
									
									WHEN 2  -- starts with
									THEN ' LIKE ''' + @SearchStr + '%'''   
									
									WHEN 3  -- not start with
									THEN ' NOT LIKE ''' + @SearchStr + '%'''   
									
									WHEN 4  -- ends with
									THEN ' LIKE ''%' + @SearchStr + ''''   
									
									WHEN 5  -- not end with
									THEN ' NOT LIKE ''%' + @SearchStr + ''''   
									
									WHEN 6  -- equals to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' = ''' + @SearchStr + '''' ELSE*/ ' = ' + @SearchStr --END   
									
									WHEN 7  -- not equal to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <> ''' + @SearchStr + '''' ELSE*/ ' <> ' + @SearchStr --END   
									
									WHEN 8  -- greater than
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' > ''' + @SearchStr + '''' ELSE*/ ' > ' + @SearchStr --END   
									
									WHEN 9  -- greater than or equal to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN' >= ''' + @SearchStr + '''' ELSE*/ ' >= ' + @SearchStr --END   
									
									WHEN 10 -- less than
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' < ''' + @SearchStr + '''' ELSE*/ ' < ' + @SearchStr --END   
									
									WHEN 11 -- less than or equal to
									THEN /*CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <= ''' + @SearchStr + '''' ELSE*/ ' <= ' + @SearchStr --END   
									
								END)   
			END  
			IF @Curr > 0   
			BEGIN   
				SET @CondStr = @CondStr + ')'   
			END   
				   
			IF @Link = 0   
				SET @LinkStr = ' AND '   
			ELSE IF @Link = 1   
				SET @LinkStr = '  OR '   
			ELSE   
				SET @LinkStr = ''    
		END		
		   
		SET @Criteria = @Criteria + @FieldStr + @CondStr + (CASE WHEN @FieldNum  = 0 AND ( @CondType in (1,3,5))
					
										THEN 'OR '+ @ViewName +'.[ContainerGUID] = 0x0 ' ELSE '' END ) +@LinkStr   
		FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link   
	END   
	CLOSE @c   
	DEALLOCATE @c   
	
	-- truncate the last @LinkStr   
	DECLARE @LastLinkStr [NVARCHAR](4)    
	SET @LastLinkStr = RIGHT(@Criteria,  4)	
	IF @Criteria <> '' AND (@LastLinkStr = 'AND ' OR @LastLinkStr = ' OR ')   
		SET @Criteria = LEFT(@Criteria, LEN(@Criteria) - 4)   
		
	IF @HaveCustomFld > 0   
		SET @Criteria = @Criteria + '<<>>'
	RETURN @Criteria   
END
############################################################################
CREATE  PROCEDURE prcPackingsList
	@CondGuid UNIQUEIDENTIFIER = 0x00   
AS
	SET NOCOUNT ON    
	    
	DECLARE    
		@HasCond INT,    
		@Criteria NVARCHAR(max),    
		@SQL NVARCHAR(max),    
		@HaveCFldCondition	BIT -- to check existing Custom Fields , it must = 1 
	  
	SET @SQL = ' SELECT pk.Guid as pkGuid FROM PackingLists000 pk'   
	
    
	IF ISNULL(@CondGUID, 0X00) <> 0X00    
	BEGIN    
		  
		SET @Criteria = dbo.fnGetPKConditionStr('pk', @CondGUID)  
    
		IF @Criteria <> ''    
		BEGIN    
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields
			BEGIN
				SET @HaveCFldCondition = 1
				SET @Criteria = REPLACE(@Criteria, '<<>>', '')   
			END
				
			SET @Criteria = '(' + @Criteria + ')' 
		END  
	END    
	ELSE    
		SET @Criteria = ''    

	IF @HaveCFldCondition > 0    
	Begin    
		Declare @CF_Table NVARCHAR(255)    
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'PackingLists000') 	   
		SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON pk.Guid = ' + @CF_Table + '.Orginal_Guid '    
	End

	SET @SQL = @SQL + '	WHERE 1 = 1 '    
	IF @Criteria <> ''    
		SET @SQL = @SQL + ' AND (' + @Criteria + ')'

	EXEC (@SQL) 
###########################################################################
CREATE FUNCTION fnSEG_GetMaterialElements(@MatGUID UNIQUEIDENTIFIER)
RETURNS @Table TABLE(Number INT, Code NVARCHAR(500), Name NVARCHAR(500))
AS 
BEGIN 

INSERT INTO @Table
SELECT 
	MSM.Number, SE.Code, SE.Name
FROM 
					MaterialElements000 AS ME
					INNER JOIN SegmentElements000 AS SE ON [SE].[Id] = [ME].[ElementId]
					INNER JOIN Segments000 AS S ON [S].[Id] = [SE].[SegmentId]
					INNER JOIN MaterialsSegmentsManagement000 AS MSM ON [MSM].[SegmentId] = [S].[Id]
WHERE [ME].[MaterialId] = @MatGUID
RETURN
END
############################################################################
#END
