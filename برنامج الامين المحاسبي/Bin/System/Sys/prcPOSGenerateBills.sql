################################################################################
CREATE PROCEDURE prcPOSGenerateBills
	@orderGuid [UNIQUEIDENTIFIER],
    @BillsID  [UNIQUEIDENTIFIER],
	@payType [INT],
	@deferredAccount [UNIQUEIDENTIFIER],
	@checkType [UNIQUEIDENTIFIER],
	@currencyID [UNIQUEIDENTIFIER],
	@currencyValue [FLOAT],
	@deferredCustomer [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON

	DECLARE @generateSalesBillResult [BIT],
			@generateReturnedSalesBillResult [BIT],
			@salesItemsCount	[INT],
			@returnedSalesItemsCount	[INT]

	SET @salesItemsCount = 0
	SET @returnedSalesItemsCount = 0	
			
	SELECT @salesItemsCount = COUNT(*)
	FROM [POSOrderItems000]
	WHERE [ParentID] = @orderGuid
		AND
		[State] = 0
		AND
		([Type] = 0 OR [Type] = 2)
			
	SELECT @returnedSalesItemsCount = COUNT(*)
	FROM [POSOrderItems000]
	WHERE [ParentID] = @orderGuid
		AND
		[State] = 0
		AND
		[Type] = 1
		
	IF (@salesItemsCount = 0) AND (@returnedSalesItemsCount = 0)
	BEGIN
		RETURN 0
	END
	
	SET @generateSalesBillResult = 1
	SET @generateReturnedSalesBillResult = 1
	
	IF @salesItemsCount > 0
	BEGIN
		EXEC @generateSalesBillResult = prcPOSGenerateSalesBill @orderGuid, @BillsID, @payType, @deferredAccount, @checkType, @currencyID, @currencyValue, 0x0, 0x0, @deferredCustomer
	END

		
	IF @returnedSalesItemsCount > 0
	BEGIN
		EXEC @generateReturnedSalesBillResult = prcPOSGenerateReturnedBill @orderGuid, @BillsID, @payType, @deferredAccount, @checkType, @currencyID, @currencyValue, @deferredCustomer
	END


	RETURN @generateSalesBillResult & @generateReturnedSalesBillResult
################################################################################
#END	