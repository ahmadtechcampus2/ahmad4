###########################################################################
CREATE FUNCTION fnOption_GetValue( @OpName [NVARCHAR](250), @OpType [INT] = 0)
	RETURNS [NVARCHAR](2000)
AS BEGIN

	DECLARE @opVal [NVARCHAR](2000)
	SET @opVal = (
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
			(@OpType = 0)
			OR 
			((@OpType = 1) AND ([UserGUID] = [dbo].[fnGetCurrentUserGUID]())) 
			OR 
			((@OpType > 1) AND ([Computer] = Host_Name()))
		)
	)

	IF ( ISNULL(@opVal, '') = '' )
	BEGIN 
		SET @opVal = (
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
		)
	END 
	
	RETURN @opVal
END 
###########################################################################
CREATE FUNCTION fnOption_GetGUID(@opName NVARCHAR(500))
RETURNS UNIQUEIDENTIFIER
BEGIN
	RETURN CAST([dbo].[fnOption_get](@opName, '00000000-0000-0000-0000-000000000000') AS UNIQUEIDENTIFIER)
END
###########################################################################
#END
