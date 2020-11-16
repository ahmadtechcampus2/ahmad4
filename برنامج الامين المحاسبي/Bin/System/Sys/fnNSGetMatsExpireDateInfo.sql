################################################################################
CREATE FUNCTION fnGetMatsExpireDateInfo( @beforeNumberOfDays INT,
	@fromDate DATETIME = NULL)
RETURNS @result TABLE 
(
	[MatPtr] [UNIQUEIDENTIFIER] NOT NULL,     
	[BiGuid] [UNIQUEIDENTIFIER],      
	[Qty] [FLOAT],   
	[Qty2] [FLOAT], 
	[Qty3] [FLOAT], 
	[Remaining] [FLOAT], 
	[Remaining2] [FLOAT], 
	[Remaining3] [FLOAT], 
	[ExpireDate] [DATETIME] NOT NULL,         
	[Date] [DATETIME],    
	[buStore] [UNIQUEIDENTIFIER], 
	[BillType] [UNIQUEIDENTIFIER],         
	[BillNum] [UNIQUEIDENTIFIER],          
	[Direction] [INT]
) 
BEGIN
	IF @fromDate is null
		SET @fromDate = getdate()
		
	DECLARE @AllResult TABLE( 
			[MatPtr] [UNIQUEIDENTIFIER] NOT NULL,  
			[BiGuid] [UNIQUEIDENTIFIER],
			[Qty] [FLOAT],   
			[Qty2] [FLOAT], 
			[Qty3] [FLOAT], 
			[Remaining] [FLOAT], 
			[Remaining2] [FLOAT], 
			[Remaining3] [FLOAT], 
			[ExpireDate] [DATETIME] NOT NULL,         
			[Date] [DATETIME],    
			[buStore] [UNIQUEIDENTIFIER], 
			[BillType] [UNIQUEIDENTIFIER],         
			[BillNum] [UNIQUEIDENTIFIER],          
			[Direction] [INT]
			) 
	DECLARE  @In_Result TABLE( 
			[MatPtr] [UNIQUEIDENTIFIER] NOT NULL,
			[BiGuid] [UNIQUEIDENTIFIER],        
			[Qty] [FLOAT],   
			[Qty2] [FLOAT], 
			[Qty3] [FLOAT], 
			[Remaining] [FLOAT], 
			[Remaining2] [FLOAT], 
			[Remaining3] [FLOAT], 
			[ExpireDate] [DATETIME] NOT NULL,         
			[Date] [DATETIME],    
			[buStore] [UNIQUEIDENTIFIER], 
			[BillType] [UNIQUEIDENTIFIER],         
			[BillNum] [UNIQUEIDENTIFIER],          
			[Direction] [INT]
			) 
	DECLARE  @Out_Result TABLE( 
				[MatPtr] [UNIQUEIDENTIFIER] NOT NULL,
				[BiGuid] [UNIQUEIDENTIFIER],        
				[Qty] [FLOAT],   
				[Qty2] [FLOAT], 
				[Qty3] [FLOAT], 
				[Remaining] [FLOAT], 
				[Remaining2] [FLOAT], 
				[Remaining3] [FLOAT], 
				[ExpireDate] [DATETIME] NOT NULL,         
				[Date] [DATETIME],    
				[buStore] [UNIQUEIDENTIFIER], 
				[BillType] [UNIQUEIDENTIFIER],         
				[BillNum] [UNIQUEIDENTIFIER],          
				[Direction] [INT]
				) 
	------------------------
	INSERT INTO @AllResult
		SELECT   
			[biMatPtr], 
			[biGUID],
			[biQty] + [biBonusQnt],   
			[biQty2] + ( [biBonusQnt] / CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END), 
			[biQty3] + ( [biBonusQnt] / CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END), 
			[biQty] + [biBonusQnt] ,
			[biQty2] + ( [biBonusQnt] /CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END), 
			[biQty3] + ( [biBonusQnt] /CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END), 
			[biExpireDate], 
			[buDate], 
			[biStorePtr], 
			[buType],    
			[buGUID], 
			[buDirection] 
		FROM    
			[fnExtended_Bi_Fixed]( 0x00)  AS  [bi]    
			INNER JOIN [mt000] AS [mat] ON [bi].[BiMatPtr] = [mat].[guid]    
		WHERE 
			[bi].[mtExpireFlag] = 1 
			ORDER BY 
			[biMatPtr],[biStorePtr],[buDate],[buDirection] DESC ,[biExpireDate] 
		
		INSERT INTO	 @In_Result
			SELECT  
				[MatPtr], 
				[BiGuid] ,      
				[Qty] ,   
				[Qty2], 
				[Qty3], 
				[Remaining] , 
				[Remaining2] , 
				[Remaining3], 
				[ExpireDate] ,         
				[Date],    
				[buStore] , 
				[BillType] ,         
				[BillNum] ,          
				[Direction]  
			FROM  
				@AllResult 
			WHERE  
				[Direction] =  1
			ORDER BY 
			[MatPtr],[buStore],[Date],[Direction] DESC ,[ExpireDate] 
	
	INSERT INTO @Out_Result
			SELECT  
				[MatPtr],   
				[BiGuid] ,     
				[Qty] ,   
				[Qty2], 
				[Qty3], 
				[Remaining] , 
				[Remaining2] , 
				[Remaining3], 
				[ExpireDate] ,         
				[Date],    
				[buStore] , 
				[BillType] ,         
				[BillNum] ,          
				[Direction]  
			FROM  
				@AllResult
			WHERE  
				[Direction] = - 1
			ORDER BY 
			[MatPtr],[buStore],[Date],[Direction] DESC ,[ExpireDate] 
	-------------------------------------------------------------------------
	DECLARE
		--@In_Res CURSOR, ÊÚÑíÝ ÈÏæä ÇÓÊÎÏÇã
		@Out_Res CURSOR,
		 
		@In_MatPtr [UNIQUEIDENTIFIER],   
		@In_biGuid [UNIQUEIDENTIFIER],   
		@In_Date [DATETIME],    
		@In_Store [UNIQUEIDENTIFIER],    
		@In_ExpireDate [DATETIME],    
		@In_Qnt [FLOAT],     
		@In_Qnt2 [FLOAT],     
		@In_Qnt3 [FLOAT],    
		@In_Remaining [FLOAT], 
		@In_Remaining2 [FLOAT], 
		@In_Remaining3 [FLOAT], 
		@In_BillType [UNIQUEIDENTIFIER], 
		@In_BillGuid [UNIQUEIDENTIFIER],    
		@In_Direction [INT], 
		
		@Out_MatPtr [UNIQUEIDENTIFIER],   
		@Out_biGuid [UNIQUEIDENTIFIER],    
		@Out_Date [DATETIME],    
		@Out_Store [UNIQUEIDENTIFIER],    
		@Out_ExpireDate [DATETIME],    
		@Out_Qnt [FLOAT],     
		@Out_Qnt2 [FLOAT],     
		@Out_Qnt3 [FLOAT],    
		@Out_BillType [UNIQUEIDENTIFIER], 
		@Out_BillGuid [UNIQUEIDENTIFIER],    
		@Out_Direction [INT], 
		@Id [INT]  
		 
	SET @Out_Res = CURSOR FAST_FORWARD FOR 
		SELECT 
			[MatPtr],
			[BiGuid],    
			[Date],    
			[buStore], 
			[ExpireDate],    
			[Qty],    
			[Qty2],    
			[Qty3], 
			[BillType], 
			[BillNum] 
		FROM    
			@Out_Result
		ORDER BY 
			[MatPtr],[buStore],[Date],[Direction] DESC ,[ExpireDate] 
			 
		OPEN @Out_Res FETCH FROM @Out_Res 
			INTO    
				@Out_MatPtr, 
				@Out_biguid,
				@Out_Date, 
				@Out_Store, 
				@Out_ExpireDate, 
				@Out_Qnt, 
				@Out_Qnt2, 
				@Out_Qnt3, 
				@In_BillType, 
				@In_BillGuid 
		 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			WHILE @Out_Qnt > 0 
			BEGIN 
				SET @In_ExpireDate = NULL 
				IF (@Out_ExpireDate = '1/1/1980') 
				BEGIN 
					 
					SELECT @In_ExpireDate = MIN([ExpireDate]) FROM  @In_Result WHERE  [MatPtr] = @Out_MatPtr AND [buStore] = @Out_Store AND  [Remaining] > 0 AND [Date] <= @Out_Date  --AND [COSTGUID] = @OUT_COSTGUID AND [CLASS] =  @OUT_CLASS  
				END 
				ELSE 
				BEGIN 
					SELECT @In_ExpireDate = MIN([ExpireDate]) FROM  @In_Result WHERE  [MatPtr] = @Out_MatPtr AND [buStore] = @Out_Store AND  [Remaining] > 0 AND [Date] <= @Out_Date AND [ExpireDate] = @Out_ExpireDate  --AND [COSTGUID] = @OUT_COSTGUID AND [CLASS] =  @OUT_CLASS  
				END 
				SET @In_biGuid = (SELECT TOP(1) BiGuid FROM @In_Result WHERE [MatPtr] = @Out_MatPtr AND [buStore] = @Out_Store AND  [Remaining] > 0 AND [Date] <= @Out_Date AND [ExpireDate] = @In_ExpireDate) 
				IF (@In_ExpireDate IS NULL) 
				BEGIN 
					INSERT INTO @In_Result ( 
						[MatPtr],    
						[Qty],    
						[Qty2],    
						[Qty3],    
						[ExpireDate],    
						[Date], 
						[buStore], 
						[Remaining],    
						[Remaining2],    
						[Remaining3],    
						[BillType],    
						[BillNum]    
						)    
					VALUES( 
						@Out_MatPtr,    
						0,--Qty    
						0,--Qty2    
						0,--Qty3    
						@Out_ExpireDate,    
						@Out_Date,    
						@Out_Store, 
						- @Out_Qnt,     
						- @Out_Qnt2,     
						- @Out_Qnt3,    
						@Out_BillType,    
						@Out_BillGuid )   
						
					BREAK 
				END 
				-------------------------------------------------------- 
				SELECT TOP 1 
					@In_Remaining = [Remaining], 
					@In_Remaining2 = [Remaining2], 
					@In_Remaining3 = [Remaining3] 
					 
				FROM  
						@In_Result
				WHERE
						[ExpireDate] = @In_ExpireDate 
						AND[BiGuid] = @In_biGuid
				-------------------------------------------------------- 
				IF @Out_Qnt <= @In_Remaining 
					UPDATE @In_Result
						SET  
						[Remaining] = [Remaining] - @Out_Qnt, 
						[Remaining2] = [Remaining2] - @Out_Qnt2,      
						[Remaining3] = [Remaining3] - @Out_Qnt3     
					WHERE     
						[ExpireDate] = @In_ExpireDate 
						AND[BiGuid] = @In_biGuid
						
				ELSE    
					DELETE TOP (1) @In_Result
					WHERE     
						[ExpireDate] = @In_ExpireDate 
						AND[BiGuid] = @In_biGuid
					
				SET @Out_Qnt = @Out_Qnt - @In_Remaining 
				SET @Out_Qnt2 = @Out_Qnt2 - @In_Remaining2 
				SET @Out_Qnt3 = @Out_Qnt3 - @In_Remaining3 
			END 
			 
		FETCH NEXT FROM @Out_Res  
			INTO  
				@Out_MatPtr,
				@Out_biGuid,				 
				@Out_Date, 
				@Out_Store, 
				@Out_ExpireDate, 
				@Out_Qnt, 
				@Out_Qnt2, 
				@Out_Qnt3, 
				@Out_BillType, 
				@Out_BillGuid 
				
	END 
	CLOSE @out_Res
	DEALLOCATE @out_Res
	INSERT INTO @result 
	SELECT *
	FROM 
		@In_Result
	 WHERE 
		( Remaining > 0) 
		AND  (DATEDIFF(day, [expiredate], @fromDate) = -1 * @beforeNumberOfDays)
	RETURN
END
################################################################################
#END
