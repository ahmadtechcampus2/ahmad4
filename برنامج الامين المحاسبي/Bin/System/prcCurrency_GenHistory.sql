##########################################################################
CREATE PROCEDURE prcCurrency_GenHistory
				@FromDate		[DATETIME],
				@ToDate			[DATETIME],
				@UpdatePrev		[BIT],-- Update Previous Saved Value
				@UpdateMoreOne	[BIT],-- Update Previous Saved Value With PricePolicy
				@Warn			[BIT],-- if More Than One CurVal In One Day
				@PricePolicy	[INT], -- 0: Min, 1: Max, 2:Avr
				@CurGuid		[UNIQUEIDENTIFIER],
				@CurPolicy		[INT], --0: One Cur, 2: All Except One
				@ExpCurWarn		[BIT], -- 1: Show Warn For Excption Cur If Val <> 1, 0:Don't
				@Save			[BIT]	--	1: Store History In DataBase, 0: Don't Store
				,@LgGuid UNIQUEIDENTIFIER=0x0
AS				
	SET NOCOUNT ON
	DECLARE @Parms NVARCHAR(2000)
	SET @Parms =  'FromDate =' + CAST (@FromDate AS NVARCHAR(50)) + 
	+ CHAR(13) + 'ToDate =' + CAST (@ToDate AS NVARCHAR(50))
	+ CHAR(13) + 'UpdatePrev =' +ISNULL( CAST (@UpdatePrev AS NVARCHAR(10)),'')
	+ CHAR(13) + 'UpdateMoreOne =' + ISNULL(CAST (@UpdateMoreOne AS NVARCHAR(5)),'')	
	+ CHAR(13) + 'Warn =' + ISNULL(CAST (@Warn AS NVARCHAR(5)),'')			
	+ CHAR(13) + 'PricePolicy =' + ISNULL(CAST (@PricePolicy	 AS NVARCHAR(5)),'')	
	+ CHAR(13) + 'CurGuid =' + ISNULL(CAST (@CurGuid	 AS NVARCHAR(36)),'')	
	+ CHAR(13) + 'CurPolicy =' + ISNULL(CAST (@CurPolicy	 AS NVARCHAR(15)),'')			
	+ CHAR(13) + 'ExpCurWarn =' + ISNULL(CAST (@ExpCurWarn	 AS NVARCHAR(5)),'')	
	+ CHAR(13) + 'Save =' + ISNULL(CAST (@Save	 AS NVARCHAR(5)),'')	
		
	 --EXEC prcCreateMaintenanceLog 9,@LgGuid OUTPUT,@Parms
	DECLARE  
		@ceGuid			[UNIQUEIDENTIFIER],  
		@EnCurrencyPtr	[UNIQUEIDENTIFIER],  
		@EnCurrencyVal	[FLOAT], 
		@CrntCur		[UNIQUEIDENTIFIER], 
		@CurCnt			[INT], 
		@CanSave 		[INT], 
		@Val			[FLOAT], 
		@CurVal			[FLOAT], 
		@SumVal			[FLOAT], 
		@EnDate 		[DATETIME], 
		@CurDate 		[DATETIME], 
		@En_c			CURSOR 

	SET @Val = 0
	EXEC [prcCheckDB_initialize]  
	
	---- SCRIPT TO DELETE DUPLICATED CURRENCY VALUE IN THE SAME DAY --------------------
	IF (@UpdatePrev > 0)
	BEGIN
	SELECT DISTINCT date, currencyguid INTO #DuplicateTb FROM mh000 GROUP BY date, currencyguid  HAVING COUNT(date) > 1
	
	CREATE TABLE #temp
		(
			GUID uniqueidentifier,
			CurrencyGUID uniqueidentifier,
			CurrencyVal float,
			Date datetime
		)

	INSERT INTO  #temp
		SELECT GUID, mh.CurrencyGUID, CurrencyVal, mh.Date FROM mh000 AS mh
		INNER JOIN #DuplicateTb AS dt ON mh.date = dt.date AND mh.currencyguid = dt.currencyguid
	
	DELETE mh000 WHERE mh000.guid IN (SELECT GUID FROM #temp) 
	INSERT mh000 SELECT top 1 * FROM #temp
	END
	-----------------END DELETE DUPLICATED VALUE -----------------------------------------------------

	IF( @CurPolicy = 0) 
		SET @En_c = CURSOR FAST_FORWARD FOR 
			SELECT [ceGuid],[EnCurrencyPtr],[EnCurrencyVal],[EnDate] 
			FROM  [vwCeEn] 
			WHERE  
			[EnCurrencyPtr] = @CurGuid AND 
			[EnDate] BETWEEN @FromDate AND @ToDate 
			ORDER BY [EnCurrencyPtr],[EnDate],[ceNumber] 
	ELSE 
		SET @En_c = CURSOR FAST_FORWARD FOR 
			SELECT [ceGuid],[EnCurrencyPtr],[EnCurrencyVal],[EnDate] 
			FROM  [vwCeEn] 
			WHERE  
			[EnDate] BETWEEN @FromDate AND @ToDate 
			ORDER BY [EnCurrencyPtr], [EnDate], [ceNumber] 
	OPEN @En_c 
	FETCH FROM @En_c INTO @ceGuid, @EnCurrencyPtr, @EnCurrencyVal, @EnDate 
	IF(@@FETCH_STATUS = 0) 
	BEGIN 
		SET @Val = 0
		SET @CurCnt	= 1 
		SET @CanSave  = 1 
		SET @SumVal = @EnCurrencyVal 
		SET @CurVal = @EnCurrencyVal 
		SET @CrntCur = @EnCurrencyPtr 
		SET @CurDate = @EnDate 
		IF( @CurPolicy <> 0 AND @CurGuid = @CrntCur) 
		BEGIN 
			SET @CanSave  = 0 
			IF( @CurVal <> 1 AND @ExpCurWarn <> 0) 
				INSERT INTO [ErrorLog]([Type],[g1],[g2]) VALUES( 0x111, @EnCurrencyPtr, @ceGuid) 
		END 
	END 
	ELSE 
		RETURN 0 
	FETCH FROM @En_c INTO @ceGuid, @EnCurrencyPtr, @EnCurrencyVal, @EnDate 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF( @EnCurrencyPtr <> @CrntCur OR @CurDate <> @EnDate)   
		BEGIN 
			IF( @Save <> 0 AND @CanSave <> 0) 
			BEGIN 
				print 1
				IF EXISTS (SELECT * FROM [mh000] WHERE [CurrencyGUID]= @CrntCur AND [Date] = @CurDate) 
				BEGIN 
					print 11
					IF( @UpdatePrev	<> 0) 
					BEGIN
						print 2
						print @CurVal
						UPDATE [mh000] SET [CurrencyVal] = @CurVal WHERE [CurrencyGUID] = @CrntCur AND [Date] = @CurDate 
					END
				END 
				ELSE 
					INSERT INTO [mh000]( [CurrencyGUID], [CurrencyVal], [Date]) VALUES (@CrntCur, @Val, @CurDate) 
			END 
			SET @CurCnt	= 1 
			SET @SumVal = @EnCurrencyVal 
			SET @CurVal = @EnCurrencyVal 
			SET @CrntCur = @EnCurrencyPtr 
			SET @CurDate = @EnDate 
			SET @CanSave  = 1 
			IF( @CurPolicy <> 0 AND @CurGuid = @CrntCur) 
			BEGIN 
				SET @CanSave  = 0 
				IF( @CurVal <> 1 AND @ExpCurWarn <> 0) 
					INSERT INTO [ErrorLog]( [Type],[g1], [g2]) VALUES( 0x111, @EnCurrencyPtr, @ceGuid) 
			END 
		END 
		ELSE 
		BEGIN 
			SET @CurCnt	= @CurCnt + 1 
			SET @SumVal = @SumVal + @EnCurrencyVal 
			IF( @PricePolicy = 0) 
				IF( @EnCurrencyVal > @Val) 
					SET @Val = @EnCurrencyVal 
			IF( @PricePolicy = 1) 
				IF( @EnCurrencyVal < @Val) 
					SET @Val = @EnCurrencyVal 
			IF( @PricePolicy = 2) 
					SET @Val = @SumVal/@CurCnt 
			IF( @CurVal <> @EnCurrencyVal ) 
			BEGIN  
				IF( @UpdateMoreOne = 0) 
					SET @CanSave = 0 
				IF @Warn <> 0 
					INSERT INTO [ErrorLog]([Type],[g1],[g2]) VALUES( 0x110, @EnCurrencyPtr, @ceGuid) 
			END 
		END 
		FETCH FROM @En_c INTO @ceGuid, @EnCurrencyPtr, @EnCurrencyVal, @EnDate 
	END 
	CLOSE @En_c 
	DEALLOCATE @En_c 
	EXEC prcCloseMaintenanceLog @LgGuid
	EXEC [prcCheckDB_Finalize]  
##########################################################################
#END
