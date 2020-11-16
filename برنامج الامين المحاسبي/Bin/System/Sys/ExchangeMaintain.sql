#####################################################
CREATE Proc prcTrnReCalcExchangeAvg
	@ToDate	  DATETIME = '2100'
AS
	DECLARE @CurrencyGuid uniqueidentifier
	DECLARE curr_cur CURSOR FORWARD_ONLY FOR
	SELECT Guid From my000 order by  number
			
	OPEN curr_cur 
	FETCH NEXT FROM curr_cur INTO 
		@CurrencyGuid

	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		--select * from TrnCurrencyBalance000
		Delete From TrnCurrencyBalance000 where Currency = @CurrencyGuid
		insert into TrnCurrencyBalance000(Currency, CurBalance, CurrencyVal,[Date])
		SELECT
			@CurrencyGuid,
			CurBalance,
			CurAvg,
			ISNULL([DATE], '1980')
		 FROM FnTrnGetCurAverage2(@CurrencyGuid, @ToDate)
		FETCH NEXT FROM curr_cur INTO 
		@CurrencyGuid
 	END
	CLOSE curr_cur 
	DEALLOCATE curr_cur
################################################################################
CREATE PROC prcTrnExchangeReGenAvg
	@FromDate DATETIME = '',
	@ToDate DATETIME ='2050',
	@JustPay BIT = 1
AS
	DECLARE	@BaseCurrency UNIQUEIDENTIFIER,
		@Type INT,
		@GUID UNIQUEIDENTIFIER,
		@Date DATETIME,
		@EntryGUID UNIQUEIDENTIFIER,
		@IsSimpleExchange BIT

	-- Type = 1 Exchange, Type = 2 CloseCashier
	DECLARE @RegenerateTable TABLE(Type INT, [Date] DATETIME, 
	Number INT,Guid UNIQUEIDENTIFIER, EntryGuid UNIQUEIDENTIFIER, IsSimpleExchange BIT)
	
	--DELETE FROM TrnCurrencyBalance000
	EXEC prcTrnReCalcExchangeAvg @FromDate
	
	SELECT @BaseCurrency = dbo.fnGetExchangeLocalCurrency()
	
	INSERT INTO @RegenerateTable
	SELECT 
		1 AS Type,
		[Date],
		Number,
		GUID,
		EntryGuid,
		bSimple
	FROM TrnExchange000
	WHERE [Date] BETWEEN @FromDate AND @ToDate 
		AND (@JustPay = 0 OR  PayCurrency <> @BaseCurrency)

	UNION 
	SELECT 
		2 AS Type,
		[Date],
		Number,
		GUID,
		EntryGuid,
		0	
	FROM TrnCloseCashier000
	WHERE [Date] Between @FromDate AND @ToDate

	DECLARE regen_cursor CURSOR FOR
	SELECT 
		Type,
 		[Date],
		Guid,
		EntryGuid,
		IsSimpleExchange
	FROM @RegenerateTable
	ORDER BY [DATE], Number

	OPEN regen_cursor
	FETCH NEXT FROM regen_cursor INTO 
		@Type,
		@Date,
	        @GUID,
		@EntryGUID,
		@IsSimpleExchange

	WHILE  @@FETCH_STATUS = 0
	BEGIN
		IF (@Type = 1)
		BEGIN		
			IF (@IsSimpleExchange = 1)		
				EXEC prcGenExchangeEntryAvg @GUID, 3, 2
			ELSE
				EXEC PrcTrnExDetailedGenEntry @GUID, 3, 2
		END
		ELSE
		IF (@Type = 2)
			EXEC TrnGenCloseCashierGenEntry @GUID, 3

		FETCH NEXT FROM regen_cursor INTO
		@Type,
		@Date,
	        @GUID,
		@EntryGUID,
		@IsSimpleExchange
	END

CLOSE regen_cursor
DEALLOCATE regen_cursor

EXEC prcTrnReCalcExchangeAvg @ToDate

##############################################
CREATE PROC  prcTrnExchangeReGenCash
	@FromDate DATETIME = '',
	@ToDate DATETIME ='2050',
	@JustPay BIT = 1
