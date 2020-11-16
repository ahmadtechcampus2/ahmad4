###########################################################################
CREATE FUNCTION fnColumnExists(@TableName NVARCHAR(128), @ColumnName NVARCHAR(128)) RETURNS BIT
AS BEGIN
	IF @TableName LIKE '#%' AND EXISTS(SELECT * FROM tempdb..syscolumns WHERE id = OBJECT_ID('tempdb..' + @TableName) AND Name = @ColumnName)
			RETURN 1 

	IF @TableName LIKE 'tempdb..#%' AND EXISTS(SELECT * FROM tempdb..syscolumns WHERE id = OBJECT_ID(@TableName) AND Name = @ColumnName)
			RETURN 1 
	
	IF EXISTS(SELECT * FROM syscolumns WHERE id = OBJECT_ID(@TableName) AND Name = @ColumnName)
		RETURN 1

	RETURN 0
END

###########################################################################
#END