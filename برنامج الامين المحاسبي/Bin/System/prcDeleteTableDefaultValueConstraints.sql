#########################################################
CREATE PROCEDURE prcDeleteTableDefaultValueConstraints

	@TableName VARCHAR(50)
AS

SET NOCOUNT ON


DECLARE @ContraintName varchar(100)

DECLARE @DropDefaultValueCommand varchar(300)

DECLARE defaultValueContraints_cursor CURSOR FOR  
SELECT ContraintName
FROM #defaultValuesConstraints

OPEN defaultValueContraints_cursor   
FETCH NEXT FROM defaultValueContraints_cursor INTO @ContraintName

WHILE @@FETCH_STATUS = 0   
BEGIN   
	
	SET @DropDefaultValueCommand = 'ALTER TABLE ' + @TableName + ' DROP CONSTRAINT ' + @ContraintName
	execute (@DropDefaultValueCommand)
	
	FETCH NEXT FROM defaultValueContraints_cursor INTO @ContraintName
END   

CLOSE defaultValueContraints_cursor   
DEALLOCATE defaultValueContraints_cursor 
#########################################################
#END