AS

	DECLARE	@BaseCurrency UNIQUEIDENTIFIER,
			@Type INT,
			@GUID UNIQUEIDENTIFIER,
			@Date DATETIME,
			@EntryGUID UNIQUEIDENTIFIER,
			@IsSimpleExchange BIT

	-- Type = 1 Exchange, Type = 2 CloseCashier
	DECLARE @RegenerateTable TABLE(Type INT, [Date] DATETIME, 
	Number INT,Guid UNIQUEIDENTIFIER, EntryGuid UNIQUEIDENTIFIER, IsSimpleExchange BIT)
	
	SELECT @BaseCurrency = dbo.fnGetExchangeLocalCurrency()
	
	INSERT INTO @RegenerateTable
	SELECT 
		1 AS Type,
		[Date],
		Number,
		GUID,
		EntryGuid,
		bSimple
	FROM TrnExchange000
	WHERE [Date] BETWEEN @FromDate AND @ToDate 
		AND (@JustPay = 0 OR  PayCurrency <> @BaseCurrency)

	UNION 
	SELECT 
		2 AS Type,
		[Date],
		Number,
		GUID,
		EntryGuid,
		0	
	FROM TrnCloseCashier000
	WHERE [Date] Between @FromDate AND @ToDate
	
		
	DECLARE regen_cursor CURSOR FOR
	SELECT 
		Type,
 		[Date],
		Guid,
		EntryGuid,
		IsSimpleExchange
	FROM @RegenerateTable
	ORDER BY [DATE], Number
	OPEN regen_cursor
	FETCH NEXT FROM regen_cursor INTO 
		@Type,
		@Date,
	        @GUID,
		@EntryGUID,
		@IsSimpleExchange

	WHILE  @@FETCH_STATUS = 0
	BEGIN
		IF (@Type = 1)
		BEGIN		
			IF (@IsSimpleExchange = 1)		
				EXEC prcGenExchangeEntryAvg @GUID, 3, 1
			ELSE
				EXEC PrcTrnExDetailedGenEntry @GUID, 3, 1
		END
		ELSE
		IF (@Type = 2)
			EXEC TrnGenCloseCashierGenEntry @GUID, 3

		FETCH NEXT FROM regen_cursor INTO
		@Type,
		@Date,
	        @GUID,
		@EntryGUID,
		@IsSimpleExchange
	END

CLOSE regen_cursor
DEALLOCATE regen_cursor
##############################################
CREATE proc prcTrnExchangeReGenNormal
	@FromDate DATETIME = '',
	@ToDate DATETIME = '2100',
	@JustPay BIT = 1
AS
	DECLARE @Guid UNIQUEIDENTIFIER, 
			@EntryGuid UNIQUEIDENTIFIER,
			@BaseCurrency UNIQUEIDENTIFIER,
			@EntryNum INT,
			@IsSimpleExchange BIT	
	
	SELECT @BaseCurrency = dbo.fnGetExchangeLocalCurrency()
	
	DECLARE cur1 CURSOR FORWARD_ONLY FOR   
	
	SELECT 	Guid,
			EntryGuid,
			bSimple
			
	FROM TrnExchange000 AS e
	WHERE Date BETWEEN @FromDate AND @ToDate
	 	AND (@JustPay = 0 OR  PayCurrency <> @BaseCurrency)
	ORDER BY [DATE], number 

	OPEN cur1  
	FETCH NEXT FROM cur1 INTO  
			@Guid,
			@EntryGuid,
			@IsSimpleExchange	
	WHILE @@FETCH_STATUS = 0  
	BEGIN
		IF(@IsSimpleExchange = 1)
		BEGIN
			EXEC prcGenExchangeEntryAvg @Guid, 3, 0
		END	
		ELSE
		BEGIN
			EXEC PrcTrnExDetailedGenEntry @GUID, 3, 0
		END
		FETCH NEXT FROM cur1 INTO  
			@Guid,
			@EntryGuid,
			@IsSimpleExchange
	END
	CLOSE cur1  
	DEALLOCATE cur1 
#####################################################
CREATE PROC prcTrnReNumberExchangeVoucher
	@TypeGuid 				UNIQUEIDENTIFIER,
	@LastRight_ExchangeVoucherNumber 	INT
