#########################################################
CREATE FUNCTION fnIsBillRelatedToOrder(@BillGUID UNIQUEIDENTIFIER)
	RETURNS BIT 
AS BEGIN 
	DECLARE @IsRelated BIT 
	SET @IsRelated = 0

	-- POS 
	IF NOT EXISTS (SELECT * FROM FileOP000 WHERE Value = '0' AND Name ='AmnPOS_PreventModifyPOSBill')
	BEGIN 
		IF EXISTS (
			SELECT * 
			FROM 
				POSOrder000 ord 
				INNER JOIN BillRel000 br ON br.ParentGUID = ord.GUID 
				INNER JOIN bu000 bu ON bu.GUID = br.BillGUID 
			WHERE 
				bu.GUID = @BillGUID)

				SET @IsRelated = 1
	END 

	-- Rest
	IF @IsRelated = 1
		RETURN @IsRelated

	IF NOT EXISTS (SELECT * FROM FileOP000 WHERE Value = '0' AND Name ='AmnRest_PreventModifyRestBill')
	BEGIN 
		IF EXISTS (
			SELECT * 
			FROM 
				RestOrder000 ord 
				INNER JOIN BillRel000 br ON br.ParentGUID = ord.GUID 
				INNER JOIN bu000 bu ON bu.GUID = br.BillGUID 
			WHERE 
				bu.GUID = @BillGUID)

				SET @IsRelated = 1
	END 

	RETURN @IsRelated
END 
#########################################################
#END
