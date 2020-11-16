#########################################################
CREATE PROC prcOptions_DeleteLike
	@opName [NVARCHAR](250),
	@opType [INT] 
AS 
	SET NOCOUNT ON 

	DELETE [op000]
	WHERE 
		[Name] like '' + @OpName + '%'
		AND 
		[type] = @OpType 
		AND 
		(
			((@OpType = 0) AND ([UserGUID] = 0x0)) 
			OR 
			((@OpType = 1) AND ([UserGUID] = [dbo].[fnGetCurrentUserGUID]())) 
			OR 
			((@OpType > 1) AND ([Computer] = Host_Name()))
		)
#########################################################
#END