#############################################################################################################
CREATE PROCEDURE prcOptionGetValue
	@OpName [NVARCHAR](2000),
	@OpType [INT] = 0
AS 
/*
This procedure:
	- get first value of selected option name and option type.
	- if there isn't a value with selected option type, return the value of the option with option name
	  and type = 0
*/
	SET NOCOUNT ON 

	DECLARE @Tbl TABLE( [Value] [NVARCHAR](2000) COLLATE ARABIC_CI_AI) 

	INSERT INTO @Tbl
	SELECT TOP 1
		[Value] 
	FROM 
		[op000] 
	WHERE 
		[name] = @OpName 
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
	
	IF ( NOT EXISTS( SELECT * FROM @Tbl)) AND (@OpType <> 0)
	BEGIN 
		INSERT INTO @Tbl
		SELECT TOP 1
		[Value] 
		FROM 
			[op000] 
		WHERE 
			([name] = @OpName)
			AND 
			([type] = 0) 
			AND 
			([UserGUID] = 0x0)
	END 
	
	SELECT * FROM @Tbl

#########################################################
#END