AS
CREATE TABLE #ExchangeTemp(GUID UNIQUEIDENTIFIER, ID INT IDENTITY(1, 1))
DECLARE @LastRight_ExchangeVoucherDate DATETIME

SELECT 
	@LastRight_ExchangeVoucherDate = [Date] 
FROM TrnExchange000 
WHERE TypeGuid = @TypeGuid AND Number = @LastRight_ExchangeVoucherNumber

INSERT INTO #ExchangeTemp(GUID)
SELECT 
	GUID 
FROM TrnExchange000 
WHERE TypeGuid = @TypeGuid AND [Date] > @LastRight_ExchangeVoucherDate
ORDER BY [Date]


UPDATE TrnExchange000
	SET Number = @LastRight_ExchangeVoucherNumber + ExTemp.[ID]  
FROM TrnExchange000 AS ex
INNER JOIN #ExchangeTemp AS ExTemp ON ExTemp.GUID = ex.GUID
#############################################################################
CREATE PROC prcTrnFixZeroExchangeVoucher
AS
	DECLARE @TypeGuid UNIQUEIDENTIFIER,
		@LastRightNumber INT	

	DECLARE exchangezeros CURSOR FOR 

	SELECT
		ex.TypeGuid,
		MAX(LastRigt.Number) AS LastNumberRight	
	FROM TrnExchange000 AS Ex 
	INNER JOIN TrnExchange000 AS LastRigt ON Ex.TypeGuid = LastRigt.TypeGuid AND LastRigt.[Date] < Ex.[Date]
	WHERE ex.GUID = 0X0 
	GROUP BY ex.TypeGuid
	
	OPEN exchangezeros
	FETCH NEXT FROM exchangezeros INTO 
		@TypeGuid,
		@LastRightNumber
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN  

		UPDATE TrnExchange000 
			SET Guid = NEWID()
			WHERE Guid = 0x0 AND TypeGuid = @TypeGuid 

		EXEC prcTrnReNumberExchangeVoucher @TypeGuid, @LastRightNumber
		
		FETCH NEXT FROM exchangezeros INTO 
			@TypeGuid,
			@LastRightNumber
	END

	CLOSE exchangezeros
	DEALLOCATE exchangezeros
#####################################################
CREATE PROC prcTrnReNumberExchange
	@SourceRepGuid UNIQUEidENTIFIER
AS
	DECLARE @TypeGuid UNIQUEidENTIFIER
	DECLARE ex_CURSOR  CURSOR FOR 
	SELECT 
		T.[Guid] 
	FROM TrnExchangetypes000 AS T
	INNER JOIN RepSrcs as ExType on ExType.IdType = T.[GUID] 
	WHERE ExType.IdTbl = @SourceRepGuid 
	ORDER BY T.[SortNum]
OPEN  ex_CURSOR
FETCH NEXT FROM ex_CURSOR INTO 
	@TypeGuid

	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		----------- Simple 
		CREATE TABLE #ExTemp_Simple(exGuid UNIQUEidENTIFIER, ID INT identity(1,1))
		INSERT INTO #ExTemp_Simple (exguid)
		SELECT Guid FROM Trnexchange000
			WHERE TypeGuid = @TypeGuid AND bSimple = 1	
			ORDER BY [DATE], NUMBER

		UPDATE ex
			SET ex.Number = t.[id]
		FROM #ExTemp_Simple  AS t
		INNER join Trnexchange000 AS ex ON t.exGuid = ex.Guid
		WHERE TypeGuid = @TypeGuid
		
		DROP TABLE #ExTemp_Simple		
		----------- NOT Simple, Complex
		CREATE TABLE #ExTemp_Complex(exGuid UNIQUEidENTIFIER, ID INT identity(1,1))
		INSERT INTO #ExTemp_Complex(exguid)
		SELECT Guid FROM Trnexchange000
			WHERE TypeGuid = @TypeGuid AND bSimple = 0
			ORDER BY [DATE], NUMBER
		
		UPDATE ex
			SET ex.Number = t.[id]
		FROM #ExTemp_Complex  AS t
		INNER join Trnexchange000 AS ex ON t.exGuid = ex.Guid
		WHERE TypeGuid = @TypeGuid

		DROP TABLE #ExTemp_Complex		

		FETCH NEXT FROM ex_CURSOR INTO 
		@TypeGuid
	END
