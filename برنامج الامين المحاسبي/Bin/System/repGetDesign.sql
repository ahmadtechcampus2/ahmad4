#########################################################
##≈Ã—«¡ ··Õ’Ê· ⁄·Ï  ’„Ì„ „⁄Ì‰
CREATE PROCEDURE repGetDesign
	@Type [int], --‰Ê⁄ «· ’„Ì„
	@Name [NVARCHAR](1000) --«”„ «· ’„Ì„
AS
	SELECT
		[dsGUID] AS [dsGUID],
		[dsName] AS [Name],
		[dsLatinName] AS [LatinName],
		[dsWidth] AS [Width],
		[dsHeight] AS [Height],
		[dsBackgroundColor] AS [BackgroundColor],
		[dfGUID] AS [dfGUID],
		[dfNumber] AS [Number],
		[dfType] AS [Type],
		[dfxPos] AS [xPos],
		[dfyPos] AS [yPos],
		[dfWidth] AS [FldWidth],
		[dfHeight] AS [FldHeight],
		[dfText] AS [FldText],
		[dfSelect] AS [Selected],
		[dfFontColor] AS [FontColor],
		[dfAlign] AS [Align],
		[dfDirect] AS [Direct],
		[dfRTL] AS [RTL],
		[dfWrapTxt] AS [WrapTxt],
		[dfBackColor] AS [BackColor],
		[dfBorderColor] AS [BorderColor],
		[dfLeftBorder] AS [LeftBorder],
		[dfRightBorder] AS [RightBorder],
		[dfTopBorder] AS [TopBorder],
		[dfButtonBorder] AS [BottomBorder],
		[dfAsBarcode] AS [AsBarcode],
		[faGUID] AS [AttrGUID],
		ISNULL( [faType], 0) AS [AttrType],
		ISNULL( [faValue], 0) AS [AttrValue],
		ISNULL( [faText], ' ') AS [AttrText],
		[fnGUID] AS [fnGUID],
		[fnName] AS [FontName],
		[fnHeight] AS [FontHeight],
		[fnWidth] AS [FontWidth],
		[fnEscapement] AS [Escapement],
		[fnOrientation] AS [Orientation],
		[fnWeight] AS [Weight],
		[fnItalic] AS [Italic],
		[fnUnderline] AS [Underline],
		[fnStrikeOut] AS [StrikeOut],
		[fnCharSet] AS [CharSet],
		[fnOutPrecision] AS [OutPrecision],
		[fnClipPrecision] AS [ClipPrecision],
		[fnQuality] AS [Quality],
		[fnPitchAndFamily] AS [PitchAndFamily]
	FROM
		[vwDs] INNER JOIN [vwDf] ON [dsGUID] = [vwDf].[dfParentGUID]
		LEFT JOIN [vwFn] ON	[vwDf].[dfFontGuid] = [vwfn].[fnGUID]
		LEFT JOIN [vwFa] ON	[vwDf].[dfGUID] = [vwFa].[faParentGUID]
	WHERE 
		[vwDs].[dsName] = @Name AND
		[vwDs].[dsType] = @Type
	-- Order by Type Used In Restaurant
	ORDER BY [Type], dfGuid, faText
#########################################################
#END 