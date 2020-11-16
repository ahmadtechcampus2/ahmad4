#########################################################################
CREATE FUNCTION fnGetOrderConditionStr (@ViewName AS [NVARCHAR](256) = NULL,@Guid AS [UNIQUEIDENTIFIER] = NULL,@CurrGuid UNIQUEIDENTIFIER = 0x00)  
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
		@Curr		[Bit],  
		@HaveCustomFld	BIT ,-- to check existing Custom Fields , it must = 1   
		@HaveAdditionInfo bit -- to check existing Addition Info Of Order , it must = 1   
	SET @HaveCustomFld = 0 
	SET @HaveAdditionInfo = 0  
	DECLARE @I INT,@T INT,@D NVARCHAR(2) ,@M NVARCHAR(2) ,@Y NVARCHAR(5)   
	SET @c = CURSOR FAST_FORWARD FOR SELECT [SearchStr], [FieldNum], [CondType], [Link] FROM [dbo].[vwConditions] WHERE [cndGUID] = @Guid AND [cndType] = 60 ORDER BY  [Number]    
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
			IF @FieldNum >=22 AND @FieldNum <=30 AND @HaveAdditionInfo = 0
				SET @HaveAdditionInfo = 1
 		
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
									WHEN 8  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix]('+ @ViewName + '.biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''', [buDate])' ELSE 'STR([dbo].[fnCurrency_fix]('+ @ViewName + '.biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END   
									WHEN 9  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix]('+ @ViewName + '.biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix]('+ @ViewName + '.biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END   
									WHEN 10  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix]('+ @ViewName + '.biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix]('+ @ViewName + '.biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END   
									WHEN 11  THEN CASE WHEN @CondType > 5 THEN @ViewName + '.[BuSalesManPtr]' ELSE 'STR(' + @ViewName + '.[BuSalesManPtr])' END   
									WHEN 12  THEN CASE WHEN @CondType > 5 THEN @ViewName + '.[BuVendor]' ELSE 'STR('+ @ViewName + '.[BuVendor])' END   
									WHEN 13  THEN	' ISNULL((SELECT co2.Code FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '    
									WHEN 14  THEN	' ISNULL((SELECT co2.Name FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '    
									WHEN 15  THEN @ViewName +'.[biPrice]'
									WHEN 18  THEN @ViewName +'.[buTextFld1]'   
									WHEN 19  THEN @ViewName +'.[buTextFld2]'   
									WHEN 20  THEN @ViewName +'.[buTextFld3]'   
									WHEN 21  THEN CASE WHEN @CondType > 5 THEN ' CAST(CASE ISDATE(' + @ViewName +'.[buTextFld4]) WHEN  1  THEN ' + @ViewName +'.buTextFld4 ELSE '+ '''1-1-1980'''+ ' END AS DATETIME)'ELSE ' ' + @ViewName +'.[buTextFld4] ' END
									WHEN 22  THEN  'OrAddInfo.ORDERSHIPCONDITION'
									WHEN 23  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SSDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SSDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SSDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SSDATE) AS NVARCHAR(4))' END   
									WHEN 24  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SADATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SADATE) AS NVARCHAR(4))' END   
									WHEN 25  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SDDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SDDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SDDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SDDATE) AS NVARCHAR(4))' END   
									WHEN 26  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SPDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SPDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SPDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SPDATE) AS NVARCHAR(4))' END   
									WHEN 27  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.ASDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.ASDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.ASDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.ASDATE) AS NVARCHAR(4))' END   
									WHEN 28  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.AADATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.AADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.AADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.AADATE) AS NVARCHAR(4))' END   
									WHEN 29  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.ADDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.ADDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.ADDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.ADDATE) AS NVARCHAR(4))' END   
									WHEN 30  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.APDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.APDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.APDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.APDATE) AS NVARCHAR(4))' END   
									WHEN 31  THEN @ViewName + '.[buNumber]'
   
									ELSE   
									 --Custom Field  Condition	   
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
									WHEN 8  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix](biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix](biBonusDisc, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END   
									WHEN 9  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix](biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''', [buDate])' ELSE 'STR([dbo].[fnCurrency_fix](biDiscount, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END   
									WHEN 10  THEN CASE WHEN @CondType > 5 THEN '[dbo].[fnCurrency_fix](biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate])' ELSE 'STR([dbo].[fnCurrency_fix](biExtra, [biCurrencyPtr], [biCurrencyVal], ''' + CAST(@CurrGuid AS NVARCHAR(36)) +''' ,[buDate]))' END   
									WHEN 11  THEN CASE WHEN @CondType > 5 THEN '[BuSalesManPtr]' ELSE 'STR([BuSalesManPtr])' END   
									WHEN 12  THEN CASE WHEN @CondType > 5 THEN '[BuVendor]' ELSE 'STR([BuVendor])' END   
									WHEN 13  THEN	' ISNULL((SELECT co2.Code FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '    
									WHEN 14  THEN	' ISNULL((SELECT co2.Name FROM co000 co2 WHERE co2.GUID = biCostPtr),'''') '    
									WHEN 15  THEN '[biPrice]'
									WHEN 17  THEN  'buNotes'
									WHEN 18  THEN '[buTextFld1]'   
									WHEN 19  THEN '[buTextFld2]'   
									WHEN 20  THEN '[buTextFld3]'   
									WHEN 21  THEN CASE WHEN @CondType > 5 THEN ' CAST(CASE ISDATE([buTextFld4]) WHEN  1  THEN buTextFld4 ELSE '+ '''1-1-1980'''+ ' END AS DATETIME)'ELSE ' [buTextFld4] ' END
									WHEN 22  THEN  'OrAddInfo.ORDERSHIPCONDITION'
									WHEN 23  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SSDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SSDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SSDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SSDATE) AS NVARCHAR(4))' END   
									WHEN 24  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SADATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SADATE) AS NVARCHAR(4))' END   
									WHEN 25  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SDDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SDDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SDDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SDDATE) AS NVARCHAR(4))' END   
									WHEN 26  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.SPDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.SPDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.SPDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.SPDATE) AS NVARCHAR(4))' END   
									WHEN 27  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.ASDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.ASDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.ASDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.ASDATE) AS NVARCHAR(4))' END   
									WHEN 28  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.AADATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.AADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.AADATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.AADATE) AS NVARCHAR(4))' END   
									WHEN 29  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.ADDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.ADDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.ADDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.ADDATE) AS NVARCHAR(4))' END   
									WHEN 30  THEN CASE WHEN @CondType > 5 THEN 'OrAddInfo.APDATE' ELSE 'CAST (DATEPART(dd,OrAddInfo.APDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(mm,OrAddInfo.APDATE) AS NVARCHAR(2)) +' +'''' + '-' + '''' + ' + CAST (DATEPART(yy,OrAddInfo.APDATE) AS NVARCHAR(4))' END   
									WHEN 31  THEN '[buNumber]'
									
									ELSE   
									-- Custom Field  Condition	   
										dbo.fnGetCustFld(@FieldNum, @CondType, 'bu000')   
									END)   
			 	    
			IF (@FieldNum = 1) OR (@FieldNum = 0)   
				SET @Curr = 1   
			ELSE   
				SET @Curr = 0   
			 
			-- Study Condition   
			IF ((@CondType >= 6) AND (@FieldNum IN (3,4,21,23,24,25,26,27,28,29,30)) )   
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
				SET @SearchStr = @m + '-' +  @D + '-' + @Y   
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
									WHEN 6  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' = ''' + @SearchStr + '''' ELSE ' = ' + @SearchStr END   
									WHEN 7  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <> ''' + @SearchStr + '''' ELSE ' <> ' + @SearchStr END   
									WHEN 8  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' > ''' + @SearchStr + '''' ELSE ' > ' + @SearchStr END   
									WHEN 9  THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN' >= ''' + @SearchStr + '''' ELSE ' >= ' + @SearchStr END   
									WHEN 10 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' < ''' + @SearchStr + '''' ELSE ' < ' + @SearchStr END   
									WHEN 11 THEN CASE WHEN @FieldNum NOT BETWEEN 5 AND 7 THEN ' <= ''' + @SearchStr + '''' ELSE ' <= ' + @SearchStr END   
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
	IF @HaveAdditionInfo > 0
		SET @Criteria =  '<<>>' + @Criteria  
				
	RETURN @Criteria   
END
#########################################################################
#END