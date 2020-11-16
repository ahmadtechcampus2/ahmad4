###########################################
CREATE FUNCTION fnTrnGetCurrencyInOutVal
	(
		@CurGuid	[UNIQUEIDENTIFIER],
		@Date DATETIME
	)
RETURNS @Result TABLE(InVal FLOAT, OutVal FLOAT, BuyTranfer FLOAT, SellTransfer FLOAT)
AS 
BEGIN
	INSERT INTO @Result
		SELECT TOP 1 
			 InCurrencyVal, 
			 OutCurrencyVal, 
			 CASE WHEN BuyTransferVal > 0 THEN BuyTransferVal ELSE InCurrencyVal END,
			 CASE WHEN SellTransferVal > 0 THEN SellTransferVal ELSE OutCurrencyVal END 
		FROM TrnMh000
		WHERE CurrencyGuid = @CurGuid AND [Date] <= @Date
		ORDER BY [Date] DESC
			
	IF NOT EXISTS (SELECT * FROM @Result)
	BEGIN	
		INSERT INTO @Result
		SELECT 
			CurrencyVal, CurrencyVal,CurrencyVal, CurrencyVal
		FROM [my000] 
		WHERE Guid = @CurGuid
	END
RETURN
END
######################################################
CREATE FUNCTION fnTrnGetAvgCurrency_4Price
	(
		@CurGuid	[UNIQUEIDENTIFIER],
		@Date DATETIME
	)
RETURNS FLOAT
AS 
BEGIN
	RETURN (SELECT (InVal + OutVal + BuyTranfer + SellTransfer)/4 FROM fnTrnGetCurrencyInOutVal(@CurGuid,@Date))
END	
######################################################	
#END