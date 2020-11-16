#################################################################
CREATE PROC prcPDABilling_PostBill
	@BillGUID uniqueidentifier, 
	@PDAGuid  uniqueidentifier 
AS  
	SET NOCOUNT ON 
	
	DECLARE @UserName NVARCHAR(100) 
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1  
	EXEC prcConnections_add2 @UserName 
	
	DECLARE	@AutoPost		BIT, 
			@AutoGenEntry 	BIT, 
			@btNoEntry 		BIT, 
			@btNoPost		BIT 
	SELECT 	  
		@btNoEntry = bNoEntry, 
		@btNoPost  = bNoPost 
	FROM  
		bu000 AS bu 
		INNER JOIN bt000 AS bt ON bt.Guid = bu.TypeGUID 
	WHERE  
		bu.Guid = @billGUID 

	SET @AutoPost = 0
	SET @AutoGenEntry = 0
/*
	SELECT  
		@DistAutoPost = AutoPostBill,  
		@DistAutoGenEntry = AutoGenBillEntry  
	FROM  
		Distributor000  
	WHERE  
		GUID = @DistributorGUID  
*/
	IF (@AutoPost <> 0 AND @btNoPost <> 1)   
	BEGIN  
		UPDATE BU000 SET Isposted = 1 WHERE GUID = @BillGUID   
		-- EXEC prcBill_Post @BillGuid, 1  
	END  
	IF (@AutoGenEntry <> 0 AND @btNoEntry <> 1)  
		EXEC prcBill_genEntry @BillGUID  
-- Exec prcPDABilling_PostBill 0x00, 0x00
#################################################################
#END