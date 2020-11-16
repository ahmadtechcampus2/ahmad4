################################################################################
CREATE PROCEDURE prcPOSSD_Ticket_GetSpecialOffers
-- Params -------------------------------   
	@TicketGuid             UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @Lang INT = [dbo].[fnConnections_getLanguage]()

	DECLARE  @SpecialOfferMaterials TABLE( SpecialOfferName		NVARCHAR(250),
										   MaterialName			NVARCHAR(250),
										   Unit					NVARCHAR(250),
										   SpecialOfferType		INT,
										   Qty					FLOAT,
										   SpecialOfferQty		FLOAT,
										   Price				FLOAT,
										   UnitDiscount			FLOAT,
										   Discount				FLOAT )


	
	INSERT INTO @SpecialOfferMaterials
	SELECT 
		CASE @Lang WHEN 0 THEN SO.Name
				   ELSE CASE SO.LatinName WHEN '' THEN SO.Name 
										  ELSE SO.LatinName END END  AS SpecialOfferName,

		CASE @Lang WHEN 0 THEN MT.Name
				   ELSE CASE MT.LatinName WHEN '' THEN MT.Name 
										  ELSE MT.LatinName END END  AS MaterialName,

		CASE TI.UnitType WHEN 0 THEN MT.Unity
						 WHEN 1 THEN MT.Unit2
						 WHEN 2 THEN MT.Unit3 END  AS Unit,

		SO.[Type]					                AS SpecialOfferType,
		TI.Qty						                AS Qty,
		TI.SpecialOfferQty			                AS SpecialOfferQty,
		TI.Price					                AS Price,
		Disc.ValueToDiscount / TI.SpecialOfferQty   AS UnitDiscount,
		Disc.ValueToDiscount					    AS Discount

	FROM 
		POSSDTicketItem000 TI
		INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
		INNER JOIN POSSDSpecialOffer000 SO ON TI.SpecialOfferGUID = SO.[GUID]
		INNER JOIN mt000 MT ON TI.MatGUID = MT.[GUID]
		INNER JOIN dbo.fnPOSSD_Ticket_GetDiscountAndAddition(@TicketGuid) Disc ON Disc.[Guid] = TI.[GUID]
	WHERE 
		T.[GUID] = @TicketGuid


-- ⁄—Ê÷ «‰›ﬁ ÊŒ– Õ”„« --
	INSERT INTO @SpecialOfferMaterials
	SELECT 
		CASE @Lang WHEN 0 THEN SO.Name
				   ELSE CASE SO.LatinName WHEN '' THEN SO.Name 
										  ELSE SO.LatinName END END  AS SpecialOfferName,

		''							         AS MaterialName,
		''							         AS Unit,
		SO.[Type]					         AS SpecialOfferType,
		0						             AS Qty,
		0			                         AS SpecialOfferQty,
		0					                 AS Price,
		0							         AS UnitDiscount,
		SUM(Disc.ItemShareOfTotalDiscount)	 AS Discount

	FROM 
		 POSSDTicket000 T
		INNER JOIN POSSDSpecialOffer000 SO ON T.SpecialOfferGUID = SO.[GUID]
		INNER JOIN dbo.fnPOSSD_Ticket_GetDiscountAndAddition(@TicketGuid) Disc ON Disc.TicketGuid = T.[GUID]
	WHERE 
		T.[GUID] = @TicketGuid
	GROUP BY 
		SO.[Type],
		SO.Name,
		SO.LatinName

	---------- RESULTS ----------

	SELECT * FROM @SpecialOfferMaterials ORDER BY SpecialOfferType
	SELECT SUM(Discount) AS TotalDiscount FROM @SpecialOfferMaterials

#################################################################
#END
