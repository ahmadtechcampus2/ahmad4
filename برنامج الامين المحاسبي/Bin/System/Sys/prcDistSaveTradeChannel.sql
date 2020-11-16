########################################
CREATE PROCEDURE prcDistSaveTradeChannel
	@CustomerName NVARCHAR(250), -- The customer name.
	@AccountCode NVARCHAR(250), -- The account code.
	@TradeChannel NVARCHAR(250), -- Trade channel code or name.
	@CustomerType NVARCHAR(250), -- Customer type code or name.
	@CustomerState BIT, -- Customer state.
	@IsCustomerContracted BIT, -- Is the customer is contracted or no.
	@ContractDate DATETIME, -- The date of the contract for the customer.
	@ContractNumber FLOAT, -- The number of the contract for the customer.
	@Notes NVARCHAR(250), -- Notes.
	@StoreCode NVARCHAR(250), -- The store code.
	@StoreName NVARCHAR(250), -- The store name.
	@UpdateData BIT -- If update data if it exists or no.
AS
	SET NOCOUNT ON

	IF @CustomerName = '' AND @AccountCode = ''
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	DECLARE 
		@CustomerGUID UNIQUEIDENTIFIER,
		@TradeChGUID UNIQUEIDENTIFIER,
		@CustomerTypeGUID UNIQUEIDENTIFIER,
		@StoreGUID UNIQUEIDENTIFIER
	
	SELECT @CustomerGUID = [GUID] FROM cu000 WHERE CustomerName = @CustomerName OR AccountGUID = (SELECT [GUID] FROM ac000 WHERE Code = @AccountCode)
	
	IF ISNULL(@CustomerGUID, 0x0) = 0x0
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	IF (@UpdateData = 0) AND EXISTS(SELECT * FROM DistCe000 WHERE CustomerGUID = @CustomerGUID)
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
		
	SELECT @TradeChGUID = [GUID] FROM DistTch000 WHERE (Code = @TradeChannel) OR (Name = @TradeChannel)
	
	IF ISNULL(@TradeChGUID, 0x0) = 0x0
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	IF (@CustomerType <> '')
	BEGIN
		SELECT @CustomerTypeGUID = [GUID] FROM DistCT000 WHERE (Code = @CustomerType) OR (Name = @CustomerType)
		
		IF ISNULL(@CustomerTypeGUID, 0x0) = 0x0
		BEGIN
			SELECT 0 AS ImportResult
			RETURN
		END
	END
	
	IF @StoreCode <> '' OR @StoreName <> ''
	BEGIN
		SELECT @StoreGUID = [GUID] FROM st000 WHERE Code = @StoreCode OR Name = @StoreName
		
		IF @StoreGUID = 0x0
		BEGIN
			SELECT 0 AS ImportResult
			RETURN
		END
	END
	
	IF (@UpdateData = 1) AND EXISTS(SELECT * FROM DistCe000 WHERE CustomerGUID = @CustomerGUID)
	BEGIN
		UPDATE DistCe000
		SET
			TradeChannelGUID = ISNULL(@TradeChGUID, 0x0),
			CustomerTypeGUID = ISNULL(@CustomerTypeGUID, 0x0),
			StoreGUID = ISNULL(@StoreGUID, 0x0),
			[State] = @CustomerState,
			[Contract] = @ContractNumber,
			Contracted = @IsCustomerContracted,
			ContractDate = @ContractDate,
			Notes = @Notes
		WHERE
			CustomerGUID = ISNULL(@CustomerGUID, 0x0)
		
		SELECT 1 AS ImportResult
		RETURN
	END
	DECLARE @Num INT

	SET @Num = (SELECT ISNULL(MAX(Number), 0) + 1 FROM DistCe000)

	INSERT INTO 
	DistCe000(Number, [GUID], CustomerGUID, TradeChannelGUID, CustomerTypeGUID, StoreGUID, [State], [Contract], Contracted, ContractDate, Notes) 
	VALUES(@Num, NEWID(), ISNULL(@CustomerGUID, 0x0), ISNULL(@TradeChGUID, 0x0), ISNULL(@CustomerTypeGUID, 0x0), ISNULL(@StoreGUID, 0x0), @CustomerState, @ContractNumber, @IsCustomerContracted, @ContractDate, @Notes)

	SELECT 1 AS ImportResult
	RETURN
#############################
#END
