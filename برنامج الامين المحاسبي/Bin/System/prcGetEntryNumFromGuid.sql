#########################################################
CREATE PROCEDURE prcGetEntryNumFromGuid
	@DbName	[NVARCHAR](256),
	@EntryGuid [UNIQUEIDENTIFIER]
AS
SET NOCOUNT ON
DECLARE @s [NVARCHAR](2000)
--SELECT Number FROM ce000 WHERE GUID = @EntryGuid
SET @s = ' SELECT [Number] FROM ' + @DbName  + '..[ce000] WHERE [GUID] = ''' + CONVERT( [NVARCHAR](1000), @EntryGuid) + ''''
-- SET @s = ' SELECT ISNULL(ce.GUID, 0x0) AS GUID, t.Number FROM ' + @DbName +'..ce000 AS ce RIGHT JOIN #t2 AS t ON ce.Number = t.Number ORDER BY ce.GUID'
print @s
EXECUTE( @s)
/*
EXEC prcGetEntryNumFromGuid
	'amndb242',--@DbName	NVARCHAR(256),
	0x0--@EntryGuid UNIQUEIDENTIFIER
*/

#########################################################
#END