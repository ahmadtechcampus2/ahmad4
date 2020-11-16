###########################################################################
CREATE FUNCTION fnGetTriggerEvent(@CountInserted [INT], @CountDeleted [INT])
	RETURNS [INT]
AS BEGIN
/*
This function:
	- return takes the number of inserted and deleted recods, and returns an integer representing an event.
	- returns integer:
		-1: no records where inserted, deleted or updated.
		0: insert.
		1: update.
		2: delete.
	- is usually called from triggers.

*/
	IF (@CountDeleted <> 0) AND (@CountInserted <> 0)
		RETURN 1

	IF (@CountDeleted <> 0)
		RETURN 2

	IF (@CountInserted <> 0)
		RETURN 0

	-- both parameters are 0
	RETURN -1
END

###########################################################################
#END