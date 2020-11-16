###########################################################################
CREATE FUNCTION fnGetAssetsOfClasses(@ClassGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN(
		SELECT [a].[asNumber], [a].[AsParent]
		FROM [vwAs] AS [a] INNER JOIN [dbo].[fnGetClassesOfClass](@ClassGUID) AS [c] ON [a].[asParent] = [c].[GUID])

###########################################################################
#END