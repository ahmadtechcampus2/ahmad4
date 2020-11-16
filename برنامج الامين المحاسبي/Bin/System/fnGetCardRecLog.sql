############################################################
CREATE FUNCTION fnGetCardRecLog( @RecGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE 
			([GUID]  [UNIQUEIDENTIFIER],
			[LogTime] [datetime],
			[UserGUID] [UNIQUEIDENTIFIER],
			[Computer] [NVARCHAR] (250),
			[Operation] [int],
			[OperationType] [int],
			[RecGUID] [UNIQUEIDENTIFIER],
			[OperationTime] [datetime],
			[RecNum] [int],
			[TypeGUID]  [UNIQUEIDENTIFIER],
			[Notes] [NVARCHAR] (MAX),
			[DrvRID] [int])
AS
	BEGIN 
	IF NOT EXISTS (SELECT GUID FROM log000 WHERE RecGuid=@RecGuid) AND EXISTS (SELECT EntryGUID FROM er000 WHERE ParentGUID=@RecGuid)
	 BEGIN
      SELECT @RecGuid=EntryGUID FROM er000 WHERE ParentGUID=@RecGuid
     END
		INSERT INTO @Result
		SELECT
			[GUID]
		  ,[LogTime]
		  ,[UserGUID]
		  ,[Computer]
		  ,[Operation]
		  ,[OperationType]
		  ,[RecGUID]
		  ,[OperationTime]
		  ,[RecNum]
		  ,[TypeGUID]
		  ,[Notes]
		  ,[DrvRID]
		FROM 
			[log000] 
		WHERE 
 			[RecGUID] = @RecGuid
			AND OperationType <> 100

		DECLARE @InsertDate [DATETIME] 
		SELECT @InsertDate = [LogTime] FROM @Result WHERE [RecGUID] = @RecGuid AND [OperationType] = 1
		DELETE FROM @Result WHERE [LogTime] < @InsertDate
		RETURN 
	END
############################################################
#END