#############################################
CREATE PROCEDURE prcPOSSD_POS_DeleteDetails
-- Param -------------------------------
	@POSGUID UNIQUEIDENTIFIER = 0x0
AS
    SET NOCOUNT ON
-----------------------------------------------------

	DELETE POSRelatedGroups000	      WHERE POSGuid     = @POSGUID
	DELETE POSCardDevice000			  WHERE POSCardGUID = @POSGUID
	DELETE POSRelatedEmployees000     WHERE POSGUID		= @POSGUID
	DELETE POSSDReturenedSales000     WHERE POSCardGUID = @POSGUID
	DELETE POSSDRelatedCurrencies000  WHERE POSGUID		= @POSGUID
	DELETE POSSDRelatedBankCards000   WHERE POSGUID		= @POSGUID
	DELETE POSSDRelatedPrintDesign000 WHERE POSCardGUID = @POSGUID
	DELETE POSSDOptions000			  WHERE POSGUID		= @POSGUID

##############################################
#END
