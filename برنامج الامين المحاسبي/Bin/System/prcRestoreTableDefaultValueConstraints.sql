#########################################################
CREATE PROCEDURE prcRestoreTableDefaultValueConstraints
	
	@TableName VARCHAR(100)

AS

SET NOCOUNT ON

DECLARE @ContraintName VARCHAR(100)
DECLARE @ColumnName VARCHAR(100)
DECLARE @DefaultValue VARCHAR(50)
DECLARE @RestoreDefaultValueCommand VARCHAR(300)

DECLARE defaultValueContraints_cursor CURSOR FOR  
SELECT ContraintName, ColumnName, DefaultValue
FROM #defaultValuesConstraints

OPEN defaultValueContraints_cursor   
FETCH NEXT FROM defaultValueContraints_cursor INTO @ContraintName, @ColumnName, @DefaultValue

WHILE @@FETCH_STATUS = 0   
BEGIN   
		
	SET @RestoreDefaultValueCommand = 'ALTER TABLE ' + @TableName + ' ADD CONSTRAINT ' + @ContraintName + ' DEFAULT ' + @DefaultValue + ' FOR [' + @ColumnName + ']'
	execute (@RestoreDefaultValueCommand)
	
	FETCH NEXT FROM defaultValueContraints_cursor INTO @ContraintName, @ColumnName, @DefaultValue
END   

CLOSE defaultValueContraints_cursor   
DEALLOCATE defaultValueContraints_cursor 
#########################################################
#END