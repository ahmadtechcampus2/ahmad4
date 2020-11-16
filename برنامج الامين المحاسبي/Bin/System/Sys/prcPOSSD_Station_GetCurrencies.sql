#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCurrencies
	@StationGUID UNIQUEIDENTIFIER,
	@ShiftGUID UNIQUEIDENTIFIER = Null
AS
    SET NOCOUNT ON

	DECLARE @NotUsedCurrency TABLE ([CurrencyGUID]		[UNIQUEIDENTIFIER])

	DECLARE @ForcedSyncCurrencies TABLE ([CurrencyGUID]	[UNIQUEIDENTIFIER])

	DECLARE @TempCurrencies TABLE (
									[GUID]	[UNIQUEIDENTIFIER],									
									[StationGUID]	[UNIQUEIDENTIFIER],
									[CurrencyGUID]	[UNIQUEIDENTIFIER],
									[IsUsed]         [BIT] ,
									[CentralBoxAccGUID] [UNIQUEIDENTIFIER],
									[FloatCachAccGUID]	[UNIQUEIDENTIFIER]
									)
	IF(@ShiftGUID IS NULL)
	BEGIN
		SET @ShiftGUID  = (SELECT TOP 1(Guid) FROM POSSDShift000
												 WHERE StationGUID = @StationGUID
											     ORDER BY OpenDate DESC)
	END
	INSERT INTO @NotUsedCurrency
		SELECT sc.CurrencyGUID
		FROM POSSDExtendStationCurrency000 sc
			LEFT JOIN POSSDStationCurrency000 possc ON possc.CurrencyGUID = sc.CurrencyGUID AND possc.StationGUID = @StationGUID
			WHERE possc.GUID IS NULL

	INSERT INTO @ForcedSyncCurrencies
		SELECT sc.CurrencyGUID 
		FROM @NotUsedCurrency sc		
			INNER JOIN POSSDTicketCurrency000 tc ON tc.CurrencyGUID = sc.CurrencyGUID 
			INNER JOIN POSSDTicket000 t on t.GUID = tc.TicketGUID AND t.ShiftGUID = @ShiftGUID
			GROUP BY sc.CurrencyGUID				
		UNION
		SELECT sc.CurrencyGUID
		FROM @NotUsedCurrency sc							
			INNER JOIN POSSDExternalOperation000  exop ON EXOP.CurrencyGUID = sc.CurrencyGUID AND exop.ShiftGUID = @ShiftGUID  		
		GROUP BY sc.CurrencyGUID
			

	INSERT INTO @TempCurrencies
	SELECT 
		excur.GUID,
		excur.StationGUID,
		excur.CurrencyGUID,
		1,
		excur.CentralBoxAccGUID,
		excur.FloatCachAccGUID 
	FROM @ForcedSyncCurrencies fs
		INNER JOIN POSSDExtendStationCurrency000 excur ON fs.CurrencyGUID = excur.CurrencyGUID AND excur.StationGUID = @StationGUID
	UNION 
	SELECT * FROM POSSDStationCurrency000 WHERE StationGUID = @StationGUID

	SELECT 
		my.GUID CurGUID,
		MY.Code, Name,Number,
		CASE WHEN mh.CurrencyVal IS NOT NULL THEN mh.CurrencyVal ELSE my.CurrencyVal END CurrencyVal,
		PartName,
		LatinName,
		LatinPartName,
		PictureGUID, 
		RC.GUID,
		RC.StationGUID,
		RC.IsUsed,
		RC.CentralBoxAccGUID,
		RC.FloatCachAccGUID,
		CAST((CASE my.CurrencyVal WHEN 1 THEN 1 ELSE 0 END) AS BIT) AS IsDefault
	 FROM my000 my 
		  LEFT JOIN mh000 mh ON my.GUID = mh.CurrencyGUID 
		  LEFT JOIN @TempCurrencies RC ON my.GUID = RC.CurrencyGUID AND StationGUID = @StationGUID
	 WHERE (RC.IsUsed = 1 OR my.CurrencyVal = 1) 
			AND (EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID) 
				  AND (mh.Date = (SELECT MAX ([Date]) FROM mh000 mhe GROUP BY CurrencyGUID HAVING CurrencyGUID = mh.CurrencyGUID )) 
				  OR (NOT EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID)))
	 ORDER BY Number
#################################################################
#END 