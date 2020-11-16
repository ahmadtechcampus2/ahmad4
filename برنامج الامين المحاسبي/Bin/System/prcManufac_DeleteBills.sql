######################################################### 
CREATE PROC prcManufac_deleteBills
	@ManufacGUID [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	DECLARE
		@c CURSOR,
		@g [UNIQUEIDENTIFIER]
	
	SET @c = CURSOR FAST_FORWARD FOR SELECT [BillGUID] FROM [mb000] WHERE [ManGUID] = @ManufacGUID

	OPEN @c FETCH FROM @c INTO @g
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcBill_Delete] @g
		FETCH FROM @c INTO @g
	END
	DELETE [mb000] WHERE [ManGUID] = @ManufacGUID
	CLOSE @c DEALLOCATE @c
#########################################################
#END