##################################################################
CREATE PROC prcBill_reConnectPayments
	@BillGUID UNIQUEIDENTIFIER, 
	@DeletePaysLinks BIT = 0,
	@EnFirstPayGUID UNIQUEIDENTIFIER = 0x0,
	@HasSecDeletePaysLink BIT = 1
AS 
	SET NOCOUNT ON 

	IF ISNULL(@BillGUID, 0x0) = 0x0
		RETURN
	
	CREATE TABLE #bp_res([DebtGUID] UNIQUEIDENTIFIER, [PayGUID] UNIQUEIDENTIFIER)

	SELECT * INTO #bp FROM bp000 WHERE ((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) AND ([Type] = 0)
	SELECT TOP 0 * INTO #bp_temp FROM #bp
	IF ((@HasSecDeletePaysLink = 0) AND EXISTS(SELECT * FROM #bp))
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 2, 0, 'AmnW0083: Can''t reconnect related payments.', @BillGUID
		RETURN
	END  
	IF NOT EXISTS (SELECT * FROM #bp)
	BEGIN 
		IF ISNULL(@EnFirstPayGUID, 0x0) != 0x0
			INSERT INTO #bp_res EXEC prcEntry_ConnectDebtPay @billGUID, @EnFirstPayGUID, 1
		RETURN 
	END
	DELETE bp000 WHERE ((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) AND ([Type] = 0)
	IF ISNULL(@EnFirstPayGUID, 0x0) != 0x0
		INSERT INTO #bp_res EXEC prcEntry_ConnectDebtPay @billGUID, @EnFirstPayGUID, 1

	IF @DeletePaysLinks = 1
	BEGIN 
		DECLARE @FirstPay FLOAT 
		SET @FirstPay = ISNULL((SELECT SUM(CASE WHEN DebtGUID = @BillGUID THEN Val ELSE PayVal END) FROM bp000 WHERE ((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) AND [Type] = 1), 0)
		IF ISNULL(dbo.fnCalcBillTotal(@billGUID, DEFAULT), 0) < (SELECT SUM(CASE WHEN DebtGUID = @BillGUID THEN val ELSE PayVal END) FROM #bp) + @FirstPay
			RETURN 
	END 

	DECLARE @bp_related TABLE([bpGUID] UNIQUEIDENTIFIER, [PayGUID] UNIQUEIDENTIFIER, PaidValue FLOAT, [Date] DATETIME, Number INT, [Value] FLOAT)
	INSERT INTO @bp_related
	SELECT 
		bp.GUID, 
		(CASE WHEN bp.DebtGUID = @BillGUID THEN bp.PayGUID ELSE DebtGUID END), 
		bp.Val / (CASE bp.CurrencyVal WHEN 0 THEN 1 ELSE bp.CurrencyVal END),
		ce.Date, ce.Number, (CASE WHEN en.Debit > 0 THEN en.Debit ELSE en.Credit END)
	FROM
		#bp bp 
		INNER JOIN en000 en ON ((bp.DebtGUID = en.GUID) OR (bp.PayGUID = en.GUID))
		INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
	UNION ALL 
	SELECT 
		bp.GUID, 
		(CASE WHEN bp.DebtGUID = @BillGUID THEN bp.PayGUID ELSE DebtGUID END), 
		bp.Val / (CASE bp.CurrencyVal WHEN 0 THEN 1 ELSE bp.CurrencyVal END),
		bu.Date, bu.Number, 0
	FROM
		#bp bp 
		INNER JOIN bu000 bu ON ((bp.DebtGUID = bu.GUID) OR (bp.PayGUID = bu.GUID))
	UNION ALL 
	SELECT 
		bp.GUID, 
		(CASE WHEN bp.DebtGUID = @BillGUID THEN bp.PayGUID ELSE DebtGUID END), 
		bp.Val / (CASE bp.CurrencyVal WHEN 0 THEN 1 ELSE bp.CurrencyVal END),
		orp.PaymentDate, orp.PaymentNumber, 0
	FROM
		#bp bp 
		INNER JOIN [vwOrderPayments] As [orp] ON ((bp.DebtGUID = [orp].[PaymentGUID]) OR (bp.PayGUID = [orp].[PaymentGUID]))
		INNER JOIN [bu000] [bu] ON [bu].[Guid] = [orp].[BillGuid] 		

	DECLARE @c_bp CURSOR, @payGUID UNIQUEIDENTIFIER, @bpGUID UNIQUEIDENTIFIER, @bpPayValue FLOAT
	SET @c_bp = CURSOR FAST_FORWARD FOR 
		SELECT bpGUID, PayGUID, PaidValue 
		FROM 
			@bp_related
		ORDER BY [Date], [Number], [Value] DESC
	
	OPEN @c_bp FETCH NEXT FROM @c_bp INTO @bpGUID, @payGUID, @bpPayValue
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		DELETE #bp_res
		INSERT INTO #bp_res EXEC prcEntry_ConnectDebtPay @BillGUID, @payGUID, 0, @bpPayValue
		IF EXISTS(SELECT * FROM #bp_res)
			INSERT INTO #bp_temp SELECT * FROM #bp WHERE [GUID] = @bpGUID

		FETCH NEXT FROM @c_bp INTO @bpGUID, @payGUID, @bpPayValue
	END CLOSE @c_bp DEALLOCATE @c_bp

	IF (SELECT COUNT(*) FROM  #bp_temp) != (SELECT COUNT(*) FROM #bp) 
	BEGIN 
		IF ((@DeletePaysLinks = 1) AND (@HasSecDeletePaysLink = 1))
		BEGIN 
			DELETE bp000 WHERE ((DebtGUID = @billGUID) OR (PayGUID = @billGUID)) AND [Type] = 0
		END ELSE 
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 2, 0, 'AmnW0083: Can''t reconnect related payments.', @BillGUID
	END 

##################################################################
CREATE PROC prcBill_GetBiFields
	@btConsideredGiftsOfSales	[BIT],
	@buMatAccGUID			[UNIQUEIDENTIFIER],
	@btDefBillAccGUID		[UNIQUEIDENTIFIER],
	@buVATAccGUID			[UNIQUEIDENTIFIER],
	@buCustAccGUID			[UNIQUEIDENTIFIER],
	@btBillType				[INT],
	@IsGCCSystemEnabled		[BIT],
	@billGUID				[UNIQUEIDENTIFIER],
	@buCustomerGUID			[UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON; 

	DECLARE @language [INT]		SET @language = [dbo].[fnConnections_getLanguage]() 

	DECLARE 
		@buItemsDiscAccGUID		[UNIQUEIDENTIFIER],
		@buItemsExtraAccGUID	[UNIQUEIDENTIFIER], 
		@btDefDiscAccGUID		[UNIQUEIDENTIFIER],
		@btDefExtraAccGUID		[UNIQUEIDENTIFIER],
		@btDefVATAccGUID		[UNIQUEIDENTIFIER],
		@buStockAccGUID			[UNIQUEIDENTIFIER],
		@btDefStockAccGUID		[UNIQUEIDENTIFIER], 
		@buCostAccGUID			[UNIQUEIDENTIFIER], 
		@btDefCostAccGUID		[UNIQUEIDENTIFIER], 
		@buBonusAccGUID			[UNIQUEIDENTIFIER], 		 
		@btDefBonusAccGuid		[UNIQUEIDENTIFIER],
		@buBonusContraAccGUID	[UNIQUEIDENTIFIER],
		@btDefBonusContraAccGuid [UNIQUEIDENTIFIER],
		@buTypeGUID				[UNIQUEIDENTIFIER]

	SELECT 	
		@buItemsDiscAccGUID		= [ItemsDiscAccGUID],
		@buItemsExtraAccGUID	= [ItemsExtraAccGUID],
		@buBonusAccGUID			= [BonusAccGUID],
		@buBonusContraAccGUID	= [BonusContraAccGUID],
		@buCostAccGUID			= [CostAccGUID],
		@buStockAccGUID			= [StockAccGUID],
		@buTypeGUID				= [TypeGUID]
	  FROM vtBu
	 WHERE [GUID] = @billGUID 

	SELECT 
		@btDefCostAccGUID		= [btDefCostAcc], 
		@btDefStockAccGUID		= [btDefStockAcc], 
		@btDefDiscAccGUID		= [btDefDiscAcc], 
		@btDefVATAccGUID		= [btDefVATAcc], 
		@btDefExtraAccGUID		= [btDefExtraAcc], 
		@btDefBonusAccGuid		= [btDefBonusAccGuid], 
		@btDefBonusContraAccGuid = [btDefBonusContraAccGuid]
	  FROM [vwBt]
	 WHERE [btGUID] = @buTypeGUID 
	
	------ read the customer VAT account
	DECLARE @BuCustAddedValGUID [UNIQUEIDENTIFIER]
	IF ISNULL(@buCustomerGUID, 0x0) <> 0x0
	    SET @BuCustAddedValGUID = (SELECT  AddedValueAccountGUID FROM cu000 WHERE GUID = @buCustomerGUID)
	ELSE 
		SET @BuCustAddedValGUID =  0x0

	-- bi buffer table filling: 
	--INSERT INTO #t_bi 
		SELECT 
		  [bi].[biGUID],
			(CASE WHEN @language <> 0 AND [bi].[mtLatinName] <> '' THEN [bi].[mtLatinName] ELSE [bi].[mtName] END) mtName,--[bi].[mtName], 
			[bi].[biMatPtr], 
			[bi].[biCurrencyVAL],
			[bi].[biClassPtr],
			[bi].[biCurrencyPtr],
			[bi].[biVAT],
			[bi].[biNumber],
			[bi].[biPrice],
			[bi].[biDiscount],
			[bi].[biBonusDisc],
			[bi].[biExtra],
			[bi].[biBillQty] + (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biBillBonusQnt] ELSE 0 END),
			[bi].[biBillBonusQnt],
			[bi].[biNotes],
			[bi].[biCostPtr],
			[bi].[biProfits],
			[bi].[biUnity],   
			---- New Update For SpecailOffer System
		    CASE 
				WHEN ISNULL([bi].[biSOGuid], 0x0) <> 0x0 AND (SELECT [Type] FROM SpecialOffers000 WHERE [GUID] = [so].[SOGuid]) = 4 
					THEN CASE ISNULL([so].[SOMatAccAccount], 0x00) 
						WHEN 0x0 THEN CASE ISNULL(Asset.[AccGuid], 0x00) 
							WHEN 0x0 THEN CASE @buMatAccGUID 
								WHEN 0x0 THEN CASE ISNULL([ma_user].[maMatAccGUID], 0x0) 
									WHEN 0x0 THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0) 
										WHEN 0x0 THEN CASE ISNULL([ga_mat].maMatAccGUID, 0X0) 
											WHEN 0x0 THEN @btDefBillAccGUID			
											ELSE [ga_mat].maMatAccGUID END 
										ELSE [ma_mat].[maMatAccGUID] END 
									ELSE [ma_user].[maMatAccGUID] END 
								ELSE @buMatAccGUID END 
							ELSE Asset.[AccGuid] END
						ELSE [so].[SOMatAccAccount] END 
			ELSE
				CASE WHEN ISNULL( [bi].[biSOType], -1) = 1 OR ISNULL( [bi].[biSOType], -1) = 2 
				THEN 
					CASE WHEN ISNULL([POSso].AccountID  , 0x00) = 0x0 OR ISNULL([offeredItems].MatID, 0x00) <> 0x0
						THEN CASE WHEN ISNULL([POSso].MatAccountID, 0x00) = 0x0 OR ISNULL([offeredItems].MatID, 0x00) = 0x0   
							THEN CASE ISNULL( [so].[SOMatAccAccount], 0x00) WHEN 0x0
								THEN CASE ISNULL(Asset.[AccGuid], 0x00) WHEN 0x0
									THEN CASE @buMatAccGUID WHEN 0x0 
										THEN CASE ISNULL([ma_user].[maMatAccGUID], 0x0)	WHEN 0x0 
											THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0)	WHEN 0x0 
												THEN @btDefBillAccGUID			
												ELSE [ma_mat].[maMatAccGUID] END
											ELSE [ma_user].[maMatAccGUID] END 
										ELSE @buMatAccGUID END 
									ELSE Asset.[AccGuid] END
								ELSE [so].[SOMatAccAccount] END 
							ELSE [POSso].MatAccountID END
						ELSE [POSso].AccountID END
				ELSE CASE WHEN ISNULL([POSso].AccountID  , 0x00) = 0x0 or ISNULL([offeredItems].MatID  , 0x00) <> 0x0  
						THEN CASE WHEN ISNULL([POSso].MatAccountID  , 0x00) = 0x0  or ISNULL([offeredItems].MatID  , 0x00) = 0x0  
							THEN CASE ISNULL( [soC].[SOMatAccAccount], 0x00) WHEN 0x00 
								THEN CASE ISNULL(Asset.[AccGuid], 0x00) WHEN 0x0
									THEN CASE @buMatAccGUID WHEN 0x0 
										THEN CASE ISNULL([ma_user].[maMatAccGUID], 0x0)	WHEN 0x0 
											THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0)	WHEN 0x0 
												THEN CASE ISNULL([ga_mat].maMatAccGUID, 0X0) WHEN 0x0 
													THEN @btDefBillAccGUID	
													ELSE [ga_mat].maMatAccGUID END	
												ELSE [ma_mat].[maMatAccGUID] END 
											ELSE [ma_user].[maMatAccGUID] END 
										ELSE @buMatAccGUID END
									ELSE Asset.[AccGuid] END
								ELSE [soC].[SOMatAccAccount] END 
							ELSE [POSso].MatAccountID END
						ELSE [POSso].AccountID END
					END
		END,
			----
			---- Check SpecialOffer Discounts
			-- CASE @buItemsDiscAccGUID	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		WHEN 0x0 THEN @btDefDiscAccGUID			ELSE [ma_mat].[maDiscAccGUID]			END ELSE [ma_user].[maDiscAccGUID]			END ELSE @buItemsDiscAccGUID END, 
			CASE
				WHEN ISNULL([bi].[biSOGuid], 0x0) <> 0x0 AND (SELECT [Type] FROM SpecialOffers000 WHERE [GUID] = [so].[SOGuid]) = 4 
					THEN CASE ISNULL( [so].[SODiscAccAccount], 0x0) WHEN 0x0 THEN CASE @buItemsDiscAccGUID	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0) WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0) WHEN 0x0 THEN CASE ISNULL([ga_mat].maDiscAccGUID, 0X0) WHEN 0x0 THEN @btDefDiscAccGUID			ELSE [ga_mat].maDiscAccGUID END ELSE [ma_mat].[maDiscAccGUID] END ELSE [ma_user].[maDiscAccGUID]	END ELSE @buItemsDiscAccGUID  END ELSE [so].[SODiscAccAccount] END 
				ELSE
				CASE 
					WHEN ISNULL( [bi].[biSOType], -1) = 1 OR ISNULL( [bi].[biSOType], -1) = 2 THEN 
						CASE WHEN ISNULL([POSso].DiscountAccountID , 0x0) = 0x0 
						THEN 
						CASE ISNULL([so].[SODiscAccAccount], 0x0) 
							WHEN 0x0 THEN CASE @buItemsDiscAccGUID	
								WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			
									WHEN 0x0 THEN 
										CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		
											WHEN 0x0 THEN @btDefDiscAccGUID			
											ELSE [ma_mat].[maDiscAccGUID]			
										END 
									ELSE [ma_user].[maDiscAccGUID] END 
								ELSE @buItemsDiscAccGUID END 
							ELSE [so].[SODiscAccAccount] END
						ELSE [POSso].DiscountAccountID END
					ELSE
						CASE ISNULL( [soC].[SODiscAccAccount], 0x00) WHEN 0x00 THEN
							CASE @buItemsDiscAccGUID	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		WHEN 0x0 THEN 		CASE ISNULL([ga_mat].maDiscAccGUID, 0X0) WHEN 0x0 THEN @btDefDiscAccGUID			ELSE [ga_mat].maDiscAccGUID END	ELSE [ma_mat].[maDiscAccGUID]			END ELSE [ma_user].[maDiscAccGUID]			END ELSE @buItemsDiscAccGUID END
						ELSE [soC].[SODiscAccAccount] END	
				END
			END,
			----
			CASE @buItemsExtraAccGUID	WHEN 0x0 THEN CASE ISNULL([ma_user].[maExtraAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maExtraAccGUID], 0x0)		WHEN 0x0 THEN  CASE ISNULL([ga_mat].maExtraAccGUID, 0X0) WHEN 0x0 THEN @btDefExtraAccGUID			ELSE [ga_mat].maExtraAccGUID END		ELSE [ma_mat].[maExtraAccGUID]		END ELSE [ma_user].[maExtraAccGUID]			END ELSE @buItemsExtraAccGUID END, 
			--if there is a VAT account in the customer card then you must give it the highest priority when generating the entry
			CASE @BuCustAddedValGUID    WHEN 0x0 THEN 
				CASE @buVATAccGUID			WHEN 0x0 THEN 
					CASE ISNULL([ma_user].[maVATAccGUID], 0x0)	WHEN 0x0 THEN 
						 CASE ISNULL([ma_mat].[maVATAccGUID], 0x0)	WHEN 0x0 THEN 
							CASE ISNULL([ga_mat].maVATAccGUID, 0X0) WHEN 0x0 THEN
								@btDefVATAccGUID			
							ELSE
								[ga_mat].maVATAccGUID
							END
						 ELSE 
							[ma_mat].[maVATAccGUID]			
						 END 
					ELSE 
						[ma_user].[maVATAccGUID]			
					END 
				ELSE 
					@buVATAccGUID 
				END
			ELSE 
				@BuCustAddedValGUID 
			END,  
			-------
			CASE @buStockAccGUID		WHEN 0x0 THEN CASE ISNULL([ma_user].[maStoreAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maStoreAccGUID], 0x0)		WHEN 0x0 THEN @btDefStockAccGUID		ELSE [ma_mat].[maStoreAccGUID]			END ELSE [ma_user].[maStoreAccGUID]			END ELSE @buStockAccGUID END, 
			CASE @buCostAccGUID			WHEN 0x0 THEN CASE ISNULL([ma_user].[maCostAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maCostAccGUID], 0x0)		WHEN 0x0 THEN @btDefCostAccGUID			ELSE [ma_mat].[maCostAccGUID]			END ELSE [ma_user].[maCostAccGUID]			END ELSE @buCostAccGUID END, 
			CASE @buBonusAccGUID		
				WHEN 0x0 THEN 
					CASE ISNULL([ma_user].[maBonusAccGuid], 0x0)			
						WHEN 0x0 THEN 
							CASE ISNULL([ma_mat].[maBonusAccGUID], 0x0)		
								WHEN 0x0 THEN 
									CASE ISNULL([ga_mat].[maBonusAccGUID], 0x0)
										WHEN 0x0 THEN @btDefBonusAccGUID --Âœ«Ì« ‰„ÿ «·›« Ê—…
										ELSE [ga_mat].[maBonusAccGUID] -- Âœ«Ì« Õ”«»«  »ÿ«ﬁ… «·„Ã„Ê⁄…
									END	
								ELSE [ma_mat].[maBonusAccGUID] -- Âœ«Ì« Õ”«»«  »ÿ«ﬁ… «·„«œ…
							END 
						ELSE [ma_user].[maBonusAccGUID]	-- Âœ«Ì« Õ”«»«  «·›Ê« Ì— ›Ì ≈œ«—… «·„” Œœ„Ì‰
					END 
				ELSE @buBonusAccGUID --Âœ«Ì« „“Ìœ
			END,
			CASE @buBonusContraAccGUID	WHEN 0x0 THEN CASE ISNULL([ma_user].[maBonusContraAccGuid], 0x0)	WHEN 0x0 THEN CASE ISNULL([ma_mat].[maBonusContraAccGUID], 0x0)	WHEN 0x0 THEN @btDefBonusContraAccGUID	ELSE [ma_mat].[maBonusContraAccGUID]	END ELSE [ma_user].[maBonusContraAccGUID]	END ELSE @buBonusContraAccGUID END,
			ISNULL(cbi.Discount, 0) ,
			-- ISNULL(soc.SODiscAccAccount, 0x0)
			CASE ISNULL( [soc].[SODiscAccAccount], 0x0) WHEN 0x0 THEN CASE @buItemsDiscAccGUID	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		WHEN 0x0 THEN @btDefDiscAccGUID			ELSE [ma_mat].[maDiscAccGUID]			END ELSE [ma_user].[maDiscAccGUID]			END ELSE @buItemsDiscAccGUID  END ELSE [soc].[SODiscAccAccount] END
		,(CASE WHEN @language <> 0 AND [bi].[btLatinName] <> '' THEN [bi].[btLatinName] ELSE [btName] END)--[bi].[btName]
		,[bi].[buNumber]
		,[bi].isApplyTaxOnGifts
		,[bi].[mtGroup]
        ,[bi].[biSOGuid]
		,bi.biTotalDiscountPercent
		,bi.biTotalExtraPercent
		,CASE [bi].buPayType 
			WHEN 0 THEN      	
				CASE ISNULL([ma_user].[maCashAccGUID], 0x0)			
         		   WHEN 0x0 THEN 
         			   CASE ISNULL([ma_mat].[maCashAccGUID], 0x0)		
         				  WHEN 0x0 THEN 
         					  CASE ISNULL([ga_mat].[maCashAccGUID], 0x0)
         						 WHEN 0x0 THEN @buCustAccGUID
         						 ELSE [ga_mat].[maCashAccGUID] 
								 END	
         				  ELSE [ma_mat].[maCashAccGUID] 
						  END 
         			ELSE [ma_user].[maCashAccGUID] 
					END 
		    ELSE @buCustAccGUID 
			END,
		[bi].biExciseTaxVal,
		[bi].biReversChargeVal,
		CASE WHEN (@btBillType = 1 OR @btBillType = 3) AND @IsGCCSystemEnabled = 1 THEN bi.mtVATIsProfitMargin ELSE 0 END
		FROM  
			[vwExtended_bi] AS [bi]   
			LEFT JOIN [vwMa] AS [ma_mat] ON [bi].[biMatPtr] = [ma_mat].[maObjGUID] AND [bi].[buType] = [ma_mat].[maBillTypeGUID] 
			LEFT JOIN [vwMa] AS [ga_mat] ON [bi].[mtGroup]  = [ga_mat].[maObjGUID] AND [bi].[buType] = [ga_mat].[maBillTypeGUID] 
			LEFT JOIN [vwMa] AS [ma_user] ON ([ma_user].[maBillTypeGUID] = [bi].[buType]) AND ([ma_user].[maObjGUID] = [bi].[buUserGUID]) AND ([ma_user].[maType] = 3)
			---- New Update For SpecailOffer System	
			LEFT JOIN [ContractBillItems000]AS [cbi]	ON [cbi].[BillItemGuid] = [bi].[biGuid] 
			LEFT JOIN [vwSOAccounts]		AS [so]		ON [so].[SODetailGuid] = [bi].[biSOGuid]
			LEFT JOIN [vwSOAccounts]		AS [soC]	ON [soC].[SODetailGuid] = [cbi].[ContractItemGuid]
			LEFT JOIN [vwSpecialOffer]		AS [POSso]	ON [POSso].[Guid] = [bi].[biSOGuid]
			LEFT JOIN [OfferedItems000]  as [offeredItems] ON [offeredItems].MatID   = [bi].[biMatPtr] and [offeredItems].ParentID   = [POSso].[Guid]
			LEFT JOIN [as000] AS [Asset] ON [Asset].[ParentGUID] = [bi].[biMatPtr]
		WHERE 
			[bi].[buGUID] = @billGUID 

##################################################################
CREATE PROC prcBill_genEntry
	@billGUID					  UNIQUEIDENTIFIER,   
	@entryNum					  INT = 0,
	@CenteringCusAcc			  INT = 0,
	@maintenanceMode			  BIT = 0,
	@UseOutbalanceAVGPrice		  BIT = 0,
	@DeletePaysLinks			  BIT = 0,
	@HasSecDeletePaysLink		  BIT = 1,
	@IsGCCSystemEnabled			  BIT = 0,
	@AssignContraAccForShortEntry BIT = 0,
	@HandlingGCCTax				  BIT = 1

AS 
/************************* FEATURES NOT IMPLEMNTED YET: 
	- error validations of bu, bi and di: 
		- concistancy errors: lookup guids, summuries... 
		- missing data: nulls, records 
*/ 
--select * From #e
	SET NOCOUNT ON 

	SET @IsGCCSystemEnabled = CASE @HandlingGCCTax WHEN 1 THEN dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0') ELSE 0 END;

	DECLARE @language [INT]						SET @language = [dbo].[fnConnections_getLanguage]() 
	DECLARE @txt_firstPay [NVARCHAR](50)			SET @txt_firstPay						= [dbo].[fnStrings_get]('BILLENTRY\FIRST_PAY', @language) 
	DECLARE @txt_firstPay_fullPay [NVARCHAR](100)SET @txt_firstPay_fullPay				= [dbo].[fnStrings_get]('BILLENTRY\FULL_PAY', @language) 
	DECLARE @txt_itemsDisc [NVARCHAR](50)		SET @txt_itemsDisc						= [dbo].[fnStrings_get]('BILLENTRY\ITEMS_DISCOUNT', @language) 
	DECLARE @txt_itemsExtra [NVARCHAR](50)		SET @txt_itemsExtra						= [dbo].[fnStrings_get]('BILLENTRY\ITEMS_EXTRA', @language) 
	DECLARE @txt_VAT [NVARCHAR](250)				SET @txt_VAT							= [dbo].[fnStrings_get]('BILLENTRY\ITEMS_VAT', @language) 
	DECLARE @txt_bonus [NVARCHAR](50)			SET @txt_bonus							= [dbo].[fnStrings_get]('BILLENTRY\ITEMS_BONUS', @language) 
	DECLARE @txt_Tax [NVARCHAR](50)			    SET @txt_Tax							= [dbo].[fnStrings_get]('BILLENTRY\ITEMS_TAX', @language)  
	DECLARE @Bill_Name [NVARCHAR](50)			SET @Bill_Name							= [dbo].[fnStrings_get]('BILLENTRY\INBILLNOTE', @language)  
	DECLARE @Bill_Num [NVARCHAR](50)			    SET @Bill_Num							= [dbo].[fnStrings_get]('BILLENTRY\BILLNUMBERNOTE', @language)  
	DECLARE @Bill_For_Customer [NVARCHAR](50)	SET @Bill_For_Customer					= [dbo].[fnStrings_get]('BILLENTRY\BILLCUSTOMERNAME', @language)   
	DECLARE @txt_Excise [NVARCHAR](250)				
	DECLARE @txt_ReversCharge [NVARCHAR](250)
	
	-- ordering costants: 
	DECLARE @recType_matAcc						[INT] SET @recType_matAcc				= 1 
	DECLARE @recType_fPayOfMatAcc				[INT] SET @recType_fPayOfMatAcc			= 3 
	DECLARE @recType_ItemsDisc					[INT] SET @recType_ItemsDisc			= 4 
	DECLARE @recType_custAcc					[INT] SET @recType_custAcc				= 6 
	DECLARE @recType_custDisc					[INT] SET @recType_custDisc				= 8 
	DECLARE @recType_fPayOfCustAcc				[INT] SET @recType_fPayOfCustAcc		= 9 
	DECLARE @recType_diCustDiscounts			[INT] SET @recType_diCustDiscounts		= 10 -- used when no MergDiscToCust 
	DECLARE @recType_diExtras					[INT] SET @recType_diExtras				= 11 
	DECLARE @recType_diExtrasToCust				[INT] SET @recType_diExtrasToCust		= 13 
	DECLARE @recType_diDiscounts				[INT] SET @recType_diDiscounts 			= 14 
	DECLARE @recType_ItemsVAT					[INT] SET @recType_ItemsVAT				= 15 
	DECLARE @recType_CustVAT					[INT] SET @recType_CustVAT				= 18 
	DECLARE @recType_Bonus						[INT] SET @recType_Bonus				= 19 
	DECLARE @recType_BonusContra				[INT] SET @recType_BonusContra			= 20 
	DECLARE @recType_Tax						[INT] SET @recType_Tax					= 21
	DECLARE @recType_TaxContra					[INT] SET @recType_TaxContra			= 22
	DECLARE @recType_Excise						[INT] SET @recType_Excise				= 23
	DECLARE @recType_ReversCharges				[INT] SET @recType_ReversCharges		= 24
	DECLARE @recType_ItemsContInvCost			[INT] SET @recType_ItemsContInvCost		= 25 --16 
	DECLARE @recType_ContInvStock				[INT] SET @recType_ContInvStock			= 26 --17 
	DECLARE @total								FLOAT
 	DECLARE @totalDisc							FLOAT
	DECLARE @totalExtra							FLOAT
	DECLARE @TaxBeforeDiscount					BIT
	DECLARE @TaxBeforeExtra						BIT
	DECLARE @IncludeTTCDiffOnSales				BIT
	DECLARE @UseSalesTax						BIT
	DECLARE @ZeroVal							FLOAT

	--******************************************* prepare buffers: 
	-- bi and ma buffer table: 
	CREATE TABLE #t_bi( 
		[biGuid]					[UNIQUEIDENTIFIER],
		[mtName]					[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
		[biMatPtr]					[UNIQUEIDENTIFIER], 
		[biCurrencyVAL]				[FLOAT], 
		[biClassPtr]				[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
		[biCurrencyPtr]				[UNIQUEIDENTIFIER], 
		[biVAT]						[FLOAT], 
		[biNumber]					[INT], 
		[biPrice]					[FLOAT], 
		[biDiscount]				[FLOAT], 
		[biBonusDisc]				[FLOAT],
		[biExtra]					[FLOAT],
		[biBillQty]					[FLOAT], 
		[biBillBonusQnt]			[FLOAT], 
		[biNotes]					[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[biCostPtr]					[UNIQUEIDENTIFIER], 
		[biProfits]					[FLOAT], 
		[biUnity]					[INT],   
		[maMatAccGUID]				[UNIQUEIDENTIFIER], 
		[maDiscAccGUID]				[UNIQUEIDENTIFIER], 
		[maExtraAccGUID]			[UNIQUEIDENTIFIER], 
		[maVATAccGUID]				[UNIQUEIDENTIFIER], 
		[maStoreAccGUID]			[UNIQUEIDENTIFIER], 
		[maCostAccGUID]				[UNIQUEIDENTIFIER], 
		[maBonusAccGuid]			[UNIQUEIDENTIFIER], 
		[maBonusContraAccGuid]		[UNIQUEIDENTIFIER],
		[biContractDiscount]		[FLOAT], 
		[maContractDiscAccGUID]		[UNIQUEIDENTIFIER],
		[biBillname]				[NVARCHAR](256) COLLATE ARABIC_CI_AI ,
		[biBillNumber]					[INT],
		[biIsApplyTaxOnGifts]		[BIT], 
		[biMatGroupPtr] [UNIQUEIDENTIFIER],
		[biSOGuid] [UNIQUEIDENTIFIER],
		biTotalDiscountPercent		FLOAT,
		biTotalExtraPercent			FLOAT, 
		maCashAccGUID  [UNIQUEIDENTIFIER],
		biExcise FLOAT,
		biReversCharge FLOAT,
		IsProfitMargin BIT)
		 
	 -- di buffer table: 
	DECLARE @t_di TABLE( 
		[diAccount]				[UNIQUEIDENTIFIER], 
		[diDiscount]			[FLOAT], 
		[diExtra]				[FLOAT], 
		[diCostGUID]			[UNIQUEIDENTIFIER], 
		[diContraAccGUID]		[UNIQUEIDENTIFIER], 
		[diCurrencyVAL]			[FLOAT], 
		[diCurrencyPtr]			[UNIQUEIDENTIFIER], 
		[diNotes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[diNumber]				[INT], 
		[diClassPtr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI) 
	 
	-- di distributive accounts sons  	
	DECLARE @t_diSons TABLE( 
		[diGuid]				[UNIQUEIDENTIFIER],
		[diAccount]				[UNIQUEIDENTIFIER], 
		[diDiscount]			[FLOAT], 
		[diExtra]				[FLOAT], 
		[diCostGUID]			[UNIQUEIDENTIFIER], 
		[diContraAccGUID]		[UNIQUEIDENTIFIER], 
		[diCurrencyVAL]			[FLOAT], 
		[diCurrencyPtr]			[UNIQUEIDENTIFIER], 
		[diNotes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[diNumber]				[INT], 
		[diClassPtr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI) 
	
	-- en buffer table: 
	DECLARE @t_en TABLE( 
		[recType]			[INT], 
		[RecBiNumber]		[INT], 
		[Date]				[DATETIME], 
		[Debit]				[FLOAT], 
		[Credit]			[FLOAT], 
		[Notes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[CurrencyVal]		[FLOAT], 
		[Class]				[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
		[Vendor]			[INT], 
		[SalesMan]			[INT], 
		[ParentGUID]		[UNIQUEIDENTIFIER], 
		[accountGUID]		[UNIQUEIDENTIFIER], 
		[CurrencyGUID]		[UNIQUEIDENTIFIER], 
		[CostGUID]			[UNIQUEIDENTIFIER], 
		[contraAccGUID]		[UNIQUEIDENTIFIER],
		[BiGuid]			[UNIQUEIDENTIFIER],
		[Type]				[INT] DEFAULT 0,
		[DiGuid]			[UNIQUEIDENTIFIER])
	DECLARE @t_en2 TABLE( 
		[recID]				[INT] IDENTITY(1,1), 
		[DC]				[FLOAT], 
		[date]				[DATETIME], 
		[notes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[currencyVal]		[FLOAT], 
		[class]				[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
		[vendor]			[INT], 
		[salesMan]			[INT], 
		[parentGUID]		[UNIQUEIDENTIFIER], 
		[accountGUID]		[UNIQUEIDENTIFIER], 
		[currencyGUID]		[UNIQUEIDENTIFIER], 
		[costGUID]			[UNIQUEIDENTIFIER], 
		[contraAccGUID]		[UNIQUEIDENTIFIER],
		[BiGuid]			[UNIQUEIDENTIFIER],
		[Type]				[INT] DEFAULT 0,
		CustomerGUID		[UNIQUEIDENTIFIER],
		[DiGuid]			[UNIQUEIDENTIFIER]) 

	-- Bonus buffer table 
	DECLARE @t_bonusBuf TABLE( 
		[mtGUID]	[UNIQUEIDENTIFIER], 
		[Price]		[FLOAT],   
		[unity] 	[int])   
	DECLARE @t_bonus TABLE( 
		[mtGUID]	[UNIQUEIDENTIFIER], 
		[Price]		[FLOAT],   
		[unity] 	[int])   

	DECLARE @MainCurrencyGUID [UNIQUEIDENTIFIER]
	SET @MainCurrencyGUID = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number)

	-- bu variables: 
	DECLARE 
		@buTypeGUID				[UNIQUEIDENTIFIER], 
		@buNumber				[INT], 
		@buIsPosted				[INT], 
		@buSecurity				[INT], 
		@buPayType				[INT], 
		@buCustAccGUID			[UNIQUEIDENTIFIER], 
		@buCustomerGUID			[UNIQUEIDENTIFIER], 
		@buCurrencyVAL			[FLOAT], 
		@buCurrencyGUID			[UNIQUEIDENTIFIER], 
		@buDate					[DATETIME], 
		@buFirstPay				[FLOAT], 
		@buFPayAccGUID			[UNIQUEIDENTIFIER], 
		@buItemsDisc			[FLOAT], 
		@buBonusDisc			[FLOAT],
		@buItemsExtra			[FLOAT],
		@buMatAccGUID			[UNIQUEIDENTIFIER], 
		@buVATAccGUID			[UNIQUEIDENTIFIER], 
		@buBonusAccGUID			[UNIQUEIDENTIFIER], 
		@buCostGUID				[UNIQUEIDENTIFIER], 
		@buNotes				[NVARCHAR](1000), 
		@buSalesManPtr			[INT], 
		@buVendor				[INT], 
		@buTotal				[FLOAT], 
		@buTotalDisc			[FLOAT], 
		@buTotalExtra			[FLOAT], 
		@buCustAccTotal			[FLOAT], 
		@buBranchGUID			[UNIQUEIDENTIFIER], 
		@buUserGUID				[UNIQUEIDENTIFIER], 
		@entryGUID				[UNIQUEIDENTIFIER], 
		@ContraDiscAccGUID		[UNIQUEIDENTIFIER],		-- For Contract Offer  
		@buCustomerName			[NVARCHAR](256),
		@buTotalPrice			[FLOAT],
		@BillCustAccGUID        [UNIQUEIDENTIFIER],
		@buVat					[FLOAT],
		@buIsTaxPayedByAgent	[BIT],
		@buReversChargeReturn   [UNIQUEIDENTIFIER],
		@buUseCustomsRate		[BIT],
		@buLocationGUID			[UNIQUEIDENTIFIER]
	-- bt variables: 
	DECLARE 
		@btName					[NVARCHAR](128), 
		@btDirection			[INT], 
		@btDefBillAccGUID		[UNIQUEIDENTIFIER], 
		@btDefCashAccGUID		[UNIQUEIDENTIFIER], 
		@btDefStoreAccGUID		[UNIQUEIDENTIFIER], 
		@btDefCostPrice			[FLOAT], 
		@btDefBonusPrice		[FLOAT], 
		@btAutoEntryPost		[BIT], 
		@btAutoGenContraAcc		[BIT], 
		@btContInv				[BIT], 
		@btConsideredGiftsOfSales [BIT], --ConsideredGiftsOfSales
		@btCostToItems			[BIT],
		@btCostToTaxAcc			[BIT],
		@btCostToCust			[BIT], 
		@btFldCostPtr			[BIT], 
		@btShortEntry			[BIT], 
		@btCollectCustAccount	[BIT], 
		@btAffectProfit			[BIT], 
		@btVatSystem			[INT],
		@btGenContraAcc			[BIT],
	    @permession				[INT],
	    @oldIsPosted			[BIT],	
	    @oldPostDate			[DATETIME],
		@btCostToDiscount		[BIT], 
		@btContraCostToDiscount	[BIT],
		@UseExcise				[BIT],
		@UseReversCharge		[BIT],
		@ExciseAccGUID			[UNIQUEIDENTIFIER],
		@ExciseContraAccGUID	[UNIQUEIDENTIFIER],
		@ReverseChargesAccGUID	[UNIQUEIDENTIFIER],
		@ReverseChargesContraAccGUID [UNIQUEIDENTIFIER],
		@DefaultLocationGUID [UNIQUEIDENTIFIER],
		@btBillType [INT],
		@btCentringCustomerAccount [BIT];

	DECLARE
		@LocationGUID [UNIQUEIDENTIFIER],
		@VATAccGUID [UNIQUEIDENTIFIER],
		@ReturnVATAccGUID [UNIQUEIDENTIFIER],
		@LocationClassifiction [INT];
	-- bi variables: 
	DECLARE 
		@maDiscAccGUID			[UNIQUEIDENTIFIER], 
		@maExtraAccGUID			[UNIQUEIDENTIFIER], 
		@maMatAccGUID			[UNIQUEIDENTIFIER] 
	-- tax
		DECLARE @t_tax TABLE( 
		[taxGuid]				[UNIQUEIDENTIFIER], 
		[taxAccount]			[UNIQUEIDENTIFIER], 
		[taxValue]				[FLOAT], 
		[taxCurrencyPtr]			[UNIQUEIDENTIFIER],
		[taxCurrencyVAL]		[FLOAT], 
		[taxNotes]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[taxNumber]				[INT],
		taxType					BIT,
		maCashAccGUID           [UNIQUEIDENTIFIER])
	-------------------------------------------- fill variables: 
	-- bu variables filling: 
	SELECT 
		@buTypeGUID				= [TypeGUID], 
		@buNumber				= [vtBu].[Number], 
		@buIsPosted				= [IsPosted], 
		@buSecurity				= [vtBu].[Security], 
		@buPayType			    = [PayType], 
		@buCustAccGUID			= [CustAccGUID], 
		@buCurrencyVAL			= [CurrencyVAL], 
		@buCurrencyGUID			= [CurrencyGUID], 
		@buDate					= [Date], 
		@buFirstPay				= [FirstPay], 
		@buFPayAccGUID			= [FPayAccGUID], 
		@buCostGUID				= [vtBu].[CostGUID], 
		@buMatAccGUID			= [MatAccGUID], 
		@buVATAccGUID			= [VATAccGUID],
		@buNotes				= [vtBu].[Notes], 
		@buSalesManPtr			= [SalesManPtr], 
		@buVendor				= [Vendor], 
		@buTotal				= [Total], 
		@buTotalDisc			= [TotalDisc], 
		@buTotalExtra			= [TotalExtra], 
		@buItemsDisc			= [ItemsDisc],
		@buBonusDisc			= [BonusDisc],
		@buItemsExtra			= [ItemsExtra],
		@buCustAccTotal			= [Total], 
		@buBranchGUID			= [Branch], 
		@buUserGUID				= [userGUID],
		@buCustomerGUID			= [CustGUID],
		@buCustomerName			= (CASE WHEN [vtBu].CustGUID <> 0X0 THEN(CASE WHEN @language <> 0 AND [vtCu].[LatinName] <> '' THEN [vtCu].[LatinName] ELSE [vtCu].[CustomerName] END) ELSE Cust_Name END),
		@total					= [Total],
		@totalDisc				= [TotalDisc],
		@totalExtra				= [TotalExtra],
		@buVat					= [VAT],
		@buIsTaxPayedByAgent    = IsTaxPayedByAgent,
		@buReversChargeReturn   = ReversChargeReturn,
		@buUseCustomsRate		= ImportViaCustoms,
		@buLocationGUID			= ISNULL([vtBu].GCCLocationGUID, 0x0)
	FROM [vtBu]
		LEFT JOIN [vtCu] ON [vtBu].[CustGUID] = [vtCu].[GUID]
	WHERE [vtBu].[GUID] = @billGUID  
	-- check: 
	IF @buNumber IS NULL 
	BEGIN 
		RAISERROR('AmnE0250: Bill specified was not found ...', 16, 1) 
		RETURN 
	END 
	-- bt variabls filling: 
	SELECT 
		@btName					= (CASE WHEN @language <> 0 AND [btLatinName] <> '' THEN [btLatinName] ELSE [btName] END), 
		@btDirection			= [btDirection], 
		@btDefBillAccGUID		= [btDefBillAcc], 
		@btDefCashAccGUID		= [dbo].fnGetDAcc([btDefCashAcc]),
		@btDefCostPrice				= [btDefCostPrice], 
		@btDefBonusPrice			= [btDefBonusPrice], 
		@btAutoEntryPost			= [btAutoEntryPost], 
		@btAutoGenContraAcc			= [btAutoGenContraAcc], 
		@btContInv					= [btContInv], 
		@btConsideredGiftsOfSales	= [btConsideredGiftsOfSales],
		@btCostToItems				= [btCostToItems], 
		@btCostToCust				= [btCostToCust], 
		@btCostToTaxAcc				= [btCostToTaxAcc],
		@btCostToDiscount			= [btCostToDiscount],
		@btContraCostToDiscount     = [btContraCostToDiscount], 
		@btFldCostPtr				= [btFldCostPtr], 
		@btShortEntry				= [btShortEntry], 
		@btCollectCustAccount		= ISNULL([btCollectCustAccount], 0), 
		@btAffectProfit				= btAffectProfit,
		@btVatSystem				= [btVATSystem], 
		@btGenContraAcc				= [btAutoGenContraAcc],
		@TaxBeforeDiscount		    = [TaxBeforeDiscount],
		@TaxBeforeExtra			    = [taxBeforeExtra],
		@IncludeTTCDiffOnSales		= [IncludeTTCDiffOnSales],
		@UseSalesTax				= [UseSalesTax],
		@Permession					= dbo.fnGetUserBillSec_Post([dbo].[fnGetCurrentUserGUID](),btGUID),   -- Can I use @buUserGUID instead of function
		@UseExcise					= bt.UseExciseTax,
		@UseReversCharge			= bt.UseReverseCharges,
		@ExciseAccGUID				= bt.ExciseAccGUID,
		@ExciseContraAccGUID		= bt.ExciseContraAccGUID,
		@ReverseChargesAccGUID		= bt.ReverseChargesAccGUID,
		@ReverseChargesContraAccGUID= bt.ReverseChargesContraAccGUID,
		@DefaultLocationGUID = bt.DefaultLocationGUID,
		@btBillType = bt.BillType,
		@btCentringCustomerAccount = bt.bCentringCustomerAccount
	FROM 
		[vwBt] AS [vwbt] INNER JOIN bt000 AS [bt] ON [vwbt].[btGuid] = [bt].[Guid]
	WHERE 
		[btGUID] = @buTypeGUID 
		
	IF @IsGCCSystemEnabled = 1
	BEGIN
		SET @btShortEntry = 0;

		SELECT @LocationGUID = GCCLocationGUID FROM cu000 WHERE GUID = @buCustomerGUID;
		SELECT
			@VATAccGUID = VATAccGUID,
			@ReturnVATAccGUID = ReturnAccGUID,
			@LocationClassifiction = Classification
		FROM GCCCustLocations000
		WHERE GUID = @LocationGUID;

		-- «–« ﬂ«‰  «·›« Ê—… „»Ì⁄ √Ê „ —Ã⁄ „»Ì⁄ Êﬂ«‰ „Êﬁ⁄ «·“»Ê‰ «·„Õœœ ÷„‰ «·›« Ê—… ÂÊ „Õ·Ì
		-- Ì „ √Œ– «·Õ”«»«  «·Œ«’… »÷—Ì»…«·›«  „‰ «·„Êﬁ⁄ «·„Õœœ ÷„‰ ‰„ÿ «·›« Ê—…
		IF @LocationClassifiction = 0 AND (@btBillType = 1 OR @btBillType = 3) 
		BEGIN
			SELECT
				@VATAccGUID = VATAccGUID,
				@ReturnVATAccGUID = ReturnAccGUID
			FROM GCCCustLocations000
			WHERE GUID = 
				CASE @buLocationGUID
					WHEN 0x0 THEN @LocationGUID
					ELSE @buLocationGUID
				END
		END

		IF @buIsTaxPayedByAgent = 1
		BEGIN
			SET @VATAccGUID = @buVATAccGUID
		END
		
		IF (@btBillType = 0 OR @btBillType = 2)
		BEGIN
			IF (@UseReversCharge = 1 AND @buReversChargeReturn <> 0x)
			BEGIN
				SET @ReverseChargesContraAccGUID = @buReversChargeReturn;
			END
		END
		ELSE
		BEGIN
			SET @buUseCustomsRate = 0;
		END

		SELECT @txt_Excise = 
			CASE @btBillType 
				WHEN 0 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_EXCISE_PURCHASE', @language)
				WHEN 1 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_EXCISE_SELL', @language)
				WHEN 2 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_EXCISE_RE_PURCHASE', @language)
				WHEN 3 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_EXCISE_RE_SELL', @language)
				ELSE N''
			END;

		SELECT @txt_ReversCharge = 
			CASE @btBillType 
				WHEN 0 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_REVERSCHARGE_PURCHASE', @language)
				WHEN 1 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_REVERSCHARGE_SELL', @language)
				WHEN 2 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_REVERSCHARGE_RE_PURCHASE', @language)
				WHEN 3 THEN [dbo].[fnStrings_get]('BILLENTRY\ITEMS_REVERSCHARGE_RE_SELL', @language)
				ELSE N''
			END;
	END

	-- fix @buCustAccGuid 
	-----------------------------
	IF ISNULL(@buNotes,'') = '' AND (@btShortEntry = 1 OR @btCollectCustAccount = 1)
	BEGIN
		SET @buNotes = @Bill_Name + ': ' + @btName + ' - ' + @Bill_Num +  ': ' + cast(@buNumber as NVARCHAR(50)) + CASE @buCustomerName WHEN '' THEN '' ELSE ' - ' + @Bill_For_Customer + ': ' + @buCustomerName END
	END
	-----------------------------	
	SET @buCustAccGUID = CASE ISNULL(@buCustAccGUID, 0x0) WHEN 0x0 THEN @btDefCashAccGUID ELSE @buCustAccGUID END 
	SELECT @ContraDiscAccGUID = ISNULL(ContraDiscAccGuid, 0x0) FROM cu000 WHERE Guid = @buCustomerGUID
	--------------------------------------------------------------------
	-- fetch new entry guid and number: 
	SET @entryGUID = NEWID() 

	IF (@maintenanceMode = 1)
	BEGIN
		SELECT 
			@oldIsPosted = ce.IsPosted,			
			@oldPostDate = ce.PostDate
		FROM 	
			[Er000] AS er
			INNER JOIN [Ce000] AS ce ON ce.[Guid] = er.EntryGuid
			INNER JOIN [Bu000] AS bu ON bu.[Guid] = er.ParentGuid
		WHERE bu.[Guid] = @billGUID
		
		SELECT @oldIsPosted = ISNULL(@oldIsPosted, 0)
	END
	--IF (@CenteringCusAcc = 1 AND @buFirstPay = 0 AND @buCustomerGuid <> 0x0 AND @buPayType = 0)
	--BEGIN 
	--	SET @buFirstPay = @total
	--	UPDATE @tempbp SET PayType = 1
	--	SET @BillCustAccGUID = @buCustAccGUID   --Õ”«» «·⁄„Ì· „‰ «·›« Ê—…
	--	SET @buCustAccGUID  = (SELECT AccountGUID FROM cu000 WHERE [GUID] = @buCustomerGUID)  --Õ”«» «·⁄„Ì· „‰ »ÿ«ﬁ… «·⁄„Ì·      
	--END 
	-- delete old entry: 
	EXEC prcBill_DeleteEntry @billGUID 
	
	----------------------------------------- buffers tables filling 
			
	INSERT INTO #t_bi EXEC prcBill_GetBiFields @btConsideredGiftsOfSales, @buMatAccGUID, @btDefBillAccGUID, 
				@buVATAccGUID, @buCustAccGUID, @btBillType, @IsGCCSystemEnabled, @billGUID, @buCustomerGUID	
	
    SELECT @buTotalPrice =  ISNULL(SUM(biPrice), 0) FROM #t_bi 
	
	-- this is tricky: if there is only one maDiscAccGuid in #t_bi, take it, or else take nothing: 
	IF (SELECT COUNT(*) FROM (SELECT DISTINCT [maDiscAccGUID] FROM #t_bi) x) = 1 
		SET @maDiscAccGUID = (SELECT TOP 1 [maDiscAccGUID] FROM #t_bi) 
	ELSE 
		SET @maDiscAccGUID = 0x0 
	IF (SELECT COUNT(*) FROM (SELECT DISTINCT [maMatAccGUID] FROM #t_bi) x) = 1 
		SET @maMatAccGUID = (SELECT TOP 1 [maMatAccGUID] FROM #t_bi) 
	ELSE 
		SET @maMatAccGUID = 0x0 
	IF (SELECT COUNT(*) FROM (SELECT DISTINCT [maExtraAccGUID] FROM #t_bi) x) = 1
	BEGIN
		SET @maExtraAccGUID = (SELECT TOP 1 [maExtraAccGUID] FROM #t_bi)
	END
	ELSE
	BEGIN
		SET @maExtraAccGUID = 0x0
	END
	 -- tax  buffer table filling:
	IF  @UseSalesTax = 1
	BEGIN
	 INSERT INTO @t_tax 
		SELECT TAX.[Guid],TAX.AccountGuid [taxAccount],
		CASE TAX.ValueType WHEN 0 THEN CASE vbu.Total WHEN 0 THEN 0 ELSE tax.Value * bi.biPrice * (bi.biBillQty - CASE WHEN @btConsideredGiftsOfSales= 1 THEN [bi].[biBillBonusQnt] ELSE 0 END) / vbu.Total END ELSE
		(bi.biPrice * (bi.biBillQty  - CASE WHEN @btConsideredGiftsOfSales= 1 THEN [bi].[biBillBonusQnt] ELSE 0 END)
		- CASE @TaxBeforeDiscount WHEN 0 THEN bi.biDiscount + bi.biTotalDiscountPercent ELSE 0 END
		+ CASE @TaxBeforeExtra WHEN 0 THEN bi.biExtra + bi.biTotalExtraPercent ELSE 0  END) * TAX.Value / 100 END,
		VBU.[CurrencyGUID] [taxCurrencyPtr],
		VBU.[CurrencyVAL] [taxCurrencyVAL],
		CASE WHEN @btShortEntry = 1 THEN '' ELSE TAX.[NAME] + ' - ' +  bi.mtName END [taxNotes],
		TAX.[NUMBER] [taxNumber],
		TaxType,
		bi.maCashAccGUID
		FROM salestax000 TAX
		INNER JOIN vtBu VBU
		CROSS JOIN #t_bi bi
		ON TAX.[BillTypeGuid] = VBU.[TypeGUID] AND VBU.[GUID] = @billGUID
		WHERE [BillTypeGuid]= @buTypeGUID
			    END
	-- di buffer table filling: 
	INSERT INTO @t_di 
		SELECT [diAccount], [diDiscount], [diExtra], [diCostGUID], [diContraAccGUID], [diCurrencyVAL], [diCurrencyPtr],CASE [diNotes] WHEN '' THEN CASE @btShortEntry	WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE '' END ELSE [diNotes]  END, [diNumber], [diClassPtr] 
		FROM [vwDi] 
		WHERE [diParent]= @billGUID AND ([diDiscount] + [diExtra]) > 0 
	
	-- fill discount grid distributive accounts sons	with new ratios
	INSERT INTO @t_diSons SELECT * FROM fnGetBillDiscounts(@BillGuid)	
	
	-- @t_bonus tables filling: 
	IF (@btDefBonusPrice > 1 ) OR (@btConsideredGiftsOfSales<> 0)
	BEGIN 
		IF @btDefBonusPrice = 2048 
			INSERT INTO @t_bonusBuf 
				SELECT [biMatPtr], 
						CASE ISNULL((SELECT [DefPrice] FROM [cu000] WHERE [GUID] = [buCustPtr]), 0) 
							WHEN 0 THEN CASE [biUnity] WHEN 1 THEN [mtWhole]	WHEN 2 THEN [mtWhole2]		ELSE [mtWhole3]		END 
							WHEN 1 THEN CASE [biUnity] WHEN 1 THEN [mtHalf]		WHEN 2 THEN [mtHalf2]		ELSE [mtHalf3]		END 
							WHEN 2 THEN CASE [biUnity] WHEN 1 THEN [mtExport]	WHEN 2 THEN [mtExport2]		ELSE [mtExport3]		END 
							WHEN 3 THEN CASE [biUnity] WHEN 1 THEN [mtVendor]	WHEN 2 THEN [mtVendor2]		ELSE [mtVendor3]		END 
							WHEN 4 THEN CASE [biUnity] WHEN 1 THEN [mtRetail]	WHEN 2 THEN [mtRetail2]		ELSE [mtRetail3]		END 
							WHEN 5 THEN CASE [biUnity] WHEN 1 THEN [mtEndUser]	WHEN 2 THEN [mtEndUser2]	ELSE [mtEndUser3]	END 
							ELSE 0 
						END,   
					[biUnity]   
				FROM [vwExtended_bi] 
				WHERE [buGUID] = @billGUID 
		ELSE 
			INSERT INTO @t_bonusBuf 


				SELECT [biMatPtr], 
						CASE @btDefBonusPrice   
							WHEN 2		THEN CASE [biBillQty] + [biBillBonusQnt] 		WHEN 0 THEN 0 ELSE (([biPrice] * [biBillQty]) - [biProfits] - ([biQty] * [biUnitDiscount]* [btDiscAffectProfit]) + ([biQty] * [biUnitExtra] * [btExtraAffectProfit])) / ([biBillQty] + [biBillBonusQnt]) END 
							WHEN 4		THEN CASE [biUnity] WHEN 1 THEN [mtWhole]		WHEN 2 THEN [mtWhole2]		ELSE [mtWhole3]		END 
							WHEN 8		THEN CASE [biUnity] WHEN 1 THEN [mtHalf]		WHEN 2 THEN [mtHalf2]		ELSE [mtHalf3]		END 
							WHEN 16		THEN CASE [biUnity] WHEN 1 THEN [mtExport]		WHEN 2 THEN [mtExport2]		ELSE [mtExport3]	END 
							WHEN 32		THEN CASE [biUnity] WHEN 1 THEN [mtVendor]		WHEN 2 THEN [mtVendor2]		ELSE [mtVendor3]	END 
							WHEN 64		THEN CASE [biUnity] WHEN 1 THEN [mtRetail]		WHEN 2 THEN [mtRetail2]		ELSE [mtRetail3]	END 
							WHEN 128	THEN CASE [biUnity] WHEN 1 THEN [mtEndUser]		WHEN 2 THEN [mtEndUser2] 	ELSE [mtEndUser3] 	END  
							WHEN 256	THEN [biUnitPrice] * mtUnitFact
							WHEN 512	THEN CASE [biUnity] WHEN 1 THEN [mtLastPrice]	WHEN 2 THEN [mtLastPrice2] 	ELSE [mtLastPrice3]	END 
							WHEN 16384	THEN CASE [biUnity] WHEN 1 THEN [biUnitPrice] * [mtUnitFact] WHEN 2 THEN [biUnitPrice] * [mtUnit2Fact] WHEN 3 THEN [biUnitPrice] * [mtUnit3Fact] END
							ELSE 0 
						END,   
					[biUnity]   
				FROM [vwExtended_bi] 
				WHERE [buGUID] = @billGUID 
		-- fill @t_bonus from its buffer: 
		INSERT INTO @t_bonus 
			SELECT [mtGuid], avg(CASE @btVatSystem WHEN 2 THEN buf.[price] / (1 + (mt.VAT / 100)) ELSE buf.[price] END), buf.[unity] 
			FROM @t_bonusBuf buf INNER JOIN mt000 mt ON mt.[GUID] = buf.mtGUID
			GROUP BY [mtGuid], buf.[unity] 
	 
	-- select @btDefBonusPrice,* from @t_bonus order by price 
	END 
	-- en buffer table filling: 
	-- 1.1: insert Materials Accounts data:
	-- 1.1.a: fill Materials Accounts Data where exist in Users management card, Materials card, and Groups cards. 
		INSERT INTO @t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
		SELECT DISTINCT
			@recType_matAcc, 
			[biNumber], 
			@buDate, 
			CASE @btDirection	WHEN 1 THEN [biPrice] * [biBillQty] ELSE 0 END, 
			CASE @btDirection	WHEN 1 THEN 0 ELSE [biPrice] * [biBillQty] END, 
			CASE @btShortEntry	WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE (CASE [biNotes] WHEN '' THEN [mtName] ELSE [mtName] + '-' + [biNotes] END) END, 
			[biCurrencyVAL], 
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			[bi].[maMatAccGUID], 
			[biCurrencyPtr], 
			CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
			bi.maCashAccGUID,
			CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END
		FROM #t_bi bi
		WHERE 
			[biPrice] * [biBillQty] > 0 
			AND (
				EXISTS( SELECT TOP 1 [maObjGUID] FROM [vwMa] AS [ma_mat] WHERE @buTypeGUID = [ma_mat].[maBillTypeGUID] AND (bi.[biMatPtr] = [ma_mat].[maObjGUID] OR bi.[biMatGroupPtr] = [ma_mat].[maObjGUID] OR ([maType] = 3 AND [maObjGUID] = @buUserGUID)))
				OR (EXISTS( SELECT TOP 1 [BillItemGuid] FROM [ContractBillItems000] [cbi] WHERE [cbi].[BillItemGuid] = [bi].[biGuid]))
				OR (EXISTS( SELECT TOP 1 [so].[SODetailGuid] FROM [vwSOAccounts] AS [so] WHERE [so].[SODetailGuid] = [bi].[biSOGuid])) 
				OR (EXISTS( SELECT TOP 1 [POSso].[Guid] FROM [vwSpecialOffer] AS [POSso] WHERE [POSso].[Guid] = [bi].[biSOGuid]))
				OR (EXISTS( SELECT TOP 1 [Asset].[AccGUID] FROM [as000] AS [Asset] WHERE [Asset].[ParentGUID] = [bi].[biMatPtr]))
				)
	-- 1.1.b: fill material accounts in new ratios for distributive accounts. 
	DECLARE @MatAccFldStr NVARCHAR(250)	
	SET @MatAccFldStr = CASE @BuMatAccGUID WHEN 0x0 THEN 'DefBillAccGUID' ELSE 'MatAccGUID' END
	
	INSERT INTO @t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
		SELECT 
			@recType_matAcc, 
			[biNumber], 
			@buDate, 
			CASE @btDirection	WHEN 1 THEN [biPrice] * [biBillQty] - (CASE WHEN bi.IsProfitMargin = 1 THEN biVAT ELSE 0 END) ELSE 0 END * MatAccSons.[Ratio] / 100, 
			CASE @btDirection	WHEN 1 THEN 0 ELSE [biPrice] * [biBillQty] - (CASE WHEN bi.IsProfitMargin = 1 THEN biVAT ELSE 0 END) END * MatAccSons.[Ratio] / 100, 
			CASE @btShortEntry	WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE (CASE [biNotes] WHEN '' THEN [mtName] ELSE [mtName] + '-' + [biNotes] END) END, 
			[biCurrencyVAL], 
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			MatAccSons.[SonGuid], 
			[biCurrencyPtr], 
			CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
			bi.maCashAccGUID,
			CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END
		FROM 
			#t_bi  bi 
			INNER JOIN fnGetBillMatAccSons(CASE @BuMatAccGUID WHEN 0x0 THEN @buTypeGUID ELSE @BillGuid END, CASE @BuMatAccGUID WHEN 0x0 THEN @BtDefBillAccGuid ELSE @BuMatAccGUID END, @MatAccFldStr) AS MatAccSons ON bi.[maMatAccGUID] = MatAccSons.ParentGuid	
		WHERE 
			[biPrice] * [biBillQty] > 0 
			AND NOT (
				EXISTS( SELECT TOP 1 [maObjGUID] FROM [vwMa] AS [ma_mat] WHERE @buTypeGUID = [ma_mat].[maBillTypeGUID] AND (bi.[biMatPtr] = [ma_mat].[maObjGUID] OR bi.[biMatGroupPtr] = [ma_mat].[maObjGUID] OR ([maType] = 3 AND [maObjGUID] = @buUserGUID)))
				OR (EXISTS( SELECT TOP 1 [BillItemGuid] FROM [ContractBillItems000] [cbi] WHERE [cbi].[BillItemGuid] = [bi].[biGuid]))
				OR (EXISTS( SELECT TOP 1 [so].[SODetailGuid] FROM [vwSOAccounts] AS [so] WHERE [so].[SODetailGuid] = [bi].[biSOGuid])) 
				OR (EXISTS( SELECT TOP 1 [POSso].[Guid] FROM [vwSpecialOffer] AS [POSso] WHERE [POSso].[Guid] = [bi].[biSOGuid])) 
				OR (EXISTS( SELECT TOP 1 [Asset].[AccGUID] FROM [as000] AS [Asset] WHERE [Asset].[ParentGUID] = [bi].[biMatPtr]))
				)
	-- 1.2: insert FirstPay data for Material Account, if any: 
	IF @buFirstPay > 0 
	 -- if (@buPayType = 0 AND @CenteringCusAcc = 1)
	 --   BEGIN
		DECLARE @m_Notes nvarchar(MAX) 
		--  SET @m_Notes = ''
		--END
		--ELSE
		--BEGIN
		SET @m_Notes =(CASE @buFirstPay WHEN @buTotal THEN @txt_firstPay_fullPay ELSE @txt_firstPay END) + ' ' + @btName + ' ' + CAST(@buNumber AS [NVARCHAR](50)) 
		--END

		INSERT INTO @t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID]) 
			SELECT 
				@recType_fPayOfMatAcc, 
				0, 
				@buDate, 
				CASE @btDirection WHEN 1 THEN @buFirstPay ELSE 0 END, 
				CASE @btDirection WHEN 1 THEN 0 ELSE @buFirstPay END, 
				@m_Notes, --(CASE @buFirstPay WHEN @buTotal THEN @txt_firstPay_fullPay ELSE @txt_firstPay END) + ' ' + @btName + ' ' + CAST(@buNumber AS [NVARCHAR](50)), 
				@buCurrencyVAL, 
				0,
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				@buCustAccGUID, 
				@buCurrencyGUID, 
				CASE @btCostToCust WHEN 1 THEN @buCostGUID ELSE 0x0 END, 
				@buFPayAccGUID

	-- 1.3: insert Items Discount data for Material Account, if any: 
	IF @buItemsDisc + @buBonusDisc > 0
		INSERT INTO @t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
			SELECT 
				@recType_ItemsDisc, 
				[biNumber], 
				@buDate, 
				CASE @btDirection WHEN 1 THEN 0 ELSE [biDiscount] - [biContractDiscount] + [biBonusDisc] END, 
				CASE @btDirection WHEN 1 THEN [biDiscount] - [biContractDiscount] + [biBonusDisc] ELSE 0 END, 
				CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE @txt_itemsDisc + ' - ' + [mtName] END, 
				@buCurrencyVAL, 
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				[maDiscAccGUID], 
				@buCurrencyGUID, 
				CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
				maCashAccGUID,
				CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END
			FROM #t_bi 
			WHERE 
				([biDiscount] - [biContractDiscount] + [biBonusDisc] <> 0) AND ([biPrice] * [biBillQty] > 0)
	-- Contract Discounts			
	-- 1.3.0: insert Items Contract Discount data for Material Account, if any: 
	IF @buItemsDisc + @buBonusDisc > 0
		INSERT INTO @t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
			SELECT 
				@recType_ItemsDisc, 
				[biNumber], 
				@buDate, 
				CASE @btDirection WHEN 1 THEN 0 ELSE [biContractDiscount] END, 
				CASE @btDirection WHEN 1 THEN [biContractDiscount] ELSE 0 END, 
				CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE @txt_itemsDisc + ' - ' + [mtName] END, 
				@buCurrencyVAL, 
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				[maContractDiscAccGUID],
				@buCurrencyGUID, 
				CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
				maCashAccGUID,
				CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END
			FROM #t_bi 
			WHERE 
				([biContractDiscount] <> 0 AND [maContractDiscAccGUID] <> 0x00) AND ([biPrice] * [biBillQty] > 0)
	-- 1.3.1: insert Items Extra data for Material Account, if any: 
	IF @buItemsExtra > 0
		INSERT INTO @t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
			SELECT 
				@recType_ItemsDisc, 
				[biNumber], 
				@buDate, 
				CASE @btDirection WHEN 1 THEN [biExtra] ELSE 0 END, 
				CASE @btDirection WHEN 1 THEN 0 ELSE [biExtra] END, 
				-- @txt_itemsDisc + CASE @btShortEntry WHEN 0 THEN ' - ' + mtName ELSE '' END, 
				--CASE @btShortEntry WHEN 1 THEN '' ELSE @txt_itemsDisc + ' - ' + mtName END, 
				CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE @txt_itemsExtra + ' - ' + [mtName] END, 
				@buCurrencyVAL, 
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				[maExtraAccGUID], 
				@buCurrencyGUID, 
				CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
				maCashAccGUID,
				CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END
			FROM #t_bi 
			WHERE 
				[biExtra] <> 0 AND 
				[biPrice] * [biBillQty] > 0
 
	-- 1.4: insert Items VAT data for Material Account (or bill), if any: 
	IF @btVatSystem = 1 OR @btVatSystem = 2 OR @IsGCCSystemEnabled = 1
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type]) 
        SELECT 
				@recType_ItemsVAT, 
				[biNumber], 
				@buDate, 
				CASE @btDirection WHEN 1 THEN [biVAT] ELSE 0 END, 
				CASE @btDirection WHEN 1 THEN 0 ELSE [biVAT] END, 
				CASE @btShortEntry
					WHEN 1 THEN @buNotes
					ELSE @txt_vat + ' "' + [mtName] + '" ' + @Bill_Name + ' " ' + [biBillname] + '" ' + @Bill_Num + ' ' + CAST([biBillNumber] AS NVARCHAR(50)) 
				END, 
				(CASE @IsGCCSystemEnabled WHEN 1 THEN 1 ELSE @buCurrencyVAL END),
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				CASE @IsGCCSystemEnabled 
					WHEN 1 THEN 
						CASE @buIsTaxPayedByAgent 
							WHEN 0 THEN 
								CASE WHEN @btBillType IN (1, 3) THEN @VATAccGUID ELSE @ReturnVATAccGUID END
							ELSE @VATAccGUID
						END
					ELSE [maVATAccGUID] 
				END, 
				(CASE @IsGCCSystemEnabled WHEN 1 THEN @MainCurrencyGUID ELSE @buCurrencyGUID END),
				CASE @btCostToTaxAcc WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
				maCashAccGUID,
				CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END,
				CASE @IsGCCSystemEnabled 
					WHEN 1 THEN CASE WHEN @btBillType IN (1, 3) THEN 201 ELSE 202 END
					ELSE 0 
				END
			FROM #t_bi 
			WHERE 
				[biVAT] > 0
				
--„⁄«·Ã… ÷—Ì»… «·ﬁÌ„… «·„÷«›… ··Âœ«Ì« 
--«·Õ”«»
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID])  
			SELECT  
				@recType_ItemsVAT,  
				[biNumber],  
				@buDate,  
				CASE @btDirection WHEN 1 THEN CASE @btConsideredGiftsOfSales WHEN 1 THEN bi.biPrice ELSE [bn].[Price] END * [bi].[biBillBonusQnt] * mt.VAT / 100 ELSE 0 END,  
				CASE @btDirection WHEN 1 THEN 0 ELSE CASE @btConsideredGiftsOfSales WHEN 1 THEN bi.biPrice ELSE [bn].[Price] END * [bi].[biBillBonusQnt] * mt.VAT / 100 END,  
				CASE @btShortEntry WHEN 1 THEN @buNotes ELSE CASE [biNotes] WHEN '' THEN @txt_vat+' '+[mtName] + ' (' + @txt_bonus + ')  ' +@Bill_Name+' " '+[biBillname]+' " '+@Bill_Num+' '+cast([biBillNumber] as NVARCHAR(50))ELSE [mtName] + '-' + [biNotes] END END,     
				-- CASE @btShortEntry WHEN 0 THEN @txt_VAT + ' - ' + mtName ELSE '' END,  
				@buCurrencyVAL,  
				[biClassPtr],  
				@buVendor,  
				@buSalesManPtr,  
				@entryGUID,  
				[maVATAccGUID],  
				@buCurrencyGUID,  
				CASE @btCostToTaxAcc WHEN 1 THEN [biCostPtr] ELSE 0x0 END,  
				[maBonusAccGuid]
			FROM #t_bi AS [bi] INNER JOIN @t_bonus AS [bn] ON [bi].[biMatPtr] = [bn].[mtGUID] AND [bn].[unity] = [bi].[biUnity]    
			INNER JOIN mt000 mt
			ON mt.GUID = bi.biMatPtr
			WHERE  
				[biVAT] >= 0 
				AND bi.biIsApplyTaxOnGifts = 1
--«·Õ”«» «·„ﬁ«»·				 	
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID])  
			SELECT  
				@recType_ItemsVAT,  
				[biNumber],  
				@buDate,  
				CASE @btDirection WHEN 1 THEN 0 ELSE CASE @btConsideredGiftsOfSales WHEN 1 THEN bi.biPrice ELSE [bn].[Price] END * [bi].[biBillBonusQnt] * mt.VAT / 100 END,  
				CASE @btDirection WHEN 1 THEN  CASE @btConsideredGiftsOfSales WHEN 1 THEN bi.biPrice ELSE [bn].[Price] END * [bi].[biBillBonusQnt] * mt.VAT / 100 ELSE 0 END,  
				CASE @btShortEntry WHEN 1 THEN @buNotes ELSE CASE [biNotes] WHEN '' THEN @txt_vat+' '+[mtName] + ' (' + @txt_bonus + ')  ' +@Bill_Name+' " '+[biBillname]+' " '+@Bill_Num+' '+cast([biBillNumber] as NVARCHAR(50))ELSE [mtName] + '-' + [biNotes] END END,    
				-- CASE @btShortEntry WHEN 0 THEN @txt_VAT + ' - ' + mtName ELSE '' END,  
				@buCurrencyVAL,  
				[biClassPtr],  
				@buVendor,  
				@buSalesManPtr,  
				@entryGUID,  
				[maBonusAccGuid],  
				@buCurrencyGUID,  
				CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END,  
				[maVATAccGUID] 
			FROM #t_bi AS [bi] INNER JOIN @t_bonus AS [bn] ON [bi].[biMatPtr] = [bn].[mtGUID] AND [bn].[unity] = [bi].[biUnity]    
			INNER JOIN mt000 mt
			ON mt.GUID = bi.biMatPtr
			WHERE  
				[biVAT] >= 0
				AND bi.biIsApplyTaxOnGifts = 1 

	IF @IsGCCSystemEnabled = 1 AND @UseExcise = 1
	BEGIN
		INSERT INTO @t_en([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type])
        SELECT
			@recType_Excise, 
			[biNumber], 
			@buDate, 
			CASE @btDirection WHEN 1 THEN biExcise ELSE 0 END, 
			CASE @btDirection WHEN 1 THEN 0 ELSE biExcise END, 
			@txt_Excise + ' "' + [mtName] + '" ',
			@buCurrencyVAL, 
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			@ExciseAccGUID,
			@buCurrencyGUID, 
			CASE @btCostToTaxAcc WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
			@ExciseContraAccGUID,
			CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END,
			203
		FROM #t_bi 
		WHERE 
			biExcise > 0;

		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type]) 
		SELECT
			@recType_Excise, 
			[biNumber], 
			@buDate, 
			CASE @btDirection WHEN 1 THEN 0 ELSE biExcise END, 
			CASE @btDirection WHEN 1 THEN biExcise ELSE 0 END, 
			@txt_Excise + ' "' + [mtName] + '" ',
			[biCurrencyVAL], 
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			@ExciseContraAccGUID,
			[biCurrencyPtr], 
			CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END,  
			@ExciseAccGUID,
			0x0, 
			204
		FROM #t_bi 
		WHERE 
			biExcise > 0;
	END

	IF @IsGCCSystemEnabled = 1 AND @UseReversCharge = 1
	BEGIN
		DECLARE @reversChargeEntryType INT;
		DECLARE @reversChargeReturnEntryType INT;

		IF @btBillType = 0 OR @btBillType = 2
		BEGIN
			IF @buUseCustomsRate = 1
				SET @reversChargeEntryType = CASE WHEN @btBillType = 0 THEN 207 ELSE 208 END;
			ELSE
				SET @reversChargeEntryType = CASE WHEN @btBillType = 0 THEN 205 ELSE 206 END;
		END
		ELSE
		BEGIN
			SET @reversChargeEntryType = CASE @btDirection WHEN 1 THEN 205 ELSE 206 END;
		END

		IF @btBillType = 0 OR @btBillType = 2
		BEGIN
			IF @buUseCustomsRate = 1
				SET @reversChargeReturnEntryType = CASE WHEN @btBillType = 0 THEN 208 ELSE 207 END;
			ELSE
				SET @reversChargeReturnEntryType = CASE WHEN @btBillType = 0 THEN 206 ELSE 205 END;
		END
		ELSE
		BEGIN
			SET @reversChargeReturnEntryType = CASE @btDirection WHEN 1 THEN 206 ELSE 205 END;
		END

		INSERT INTO @t_en([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type])
        SELECT 
			@recType_ReversCharges, 
			[biNumber], 
			@buDate, 
			biReversCharge,
			0,
			@txt_ReversCharge + ' "' + [mtName] + '" ',
			CASE @buUseCustomsRate WHEN 1 THEN 1 ELSE @buCurrencyVAL END,
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			CASE WHEN @btBillType = 0 OR @btBillType = 2
				THEN CASE WHEN @btBillType = 0 THEN @ReverseChargesAccGUID ELSE @ReverseChargesContraAccGUID END
				ELSE CASE @btDirection WHEN 1 THEN @ReverseChargesAccGUID ELSE @ReverseChargesContraAccGUID END
			END,
			CASE @buUseCustomsRate WHEN 1 THEN @MainCurrencyGUID ELSE @buCurrencyGUID END,
			CASE @btCostToTaxAcc WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
			CASE WHEN @btBillType = 0 OR @btBillType = 2
				THEN CASE WHEN @btBillType = 0 THEN @ReverseChargesContraAccGUID ELSE @ReverseChargesAccGUID END
				ELSE CASE @btDirection WHEN 1 THEN @ReverseChargesContraAccGUID ELSE @ReverseChargesAccGUID END
			END,
			biGuid,
			@reversChargeEntryType
		FROM #t_bi 
		WHERE 
			biReversCharge > 0;

		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type]) 
		SELECT
			@recType_ReversCharges, 
			[biNumber], 
			@buDate, 
			0,
			biReversCharge,
			@txt_ReversCharge + ' "' + [mtName] + '" ',
			CASE @buUseCustomsRate WHEN 1 THEN 1 ELSE @buCurrencyVAL END,
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			CASE WHEN @btBillType = 0 OR @btBillType = 2
				THEN CASE WHEN @btBillType = 0 THEN @ReverseChargesContraAccGUID ELSE @ReverseChargesAccGUID END
				ELSE CASE @btDirection WHEN 1 THEN @ReverseChargesContraAccGUID ELSE @ReverseChargesAccGUID END
			END,
			CASE @buUseCustomsRate WHEN 1 THEN @MainCurrencyGUID ELSE @buCurrencyGUID END, 
			CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END,  
			CASE WHEN @btBillType = 0 OR @btBillType = 2
				THEN CASE WHEN @btBillType = 0 THEN @ReverseChargesAccGUID ELSE @ReverseChargesContraAccGUID END
				ELSE CASE @btDirection WHEN 1 THEN @ReverseChargesAccGUID ELSE @ReverseChargesContraAccGUID  END
			END,
			biGuid, 
			@reversChargeReturnEntryType
		FROM #t_bi 
		WHERE 
			biReversCharge > 0;
	END
	-- 1.5: insert Items ContInv CostAccounts, if any: 	-- 2.9: insert ContInv StockAccount data, if any: 
	IF @btContInv = 1 AND (@buIsPosted != 0 OR @btAffectProfit = 1)
		INSERT INTO @t_en EXEC prcBill_ReGenCostEntrys @entryGuid, @billGuid, @buTypeGUID, @UseOutbalanceAVGPrice, 
				@buDate, @btDirection, @btConsideredGiftsOfSales, @btShortEntry, @txt_bonus, @btCostToItems,
				@buNotes, @buCurrencyVAL, @buVendor, @buSalesManPtr, @buCurrencyGUID, @btCostToCust, 
				@recType_ItemsContInvCost, @recType_ContInvStock

	-- 1.6: insert bonus 
	IF (@btDefBonusPrice > 1) OR (@btConsideredGiftsOfSales<> 0)
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
			SELECT --DISTINCT   
				CASE @btDirection WHEN 1 THEN @recType_Bonus ELSE @recType_BonusContra END, 
				[biNumber], 
				@buDate, 
				CASE @btDirection WHEN 1 THEN 0 ELSE (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] END,
				CASE @btDirection WHEN 1 THEN (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] ELSE 0 END,
				CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE CASE [biNotes] WHEN '' THEN [mtName] + ' (' + @txt_bonus + ')' ELSE [mtName] + '-' + [biNotes] END END, 
				@buCurrencyVal, 
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				[maBonusAccGuid], 
				@buCurrencyGUID, 
				CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
				CASE WHEN (@btConsideredGiftsOfSales<> 0) THEN bi.maCashAccGUID ELSE [maBonusContraAccGuid] END,
				CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END
			FROM #t_bi AS [bi] INNER JOIN @t_bonus AS [bn] ON [bi].[biMatPtr] = [bn].[mtGUID] AND [bn].[unity] = [bi].[biUnity]   
  --tax 1.7
IF  @UseSalesTax = 1
 BEGIN
	INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID]) 
		SELECT 
			CASE @btDirection WHEN 1 THEN @recType_TaxContra ELSE @recType_Tax END, 
			[taxNumber]	, 
			@buDate, 
			CASE @btDirection 
				WHEN 1 THEN CASE taxType WHEN 0 THEN [taxVALUE] ELSE 0 END
				ELSE CASE taxType WHEN  0 THEN 0 ELSE taxValue END
				END, 
			CASE @btDirection 
				WHEN 1 THEN CASE taxType WHEN 0 THEN  0 ELSE taxValue END
				ELSE  CASE taxType WHEN 0 THEN [taxVALUE] ELSE 0 END
				END, 
			CASE WHEN @btShortEntry = 1 THEN '' ELSE @txt_Tax +' - '+[taxNotes] END, 
			[taxCurrencyVAL], 
			'', 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			[taxAccount], 
			[taxCurrencyPtr], 
			0x0, 
			maCashAccGUID 
		FROM @t_tax
		
	
	--INSERT TAX
	INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID]) 
		SELECT * FROM (SELECT 
			CASE @btDirection WHEN 1 THEN @recType_TaxContra ELSE @recType_Tax END recType, 
			[taxNumber]	, 
			@buDate [Date], 
			SUM(CASE @btDirection 
				WHEN 1 THEN CASE taxType WHEN 0 THEN  0 ELSE taxValue END
				ELSE  CASE taxType WHEN 0 THEN [taxVALUE] ELSE 0 END
				END) debit,
			SUM(CASE @btDirection 
				WHEN 1 THEN CASE taxType WHEN 0 THEN [taxVALUE] ELSE 0 END
				ELSE CASE taxType WHEN  0 THEN 0 ELSE taxValue END
				END) credit, 
			@txt_Tax [Notes],   
			[taxCurrencyVAL], 
			'' Class, 
			@buVendor Vendor, 
			@buSalesManPtr SalesMan, 
			@entryGUID ParentGuid, 
			maCashAccGUID accountGuid, 
			[taxCurrencyPtr], 
			0x0 CostGuid, 
			[taxAccount]
		FROM @t_tax
		GROUP BY taxAccount, taxNumber, taxCurrencyVAL, taxCurrencyPtr, taxNotes, maCashAccGUID
		) t
--„⁄«·Ã… ÷—Ì»… «·„»Ì⁄  ··Âœ«Ì«
		--ﬁ·„ «·Õ”«» 
		
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID])  
			SELECT  
				@recType_ItemsVAT,  
				[biNumber],  
				@buDate,  
				CASE @btDirection 
					WHEN 1 THEN CASE taxType WHEN 0 THEN (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 ELSE 0 END
					ELSE CASE taxType WHEN  0 THEN 0 ELSE (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 END
				END, 
				CASE @btDirection 
					WHEN 1 THEN CASE taxType WHEN 0 THEN  0 ELSE (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 END
					ELSE  CASE taxType WHEN 0 THEN (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 ELSE 0 END
				END,
				CASE @btShortEntry WHEN 1 THEN @buNotes ELSE CASE [biNotes] WHEN '' THEN  @txt_Tax + ' - ' + st.Name + ' - ' + [mtName] + ' (' + @txt_bonus + ')  ' +@Bill_Name+' " '+[biBillname]+' " '+@Bill_Num+' '+cast([biBillNumber] as NVARCHAR(50))ELSE [mtName] + '-' + [biNotes] END END,     
				-- CASE @btShortEntry WHEN 0 THEN @txt_VAT + ' - ' + mtName ELSE '' END,  
				@buCurrencyVAL,  
				[biClassPtr],  
				@buVendor,  
				@buSalesManPtr,  
				@entryGUID,  
				st.AccountGuid,  
				@buCurrencyGUID,  
				CASE @btCostToTaxAcc WHEN 1 THEN [biCostPtr] ELSE 0x0 END,  
				[maBonusAccGuid] 
			FROM 
				#t_bi AS [bi] INNER JOIN @t_bonus AS [bn] ON [bi].[biMatPtr] = [bn].[mtGUID] AND [bn].[unity] = [bi].[biUnity]    
				CROSS JOIN SalesTax000 st 
			WHERE  
			 bi.biIsApplyTaxOnGifts = 1
				AND st.ValueType = 1
				AND [BillTypeGuid]= @buTypeGUID
	--ﬁ·„ «·Õ”«» «·„ﬁ«»·				
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID])  
			SELECT  
				@recType_ItemsVAT,  
				[biNumber],  
				@buDate,  
				CASE @btDirection 
					WHEN 1 THEN CASE taxType WHEN 0 THEN 0 ELSE (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 END
					ELSE CASE taxType WHEN  0 THEN (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 ELSE 0 END
				END, 
				CASE @btDirection 
					WHEN 1 THEN CASE taxType WHEN 0 THEN (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 ELSE 0 END
					ELSE  CASE taxType WHEN 0 THEN 0 ELSE (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] * ST.Value/ 100 END
				END,
				CASE @btShortEntry WHEN 1 THEN @buNotes ELSE CASE [biNotes] WHEN '' THEN @txt_Tax + ' - ' + st.Name + ' - ' + [mtName] + ' (' + @txt_bonus + ')  ' +@Bill_Name+' " '+[biBillname]+' " '+@Bill_Num+' '+cast([biBillNumber] as NVARCHAR(50))ELSE [mtName] + '-' + [biNotes] END END,    
				-- CASE @btShortEntry WHEN 0 THEN @txt_VAT + ' - ' + mtName ELSE '' END,  
				@buCurrencyVAL,  
				[biClassPtr],  
				@buVendor,  
				@buSalesManPtr,  
				@entryGUID,  
				[maBonusAccGuid],  
				@buCurrencyGUID,  
				CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END,  
				st.AccountGuid
			FROM 
				#t_bi AS [bi] INNER JOIN @t_bonus AS [bn] ON [bi].[biMatPtr] = [bn].[mtGUID] AND [bn].[unity] = [bi].[biUnity]    
				CROSS JOIN SalesTax000 st 
			WHERE  
				 bi.biIsApplyTaxOnGifts = 1 
				 AND st.ValueType = 1
				 AND [BillTypeGuid]= @buTypeGUID
	End
	------------------------------------------------------------------ other side ------------------------------------------------------------------  
	-- 2.1: insert Customer Accounts data: 
	SELECT 
		@recType_CustAcc AS [recType], 
		[biNumber] AS [RecBiNumber], 
		@buDate AS [Date], 
		CASE @btDirection WHEN 1 THEN 0 ELSE [biPrice] * [biBillQty] END AS [Debit], 
		CASE @btDirection WHEN 1 THEN [biPrice] * [biBillQty] ELSE 0 END AS [Credit], 
		CASE WHEN @btShortEntry = 0 AND @btGenContraAcc = 1 THEN (CASE [biNotes] WHEN '' THEN [mtName] ELSE [mtName] + '-' + [biNotes] END) ELSE CAST (@buNotes AS NVARCHAR(1000))   END AS [Notes],
		[biCurrencyVAL] AS [CurrencyVal], 
		[biClassPtr] AS [Class], 
		@buVendor AS [Vendor], 
		@buSalesManPtr AS [SalesMan], 
		@entryGUID AS [ParentGUID], 
		maCashAccGUID AS [accountGUID], 
		biCurrencyPtr AS [CurrencyGUID], 
		CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END AS [CostGUID], 
		@maMatAccGUID AS [contraAccGUID], --CASE @btShortEntry WHEN 1 THEN 0x0 ELSE @maMatAccGUID END  
		0x0 AS [BiGuid]
	INTO #t_2_1_data
	FROM #t_bi 
	WHERE 
		[biPrice] * [biBillQty] > 0
	INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID],[BiGuid]) 
		SELECT 
			[recType],
			0,
			[Date],
			SUM([Debit]),
			SUM([Credit]),
			[Notes],
			[CurrencyVal],
			[Class],
			[Vendor],
			[SalesMan],
			[ParentGUID],
			[accountGUID],
			[CurrencyGUID],
			[CostGUID],
			[contraAccGUID],
			0x0
		FROM
			#t_2_1_data
		GROUP BY
			[recType],
			[Date],
			[Notes],
			[CurrencyVal],
			[Class],
			[Vendor],
			[SalesMan],
			[ParentGUID],
			[accountGUID],
			[CurrencyGUID],
			[CostGUID],
			[contraAccGUID],
			[BiGuid] 
	-- 2.2: put Custormer Discount data, if needed: 
	IF @buItemsDisc + @buBonusDisc > 0
	BEGIN
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
		SELECT 
			@recType_custDisc, 
			0, 
			@buDate, 
			CASE @btDirection WHEN 1 THEN [biDiscount] + [biBonusDisc] - [biContractDiscount] ELSE 0 END, 
			CASE @btDirection WHEN 1 THEN 0 ELSE [biDiscount] + [biBonusDisc] - [biContractDiscount] END, 
			CAST (@buNotes AS NVARCHAR(1000)), --@txt_itemsDisc + ' - ' + mtName, 
			@buCurrencyVal, 
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			maCashAccGUID, 
			@buCurrencyGUID, 
			CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
			CASE @btShortEntry WHEN 1 THEN @maMatAccGuid ELSE @maDiscAccGUID END,
			0x0
		FROM #t_bi 
		WHERE 
			[biDiscount] + [biBonusDisc] - [biContractDiscount] <> 0 AND
			[biPrice] * [biBillQty] > 0 
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
		SELECT 
			@recType_custDisc, 
			0, 
			@buDate, 
			CASE @btDirection WHEN 1 THEN [biContractDiscount] ELSE 0 END, 
			CASE @btDirection WHEN 1 THEN 0 ELSE [biContractDiscount] END, 
			CAST (@buNotes AS NVARCHAR(1000)), --@txt_itemsDisc + ' - ' + mtName, 
			@buCurrencyVal, 
			[biClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			CASE @ContraDiscAccGUID WHEN 0x0 THEN maCashAccGUID ELSE @ContraDiscAccGUID END,
			@buCurrencyGUID, 
			CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
			CASE @btShortEntry WHEN 1 THEN @maMatAccGuid ELSE @maDiscAccGUID END, 
			0x0
		FROM #t_bi 
		WHERE 
			[biContractDiscount] <> 0 AND
			[biPrice] * [biBillQty] > 0 
	END 
	
	-- 2.2.1: put Custormer Extra data, if needed: 
	IF @buItemsExtra > 0
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes], [CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
			SELECT 
				@recType_custDisc, 
				0, 
				@buDate, 
				CASE @btDirection WHEN 1 THEN 0 ELSE [biExtra] END, 
				CASE @btDirection WHEN 1 THEN [biExtra] ELSE 0 END, 
				CAST (@buNotes AS NVARCHAR(1000)), --@txt_itemsDisc + ' - ' + mtName, 
				@buCurrencyVal, 
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				maCashAccGUID, 
				@buCurrencyGUID, 
				CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
				CASE @btShortEntry WHEN 1 THEN @maMatAccGuid ELSE @maExtraAccGUID END, 
				0x0
			FROM #t_bi 
			WHERE 
				[biExtra] <> 0 AND
				[biPrice] * [biBillQty] > 0 
	-- 2.3 put di discount data for customer: 
	set @BillCustaccguid =(select custAccguid from bu000 where guid= @billGUID) 
	IF @buTotalDisc > 0 AND @buTotalDisc <> @buItemsDisc 
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID]) 
			SELECT 
				@recType_diCustDiscounts, 
				[diNumber], 
				@buDate, 
				CASE @btDirection 
					WHEN 1 THEN [diDiscount] 
					ELSE 0 
					END, 
				CASE @btDirection 
					WHEN 1 THEN 0 
					ELSE [diDiscount] 
					END, 
				CASE [diContraAccGUID] 
					WHEN 0x0 THEN 
						 CASE @btShortEntry	WHEN 0 THEN [diNotes] ELSE CAST (@buNotes AS NVARCHAR(1000)) END
					ELSE 
						[diNotes]
					END, 
				[diCurrencyVAL], 
				[diClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				CASE [diContraAccGUID] 
					WHEN 0x0 THEN @BillCustaccguid 
					ELSE [diContraAccGUID] 
					END, 
				[diCurrencyPtr], 
				CASE @btContraCostToDiscount WHEN 1 THEN
				CASE [diCostGUID] WHEN 0x0 THEN @buCostGuid ELSE [diCostGUID] END 
				ELSE 0x0 END, 
				CASE @btShortEntry WHEN 1 THEN @maMatAccGUID ELSE [diAccount] END 
			FROM @t_di WHERE [diDiscount] > 0 
	 
	-- 2.4: insert FirstPay data for Customer Account, if any: 
	DECLARE @m_note nvarchar(MAX)
	IF @buFirstPay > 0 
	BEGIN 
		--IF (@CenteringCusAcc = 1 AND @buPayType = 0)  
		--BEGIN
		--   SET @buFPayAccGUID = @BillCustAccGuid
		--   SET @m_note =''
		--END
		--ELSE
		--BEGIN
		SET @buFPayAccGUID = CASE ISNULL(@buFPayAccGUID, 0x0) WHEN 0x0 THEN @btDefCashAccGUID ELSE @buFPayAccGUID END 
		SET @m_note =@txt_firstPay + ' ' + @btName + ' ' + CAST(@buNumber AS [NVARCHAR](50))
		--END 
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID]) 
			SELECT 
				@recType_fPayOfCustAcc, 
				0, 
				@buDate, 
				CASE @btDirection WHEN 1 THEN 0 ELSE @buFirstPay END, 
				CASE @btDirection WHEN 1 THEN @buFirstPay ELSE 0 END, 
				@m_note , --@txt_firstPay + ' ' + @btName + ' ' + CAST(@buNumber AS [NVARCHAR](50)), 
				@buCurrencyVAL, 
				0, 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				@buFPayAccGUID, 
				@buCurrencyGUID, 
				CASE @btCostToCust WHEN 1 THEN @buCostGUID ELSE 0x0 END, 
				@buCustAccGUID 
	END 

	DECLARE @buTotalWithoutTTC FLOAT

	SELECT @buTotalWithoutTTC = SUM(
		CASE @IncludeTTCDiffOnSales WHEN 1 THEN 
			((biPrice * (biBillQty - CASE WHEN @btConsideredGiftsOfSales= 1 THEN [bi].[biBillBonusQnt] ELSE 0 END)) + biVAT) / (1 + (MT.VAT / 100)) 
		ELSE biPrice * biBillQty END)
	FROM #t_bi BI INNER JOIN mt000 MT ON BI.biMatPtr = MT.GUID

	-- 2.5: insert di Discount data, if any: 
	IF @btShortEntry = 0
	BEGIN
	IF @buTotalPrice <> 0 
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid],[DiGuid]) 
			SELECT 
				@recType_diDiscounts, 
				[diNumber], 
				@buDate, 
				CASE @btDirection 
					WHEN 1 THEN 0 
					ELSE 
						CASE WHEN @buTotalWithoutTTC - @buItemsDisc<> 0 THEN
							CASE @IncludeTTCDiffOnSales WHEN 0 THEN							
							(CASE WHEN @btConsideredGiftsOfSales= 1 
									THEN ([diDiscount] * ([biPrice] * ([bi].[biBillQty] - [bi].[biBillBonusQnt]) - bi.biDiscount) / (@buTotal - @buItemsDisc))
									ELSE [diDiscount] * ([biPrice] * [biBillQty] - bi.biDiscount) / (@buTotal - @buItemsDisc)
							END)
							ELSE
								([diDiscount] * 
								(((([biPrice] * ([bi].[biBillQty] - CASE WHEN @btConsideredGiftsOfSales= 1 THEN [bi].[biBillBonusQnt] ELSE 0 END) ) + bi.biVAT) / (1 + (MT.VAT / 100))) - bi.biDiscount)
								 / 
								(@buTotalWithoutTTC - @buItemsDisc))
							END
						ELSE 0
						END
					END, 
				CASE @btDirection 
					WHEN 1 THEN
						CASE WHEN @buTotalWithoutTTC - @buItemsDisc<> 0 THEN
							CASE @IncludeTTCDiffOnSales WHEN 0 THEN							
							(CASE WHEN @btConsideredGiftsOfSales= 1 
									THEN ([diDiscount] * ([biPrice] * ([bi].[biBillQty] - [bi].[biBillBonusQnt]) - bi.biDiscount) / (@buTotal - @buItemsDisc))
									ELSE [diDiscount] * ([biPrice] * [biBillQty] - bi.biDiscount) / (@buTotal - @buItemsDisc)
							END)
							ELSE
								([diDiscount] * 
								(((([biPrice] * ([bi].[biBillQty] - CASE WHEN @btConsideredGiftsOfSales= 1 THEN [bi].[biBillBonusQnt] ELSE 0 END) ) + bi.biVAT) / (1 + (MT.VAT / 100))) - bi.biDiscount)
								 / 
								(@buTotalWithoutTTC - @buItemsDisc))
							END
						ELSE 0
						END
					ELSE 0 
					END, 
				CASE [diNotes] WHEN  '' THEN '' ELSE [diNotes] + ' _ ' END + bi.[mtName], 
				[diCurrencyVAL], 
				[diClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				[diAccount], 
				[diCurrencyPtr], 
				CASE @btCostToDiscount WHEN 1 THEN 
				CASE [diCostGUID] WHEN 0x0 THEN @buCostGuid ELSE [diCostGUID] END 
				ELSE 0x0 END, 
				CASE [diContraAccGUID] WHEN 0x0 THEN bi.maCashAccGUID ELSE [diContraAccGUID] END, 
				bi.[biGuid],
				di.diGuid
			FROM @t_diSons di
			CROSS JOIN #t_bi bi
			INNER JOIN mt000 MT ON BI.biMatPtr = MT.GUID
			WHERE [diDiscount] > 0 
			ORDER BY [diAccount],[diNumber]
	ELSE IF (@buTotalPrice = 0)
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
			SELECT 
				@recType_diDiscounts, 
				[diNumber], 
				@buDate,
				CASE @btDirection 
					WHEN 1 THEN 0 
					ELSE [diDiscount] 
					END,  
				CASE @btDirection 
					WHEN 1 THEN [diDiscount] 
					ELSE 0 
					END, 
				
				CASE [diContraAccGUID] 
					WHEN 0x0 THEN 
						 CASE @btShortEntry	WHEN 0 THEN [diNotes] ELSE CAST (@buNotes AS NVARCHAR(1000)) END
					ELSE 
						[diNotes]
					END, 
				[diCurrencyVAL], 
				[diClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID,
				[diAccount],
				[diCurrencyPtr], 
				CASE @btCostToDiscount WHEN 1 THEN 
				CASE [diCostGUID] WHEN 0x0 THEN @buCostGuid ELSE [diCostGUID] END 
				ELSE 0x0 END ,
				CASE [diContraAccGUID] WHEN 0x0 THEN @buCustAccGUID ELSE [diContraAccGUID] END, 
				0x0
			FROM @t_di WHERE [diDiscount] > 0  
	END
	
	ELSE
	BEGIN
	 IF @buTotalPrice <> 0 
	    INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID],[DiGuid]) 
		SELECT 
			@recType_diDiscounts, 
			[diNumber], 
			@buDate, 
			CASE @btDirection 
				WHEN 1 THEN 0 
				ELSE [diDiscount] 
				END, 
			CASE @btDirection 
				WHEN 1 THEN [diDiscount] 
				ELSE 0 
				END, 
			CASE 
					WHEN [diAccount] = @buMatAccGUID OR [diAccount] = @btDefBillAccGUID THEN CAST (@buNotes AS NVARCHAR(1000))  
					ELSE [diNotes] 
				END, 
			[diCurrencyVAL], 
			[diClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			[diAccount], 
			[diCurrencyPtr], 
			CASE @btCostToItems WHEN 1 THEN [diCostGUID] ELSE 0x0 END, 
			CASE [diContraAccGUID] WHEN 0x0 THEN @buCustAccGUID ELSE [diContraAccGUID] END,
			[diGuid]
		FROM @t_diSons 
		WHERE [diDiscount] > 0 
		ORDER BY [diAccount],[diNumber]
	 ELSE IF (@buTotalPrice = 0)
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
					SELECT 
						@recType_diDiscounts, 
						[diNumber], 
						@buDate, 
						
						CASE @btDirection 
							WHEN 1 THEN 0 
							ELSE [diDiscount] 
							END, 
							CASE @btDirection 
							WHEN 1 THEN [diDiscount] 
							ELSE 0 
							END, 
						CASE [diContraAccGUID] 
							WHEN 0x0 THEN 
								 CASE @btShortEntry	WHEN 0 THEN [diNotes] ELSE CAST (@buNotes AS NVARCHAR(1000)) END
							ELSE 
								[diNotes]
							END, 
						[diCurrencyVAL], 
						[diClassPtr], 
						@buVendor, 
						@buSalesManPtr, 
						@entryGUID, 
						[diAccount],
						[diCurrencyPtr], 
						CASE @btCostToDiscount WHEN 1 THEN 
						CASE [diCostGUID] WHEN 0x0 THEN @buCostGuid ELSE [diCostGUID] END 
						ELSE 0x0 END , 
						CASE [diContraAccGUID] WHEN 0x0 THEN @buCustAccGUID ELSE [diContraAccGUID] END, 
						0x0
					FROM @t_di WHERE [diDiscount] > 0  
		END			
	-- 2.6: insert di Extra data, if any: 
	IF @btShortEntry = 0
		BEGIN
		 IF @buTotalPrice <> 0 
			INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid],[DiGuid]) 
				SELECT 
					@recType_diExtras, 
					[diNumber], 
					@buDate, 
					CASE @btDirection WHEN 1 THEN 
						CASE WHEN @buTotalWithoutTTC + @buItemsExtra <> 0 THEN
							CASE @IncludeTTCDiffOnSales WHEN 0 THEN
							(CASE WHEN @btConsideredGiftsOfSales= 1 
									THEN ([diExtra] * ([biPrice] * ([bi].[biBillQty] - [bi].[biBillBonusQnt]) + [bi].biExtra) / (@buTotal + @buItemsExtra)) 
									ELSE [diExtra] * ([biPrice] * [biBillQty] + bi.biExtra) / (@buTotal + @buItemsExtra)
							END)
							ELSE
								([diExtra] * 
								(((([biPrice] * ([bi].[biBillQty] - CASE WHEN @btConsideredGiftsOfSales= 1 THEN [bi].[biBillBonusQnt] ELSE 0 END) ) + bi.biVAT) / (1 + (MT.VAT / 100))) + bi.biExtra)
								 / 
								(@buTotalWithoutTTC + @buItemsExtra))
							END
						ELSE 0
						END
					ELSE 0 
					END, 
					CASE @btDirection WHEN 1 THEN 0 ELSE 
						CASE WHEN @buTotalWithoutTTC + @buItemsExtra<> 0 THEN
							CASE @IncludeTTCDiffOnSales WHEN 0 THEN
							(CASE WHEN @btConsideredGiftsOfSales= 1 
									THEN ([diExtra] * ([biPrice] * ([bi].[biBillQty] - [bi].[biBillBonusQnt]) + [bi].biExtra) / (@buTotal + @buItemsExtra)) 
									ELSE [diExtra] * ([biPrice] * [biBillQty] + bi.biExtra) / (@buTotal + @buItemsExtra)
							END)
							ELSE
								([diExtra] * 
								(((([biPrice] * ([bi].[biBillQty] - CASE WHEN @btConsideredGiftsOfSales= 1 THEN [bi].[biBillBonusQnt] ELSE 0 END) ) + bi.biVAT) / (1 + (MT.VAT / 100))) + bi.biExtra)
								 / 
								(@buTotalWithoutTTC + @buItemsExtra))
							END
						ELSE 0
						END					
					END, 
					CASE [diNotes] WHEN  '' THEN '' ELSE [diNotes] + ' _ ' END + bi.[mtName], 
					[diCurrencyVAL], 
					[diClassPtr], 
					@buVendor, 
					@buSalesManPtr,
					@entryGUID,
					[diAccount],
					[diCurrencyPtr], 
					CASE @btCostToDiscount WHEN 1 THEN 
					CASE [diCostGUID] WHEN 0x0 THEN @buCostGuid ELSE [diCostGUID] END 
					ELSE 0x0 END , 
					CASE [diContraAccGUID] WHEN 0x0 THEN @billCustAccGUID ELSE [diContraAccGUID] END, 
					bi.[biGuid],
					di.[diGuid]
				FROM @t_diSons di
				CROSS JOIN #t_bi bi  INNER JOIN mt000 MT ON BI.biMatPtr = MT.GUID
				WHERE [diExtra] > 0
				ORDER BY [diAccount],[diNumber]
		  ELSE IF @buTotalPrice = 0 
			  INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
				SELECT 
					@recType_diExtras, 
					[diNumber], 
					@buDate, 
					CASE @btDirection WHEN 1 THEN [diExtra] ELSE 0 END, 
					CASE @btDirection WHEN 1 THEN 0 ELSE [diExtra] END, 
					[diNotes], 
					[diCurrencyVAL], 
					[diClassPtr], 
					@buVendor, 
					@buSalesManPtr, 
					@entryGUID, 
					[diAccount],
					[diCurrencyPtr], 
					CASE @btCostToCust WHEN 1 THEN [diCostGUID] ELSE 0x0 END, 
					CASE [diContraAccGUID] WHEN 0x0 THEN @buCustAccGUID ELSE [diContraAccGUID] END 
					,0x0
				FROM @t_di 
				WHERE [diExtra]> 0 
		  END
	ELSE
	  BEGIN
		IF @buTotalPrice <> 0 
			INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID],[DiGuid]) 
				SELECT 
					@recType_diExtras, 
					[diNumber], 
					@buDate, 
					CASE @btDirection WHEN 1 THEN [diExtra] ELSE 0 END, 
					CASE @btDirection WHEN 1 THEN 0 ELSE [diExtra] END, 
					[diNotes], 
					[diCurrencyVAL], 
					[diClassPtr], 
					@buVendor, 
					@buSalesManPtr, 
					@entryGUID, 
					[diAccount], 
					[diCurrencyPtr], 
					CASE @btCostToDiscount WHEN 1 THEN 
					CASE [diCostGUID] WHEN 0x0 THEN @buCostGuid ELSE [diCostGUID] END 
					ELSE 0x0 END , 
					CASE [diContraAccGUID] WHEN 0x0 THEN @billCustAccGUID ELSE [diContraAccGUID] END,
					diGuid
				FROM @t_diSons 
				WHERE [diExtra] > 0 
				ORDER BY [diAccount],[diNumber]
		ELSE IF @buTotalPrice = 0 
			  INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid]) 
				SELECT 
					@recType_diExtras, 
					[diNumber], 
					@buDate,
					CASE @btDirection WHEN 1 THEN [diExtra] ELSE 0 END,  
					CASE @btDirection WHEN 1 THEN 0 ELSE [diExtra] END, 
					
					[diNotes], 
					[diCurrencyVAL], 
					[diClassPtr], 
					@buVendor, 
					@buSalesManPtr, 
					@entryGUID, 
					[diAccount], 
					[diCurrencyPtr], 
					CASE @btCostToCust WHEN 1 THEN [diCostGUID] ELSE 0x0 END, 
					CASE [diContraAccGUID] WHEN 0x0 THEN @buCustAccGUID ELSE [diContraAccGUID] END 
					,0x0
				FROM @t_di 
				WHERE [diExtra]> 0 
		END		
	  
	-- 2.7: insert di ExtrasToCust data, if any: 
INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID]) 
		SELECT 
			@recType_diExtrasToCust, 
			[diNumber], 
			@buDate, 
			CASE @btDirection WHEN 1 THEN 0 ELSE [diExtra] END, 
			CASE @btDirection WHEN 1 THEN [diExtra] ELSE 0 END, 
			[diNotes], 
			[diCurrencyVAL], 
			[diClassPtr], 
			@buVendor, 
			@buSalesManPtr, 
			@entryGUID, 
			CASE [diContraAccGUID] WHEN 0x0 THEN @billCustAccGUID ELSE [diContraAccGUID] END, 
			[diCurrencyPtr], 
			CASE @btContraCostToDiscount WHEN 1 THEN
			CASE [diCostGUID] WHEN 0x0 THEN @buCostGuid ELSE [diCostGUID] END
			ELSE 0x0 END  ,
			/*CASE [diContraAccGUID] WHEN 0x0 THEN @maMatAccGUID ELSE*/ [diAccount] /*END*/ 
		FROM @t_di 
		WHERE [diExtra]> 0 
	 
	-- 2.8: insert biVAT data of customer, if any: 
	IF @btVatSystem = 1 OR @btVatSystem = 2 OR @IsGCCSystemEnabled = 1
		INSERT INTO @t_en ([recType],[RecBiNumber],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type]) 
			SELECT
				@recType_CustVAT, 
				[biNumber], 
				@buDate, 
				CASE @btDirection WHEN 1 THEN 0 ELSE [biVAT] END, 
				CASE @btDirection WHEN 1 THEN [biVAT] ELSE 0 END, 
				CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE @txt_vat + ' "' + [mtName]+'" '+@Bill_Name+' " '+[biBillname]+'" '+@Bill_Num+' '+cast([biBillNumber] as NVARCHAR(50)) end, 
				[biCurrencyVAL], 
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				maCashAccGUID, 
				[biCurrencyPtr], 
				CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END,  
				CASE @btShortEntry WHEN 1 THEN @maMatAccGuid ELSE [maVATAccGUID] END,
				0x0,
				0
			FROM #t_bi 
			WHERE 
				[biVAT] > 0 AND ((@IsGCCSystemEnabled = 1 AND IsProfitMargin = 0) OR @IsGCCSystemEnabled = 0)

	-- 2.10: insert Bonus: 
	IF (@btDefBonusPrice > 1) OR (@btConsideredGiftsOfSales<> 0)
		INSERT INTO @t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
			SELECT --DISTINCT   
				CASE @btDirection WHEN 1 THEN @recType_BonusContra ELSE @recType_Bonus END, 
				[biNumber], 
				@buDate, 
				CASE @btDirection WHEN 1 THEN (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] ELSE 0 END,
				CASE @btDirection WHEN 1 THEN 0 ELSE (CASE WHEN @btConsideredGiftsOfSales<> 0 THEN [bi].[biPrice] ELSE [bn].[Price] END) * [bi].[biBillBonusQnt] END,
				CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE CASE [biNotes] WHEN '' THEN [mtName] + ' (' + @txt_bonus + ')' ELSE [mtName] + '-' + [biNotes] END END, 
				@buCurrencyVal, 
				[biClassPtr], 
				@buVendor, 
				@buSalesManPtr, 
				@entryGUID, 
				CASE WHEN (@btConsideredGiftsOfSales<> 0) THEN bi.maCashAccGUID ELSE [maBonusContraAccGuid] END, 
				@buCurrencyGUID, 
				CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
				[maBonusAccGuid],
				[biGuid]
			FROM #t_bi AS [bi] INNER JOIN @t_bonus AS [bn] ON [bi].[biMatPtr] = [bn].[mtGUID] AND [bn].[unity] = [bi].[biUnity]   
			INNER JOIN mt000 mt on mt.[GUID] = bi.biMatPtr
	-- 3: insert data from buffers and generate entry: 
	-- 3.1 summarizing @t_en into @t_en2 
	-- 3.1.1 debits 
	INSERT INTO @t_en2 ([DC], [date],[notes],[currencyVal],[class],[vendor],[salesMan],[parentGUID],[accountGUID],[currencyGUID],[costGUID],[contraAccGUID], [BiGuid], [Type],[DiGuid]) 
		SELECT 
			SUM([e].debit), 
			[e].[date], 
			[e].[notes], 
			[e].[currencyVal], 
			[e].[class], 
			[e].[vendor], 
			[e].[salesMan], 
			[e].[parentGUID], 
			[e].[accountGUID], 
			[e].[currencyGUID], 
			[e].[costGUID],  
			[e].[contraAccGUID],
			[e].[BiGuid],
			[e].[Type],
			[e].[DiGuid]
		FROM @t_en AS [e] INNER JOIN [ac000] AS [a] ON [e].[accountGUID] = [a].[GUID]  
		WHERE [e].[debit] <> 0  
		GROUP BY [e].[recType],[e].[RecBiNumber], [e].[date], [e].[notes], [e].[currencyVal], [e].[class], [e].[vendor], [e].[salesMan], [e].[parentGUID], [e].[accountGUID], [e].[currencyGUID], [e].[costGUID], [e].[contraAccGUID], [a].[Code], [e].[BiGuid], [e].[Type], [e].[DiGuid]
		ORDER BY [e].[recType], [e].[RecBiNumber], [a].[Code] DESC 
	-- 3.1.2 credit 
	INSERT INTO @t_en2 ([DC], [date], [notes], [currencyVal], [class], [vendor], [salesMan], [parentGUID], [accountGUID], [currencyGUID], [costGUID], [contraAccGUID], [BiGuid], [Type],[DiGuid]) 
		SELECT 
			- SUM([e].[credit]), 
			[e].[date], 
			[e].[notes], 
			[e].[currencyVal], 
			[e].[class], 
			[e].[vendor], 
			[e].[salesMan], 
			[e].[parentGUID], 
			[e].[accountGUID], 
			[e].[currencyGUID], 
			[e].[costGUID], 
			[e].[contraAccGUID],
			[e].[BiGuid],
			[e].[Type],
			[e].[DiGuid]
		FROM @t_en AS [e] INNER JOIN [ac000] AS [a] ON [e].[accountGUID] = [a].[GUID] 
		WHERE [e].[credit] <> 0  
		GROUP BY [e].[recType], [e].[RecBiNumber], [e].[date], [e].[notes], [e].[currencyVal], [e].[class], [e].[vendor], [e].[salesMan], [e].[parentGUID], [e].[accountGUID], [e].[currencyGUID], [e].[costGUID],[e].[contraAccGUID],[a].[Code], [e].[BiGuid], e.[Type], [e].[DiGuid]
		ORDER BY [e].[recType], [e].[RecBiNumber], [a].[Code]  
	-- 3.2 try to put customer contraAcc, if any 
	IF (SELECT COUNT(*) FROM (SELECT DISTINCT [accountGUID] FROM @t_en2 WHERE [accountGUID] <> @buCustAccGUID) AS dum) = 1 
		UPDATE @t_en2 SET 
				[contraAccGUID] = (SELECT TOP 1 [accountGUID] FROM @t_en2 WHERE [accountGUID] <> @buCustAccGUID) 
			WHERE [accountGUID] = @buCustAccGUID 

	IF EXISTS(SELECT * FROM @t_en2) 
	BEGIN 
		DECLARE @AccoutnGUID UNIQUEIDENTIFIER;
		IF @buPayType = 0 AND EXISTS(SELECT 1 FROM vwAcCu WHERE GUID = @buCustAccGUID AND CustomersCount = 1)
		BEGIN
			UPDATE @t_en2 SET CustomerGUID = (SELECT TOP 1 GUID FROM cu000 WHERE AccountGUID = @buCustAccGUID) WHERE [accountGUID] = @buCustAccGUID 
		END
		ELSE
		BEGIN
			UPDATE @t_en2 SET CustomerGUID = @buCustomerGUID WHERE [accountGUID] = @buCustAccGUID 
		END

		UPDATE t
			SET CustomerGuid = cu.GUID 
			FROM @t_en2 t  
				INNER JOIN vwAcCu ac ON t.accountGUID = ac.GUID
				LEFT JOIN cu000 cu on cu.AccountGUID = t.accountGUID
				WHERE ISNULL(t.CustomerGUID, 0x0) = 0x0
				AND ac.CustomersCount = 1
				  
			IF EXISTS(SELECT 1 
				FROM @t_en2 AS t
				INNER JOIN vwAcCu ac ON t.accountGUID = ac.GUID
			WHERE CustomerGUID = @buCustomerGUID AND accountGUID = @buCustAccGUID 
				AND NOT EXISTS(SELECT 1 FROM cu000 WHERE GUID = @buCustomerGUID AND AccountGUID = @buCustAccGUID)
				AND ac.CustomersCount > 1)
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0052: [' + CAST(@buCustAccGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
				RETURN
			END
			-- check the default bill account if it has multi customers or not 
			IF EXISTS(SELECT 1 FROM vwAcCu WHERE GUID = @btDefBillAccGUID AND CustomersCount > 1) 
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0052: [' + CAST(@btDefBillAccGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
				RETURN
			END

			IF EXISTS(SELECT t.accountGUID
			FROM @t_en2 t  
			INNER JOIN vwAcCu ac ON t.accountGUID = ac.GUID
			LEFT JOIN cu000 cu on cu.AccountGUID = t.accountGUID
			WHERE ISNULL(t.CustomerGUID, 0x0) = 0x0
			AND ac.CustomersCount > 1)
			BEGIN
				SELECT TOP 1 @AccoutnGUID = t.accountGUID
				FROM @t_en2 t  
				INNER JOIN vwAcCu ac ON t.accountGUID = ac.GUID
				LEFT JOIN cu000 cu on cu.AccountGUID = t.accountGUID
				WHERE ISNULL(t.CustomerGUID, 0x0) = 0x0
				AND ac.CustomersCount > 1

			
			END

		UPDATE en
		SET customerguid = di.CustomerGuid 
		FROM @t_en2 en 
		INNER JOIN di000  AS [di] ON [en].[accountGUID] = [di].AccountGUID
		WHERE [di].ParentGUID = @billguid  AND di.GUID = en.DiGuid

		INSERT INTO [ce000] ([typeGUID], [Type],[Number],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[IsPosted],[Security],[Branch],[GUID],[CurrencyGUID], [PostDate]) 
			SELECT @buTypeGUID, 1, [dbo].[fnEntry_getNewNum1](@entryNum, @buBranchGUID), @buDate, SUM(CASE WHEN [DC] > 0 THEN [DC] ELSE 0 END), SUM(CASE WHEN [DC] < 0 THEN -[DC] ELSE 0 END), @buNotes, @buCurrencyVAL, 0, @buSecurity, @buBranchGUID, @entryGUID, @buCurrencyGUID, CASE @btAutoEntryPost WHEN 1 THEN GetDate() ELSE @buDate END
			FROM @t_en2 
		-- 3.4 en 
		DECLARE @EnCount AS [FLOAT]
		SELECT @EnCount = COUNT(DISTINCT [name]) FROM @t_en2 INNER JOIN [ac000] [a] ON [accountGuid] = [a].[guid]
		
		CREATE TABLE #FinalEN (
			[Number] INT, [Date] DATE, [Debit] FLOAT, [Credit] FLOAT, [Notes] NVARCHAR(1000), 
			[CurrencyVal] FLOAT, [Class] NVARCHAR(250), [Vendor] FLOAT,[SalesMan] FLOAT,
			[ParentGUID] UNIQUEIDENTIFIER, [accountGUID] UNIQUEIDENTIFIER, [CurrencyGUID] UNIQUEIDENTIFIER,
			[CostGUID] UNIQUEIDENTIFIER,[contraAccGUID] UNIQUEIDENTIFIER, [BiGuid] UNIQUEIDENTIFIER, 
			[Type] INT, [CustomerGUID] UNIQUEIDENTIFIER)

		IF (@btShortEntry != 0 AND @EnCount > 1) 
		BEGIN
			DECLARE @btDefCostAcc UNIQUEIDENTIFIER,
					@btDefStockAcc UNIQUEIDENTIFIER

			SELECT @btDefCostAcc = btDefCostAcc, @btDefStockAcc = btDefStockAcc FROM vwBt WHERE btGUID = @buTypeGUID

			INSERT INTO #FinalEN ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type], [CustomerGUID]) 
			SELECT 
				MIN([recID]), 
				[Date], 
				CASE WHEN SUM([DC]) > 0 THEN SUM([DC]) ELSE 0 END, 
				CASE WHEN SUM([DC]) < 0 THEN -SUM([DC]) ELSE 0 END, 
				CASE WHEN [accountGUID] = @BillCustAccGUID THEN N'' ELSE Notes END,  
				[CurrencyVal], 
				MAX( [Class]), 
				[Vendor], 
				[SalesMan], 
				[ParentGUID], 
				[accountGUID], 
				[CurrencyGUID], 
				ISNULL([CostGUID], 0x0), 
				0x0,--ISNULL([contraAccGUID], 0x0),
				0x0, 
				[Type],
				ISNULL(CustomerGUID, 0x0)
			FROM @t_en2 
			GROUP BY 
				[date],CASE WHEN [accountGUID] = @BillCustAccGUID THEN N'' ELSE Notes END, [CurrencyVal], /*[Class],*/[Vendor], [SalesMan], [ParentGuid], [accountGuid], [CurrencyGuid], [CostGuid], [Type], ISNULL(CustomerGUID, 0x0)
		END 
		ELSE IF (@btCollectCustAccount != 0 AND @EnCount > 1)  
		BEGIN 
			INSERT INTO #FinalEN ([Number],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type], CustomerGUID) 
			SELECT 
				[recID], 
				[Date], 
				CASE WHEN [DC] > 0 THEN [DC] ELSE 0 END, 
				CASE WHEN [DC] < 0 THEN -[DC] ELSE 0 END, 
				[Notes], 
				[CurrencyVal], 
				[Class], 
				[Vendor], 
				[SalesMan], 
				[ParentGUID], 
				[accountGUID], 
				[CurrencyGUID], 
				ISNULL([CostGUID], 0x0), 
				ISNULL([contraAccGUID], 0x0),
				ISNULL([BiGuid], 0x0),
				[Type],
				ISNULL(CustomerGUID, 0x0)
			FROM @t_en2  
			WHERE [accountGUID] != @BillCustAccGUID
			ORDER BY [recID], [DC] ASC

			INSERT INTO #FinalEN ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID],[CostGUID],[contraAccGUID], [BiGuid], [Type], [CustomerGUID]) 
			SELECT 
				MIN([recID]), 
				[Date], 
				CASE WHEN SUM([DC]) > 0 THEN SUM([DC]) ELSE 0 END, 
				CASE WHEN SUM([DC]) < 0 THEN -SUM([DC]) ELSE 0 END, 
				@buNotes,  
				[CurrencyVal], 
				MAX( [Class]), 
				[Vendor], 
				[SalesMan], 
				[ParentGUID], 
				[accountGUID], 
				[CurrencyGUID], 
				ISNULL([CostGUID], 0x0), 
				0x0,--ISNULL([contraAccGUID], 0x0),
				0x0, 
				[Type],
				ISNULL(CustomerGUID, 0x0)
			FROM @t_en2 
			WHERE [accountGUID] = @BillCustAccGUID
			GROUP BY 
				[date], /*[Notes], */[CurrencyVal], /*[Class],*/ [Vendor], [SalesMan], [ParentGuid], [accountGuid], [CurrencyGuid], [CostGuid], [Type], ISNULL(CustomerGUID, 0x0)
		END ELSE
			INSERT INTO #FinalEN ([Number],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[Class],[Vendor],[SalesMan],[ParentGUID],[accountGUID],[CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type], CustomerGUID) 
			SELECT 
				[recID], 
				[Date], 
				CASE WHEN [DC] > 0 THEN [DC] ELSE 0 END, 
				CASE WHEN [DC] < 0 THEN -[DC] ELSE 0 END, 
				[Notes], 
				[CurrencyVal], 
				[Class], 
				[Vendor], 
				[SalesMan], 
				[ParentGUID], 
				[accountGUID], 
				[CurrencyGUID], 
				ISNULL([CostGUID], 0x0), 
				ISNULL([contraAccGUID], 0x0),
				ISNULL([BiGuid], 0x0),
				[Type],
				ISNULL(CustomerGUID, 0x0)
			FROM @t_en2  
			ORDER BY [recID], [DC] ASC

		IF ((@btCentringCustomerAccount > 0) AND EXISTS (SELECT * FROM #FinalEN) AND @buCustomerGUID <> 0x0 AND @buPayType = 0)
		BEGIN
			DECLARE @AccGUID UNIQUEIDENTIFIER 
			SELECT @AccGUID = AccountGUID FROM cu000 WHERE [GUID] = @buCustomerGUID

			UPDATE #FinalEN
			SET [ContraAccGUID] = @AccGUID
			WHERE [ContraAccGUID] = @BillCustAccGUID

			INSERT INTO #FinalEN ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID],
				[AccountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type], [CustomerGUID]) 
			SELECT 
				number,
				[Date], 
				Debit, 
				[Credit], 
				[Notes] ,  
				[CurrencyVal], 
				[Class], 
				[Vendor], 
				[SalesMan], 
				[ParentGUID], 
				-- [accountGUID], 
				@AccGUID,
				[CurrencyGUID], 
				[CostGUID], 
				ISNULL([contraAccGUID], 0x0),
				0x0, 
				[Type],
				ISNULL(CustomerGUID, 0x0)
			FROM #FinalEN
			WHERE [AccountGUID] = @BillCustAccGUID

			INSERT INTO #FinalEN ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID],
				[AccountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type], [CustomerGUID]) 
			SELECT 
				number,
				[Date], 
				[Credit],	-- to debit
				Debit,		-- to credit
				[Notes] ,  
				[CurrencyVal], 
				[Class], 
				[Vendor], 
				[SalesMan], 
				[ParentGUID], 
				-- [accountGUID], 
				@AccGUID,
				[CurrencyGUID], 
				[CostGUID], 
				@BillCustAccGUID,--ISNULL([contraAccGUID], 0x0),
				0x0, 
				[Type],
				ISNULL(CustomerGUID, 0x0)
			FROM #FinalEN
			WHERE [AccountGUID] = @BillCustAccGUID

			UPDATE #FinalEN
			SET [ContraAccGUID] = @AccGUID
			WHERE [AccountGUID] = @BillCustAccGUID -- AND ISNULL([ContraAccGUID], 0x0) = 0x0


		END

		INSERT INTO en000([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID],
			[AccountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type], [CustomerGUID]) 
		SELECT 
				[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID],
				[AccountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type], [CustomerGUID]
		FROM #FinalEN

		-- populate distibutive accounts:   
		WHILE EXISTS(SELECT * FROM [en000] [e] INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] WHERE [e].[parentGuid] = @entryGUID AND [a].[type] = 8)   
		BEGIN   
			-- mark distributives:   
			UPDATE [en000] SET [number] = - [e].[number] FROM [en000] [e] INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] WHERE [e].[parentGuid] = @entryGuid AND [a].[type] = 8   
	   
			-- insert distributives detailes:   
			INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID],[CurrencyGUID],[CostGUID],[ContraAccGUID], [Type], CustomerGUID)   
				SELECT   
					- [e].[number], -- this is called unmarking.   
					[e].[date],   
					[e].[debit] * [c].[num2] / 100,   
					[e].[credit] * [c].[num2] / 100,   
					[e].[notes],   
					[e].[currencyVal],   
					[e].[parentGUID],   
					[c].[sonGuid],--e.accountGUID,   
					[e].[currencyGUID],   
					[e].[costGUID],   
					[e].[contraAccGUID], 
					e.[Type], 
					CASE ISNULL(c.CustomerGUID, 0x0) WHEN 0x0 THEN e.CustomerGUID ELSE c.CustomerGUID END
				FROM 
					[en000] [e] 
					inner join [ac000] [a] on [e].[accountGuid] = [a].[guid] 
					inner join [ci000] [c] on [a].[guid] = [c].[parentGuid]   
				WHERE [e].[parentGuid] = @entryGuid and [a].[type] = 8   
	   
			-- delete the marked distributives:   
			DELETE [en000] WHERE [parentGuid] = @entryGuid and [number] < 0   
			-- continue looping untill no distributive accounts are found   
		END   

		-- populate distibutive cost:   
		WHILE EXISTS(SELECT * FROM [en000] [e] INNER JOIN [co000] [a] ON [e].[CostGUID] = [a].[guid] WHERE [e].[parentGuid] = @entryGUID AND [a].[type] = 2)   
		BEGIN   
			-- mark distributives:   
			UPDATE [en000] SET [number] = - [e].[number] FROM [en000] [e] INNER JOIN [co000] [a] ON [e].[CostGUID] = [a].[guid] WHERE [e].[parentGuid] = @entryGUID AND [a].[type] = 2
	   
			-- insert distributives detailes:   
			INSERT INTO [en000] ([Number], [Num1], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Type], CustomerGUID)   
			SELECT   
				- [e].[number],
				c.Number,
				[e].[date],   
				[e].[debit] * [c].[Rate] / 100,
				[e].[credit] * [c].[Rate] / 100,   
				[e].[notes],   
				[e].[currencyVal],   
				[e].[parentGUID],   
				[e].[AccountGUID],   
				[e].[currencyGUID],   
				[c].[SonGuid],
				[e].[contraAccGUID], 
				e.[Type],
				e.CustomerGUID
			FROM 
				[en000] [e] 
				inner join [co000] [a] on [e].[CostGUID] = [a].[GUID] 
				inner join [CostItem000] [c] on [a].[guid] = [c].[parentGuid]   
			WHERE [e].[parentGuid] = @entryGuid and [a].[type] = 2   

			-- delete the marked distributives:   
			DELETE [en000] where [parentGuid] = @entryGuid and [number] < 0   
			
			-- order the en number
			UPDATE en000
			SET 
				Number = o.Number,
				Num1 = 0
			FROM 
				en000 en INNER JOIN 
				(SELECT ROW_NUMBER() OVER (ORDER BY [number], Num1) AS Number, GUID 
					FROM en000
					WHERE [parentGuid] = @entryGuid) o ON en.GUID = o.GUID
		END   

		IF (@maintenanceMode = 1) 
		BEGIN
			IF (@oldIsPosted = 1) 
				UPDATE [ce000] SET 
					[IsPosted] = @oldIsPosted, 
					[PostDate]= @oldPostDate 
				WHERE [GUID] = @entryGUID 

				IF(@AssignContraAccForShortEntry = 1 AND @btShortEntry = 1)
				BEGIN
					EXEC prcEntry_AssignContraAcc @guid = @entryGUID
				END

		END
		ELSE
		-- 3.5 Post, if needed: 
		IF @btAutoEntryPost = 1 
			UPDATE [ce000] 
			SET 
				[IsPosted] = 1, 
				[PostDate]= GetDate()
			WHERE 
				[GUID] = @entryGUID 
		-- 3.6: update er: 
		INSERT INTO [er000] ([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])  
				VALUES(@entryGUID, @billGUID, 2, @buNumber)  
	END   
	DECLARE @enDPay UNIQUEIDENTIFIER
	SET @enDPay = 0x0
	IF @buFirstPay > 0 
	BEGIN
		SELECT 
			@enDPay = [GUID] 
		FROM 
			en000 en 
			INNER JOIN (SELECT entryguid FROM er000 WHERE ParentGuid =  @billGUID ) B 
				ON B.entryguid = en.ParentGuid 
		WHERE 
			en.[ContraAccGuid]  = @buFPayAccGUID
	END
	EXEC prcBill_reConnectPayments @BillGUID, @DeletePaysLinks, @enDPay, @HasSecDeletePaysLink

