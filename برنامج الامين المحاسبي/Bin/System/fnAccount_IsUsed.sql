#########################################################
CREATE FUNCTION fnAccount_IsUsed(@AccGUID [UNIQUEIDENTIFIER],@HaveFlag [INT] = 0)
	RETURNS [BIGINT] 
AS BEGIN 
/*  
this function:  
	- returns a constanct integer representing the existance of a given account in the database tables.  
	- is usually called from trg_ac000_CheckConstraints.  
*/  
	DECLARE @result [BIGINT]
	SET @result = 0 
	IF EXISTS(SELECT * FROM [ac000] WHERE [ParentGUID]		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000001 
		IF (@HaveFlag = 0)
			GOTO ENDF
		IF @HaveFlag = 2
			SET @HaveFlag = 0
	END
	IF EXISTS(SELECT * FROM [ac000] WHERE [FinalGUID]		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000002
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [as000] WHERE [AccGUID]			= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000004
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [as000] WHERE [DepAccGUID]		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000008
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [as000] WHERE [AccuDepAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000010
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [as000] WHERE [ExpensesAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000020
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [as000] WHERE [RevaluationAccGuid]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000040
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [as000] WHERE [CapitalProfitAccGuid]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000080
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [as000] WHERE [CapitalLossAccGuid]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000100
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefBillAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000200
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefCashAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000400
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefMainAccount] = @AccGUID)
	BEGIN 
	  SET @result = @result | 0x000000000400
		IF (@HaveFlag = 0)
			GOTO ENDF
	END 
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefDiscAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000000800
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefExtraAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000001000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefVATAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000002000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefCostAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000002000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefStockAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000004000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefBonusAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000008000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bt000] WHERE [DefBonusContraAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000010000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bu000] WHERE [CustAccGUID]		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000020000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [bu000] WHERE [MatAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000040000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ch000] WHERE [AccountGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000080000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [di000] WHERE [AccountGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000100000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [et000] WHERE [DefAccGUID] 		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000200000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ma000] WHERE [MatAccGUID] 		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000400000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ma000] WHERE [DiscAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000000800000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ma000] WHERE [ExtraAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000001000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ma000] WHERE [VATAccGUID] 		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000002000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	ELSE IF EXISTS(SELECT * FROM [ma000] WHERE [StoreAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000004000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	ELSE IF EXISTS(SELECT * FROM [ma000] WHERE [CostAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000008000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	ELSE IF EXISTS(SELECT * FROM [ma000] WHERE [CashAccGuid] = @AccGUID)
	BEGIN
		SET @result = @result | 0x1000000000001000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [mn000] WHERE [InAccountGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000010000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [mn000] WHERE [OutAccountGUID] 		= @AccGUID)
	BEGIN
		SET @result = @result | 0x000020000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [mn000] WHERE [InTempAccGUID]	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000040000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [mn000] WHERE [OutTempAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000080000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [mx000]  WHERE [AccountGuid] = @AccGUID)
	BEGIN
		SET @result = @result | 0x000100000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefPayAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000200000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefRecAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000400000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefColAccGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x000800000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT
			 *  FROM [ChequesPortfolio000]
					  WHERE @AccGUID
						 IN   ([ReceiveAccGUID]
				  ,[PayAccGUID]
				  ,[ReceivePayAccGUID]
				  ,[EndorsementAccGUID]
				  ,[CollectionAccGUID]
				  ,[UnderDiscountingAccGUID]
				  ,[DiscountingAccGUID]))
	BEGIN
		SET @result = @result | 0x000808880080
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [py000] WHERE [AccountGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x001000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [st000] WHERE [AccountGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x002000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	
	IF EXISTS(SELECT * FROM [ci000] WHERE [SonGUID]			= @AccGUID)
	BEGIN
		SET @result = @result | 0x008000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [en000] WHERE [AccountGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x010000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [en000] WHERE [contraAccGuid] = @AccGuid)
	BEGIN
		SET @result = @result | 0x020000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [cu000] WHERE [AccountGUID] 	= @AccGUID)
	BEGIN
		SET @result = @result | 0x004000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS (SELECT * FROM  TrnExchangeTypes000 WHERE  
			RoundAccGuid = @AccGuid OR ExchangeAcc = @AccGuid)          
	BEGIN
		SET @result = @result | 0x040000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END		 
	IF EXISTS (SELECT * FROM  TrnCurrencyAccount000 
			 WHERE 	AccountGUID = @AccGuid)
	BEGIN
		SET @result = @result | 0x080000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END		
	IF EXISTS (SELECT * FROM  [sm000] WHERE [CustAccGUID] = @AccGuid) 
	BEGIN
		SET @result = @result | 0x100000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END	
	
	IF EXISTS (SELECT * FROM  [bu000] WHERE [FPayAccGUID] = @AccGuid)  
	BEGIN 
		SET @result = @result | 0x110000000000 
		IF (@HaveFlag = 0) 
			GOTO ENDF 
	END
	IF EXISTS (SELECT * FROM  [Hosemployee000] WHERE [AccGuid] = @AccGuid)  
	BEGIN 
		SET @result = @result | 0x111000000000 
		IF (@HaveFlag = 0) 
			GOTO ENDF 
	END
	IF EXISTS (SELECT * FROM  [JobOrder000] WHERE [Account] = @AccGuid)   
	BEGIN  
		SET @result = @result | 0x200000000000  
		IF (@HaveFlag = 0)  
			GOTO ENDF  
	END 
	IF EXISTS (SELECT * FROM  [JOCBOMSpoilage000] WHERE [SpoilageAccount] = @AccGuid)   
	BEGIN  
		SET @result = @result | 0x200000000000  
		IF (@HaveFlag = 0)  
			GOTO ENDF  
	END 	
	IF EXISTS (SELECT * FROM  [JOCOperatingBOMFinishedGoods000] WHERE [SpoilageAccount] = @AccGuid)   
	BEGIN  
		SET @result = @result | 0x200000000000  
		IF (@HaveFlag = 0)  
			GOTO ENDF  
	END 
	IF EXISTS (SELECT * FROM  [ProductionLine000] WHERE [ExpensesAccount] = @AccGuid)   
	BEGIN  
		SET @result = @result | 0x400000000000  
		IF (@HaveFlag = 0)  
			GOTO ENDF  
	END 
	IF Exists ( select * From SpecialOffers000 
				where @AccGuid IN (AccountGuid, ItemsAccount, ItemsDiscountAccount, OfferedItemsAccount, OfferedItemsDiscountAccount)
			  )
	BEGIN
		SET @result = @result | 0x800000000000   
		IF (@HaveFlag = 0)   
			GOTO ENDF   
	END 
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefRecOrPayAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x000808000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefUnderDisAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x000808880000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefComAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x000888800000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefChargAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x000888040000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefEndorseAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x040888040000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [nt000] WHERE [DefDisAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x040888040040
		IF (@HaveFlag = 0)
			GOTO ENDF
	END 
	
	IF EXISTS(SELECT * FROM [nt000] WHERE [ExchangeRatesAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x040888040040
		IF (@HaveFlag = 0)
			GOTO ENDF
	END 
	IF EXISTS(SELECT * FROM [ChequesPortfolio000] WHERE [ReceiveAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x01000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ChequesPortfolio000] WHERE [PayAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x02000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ChequesPortfolio000] WHERE [ReceivePayAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x04000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ChequesPortfolio000] WHERE [EndorsementAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x08000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ChequesPortfolio000] WHERE [CollectionAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x10000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(SELECT * FROM [ChequesPortfolio000] WHERE [UnderDiscountingAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x20000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END 
	IF EXISTS(SELECT * FROM [ChequesPortfolio000] WHERE [DiscountingAccGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x40000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END 
	IF EXISTS(SELECT * FROM [AccCostNewRatio000] WHERE [SonGUID] = @AccGUID)
	BEGIN
		SET @result = @result | 0x80000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(select ReceiptAccounts from TrnReceiptPayAccounts000 WHERE ISNULL(ReceiptAccounts, 0x0) <> 0x0 AND ReceiptAccounts = @AccGUID)
	BEGIN
		SET @result = @result | 0x1000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS(select PayAccounts from TrnReceiptPayAccounts000 WHERE ISNULL(PayAccounts, 0x0) <> 0x0 AND PayAccounts = @AccGUID)
	BEGIN
		SET @result = @result | 0x2000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF EXISTS ( SELECT * FROM RestVendor000 WHERE AccountGUID = @AccGUID )
	BEGIN
		SET @result = @result | 0x110000000000000
		IF (@HaveFlag = 0)
			GOTO ENDF
	END
	IF Exists ( select * From SpecialOffer000 
				where @AccGuid IN (CustomersAccountID, AccountID, MatAccountID, DiscountAccountID)
			  )
	BEGIN
		SET @result = @result | 0x4400000000000000 
		IF (@HaveFlag = 0)   
			GOTO ENDF   
	END 
ENDF:
	RETURN @result
END 

#########################################################
#END
