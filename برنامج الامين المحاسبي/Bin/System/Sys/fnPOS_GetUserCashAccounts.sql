################################################################################
CREATE FUNCTION fnPOS_GetUserCashAccounts(@userid [UNIQUEIDENTIFIER])
RETURNS TABLE
AS
RETURN 
		(
			SELECT * FROM vbAc  
			WHERE EXISTS(SELECT 1 FROM POSCurrencyItem000 ci  WHERE 
			vbAc.GUID = ci.CashAccID AND  UserID = @userid  )
		)
	    
################################################################################
#END

