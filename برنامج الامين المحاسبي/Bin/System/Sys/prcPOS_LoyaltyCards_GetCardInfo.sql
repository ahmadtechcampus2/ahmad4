##################################################################
CREATE PROC prcPOS_LoyaltyCards_GetCardInfo
	@LoyaltyCardCode Nvarchar(500)
AS 
	SET NOCOUNT ON 

	CREATE TABLE #LoyaltyCard (
		[GUID]					UNIQUEIDENTIFIER,
		[OwnerName]				NVARCHAR(500), 
		[ClassificationGUID]	UNIQUEIDENTIFIER,
		[StateCard]				BIT,
		[StartDate]				DATETIME,
		[EndDate]				DATETIME,
		[Password]				NVARCHAR(500),
		[SubscriptionCode]		Nvarchar(500))
		
	DECLARE 
		@CentralizedDBName			NVARCHAR(250),
		@ErrorNumber				INT

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	EXEC ('
		INSERT INTO #LoyaltyCard
		SELECT 
			[GUID],
			[Name],
			[ClassificationGUID],
			[IsInactive],
			[StartDate],
			[EndDate],
			[Password],
			[SubscriptionCode]
		FROM ' + @CentralizedDBName + ' POSLoyaltyCard000 WHERE Code = ''' + @LoyaltyCardCode + '''')

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
		SELECT * FROM #LoyaltyCard
#######################################################################################
#END
