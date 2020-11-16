#####################################################################
CREATE VIEW vwPOSOrderItemsTempWithoutCanceled
AS
	SELECT * 
	FROM 
		POSOrderItemsTemp000 
	WHERE 
		[State] <> 1 AND SpecialOfferIndex <> 2 AND [Type] <> 1
#####################################################################
CREATE FUNCTION fnPOS_SO_GetAvailableOrderItems(@OrderGUID UNIQUEIDENTIFIER, @IsReturned BIT = 0)
	RETURNS TABLE 
AS
	RETURN (SELECT * 
	FROM 
		POSOrderItemsTemp000 
	WHERE 
		ParentID = @OrderGUID
		AND [State] != 1 -- AND SpecialOfferIndex != 2 
		AND (((@IsReturned = 0) AND (Type != 1)) OR ((@IsReturned = 1) AND (Type = 1))))
#####################################################################
#END
