######################################################### 
CREATE FUNCTION fnMaterial_GetUnitList(@MatGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN(
		SELECT 1 AS [Number], [Unity] AS [Unit], 1 AS [UnitFactor], (CASE [DefUnit] WHEN 1 THEN 1 ELSE 0 END) AS [DefaultUnit] FROM [mt000] WHERE [GUID] = @MatGUID AND [Unity] <> ''
		UNION ALL
		SELECT 2 AS [Number], [Unit2] AS [Unit], [Unit2Fact] AS [UnitFactor], (CASE [DefUnit] WHEN 2 THEN 1 ELSE 0 END) AS [DefaultUnit] FROM [mt000] WHERE [GUID] = @MatGUID AND [Unit2] <> ''
		UNION ALL
		SELECT 3 AS [Number], [Unit3] AS [Unit], [Unit3Fact] AS [UnitFactor], (CASE [DefUnit] WHEN 3 THEN 1 ELSE 0 END) AS [DefaultUnit] FROM [mt000] WHERE [GUID] = @MatGUID AND [Unit3] <> ''
)

#########################################################
#END