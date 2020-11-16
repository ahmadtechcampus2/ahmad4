#########################################################
CREATE PROCEDURE prcGetTablesToBeConvertedUnicode
AS

SET NOCOUNT ON

	SELECT DISTINCT '[' + s.name + '].[' + t.name + ']' AS TableName, t.[object_id] TableID
	FROM 
		sys.tables t
		INNER JOIN sys.schemas s ON t.[schema_id] = s.[schema_id]
		INNER JOIN sys.columns c ON t.[object_id] = c.[object_id]
		INNER JOIN sys.types ty ON c.system_type_id = ty.system_type_id AND c.user_type_id = ty.user_type_id
	WHERE 
		t.[type] = 'U'
		AND 
		ty.name IN ('char', 'varchar', 'text')
		AND 
		LOWER(t.name) NOT LIKE '%rpl%'
	ORDER BY 
		[TableName]
#########################################################
#END
