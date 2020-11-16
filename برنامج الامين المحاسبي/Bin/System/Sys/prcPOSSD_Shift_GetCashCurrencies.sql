#########################################################
CREATE PROC prcPOSSD_Shift_GetCashCurrencies
	@ShiftGUID UNIQUEIDENTIFIER
AS
    SET NOCOUNT ON 


    DECLARE @result TABLE (
        CurrencyNumber        INT,
        CurrencyGUID        UNIQUEIDENTIFIER,
        CurrencyCode        NVARCHAR (256) COLLATE ARABIC_CI_AI,
        CurrencyName        NVARCHAR (256) COLLATE ARABIC_CI_AI,
        CurrencyLatinName    NVARCHAR (256) COLLATE ARABIC_CI_AI,
        IsDefaultCurrency    BIT,
        OpeningCash            FLOAT,
        OpeningCashCurVal    FLOAT,
        ContinuesCash        FLOAT,
        ContinuesCashCurVal FLOAT)
    


    select CurrencyGUID, CurrencyValue, Amount
    into #ExternalOperation
    from POSSDExternalOperation000
    where IsPayment = 0 AND [Type] = 0 AND ShiftGUID = @ShiftGUID


	DECLARE @StationCurrency TABLE 
	(	CurGUID				UNIQUEIDENTIFIER,
        CurCode				NVARCHAR (256),
        CurName				NVARCHAR (256),
		CurrNumber			INT,
		CurrencyVal			FLOAT,
		PartName			NVARCHAR (256),
		LatinName			NVARCHAR (256),
		LatinPartName		NVARCHAR (256),
		PictureGUID			UNIQUEIDENTIFIER,
		ExtendCurrency		UNIQUEIDENTIFIER,
		StationGUID			UNIQUEIDENTIFIER,
		IsUsed				BIT,
		CentralBoxAccGUID   UNIQUEIDENTIFIER,
		FloatCachAccGUID    UNIQUEIDENTIFIER,
		IsDefault		    BIT
	)

	DECLARE @StationGuid [UNIQUEIDENTIFIER] = (SELECT StationGUID FROM POSSDShift000 WHERE [GUID] = @ShiftGUID)
	INSERT INTO @StationCurrency
	EXEC prcPOSSD_Station_GetCurrencies @StationGuid ,@ShiftGUID

    --========================== Insert Currencies
    INSERT INTO @result
    SELECT TOP 1
        my.Number,
        my.GUID,
        my.Code,
        my.Name,
        my.LatinName,
        1, 
        0, 1, 0, 1
    FROM         
        my000 my
    WHERE 
        my.CurrencyVal = 1
    ORDER BY my.Number


    INSERT INTO @result
    SELECT
        my.Number,
        my.GUID,
        my.Code,
        my.Name,
        my.LatinName,
        0,
        0, 0, 0, 0
    FROM         
        POSSDShift000 sh
        INNER JOIN POSSDStation000 pos ON pos.GUID = sh.StationGUID 
        INNER JOIN @StationCurrency pmy ON pos.GUID = pmy.StationGUID
        INNER JOIN my000 my ON my.GUID = pmy.CurGUID
    WHERE 
        sh.[GUID] = @ShiftGUID
    ORDER BY my.Number


    UPDATE @result
    SET 
        OpeningCash = ISNULL(EX.Amount, 0),
        OpeningCashCurVal = CASE my.IsDefaultCurrency WHEN 1 THEN 1 ELSE ISNULL(EX.CurrencyValue, 0) END,
        ContinuesCash = ISNULL(cu.FloatCash, 0),
        ContinuesCashCurVal = CASE my.IsDefaultCurrency WHEN 1 THEN 1 ELSE ISNULL(cu.FloatCashCurVal, 0) END
    FROM 
        @result my
        INNER JOIN POSSDShiftCashCurrency000 cu ON cu.CurrencyGUID = my.CurrencyGUID
        LEFT JOIN #ExternalOperation EX ON EX.CurrencyGUID = cu.CurrencyGUID
        WHERE cu.ShiftGUID = @ShiftGUID


    SELECT * FROM @result ORDER BY CurrencyNumber
#########################################################
#END