CLOSE ex_CURSOR
DEALLOCATE ex_CURSOR
#####################################################
CREATE PROC TrnRecylceTransfer
	 @DestDBName	[NVARCHAR](255) -- ÇáãáÝ ÇáåÏÝ
AS
		-- ÇáÊÞÑíÈ
		EXEC [prcCopyTbl]  @DestDBName, TRNROUNDSETTING000
		-- ÍÓÇÈÇÊ ãÈíÚÇÊ ÇáÚãáÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TRNCURRENCYSELLSACC000
		-- ÃäãÇØ ÇáÕÑÇÝÉ
		EXEC [prcCopyTbl]  @DestDBName, TRNEXCHANGETYPES000
		-- ÃäãÇØ ÇáßÔæÝÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TRNSTATEMENTTYPES000
		-- ÅÚÏÇÏÇÊ ÇáãÓÊÎÏãíä
		EXEC [prcCopyTbl]  @DestDBName, TRNUSERCONFIG000
		-- ÃÞáÇã ÕäÇÏíÞ ÇáÚãáÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TRNCURRENCYACCOUNT000
		-- ÕäÇÏíÞ ÇáÚãáÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TRNGROUPCURRENCYACCOUNT000
		-- ÃÞáÇã ÃÌæÑ ÇáÍæÇáÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TRNWAGESITEM000
		-- ÃÌæÑ ÇáÍæÇáÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TRNWAGES000
		-- äãØ ÊæÒíÚ ÃÌæÑ ÇáÍæÇáÇÊ 
		EXEC [prcCopyTbl]  @DestDBName, TRNRATIO000
		-- ÅÚÏÇÏÇÊ ÃÌæÑ ÇáÍæÇáÇÊ æÊæÒíÚåÇ 
		EXEC [prcCopyTbl]  @DestDBName, TRNBRANCHSCONFIG000
		-- ÈØÇÞÉ ÝÑÚ
		EXEC [prcCopyTbl]  @DestDBName, TRNBRANCH000
		-- ÈØÇÞÉ ãßÊÈ
		EXEC [prcCopyTbl]  @DestDBName, TRNOFFICE000
		-- ÈØÇÞÉ ãÑßÒ ÍæÇáÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TRNCENTER000
		-- æÌåÉ ÍæÇáÉ
		EXEC [prcCopyTbl]  @DestDBName, TRNDESTINATION000
		-- ÇááÇÆÍÉ ÇáÓæÏÇÁ
		EXEC [prcCopyTbl]  @DestDBName, TRNBLACKLIST000
		-- ËæÇÈÊ ÇáÚãáÉ
		EXEC [prcCopyTbl]  @DestDBName, TRNCURRENCYCONSTVALUE000
		-- ÈØÇÞÉ ãÓÇåã
		EXEC [prcCopyTbl]  @DestDBName, TRNPARTICIPATOR000
		-- ÈØÇÞÉ ãÕÑÝ
		EXEC [prcCopyTbl]  @DestDBName, TRNBANK000
		-- ÕáÇÍíÇÊ ÃÓÚÇÑ ÇáÚãáÇÊ
		EXEC [prcCopyTbl]  @DestDBName, TrnCurrencyValRange000
		--- ÅÚÏÇÏÇÊ ÇáÊÑÞíã ÇáÊáÞÇÆí
		EXEC [prcCopyTbl]  @DestDBName, TRNAUTONUMBER000
		-- ÅíÕÇá ÍæÇáÉ
		EXEC [prcCopyTbl]  @DestDBName, TrnTransferVoucher000, ' GUID IN (SELECT Guid FROM FnTrnRecycleGetTransferVoucher()) '
		
		DECLARE @Str NVARCHAR(500)
		SET @Str = 'UPDATE ' + @DestDBName + '..[TrnTransferVoucher000] SET [IsRecycled] = 1'
		EXEC (@Str)
		
		-- äÔÑÉ ÇáÃÓÚÇÑ
		EXEC [prcCopyTbl]  @DestDBName, TRNMH000, ' GUID IN (SELECT Guid FROM fnTrnRecycleGetMh()) '
#####################################################
#END