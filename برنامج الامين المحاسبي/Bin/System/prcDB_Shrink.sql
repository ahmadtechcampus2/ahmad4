######################################################### 
CREATE PROC prcDB_CompressData
	@CompressionType INT = 0 -- 0:NONE, 1:ROW, 2:PAGE 
AS 
	SET NOCOUNT ON

	DECLARE 
		@ct VARCHAR(10),
		@sql NVARCHAR(MAX)
	SET @ct = (CASE @CompressionType WHEN 1 THEN'ROW' WHEN 2 THEN 'PAGE' ELSE 'NONE' END)
	SET @sql = 'SET QUOTED_IDENTIFIER ON; ALTER TABLE ? REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = ' + @ct + ')'

	EXEC sp_msforeachtable @sql

	DECLARE @date DATE 
	SET @date = GETDATE()
	IF NOT EXISTS(SELECT * FROM op000 WHERE Name = 'LastShrinkDatabaseDate')
		INSERT INTO op000([GUID], Name, Value, [Type])
		SELECT NEWID(), 'LastShrinkDatabaseDate', CAST(@date AS VARCHAR(250)), 0
	ELSE 
		UPDATE op000 SET Value = CAST(@date AS VARCHAR(250)), PrevValue = Value WHERE Name = 'LastShrinkDatabaseDate'

	IF EXISTS(SELECT * FROM op000 WHERE Name = 'CheckingShrinkDatabase')
		DELETE op000 WHERE Name = 'CheckingShrinkDatabase'
######################################################### 
CREATE PROC prcDB_shrink
AS
	DECLARE @dbName [NVARCHAR](128)
	SET @dbName = db_name()

	DBCC SHRINKDATABASE (@dbname)
######################################################### 
CREATE PROCEDURE prcShrinkDBMaintance
	@CompressionType INT = -1
AS
	SET NOCOUNT ON

	IF @CompressionType >= 0
		EXEC prcDB_CompressData @CompressionType;

	EXEC prcDB_shrink;

#########################################################
CREATE PROCEDURE prcEmptingTemporaryTables
	@Data NVARCHAR(MAX)=';,MaintenanceLogItem000,1,50,1,;'
AS
	SET NOCOUNT ON 

	DECLARE 
		@IND INT,
		@EIND INT
		
	SET @IND =	CHARINDEX(';', @Data)
	SET @EIND =	0

	WHILE (@IND <> LEN(@Data))
	BEGIN
		DECLARE 
			@DataTable	NVARCHAR(MAX),
			@IndexData	INT,
			@EINDData	INT, 
			@TableName	NVARCHAR(250),
			@Save		NVARCHAR(1),
			@Period		NVARCHAR(MAX),
			@IsDay		NVARCHAR(MAX),
			@I			INT

		SET @EIND =			ISNULL(((CHARINDEX(';', @Data, @IND + 1)) - @IND - 1), 0)
		SET @DataTable =	SUBSTRING(@Data, (@IND  + 1),  @EIND)
		SET @IND =			ISNULL(CHARINDEX(';', @Data, @IND + 1), 0)
		SET @EINDData =		0
		SET @IndexData =	CHARINDEX(',',@DataTable)
		SET @I =			0

		WHILE (@IndexData <> LEN(@DataTable) AND  @IndexData <> 0 )
		BEGIN
			SET  @EINDData = ISNULL(((CHARINDEX(',', @DataTable, @IndexData + 1)) - @IndexData - 1), 0)
			
			IF @I = 0  
				SET @TableName = (SUBSTRING(@DataTable, (@IndexData  + 1),  @EINDData))
			
			IF @I = 1
			BEGIN
			  SET @Save = (SUBSTRING(@DataTable, (@IndexData  + 1),  @EINDData))
			  IF @Save ='0'
				BREAK;
			END

			IF @I = 2
				SET @Period = (SUBSTRING(@DataTable, (@IndexData  + 1),  @EINDData))
			
			IF @I = 3
				SET @IsDay = (SUBSTRING(@DataTable, (@IndexData  + 1),  @EINDData))

			SET @I = @I + 1
			SET @IndexData = ISNULL(CHARINDEX(',', @DataTable, @indexdata + 1), 0)	
		END
		
		DECLARE @sql NVARCHAR(MAX)
		IF @TableName = 'MaintenanceLogItem000'
		BEGIN
			SET @sql='DELETE FROM MaintenanceLogItem000'
			IF @Save = '1'
			BEGIN
			IF @IsDay = '0'
				SET @sql += ' WHERE DATEDIFF(DAY, LogTime, GETDATE()) > ' + @Period
			ELSE 	
				SET @sql += ' WHERE DATEDIFF(MONTH, LogTime, GETDATE()) > ' + @Period
			END
			EXEC (@sql)
		END

		IF @TableName = 'Lg000'
		BEGIN
			SET @sql='DELETE FROM Lg000'
			IF @Save = '1'
			BEGIN
			IF @IsDay = '0'
				SET @sql += ' WHERE DATEDIFF(DAY, LogTime, GETDATE()) > ' + @Period
			ELSE 	
				SET @sql += ' WHERE DATEDIFF(MONTH, LogTime, GETDATE()) > ' + @Period
			END
			EXEC (@sql)
		END

		IF @TableName = 'TransferedCP000'
		BEGIN
			EXEC ('DELETE FROM TransferedCP000')
		END

		IF @TableName = 'TransferedLP000'
		BEGIN
			EXEC ('DELETE FROM TransferedLP000')
		END

	END
	EXEC prcDB_shrink
#########################################################
#END