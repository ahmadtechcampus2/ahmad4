###########################################################################
CREATE FUNCTION fnGetCustDefPeiceCond(@CondType [INT],@SearchStr NVARCHAR(MAX)) 
	RETURNS [NVARCHAR](300)
AS 
BEGIN 
	DECLARE @CondStr NVARCHAR(200),@c CURSOR,@Id [INT],@I [INT]
	
	DECLARE @Tbl TABLE (ID INT,[Name] NVARCHAR(100) COLLATE ARABIC_CI_AI,Lang INT,id2 INT)
	DECLARE @Tbl2 TABLE (ID INT,[Name] NVARCHAR(100) COLLATE ARABIC_CI_AI,Lang INT)
	INSERT INTO @Tbl (ID,[Name],Lang)
		SELECT [Number],[Asc1],0 FROM mc000 WHERE TYPE = 8 AND [Asc1] <> '' AND NUMBER BETWEEN 1095 AND 1100
		UNION ALL
		SELECT [Number],[Asc2],1 FROM mc000 WHERE TYPE = 8 AND [Asc2] <> '' AND NUMBER BETWEEN 1095 AND 1100
	INSERT INTO @Tbl2 VALUES(1095 ,'«·Ã„·…' ,0)
	INSERT INTO @Tbl2 VALUES(1096 ,'‰’› «·Ã„·…' ,0)
	INSERT INTO @Tbl2 VALUES(1097 ,'«·„›—ﬁ' ,0)
	INSERT INTO @Tbl2 VALUES(1098 ,'«·„Ê“⁄' ,0)
	INSERT INTO @Tbl2 VALUES(1099 ,'«· ’œÌ—' ,0)
	INSERT INTO @Tbl2 VALUES(1100 ,'«·„” Â·ﬂ' ,0)
	INSERT INTO @Tbl2 VALUES(1095 ,'Whole' ,1)
	INSERT INTO @Tbl2 VALUES(1096 ,'Special' ,1)
	INSERT INTO @Tbl2 VALUES(1097 ,'Retail' ,1)
	INSERT INTO @Tbl2 VALUES(1098 ,'Distributor' ,1)
	INSERT INTO @Tbl2 VALUES(1099 ,'Export' ,1)
	INSERT INTO @Tbl2 VALUES(1100 ,'End User' ,1)
	INSERT INTO @Tbl (ID,[Name],Lang) SELECT ID,[Name],Lang FROM @Tbl2 WHERE Lang = 0 AND [Id] NOT IN (SELECT [Id] FROM @Tbl WHERE  Lang = 0)
	INSERT INTO @Tbl (ID,[Name],Lang) SELECT ID,[Name],Lang FROM @Tbl2 WHERE Lang = 1 AND [Id] NOT IN (SELECT [Id] FROM @Tbl WHERE  Lang = 1)
	UPDATE	@Tbl SET ID2 = POWER(2,ID - 1095 + 2) WHERE ID = 1095 OR	   ID = 1096  OR ID = 1100
	UPDATE	@Tbl SET ID2 = POWER(2,4) WHERE ID = 1099
	UPDATE	@Tbl SET ID2 = POWER(2,5) WHERE ID = 1098
	UPDATE	@Tbl SET ID2 =  POWER(2,6) WHERE ID = 1097
	
	DECLARE @Tbl3 TABLE (ID INT)
	IF @CondType = 0
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] LIKE '%' + @SearchStr + '%'
	ELSE IF @CondType = 1	
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] NOT LIKE '%' + @SearchStr + '%'
	ELSE IF @CondType = 2	
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] LIKE  @SearchStr + '%'
	ELSE IF @CondType = 3	
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name]  NOT LIKE  + @SearchStr + '%'
	ELSE IF @CondType = 4	
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] LIKE '%' + @SearchStr
	ELSE IF @CondType = 5
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] NOT LIKE '%' + @SearchStr 
	ELSE IF @CondType = 6
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] = @SearchStr 
	ELSE IF @CondType = 7
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] <> @SearchStr  
	ELSE IF @CondType = 8
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] > @SearchStr  
	ELSE IF @CondType = 9
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] >= @SearchStr
	ELSE IF @CondType = 10
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] < @SearchStr 
	ELSE IF @CondType = 11
		INSERT INTO @Tbl3 SELECT DISTINCT ID2 FROM @Tbl WHERE [Name] <= @SearchStr 
	SELECT @i = COUNT(*) FROM @Tbl3
	IF  @i = 0 
		SET @CondStr = '(1 = 1) '
	ELSE
	BEGIN
		SET @c = CURSOR FAST_FORWARD FOR SELECT [ID] FROM @Tbl3
		OPEN @c FETCH FROM @c INTO @Id
		SET @CondStr = '('
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @CondStr <> '('
				SET @CondStr = @CondStr + ' OR '
			SET @CondStr = @CondStr + ' [cudefPrice] = ' + CAST( (@Id) AS NVARCHAR(3))
			FETCH FROM @c INTO @Id
		END
		SET @CondStr = @CondStr + ' ) '
		CLOSE @c
		DEALLOCATE @c
	END
	RETURN @CondStr
