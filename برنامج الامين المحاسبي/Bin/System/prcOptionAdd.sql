#############################################################################################################
CREATE PROCEDURE prcOptionAdd
	@OpName [NVARCHAR](2000),
	@opVal [NVARCHAR](2000),
	@OpType [INT] = 0
AS 
	SET NOCOUNT ON 

	DECLARE @Tbl TABLE( [guid] [UNIQUEIDENTIFIER]) 	

	DECLARE @UserGuid [UNIQUEIDENTIFIER]
	SET @UserGuid = (CASE @OpType WHEN 1 THEN [dbo].[fnGetCurrentUserGUID]() ELSE 0x0 END)

	INSERT INTO @Tbl
	SELECT 
		TOP 1 [guid]
	FROM 
		[op000] 
	WHERE 
		[name] = @OpName 
		AND 
		[type] = @OpType 
		AND 
		(
			(((@OpType = 0) OR (@OpType = 1)) AND ([UserGUID] = @UserGuid))
			OR 
			((@OpType > 1) AND ([Computer] = Host_Name()))
		)

	IF EXISTS ( SELECT * FROM @Tbl)
	BEGIN 
		UPDATE 
			[op000]
		SET 
			[PrevValue] = [op].[Value],
			[Value] = @opVal,
			[Computer] = HOST_NAME(),
			[Time] = GETDATE()
		FROM 
			[op000] [op] 
			INNER JOIN @Tbl [op1] ON [op].[guid] = [op1].[guid]
		WHERE 
			[Value] != @opVal
	END ELSE BEGIN 

		INSERT INTO [op000]
		SELECT 
			newid(),
			@OpName,			
			@opVal,
			'',
			HOST_NAME(),
			GETDATE(),
			@OpType,
			[dbo].[fnGetCurrentUserGUID](),
			@UserGuid

	END 

#########################################################
#END
