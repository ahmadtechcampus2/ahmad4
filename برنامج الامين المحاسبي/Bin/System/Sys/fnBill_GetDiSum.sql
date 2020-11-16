############################################################################
CREATE function fnBill_GetDiSum(@BuGUID UNIQUEIDENTIFIER)
	RETURNS @Result TABLE(Discount FLOAT, Extra FLOAT)
AS BEGIN 
	INSERT INTO @Result(Discount, Extra)
	SELECT 
		SUM(Discount),
		SUM(Extra)
	FROM 
		di000 
	WHERE ParentGUID = @BuGUID
	RETURN
END 
############################################################################
#END
