#################################################################
CREATE PROC prcPDAStockTransfer_Post
AS
	SET NOCOUNT ON    
	DECLARE @CurGUID 		uniqueidentifier,        
			@CurVal		float,         
			@BranchGUID		uniqueidentifier,        
			@UserGuid		uniqueidentifier 
	SELECT @CurGUID = GUID, @CurVal = CurrencyVal FROM My000 WHERE Number = 1         
	SELECT @BranchGuid = ISNULL(Guid, 0x0) FROM br000 WHERE Number = 1  
	SET @BranchGuid = ISNULL(@BranchGuid, 0x0)   
	Select @UserGuid = Guid From us000 Where Number = 1  
	 
	DECLARE @C			CURSOR, 
			@buGuid		UNIQUEIDENTIFIER, 
			@btGuid		UNIQUEIDENTIFIER, 
			@buNumber	INT	 
	 
	SET @C = CURSOR FAST_FORWARD FOR SELECT Guid, TypeGuid FROM PDAStTr_Bu ORDER By Number 
	OPEN @C FETCH FROM @C INTO @buGuid, @btGuid 
	
	--EXEC prcDisableTriggers 'bu000'
	--EXEC prcDisableTriggers 'bi000'
	WHILE @@FETCH_STATUS = 0            
	BEGIN     
		SELECT @buNumber = dbo.fnDistGetNewBillNum(@btGuid) 
		---- Bu000 
		INSERT INTO Bu000(  
			Number, Cust_Name, Date, CurrencyVal, Notes, Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay, Profits, IsPosted,          
			Security, Vendor, SalesManPtr, Branch, VAT, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, CustAccGUID, MatAccGUID, ItemsDiscAccGUID,          
			BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID, TextFld1, TextFld2, TextFld3, TextFld4, RecState, ItemsExtra,         
			ItemsExtraAccGUID, CostAccGUID, StockAccGUID, VATAccGUID, BonusAccGUID, BonusContraAccGUID, IsPrinted     
		)     
		SELECT  
			@buNumber, '', Date, @CurVal, ISNULL(Notes, ''), 0, 1, 0, 0, 0, 0, 0, 0, 0,	-- Is Posted 
			1, 0, 1, @BranchGuid, 0, Guid, TypeGuid, 0x00, @CurGuid, StoreGuid, 0x00, 0x00, 0x00, 
			0x00, 0x00,	0x00, @UserGuid, 0x00, '', '', '', '', 0, 0,  
			0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0			 
		FROM  
			PDAStTr_Bu 
		WHERE 
			Guid = @buGuid	 
		---- Bi000 
		
		INSERT INTO Bi000(     
			Number, Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal, Notes,  
			Profits, Num1, Num2, Qty2, Qty3, ClassPtr, [ExpireDate], ProductionDate, [Length], Width, Height, GUID,          
			VAT, VATRatio, ParentGUID, MatGUID, CurrencyGUID, StoreGUID, CostGUID, SOType, SOGuid         
		)     
		SELECT     
			bi.Number, Qty = CASE bi.Unity When 2 THEN bi.Qty*mt.Unit2Fact WHEN 3 THEN bi.Qty*mt.Unit3Fact ELSE bi.Qty END,  
			0, 0, bi.Unity, 0, 0, 0, 0, 0, 1, '', -- Notes 
			0, 0, 0, 0, 0, '', '01-01-1980', '01-01-1980', 0, 0, 0, NewId(),  
			0 ,0, ParentGuid, MatGuid, @CurGuid, StoreGuid, 0x00, 0, 0x00 
		FROM  
			PDAStTr_Bi AS bi 
			INNER JOIN mt000 AS mt ON mt.Guid = bi.MatGuid 
		WHERE  
			ParentGuid = @buGuid 
		 
		FETCH FROM @C INTO @buGuid, @btGuid 
	END 
	CLOSE @C DEALLOCATE @C	 
	
	--EXEC prcEnableTriggers 'bu000'
	--EXEC prcEnableTriggers 'bi000'
	---------------------------------------------------------------------- 
	--- TS000 
	INSERT INTO TS000(   
		Guid, OutBillGuid, InBillGuid			   
	)   
	SELECT   
		Guid, OutBillGuid, InBillGuid   
	FROM    
		PDAStTr_Ts 
	----------------------------------------------------------------------- 
	--- Post Bills 
	ALTER TABLE ms000 DISABLE TRIGGER trg_ms000_CheckBalance  
	UPDATE bu000 SET IsPosted = 1  
	FROM bu000 AS bu  
		INNER JOIN bt000 AS bt ON bt.Guid = bu.TypeGuid AND bt.bAutoPost = 1 
		INNER JOIN PDAStTr_Bu AS pda ON pda.Guid = bu.Guid 
	ALTER TABLE ms000 ENABLE TRIGGER trg_ms000_CheckBalance  
	----------------------------------------------------------------------- 
	-- Fix Expiry Date	     
	CREATE TABLE #PDABillGuids(GUID UNIQUEIDENTIFIER, DistributorGUID UNIQUEIDENTIFIER)    
	INSERT INTO  #PDABillGuids SELECT Guid, 0x0 From PDAStTr_Bu
	
	DECLARE @CheckExpireDatePalm BIT   
		 
	SELECT @CheckExpireDatePalm = ISNULL(op000.[Value],0) FROM op000 WHERE Name = 'DistCfg_CHECK_MAT_VALIDITY' 
	   
	IF (@CheckExpireDatePalm = 1)
		EXEC prcCheckExpireDatePalm   
	-- End Fix Expiry Date    
	
	DELETE 	FROM PDAStTr_Bu 
	DELETE 	FROM PDAStTr_Bi 
	DELETE 	FROM PDAStTr_Ts 

/*
Select * from PDAStTr_Bu
Select * from PDAStTr_Bi
Select * from PDAStTr_Ts
Select bAutoPost, * From bt000
*/
#################################################################
#END
