#########################################################
CREATE VIEW vwDf
AS 
	SELECT 
		[GUID] AS [dfGUID],
		[ParentGUID] AS [dfParentGUID],
		[Number] AS [dfNumber],  
		[Type] AS [dfType],
		[xPos] AS [dfxPos], 
		[yPos] AS [dfyPos],
		[Width] AS [dfWidth],
		[Height] AS [dfHeight],
		[Text] AS [dfText],
		[Select] AS [dfSelect],
		[FontGuid] AS [dfFontGuid],
		[FontColor] AS [dfFontColor],
		[Align] AS [dfAlign],
		[Direct] AS [dfDirect],
		[RTL] AS [dfRTL],
		[WrapTxt] AS [dfWrapTxt],
		[BackColor] AS [dfBackColor],
		[BorderColor] AS [dfBorderColor],
		[LeftBorder] AS [dfLeftBorder],
		[RightBorder] AS [dfRightBorder],
		[TopBorder] AS [dfTopBorder],
		[ButtonBorder] AS [dfButtonBorder],
		[AsBarcode] AS [dfAsBarcode]
	FROM 
		[df000] AS [df]

#########################################################
#END