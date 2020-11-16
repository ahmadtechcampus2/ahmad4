###########################################################################
CREATE PROC prcGetAccountsList
	@StartGUID [UNIQUEIDENTIFIER] = NULL,
	@StartLevel [INT] = 0,
	@EndLevel [INT] = 0
AS
	SET NOCOUNT ON
	
	DECLARE @SQL [NVARCHAR](2000)
	
	SET @StartGUID = ISNULL(@StartGUID, 0x0)

	SET @SQL = '
		SELECT 
			[ac].[acGUID] AS [GUID],
			[ac].[acSecurity] AS [Security],
			[fn].[Level] AS [Level]
		FROM
			[dbo].[fnGetAccountsList](''{' + CAST(@StartGUID AS [NVARCHAR](128)) + '}'', DEFAULT) AS [fn] INNER JOIN [vwAc] AS [ac]
			ON [fn].[GUID] = [ac].[acGUID]
		WHERE 1 = 1'

	IF @StartLevel <> 0
		IF @EndLevel <> 0
			SET @SQL = @SQL + ' AND [fn].[Level] BETWEEN ' + CAST(@StartLevel AS NVARCHAR) + ' AND ' + CAST(@EndLevel AS NVARCHAR)
		ELSE
			SET @SQL = @SQL + ' AND [fn].[Level] >= ' + CAST(@StartLevel AS NVARCHAR)
	ELSE IF @EndLevel <> 0
			SET @SQL = @SQL + ' AND [fn].[Level] <= ' + CAST(@EndLevel AS NVARCHAR)		

	EXEC (@SQL)

###########################################################################
#END