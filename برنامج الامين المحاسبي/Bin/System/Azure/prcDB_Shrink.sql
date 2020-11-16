######################################################### 
CREATE PROC prcDB_shrink
AS
	DECLARE @dbName [NVARCHAR](128)
	SET @dbName = db_name()

	-- This function not available in Azure
	-- DBCC SHRINKDATABASE (@dbname)

	EXECUTE prcNotSupportedInAzure


#########################################################