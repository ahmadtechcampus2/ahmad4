#########################################################
CREATE FUNCTION fnNote_IsUsed(@ntGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([IsUsed] BIT, [IsUsedInRec] BIT, [IsUsedInPay] BIT, 
		[IsUsedForRecOrPay] BIT, [IsUsedForEndorse] BIT, [IsUsedForCollect] BIT, [IsUsedForDiscount] BIT)
AS BEGIN 
	INSERT INTO @Result SELECT 0, 0, 0, 0, 0, 0, 0
	IF EXISTS(SELECT * FROM ch000 WHERE TypeGUID = @ntGUID) 
	BEGIN 
		UPDATE @Result SET [IsUsed]  = 1
		IF EXISTS(SELECT * FROM ch000 WHERE TypeGUID = @ntGUID AND Dir = 1) 
			UPDATE @Result SET [IsUsedInRec] = 1
		IF EXISTS(SELECT * FROM ch000 WHERE TypeGUID = @ntGUID AND Dir = 2) 
			UPDATE @Result SET [IsUsedInPay] = 1
		IF EXISTS(SELECT * FROM ch000 ch INNER JOIN ChequeHistory000 chh ON ch.GUID = chh.ChequeGUID 
			WHERE ch.TypeGUID = @ntGUID AND ((chh.EventNumber = 0) OR (chh.EventNumber = 2)))
			UPDATE @Result SET [IsUsedForRecOrPay] = 1
		IF EXISTS(SELECT * FROM ch000 ch INNER JOIN ChequeHistory000 chh ON ch.GUID = chh.ChequeGUID 
			WHERE ch.TypeGUID = @ntGUID AND chh.EventNumber = 7)
			UPDATE @Result SET [IsUsedForEndorse] = 1
		IF EXISTS(SELECT * FROM ch000 ch INNER JOIN ChequeHistory000 chh ON ch.GUID = chh.ChequeGUID 
			WHERE ch.TypeGUID = @ntGUID AND chh.EventNumber = 14)
			UPDATE @Result SET [IsUsedForCollect] = 1
		IF EXISTS(SELECT * FROM ch000 ch INNER JOIN ChequeHistory000 chh ON ch.GUID = chh.ChequeGUID 
			WHERE ch.TypeGUID = @ntGUID AND chh.EventNumber = 21)
			UPDATE @Result SET [IsUsedForDiscount] = 1
	END 
	RETURN
END 

#########################################################
#END