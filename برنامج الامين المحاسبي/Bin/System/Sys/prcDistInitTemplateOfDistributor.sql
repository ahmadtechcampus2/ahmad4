####################################################
###### prcDistInitTemplateOfDistributor
CREATE PROCEDURE prcDistInitTemplateOfDistributor
		@DistributorGUID uniqueidentifier
AS     
	SET NOCOUNT ON     
	----------------------------------------------
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	-----------------------------------------------
	DELETE DistDeviceBt000 WHERE DistributorGUID = @DistributorGUID
	DELETE DistDeviceSalesTax000 WHERE DistributorGUID = @DistributorGUID
	DELETE DistDeviceEt000 WHERE DistributorGUID = @DistributorGUID
	DELETE DistDeviceTt000 WHERE DistributorGUID = @DistributorGUID
	-----------------------------------------------
	INSERT INTO  DistDeviceBt000
	(
			[btGUID],
			[DistributorGUID],
			[SortNum],
			[Name],
			[LatinName],
			[Abbrev],
			[BillType],
			[DefPrice],
			[bIsInput],
			[bIsOutput],
			[bNoEntry],
			[bNoPost],
			[bPrintReceipt],
			[Type],
			[StoreGUID],
			[VATSystem],
			[UseSalesTax],
			[CalcTaxBeforeDiscount],
			[CalcTaxBeforeExtra],
			[ApplyTaxOnGifts],
			[IncludeTTCDiffOnSales],
			[PayTerms],
			[PayTermsDays],
			[CalcTotalDiscRegardlessItemDisc],
			[CalcTotalExtraRegardlessItemExtra],
			[IsStopDate],
			[StopDate]
	)
	SELECT  
			[vwBt].[btGUID],
			@DistributorGUID,
			[vwBt].[btSortNum],
			[vwBt].[btName],
			[vwBt].[btLatinName],
			[vwBt].[btAbbrev],
			[vwBt].[btBillType],
			CASE [vwBt].[btDefPrice]	
				WHEN 4		THEN 1		-- Whole Price		الجملة
				WHEN 8		THEN 2		-- Half Price		نصف الجملة
				WHEN 16		THEN 4		-- Export Price		التصدير
				WHEN 32		THEN 3		-- Vendor Price		الموزع
				WHEN 64		THEN 5		-- Retail Price		المفرق
				WHEN 128	THEN 6		-- EndUser Price	المستهلك
				WHEN 2048	THEN 2048	-- CustPrice		سعر بطاقة الزبون
				WHEN 1024	THEN 1024   -- LastPrice		سعر  اخر مبيع
				WHEN 1	    THEN 0      -- Without  
				ELSE 1	-- Whole Price
			END,
			[vwBt].[btIsInput],
			[vwBt].[btIsOutput],
			[vwBt].[btNoEntry],
			[vwBt].[btNoPost],
			[vwBt].[btPrintReceipt],
			[vwBt].[btType],
			[vwBt].[btDefStore],
			CASE @IsGCCEnabled WHEN 1 THEN 1 ELSE [vwBt].[btVatSystem] END,
			[vwBt].[btUseSalesTax],
			[vwBt].[btTaxBeforeDiscount],
			[vwBt].[btTaxBeforeExtra],
			[vwBt].[isApplyTaxOnGifts],
			[vwBt].[btIncludeTTCDiffOnSales],
			ISNULL([bt].[bPayTerms], 0),
			ISNULL([pt].[Days], 0),
			[vwBt].TotalDiscRegardlessItemDisc,
			[vwBt].TotalExtraRegardlessItemExtra,
			[vwBt].IsStopDate,
			[vwBt].StopDate
	FROM         
		vwBt 
		INNER JOIN DistDD000 dd ON vwBt.btGUID = dd.ObjectGUID
		INNER JOIN bt000 bt ON bt.Guid = vwBt.btGuid
		LEFT  JOIN pt000 pt ON pt.RefGuid = vwBt.btGuid AND pt.Type = 1 AND pt.Term = 2 -- أيام استحقاق الفواتير
	WHERE                 
		vwBt.btType IN (1, 5)
		AND dd.ObjectType = 1
		AND dd.DistributorGUID = @DistributorGUID
		
	INSERT INTO DistDeviceBt000
	(
		[btGUID],
		[DistributorGUID],
		[SortNum],
		[Name],
		[LatinName],
		[Abbrev],
		[BillType],
		[DefPrice],
		[bIsInput],
		[bIsOutput],
		[bNoEntry],
		[bNoPost],
		[bPrintReceipt],
		[Type],
		[StoreGUID],
		[VATSystem],
		[UseSalesTax],
		[CalcTaxBeforeDiscount],
		[CalcTaxBeforeExtra],
		[ApplyTaxOnGifts],
		[IncludeTTCDiffOnSales],
		[CalcTotalDiscRegardlessItemDisc],
		[CalcTotalExtraRegardlessItemExtra],
		[IsStopDate],
		[StopDate]
	)
	SELECT  
		[bt].[btGUID],
		@DistributorGUID,
		[bt].[btSortNum],
		[bt].[btName],
		[bt].[btLatinName],
		[bt].[btAbbrev],
		[bt].[btBillType],
		CASE [bt].[btDefPrice]	WHEN 4		THEN 1		-- Whole Price		الجملة
								WHEN 8		THEN 2		-- Half Price		نصف الجملة
								WHEN 16		THEN 4		-- Export Price		التصدير
								WHEN 32		THEN 3		-- Vendor Price		الموزع
								WHEN 64		THEN 5		-- Retail Price		المفرق
								WHEN 128	THEN 6		-- EndUser Price	المستهلك
								WHEN 2048	THEN 2048	-- CustPrice		سعر بطاقة الزبون
								ELSE 1	-- Whole Price
		END,
		[bt].[btIsInput],
		[bt].[btIsOutput],
		[bt].[btNoEntry],
		[bt].[btNoPost],
		[bt].[btPrintReceipt],
		[bt].[btType],
		[bt].[btDefStore],
		[bt].[btVatSystem],
		[bt].[btUseSalesTax],
		[bt].[btTaxBeforeDiscount],
		[bt].[btTaxBeforeExtra],
		[bt].[isApplyTaxOnGifts],
		[bt].[btIncludeTTCDiffOnSales],
		[bt].TotalDiscRegardlessItemDisc,
		[bt].TotalExtraRegardlessItemExtra,
		[bt].IsStopDate,
		[bt].StopDate
	FROM         
		DistDD000 AS dd
		INNER JOIN tt000 AS tt ON dd.ObjectGuid = tt.Guid
		INNER JOIN vwbt AS bt On bt.btGuid = tt.OutTypeGUID 
	WHERE                 
		bt.btType <>  1 	 AND  
		dd.ObjectType = 4	 AND
		dd.DistributorGUID = @DistributorGUID
	-----------------------------------------------
	INSERT INTO  DistDeviceSalesTax000
	(
		[GUID],
		[DistributorGUID],
		[SortNum],
		[BillTypeGuid],
		[Name],
		[ValueType],
		[Value],
		[AccountGuid],
		[TaxType]
	)
	SELECT  
		[st].[GUID],
		@DistributorGUID,
		[st].[Number],
		[st].[BillTypeGuid],
		[st].[Name],
		[st].[ValueType],
		[st].[Value],
		[st].[AccountGuid],
		[st].[TaxType]
	FROM         
		SalesTax000 AS st 
		INNER JOIN DistDeviceBt000 AS bt ON st.BillTypeGuid = bt.btGUID
	WHERE                 
		bt.DistributorGUID = @DistributorGUID
	-----------------------------------------------
	INSERT INTO  DistDeviceEt000
	(
		[etGUID],
		[DistributorGUID],
		[SortNum],
		[Name],
		[Abbrev],
		[EntryType],
		[FldDebit],
		[FldCredit],
		LatinName,
		IsStopDate,
		StopDate
	)
	SELECT  
		[et].[etGUID],
		@DistributorGUID,
		0,
		[et].[etName],
		[et].[etAbbrev],
		[et].[etEntryType],
		[et].[etFldDebit],
		[et].[etFldCredit],
		et.etLatinName,
		EtTable.IsStopDate,
		EtTable.StopDate
	FROM         
		vwet AS et 
		INNER JOIN DistDD000 AS dd ON et.etGUID = dd.ObjectGUID
		INNER JOIN et000 AS EtTable ON EtTable.guid = et.etGUID
	WHERE                 
		et.etEntryType =  0 AND  
		dd.ObjectType = 2 AND
		dd.DistributorGUID = @DistributorGUID
	-----------------------------------------------
	INSERT INTO  DistDeviceTT000
	(
		[ttGUID],
		[InTypeGUID],
		[OutTypeGUID],
		[Name],
		[DistributorGUID]
	)
	SELECT  
		tt.Guid,
		tt.InTypeGuid,
		tt.OutTypeGuid,
		RIGHT([bt].[name], LEN([bt].[Name])-3) AS ttName,
		@DistributorGUID
	FROM         
		tt000 AS tt
		INNER JOIN [bt000] AS bt ON [tt].[OutTypeGuid] = [bt].[Guid]		
		INNER JOIN DistDD000 AS dd ON tt.GUID = dd.ObjectGUID
	WHERE                 
		dd.ObjectType = 4 AND
		dd.DistributorGUID = @DistributorGUID
	
