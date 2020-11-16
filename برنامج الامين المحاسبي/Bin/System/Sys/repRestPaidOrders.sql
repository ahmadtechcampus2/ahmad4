#################################################################################
CREATE PROCEDURE repRestPaidOrders
	@startDate [DateTime],
	@endDate   [DateTime],
	@CashierGuid  [uniqueidentifier],
	@showGroups [bit],
	@showMats [bit],
	@showTaxDetails [bit],
	@showCurDetails [bit],
	@showChecksDetails [bit],
	@showCreditPaymentsDetails [bit]
	
AS
	SET NOCOUNT ON
	DECLARE @selectedOrders TABLE 
	( 
		[GUID] [uniqueidentifier]
	)
	INSERT INTO @selectedOrders
	SELECT 
		[GUID] 
	FROM 
		RestOrder000 [Order]
		
	WHERE 
	    (@CashierGuid=0x0 OR @CashierGuid = [Order].FinishCashierID) 
		AND ([Order].[Closing] BETWEEN @startDate AND @endDate) 
	DECLARE @language [INT]		
	SET @language = [dbo].[fnConnections_getLanguage]() 
	
    declare @master table 
	( 
		[ID] [uniqueidentifier] ,
		[Type] [INT],
		[OrderType] [INT],
		[Note] nvarchar(1000),
		[FinalTotal]  [FLOAT],
		[UserName] nvarchar(500),
		[PARENTID] [uniqueidentifier],
		[SortNum] [INT] default 0
	)
	INSERT INTO 
			@master (ID, [Type],[OrderType], Note, FinalTotal, UserName, ParentID)
	SELECT 
		NEWID(),1,[Order].[TYPE],'',
		ISNULL( (CASE [Order].[TYPE] WHEN 4 THEN -1 ELSE 1 END ) * (BU.Total + BU.TotalExtra + BU.VAT - BU.TotalDisc ), 0),
		us.LoginName, 0x0
	FROM 
		RestOrder000 [Order] 	
		INNER JOIN BillRel000 REL ON [Order].[Guid] = REL.ParentGUID
		INNER JOIN BU000 BU ON REL.BillGUID = BU.[GUID]	
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.GUID
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.GUID
	
	IF(@@ROWCOUNT = 0)
	INSERT INTO @master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
	VALUES (NEWID(), 1, 2,'', 0, '', 0x0 )
	DECLARE @NetSalesGuid [uniqueidentifier]
	SELECT TOP(1) @NetSalesGuid =  ID from @master
	 
	INSERT INTO 
		@master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
	SELECT 
		NEWID() , 2,[Order].[TYPE] ,'',
		(CASE [Order].[TYPE] WHEN 4 THEN -1  ELSE 1 END ) * (ISNULL( Cur.Paid * [Cur].Equal,0)),
		us.LoginName,0x0
	FROM
		RestOrder000 [Order] ​	
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
		INNER JOIN POSPaymentsPackageCurrency000 [Cur] ON [Pack].[Guid] = [Cur].ParentID​
		INNER JOIN my000 my ON [Cur].CurrencyID = [My].[GUID]​
		INNER JOIN BillRel000 rel ON rel.ParentGUID=[Order].GUID​
		INNER JOIN vwBu bu ON bu.buGUID = rel.BillGUID​
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.GUID
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.GUID
	
	IF(@@ROWCOUNT = 0)
    INSERT INTO @master (ID, [Type], [OrderType],Note, FinalTotal, UserName, ParentID)
	VALUES (NEWID(), 2, 2, '', 0, '', 0x0)
	DECLARE @CashGuid [uniqueidentifier]
	SELECT TOP(1) @CashGuid = ID 
	FROM @master
	WHERE [TYPE] = 2
		
	INSERT INTO
		 @master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
	SELECT
		 NEWID(), 3, [Order].[TYPE],'',
		 ISNULL((CASE REL.TYPE WHEN 1 THEN 1 ELSE -1 END) * CHK.Paid,0),
		 us.LoginName, 0x0
	FROM 
		RestOrder000 [ORDER]​
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
		INNER JOIN POSPaymentsPackageCheck000 CHK ON [Pack].[Guid] = CHK.ParentID​
		INNER JOIN nt000 NT ON CHK.Type = NT.[GUID]​
		INNER JOIN BillRel000 rel ON rel.ParentGUID=[Order].GUID​
		INNER JOIN vwBu bu ON bu.buGUID = rel.BillGUID​
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.GUID
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.GUID
	
   IF(@@ROWCOUNT = 0)
   INSERT INTO @master (ID, [Type], [OrderType],Note, FinalTotal, UserName, ParentID)
   VALUES (NEWID(), 3, 2,'', 0, '', 0x0)
	DECLARE @CheckGuid [uniqueidentifier]
	SELECT TOP (1) @CheckGuid = ID 
	FROM @master
	WHERE [TYPE] = 3
	INSERT INTO 
		@master (ID, [Type], [OrderType],Note, FinalTotal, UserName, ParentID)
	SELECT 
		NEWID(), 4, [Order].[TYPE],'',
		ISNULL( PACK.DeferredAmount, 0),
		us.LoginName,0x0
	FROM 
		RestOrder000 [Order] ​
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
		INNER JOIN cu000 [Cu] ON [Pack].[DeferredAccount] = [Cu].[GUID]​
		INNER JOIN ac000 [Acc] ON [Cu].[AccountGUID] = [Acc].[GUID]​
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]	
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
		
	WHERE 
		PACK.DeferredAmount != 0
   IF(@@ROWCOUNT = 0)
   INSERT INTO @master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
   VALUES (NEWID(), 4, 2,'', 0,'', 0x0)
	DECLARE @CreditPaymentGuid [uniqueidentifier]
	SELECT TOP (1)  @CreditPaymentGuid = ID 
	FROM @master
	WHERE [TYPE] = 4

	---Loyaltycard pay
	INSERT INTO
		 @master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
	SELECT
		 NEWID(), 17, [Order].[TYPE],'',
		 ISNULL(pp.PointsValue,0),
		 us.LoginName, 0x0
	FROM 
		RestOrder000 [ORDER]​
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
		INNER JOIN POSPaymentsPackagePoints000 pp ON  [Pack].[Guid] = pp.ParentGUID
		INNER JOIN BillRel000 rel ON rel.ParentGUID=[Order].GUID​
		INNER JOIN vwBu bu ON bu.buGUID = rel.BillGUID​
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.GUID
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.GUID

	IF( @showGroups = 1 )
	BEGIN
		INSERT INTO @master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
		SELECT 
			  gr.GUID, 5,[Order].[TYPE],
		      (CASE 
					WHEN @language <> 0 AND gr.LatinName <> ''
					THEN gr.LatinName 
				    ELSE gr.Name
			   END),			
			(CASE [Order].[TYPE] WHEN 4 THEN -1 ELSE 1 END) * (([item].Price * [item].Qty)-[item].Discount+[item].Added) +
			([item].Price * [item].Qty) * (ISNULL(DI.Extra,0)-ISNULL(DI.Discount,0))/(CASE BU.Total WHEN 0 THEN 1 ELSE BU.Total END ),
			us.LoginName, @NetSalesGuid
		FROM 
			RestOrder000 [Order] 
			INNER JOIN RestOrderItem000 [item] ON [item].ParentID = [Order].[Guid]
			INNER JOIN BillRel000 REL ON [Order].[Guid] = REL.ParentGUID
			INNER JOIN BU000 BU ON REL.BillGUID = BU.[GUID]
			INNER JOIN MT000 MT ON [item].MatID = mt.[GUID]
			INNER JOIN gr000 GR ON MT.GroupGUID = GR.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]	
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			OUTER Apply fnBill_GetDiSum(bu.GUID) di
	IF(@showMats = 1) 
		INSERT INTO
		    @master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
		SELECT 
			NEWID(), 6, [Order].[TYPE],
			            (CASE 
					    WHEN @language <> 0 AND MT.LatinName <> '' THEN Mt.LatinName 
					    ELSE Mt.Name
					    END),
			(CASE [Order].[TYPE] WHEN 4 THEN -1 ELSE 1 END) * (([item].Price * [item].Qty)-[item].Discount + [item].Added) +
			([item].Price * [item].Qty) * (ISNULL(DI.Extra,0)-ISNULL(DI.Discount,0))/(CASE BU.Total WHEN 0 THEN 1 ELSE BU.Total END ),
			us.LoginName,MT.GroupGUID
		FROM 
			RestOrder000 [Order] 
			INNER JOIN RestOrderItem000 [item] ON [item].ParentID = [Order].[Guid]
			INNER JOIN BillRel000 REL ON [Order].[Guid] = REL.ParentGUID
			INNER JOIN BU000 BU ON REL.BillGUID = BU.[GUID]
			INNER JOIN MT000 MT ON [item].MatID = mt.[GUID]
			INNER JOIN gr000 GR ON MT.GroupGUID = GR.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]	
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			OUTER Apply fnBill_GetDiSum(bu.GUID) di
	END
	ELSE
	BEGIN
		INSERT INTO
			 @master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
		
	    SELECT
			bt.GUID, 7, [Order].[TYPE],'',
			 ISNULL((CASE [Order].[TYPE]
			 WHEN 4 THEN -1 
			 ELSE 1 END ) * bu.Total, 0),
			us.LoginName,@NetSalesGuid
		FROM 
			RestOrder000 [Order]
			INNER JOIN BillRel000 rel  ON [ORDER].[Guid] = rel.ParentGUID
			INNER JOIN bu000 bu ON REL.BillGUID = bu.[GUID]
			INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID] 
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
		WHERE 
			bt.BillType = 1
		UNION all
	    SELECT 
			bt.GUID, 8,[Order].[TYPE], '',
			ISNULL((CASE [Order].[TYPE]
			 WHEN 4 THEN -1 
			 ELSE 1 END ) * bu.Total, 0),
			us.LoginName,@NetSalesGuid
		FROM 
			RestOrder000 [Order]
			INNER JOIN BillRel000 rel  ON [ORDER].[Guid] = rel.ParentGUID
			INNER JOIN bu000 bu ON REL.BillGUID = bu.[GUID]
			INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID] 
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
		WHERE
			 bt.BillType = 3 
		UNION all
		SELECT 
			NEWID(), 9,[Order].[TYPE], '',
			ISNULL(bu.TotalDisc, 0) ,
			us.LoginName,@NetSalesGuid
		FROM 
			RestOrder000 [Order]
			INNER JOIN BillRel000 rel  ON [ORDER].[Guid] = rel.ParentGUID
			INNER JOIN bu000 bu ON REL.BillGUID = bu.[GUID]
			INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID]
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]

		UNION all
		SELECT 
			NEWID(), 10,[Order].[TYPE], '',
			ISNULL(bu.TotalExtra, 0) - ISNULL([ORDER].DeliveringFees, 0) -ISNULL([Order].Tax, 0),
			us.LoginName,@NetSalesGuid
		FROM  
			RestOrder000 [Order]
			INNER JOIN BillRel000 rel  ON [ORDER].[Guid] = rel.ParentGUID
			INNER JOIN bu000 bu ON REL.BillGUID = bu.[GUID]
			INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID] 
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]

		UNION all
		SELECT 
			NEWID(), 11,[Order].[TYPE],'',
			ISNULL([ORDER].DeliveringFees, 0) ,
			us.LoginName,@NetSalesGuid
		FROM  
			RestOrder000 [Order]
			INNER JOIN BillRel000 rel  ON [ORDER].[Guid] = rel.ParentGUID
			INNER JOIN bu000 bu ON REL.BillGUID = bu.[GUID]
			INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID] 
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
	
		UNION all
		
		SELECT
			NEWID(),12,[Order].[TYPE],'',
			(CASE [Order].[TYPE] WHEN 4 THEN -1 ELSE 1 END ) * ISNULL([Order].Tax, 0) ,
			us.LoginName,@NetSalesGuid
		FROM 
			RestOrder000 [Order]
			INNER JOIN BillRel000 rel  ON [ORDER].[Guid] = rel.ParentGUID
			INNER JOIN bu000 bu ON REL.BillGUID = bu.[GUID]
			INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID] 
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]

			DECLARE @TaxGuid [uniqueidentifier]
			SELECT TOP (1)  @TaxGuid = ID 
			FROM @master
			WHERE [TYPE] = 12
	END
	IF(@showCurDetails = 1)
	BEGIN
			INSERT INTO 
				@master(ID, [Type],[OrderType], Note, FinalTotal, UserName, ParentID)
			SELECT 
				NEWID(),13,[Order].[TYPE],
				(CASE 
				WHEN @language <> 0 AND MY.LatinName <> '' THEN MY.LatinName 
				ELSE MY.Name
				END),
				ISNULL((CASE [Order].[TYPE] WHEN 4 THEN -1 ELSE 1 END ) * Cur.Paid, 0) ,us.LoginName,@CashGuid
			FROM
				RestOrder000 [Order] ​	
				INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
				INNER JOIN POSPaymentsPackageCurrency000 [Cur] ON [Pack].[Guid] = [Cur].ParentID​
				INNER JOIN my000 MY ON [Cur].CurrencyID = [My].[GUID]​
				INNER JOIN BillRel000 rel ON rel.ParentGUID = [Order].[GUID]
				INNER JOIN vwBu bu ON bu.buGUID = rel.BillGUID​
				INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
				INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
				
	END
	
	IF(@showChecksDetails = 1)
	BEGIN
	    INSERT INTO 
			@master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID,SortNum)
		SELECT
			NEWID(), 14,[Order].[TYPE],
			(CASE 
				WHEN @language <> 0 AND NT.LatinName <> '' 
					THEN NT.LatinName 
					ELSE NT.Name
			END),
			ISNULL((CASE REL.TYPE WHEN 1 THEN 1 ELSE -1 END) * CHK.Paid / (CASE CHK.CurrencyValue WHEN 0 THEN 1 ELSE CHK.CurrencyValue END), 0) , 
			US.LoginName,@CheckGuid,NT.sortNum
		FROM
			RestOrder000 [ORDER]​
			INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
			INNER JOIN POSPaymentsPackageCheck000 CHK ON [Pack].[Guid] = CHK.ParentID​
			INNER JOIN nt000 NT ON CHK.Type = NT.[GUID]​
			INNER JOIN BillRel000 rel ON rel.ParentGUID=[Order].GUID​
			INNER JOIN vwBu bu ON bu.buGUID = rel.BillGUID​
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.GUID
			INNER JOIN us000 US ON [ORDER].FinishCashierID = US.GUID​
			
	END
	IF(@showCreditPaymentsDetails = 1)
	BEGIN
		INSERT INTO 
						@master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID)
		SELECT 
						NEWID(), 15,[Order].[TYPE],
						(CASE 
							  WHEN @language <> 0 AND ACC.LatinName <> '' 
							  THEN ACC.LatinName 
							  ELSE ACC.Name
					    END), 
						ISNULL(PACK.DeferredAmount, 0) ,
						US.LoginName,@CreditPaymentGuid
		FROM 
				RestOrder000 [Order] ​
				INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
				INNER JOIN cu000 [Cu] ON [Pack].[DeferredAccount] = [Cu].[GUID]​
				INNER JOIN ac000 [Acc] ON [Cu].[AccountGUID] = [Acc].[GUID]​
				INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.GUID
				INNER JOIN us000 US ON [ORDER].FinishCashierID = US.GUID​
		WHERE  
				PACK.DeferredAmount != 0
	END

	IF(@showTaxDetails = 1)
	BEGIN 
		INSERT INTO 
						@master (ID, [Type], [OrderType], Note, FinalTotal, UserName, ParentID, SortNum)
		SELECT 
						NEWID(), 16, [Order].[TYPE],
						Tax.Name,
						(CASE [Order].[TYPE] WHEN 4 THEN -1 ELSE 1 END ) * ISNULL(VTax.CalculatedValue, 0) ,
						US.LoginName, @TaxGuid, Tax.Number
		FROM 
				RestOrder000 [Order] ​
				INNER JOIN RestDiscTax000 VTax ON  [Order].[Guid] = VTax.ParentID
				INNER JOIN RestTaxes000 Tax ON VTax.ParentTaxID = Tax.Guid  
				INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.GUID
				INNER JOIN us000 US ON [ORDER].FinishCashierID = US.GUID​
	

	END
	
	SELECT 
			ID,
			[Note] AS [Note],
			[OrderType]  AS OrderType,
			[Type] AS [Type],
			ISNULL(FinalTotal,0) AS Total,
			UserName AS CashierName ,
			PARENTID
	FROM @master 
	ORDER BY [Type],[SortNum]
#################################################################################
#END
