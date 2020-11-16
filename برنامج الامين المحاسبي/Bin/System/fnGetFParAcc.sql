###########################################################################
CREATE FUNCTION fnGetFParAcc(@FinalAccGUID [UNIQUEIDENTIFIER], @AccGUID [UNIQUEIDENTIFIER])
	RETURNS [UNIQUEIDENTIFIER]
AS BEGIN
/*
  «»⁄ ÌﬁÊ„ »≈⁄ÿ«¡‰« √ﬂ»— √» Œ «„Ì ··Õ”«» «·›—⁄Ì
*/

	DECLARE @GUID [UNIQUEIDENTIFIER]
	DECLARE @Final [UNIQUEIDENTIFIER]
	DECLARE @Count [INT]

	SELECT @Final = [acFinal] FROM [vwAc] WHERE [acGUID] = @AccGUID
	SET @Count = @@RowCount

	SET @GUID = @Final
	WHILE @Count <> 0
	BEGIN
		if @Final <> @FinalAccGUID
		BEGIN
			SET @GUID =  @Final
			SELECT @Final = [acParent] FROM [vwAc] WHERE [acGUID] = @GUID
			SET @Count = @@RowCount
		END
		ELSE
			BREAK
	END
	RETURN @GUID
END

###########################################################################
#END