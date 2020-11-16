################################################################################
CREATE FUNCTION fnGetDiscountMats (@DiscountID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE
	(	
		[GUID] [UNIQUEIDENTIFIER],
		[DiscountVal][FLOAT], 
		[DiscountType][INT]
	) 
AS
BEGIN 	
	INSERT INTO @Result SELECT 	
			ItemGuid,
			Value,
			DiscountType	
		FROM DiscountTypesItems000 
		WHERE (Type = 0) AND (ParentGuid = @DiscountID)

	INSERT INTO @Result SELECT 
			mt.GUID,
			Value,
			DiscountType	
		FROM DiscountTypesItems000 item inner join mt000 mt on mt.GroupGUID=item.ItemGUID
		WHERE item.ParentGuid = @DiscountID
	RETURN 
END
################################################################################
#END

