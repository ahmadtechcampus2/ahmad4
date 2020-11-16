###############################################################################
CREATE PROC prcDB_GetGlobalVars
	@Str [NVARCHAR](max),
	@Dir [INT] = 0
AS 
/* 
this procedure 
	- return custom strings depending on dir 0 RTL, 1 LTR.
*/ 
	SET NOCOUNT ON 

	SELECT 
		[Number],
		( CASE @Dir WHEN 0 THEN [Asc1] ELSE [Asc2] END) AS [Asc]
	FROM 
		[mc000] 
	WHERE 
		[type] = 8 
		AND 
		[Number] IN ( SELECT [SubStr] FROM [dbo].[fnString_Split]( @str, DEFAULT))

###############################################################################
#END