END
###########################################################################
CREATE FUNCTION fnGetCustConditionStr(@Guid AS [UNIQUEIDENTIFIER] = NULL)
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
		@SearchStr [NVARCHAR](300),
		@FieldNum [INT],
		@CondType [INT],
		@Link     [INT],
		@FieldStr [NVARCHAR](200),
		@CondStr  [NVARCHAR](100),
		@LinkStr  [NVARCHAR](100),
		@SQL [NVARCHAR](max),
		@Criteria [NVARCHAR](max),
		@HaveCustomFld	BIT -- to check existing Custom Fields , it must = 1
	SET @HaveCustomFld = 0

	SET @c = CURSOR FAST_FORWARD FOR  
				SELECT [SearchStr], [FieldNum], [CondType], [Link] FROM [dbo].[vwConditions] WHERE [cndGUID] = @Guid AND [cndType] =  23 ORDER BY  [Number] 
				

	OPEN @c FETCH FROM @c INTO @SearchStr, @FieldNum, @CondType, @Link

	Set @Criteria = ''

	WHILE @@FETCH_STATUS = 0
	BEGIN
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
					WHEN 0  THEN '[cuCustomerName]'
					WHEN 1  THEN '[cuAddress]'
					WHEN 2  THEN '[cuNationality]'
					WHEN 3  THEN '[cuPhone1]'
					WHEN 4  THEN '[cuPhone2]'
					WHEN 5  THEN '[cuFax]'
					WHEN 6  THEN '[cuTelex]'
					WHEN 7  THEN '[cuNotes]'
					WHEN 8  THEN '[cuLatinName]'
					WHEN 9  THEN '[cuEMail]'
					WHEN 10  THEN '[cuHomePage]'
					WHEN 11  THEN '[cuPrefix]'
					WHEN 12  THEN '[cuSuffix]'
					WHEN 13  THEN '[cuArea]'
					WHEN 14  THEN '[cuCity]'
					WHEN 15  THEN '[cuStreet]'
					WHEN 16  THEN '[cuPOBox]'
					WHEN 17  THEN '[cuZipCode]'
					WHEN 18  THEN '[cuMobile]'
					WHEN 19  THEN '[cuPager]'
					WHEN 20  THEN '[cuCountry]'
					WHEN 21  THEN '[cuUserFld1]'
					WHEN 22  THEN '[cuUserFld2]'
					WHEN 23  THEN '[cuUserFld3]'
					WHEN 24  THEN '[cuUserFld4]'
					WHEN 25  THEN '[cuCertificate]' 
					WHEN 26  THEN '[cuJob]' 
					WHEN 27  THEN '[cuJobCategory]' 
					WHEN 28  THEN '[cuGender]' 
					WHEN 29  THEN '[cuHobbies]'
					WHEN 30  THEN '(SELECT [acCode] FROM [vwAc] AS [ac] WHERE [acGuid] = [cuAccount])'  
					WHEN 31  THEN  [dbo].[fnGetCustDefPeiceCond](@CondType,@SearchStr ) 
					WHEN 32  THEN '[cuDiscRatio]'
					ELSE
						-- Custom Field  Condition	
						dbo.fnGetCustFld(@FieldNum, @CondType, 'cu000')
					END)
			-- Study Condition
				IF @FieldNum >= 2000 AND @HaveCustomFld = 1		
					-- Custom Field  Condition
					BEGIN
						SET @CondStr=  dbo.fnGetCustFldCondStr(@FieldNum ,@CondType ,@SearchStr , 'cu000' )
					END
				ELSE			
					BEGIN 						
						SET @CondStr = (CASE @CondType
								WHEN 0  THEN ' LIKE ''%' + @SearchStr + '%'''
								WHEN 1  THEN ' NOT LIKE ''%' + @SearchStr + '%'''
								WHEN 2  THEN ' LIKE ''' + @SearchStr + '%'''
								WHEN 3  THEN ' NOT LIKE ''' + @SearchStr + '%'''
								WHEN 4  THEN ' LIKE ''%' + @SearchStr + ''''
								WHEN 5  THEN ' NOT LIKE ''%' + @SearchStr + ''''
								WHEN 6  THEN CASE WHEN @FieldNum < 35 THEN ' =  ''' + @SearchStr + '''' ELSE ' =  ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
								WHEN 7  THEN CASE WHEN @FieldNum < 35 THEN ' <> ''' + @SearchStr + '''' ELSE ' <> ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
								WHEN 8  THEN CASE WHEN @FieldNum < 35 THEN ' >  ''' + @SearchStr + '''' ELSE ' >  ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
								WHEN 9  THEN CASE WHEN @FieldNum < 35 THEN ' >= ''' + @SearchStr + '''' ELSE ' >= ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
								WHEN 10 THEN CASE WHEN @FieldNum < 35 THEN ' <  ''' + @SearchStr + '''' ELSE ' <  ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
								WHEN 11 THEN CASE WHEN @FieldNum < 35 THEN ' <= ''' + @SearchStr + '''' ELSE ' <= ' + CASE ISNUMERIC(@SearchStr) WHEN 1 THEN @SearchStr ELSE ' -1 ' END END
								END)
					END
				-- Study link:
			IF @FieldNum = 31
				SET @CondStr = ' '
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

	-- For Linker exists in End of Criteria 
	DECLARE @Left [NVARCHAR](4) 
	SET @Left = RIGHT(@Criteria,  4)
	-- truncate the last @LinkStr
	IF @Criteria <> '' AND (@Left = 'AND ' OR @Left = ' OR ')
		SET @Criteria = LEFT(@Criteria, LEN(@Criteria) - 3)

	IF @HaveCustomFld > 0
		SET @Criteria = @Criteria + '<<>>'
	RETURN @Criteria
END

###########################################################################
#END