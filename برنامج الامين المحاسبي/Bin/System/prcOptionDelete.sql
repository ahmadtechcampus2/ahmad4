#############################################################################################################
CREATE PROCEDURE prcOptionDelete
	@OpName [NVARCHAR](250),
	@OpType [INT] = 0
AS 
	SET NOCOUNT ON 	
	
	DECLARE @UserGuid [UNIQUEIDENTIFIER]
	SET @UserGuid = (CASE @OpType WHEN 1 THEN [dbo].[fnGetCurrentUserGUID]() ELSE 0x0 END)

	DELETE 
		[op000]
	WHERE 
		[name] LIKE '' + @OpName + ''
		AND 
		[type] = @OpType 
		AND 
		(
			((@OpType = 0) OR (@OpType = 1) AND ([UserGUID] = @UserGuid))
			OR 
			((@OpType > 1) AND ([Computer] = Host_Name()))

		)
#########################################################
#END
