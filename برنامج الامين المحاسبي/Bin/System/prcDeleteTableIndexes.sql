#########################################################
CREATE PROCEDURE prcDeleteTableIndexes

AS

SET NOCOUNT ON

DECLARE @DropIndexCommand varchar(300)

DECLARE indexes_cursor CURSOR FOR  
SELECT IndexDropSQL
FROM #Indexes

OPEN indexes_cursor   
FETCH NEXT FROM indexes_cursor INTO @DropIndexCommand

WHILE @@FETCH_STATUS = 0   
BEGIN   

	execute(@DropIndexCommand)
	
	FETCH NEXT FROM indexes_cursor INTO @DropIndexCommand
END   

CLOSE indexes_cursor   
DEALLOCATE indexes_cursor 
#########################################################
#END