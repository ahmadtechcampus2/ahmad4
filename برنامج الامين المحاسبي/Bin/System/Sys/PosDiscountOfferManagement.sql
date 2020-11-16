######################################
CREATE PROCEDURE prcAddPOSDiscountOffer
    @ID				UNIQUEIDENTIFIER,
	@OfferName		NVARCHAR(200),
	@OfferLatinName		NVARCHAR(200),
	@StartDate Date,
	@EndDate Date,
	@Note    NVARCHAR(500),
	@StartValue FLOAT,
	@EndValue FLOAT,
	@DiscountType INT,
	@DiscountValue FLOAT,
	@SecLevel INT      
AS
BEGIN
    SET NOCOUNT ON

	IF EXISTS( SELECT * FROM POSOfferDiscount000 WHERE (@StartDate <= EndDate)  AND  (@EndDate >= StartDate) AND (@StartValue <= EndValue)  AND  (@EndValue >= BeginValue))
	BEGIN
		RETURN 0
	END
	ELSE
	BEGIN
		DECLARE @Number AS INT
		SELECT @Number = ISNULL(MAX(Number), 0) + 1 FROM POSOfferDiscount000
		
		INSERT INTO POSOfferDiscount000
		(
			[GUID],
			Number,
			OfferDiscName,
			OfferLatinName,
			StartDate,
			EndDate,
			BeginValue,
			EndValue,
			DiscType,
			DiscValue,
			[Security]
		)
		VALUES
		(
			NEWID(),
			@Number,
			@OfferName,
			@OfferLatinName,
			@StartDate,
			@EndDate,
			@StartValue,
			@EndValue,
			@DiscountType,
			@DiscountValue,
			@SecLevel	
		)
		RETURN 1
	END
END
######################################
CREATE PROCEDURE prcUpdatePOSDiscountOffer
    @ID				UNIQUEIDENTIFIER,
	@OfferName		NVARCHAR(200),
	@OfferLatinName		NVARCHAR(200),
	@StartDate Date,
	@EndDate Date,
	@Note    NVARCHAR(500),
	@StartValue FLOAT,
	@EndValue FLOAT,
	@DiscountType INT,
	@DiscountValue FLOAT,
	@SecLevel INT      
AS
BEGIN
    SET NOCOUNT ON

	IF EXISTS( SELECT * FROM POSOfferDiscount000 WHERE ([GUID] != @ID) AND (@StartDate <= EndDate)  AND  (@EndDate >= StartDate) AND (@StartValue <= EndValue)  AND  (@EndValue >= BeginValue))
	BEGIN
		RETURN 0
	END
	ELSE
	BEGIN

		UPDATE POSOfferDiscount000
		SET
			OfferDiscName = @OfferName,
			OfferLatinName = @OfferLatinName,
			StartDate = @StartDate,
			EndDate = @EndDate,
			BeginValue = @StartValue,
			EndValue = @EndValue,
			DiscType = @DiscountType,
			DiscValue = @DiscountValue,
			[Security] = @SecLevel
		WHERE 
			[GUID] = @ID
		
		RETURN 1
	END
END
######################################
#END