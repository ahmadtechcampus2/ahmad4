#########################################################
CREATE FUNCTION fnCost_HSecList()
	RETURNS @Result TABLE (GUID [UNIQUEIDENTIFIER], security [INT])
AS BEGIN
/*
Hierarichal Security List:
select function return a selection close to : select guid, security from co000, with the exception that
the security value of each records is dependant on securoty value of parent record.
following a rule where a sons' security value is always greater or equal to its parent security value
*/

	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [OK] [BIT])
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT])
	DECLARE @Continue [BIT]
 
	INSERT INTO @FatherBuf SELECT [coGUID], [coSecurity], 0 FROM [vwCo] WHERE ISNULL([coParent], 0x0) = 0x0
	SET @Continue = @@ROWCOUNT
 
	WHILE @Continue <> 0 
	BEGIN 
		INSERT INTO @SonsBuf 
			SELECT [co].[coGUID], CASE WHEN [fb].[security] > [co].[coSecurity] THEN [fb].[security] ELSE [co].[coSecurity] END
			FROM [vwCo] AS [co] INNER JOIN @FatherBuf AS [fb] ON [co].[coParent] = [fb].[GUID]
			WHERE [fb].[OK] = 0 

		SET @Continue = @@ROWCOUNT 

		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0 
		INSERT INTO @FatherBuf SELECT [GUID], [security], 0 FROM @SonsBuf 

		DELETE FROM @SonsBuf 
	END 

	INSERT INTO @Result SELECT [GUID], [security] FROM @FatherBuf

	RETURN

END

#########################################################
#END