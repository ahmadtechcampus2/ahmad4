######################################################
CREATE TRIGGER trg_BillRel000_delete ON [BillRel000] FOR DELETE 
	NOT FOR REPLICATION

AS 
	SET NOCOUNT ON 
	DECLARE 
		@c CURSOR, 
		@g [UNIQUEIDENTIFIER]
	 
	SET @c = CURSOR fast_forward FOR SELECT [BillGUID] FROM [deleted]
	OPEN @c FETCH FROM @c INTO @g 
	 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		EXEC [prcBill_delete] @g 
		FETCH FROM @c INTO @g 
	END 
	 
	CLOSE @c DEALLOCATE @c 

#######################################################
#END