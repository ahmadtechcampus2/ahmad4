#########################################################
CREATE PROC repMatExpireDate2
	@UntilDate [DATETIME],       
	@ShowBonus [BIT],       
	@UseUnit [INT], -- 1 unit1 2 unit2 3 unit3 4 defunit       
	@CurrencyGUID [UNIQUEIDENTIFIER],       
	@CurrencyVal [FLOAT],  
	@FromDate [DATETIME] =  '1980-01-01',
	@Flg [INT] = 0,
	@Posted [INT] = -1,
	@BrGuid [UNIQUEIDENTIFIER] = 0X0,
	@ShowPrice [BIT] = 0,
	@CostGuid [UNIQUEIDENTIFIER] = 0X00,
	@DntImplistCost	[BIT] = 0,
	@bProcessCost bit = 0,
	@bProcessClass bit = 0,
	@FilterByExpireDate BIT = 0
AS
	--DECLARE @CurrencyGUID UNIQUEIDENTIFIER
	CREATE TABLE [#Cost]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	IF (@DntImplistCost = 0)
	BEGIN
		INSERT INTO [#Cost]		SELECT [fn].[GUID],[co].[coSecurity] 	FROM
			[dbo].[fnGetCostsList](@CostGUID) AS [fn] INNER JOIN [vwco] AS [co]
			ON [fn].[GUID] = [co].[coGUID] 		 
		IF (ISNULL(@CostGUID,0X00)=0X00) 
			INSERT INTO [#Cost]	 VALUES(0X00,0)	
	END
	ELSE 
	BEGIN
		IF @CostGuid <> 0X00
			INSERT INTO [#Cost] SELECT coGUID,coSECURITY FROM vwco
		ELSE
			INSERT INTO [#Cost] SELECT 0X00,0
	END
	CREATE TABLE [#SecViol]( Type [INT], Cnt [INT])
	CREATE TABLE [#AllResult](
			[CLASS] [NVARCHAR](250) COLLATE Arabic_CI_AI,
			[COSTGuid] UNIQUEIDENTIFIER,
			[MatPtr] [UNIQUEIDENTIFIER] NOT NULL,       
			[Price] [FLOAT],        
			[Qty] [FLOAT],  
			[Qty2] [FLOAT],
			[Qty3] [FLOAT],
			[Remaining] [FLOAT],
			[Remaining2] [FLOAT],
			[Remaining3] [FLOAT],
			[ExpireDate] [DATETIME] NOT NULL,        
			[Date] [DATETIME],   
			[buStore] [UNIQUEIDENTIFIER],
			[MatUnitName] [NVARCHAR](150) COLLATE Arabic_CI_AI,        
			[BillType] [UNIQUEIDENTIFIER],        
			[BillNum] [UNIQUEIDENTIFIER],         
			[BillNotes] [NVARCHAR](256) COLLATE Arabic_CI_AI,
			[mtSecurity] [INT],
			[Security] [INT],
			[UserSecurity] [INT],
			[Direction] [INT],
			[ID] [INT] IDENTITY(1,1))
	INSERT INTO [#AllResult]
			(
			[CLASS],
			[COSTGuid],
			[MatPtr],
			[Price],
			[Qty],
			[Qty2],
			[Qty3],
			[Remaining],
			[Remaining2],
			[Remaining3],
			[ExpireDate],
			[Date],
			[buStore],
			[MatUnitName],
			[BillType],
			[BillNum],
			[BillNotes],
			[mtSecurity],
			[Security],
			[UserSecurity],
			[Direction])
		SELECT  
			case @bProcessClass when 0 then '' else [BICLASSPTR] end,
			case @bProcessCost  when 0 then 0x00 else [biCostPtr] end,
			[biMatPtr],
			CASE WHEN ReadPrice >= BuSecurity THEN 1 ELSE 0 END * [biBillQty] * [FixedBiPrice],
			CASE @UseUnit    
				WHEN 0 THEN [biQty] + [biBonusQnt] * @ShowBonus    
				WHEN 1 THEN [biQty2] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)    
				WHEN 2 THEN [biQty3] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)   
				WHEN 3 THEN ([biQty] + [biBonusQnt] * @ShowBonus)/CASE bi.[mtDefUnitFact] WHEN 0 THEN 1 ELSE bi.[mtDefUnitFact] END   
			END,     
			[biQty2] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END),
			[biQty3] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END),
			CASE @UseUnit    
				WHEN 0 THEN [biQty] + [biBonusQnt] * @ShowBonus    
				WHEN 1 THEN [biQty2] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)    
				WHEN 2 THEN [biQty3] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)   
				WHEN 3 THEN ([biQty] + [biBonusQnt] * @ShowBonus)/CASE bi.[mtDefUnitFact] WHEN 0 THEN 1 ELSE bi.[mtDefUnitFact] END   
			END,     
			[biQty2] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END),
			[biQty3] + ( [biBonusQnt] * @ShowBonus/CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END),
			[biExpireDate],
			[buDate],
			[biStorePtr],
			CASE @UseUnit   
				WHEN 0 THEN bi.[mtUnity]    
				WHEN 1 THEN bi.[mtUnit2]    
				WHEN 2 THEN bi.[mtUnit3]    
				WHEN 3 THEN bi.[mtDefUnitName]    
			END,
			[buType],   
			CASE @Flg WHEN 1 THEN [buGUID] ELSE 0X00 END,
			[buNotes],
			bi.[mtSecurity],
			[buSecurity],
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
			[buDirection]
		FROM   
			[fnExtended_Bi_Fixed]( @CurrencyGUID)  AS  [bi]   
			INNER JOIN [#Mat] AS [mat] ON [bi].[BiMatPtr] = [mat].[mtNumber]   
			INNER JOIN [#Src] AS [src] ON [bi].[BuType] = [src].[Type]   
			INNER JOIN [#Store] AS [stor] ON [bi].[BiStorePtr] = [stor].[Number] 
			INNER JOIN [#Cost] AS [cost] ON  [bi].[BiCostPtr] =  [CostGUID]
		WHERE
			(
				(
					@FilterByExpireDate = 0 AND
					((@FromDate =  '1980-01-01'  AND [buDate] <= @UntilDate ) OR ( @FromDate <>  '1980-01-01'   AND [buDate] between @FromDate and @UntilDate))
				)
				OR (@FilterByExpireDate = 1 AND biExpireDate BETWEEN @FromDate AND @UntilDate)
			)
			AND [bi].[mtExpireFlag] = 1
			AND (@Posted = -1 OR [bi].[buIsPosted] = @Posted)
			AND (@BrGuid = 0X0 OR [bi].[buBranch] = @BrGuid)
		ORDER BY [biMatPtr],[biStorePtr],[buDate],[buDirection] DESC ,[biExpireDate]
	----------------------------------------------------
	CREATE TABLE [#Out_Result]( 
				[CLASS] [NVARCHAR](250) COLLATE Arabic_CI_AI,
				[COSTGuid] [UNIQUEIDENTIFIER],
				[MatPtr] [UNIQUEIDENTIFIER],   
				[Date] [DATETIME],   
				[buStore] [Uniqueidentifier],
				[ExpireDate] [DATETIME] NOT NULL,   
				[Price] [FLOAT],
				[Qty] [FLOAT],   
				[Qty2] [FLOAT],   
				[Qty3] [FLOAT],   
				[MatUnitName] [NVARCHAR](150) COLLATE Arabic_CI_AI,        
				[BillType] [UNIQUEIDENTIFIER],        
				[BillNum] [UNIQUEIDENTIFIER],         
				[BillNotes] [NVARCHAR](256) COLLATE Arabic_CI_AI,
				[Direction] [INT] DEFAULT -1,
				[Id] [INT] DEFAULT 0)   

	
	CREATE TABLE [#In_Result]( 
			[CLASS] [NVARCHAR](250) COLLATE Arabic_CI_AI,
			[COSTGuid][UNIQUEIDENTIFIER],
			[MatPtr] [UNIQUEIDENTIFIER] NOT NULL,       
			[Price] [FLOAT],        
			[Qty] [FLOAT],    
			[Qty2] [FLOAT],    
			[Qty3] [FLOAT],    
			[ExpireDate] [DATETIME] NOT NULL,        
			[Date] [DATETIME],   
			[buStore] [UNIQUEIDENTIFIER],
			[Remaining] [FLOAT],    
			[Remaining2] [FLOAT],    
			[Remaining3] [FLOAT],        
			[MatUnitName] [NVARCHAR](150) COLLATE Arabic_CI_AI,        
			[BillType] [UNIQUEIDENTIFIER],        
			[BillNum] [UNIQUEIDENTIFIER],         
			[BillNotes] [NVARCHAR](256) COLLATE Arabic_CI_AI,
			[Direction] [INT] DEFAULT 1,
			[id] [INT] DEFAULT 0)    

	

	-- insert inputs:       
	INSERT INTO [#In_Result]
		SELECT    
			[CLASS],
			[COSTGuid], 
			[MatPtr],       
			[Price],    
			[Qty],
			[Qty2],
			[Qty3],
			[ExpireDate],       
			[Date], 
			[buStore],      
			[Remaining],
			[Remaining2],
			[Remaining3],
			[MatUnitName],
			CASE WHEN @Flg = 1 THEN [BillType] ELSE 0x00 END,
			CASE WHEN @Flg = 1 THEN [BillNum] ELSE 0X00 END,   
			CASE WHEN @Flg = 1 THEN [BillNotes] ELSE '' END,
			1,ID
		FROM 
			[#AllResult]
		WHERE 
			[Direction] =  1	
			--AND ExpireDate <> '1980-01-01'
		
	
	DECLARE @Maxid INT
	SELECT @Maxid = MAX(ID) FROM #Out_Result WHERE [Direction] = -1  AND ExpireDate > '1/1/1980'
	IF @Maxid IS NULL
		SET @Maxid = 0
		
			
	INSERT INTO [#Out_Result] (
				[CLASS],
				[COSTGuid],
				[MatPtr],
				[Date],
				[buStore],
				[ExpireDate],
				[Price],
				[Qty],
				[Qty2],
				[Qty3],
				[MatUnitName],
				[BillType],
				[BillNum],
				[BillNotes],
				[Direction] )
			SELECT   
				[CLASS],
				[COSTGuid],
				[MatPtr],   
				[Date], 
				[buStore],
				[ExpireDate],   
				[Price],    
				[Qty],
				[Qty2],
				[Qty3],
				[MatUnitName],
				CASE WHEN @Flg = 1 THEN [BillType] ELSE 0x00 END,
				CASE WHEN @Flg = 1 THEN [BillNum] ELSE 0X00 END,   
				CASE WHEN @Flg = 1 THEN [BillNotes] ELSE '' END,
				-1
			FROM   
				[#AllResult]
			WHERE   
				[Direction] = -1
			ORDER BY CASE WHEN ExpireDate > '1/1/1980' THEN [ID] ELSE [ID] + @Maxid END


	DECLARE @In_Res CURSOR,
		@Out_Res CURSOR,
		
		@In_MatPtr [UNIQUEIDENTIFIER],   
		@In_Date [DATETIME],   
		@In_Store [UNIQUEIDENTIFIER],   
		@In_ExpireDate [DATETIME],   
		@In_Qnt [FLOAT],    
		@In_Qnt2 [FLOAT],    
		@In_Qnt3 [FLOAT],   
		@In_Remaining [FLOAT],
		@In_Remaining2 [FLOAT],
		@In_Remaining3 [FLOAT],
		@In_MatUnitName [NVARCHAR](255),
		@In_BillType [UNIQUEIDENTIFIER],
		@In_BillGuid [UNIQUEIDENTIFIER],   
		@In_BillNotes [NVARCHAR](255),
		@In_Direction [INT],

		@OUT_CLASS [NVARCHAR](250),
		@OUT_COSTGuid [UNIQUEIDENTIFIER],
		@Out_MatPtr [UNIQUEIDENTIFIER],   
		@Out_Date [DATETIME],   
		@Out_Store [UNIQUEIDENTIFIER],   
		@Out_ExpireDate [DATETIME],   
		@Out_Qnt [FLOAT],    
		@Out_Qnt2 [FLOAT],    
		@Out_Qnt3 [FLOAT],   
		@Out_MatUnitName [NVARCHAR](255),
		@Out_BillType [UNIQUEIDENTIFIER],
		@Out_BillGuid [UNIQUEIDENTIFIER],   
		@Out_BillNotes [NVARCHAR](255),
		@Out_Direction [INT],
		@Id [INT] 
		

	SET @Out_Res = CURSOR FAST_FORWARD FOR
		SELECT
			[CLASS],
			[COSTGuid],
			[MatPtr],   
			[Date],   
			[buStore],
			[ExpireDate],   
			[Qty],   
			[Qty2],   
			[Qty3],
			[MatUnitName],
			[BillType],
			[BillNum],
			[BillNotes] 
		FROM   
			[#Out_Result]
		ORDER BY
				[Id]
			
		OPEN @Out_Res FETCH FROM @Out_Res
			INTO   
				@OUT_CLASS, 
				@OUT_COSTGuid, 
				@Out_MatPtr,
				@Out_Date,
				@Out_Store,
				@Out_ExpireDate,
				@Out_Qnt,
				@Out_Qnt2,
				@Out_Qnt3,
				@In_MatUnitName,
				@In_BillType,
				@In_BillGuid,
				@In_BillNotes
				
		CREATE CLUSTERED INDEX [inind] ON [#In_Result]([ID])
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			WHILE @Out_Qnt > 0
			BEGIN
				SET @In_ExpireDate = NULL
				IF (@Out_ExpireDate = '1/1/1980')
				BEGIN
					
					SELECT @In_ExpireDate = MIN([ExpireDate]) FROM   [#In_Result] WHERE  [MatPtr] = @Out_MatPtr AND [buStore] = @Out_Store AND  [Remaining] > 0 AND [Date] <= @Out_Date  AND [COSTGUID] = @OUT_COSTGUID AND [CLASS] =  @OUT_CLASS 
				END
				ELSE
				BEGIN
					SELECT @In_ExpireDate = MIN([ExpireDate]) FROM   [#In_Result] WHERE  [MatPtr] = @Out_MatPtr AND [buStore] = @Out_Store AND  [Remaining] > 0 AND [Date] <= @Out_Date AND [ExpireDate] = @Out_ExpireDate  AND [COSTGUID] = @OUT_COSTGUID AND [CLASS] =  @OUT_CLASS 
				END 
				IF (@In_ExpireDate IS NULL)
				BEGIN
					INSERT INTO [#In_Result] (
						[CLASS] ,
						[COSTGuid] ,
						[MatPtr],   
						[Price],   
						[Qty],   
						[Qty2],   
						[Qty3],   
						[ExpireDate],   
						[Date],
						[buStore],
						[Remaining],   
						[Remaining2],   
						[Remaining3],   
						[MatUnitName],   
						[BillType],   
						[BillNum],   
						[BillNotes])   
					VALUES(
						@OUT_CLASS,
						@OUT_COSTGuid,
						@Out_MatPtr,   
						0,--Price   
						0,--Qty   
						0,--Qty2   
						0,--Qty3   
						@Out_ExpireDate,   
						@Out_Date,   
						@Out_Store,
						- @Out_Qnt,    
						- @Out_Qnt2,    
						- @Out_Qnt3,   
						@Out_MatUnitName,   
						@Out_BillType,   
						@Out_BillGuid,   
						@Out_BillNotes)
					BREAK
				END
				--------------------------------------------------------
				SELECT TOP 1 @ID = [id] ,
					@In_Remaining = [Remaining],
					@In_Remaining2 = [Remaining2],
					@In_Remaining3 = [Remaining3]
					
				FROM   [#In_Result] WHERE [ExpireDate] = @In_ExpireDate AND [MatPtr] = @Out_MatPtr AND [buStore] = @Out_Store AND  [Remaining] > 0 AND [Date] <= @Out_Date 
				--------------------------------------------------------
				IF @Out_Qnt <= @In_Remaining
					UPDATE [#In_Result]
						SET 
						[Remaining] = [Remaining] - @Out_Qnt,
						[Remaining2] = [Remaining2] - @Out_Qnt2,     
						[Remaining3] = [Remaining3] - @Out_Qnt3    
					WHERE    
						[ID] = @ID 
				ELSE   
					DELETE  [#In_Result] 
					WHERE    
						[ID] = @ID 
				SET @Out_Qnt = @Out_Qnt - @In_Remaining
				SET @Out_Qnt2 = @Out_Qnt2 - @In_Remaining2
				SET @Out_Qnt3 = @Out_Qnt3 - @In_Remaining3
			END
			
		FETCH NEXT FROM @Out_Res 
			INTO 
				@OUT_CLASS,
				@OUT_COSTGuid,
				@Out_MatPtr,
				@Out_Date,
				@Out_Store,
				@Out_ExpireDate,
				@Out_Qnt,
				@Out_Qnt2,
				@Out_Qnt3,
				@Out_MatUnitName,
				@Out_BillType,
				@Out_BillGuid,
				@Out_BillNotes
	END
	CLOSE @Out_Res
	DEALLOCATE @Out_Res
	
	DECLARE @CostStr NVARCHAR(40)
	SET @CostStr = ''
	IF @bProcessCost > 0
		Set @CostStr = ',
		[res].[COSTGuid]'
	
	DECLARE @ResStr NVARCHAR(4000)
	Set @ResStr = 
	'SELECT 
		0,
		[MatPtr],
		[mt].[Code] AS [MatCode],
		[mt].[Name] AS [MatName],
		SUM( CASE ' + CAST(@ShowPrice AS NVARCHAR(50)) + ' WHEN 0 THEN 0 ELSE [Price]/CASE [res].[Qty] WHEN 0 THEN 1 ELSE [res].[Qty] END * [Remaining] END ), 
		SUM([res].[Qty]),
		SUM([Qty2]),
		SUM([Qty3]),
		[ExpireDate],
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [Date] ELSE CAST(''1/1/1980'' AS [DATETIME]) END,
		[buStore],
		SUM([Remaining]),
		SUM([Remaining2]),
		SUM([Remaining3]),
		[MatUnitName],
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [BillType] ELSE 0X00 END,
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [BillNum] ELSE 0X00 END,
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [BillNotes] ELSE '''' END,
		0 AS Age ,
		CASE WHEN ' + CAST(@bProcessClass AS NVARCHAR(2)) + ' = 1 THEN [res].[CLASS] ELSE '''' END
		' + @CostStr  + '
	FROM
		[#In_Result] AS [res] INNER JOIN [Mt000] AS [mt] ON [res].[MatPtr] = [mt].[GUID]
	WHERE
		[Remaining] <> 0
	GROUP BY 
		[MatPtr],
		[mt].[Code],
		[mt].[Name],
		[ExpireDate],
		[buStore],
		[MatUnitName],
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [BillType] ELSE 0X00 END,
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [BillNum] ELSE 0X00 END,
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [Date] ELSE CAST(''1/1/1980'' AS [DATETIME]) END,
		CASE WHEN ' + CAST(@Flg AS NVARCHAR(2)) + ' = 1 THEN [BillNotes] ELSE '''' END,
		CASE WHEN ' + CAST(@bProcessClass AS NVARCHAR(2)) + ' = 1 THEN [res].[CLASS] ELSE '''' END
		' + @CostStr  + '
	ORDER BY 
		[MatPtr],
		[buStore]'
	
	EXECUTE SP_ExecuteSql @ResStr

	RETURN @@ROWCOUNT  
	
/*
DECLARE @ID INT,@W INT
SET @iD =-22
SELECT @iD = NUMBER ,@W = NUMBER FROM BU000 WHERE GUID = 'EAF87DC6-9C12-4016-8E31-00DC21DC71F9'
PRINT @ID

SELECT GUID,* FROM AMNDB036..BU000
*/
#########################################################
#END
