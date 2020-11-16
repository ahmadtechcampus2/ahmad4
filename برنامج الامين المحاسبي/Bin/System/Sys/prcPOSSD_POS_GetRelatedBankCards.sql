#################################################################
CREATE PROCEDURE prcPOSSDGetRelatedBankCards
-- Param -------------------------------   
	   @PosGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
    SET NOCOUNT ON
------------------------------------------------------------------------
 SELECT BC.*, 
		RC.POSGuid,
		RC.Used
 FROM BankCard000 BC 
      LEFT JOIN POSSDRelatedBankCards000 RC
      ON BC.GUID = RC.BankCardGUID AND  POSGuid = @PosGuid 
 WHERE Used = 1	   
 ORDER BY Number
END
#################################################################
#END 