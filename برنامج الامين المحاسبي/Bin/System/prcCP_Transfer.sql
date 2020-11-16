########################################################
CREATE PROC prcCP_DB_Transfer
	@DbName NVARCHAR(250)
AS 
	SET NOCOUNT ON 

	SET @DbName = dbo.fnObject_GetQualifiedName(@DbName)
	IF NOT EXISTS (SELECT * FROM SYS.DATABASES WHERE dbo.fnObject_GetQualifiedName([Name]) = @DbName)
		RETURN

	IF ISNULL(@DbName, '') = ''
		RETURN 

	TRUNCATE TABLE [TransferedCP000]

	DECLARE @CmdText NVARCHAR(MAX)
	SET @CmdText = '
		EXEC ' + @DbName + '.dbo.prcCP_Recalc
		
		INSERT INTO [TransferedCP000] (Price, Unity, GUID, CustGUID, MatGUID, DiscValue, ExtraValue, CurrencyVal, CurrencyGUID, Date, BiGUID)
		SELECT Price, Unity, GUID, CustGUID, MatGUID, DiscValue, ExtraValue, CurrencyVal, CurrencyGUID, Date, BiGUID
		FROM ' + @DbName + '.dbo.cp000 
		WHERE ISNULL(CustGUID, 0x0) != 0x0 AND ISNULL(MatGUID, 0x0) != 0x0 '
	
	EXEC (@CmdText)

	DELETE s
	FROM
		[TransferedCP000] s
		LEFT JOIN cu000 cu ON s.CustGUID = cu.GUID 
	WHERE cu.GUID IS NULL 
	
	DELETE s
	FROM
		[TransferedCP000] s
		LEFT JOIN mt000 mt ON s.MatGUID = mt.GUID 
	WHERE mt.GUID IS NULL 
########################################################
CREATE PROC prcCP_Transfer 
	@IsCalcCP BIT = 1
AS 
	SET NOCOUNT ON 

	DECLARE @DbName NVARCHAR(500)

	SET @DbName = dbo.fnDatasource_GetLastDBName()

	IF ISNULL(@DbName, '') = ''
		RETURN
	
	EXEC prcCP_DB_Transfer @DbName

	IF @IsCalcCP = 1
		EXEC prcCP_Recalc
#########################################################
#END 
