


















































































































































#########################################################################
CREATE PROCEDURE prcPostPocketBill
	@billGuid uniqueidentifier
AS  
	SET NOCOUNT ON  
	DECLARE @UserName NVARCHAR(100)  
	 
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1   
	 
	EXEC prcConnections_add2 @UserName  
	 
	DECLARE	@DistAutoPost		BIT,  
		@DistAutoGenEntry 	BIT,  
		@btNoEntry 			BIT,  
		@btNoPost		 	BIT  
	 
	SELECT 	   
		@btNoEntry = bt.bNoEntry,  
		@btNoPost  = bt.bNoPost  
	FROM   
		bt000 bt
		INNER JOIN bu000 bu ON bt.Guid = bu.TypeGUID  
	WHERE   
		bu.Guid = @billGUID  
	
	
	IF (@btNoPost <> 1)    
	BEGIN   

		EXEC prcDisableTriggers 'mt000'
		EXEC prcDisableTriggers 'MS000'
		ALTER TABLE bu000 DISABLE TRIGGER  trg_bu000_CheckConstraintsExpireDate 
		 
		UPDATE BU000  
		SET Isposted = 1  
		WHERE GUID = @BillGUID  
		 
		ALTER TABLE mt000 ENABLE TRIGGER ALL 
		ALTER TABLE MS000 ENABLE TRIGGER ALL 
		ALTER TABLE bu000 ENABLE TRIGGER  trg_bu000_CheckConstraintsExpireDate 
	END   
	 
	IF (@btNoEntry <> 1)   
	BEGIN  
		EXEC prcDisableTriggers 'ce000'	 
		EXEC prcBill_genEntry @BillGUID 
		 
		ALTER TABLE ce000 ENABLE TRIGGER All 
	END
#########################################################################
#END