####################################################
CREATE FUNCTION fnIsCustomerHasDuePayments(@CustomerGuid UNIQUEIDENTIFIER)
RETURNS BIT
AS
BEGIN
    IF ISNULL(@CustomerGuid, 0x) = 0x
		RETURN 0;

    IF EXISTS(
		SELECT 
			  bu.[Guid]
		FROM
			  bu000 bu
			  INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
			  INNER JOIN pt000 pt ON pt.RefGUID = bu.[Guid]
			  LEFT JOIN er000 er ON er.ParentGUID = bu.[GUID]
			  INNER JOIN ce000 ce ON ce.[Guid] = entryGuid
			  INNER JOIN en000 en ON en.parentguid = ce.GUID
			  LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID, ParentDebitGuid FROM bp000 GROUP BY DebtGUID,ParentDebitGuid) bp ON bp.DebtGUID = bu.GUID OR bp.ParentDebitGuid = bu.GUID
			  INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
			  INNER JOIN cu000 cu ON ac.GUID = cu.AccountGUID
		WHERE 
			  bu.CustGUID = @CustomerGuid
			  AND bt.bIsOutput > 0 
			  AND bu.PayType = 1 
			  AND bu.IsPosted > 0
			  AND bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - ISNULL(bp.Val,0) > 0.9
			  AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())
		UNION ALL 
		SELECT -- لمعالجة الاستحقاقات في ملف مدور وتفعيل خيار استحقاق الفواتير اثناء التدوير
			  ce.[Guid]
		FROM 
			  ce000 AS ce
			  INNER JOIN pt000 pt ON pt.RefGUID = ce.[Guid]
			  LEFT JOIN er000 er ON er.ParentGUID = ce.[Guid]
			  INNER JOIN ce000 ce1 ON ce1.[Guid] = entryGuid
			  INNER JOIN en000 en ON en.parentguid = ce1.GUID
			  LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID FROM bp000 GROUP BY DebtGUID) bp ON bp.DebtGUID = en.GUID
			  INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
			  INNER JOIN cu000 cu ON ac.GUID = cu.AccountGUID AND cu.GUID = @CustomerGuid
		WHERE
			  en.Debit - ISNULL(bp.Val,0) > 0.9
			  AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())
         )
         RETURN 1;
      ELSE
		RETURN 0;
             
	RETURN 0;
