#########################################################
CREATE PROCEDURE prcGetTableStringColumns
	@TableID BIGINT
AS
	SET NOCOUNT ON

	SELECT 
		 c.column_id AS ColumnID,
		 c.name AS ColumnName,
		 c.is_nullable AS [ISNull],
		 t.name + '(' + CAST(c.max_length AS NVARCHAR(10)) + ')' AS SourceType,
		 CASE WHEN t.name = 'VARCHAR' THEN 'NVARCHAR(' + CASE WHEN c.max_length != -1  AND c.max_length <= 4000 THEN CAST(c.max_length AS NVARCHAR(10)) ELSE 'MAX' END + ')'
			  WHEN t.name = 'TEXT' THEN 'NVARCHAR(MAX)'--'NTEXT'
			  ELSE 'NCHAR('+ CASE WHEN c.max_length != -1 THEN CAST(c.max_length AS NVARCHAR(10)) ELSE 'MAX' END + ')'
		 END  AS UnicodeType
	FROM 
		sys.columns c
		INNER JOIN sys.types t ON c.system_type_id = t.system_type_id AND c.user_type_id = t.user_type_id
	WHERE 
		c.[object_id] = @TableID AND t.name IN ('char', 'varchar', 'text')
	--('CustomReport000', 'MaintenanceLog000', 'MaintenanceLogItem000', 'man_ActualStdAcc000', 'prh000') has text fields
	ORDER BY 
		  c.[object_id],
		  c.column_id
#########################################################
#END      