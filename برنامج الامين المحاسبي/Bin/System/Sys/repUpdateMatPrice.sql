#########################################################################
CREATE PROCEDURE repUpdateMatPrice
				@GrpPtr [UNIQUEIDENTIFIER],  
				@Unit1 [INT], 
				@Price1 [INT],  
				@Unit2 [INT], 
				@Price2 [INT],  
				@Type [INT], 
				--  #1 multiply the price in unit fact price from unit  
				--  #2 Added constant value 
				--  #3 Percent multiply 
				--  #4 change each price is A to price B 
				--  #5 change each price to price A
				@UnitMulti [INT], -- the unit must multipy the facts in price 
				@Value1 [FLOAT], 
				@Value2 [FLOAT], 
				@PriceType [INT], 
				@BillType [UNIQUEIDENTIFIER],
				@BillNum [INT],
				@TableName [NVARCHAR](100),
				@SubTableName [NVARCHAR](100),
				@MatCond [UNIQUEIDENTIFIER] =0X00 ,
				@RepType [INT]
				/*
					@RepType = 1 	update price of material must update it 

				 	@RepType = 0 	read data of material must update it 
							and insert it in table 
				*/
	
AS
	SET NOCOUNT ON 
	DECLARE @SQL AS [NVARCHAR](max) 
	DECLARE @ValSQL AS [NVARCHAR](2000),@CurrencyGUID UNIQUEIDENTIFIER 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#t_Prices] 
	( 
		[mtNumber] 	[UNIQUEIDENTIFIER], 
		[APrice] 	[FLOAT] 
	) 
	IF (@RepType = 0 AND @Price2 = 9)
	BEGIN
		SELECT @CurrencyGUID = [Guid] FROM [my000] WHERE NUMBER = 1
		INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		0X00, @GrpPtr, -1, @MatCond, 0
		INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList]	0x00 
		EXEC [prcGetLastPrice] '1/1/1980' , '1/1/2070' , 0X00, @GrpPtr, 0X00, 0X00, -1,	@CurrencyGUID, 0X00, 0, 0, 0,	1 
	END
	SET @ValSQL = '' 
	DECLARE @Defpr NVARCHAR(256)

	IF @RepType = 0 
	BEGIN 
		SET @SQL = ' CREATE TABLE [#TResult]( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) '
		SET @SQL = @SQL + 'INSERT INTO [#TResult] EXEC [prcGetMatsList]  NULL, ''' + CAST ( @GrpPtr AS [NVARCHAR](40)) + ''',-1,' + ''''+ CAST (@MatCond AS NVARCHAR(40))+''', 0' 
		IF( @BillType <> 0x0 AND @BillNum <> 0)
		BEGIN 
			CREATE TABLE [#MatBill]( [MatGuid] [UNIQUEIDENTIFIER])
			INSERT INTO [#MatBill] 
				SELECT 
					[biMatPtr] 
				FROM 
					[vwExtended_bi] AS [bill] 
				WHERE 
					[buType] = @BillType 
					AND buNumber = @BillNum 
				GROUP BY 
					biMatPtr
			SET @SQL = @SQL + ' DELETE FROM [#TResult] WHERE [mtGUID] NOT IN ( SELECT MatGuid FROM [#MatBill])'
		END
		--print 'b'
		IF @Type = 1  
		BEGIN 
			SET @ValSQL = CASE @Price2 
				WHEN 1 THEN '[AvgPrice]' 
				WHEN 2 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Whole]'   
								WHEN @Unit2 = 2 THEN '[Whole2]'  
								WHEN @Unit2 = 3 THEN '[Whole3]' 
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Whole] WHEN 2 THEN  [Whole2] ELSE  [Whole3] END' END 
				WHEN 3 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Half]' 
								WHEN @Unit2 = 2 THEN '[Half2]'  
								WHEN @Unit2 = 3 THEN '[Half3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Half] WHEN 2 THEN  [Half2] ELSE  [Half3] END' END 
				WHEN 4 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Export]' 
								WHEN @Unit2 = 2 THEN '[Export2]'  
								WHEN @Unit2 = 3 THEN '[Export3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Export] WHEN 2 THEN  [Export2] ELSE  [Export3] END' END 
				WHEN 5 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Vendor]' 
								WHEN @Unit2 = 2 THEN '[Vendor2]'  
								WHEN @Unit2 = 3 THEN '[Vendor3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Vendor] WHEN 2 THEN  [Vendor2] ELSE  [Vendor3] END' END 
				WHEN 6 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Retail]' 
								WHEN @Unit2 = 2 THEN '[Retail2]'  
								WHEN @Unit2 = 3 THEN '[Retail3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Retail] WHEN 2 THEN  [Retail2] ELSE  [Retail3] END' END 
				WHEN 7 THEN CASE 
								WHEN @Unit2 = 1 THEN '[EndUser]' 
								WHEN @Unit2 = 2 THEN '[EndUser2]'  
								WHEN @Unit2 = 3 THEN '[EndUser3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [EndUser] WHEN 2 THEN  [EndUser2] ELSE  [EndUser3] END' END 
				WHEN 8 THEN CASE 
								WHEN @Unit2 = 1 THEN '[LastPrice]' 
								WHEN @Unit2 = 2 THEN '[LastPrice2]'  
								WHEN @Unit2 = 3 THEN '[LastPrice3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [LastPrice] WHEN 2 THEN  [LastPrice2] ELSE  [LastPrice3] END' END 
				WHEN 9 THEN  ' ISNULL([APrice],0) ' 
			END  
			+ ' * ' + CASE @UnitMulti  
						WHEN 2 THEN '[Unit2Fact]'  
						WHEN 3 THEN '[Unit3Fact]'  
						WHEN 4 THEN 		 
							'CASE [DefUnit]  
								WHEN 2 THEN [Unit2Fact]  
								WHEN 3 THEN [Unit3Fact]  
								ELSE 1 END' 
						ELSE '1' END 
		END 
	 
		IF @Type = 2 
		BEGIN 
			SET @ValSQL = CASE @Price2 
				WHEN 1 THEN '[AvgPrice]' 
				WHEN 2 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Whole]'   
								WHEN @Unit2 = 2 THEN '[Whole2]'  
								WHEN @Unit2 = 3 THEN '[Whole3]' 
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Whole] WHEN 2 THEN  [Whole2] ELSE  [Whole3] END' END 
				WHEN 3 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Half]' 
								WHEN @Unit2 = 2 THEN '[Half2]'  
								WHEN @Unit2 = 3 THEN '[Half3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Half] WHEN 2 THEN  [Half2] ELSE  [Half3] END' END 
				WHEN 4 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Export]' 
								WHEN @Unit2 = 2 THEN '[Export2]'  
								WHEN @Unit2 = 3 THEN '[Export3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Export] WHEN 2 THEN  [Export2] ELSE  [Export3] END' END 
				WHEN 5 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Vendor]' 
								WHEN @Unit2 = 2 THEN '[Vendor2]'  
								WHEN @Unit2 = 3 THEN '[Vendor3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Vendor] WHEN 2 THEN  [Vendor2] ELSE  [Vendor3] END' END 
				WHEN 6 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Retail]' 
								WHEN @Unit2 = 2 THEN '[Retail2]'  
								WHEN @Unit2 = 3 THEN '[Retail3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Retail] WHEN 2 THEN  [Retail2] ELSE  [Retail3] END' END 
				WHEN 7 THEN CASE 
								WHEN @Unit2 = 1 THEN '[EndUser]' 
								WHEN @Unit2 = 2 THEN '[EndUser2]'  
								WHEN @Unit2 = 3 THEN '[EndUser3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [EndUser] WHEN 2 THEN  [EndUser2] ELSE  [EndUser3] END' END 
				WHEN 8 THEN CASE 
								WHEN @Unit2 = 1 THEN '[LastPrice]' 
								WHEN @Unit2 = 2 THEN '[LastPrice2]'  
								WHEN @Unit2 = 3 THEN '[LastPrice3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [LastPrice] WHEN 2 THEN  [LastPrice2] ELSE  [LastPrice3] END' END 
				WHEN 9 THEN  ' ISNULL([APrice],0) ' 
			END  
			+ ' + ' + CAST ( @Value1 AS [NVARCHAR](40)) 
		END 

		IF @Type = 7 
		BEGIN 
			SET @ValSQL = CASE @Price2 
				WHEN 1 THEN '[AvgPrice]' 
				WHEN 2 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Whole]'   
								WHEN @Unit2 = 2 THEN '[Whole2]'  
								WHEN @Unit2 = 3 THEN '[Whole3]' 
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Whole] WHEN 2 THEN  [Whole2] ELSE  [Whole3] END' END 
				WHEN 3 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Half]' 
								WHEN @Unit2 = 2 THEN '[Half2]'  
								WHEN @Unit2 = 3 THEN '[Half3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Half] WHEN 2 THEN  [Half2] ELSE  [Half3] END' END 
				WHEN 4 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Export]' 
								WHEN @Unit2 = 2 THEN '[Export2]'  
								WHEN @Unit2 = 3 THEN '[Export3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Export] WHEN 2 THEN  [Export2] ELSE  [Export3] END' END 
				WHEN 5 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Vendor]' 
								WHEN @Unit2 = 2 THEN '[Vendor2]'  
								WHEN @Unit2 = 3 THEN '[Vendor3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Vendor] WHEN 2 THEN  [Vendor2] ELSE  [Vendor3] END' END 
				WHEN 6 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Retail]' 
								WHEN @Unit2 = 2 THEN '[Retail2]'  
								WHEN @Unit2 = 3 THEN '[Retail3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Retail] WHEN 2 THEN  [Retail2] ELSE  [Retail3] END' END 
				WHEN 7 THEN CASE 
								WHEN @Unit2 = 1 THEN '[EndUser]' 
								WHEN @Unit2 = 2 THEN '[EndUser2]'  
								WHEN @Unit2 = 3 THEN '[EndUser3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [EndUser] WHEN 2 THEN  [EndUser2] ELSE  [EndUser3] END' END 
				WHEN 8 THEN CASE 
								WHEN @Unit2 = 1 THEN '[LastPrice]' 
								WHEN @Unit2 = 2 THEN '[LastPrice2]'  
								WHEN @Unit2 = 3 THEN '[LastPrice3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [LastPrice] WHEN 2 THEN  [LastPrice2] ELSE  [LastPrice3] END' END 
				WHEN 9 THEN  ' ISNULL([APrice],0) ' 
			END  
			+ ' - ' + CAST ( @Value1 AS [NVARCHAR](40)) 
			SET @ValSQL = 'CASE WHEN (' + @ValSQL + ' < 0) THEN 0 ELSE (' + @ValSQL + ') END '
		END 

		IF( @Type = 3 OR @Type = 6)
		BEGIN 
			SET @ValSQL = CASE @Price2 
				WHEN 1 THEN '[AvgPrice]' 
				WHEN 2 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Whole]'   
								WHEN @Unit2 = 2 THEN '[Whole2]'  
								WHEN @Unit2 = 3 THEN '[Whole3]' 
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Whole] WHEN 2 THEN  [Whole2] ELSE  [Whole3] END'  END 
				WHEN 3 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Half]' 
								WHEN @Unit2 = 2 THEN '[Half2]'  
								WHEN @Unit2 = 3 THEN '[Half3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Half] WHEN 2 THEN  [Half2] ELSE  [Half3] END' END 
				WHEN 4 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Export]' 
								WHEN @Unit2 = 2 THEN '[Export2]'  
								WHEN @Unit2 = 3 THEN '[Export3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Export] WHEN 2 THEN  [Export2] ELSE  [Export3] END' END 
				WHEN 5 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Vendor]' 
								WHEN @Unit2 = 2 THEN '[Vendor2]'  
								WHEN @Unit2 = 3 THEN '[Vendor3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Vendor] WHEN 2 THEN  [Vendor2] ELSE  [Vendor3] END' END 
				WHEN 6 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Retail]' 
								WHEN @Unit2 = 2 THEN '[Retail2]'  
								WHEN @Unit2 = 3 THEN '[Retail3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Retail] WHEN 2 THEN  [Retail2] ELSE  [Retail3] END' END 
				WHEN 7 THEN CASE 
								WHEN @Unit2 = 1 THEN '[EndUser]' 
								WHEN @Unit2 = 2 THEN '[EndUser2]'  
								WHEN @Unit2 = 3 THEN '[EndUser3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [EndUser] WHEN 2 THEN  [EndUser2] ELSE  [EndUser3] END' END 
				WHEN 8 THEN CASE 
								WHEN @Unit2 = 1 THEN '[LastPrice]' 
								WHEN @Unit2 = 2 THEN '[LastPrice2]'  
								WHEN @Unit2 = 3 THEN '[LastPrice3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [LastPrice] WHEN 2 THEN  [LastPrice2] ELSE  [LastPrice3] END' END 
				WHEN 9 THEN  'ISNULL([APrice],0) ' 
			END  
			
			IF @Type = 3 
				SET @ValSQL = @ValSQL + ' * ' + CAST ( @Value1/100 AS [NVARCHAR](40)) 
			ELSE
				SET @ValSQL = @ValSQL + ' * ' + CAST ( @Value1 AS [NVARCHAR](40)) 
		END 
		IF @Type = 4  
		BEGIN 
			SET @ValSQL = CAST( @Value2 AS [NVARCHAR](40)) 
		END 
		IF @Type = 5
		BEGIN 
			SET @ValSQL = CAST( @Value1 AS [NVARCHAR](40)) 		
		END
	

		------------------------------------------------------- 
		SET @SQL = @SQL + /*' UPDATE mt000 SET ' */+  
		
		' CREATE TABLE ['+ @TableName + '] ( [mtGuid] [UNIQUEIDENTIFIER], [Price] [FLOAT]) '+
		' INSERT INTO [' + @TableName + '] ( [mtGuid], [Price]) SELECT [mt].[Guid], ' + @ValSQL 
		SET @SQL = @SQL + ' FROM [MT000] AS [MT] INNER JOIN [#TResult] AS [Res] ON [MT].[GUID] = [Res].[mtGUID]'  
		IF (@RepType = 0 AND @Price2 = 9)
				SET @SQL = @SQL + ' LEFT JOIN [#t_Prices] AP ON   [MT].[GUID] = [mtNumber] '
		SET @SQL = @SQL + ' WHERE ((ISNULL(mt.Parent, 0x0) = 0x0) OR ((ISNULL(mt.Parent, 0x0) != 0x0) AND (ISNULL(mt.InheritsParentSpecs, 0) = 1))) AND '
		IF @Type = 4 
		BEGIN 
			SET @SQL = @SQL + 
				CASE @Price2 
				WHEN 1 THEN '[AvgPrice]' 
				WHEN 2 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Whole]'   
								WHEN @Unit2 = 2 THEN '[Whole2]'  
								WHEN @Unit2 = 3 THEN '[Whole3]' 
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Whole] WHEN 2 THEN  [Whole2] ELSE  [Whole3] END'  END 
				WHEN 3 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Half]' 
								WHEN @Unit2 = 2 THEN '[Half2]'  
								WHEN @Unit2 = 3 THEN '[Half3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Half] WHEN 2 THEN  [Half2] ELSE  [Half3] END' END 
				WHEN 4 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Export]' 
								WHEN @Unit2 = 2 THEN '[Export2]'  
								WHEN @Unit2 = 3 THEN '[Export3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Export] WHEN 2 THEN  [Export2] ELSE  [Export3] END' END 
				WHEN 5 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Vendor]' 
								WHEN @Unit2 = 2 THEN '[Vendor2]'  
								WHEN @Unit2 = 3 THEN '[Vendor3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Vendor] WHEN 2 THEN  [Vendor2] ELSE  [Vendor3] END' END 
				WHEN 6 THEN CASE 
								WHEN @Unit2 = 1 THEN '[Retail]' 
								WHEN @Unit2 = 2 THEN '[Retail2]'  
								WHEN @Unit2 = 3 THEN '[Retail3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [Retail] WHEN 2 THEN  [Retail2] ELSE  [Retail3] END' END 
				WHEN 7 THEN CASE 
								WHEN @Unit2 = 1 THEN '[EndUser]' 
								WHEN @Unit2 = 2 THEN '[EndUser2]'  
								WHEN @Unit2 = 3 THEN '[EndUser3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [EndUser] WHEN 2 THEN  [EndUser2] ELSE  [EndUser3] END' END 
				WHEN 8 THEN CASE 
								WHEN @Unit2 = 1 THEN '[LastPrice]' 
								WHEN @Unit2 = 2 THEN '[LastPrice2]'  
								WHEN @Unit2 = 3 THEN '[LastPrice3]'  
								WHEN @Unit2 = 4 THEN 'CASE [DefUnit] WHEN 1 THEN [LastPrice] WHEN 2 THEN  [LastPrice2] ELSE  [LastPrice3] END' END 
				WHEN 9 THEN  '[APrice] ' 
			END + ' = ' + CAST ( @Value1 AS [NVARCHAR](40)) 
			+ CASE @PriceType WHEN 1 THEN ' AND [PriceType] = 15' WHEN 2 THEN ' AND [PriceType] <> 15' ELSE '' END 
		END 
		ELSE 
			SET @SQL = @SQL + CASE @PriceType WHEN 1 THEN ' [PriceType] = 15 ' WHEN 2 THEN ' [PriceType] <> 15 ' ELSE '' END	 
		
		--PRINT @SQL 
		EXEC ( @SQL) 
		SET @SQL = 'SELECT COUNT(*) AS [MatUpdate] FROM [' + @TableName +']'
		EXEC ( @SQL) 
		SET @SQL = 'SELECT [mtGuid]  FROM [' + @TableName +']'
		EXEC ( @SQL) 
		
		-------------------------------------------------------		 
	END 
	ELSE 
	BEGIN 
		--print 'update'
		SET @SQL = ' UPDATE [MT] SET LastPriceDate = '''+ cast( GETDATE() as NVARCHAR(100))+ ''',' +
		CASE @Price1 
			WHEN 0 THEN 
				CASE 
					WHEN @Unit1 = 1 THEN '[Whole]' 
					WHEN @Unit1 = 2 THEN '[Whole2]' 
					WHEN @Unit1 = 3 THEN '[Whole3]' 
					ELSE ''
				END 
			WHEN 1 THEN CASE 
					WHEN @Unit1 = 1 THEN '[Half]' 
					WHEN @Unit1 = 2 THEN '[Half2]' 
					WHEN @Unit1 = 3 THEN '[Half3]'
					ELSE '' 
				END
			WHEN 2 THEN CASE 
					WHEN @Unit1 = 1 THEN '[Export]' 
					WHEN @Unit1 = 2 THEN '[Export2]' 
					WHEN @Unit1 = 3 THEN '[Export3]'
					ELSE '' 
				END
			WHEN 3 THEN CASE 
					WHEN @Unit1 = 1 THEN '[Vendor]' 
					WHEN @Unit1 = 2 THEN '[Vendor2]' 
					WHEN @Unit1 = 3 THEN '[Vendor3]'
					ELSE '' 
			END 
			WHEN 4 THEN CASE 
					WHEN @Unit1 = 1 THEN '[Retail]' 
					WHEN @Unit1 = 2 THEN '[Retail2]' 
					WHEN @Unit1 = 3 THEN '[Retail3]' 
			END  
			WHEN 5 THEN CASE 
					WHEN @Unit1 = 1 THEN '[EndUser]' 
					WHEN @Unit1 = 2 THEN '[EndUser2]' 
					WHEN @Unit1 = 3 THEN '[EndUser3]' 
					ELSE ''
				END
			WHEN 6 THEN CASE 
					WHEN @Unit1 = 1 THEN '[LastPrice]' 
					WHEN @Unit1 = 2 THEN '[LastPrice2]' 
					WHEN @Unit1 = 3 THEN '[LastPrice3]'
					ELSE '' 
				END 
		END
		IF @Unit1 = 4
		BEGIN
			SET @Defpr = CASE @Price1 
					WHEN 0 THEN  'Whole'
					WHEN 1 THEN  'Half'  
					WHEN 2 THEN 'Export'
					WHEN 3 THEN 'Vendor'
					WHEN 4 THEN 'Retail' 
					WHEN 5 THEN 'EndUser'
					WHEN 6 THEN 'LastPrice'
					ELSE ''
				END 
				SET @SQL = @SQL + '['+@Defpr + '] = CASE [DefUnit] WHEN 1 THEN [Mu].[Price] ELSE ['+@Defpr + '] END ,['+@Defpr + '2] = CASE [DefUnit] WHEN 2 THEN [Mu].[Price] ELSE ['+@Defpr + '2] END,['+@Defpr + '3] = CASE [DefUnit] WHEN 3 THEN [Mu].[Price] ELSE ['+@Defpr + '3] END'
		END
		ELSE
			SET @SQL = @SQL + ' = [Mu].[Price] '
		SET @SQL = @SQL + ' FROM [mt000] AS [mt] INNER JOIN [' + @TableName + '] AS [Mu] ON [Guid] = [Mu].[mtGuid] 
			WHERE ((ISNULL(mt.Parent, 0x0) = 0x0) OR ((ISNULL(mt.Parent, 0x0) != 0x0) AND (ISNULL(mt.InheritsParentSpecs, 0) = 1))) ' 
		--PRINT @SQL
		EXEC ( @SQL)
		
		SELECT @@ROWCOUNT AS [MatUpdate]
		SET @SQL = 'SELECT [mu].[mtGuid] FROM [mt000] AS [mt] INNER JOIN [' + @TableName + '] AS [mu] ON [Guid] = [Mu].[mtGuid]
			WHERE ((ISNULL(mt.Parent, 0x0) = 0x0) OR ((ISNULL(mt.Parent, 0x0) != 0x0) AND (ISNULL(mt.InheritsParentSpecs, 0) = 1))) ' 
		EXEC (@SQL)	
	END
	IF @RepType = 1
	BEGIN
		SET @SQL = 'DROP TABLE [' + @TableName + ']'
		EXEC ( @SQL)
		
	END 
#########################################################################
CREATE PROCEDURE UpdateMatPriceCount
			@GrpPtr [UNIQUEIDENTIFIER],
			@BillType [UNIQUEIDENTIFIER],
			@BillNum [INT],
			@MatCond [UNIQUEIDENTIFIER] =0X00
AS
		SET NOCOUNT ON  
		
		 CREATE TABLE [#Result]( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	     INSERT INTO [#Result] EXEC [prcGetMatsList]  NULL, @GrpPtr ,-1, @MatCond, 0
		IF( @BillType <> 0x0 AND @BillNum <> 0)
		BEGIN 
			CREATE TABLE [#MatBill]( [MatGuid] [UNIQUEIDENTIFIER])
			INSERT INTO [#MatBill] 
				SELECT 
					[biMatPtr] 
				FROM 
					[vwExtended_bi] AS [bill] 
					INNER JOIN mt000 mt ON bill.[biMatPtr] = mt.GUID 
				WHERE 
					[buType] = @BillType 
					AND buNumber = @BillNum 
					AND ((ISNULL(mt.Parent, 0x0) = 0x0) OR ((ISNULL(mt.Parent, 0x0) != 0x0) AND (ISNULL(mt.InheritsParentSpecs, 0) = 1)))
				GROUP BY 
					biMatPtr
			 DELETE FROM [#Result] WHERE [mtGUID] NOT IN ( SELECT MatGuid FROM [#MatBill])
		END
			SELECT 
				COUNT(*) AS MatCount 
			FROM 
				[MT000] AS [MT] 
				INNER JOIN [#Result] AS [Res] ON [MT].[GUID] = [Res].[mtGUID]
			WHERE ((ISNULL(mt.Parent, 0x0) = 0x0) OR ((ISNULL(mt.Parent, 0x0) != 0x0) AND (ISNULL(mt.InheritsParentSpecs, 0) = 1)))
#########################################################################
#END