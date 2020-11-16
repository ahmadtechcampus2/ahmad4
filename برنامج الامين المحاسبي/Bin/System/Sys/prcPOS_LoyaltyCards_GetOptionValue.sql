##################################################################
CREATE PROC prcPOS_LoyaltyCards_GetOptionValue
	@OptionName NVARCHAR(500)
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Option ([Value] NVARCHAR(500))

	DECLARE 
		@CentralizedDBName			NVARCHAR(250),
		@ErrorNumber				INT,
		@OptionValue				NVARCHAR(500)
	
	SET @ErrorNumber = 0
	SET @OptionValue = ''

	IF ISNULL(@OptionName, '') = ''
		GOTO exitproc

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	EXEC ('
		INSERT INTO #Option ([Value])
		SELECT TOP 1
			[Value]
		FROM ' + @CentralizedDBName + 'op000 WHERE Type = 0 AND Name = ''' + @OptionName + '''')
	
	SET @OptionValue = ISNULL((SELECT TOP 1 [Value] FROM #Option), '')

	exitProc:
		SELECT 
			@ErrorNumber AS ErrorNumber,
			@OptionValue AS OptionValue
#######################################################################################
#END
