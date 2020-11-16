############################################################################
CREATE PROCEDURE prcCopyCustomFields @OriginalGuid UNIQUEIDENTIFIER
	, @NewGuid UNIQUEIDENTIFIER
	, @Original_Table nvarchar(100)
AS
/*
-AUTHER: Abdulkareem Attiya.
-This Procedure we can used it for all types related  with custom fiels groups , material ,bills , Orders, ...etc
-We can copy custom fields from card to the same card .
-Depends on @Original_Table as type of card relationship with custom fiels group.
*/
SET NOCOUNT ON;
DECLARE @tble NVARCHAR(MAX)

SELECT @tble = map.CFGroup_Table
FROM CFMapping000 map
WHERE map.Orginal_Table = @Original_Table

SELECT @tble

DECLARE @sql NVARCHAR(MAX)

SET @sql = ' SELECT * into #Temp from ' + @tble 
			+ ' where Orginal_Guid = ''' + CAST(@OriginalGuid AS NVARCHAR(50)) + ''' ; ' 
			+ ' UPDATE #Temp 
				SET [guid] = NEWID() 
							, Orginal_Guid = ''' + CAST(@NewGuid AS NVARCHAR(50)) + ''' ; '
			+ ' INSERT INTO ' + @tble 
		    + ' select * from #TEmp ; ' 
			-- For Test + ' select * from ' + @tble

--PRINT @sql

EXEC (@sql)
############################################################################
#END

