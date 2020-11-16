##################################################################
CREATE PROC prcPOS_LoyaltyCards_LOC_GetAvailablePointsCount
	@LoyaltyCardGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT dbo.fnPOS_LoyaltyCards_GetAvailablePointsCount(@LoyaltyCardGUID) AS PointsCount
##################################################################
CREATE PROC prcPOS_LoyaltyCards_GetAvailablePointsCount
	@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
	@LoyaltyCardGUID		UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	DECLARE 
		@CentralizedDBName			NVARCHAR(250),
		@ErrorNumber				INT,
		@AvailablePointsCount		INT 

	SET @AvailablePointsCount = 0
	
	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (@LoyaltyCardTypeGUID)

	IF @ErrorNumber > 0 
		GOTO exitproc
	
	IF @CentralizedDBName = ''
		SET @CentralizedDBName = 'dbo.'
	CREATE TABLE #count (cnt INT)
	DECLARE @CmdText NVARCHAR(MAX)
	SET @CmdText = 'INSERT INTO #count(cnt) SELECT '  + @CentralizedDBName + 'fnPOS_LoyaltyCards_GetAvailablePointsCount('''  + CAST(@LoyaltyCardGUID AS VARCHAR(100)) + ''')'
	
	EXEC (@CmdText)

	IF EXISTS (SELECT * FROM #count)
		SET @AvailablePointsCount = (SELECT TOP 1 CAST(cnt AS INT) FROM #count)

	exitproc:

		SELECT 
			@ErrorNumber			AS ErrorNumber,
			@AvailablePointsCount	AS AvailablePointsCount
#######################################################################################
#END
