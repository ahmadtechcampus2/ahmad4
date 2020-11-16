#########################################################
CREATE PROC prcDropUserDefinedTypeDependencies
	@typeName NVARCHAR(50)
AS
BEGIN
	DECLARE @dependentName VARCHAR(100)
	DECLARE cur CURSOR 

	FOR SELECT SPECIFIC_NAME FROM  Information_Schema.PARAMETERS  WHERE  USER_DEFINED_TYPE_NAME = @typeName
	OPEN cur
	FETCH NEXT FROM cur INTO @dependentName

	WHILE @@fetch_status = 0
	BEGIN
		IF OBJECT_ID(@dependentName) IS NOT NULL
		  EXEC('DROP PROCEDURE [' + @dependentName + ']')

		FETCH NEXT FROM cur INTO @dependentName
	END

	CLOSE cur
	DEALLOCATE cur
END
#########################################################
#END
