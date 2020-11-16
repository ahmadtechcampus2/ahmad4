#########################################################
CREATE PROCEDURE prcRestoreTableIndexes

AS

SET NOCOUNT ON

DECLARE @CreateIndexCommand varchar(MAX)

DECLARE indexes_cursor CURSOR FOR  
SELECT IndexCreateSQL
FROM #Indexes

OPEN indexes_cursor   
FETCH NEXT FROM indexes_cursor INTO @CreateIndexCommand

WHILE @@FETCH_STATUS = 0   
BEGIN   
	
	execute (@CreateIndexCommand)
	
	FETCH NEXT FROM indexes_cursor INTO @CreateIndexCommand
END   

CLOSE indexes_cursor   
DEALLOCATE indexes_cursor 
#########################################################
#END