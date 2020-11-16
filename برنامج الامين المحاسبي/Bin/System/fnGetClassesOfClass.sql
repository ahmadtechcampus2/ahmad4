###########################################################################
CREATE FUNCTION fnGetClassesOfClass (@ClassGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER])
AS BEGIN

	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [OK] [BIT])
	DECLARE @SonsBuf TABLE ([GUID] [UNIQUEIDENTIFIER])
	DECLARE @Continue [INT]

	IF @ClassGUID IS NULL
		INSERT INTO @FatherBuf SELECT [agGUID], 0 FROM [vwAg] WHERE [agParent] IS NULL
	ELSE
		INSERT INTO @FatherBuf SELECT [agGUID], 0 FROM [vwAg] WHERE [AgGUID] = @ClassGUID

	SET @Continue = 1
	WHILE @Continue <> 0
	BEGIN
		INSERT INTO @SonsBuf
			SELECT [ag].[agGUID]
			FROM [vwAg] AS [ag] INNER JOIN @FatherBuf AS [fb] ON [ag].[agParent] = [fb].[GUID]
			WHERE [fb].[OK] = 0

		SET @Continue = @@ROWCOUNT
		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0
		INSERT INTO @FatherBuf SELECT [GUID], 0 FROM @SonsBuf
		DELETE FROM @SonsBuf
	END
	INSERT INTO @Result SELECT [GUID] FROM @FatherBuf
	RETURN

END

###########################################################################
#END