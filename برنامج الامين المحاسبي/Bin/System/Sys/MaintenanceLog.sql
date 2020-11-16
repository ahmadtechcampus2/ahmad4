#############################################################################
CREATE PROCEDURE prcCreateMaintenanceLog
	@MainTainId INT,
	@Guid UNIQUEIDENTIFIER OUTPUT,
	@Params NTEXT
AS 
	SET @Guid = NEWID();
	INSERT INTO MaintenanceLog000([Guid], Id, [Parameters],UserGUID,StartLogTime,Computer)  VALUES (@Guid,@MainTainId, @Params,dbo.fnGetCurrentUserGUID(),GetDate(),HOST_NAME())
#############################################################################
CREATE PROCEDURE prcCreateMaintenanceLogWithResult
	@MainTainId INT,
	@Text NTEXT
AS 
	SET NOCOUNT ON
	DECLARE @Guid UNIQUEIDENTIFIER
	EXEC prcCreateMaintenanceLog @MainTainId,@Guid OUTPUT,@Text
	SELECT @Guid [Guid]
#############################################################################
CREATE PROCEDURE prcCloseMaintenanceLog
	@Guid UNIQUEIDENTIFIER,
	@CloseReason	TINYINT = 3
AS 
	UPDATE MaintenanceLog000  SET [EndLogTime] = GETDATE(),CloseReason = @CloseReason WHERE [Guid] = @Guid

#############################################################################
CREATE PROCEDURE prcAddMaintenanceLogItem 
	@ParentGuid UNIQUEIDENTIFIER,
	@Severity INT,
	@Notes NTEXT,
	@SourceGUID1 UNIQUEIDENTIFIER,
	
	@SourceType1 INT,
	@SourceGUID2 UNIQUEIDENTIFIER = 0x0,
	@SourceType2 INT = 0
	
AS
	IF NOT EXISTS(SELECT * FROM MaintenanceLog000 WHERE [Guid] = @ParentGuid)
		RETURN 1
	
		INSERT INTO MaintenanceLogItem000 ( GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, ErrorSourceGUID2, ErrorSourceType2, Notes)
		VALUES( NEWID(), @ParentGuid, @Severity,GetDate(), @SourceGUID1, @SourceType1, @SourceGUID2, @SourceType2, @Notes)
#############################################################################
CREATE PROCEDURE prcsetSrcStringLog
	@Str NVARCHAR(2000) OUTPUT
AS
	DECLARE	@c CURSOR,@Name NVARCHAR(100)
	SET @Str = ''
	SET @c = CURSOR FAST_FORWARD FOR
				SELECT Name FROM
				(
					SELECT GUID,Abbrev [Name] FROM vbbt
					UNION ALL
					SELECT GUID,Abbrev [Name] FROM vbnt
					UNION ALL
					SELECT GUID,Abbrev [Name] FROM vbet) e INNER JOIN [#Src] r on r.[Type] = e.GUID 
	OPEN @c FETCH FROM @c INTO @Name
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Str = @Str + @Name + '-'
		FETCH FROM @c INTO @Name
	END
	SET @Str = @Str + CHAR(13)
	CLOSE @c 
	DEALLOCATE @c
#############################################################################
CREATE PROCEDURE repMaintenanceLog
	@MainTainId INT,
	@StatDate DATETIME,
	@EndDate  DATETIME,
	@UserGUID UNIQUEIDENTIFIER,
	@Computer NVARCHAR(100)
AS
	SET NOCOUNT ON
	SELECT a.*,ISNULL(LoginName,'') LoginName
	INTO #Log
	FROM MaintenanceLog000 A LEFT JOIN us000 us ON us.Guid = a.UserGUID
	WHERE 
	(@MainTainId = -1 OR Id = @MainTainId)
	AND 
	CAST(a.StartLogTime AS DATE) BETWEEN CAST(@StatDate AS DATE) AND CAST(@EndDate AS DATE)
	AND 
	(@UserGUID = 0x00 OR UserGUID = @UserGUID)
	AND
	(@Computer = '' OR  Computer = @Computer)
	ORDER BY a.StartLogTime
	SELECT * FROM #Log
	SELECT m.* 
	INTO #MU
	FROM MaintenanceLogItem000 M INNER JOIN #Log l ON m.ParentGUID = l.Guid
	ALTER TABLE #mu ADD Name1 [NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT ''
	ALTER TABLE #mu ADD Name2 [NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT ''
	UPDATE m SET Name1 = bt.Name + ':' + CAST(bu.Number AS NVARCHAR(100)) FROM #mu M INNER JOIN  bu000 bu ON m.ErrorSourceGUID1 = bu.Guid INNER JOIN bt000 bt ON bt.Guid = bu.TypeGuid WHERE ErrorSourceType1 = 0x10010000
	UPDATE m SET Name2 = bt.Name + ':' + CAST(bu.Number AS NVARCHAR(100)) FROM #mu M INNER JOIN  bu000 bu ON m.ErrorSourceGUID2 = bu.Guid INNER JOIN bt000 bt ON bt.Guid = bu.TypeGuid WHERE ErrorSourceType2 = 0x10010000
	
	UPDATE m SET Name1 = co.Code + '-' + co.Name FROM #mu M INNER JOIN  cO000 co ON m.ErrorSourceGUID1 = co.Guid  WHERE ErrorSourceType1 = 0x1001B000
	UPDATE m SET Name2 = co.Code + '-' + co.Name FROM #mu M INNER JOIN  cO000 co ON m.ErrorSourceGUID2 = co.Guid  WHERE ErrorSourceType2 = 0x1001B000
	
	UPDATE m SET Name1 = ac.Code + '-' + ac.Name FROM #mu M INNER JOIN  ac000 ac ON m.ErrorSourceGUID1 = ac.Guid  WHERE ErrorSourceType1 = 0x10017000
	UPDATE m SET Name2 = ac.Code + '-' + ac.Name FROM #mu M INNER JOIN  ac000 ac ON m.ErrorSourceGUID2 = ac.Guid  WHERE ErrorSourceType2 = 0x10017000
	
	SELECT * FROM #mu

#############################################################################
CREATE PROCEDURE repMaintenanceDelete
AS
  DELETE  MaintenanceLog000
  DELETE  MaintenanceLogItem000
#############################################################################
#END
	
	