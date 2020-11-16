#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetOpeningCash
@posGuid AS uniqueidentifier,
@rtl BIT
AS 
BEGIN
   DECLARE	@lastShiftGuid [uniqueidentifier]
   DECLARE	@LatFlostCash TABLE (CurrenceyGUID uniqueidentifier, CurrenceyName NVARCHAR(256), OpeningCash FLOAT)
   
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
    
	SET @lastShiftGuid = (SELECT [GUID] From POSSDShift000 ps WHERE StationGUID = @posGuid 
	                             AND CloseDate = (SELECT MAX(CloseDate) From POSSDShift000 ps WHERE StationGUID = @posGuid))
	
	INSERT INTO @LatFlostCash 
     SELECT PRC.CurGUID
	        ,(SELECT CASE @rtl WHEN 1 THEN Name ELSE (CASE LatinName WHEN '' THEN Name ELSE LatinName END) END  FROM my000 WHERE Guid = PRC.CurGUID)
			,ISNULL(FloatCash , 0)
	 FROM @RelatedCurrencies PRC 
	 LEFT JOIN POSSDShiftCashCurrency000 SC 
	 ON PRC.CurGUID = SC.CurrencyGUID AND SC.ShiftGUID = @lastShiftGuid
	
	SELECT * FROM @LatFlostCash
END
#################################################################
#END 