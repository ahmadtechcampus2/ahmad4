#########################################################
CREATE FUNCTION fnStore_HSecList()
	RETURNS @Result TABLE (GUID [UNIQUEIDENTIFIER], security [INT])
AS BEGIN
/*
Hierarichal Security List:
select function return a selection close to : select guid, security from st000, with the exception that
the security value of each records is dependant on securoty value of parent record.
following a rule where a sons' security value is always greater or equal to its parent security value
*/

	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [OK] [BIT])
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT])
	DECLARE @Continue BIT
 
	INSERT INTO @FatherBuf SELECT [stGUID], [stSecurity], 0 FROM [vwSt] WHERE ISNULL([stParent], 0x0) = 0x0
	SET @Continue = @@ROWCOUNT
 
	WHILE @Continue <> 0 
	BEGIN 
		INSERT INTO @SonsBuf 
			SELECT [st].[stGUID], CASE WHEN [fb].[security] > [st].[stSecurity] THEN [fb].[security] ELSE [st].[stSecurity] END
			FROM [vwSt] AS [st] INNER JOIN @FatherBuf AS [fb] ON [st].[stParent] = [fb].[GUID] 
			WHERE [fb].[OK] = 0 

		SET @Continue = @@ROWCOUNT 

		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0 
		INSERT INTO @FatherBuf SELECT [GUID],[security], 0 FROM @SonsBuf 

		DELETE FROM @SonsBuf 
	END 

	INSERT INTO @Result SELECT [GUID],[security] FROM @FatherBuf

	RETURN

END

#########################################################
#END