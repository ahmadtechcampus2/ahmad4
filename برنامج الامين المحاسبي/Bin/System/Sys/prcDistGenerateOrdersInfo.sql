############################################################## 
CREATE PROC prcDistGenerateOrdersInfo 
	@DistributorGUID uniqueidentifier
AS 
	SET NOCOUNT ON;
	
	--CREATE TABLE #DistOrderBu000(Guid UNIQUEIDENTIFIER, TypeGuid UNIQUEIDENTIFIER, DistributorGuid UNIQUEIDENTIFIER) 

	DECLARE @cursor CURSOR
	DECLARE @BillGuid UNIQUEIDENTIFIER,
			@BillTypeGuid UNIQUEIDENTIFIER

	SET @cursor = CURSOR FAST_FORWARD FOR 
	SELECT [Guid], [TypeGuid] FROM #DistOrderBu000 WHERE DistributorGuid = @DistributorGUID

	OPEN @cursor 
	FETCH NEXT FROM @cursor INTO @BillGuid, @BillTypeGuid
   
	WHILE @@FETCH_STATUS = 0
	BEGIN
			EXEC prcDistCheckOrdersStoreBalance	@BillGuid, @BillTypeGuid, @DistributorGUID
			EXEC prcSaveOrderInitiate			@BillGUID
			EXEC prcDistSaveOrderMsgReciver		@BillGUID, @DistributorGUID

	FETCH NEXT FROM @cursor INTO @BillGuid, @BillTypeGuid
	END
      
	CLOSE @cursor
	DEALLOCATE @cursor

	DELETE #DistOrderBu000
#################################################################
#END     