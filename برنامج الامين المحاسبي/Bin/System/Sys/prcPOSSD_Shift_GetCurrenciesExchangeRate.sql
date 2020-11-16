#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetCurrenciesExchangeRate
@shiftGuid UNIQUEIDENTIFIER,
@rtl BIT

AS 
BEGIN
	DECLARE @posGuid UNIQUEIDENTIFIER = (SELECT StationGUID FROM POSSDShift000 WHERE [GUID] = @shiftGuid);
	DECLARE @sumCurrencyValue FLOAT,
	        @sumCurrEquilavent FLOAT,
		    @curGUID UNIQUEIDENTIFIER,
			@defaultCurGUID UNIQUEIDENTIFIER = (SELECT [dbo].[fnGetDefaultCurr]()),
			@currName  NVARCHAR(256), @CurrencyName NVARCHAR(256),
			@currLatinName  NVARCHAR(256)

	DECLARE @CurrCash TABLE (CurrGUID UNIQUEIDENTIFIER, ExchangeAverage FLOAT, ExpectedCash FLOAT, CurrencyName NVARCHAR(256))
	
	DECLARE @RelatedCurrencies TABLE (CurGUID UNIQUEIDENTIFIER,
			Code NVARCHAR(256), Name NVARCHAR(256),Number INT,
			CurrencyVal FLOAT,
			PartName NVARCHAR(256),
			LatinName NVARCHAR(256),
			LatinPartName NVARCHAR(256),
			PictureGUID UNIQUEIDENTIFIER, 
			GUID UNIQUEIDENTIFIER,
			POSGuid UNIQUEIDENTIFIER,
			Used BIT,
			CentralBoxAccGUID UNIQUEIDENTIFIER,
			FloatCachAccGUID UNIQUEIDENTIFIER,
			IsDefault BIT)

	INSERT INTO @RelatedCurrencies
	 EXEC prcPOSSD_Station_GetCurrencies @posGuid

	DECLARE curr_cursor CURSOR FOR  
		SELECT CurGUID, Name, LatinName FROM @RelatedCurrencies 

	OPEN curr_cursor   
		FETCH NEXT FROM curr_cursor INTO @curGUID, @currName, @currLatinName

		WHILE @@FETCH_STATUS = 0   
		BEGIN  
		       
			   SET @sumCurrencyValue = (SELECT [dbo].fnPOSSD_Shift_GetShiftCash(@shiftGuid, @curGUID, DEFAULT))
			   SET @sumCurrEquilavent = (SELECT [dbo].fnPOSSD_Shift_GetShiftCash(@shiftGuid, @curGUID, 1))
               SET @CurrencyName = CASE @rtl WHEN 1 THEN @currName ELSE (CASE @currLatinName WHEN '' THEN @currName ELSE @currLatinName END) END 
			   
			   IF (@sumCurrencyValue = 0 AND @curGUID = @defaultCurGUID)
			   BEGIN
			     INSERT INTO @CurrCash VALUES (@curGUID, 1, @sumCurrencyValue, @CurrencyName)
			   END
			   ELSE
			   BEGIN
				IF (@sumCurrencyValue <> 0)
					INSERT INTO @CurrCash VALUES (@curGUID, @sumCurrEquilavent/@sumCurrencyValue, @sumCurrencyValue, @CurrencyName)
			   END
			FETCH NEXT FROM curr_cursor INTO @curGUID, @currName, @currLatinName
		END   

	CLOSE curr_cursor   
	DEALLOCATE curr_cursor

	SELECT * FROM @CurrCash

END
#################################################################
#END 