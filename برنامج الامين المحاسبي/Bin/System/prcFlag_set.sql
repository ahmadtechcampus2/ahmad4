###############################################################################
CREATE PROC prcFlag_set
	@flagID [INT]
AS
/*
this procedure:
	- sets a given flag
	- flagID values have the following meanings:
		1. reindexing is needed.
		100. prcBill_rePost is needed.
		1000. suppress raiserror from prcRaisError
		1001. suppress rollback from prcRaisError
*/


	BEGIN TRAN

	EXEC [prcFlag_reset] @flagID
	INSERT INTO [mc000] ([type],[number],[item]) VALUES (24, @flagID, 0) 

	COMMIT TRAN

###############################################################################
#END