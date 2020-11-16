#########################################################
CREATE PROC prcPOSSD_POS_GetPayTypes
	@PosGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 

	DECLARE @result TABLE (
		Number INT,
		GUID UNIQUEIDENTIFIER,
		Code NVARCHAR (256) COLLATE ARABIC_CI_AI,
		Name NVARCHAR (256) COLLATE ARABIC_CI_AI,
		IsDefault BIT,
		IsCurrency BIT,
		IsForceVerificationNumber BIT)

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
		0
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
		CASE @lang 
			WHEN 0 THEN my.Name
			ELSE CASE my.LatinName WHEN '' THEN my.Name ELSE my.LatinName END 
		END,
		0, 
		1,
		0
	FROM 		
		POSCard000 pos
		INNER JOIN POSSDRelatedCurrencies000 pmy ON pos.GUID = pmy.POSGUID
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
		b.ForceVerificationNumber
	FROM 		
		POSCard000 pos
		INNER JOIN POSSDRelatedBankCards000 pb ON pos.GUID = pb.POSGUID
		INNER JOIN BankCard000 b ON b.GUID = pb.BankCardGUID 
	WHERE 
		pos.GUID = @PosGUID
	
	SELECT * FROM @result ORDER BY Number
#########################################################
#END
