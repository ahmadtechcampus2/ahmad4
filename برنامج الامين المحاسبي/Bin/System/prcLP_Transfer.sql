########################################################
CREATE PROC prcLP_DB_Transfer
	@DbName NVARCHAR(250)
AS 
	SET NOCOUNT ON 

	SET @DbName = dbo.fnObject_GetQualifiedName(@DbName)
	IF NOT EXISTS (SELECT * FROM SYS.DATABASES WHERE dbo.fnObject_GetQualifiedName([Name]) = @DbName)
		RETURN

	IF ISNULL(@DbName, '') = ''
		RETURN 

	TRUNCATE TABLE [TransferedLP000]

	DECLARE @CmdText NVARCHAR(MAX)
	SET @CmdText = '
		INSERT INTO [TransferedLP000] (GUID, MatGUID, LastPrice, LastPrice2, LastPrice3, CurrencyVal, CurrencyGUID, Date)
		SELECT NEWID(), GUID, LastPrice, LastPrice2, LastPrice3, LastPriceCurVal, CurrencyGUID, LastPriceDate
		FROM ' + @DbName + '.dbo.mt000 WHERE LastPrice != 0 '

	EXEC (@CmdText)

	DELETE s
	FROM
		TransferedLP000 s
		LEFT JOIN mt000 mt ON s.MatGUID = mt.GUID 
	WHERE mt.GUID IS NULL 
########################################################
CREATE PROC prcLP_Transfer
	@IsCalcLP BIT = 1
AS 
	SET NOCOUNT ON 

	DECLARE @DbName NVARCHAR(500)

	SET @DbName = dbo.fnDatasource_GetLastDBName()

	IF ISNULL(@DbName, '') = ''
		RETURN
	
	EXEC prcLP_DB_Transfer @DbName

	IF @IsCalcLP = 1
		EXEC prcLP_Recalc 1, 1
########################################################
#END 
