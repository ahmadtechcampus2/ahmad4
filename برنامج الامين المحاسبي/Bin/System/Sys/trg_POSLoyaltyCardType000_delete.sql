##################################################################################
CREATE TRIGGER trg_POSLoyaltyCardType000_delete ON POSLoyaltyCardType000 FOR DELETE
	NOT FOR REPLICATION
AS
	SET NOCOUNT ON 


	DELETE  
		POSLoyaltyCardTypeItem000 
	FROM 
		POSLoyaltyCardTypeItem000 lcti 
		INNER JOIN deleted d ON  lcti.ParentGUID = d.GUID  
##################################################################################
#END
