#########################################################
CREATE PROCEDURE prcDiscount_Add
	@Number [FLOAT], 
	@Discount [FLOAT], 
	@Extra [FLOAT], 
	@CurrencyVal [FLOAT], 
	@Notes [NVARCHAR](1000),  
	@Flag [INT],  
	-- @GUID [UNIQUEIDENTIFIER],  
	@ClassPtr [NVARCHAR](250),  
	@ParentGUID [UNIQUEIDENTIFIER],  
	@AccountGUID [UNIQUEIDENTIFIER],  
	@CustomerGUID [UNIQUEIDENTIFIER], 
	@CurrencyGUID [UNIQUEIDENTIFIER],  
	@CostGUID [UNIQUEIDENTIFIER],  
	@ContraAccGUID [UNIQUEIDENTIFIER],
	@IsGeneratedByPayTerms [BIT] = 0,
	@IsValue [BIT] = 0,
	@IsRatio [BIT] = 0
AS  
	SET NOCOUNT ON  
	INSERT INTO di000 
	( 
		Number,  
		Discount,  
		Extra,  
		CurrencyVal,  
		Notes,  
		Flag,  
		GUID,  
		ClassPtr,  
		ParentGUID,  
		AccountGUID,  
		CustomerGUID , 
		CurrencyGUID,  
		CostGUID,  
		ContraAccGUID,
		IsGeneratedByPayTerms,
		IsValue,
		IsRatio
	) 
	VALUES 
	( 
		@Number, 
		@Discount, 
		@Extra, 
		@CurrencyVal, 
		@Notes,  
		@Flag,  
		newid(),  
		@ClassPtr,  
		@ParentGUID,  
		@AccountGUID, 
		@CustomerGUID, 
		@CurrencyGUID,  
		@CostGUID,  
		@ContraAccGUID,
		@IsGeneratedByPayTerms,
		@IsValue,
		@IsRatio
	) 
#########################################################
#END