###############################################################################
CREATE FUNCTION fnCheckForceCost (@billGUID	UNIQUEIDENTIFIER, @BillForceCost INT )
RETURNS INT
BEGIN 

DECLARE @popupMsg INT 
SET @popupMsg = 0 
	 
	SELECT @popupMsg = (CASE @BillForceCost WHEN 1 THEN (CASE  bu.CostGUID WHEN 0x0 THEN 1 ELSE 0 END ) 
						ELSE 0 
						END)
		FROM bu000 bu INNER JOIN bt000 bt ON bu.TypeGUID = bt.Guid 
	WHERE bu.Guid = @billGUID 

	if (@popupMsg = 1)
	RETURN @popupMsg
	
	SELECT @popupMsg = (CASE @BillForceCost WHEN 1  THEN 
		
	 (CASE 
		(select  top 1 en.CostGUID  from [vwDi] di inner join en000 en on en.AccountGUID = di.diAccount   
						INNER JOIN er000 er on en.ParentGUID = er.EntryGUID WHERE [diParent]= er.ParentGUID AND 
						 er.ParentGUID =   @billGUID
        )
		WHEN 0x0 THEN 
		(CASE  
		(select  top 1 en.CostGUID  from [vwDi] di inner join en000 en on en.ContraAccGUID = di.diAccount   
						INNER JOIN er000 er on en.ParentGUID = er.EntryGUID WHERE [diParent]= er.ParentGUID AND 
						 er.ParentGUID =   @billGUID
        )
		WHEN 0x0 THEN 
		(CASE [diCostGUID] WHEN 0x0 THEN 1 ELSE 0 END ) 
		ELSE 0 
		END )
	ELSE 0 END)
	  ELSE 0 END )
	FROM 
		  [vwDi] di
	WHERE [diParent]= @billGUID
	
	
	RETURN @popupMsg

END
###############################################################################
CREATE FUNCTION fnCheckForceCustomer (@billGUID	UNIQUEIDENTIFIER, @BillForceCustomer INT )
RETURNS INT
BEGIN 

DECLARE @popupMsg INT 
SET @popupMsg = 0 
	 
	SELECT @popupMsg = (CASE @BillForceCustomer WHEN 1 THEN (CASE  bu.CustGUID WHEN 0x0 THEN 1 ELSE 0 END ) 
						ELSE 0 
						END)
		FROM bu000 bu INNER JOIN bt000 bt ON bu.TypeGUID = bt.Guid 
	WHERE bu.Guid = @billGUID 

	RETURN @popupMsg

END
###############################################################################
#END
