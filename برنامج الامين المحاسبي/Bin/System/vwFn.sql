#########################################################
CREATE VIEW vwFn
AS 
	SELECT 
		[GUID] AS [fnGUID],
		[Number] AS [fnNumber],  
		[Name] AS [fnName],
		[Height] AS [fnHeight],
		[Width] AS [fnWidth],
		[Escapement] AS [fnEscapement],
		[Orientation] AS [fnOrientation],
		[Weight] AS [fnWeight],
		[Italic] AS [fnItalic],
		[Underline] AS [fnUnderline],
		[StrikeOut] AS [fnStrikeOut],
		[CharSet] AS [fnCharSet],
		[OutPrecision] AS [fnOutPrecision],
		[ClipPrecision] AS [fnClipPrecision],
		[Quality] AS [fnQuality],
		[PitchAndFamily] AS [fnPitchAndFamily],
		[Color] AS [fnColor]
	FROM 
		[fn000]

#########################################################
#END