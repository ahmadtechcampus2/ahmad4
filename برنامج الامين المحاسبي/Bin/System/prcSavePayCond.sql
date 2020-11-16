#########################################################
CREATE PROCEDURE prcSavePayCond
	@buGuid [UNIQUEIDENTIFIER],
	@Type [UNIQUEIDENTIFIER],
	@Cust [UNIQUEIDENTIFIER]
AS
	DECLARE @Guid [UNIQUEIDENTIFIER],@PayGuid [UNIQUEIDENTIFIER]
	SET @Guid = NEWID()
	IF ISNULL(@Cust,0X00) <> 0X00
		SELECT @PayGuid = [Guid] FROM [PT000] WHERE [RefGUID] = @Cust
	IF ISNULL(@PayGuid,0X00) = 0X00
		SELECT @PayGuid = [Guid] FROM [PT000] WHERE [RefGUID] = @Type
	IF ISNULL(@PayGuid,0X00) <> 0X00
	BEGIN
		INSERT INTO [pt000]([GUID],[Type],[RefGUID],[Term],[Days],[Disable],[CalcOptions]) SELECT @Guid,3,@buGuid,[Term],[Days],[Disable],[CalcOptions] FROM [pt000] WHERE [GUID] = @PayGuid
		INSERT INTO  [ti000] ([GUID],[ParentGUID],[Days],[DiscountRatio],[DiscountVal]) SELECT NEWID(),@Guid,[Days],[DiscountRatio],[DiscountVal] FROM [ti000] WHERE [ParentGUID] = @PayGuid
	END
		 
#########################################################
#END 