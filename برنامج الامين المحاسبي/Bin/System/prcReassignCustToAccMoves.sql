#########################################################
CREATE PROCEDURE prcReassignCustToAccMoves 
@accGUID UNIQUEIDENTIFIER , @custGUID UNIQUEIDENTIFIER 
AS 

SET NOCOUNT ON
CREATE TABLE #ENTRY ([GUID] UNIQUEIDENTIFIER ) 
INSERT INTO #ENTRY  
	SELECT ce.[GUID] FROM ce000 ce   
	WHERE  EXISTS( SELECT GUID FROM en000 en WHERE en.AccountGUID = @accGUID
	AND en.ParentGUID = ce.GUID AND CustomerGUID != @custGUID AND IsPosted = 1   ) 


UPDATE ce 
	SET IsPosted = 0     
	FROM ce000 ce 
	INNER JOIN #ENTRY e 
	ON e.GUID = ce.GUID


UPDATE bu000 
	SET CustGUID = @custGUID 
	WHERE CustAccGUID = @accGUID 
	AND CustGUID = 0x0 

UPDATE en000 
	SET CustomerGUID = @custGUID    
	WHERE AccountGUID = @accGUID 
	AND CustomerGUID != @custGUID

UPDATE ce 
	SET IsPosted = 1     
	FROM ce000 ce 
	INNER JOIN #ENTRY e ON e.GUID = ce.GUID

UPDATE ch000 
	SET CustomerGuid = @custGUID
	WHERE AccountGUID = @accGUID 
	AND CustomerGuid != @custGUID

UPDATE ch000 
	SET EndorseCustGUID = @custGUID
	WHERE EndorseAccGUID = @accGUID 
	AND EndorseCustGUID != @custGUID

Update di000
	SET CustomerGuid = @custGUID
	WHERE AccountGUID = @accGUID 
	AND CustomerGuid != @custGUID

UPDATE Allocations000
	SET CustomerGUID = @custGUID 
	WHERE AccountGUID = @accGUID
	AND CustomerGuid != @custGUID

UPDATE Allocations000
	SET ContraCustomerGUID = @custGUID
	WHERE CounterAccountGuid = @accGUID 
	AND ContraCustomerGUID != @custGUID

UPDATE POSPayRecieveTable000 
	SET CustomerGUID = @custGUID 
	WHERE IIF(Type = 1 , FromAccGUID , ToAccGUID) = @accGUID 
	AND CustomerGuid != @custGUID


UPDATE RestEntry000 
	SET CustomerID = @custGUID 
	WHERE AccID = @accGUID 
	AND CustomerID != @custGUID

DROP TABLE #ENTRY
 
#########################################################	
#END