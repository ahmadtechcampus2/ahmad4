##########################################################
CREATE FUNCTION fnMaintenance_CheckExportData()
	RETURNS [INT]
AS 
BEGIN 
	DECLARE @ReturnValue TINYINT 
	SET @ReturnValue = 0

	-- If replication is applied to file 
	IF [dbo].[fnObjectExists]('rpl_nodes') <> 0
		RETURN 1
	IF EXISTS(SELECT * FROM SubProfitCenter000) OR EXISTS(SELECT * FROM op000 WHERE Name = 'PFC_IsBelongToProfitCenter' AND Value <> '0') 
		RETURN 2
	IF EXISTS(SELECT * FROM op000 WHERE Name = 'HR_Connection_Activate' AND Value = '1') 
		RETURN 3
	RETURN 0
END 
##########################################################
CREATE PROCEDURE prcCopyDataTablesToNewDatabase
	@DestName NVARCHAR(MAX)
AS
	DECLARE @c CURSOR
	DECLARE @Name NVARCHAR(256)
	DECLARE @Str NVARCHAR(MAX)
	SET @c = CURSOR FAST_FORWARD FOR 	
		SELECT [name] FROM sysobjects WHERE xtype = 'u' ORDER BY name
	OPEN @c 

	FETCH NEXT FROM @c INTO @Name
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		EXEC prcCopyTbl @DestName,@Name,'',0,1,0
		FETCH NEXT FROM @c INTO @Name
	END
	
	SET @Str='UPDATE ['+@DestName+']..us000
				SET dirty = 1
				WHERE bAdmin=1'
	EXEC(@Str)
############################################################################################
#END
