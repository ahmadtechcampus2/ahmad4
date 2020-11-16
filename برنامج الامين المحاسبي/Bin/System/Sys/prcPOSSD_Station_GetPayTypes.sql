#########################################################
CREATE PROC prcPOSSD_Station_GetPayTypes
	@PosGUID UNIQUEIDENTIFIER,
	@ShiftGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 

	DECLARE @result TABLE (
		Number INT,
		GUID UNIQUEIDENTIFIER,
		Code NVARCHAR (256) COLLATE ARABIC_CI_AI,
		Name NVARCHAR (256) COLLATE ARABIC_CI_AI,
		IsDefault BIT,
		IsCurrency BIT,
		IsForceVerificationNumber BIT,
		IsCoupon BIT)

	DECLARE @lang INT
	SET @lang = [dbo].[fnConnections_GetLanguage]()

	INSERT INTO @result
	SELECT TOP 1
		my.Number,
		my.GUID,
		my.Code,
		CASE @lang 
			WHEN 0 THEN my.Name
			ELSE CASE my.LatinName WHEN '' THEN my.Name ELSE my.LatinName END 
		END,
		1, 
		1,
		0,
		0
	FROM 		
		my000 my
	WHERE 
		my.CurrencyVal = 1
	ORDER BY my.Number

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

	INSERT INTO @StationCurrency
	EXEC prcPOSSD_Station_GetCurrencies @PosGUID ,@ShiftGUID

	INSERT INTO @result
	SELECT
		my.Number,
		my.GUID,
		my.Code,
		CASE @lang 
			WHEN 0 THEN my.Name
			ELSE CASE my.LatinName WHEN '' THEN my.Name ELSE my.LatinName END 
		END,
		0, 
		1,
		0,
		0
	 FROM 		
		POSSDStation000 pos
		INNER JOIN @StationCurrency pmy ON pos.GUID = pmy.StationGUID
		INNER JOIN my000 my ON my.GUID = pmy.CurGUID
	WHERE 
		pos.GUID = @PosGUID
	
	DECLARE @MaxNumber INT 
	SET @MaxNumber = ISNULL((SELECT MAX(Number) FROM @result), 0)

	INSERT INTO @result
	SELECT
		@MaxNumber + b.Number,
		b.GUID,
		CASE @lang 
			WHEN 0 THEN b.AbbrevName
			ELSE CASE b.AbbrevLatinName WHEN '' THEN b.AbbrevName ELSE b.AbbrevLatinName END 
		END,
		CASE @lang 
			WHEN 0 THEN b.Name
			ELSE CASE b.LatinName WHEN '' THEN b.Name ELSE b.LatinName END 
		END,
		0, 
		0,
		b.ForceVerificationNumber,
		0
	FROM 		
		POSSDStation000 pos
		INNER JOIN POSSDStationBankCard000 pb ON pos.GUID = pb.StationGUID
		INNER JOIN BankCard000 b ON b.GUID = pb.BankCardGUID 
	WHERE 
		pos.GUID = @PosGUID

	INSERT INTO @result
	SELECT 
		(SELECT MAX(Number) + 1 FROM @result), 
		SRCS.[GUID], 
		0,
		'Coupon',
		0,
		0,
		0,
		1
	FROM 
		POSSDStation000 POS
		INNER JOIN POSSDStationReturnCouponSettings000 SRCS ON POS.[GUID] = SRCS.StationGUID

	WHERE 
		POS.[GUID] = @PosGUID
		AND SRCS.[Type] = 0


	INSERT INTO @result
	SELECT 
		(SELECT MAX(Number) + 1 FROM @result), 
		SRCS.[GUID], 
		0,
		'Card',
		0,
		0,
		0,
		1
	FROM 
		POSSDStation000 POS
		INNER JOIN POSSDStationReturnCouponSettings000 SRCS ON POS.[GUID] = SRCS.StationGUID

	WHERE 
		POS.[GUID] = @PosGUID
		AND SRCS.[Type] = 1

	SELECT * FROM @result ORDER BY Number
#########################################################
#END