END
####################################################
CREATE FUNCTION fnGetCustomerDuePayments (@CustomerGuid UNIQUEIDENTIFIER)
RETURNS float
AS
BEGIN
	-- Declare the return variable here
		RETURN (SELECT ISNULL(SUM(ISNULL(DUE, 0)), 0) DUE FROM
       (SELECT 
                       SUM(bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - ISNULL(bp.Val,0)) DUE
              FROM
                       bu000 bu
                       INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
                       INNER JOIN pt000 pt ON pt.RefGUID = bu.[Guid]
                       LEFT JOIN er000 er ON er.ParentGUID = bu.[GUID]
                       INNER JOIN ce000 ce ON ce.[Guid] = entryGuid
                       INNER JOIN en000 en ON en.parentguid = ce.GUID
                       LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID, ParentDebitGuid FROM bp000 GROUP BY DebtGUID,ParentDebitGuid) bp ON bp.DebtGUID = bu.GUID OR bp.ParentDebitGuid = bu.GUID
                       INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
                       INNER JOIN cu000 cu ON ac.GUID = cu.AccountGUID
              WHERE 
                       bu.CustGUID = @CustomerGuid
                       AND bt.bIsOutput > 0 
                       AND bu.PayType = 1 
                       AND bu.IsPosted > 0
                       AND bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - ISNULL(bp.Val,0) > 0.9
                       AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())
              UNION ALL 
              SELECT 
                       SUM(en.Debit - ISNULL(bp.Val,0)) DUE
              FROM 
                       ce000 AS ce
                       INNER JOIN pt000 pt ON pt.RefGUID = ce.[Guid]
                       LEFT JOIN er000 er ON er.ParentGUID = ce.[Guid]
                       INNER JOIN ce000 ce1 ON ce1.[Guid] = entryGuid
                       INNER JOIN en000 en ON en.parentguid = ce1.GUID
                       LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID FROM bp000 GROUP BY DebtGUID) bp ON bp.DebtGUID = en.GUID
                       INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
                       INNER JOIN cu000 cu ON ac.GUID = cu.AccountGUID AND cu.GUID = @CustomerGuid
              WHERE
			   en.Debit - ISNULL(bp.Val,0) > 0.9
               AND  dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())) D)

END
####################################################
#END