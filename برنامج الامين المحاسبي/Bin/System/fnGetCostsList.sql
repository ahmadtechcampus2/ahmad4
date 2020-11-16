###########################################################################
CREATE FUNCTION fnGetCostCenters(@Type INT)
RETURNS TABLE 
AS
RETURN
	(
		SELECT 
			*
		FROM
			vdco AS co
		WHERE 
			POWER(2, co.[type]) & @Type <> 0  -- = 	POWER(2, @cotype)	
	)		
###########################################################################
CREATE FUNCTION fnGetCostsList(@CostGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER])
AS BEGIN

	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [OK] [BIT] DEFAULT 0)
	DECLARE @SonsBuf TABLE ([GUID] [UNIQUEIDENTIFIER])
	DECLARE @Continue [INT]

	SET @CostGUID = ISNULL(@CostGUID, 0x0)

   	IF @CostGUID = 0x0
   	BEGIN
		INSERT INTO @Result SELECT [coGUID] FROM [vwCo] WHERE [coType] = 0
		RETURN
	END

	DECLARE @Type [INT]
	SET @Type = 0
	SELECT @Type = [Type] FROM [Co000] WHERE [Guid] = @CostGUID
	IF (@Type = 0) 
		INSERT INTO @FatherBuf SELECT [coGUID], 0 FROM [vwCo] WHERE [coGUID] = @CostGUID
	ELSE
	IF(@Type = 1)
		INSERT INTO @FatherBuf SELECT [SonGUID], 0 FROM [CostItem000] WHERE [ParentGUID] = @CostGUID 

	SET @Continue = @@ROWCOUNT
	WHILE @Continue <> 0
	BEGIN
		INSERT INTO @SonsBuf
			SELECT [co].[coGUID]
			FROM [vwCo] AS [co] INNER JOIN @FatherBuf AS [fb] ON [co].[coParent] = [fb].[GUID]
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