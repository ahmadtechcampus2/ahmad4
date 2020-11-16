#########################################################
CREATE PROC prcBill_rePostSN
	@hushed [BIT] = 0
AS
/*
This procedure;
	- repost SN.
	- is usually called from prcBill_rePostSN.
*/
	SET NOCOUNT ON
	
	DECLARE
		@c CURSOR,
		@buGuid [UNIQUEIDENTIFIER]

	-- check if needed:
	IF NOT EXISTS(SELECT * FROM [sn000])
		RETURN

	SET @c = CURSOR FAST_FORWARD FOR 
					SELECT [buGuid] 
					FROM [vwBu] 
					WHERE [buIsPosted] <> 0
					ORDER BY [buDate],[buSortFlag],[buNumber]

	OPEN @c FETCH FROM @c INTO @buGuid

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcBill_postSn] @buGuid
		FETCH FROM @c INTO @buGuid
	END

	CLOSE @c DEALLOCATE @c

######################################################### 
#END