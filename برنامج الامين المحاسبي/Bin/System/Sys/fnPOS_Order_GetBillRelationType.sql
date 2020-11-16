###########################################################
CREATE FUNCTION fnPOS_Order_GetBillRelationType (@OrderGUID UNIQUEIDENTIFIER)
	RETURNS INT 
AS BEGIN  

	IF EXISTS (
		SELECT 1 
		FROM BillRel000 br
		WHERE 
			br.BillGUID IN (
				SELECT 
					br.BillGUID 
				FROM 
					POSOrder000 o
					INNER JOIN BillRel000 br ON o.GUID = br.ParentGUID
				WHERE o.GUID = @OrderGUID) 
			AND ParentGUID != @OrderGUID)
	BEGIN 
		RETURN 2 /*Merged*/
	END

	IF NOT EXISTS (
		SELECT * 
		FROM
			POSOrder000 o
			INNER JOIN BillRel000 br ON o.GUID = br.ParentGUID
			INNER JOIN bu000 bu ON bu.GUID = br.BillGUID
		WHERE o.GUID = @OrderGUID) 
	BEGIN 
		RETURN 1 /*NO BILL*/
	END 

	RETURN 0
END 
############################################################
#END