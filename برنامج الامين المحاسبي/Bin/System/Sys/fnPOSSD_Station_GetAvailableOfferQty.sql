################################################################################
CREATE FUNCTION fnPOSSD_Station_GetAvailableOfferQty
(
   @offerGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @currentOfferQty FLOAT = 
			(	SELECT ISNULL(SUM(SpecialOfferQty), 0) 
				FROM POSSDTicket000 T 
				INNER JOIN  POSSDTicketItem000 TI ON T.GUID = TI.TicketGUID
				WHERE TI.SpecialOfferGUID = @offerGuid AND (T.State IN (0, 5, 6, 7)))

	DECLARE @offerExpireQty FLOAT = (SELECT ExpireQty FROM POSSDSpecialOffer000 WHERE GUID = @offerGuid)
	RETURN @offerExpireQty - @currentOfferQty
END 
#################################################################
CREATE FUNCTION fnPOSSD_Station_GetAvailableCountOfOfferToApplied
( @offerGuid UNIQUEIDENTIFIER )
RETURNS INT
AS
BEGIN

	DECLARE @Temp TABLE ( NumberOfSpecialOffer INT )
	DECLARE @SpecialOfferType INT = (SELECT [Type] FROM POSSDSpecialOffer000 WHERE [GUID] = @offerGuid)

	--============================== BOGO, BOGSE, bundle
	IF (@SpecialOfferType = 2 OR @SpecialOfferType = 5 OR @SpecialOfferType = 4)
	BEGIN

		INSERT INTO @Temp
		SELECT  dbo.fnPOSSD_SpecialOffer_GetNumberApplied(@offerGuid)

	END 
	ELSE
	BEGIN

		INSERT INTO @Temp
		SELECT 
			SUM(DISTINCT (ISNULL(TI.NumberOfSpecialOfferApplied, 0))) AS NumberOfSpecialOffer
		FROM 
			POSSDTicket000 T
			INNER JOIN  POSSDTicketItem000 TI ON T.[GUID] = TI.TicketGUID
		WHERE 
			TI.SpecialOfferGUID = @offerGuid  
			AND (T.[State] IN (0, 5, 6, 7))
		GROUP BY 
			T.[GUID]

	END


	DECLARE @NumberOfOfferApplied INT = (SELECT ISNULL(SUM(NumberOfSpecialOffer),0) FROM @Temp)
	DECLARE @ExpireQty INT = (SELECT ExpireQty FROM POSSDSpecialOffer000 WHERE guid = @offerGuid)
	DECLARE @Result INT = (@ExpireQty - @NumberOfOfferApplied)

	IF (@ExpireQty <= @NumberOfOfferApplied) 
		RETURN 0 

    RETURN  @Result

END 
#################################################################
CREATE FUNCTION fnPOSSD_Station_IsOfferStillAvailable
(
	@offerGuid UNIQUEIDENTIFIER,
	@Type INT
)
RETURNS BIT
AS
BEGIN 
	DECLARE @isStillAvailable BIT
	IF(@Type IN (1/*Discount*/, 3/*Slides*/))
	BEGIN
		SELECT @isStillAvailable = IIF((SELECT dbo.fnPOSSD_Station_GetAvailableOfferQty(@offerGuid)) = 0, 0, 1)
	END
	ELSE IF(@Type IN(2/*BOGO*/, 4/*BOGSE*/, 5/*Bundle*/, 7/*SGP*/))
	BEGIN
		SELECT @isStillAvailable = IIF((SELECT dbo.fnPOSSD_Station_GetAvailableCountOfOfferToApplied(@offerGuid)) = 0, 0, 1)
	END
	RETURN @isStillAvailable
END
#################################################################
#END
