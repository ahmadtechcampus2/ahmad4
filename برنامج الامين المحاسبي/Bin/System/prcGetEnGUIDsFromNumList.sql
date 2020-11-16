#########################################################
CREATE PROCEDURE prcGetEnGUIDsFromNumList
	@DbName	[NVARCHAR](256),
	@EnList [NVARCHAR](2000)--1,2,3,5,8,7
AS

SET NOCOUNT ON
CREATE TABLE [#t]([Number] [SQL_VARIANT])
DECLARE @s [NVARCHAR](2000)
SET @s = ' INSERT INTO [#t] SELECT [Data] FROM ' + @DbName + '..[fnTextToRows]( ''' + @EnList + ''')'
EXECUTE(@s)

CREATE TABLE [#t2]([Number] [INT])
INSERT INTO [#t2] SELECT CONVERT( [INT], [number]) FROM [#t]

SET @s = ' SELECT ISNULL([ce].[GUID], 0x0) AS [GUID], [t].[Number] FROM ' + @DbName +'..[ce000] AS [ce] RIGHT JOIN [#t2] AS [t] ON [ce].[Number] = [t].[Number] ORDER BY [ce].[GUID]'
EXECUTE(@s)

/*
EXECUTE prcGetEnGUIDsFromNumList 'amndb242', '59,99,111'
SELECT ISNULL( ce.GUID, 0x0) AS GUID FROM amndb242..ce000 AS ce RIGHT JOIN #t2 AS t ON ce.Number = t.Number ORDER BY ce.GUID
*/
#########################################################
#END