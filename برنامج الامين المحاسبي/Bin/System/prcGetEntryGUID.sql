#########################################################
CREATE PROCEDURE prcGetEntryGUID
	@EntryNumber [INT]
AS
SET NOCOUNT ON
SELECT [GUID] FROM [ce000] WHERE [number] = @EntryNumber
/*
EXEC prcGetEntryGUID 1
*/ 
#########################################################
#END