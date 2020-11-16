###########################################################################
CREATE FUNCTION fnGetAccByLevel(@AccGUID [UNIQUEIDENTIFIER], @Level [INT], @AccSec [INT])
	RETURNS @Result TABLE(
			GUID	[UNIQUEIDENTIFIER],
			NSons	[INT],
			AccName	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			AccCode	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			Parent	[UNIQUEIDENTIFIER])
AS BEGIN

/*
 «»⁄ ‰„—— ·Â «·Õ”«» Ê«·„” ÊÏ Ê’·«ÕÌ… «·„” Œœ„ ··Õ”«»«  ›Ì⁄ÿÌ‰« √»‰«¡ Â–« «·Õ”«» ·Õœ «·„” ÊÏ «·„Õœœ
√Ì ≈–« „——‰« ·Â «·Õ”«» Ê„” ÊÏ Ê«Õœ ›Ì⁄ÿÌ‰« √»‰«¡ Â–« «·Õ”«» Ê»œÊ‰ √Õ›«œÂ ·√‰Â Õœœ‰« ·„” ÊÏ Ê«Õœ
√–« „——‰« ·Â «·„” ÊÏ Ì”«ÊÌ «·’›— ›Ì⁄ÿÌ‰« ‘Ã—… √»‰«¡ «·Õ”«» «·„Õœœ
*/

	DECLARE @FatherBuf TABLE(
					[GUID]		[UNIQUEIDENTIFIER],
					[NSons]		[INT],
					[AccName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
					[AccCode]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
					[Parent]	[UNIQUEIDENTIFIER],
					[Type]		[INT],
					[OK]		[BIT])

	DECLARE @SonsBuf TABLE(
					[GUID]		[UNIQUEIDENTIFIER],
					[NSons]		[INT],
					[AccName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
					[AccCode]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
					[Parent]	[UNIQUEIDENTIFIER],
					[Type]		[INT])
	DECLARE 
		@Continue	[BIT],
		@RLevel		[INT]

	IF ISNULL(@AccGUID, 0x0) = 0x0
		INSERT INTO @FatherBuf SELECT [acGUID], [acNSons], [acName], [acCode], [acParent], [acType], 0 FROM [vwAc] WHERE [acParent] IS NULL AND [acSecurity] <= @AccSec
	ELSE
		INSERT INTO @FatherBuf SELECT [acGUID], [acNSons], [acName], [acCode], [acParent], [acType], 0 FROM [vwAc] WHERE [acGUID] = @AccGUID AND [acSecurity] <= @AccSec

	SET @Continue = 1
	IF @Level <> 0 AND @AccGUID IS NULL
		IF @Level = 1
			SET @Continue = 0
		ELSE
			SET @Level = @Level - 1

	SET @RLevel = @Level
	WHILE @Continue <> 0
	BEGIN
		INSERT INTO @SonsBuf
			SELECT [ac].[acGUID], [ac].[acNSons], [ac].[acName], [ac].[acCode], [ac].[acParent], [ac].[acType] FROM [vwAc] AS [ac] INNER JOIN @FatherBuf AS [fb] ON [ac].[acParent] = [fb].[GUID] WHERE [fb].[OK] = 0 AND [ac].[acSecurity] <= @AccSec
		SET @Continue = @@ROWCOUNT

		INSERT INTO @SonsBuf
			SELECT [ci].[SonGUID], [ac].[acNSons], [ac].[acName], [ac].[acCode], [ac].[acParent], [ac].[acType] FROM [ci000] AS [ci] INNER JOIN [vwAc] AS [ac] ON [ci].[SonGUID] = [ac].[acGUID] INNER JOIN @FatherBuf AS [fb] ON [ci].[ParentGUID] = [fb].[GUID] WHERE [fb].[Type] = 4 and [fb].[OK] = 0
		SET @Continue = @Continue + @@ROWCOUNT

		IF @RLevel > 0
			SET @RLevel = @RLevel - 1
		IF((@RLevel = 0) AND (@Level > 0))
			SET @Continue = 0

		UPDATE @FatherBuf SET OK = 1 WHERE OK = 0
		INSERT INTO @FatherBuf SELECT [GUID], [NSons], [AccName], [AccCode], [Parent], [Type],0 FROM @SonsBuf
		DELETE FROM @SonsBuf
	END
	INSERT INTO @Result([GUID], [NSons], [AccName], [AccCode], [Parent])
		SELECT [GUID], [NSons], [AccName], [AccCode], [Parent] FROM @FatherBuf GROUP BY [GUID], [NSons], [AccName], [AccCode], [Parent]
	RETURN
END

###########################################################################
#END
