#################################################################################### 
CREATE function fnGetStoreConditionString(
	@GUID		UNIQUEIDENTIFIER,
	@viewName	NVARCHAR = ''
)
RETURNS [NVARCHAR](max)
AS BEGIN
	DECLARE 
			@Cursor		CURSOR,
			@SearchStr	[NVARCHAR](100),   
			@FieldNum	[INT],   
			@CondType	[INT],   
			@Link		[INT],   
			@FieldStr	[NVARCHAR](250),   
			@CondStr	[NVARCHAR](200),   
			@LinkStr	[NVARCHAR](150),   
			@Criteria	[NVARCHAR](max)
			
	IF ISNULL(@ViewName, '') != '' 
		SET @ViewName = @ViewName + '.' 
	ELSE 
		SET @ViewName = '' 
	
	SET @Cursor = CURSOR FAST_FORWARD FOR 
				  SELECT 
					SearchStr, FieldNum, CondType, Link 
				  FROM 
					vwConditions 
				  WHERE 
					cndGUID = @Guid
				  ORDER BY 
					Number
	
	OPEN @Cursor FETCH FROM @Cursor INTO @SearchStr, @FieldNum, @CondType, @Link   		
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		SET @FieldStr = (
			CASE @FieldNum    
				WHEN 0  THEN @ViewName + '( '
				WHEN 1  THEN @ViewName + ') '
				WHEN 2  THEN @ViewName + 'st.stCODE '
				WHEN 3  THEN @ViewName + 'st.stNAME '
				WHEN 4  THEN @ViewName + 'st.stLATINNAME '
				WHEN 5  THEN @ViewName + 'Parent.stName '   
				WHEN 6  THEN @ViewName + 'st.stAccount '   
				WHEN 7  THEN @ViewName + 'st.stAddress '   
				WHEN 8  THEN @ViewName + 'st.stKeeper ' 
				WHEN 9  THEN @ViewName + 'st.stNotes ' 
			END
		)
		   
		SET @CondStr = (
			CASE 
				WHEN @FieldNum IN (0, 1) THEN ''
				ELSE
					CASE @CondType   
						WHEN 0  THEN ' LIKE ''%'	 + @SearchStr + '%'''   
						WHEN 1  THEN ' NOT LIKE ''%' + @SearchStr + '%'''   
						WHEN 2  THEN ' LIKE '''		 + @SearchStr + '%'''   
						WHEN 3  THEN ' NOT LIKE '''	 + @SearchStr + '%'''   
						WHEN 4  THEN ' LIKE ''%'	 + @SearchStr + ''''   
						WHEN 5  THEN ' NOT LIKE ''%' + @SearchStr + ''''   
						WHEN 6  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' = '''  + @SearchStr + '''' ELSE ' = '  + @SearchStr END   
						WHEN 7  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <> ''' + @SearchStr + '''' ELSE ' <> ' + @SearchStr END   
						WHEN 8  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' > '''  + @SearchStr + '''' ELSE ' > '  + @SearchStr END   
						WHEN 9  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' >= ''' + @SearchStr + '''' ELSE ' >= ' + @SearchStr END   
						WHEN 10 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' < '''  + @SearchStr + '''' ELSE ' < '  + @SearchStr END   
						WHEN 11 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <= ''' + @SearchStr + '''' ELSE ' <= ' + @SearchStr END   
					END
			END
		)   
				 
		SET @LinkStr = CASE 
							WHEN @FieldNum = 0 THEN ''
							ELSE
								CASE @Link 
									WHEN 0 THEN ' AND '    
									WHEN 1 THEN ' OR '    
									ELSE ''     
								END
						END

		SET @Criteria = ISNULL(@Criteria, '') + @FieldStr + @CondStr + @LinkStr   
		FETCH FROM @Cursor INTO @SearchStr, @FieldNum, @CondType, @Link
	END	
	CLOSE @Cursor
	DEALLOCATE @Cursor
	
	IF SUBSTRING(@Criteria, LEN(@Criteria) - 2, LEN(@Criteria)) LIKE '%AND%' OR SUBSTRING(@Criteria, LEN(@Criteria) - 2, LEN(@Criteria)) LIKE '%OR%'
		RETURN SUBSTRING(@Criteria, 0, LEN(@Criteria) - 2)
		
	RETURN 	@Criteria
END
####################################################################################
#END