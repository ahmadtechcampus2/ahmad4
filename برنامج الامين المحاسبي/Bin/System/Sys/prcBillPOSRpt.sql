################################################################################
CREATE PROC prcGetBillsItems
	@StartDate [datetime], 
	@EndDate [datetime], 
	@BillType [uniqueidentifier], 
	@BillNumber [int], 
	@BillNumber2 [int]
AS 
SET NOCOUNT ON 

DECLARE @temp table 
( 
	[GUID] [UNIQUEIDENTIFIER],
	[PaymentsPackageID] [UNIQUEIDENTIFIER],
	[Direction]  [INT]
) 
	 

INSERT @temp 
	SELECT 
		bu.GUID ,  o.PaymentsPackageID , IIF( SubTotal >= 0 , 1 , -1)  
	FROM
		bu000 bu
		INNER JOIN billrel000 rel ON rel.billguid=bu.guid	
		INNER JOIN POSOrder000 o on rel.ParentGUID=o.GUID
	WHERE (bu.[date] between @StartDate and  @EndDate) 
		AND (	(  @BillNumber2 > 0  AND  bu.number >= @BillNumber and bu.number <= @BillNumber2 )
				OR  ( @BillNumber2 <= 0 AND bu.number = 
						( CASE WHEN @BillNumber > 0 
							   THEN @BillNumber 
							   ELSE bu.number 
						  END  
						) 
					)
			)
	AND dbo.fnGetUserBillSec_Browse([dbo].[fnGetCurrentUserGUID](), bu.typeguid) > 0
	AND EXISTS ( SELECT 1 FROM RepSrcs WHERE @BillType=IdTbl AND IdType = bu.typeguid)

	
SELECT 
		bu.Number AS BillNumber,  
		bu.Guid AS BillGuid, 
		bt.GUID as BillType, 
		bu.Date AS [BillDate], 
		isnull(bt.abbrev, '') AS [Abbrev],
		isnull(bt.LatinAbbrev, '') AS [LatinAbbrev], 
		bu.PayType as [BillPayType],
		isnull(bu.Cust_Name, '') as [BillCust],
		bu.Total / bu.CurrencyVal as [BillTotal],
		(bu.Total + bu.TotalExtra +  bu.VAT - bu.TotalDisc)  / bu.CurrencyVal as [FinalTotal],	
		isnull(bu.Notes, '') as [BuNotes],
		isnull(bu.totaldisc / bu.CurrencyVal, 0)  as [Discount],
	    isnull(bu.totalextra / bu.CurrencyVal, 0) as [EXTRA],
		CASE WHEN bu.CurrencyVal > 0 THEN bu.vat / bu.CurrencyVal ELSE 0 END [VAT],
		bt.vatsystem [VATsystem],
		bu.CurrencyVal,
		my.code AS CurrencyCode
from bu000 bu  
		INNER JOIN my000 my ON my.GUID = bu.CurrencyGUID
		inner join bt000 bt on bt.guid=bu.typeguid
WHERE EXISTS ( SELECT 1 FROM @temp t WHERE  t.guid = bu.guid )
ORDER BY bt.BillType , BillNumber

--Fetch Order Items
select
		bi.biGuid AS [BiGuid],
		bimatptr as [MtGuid],
		isnull(mtname, '') as [MtName],
		isnull(mtLatinName, '') as [MtLatinName],
		bibillQty as [MtQty],
		biPrice/biCurrencyVal as [MtPrice],
		(bibillQty*biPrice)/biCurrencyVal as [MtTotal], 
		mtUnityName AS MtUnit,
		buCurrencyVal,
		bi.buguid AS [BillGuid], 
		ISNULL(SN,'') AS [SN]
from vwExtended_bi bi
LEFT JOIN snt000 snt ON  snt.biGUID = bi.biGUID
LEFT JOIN snc000 snc ON snc.GUID = snt.ParentGUID
WHERE EXISTS ( SELECT 1 FROM @temp t WHERE  t.guid = bi.buguid )
--ORDER BY  bu.Number

------------------------------------------------------------------------------------------------------------------------
SELECT Pay.* , bt.BillType AS [TypeNum]  , (bu.Total + bu.TotalExtra +  bu.VAT - bu.TotalDisc) as [BillTotal]
INTO #Pay
FROM  (
SELECT
		t.guid as BillGuid,
		cur.Code as [PayName],
		cur.Paid as [PayTotal],
		cur.Returned as [RetAmmount],
		[Direction],
		'' as [PayAcc1],
		2 AS [fieldOrder]
from @temp t 
		CROSS APPLY ( SELECT  Code , SUM(Paid) AS [Paid] , SUM(Returned) AS [Returned]
					 FROM POSPaymentsPackageCurrency000 cur
					 WHERE  t.PaymentsPackageID = cur.ParentID 
					 GROUP BY Code 
				   ) cur 
--Checks
UNION ALL
(
SELECT
		t.guid as BillGuid,
		[PayName],
		[PayTotal],
		0 as [RetAmmount],
		[Direction]   ,
		ac.Code + '-' + ac.Name as [PayAcc1],
		3 AS [fieldOrder]
from @temp t 
		CROSS APPLY (
			SELECT ch.DebitAccID , ch.name AS [PayName] , SUM(( ch.paid * IIF (NewVoucher = 1 , -1 , 1 ) ) / ch.CurrencyValue  )    AS [PayTotal] 
			FROM POSPaymentsPackage000 pack
			INNER JOIN POSPaymentsPackageCheck000 ch ON ch.ParentID = pack.Guid 
			WHERE  t.PaymentsPackageID = pack.Guid 
			GROUP BY ch.DebitAccID , ch.name 
			UNION ALL 
			SELECT nt.DefRecAccGUID , nt.Name AS [PayName] , SUM ( (ReturnVoucherValue ) / ch.CurrencyVal  )    AS [PayTotal] 
			FROM POSPaymentsPackage000 pack
			INNER JOIN ch000 ch ON ch.GUID = ReturnVoucherID
			INNER JOIN nt000 nt ON nt.GUID = ch.TypeGUID
			WHERE  t.PaymentsPackageID = pack.Guid 
			GROUP BY nt.DefRecAccGUID  , nt.Name  
		) ch
		LEFT JOIN ac000 ac ON ch.DebitAccID = ac.GUID
)
--Deffered
UNION ALL
(
SELECT
		t.guid as BillGuid,
		'Deffered' as [PayName],
		pack.DeferredAmount / bu.CurrencyVal as [PayTotal],
		0 as [RetAmmount],
		[Direction],
		ac.Name as [PayAcc1],
		4 AS [fieldOrder]
from bu000 bu 
		INNER JOIN @temp t ON  t.guid = bu.guid 
		INNER JOIN POSPaymentsPackage000 pack ON t.PaymentsPackageID = pack.Guid
		INNER JOIN cu000 cu ON pack.DeferredAccount = cu.GUID
		LEFT JOIN ac000 ac ON cu.AccountGUID = ac.GUID
) ) Pay
INNER JOIN bu000 bu ON Pay.BillGuid = bu.GUID
INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID


SELECT  BillGuid , PayName , SUM(PayTotal) AS [PayTotal] , SUM(RetAmmount) AS [RetAmmount] , PayAcc1
FROM #Pay
WHERE (Direction = 1  AND TypeNum = 1) OR (Direction = -1  AND TypeNum = 3)
GROUP BY BillGuid , PayName , PayAcc1


SELECT 0 AS [orderFld] , SUM(BillTotal) AS Total , IIF ( TypeNum = 1 , 'Sales' , 'Return' ) AS [Name] FROM (
		SELECT   BillTotal  , TypeNum  
		FROM #Pay
		GROUP BY  TypeNum , BillGuid , BillTotal 
) t
GROUP BY TypeNum
UNION ALL
SELECT 1 , SUM(IIF( TypeNum = 1 , 1 , -1 ) * BillTotal) AS BillTotal  , 'Total' FROM (
		SELECT   BillTotal  , TypeNum  
		FROM #Pay
		GROUP BY  TypeNum , BillGuid , BillTotal 
) t
UNION ALL 
(
SELECT fieldOrder   , SUM( IIF(fieldOrder = 3, Direction, 1) * (PayTotal - RetAmmount) )  , [PayName]
		FROM #Pay
		WHERE (Direction = 1  AND TypeNum = 1) OR (Direction = -1  AND TypeNum = 3)
		GROUP BY PayName , fieldOrder
) 
	

################################################################################
CREATE PROCEDURE prcPOSDrawerDetials
	@id UNIQUEIDENTIFIER
	,@start DATETIME
	,@end DATETIME
	,@userid UNIQUEIDENTIFIER
AS
SET NOCOUNT ON
Declare @language INT= [dbo].[fnConnections_getLanguage]();
CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpostedSecurity] [INTEGER]) 
                
INSERT INTO [#BillsTypesTbl] EXEC prcGetBillsTypesList2 0x0 
CREATE TABLE [#Result]
(
	[enDate]		[DATETIME],
	[Debit]			[FLOAT],
	[Credit]		[FLOAT],
	[CurrencyCode] NVARCHAR(100),
	[CurrencyValue] [FLOAT],
	[Discount]		[FLOAT],
	[extra]			[FLOAT],
	[Notes]			NVARCHAR(1000),
	[name]			NVARCHAR(1000),
	[entryGuid]		[UNIQUEIDENTIFIER],
	[buGuid]		[UNIQUEIDENTIFIER],
	[CeNumber]		[INT],
	[buType]		[UNIQUEIDENTIFIER],
	[UserSecurity]	INT,
	[ceGuid]		[UNIQUEIDENTIFIER],
	[custGuid]		[UNIQUEIDENTIFIER],
	[ceSecurity]	INT,
	[Security]	INT,
	[pySecurity]	INT,
	[OpenTime]	NVARCHAR(9)
)
INSERT INTO #Result
SELECT 
	ce.ceCreateDate,
	en.Debit, 
	en.Credit,
	my.Code,
	en.CurrencyVal ,
	ISNull(bu.buTotalDisc, 0),
	ISNull(bu.buTotalExtra,0),
	en.Notes,
	CASE @language WHEN 0 THEN ISNULL(bt.btName, '') ELSE ISNULL(bt.btLatinName, '') END,
	ce.[ceGUID],
	ISNULL(bu.buGUID, 0x0),
	ce.cenumber,
	bu.buType,
    CASE bu.buIsPosted WHEN 1 THEN bttbl.UserSecurity ELSE bttbl.UnpostedSecurity END,
	ce.[ceGuid],
	ISNUll(bu.[buCustAcc], en.[AccountGUID]),
	ISNULL(ce.[ceSecurity], 0),
	ISNULL(bu.buSecurity, 0),
	ISNULL(CAST(py.pySecurity AS INT), 0),
	CONVERT(nvarchar(9),  ceCreateDate , 108)
FROM 
		en000 en
		LEFT JOIN my000 my ON my.GUID = en.CurrencyGUID
		LEFT JOIN vwCe ce On en.ParentGuid=ce.ceGUID 
		LEFT JOIN er000 er On er.EntryGuid=ce.ceGUID
		LEFT JOIN vwbu bu On er.parentGuid = bu.buGUID
		LEFT JOIN vwBt bt On bu.buType = bt.btGUID
		LEFT JOIN vwpy py on er.parentGuid = py.pyGUID
		LEFT JOIN #BillsTypesTbl bttbl on bttbl.TypeGuid = bu.buType

WHERE   ( ( @id  = 0x0 AND EXISTS( SELECT 1 FROM POSCurrencyItem000 cur 
									WHERE  cur.CashAccID = en.AccountGUID  )) 
			OR en.AccountGUID=@id ) 
		AND ce.ceCreateDate between @start AND @end 
		AND (dbo.fnGetUserEntrySec_Browse(dbo.fnGetCurrentUserGUID(), py.pyTypeGUID) >= pySecurity OR py.pyTypeGUID IS NULL)
		AND ce.ceCreateUserGUID = @userid
EXEC [prcCheckSecurity]
-- detailed result:
SELECT * FROM #Result
ORDER BY CeNumber
-- master result:
SELECT 
	SUM(Debit/CurrencyValue) AS [Debit],
	SUM(Credit/CurrencyValue) AS [Credit],
	SUM(Debit/CurrencyValue) - SUM(Credit/CurrencyValue) AS [Balance],
	CurrencyCode
FROM #Result
GROUP BY CurrencyCode
################################################################################
CREATE PROCEDURE prcPOSGenerateTransferBills
	@orderGuid [UNIQUEIDENTIFIER],
    @configGuid  [UNIQUEIDENTIFIER],	
	@reverse [BIT],
	@payment [FLOAT],
	@Notes [NVARCHAR](250) = '',
	@test int = 0
As
SET NOCOUNT ON
DECLARE	@currencyID [UNIQUEIDENTIFIER],
	@inBillTypeID [UNIQUEIDENTIFIER],
	@inBillID [UNIQUEIDENTIFIER],
	@outBillTypeID [UNIQUEIDENTIFIER],
	@outBillID [UNIQUEIDENTIFIER],
	@StoreID [UNIQUEIDENTIFIER],
	@tempStoreID [UNIQUEIDENTIFIER],
	@currencyValue [FLOAT],
	@Result [bit],
	@CreditGuid [UNIQUEIDENTIFIER],
	@DebitGuid [UNIQUEIDENTIFIER],
	@BranchGuid [UNIQUEIDENTIFIER],
	@Number [FLOAT],
	@EntryTypeID [UNIQUEIDENTIFIER],
	@EntryType [INT],
	@Guid  [UNIQUEIDENTIFIER],
	@PaymentGuid  [UNIQUEIDENTIFIER],
	@CurrentDate [DATETIME],
	@UserGuid [UNIQUEIDENTIFIER],
	@deferredAccount [UNIQUEIDENTIFIER],
	@EnDebitGuid [UNIQUEIDENTIFIER],
	@EnCreditGuid [UNIQUEIDENTIFIER] 

	
	SELECT @BranchGuid = BranchID,
			@EntryType = 4,
		@UserGuid = CashierID	FROM [POSOrder000]	WHERE [Guid] = @orderGuid

	SELECT 
		@inBillTypeID = CASE WHEN Name='AmnPOS_TransferType' THEN CAST(value as uniqueidentifier) ELSE @inBillTypeID END,
		@StoreID = CASE WHEN Name='AmnPOS_ReserveStore' THEN CAST(value as uniqueidentifier) ELSE @StoreID END,
		@EntryTypeID = CASE WHEN Name='AmnPOS_EarnestReceiveEntryID' AND @reverse=0 THEN CAST(value as uniqueidentifier) ELSE @EntryTypeID END,
		@EntryTypeID = CASE WHEN Name='AmnPOS_EarnestRetrieveEntryID' AND @reverse=1 THEN CAST(value as uniqueidentifier) ELSE @EntryTypeID END,
		@CreditGuid = CASE WHEN Name='AmnPOS_EarnestAccID' AND @reverse=0 THEN CAST(value as uniqueidentifier) ELSE @CreditGuid END,
		@DebitGuid = CASE WHEN Name='AmnPOS_EarnestAccID' AND @reverse=1 THEN CAST(value as uniqueidentifier) ELSE @DebitGuid END
	from UserOp000 
	where UserID=@UserGuid
	
	SELECT TOP 1 @currencyID= ISNULL([Value], 0x0) FROM FileOP000 
    WHERE [Name] = 'AmnPOS_DefaultCurrencyID'

	IF ISNULL(@currencyID,0X0) = 0X0
	BEGIN
		SELECT TOP 1 @currencyID = ISNULL([Value], 0x0) 
		FROM [OP000] WHERE [Name] = 'AmnCfg_DefaultCurrency'

		SELECT @currencyValue = ISNULL([CurrencyVal], 0) 
		FROM [MY000] WHERE [Guid] = @currencyID
	END

	ELSE
		SET @currencyValue = dbo.fnGetCurVal(@currencyID,GetDate())	

	SELECT @CreditGuid = ISNULL(@CreditGuid, CashAccID),
		@DebitGuid = ISNULL(@DebitGuid, CashAccID)
	FROM POSCurrencyItem000 
	WHERE UserID = @UserGuid AND CurID = @currencyID  

	SELECT @outBillTypeID = outtypeguid from tt000 where intypeguid=@inBillTypeID
	
	IF @reverse=0
	BEGIN
	  SELECT 
           @tempStoreID = ISNULL([DefStoreGUID], 0x0)
	  FROM [BT000] bt WHERE [Guid] = @outBillTypeID
	  SELECT 
          @StoreID = ISNULL([DefStoreGUID], 0x0)
	  FROM [BT000] bt WHERE [Guid] = @inBillTypeID
	  
	  SELECT @deferredAccount = [dbo].fnGetDAcc([DefCashAccGUID])
        FROM [BT000]
      WHERE [Guid] = @outBillTypeID	

	  EXEC @Result = prcPOSGenerateSalesBill @orderGuid, @configGuid, 0, @deferredAccount, 0x0, @currencyID, @currencyValue, @outBillTypeID, @tempStoreID, 0x0

	  SELECT @deferredAccount = [dbo].fnGetDAcc([DefCashAccGUID])
        FROM [BT000]
      WHERE [Guid] = @inBillTypeID	

	  EXEC @Result = prcPOSGenerateSalesBill @orderGuid, @configGuid, 0, @deferredAccount, 0x0, @currencyID, @currencyValue, @inBillTypeID, @StoreID, 0x0 
	END ELSE
	BEGIN
	  SELECT 
           @tempStoreID = ISNULL([DefStoreGUID], 0x0)
	  FROM [BT000] bt WHERE [Guid] = @outBillTypeID

 	  SELECT 
          @StoreID = ISNULL([DefStoreGUID], 0x0)
	  FROM [BT000] bt WHERE [Guid] = @inBillTypeID

	  SELECT @deferredAccount = [dbo].fnGetDAcc([DefCashAccGUID])
        FROM [BT000]
      WHERE [Guid] = @outBillTypeID	

	  EXEC @Result = prcPOSGenerateSalesBill @orderGuid, @configGuid, 0, 0x0, 0x0, @currencyID, @currencyValue, @outBillTypeID,@StoreID, 0x0

	  SELECT @deferredAccount = [dbo].fnGetDAcc([DefCashAccGUID])
        FROM [BT000]
      WHERE [Guid] = @inBillTypeID	

	  EXEC @Result = prcPOSGenerateSalesBill @orderGuid, @configGuid, 0, 0x0, 0x0, @currencyID, @currencyValue, @inBillTypeID, @tempStoreID, 0x0
	END

	IF @Result = 0
		return -5
	
	SELECT 
           @inBillID = ISNULL([GUID], 0x0)
	FROM [Bu000] bu WHERE [Number] = (SELECT MAX(NUMBER) from bu000 where typeguid=@inBillTypeID) and typeguid=@inBillTypeID

	SELECT 
           @outBillID = ISNULL([GUID], 0x0)
	FROM [Bu000] bu WHERE [Number] = (SELECT MAX(NUMBER) from bu000 where typeguid=@outBillTypeID) and typeguid=@outBillTypeID

	insert into ts000 ([GUID],[OutBillGUID],[InBillGUID]) values(newID(), @outBillID, @inBillID)
	
	if ISNULL(@payment,-1) < 1
		return 1
	
	Set @Guid = newid()
	SET @EnDebitGuid  = newid()
	SET @EnCreditGuid = newid()
	Set @CurrentDate = GetDate()
	Select @Number=ISNULL(Max(Number),0)+1 From Ce000

	INSERT INTO CE000([Type], [Number], [Date], [PostDate], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [State], [Security],	[Branch], [Guid], [CurrencyGuid], [TypeGuid]) 
						VALUES
					(@EntryType, @Number, @CurrentDate, @CurrentDate, @payment, @payment,	@Notes,	@CurrencyValue,	0, 0, 1, @BranchGuid, @Guid, @CurrencyID, @EntryTypeID)	

	INSERT INTO [en000]	( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Num1], [Num2], [Vendor], [SalesMan], [GUID], [ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID]) 
			VALUES 
		(1,	@CurrentDate, @Payment, 0, '', @CurrencyValue, '', 0, 0, 0, 0, @EnDebitGuid,	@GUID, @DebitGUID, @CurrencyID, 0x0, @CreditGuid)

	INSERT INTO [en000] ( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Num1],	[Num2],	[Vendor], [SalesMan], [GUID], [ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID]) 
					VALUES 
				(1, @CurrentDate, 0, @payment, '', @CurrencyValue, '', 0, 0, 0, 0, @EnCreditGuid,	@GUID, @CreditGuid,	@CurrencyID, 0x0, @DebitGUID)

	Set @PaymentGuid = newID()
	Select @Number=ISNULL(Max(Number),0)+1 From py000 WHERE TypeGUID = @EntryTypeID

	INSERT INTO py000(Number, [Date], Notes, CurrencyVal, [Security], [Guid], TypeGuid, AccountGuid, CurrencyGuid, BranchGuid)
			Values
		(@Number,@CurrentDate,@Notes,@CurrencyValue,1,@PaymentGuid,	@EntryTypeID,CASE WHEN @reverse=0 THEN @DebitGuid ELSE @CreditGuid END,	@CurrencyID,@BranchGuid)

	
	INSERT INTO er000 ([GUID],EntryGUID,ParentGUID,ParentType,ParentNumber) VALUES (newid(), @Guid, @paymentGuid, @EntryType, @Number)
	UPDATE CE000 SET IsPosted=1 WHERE GUID=@Guid

	--Procedure for send message to users and customer 
	--where insert or modify entry
	EXEC NSPrcObjectEvent @EnDebitGuid,  3, 0
	EXEC NSPrcObjectEvent @EnCreditGuid, 3, 0


	return 1
################################################################################
CREATE TRIGGER trgPaymentsPackage_Delete ON pospaymentspackage000 FOR DELETE
	NOT FOR REPLICATION
AS
	SET NOCOUNT ON 
	
	DELETE cu
	FROM 
		POSPaymentsPackageCurrency000 cu 
		INNER JOIN DELETED d ON d.GUID = cu.ParentID

	DELETE ch
	FROM 
		POSPaymentsPackageCheck000 ch 
		INNER JOIN DELETED d ON d.GUID = ch.ParentID

	DELETE po
	FROM 
		POSPaymentsPackagePoints000 po 
		INNER JOIN DELETED d ON d.GUID = po.ParentGUID
################################################################################
CREATE TRIGGER trg_bu000_pos_constraint ON bu000 FOR DELETE
	NOT FOR REPLICATION
AS
	SET NOCOUNT ON 

	IF ISNULL((SELECT TOP 1 CAST(ISNULL(Value, '1') AS INT) FROM FileOP000 WHERE Name = 'AmnPOS_PreventModifyPOSBill'), 1) = 0
		RETURN;

	IF EXISTS (
		SELECT *
		FROM 
			POSOrder000 o 
			INNER JOIN BillRel000 br	ON o.GUID = br.ParentGUID
			INNER JOIN DELETED d		ON d.GUID = br.BillGUID)
	BEGIN
		INSERT INTO [ErrorLog] ([Level], [Type], [c1]) 
		SELECT 1, 0, 'AmnE0620: Can''t Change POS Bill'  
	END
################################################################################
CREATE PROCEDURE prcPOSGetOptions
		@UserGUID UNIQUEIDENTIFIER = 0x0,
		@Computer NVARCHAR(250) = ''
AS
SET NOCOUNT ON 
DECLARE @ConfigGUID UNIQUEIDENTIFIER, @PriceType FLOAT, @DefCurrGuid UNIQUEIDENTIFIER, @DefCurrVal FLOAT 
SELECT @ConfigGUID=GUID FROM POSConfig000 where HostName=@Computer
SET @PriceType = ISNULL((SELECT TOP 1 CAST ([Value] AS [FLOAT]) FROM [FileOp000] WHERE [Name] = 'AmnPOS_InfoPriceType'), 0)

SELECT Name, Value, 0 AS [Type] FROM FileOP000 WHERE Name like 'AmnPOS%' 
	UNION SELECT Name, Value, 1 AS [Type] FROM UserOP000 WHERE  Name like 'AmnPOS%' AND UserID=@UserGUID
	UNION SELECT Name, Value, 2 AS [Type] FROM PcOP000 WHERE  Name like 'AmnPOS%' AND CompName=@Computer
SELECT 
	* 
FROM POSInfos000 
where ConfigID=@ConfigGUID
ORDER BY RowIndex, ColumnIndex

SELECT @DefCurrGuid = [Value] FROM FileOP000 
Where [Name] = 'AmnPOS_DefaultCurrencyID'
IF ISNULL(@DefCurrGuid,0X0) = 0X0
	SET  @DefCurrVal = 1
ELSE 
	SET @DefCurrVal = dbo.fnGetCurVal(@DefCurrGuid,GetDate())	
CREATE TABLE #POSBG (
		[bgNumber] [float],
		[bgGUID] [uniqueidentifier],		
		[bgCaption] [nvarchar](256),
		[bgLatinCaption] [nvarchar](256),
		[bgPictureID] [uniqueidentifier],
		[bgType] [int],
		[bgConfigID] [uniqueidentifier],
		[bgGroupGUID] [uniqueidentifier],
		[bgIsAutoRefresh] [bit],
		[bgIsAutoCaption] [bit],
		[bgIsSegmentedMaterial] [bit],
		[bgIsCodeInsteadName] [bit],
		[bgWeekDays]		[INT],
		[bgFromTime]		[nvarchar](10),
		[bgToTime]		[nvarchar](10),
		[bgPictureName] [nvarchar](256),
		[bgBColor] [float],
		[bgFColor] [float],
		[bgIsThemeColors] [bit],
		[bgiNumber] [float],
		[bgiGuid] [uniqueidentifier],
		[bgiType] [int],
		[bgiParentID] [uniqueidentifier],
		[bgiCommand] [int],
		[bgiItemID] [uniqueidentifier],
		[bgiCaption] [nvarchar](256),
		[bgiLatinCaption] [nvarchar](256),
		[bgiPrice]	[float],
		[bgiBColor] [float],
		[bgiFColor] [float],
		[bgiPictureID] [uniqueidentifier],
		[bgiPictureAlignment] [int],
		[bgiPictureFactor] [float],
		[bgiIsThemeColors] [bit],
		[bgiIsAutoCaption] [bit],
		[bgiPictureName] [nvarchar](256),
		[bgiHasSegments] [bit],
		[bgiIsCodeInsteadName] [bit],
		[bgiUnit] [int])
	INSERT INTO #POSBG
	SELECT 
		BG.Number bgNumber,
		BG.GUID bgGUID,
		BG.Caption bgCaption,
		BG.LatinCaption bgLatinCaption,
		BG.PictureID bgPictureID,
		BG.Type bgType,
		BG.ConfigID bgConfigID,	
		BG.GroupGUID bgGroupGUID,
		BG.IsAutoRefresh AS bgIsAutoRefresh,
		BG.IsAutoCaption AS bgIsAutoCaption,
		BG.IsSegmentedMaterial AS bgIsSegmentedMaterial,
		BG.IsCodeInsteadName AS bgIsCodeInsteadName,
		BG.WeekDays bgWeekDays,
		BG.FromTime bgFromTime,
		BG.ToTime bgToTime,
		ISNULL(bm.Name, '') bgPictureName,
		BG.BColor,
		BG.FColor,
		BG.IsThemeColors,
		BGI.Number bgiNumber,
		BGI.GUID bgiGUID,
		BGI.Type,
		BGI.ParentID,
		BGI.Command bgiCommand,
		BGI.ItemID bgiItemID,
		BGI.Caption bgiCaption,
		BGI.LatinCaption bgiLatinCaption,
		0,
		BGI.BColor bgiBColor,
		BGI.FColor bgiFColor,
		BGI.PictureID bgiPictureID,
		BGI.PictureAlignment bgiPictureAlignment,
		BGI.PictureFactor bgiPictureFactor,
		BGI.IsThemeColors bgiIsThemeColors,
		BGI.IsAutoCaption bgiIsAutoCaption,
		'' bgiPictureName,
		MT.HasSegments AS bgiHasSegments,
		BGI.IsCodeInsteadName AS bgiIsCodeInsteadName,
		BGI.Unit AS bgiUnit
	FROM 
		BG000 BG 
		INNER JOIN BGI000 BGI ON BGI.ParentID = BG.GUID
		LEFT JOIN bm000 bm ON bm.GUID = BG.PictureID
		LEFT JOIN mt000 mt ON mt.GUID = BGI.ItemID
	WHERE 
		ConfigID = @ConfigGUID
		AND 
		bg.Type = 1 -- commands
	DECLARE @lang INT
	SET @lang = [dbo].[fnConnections_GetLanguage]()
	INSERT INTO #POSBG
	SELECT 
		BG.Number bgNumber,
		BG.GUID bgGUID,
		CASE WHEN BG.IsAutoCaption = 1 THEN gr.Name ELSE BG.Caption END AS bgCaption,
		CASE WHEN BG.IsAutoCaption = 1 THEN gr.LatinName ELSE BG.LatinCaption END AS bgLatinCaption,
		BG.PictureID bgPictureID,
		BG.Type bgType,
		BG.ConfigID bgConfigID,	
		BG.GroupGUID bgGroupGUID,
		BG.IsAutoRefresh AS bgIsAutoRefresh,
		BG.IsAutoCaption AS bgIsAutoCaption,
		BG.IsSegmentedMaterial AS bgIsSegmentedMaterial,
		BG.IsCodeInsteadName AS bgIsCodeInsteadName,
		BG.WeekDays bgWeekDays,
		BG.FromTime bgFromTime,
		BG.ToTime bgToTime,
		ISNULL(bm.Name, '') bgPictureName,
		BG.BColor,
		BG.FColor,
		BG.IsThemeColors,
		BGI.Number bgiNumber,
		BGI.GUID bgiGUID,
		BGI.Type,
		BGI.ParentID,
		BGI.Command bgiCommand,
		BGI.ItemID bgiItemID,
		CASE WHEN BGI.IsAutoCaption = 1 
				THEN mt.Name  + 
						(CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL 
								THEN '' 
								ELSE ' (' + (CASE WHEN BGI.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionName END) + ')' END)
				ELSE BGI.Caption END AS bgiCaption,
		CASE WHEN BGI.IsAutoCaption = 1 
				THEN mt.LatinName + 
						(CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL OR mt.LatinName = '' 
								THEN '' 
								ELSE ' (' + (CASE WHEN BGI.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionLatinName END) + ')' END)
				ELSE BGI.LatinCaption END AS bgiLatinCaption,
		(CASE @DefCurrVal  WHEN 1 THEN 1 
				                   ELSE (CASE mt.CurrencyGUID WHEN @DefCurrGuid THEN 1 / mt.CurrencyVal 
								                              ELSE (1 / mt.CurrencyVal) * dbo.fnGetCurVal(mt.CurrencyGUID,GetDate()) / @DefCurrVal
										END)
		END) * dbo.fnGetMtPriceByType (@PriceType, mt.GUID, IIF( bgi.Unit >= 1 AND bgi.Unit <= 3, bgi.Unit, mt.DefUnit)) AS Price,
		BGI.BColor bgiBColor,
		BGI.FColor bgiFColor,
		BGI.PictureID bgiPictureID,
		BGI.PictureAlignment bgiPictureAlignment,
		BGI.PictureFactor bgiPictureFactor,
		BGI.IsThemeColors bgiIsThemeColors,
		BGI.IsAutoCaption bgiIsAutoCaption,
		ISNULL(bm1.Name, '') bgiPictureName,
		MT.HasSegments AS bgiHasSegments,
		BGI.IsCodeInsteadName AS bgiIsCodeInsteadName,
		bgi.Unit AS bgiUnit
	FROM 
		BG000 BG 
		INNER JOIN BGI000 BGI ON BGI.ParentID = BG.GUID
		INNER JOIN mt000 mt ON mt.GUID = BGI.ItemID
		LEFT JOIN gr000 gr ON gr.GUID = BG.GroupGUID		
		LEFT JOIN bm000 bm ON bm.GUID = BG.PictureID		
		LEFT JOIN bm000 bm1 ON bm1.GUID = mt.PictureGUID
	WHERE 
		ConfigID = @ConfigGUID
		AND 
		bg.Type = 0 -- materials
	IF EXISTS(SELECT * FROM #POSBG WHERE bgIsAutoRefresh = 1)
	BEGIN 
		DECLARE 
			@bgC CURSOR, 
			@bgGUID UNIQUEIDENTIFIER 
		
		DECLARE 
			@ItemNumber INT,
			@BColor INT,
			@FColor INT,
			@PictureFactor INT
		SET @bgC = CURSOR FAST_FORWARD FOR 
			SELECT [GUID] 
			FROM BG000 
			WHERE 
				ConfigID = @ConfigGUID 
				AND [Type] = 0
				AND IsAutoRefresh = 1
		OPEN @bgC FETCH NEXT FROM @bgC INTO @bgGUID
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			SET @ItemNumber = NULL
			SELECT TOP 1 
				@ItemNumber = Number,
				@BColor = BColor,
				@FColor = FColor,
				@PictureFactor = PictureFactor
			FROM 
				BGI000 
			WHERE 
				ParentID = @bgGUID
			ORDER BY Number DESC 
			IF ISNULL(@ItemNumber, 0) = 0
			BEGIN 
				SET @ItemNumber = 0
				SET @BColor = 11194327
				SET @FColor = 0
				SET @PictureFactor = 60				
			END 
			INSERT INTO #POSBG
			SELECT 
				BG.Number bgNumber,
				BG.GUID bgGUID,
				BG.Caption AS bgCaption,
				BG.LatinCaption AS bgLatinCaption,
				BG.PictureID bgPictureID,
				BG.Type bgType,
				BG.ConfigID bgConfigID,	
				BG.GroupGUID bgGroupGUID,
				BG.IsAutoRefresh AS bgIsAutoRefresh,
				BG.IsAutoCaption AS bgIsAutoCaption,
				BG.IsSegmentedMaterial AS bgIsSegmentedMaterial,
				BG.IsCodeInsteadName AS bgIsCodeInsteadName,
				BG.WeekDays bgWeekDays,
				BG.FromTime bgFromTime,
				BG.ToTime bgToTime,
				ISNULL(bm.Name, '') bgPictureName,
				BG.BColor,
				BG.FColor,
				BG.IsThemeColors,
				@ItemNumber + (ROW_NUMBER() OVER(ORDER BY mt.Number ASC)),	-- bgiNumber
				NEWID(),				-- bgiGUID,
				0,						-- bgiType
				@bgGUID,
				0,						-- bgiCommand
				mt.GUID,				-- bgiItemID,
				(mt.Name + (CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL 
									THEN '' 
									ELSE ' (' + (CASE WHEN BG.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionName END) + ')' END))
				AS bgiCaption,
				(mt.LatinName  + (CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL OR mt.LatinName = '' 
										THEN '' 
										ELSE ' (' + (CASE WHEN BG.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionLatinName END) + ')' END))
				AS bgiLatinCaption,	
				(CASE @DefCurrVal  WHEN 1 THEN 1 
				                   ELSE (CASE mt.CurrencyGUID WHEN @DefCurrGuid THEN 1 / mt.CurrencyVal 
								                              ELSE (1 / mt.CurrencyVal) * dbo.fnGetCurVal(mt.CurrencyGUID,GetDate()) / @DefCurrVal
										 END)
				END) * dbo.fnGetMtPriceByType (@PriceType, mt.GUID, IIF( bgi.Unit >= 1 AND bgi.Unit <= 3, bgi.Unit, mt.DefUnit)) AS Price,
				
				@BColor,				-- bgiBColor,
				@FColor,				-- bgiFColor,
				ISNULL(bm1.GUID, 0x0),	-- bgiPictureID,
				0,						-- bgiPictureAlignment,
				@PictureFactor,			-- bgiPictureFactor,
				1,						-- bgiIsThemeColors,
				1,						-- bgiIsAutoCaption
				ISNULL(bm1.Name, ''),	-- bgiPictureName
				MT.HasSegments AS bgiHasSegments,
				BGI.IsCodeInsteadName AS bgiIsCodeInsteadName,
				bgi.Unit AS bgiUnit
			FROM 
				BG000 BG
				INNER JOIN gr000 gr ON gr.GUID = BG.GroupGUID		
				INNER JOIN mt000 mt ON mt.GroupGUID = gr.GUID
				LEFT JOIN BGI000 BGI ON BGI.ParentID = Bg.Guid AND BGI.ItemID = mt.GUID
				LEFT JOIN bm000 bm ON bm.GUID = BG.PictureID		
				LEFT JOIN bm000 bm1 ON bm1.GUID = mt.PictureGUID
			WHERE 
				bg.GUID = @bgGUID
				AND
				ISNULL(mt.bHide, 0) = 0
				AND 
				BGI.GUID IS NULL 
				AND ((mt.Parent = (CASE WHEN BG.IsSegmentedMaterial = 1 THEN 0x0 ELSE  mt.Parent END) OR mt.Parent IS NULL)
						AND ( mt.HasSegments <> (CASE WHEN BG.IsSegmentedMaterial = 0 THEN 1 ELSE 0 END )))
			ORDER BY 
				mt.Number
			FETCH NEXT FROM @bgC INTO @bgGUID
		END 
		CLOSE @bgc
		DEALLOCATE @bgc
		
	END 
	SELECT 
		* 
	FROM 
		#POSBG
	ORDER BY 
		bgTYPE, bgNumber, bgiNumber

	--Load Currencies
	SELECT ISNULL(ci.GUID, newid()) GUID,
		   my.myCurrencyVal CurrencyVal,
		   my.myNumber Number, 
		   my.myGUID CurID, 
		   CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN my.myName ELSE CASE my.myLatinName WHEN '' THEN my.myName ELSE my.myLatinName END END CurName, 
		   ISNULL(ci.Used, 0) IsVisible,
		   ISNULL(ci.CashAccID, 0x0) CashAccID, 
		   CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN ISNULL(cAcc.acName, '') ELSE CASE ISNULL(cAcc.acLatinName, '') WHEN '' THEN ISNULL(cAcc.acName, '') ELSE ISNULL(cAcc.acLatinName, '') END END CashAccName, 
		   ISNULL(ci.ResetAccID, 0x0) ResetAccID, 
		   CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN ISNULL(rAcc.acName, '') ELSE CASE ISNULL(rAcc.acLatinName, '') WHEN '' THEN ISNULL(rAcc.acName, '') ELSE ISNULL(rAcc.acLatinName, '') END END ResetAccName, 
		   ci.UserID
	FROM POSCurrencyItem000 ci
	INNER JOIN vwac cAcc ON ci.CashAccID = cAcc.acGUID
	INNER JOIN vwac rAcc ON ci.ResetAccID = rAcc.acGUID 
	RIGHT  JOIN vwmy my ON ci.CurID = my.myGUID AND ci.UserID = @UserGUID
	WHERE ci.UserID = @UserGUID OR ci.UserID is NULL
	ORDER BY Number

################################################################################
CREATE TRIGGER trgBG_FOR_DELETE On BG000 FOR DELETE
NOT FOR REPLICATION
AS

DELETE BGI000 WHERE ParentID in (SELECT GUID FROM DELETED)
################################################################################
CREATE PROCEDURE prcPOSCopySetting
	@SourceID UNIQUEIDENTIFIER,
	@DestinationID UNIQUEIDENTIFIER,
	@destinationName NVARCHAR(250) = ''
AS

DECLARE	@HostName NVARCHAR(250),
	@sourceComputer NVARCHAR(250),
	@Number FLOAT,
	@bgNumber FLOAT, 
	@bgGuid UNIQUEIDENTIFIER, 
	@bgType int, 
	@bgCaption NVARCHAR(250), 
	@bgLatinCaption NVARCHAR(250), 
	@bgPictureID UNIQUEIDENTIFIER,
	@bgGroupGUID UNIQUEIDENTIFIER,
	@bgIsAutoRefresh BIT,
	@bgIsAutoCaption BIT,
	@isNew INT,
	@bgWeekDays int,
	@bgFromTime NVARCHAR(10),
	@bgToTime NVARCHAR(10),
	@IsSegmentedMaterial BIT,
	@IsCodeInsteadName BIT



IF @destinationName = ''
	SET @isNew = 0
ELSE
	SET @isNew = 1

IF @isNew = 0
BEGIN
	SELECT 
		@Number=number, 
		@HostName = HostName 
	FROM POSCONFIG000 WHERE GUID = @DestinationID
	DELETE POSCONFIG000 WHERE GUID = @DestinationID
	DELETE PcOP000 WHERE Name like 'AmnPOS%' AND CompName=@HostName
	DELETE BG000 WHERE ConfigID=@DestinationID
	DELETE POSinfos000 WHERE ConfigID=@DestinationID
	DELETE [POSUserBills000] where [ConfigID] = @DestinationID
END
ELSE BEGIN
	SET @HostName = @destinationName
	SELECT @Number = max(number) + 1 FROM POSCONFIG000
END

SELECT 
	@sourceComputer=HostName 
FROM POSCONFIG000 WHERE GUID = @SourceID

INSERT INTO POSCONFIG000 ([Number], 
		[GUID], 
		[HostName], 
		[Password], 
		[UseExclusiveBT])		
	SELECT 	@Number, 
		@DestinationID, 
		@HostName, 
		[Password], 
		[UseExclusiveBT]
	FROM [PosConfig000] WHERE GUID=@SourceID

 
 INSERT INTO
	[POSUserBills000] ([Type]
      , [GUID]
      , [UserID]
      , [ConfigID]
      ,[Name]
      ,[SalesID]
      ,[ReturnedID]
      ,[BranchID]
      ,[UsePoint]
      ,[PrintID]
      ,[PrintCopy]
      ,[EntryNumber]
      ,[ZeroingDate]) 
 SELECT [Type]
      , newid()
      , [UserID]
      ,@DestinationID
      ,[Name]
      ,[SalesID]
      ,[ReturnedID]
      ,[BranchID]
      ,[UsePoint]
      ,[PrintID]
      ,[PrintCopy]
      , 0
      , GetDate()
  FROM [POSUserBills000] where [ConfigID]=@SourceID

INSERT INTO PcOP000(GUID, [Name], Value, CompName) SELECT 
	newID(), 
	[Name], 
	[Value], 	
	@HostName
FROM PcOP000 where Name like 'AmnPOS%' AND CompName=@sourceComputer

DECLARE bg_cur Cursor fast_forward for
SELECT	[Number], 
	[Guid], 
	[Type], 
	[Caption], 
	[LatinCaption], 
	[PictureID],
	[GroupGUID],
	[IsAutoRefresh],
	[IsAutoCaption],
	[WeekDays],
	[FromTime],
	[ToTime] ,
	[IsSegmentedMaterial],
	[IsCodeInsteadName]
FROM BG000 WHERE CONFIGID = @SourceID

open bg_cur fetch from bg_cur into @bgNumber, @bgGUID, @bgType, @bgCaption, @bgLatinCaption, @bgPictureID, @bgGroupGUID, @bgIsAutoRefresh, @bgIsAutoCaption, @bgWeekDays, @bgFromTime, @bgToTime, @IsSegmentedMaterial, @IsCodeInsteadName
DECLARE @count int, @bg_guid uniqueidentifier
set @count = 0

WHILE @@FETCH_STATUS=0
BEGIN
	SET @count = @count + 1
	SET @bg_guid = newid()
	
	INSERT INTO bgi000([Number], [Guid], [Type], [ParentID], [Command], [ItemID], [Caption], [LatinCaption], [BColor], [FColor], [PictureID], [PictureAlignment], [PictureFactor], [IsThemeColors], [IsAutoCaption],[IsCodeInsteadName],[Unit]) 
	SELECT [Number], newid(), [Type], @bg_guid, [Command], [ItemID], [Caption], [LatinCaption], [BColor], [FColor], [PictureID], [PictureAlignment], [PictureFactor], IsThemeColors, IsAutoCaption, IsCodeInsteadName, Unit
	FROM [bgi000] WHERE ParentID = @bgGUID

	INSERT INTO bg000(Number, Guid, Type, Caption, LatinCaption, PictureID,  ConfigID, GroupGuid, IsAutoRefresh, IsAutoCaption, WeekDays, FromTime, ToTime, IsSegmentedMaterial, IsCodeInsteadName) 
	SELECT /*@count*/@bgNumber, @bg_guid, @bgType, @bgCaption, @bgLatinCaption, @bgPictureID, @DestinationID, @bgGroupGUID, @bgIsAutoRefresh, @bgIsAutoCaption, @bgWeekDays, @bgFromTime, @bgToTime, @IsSegmentedMaterial, @IsCodeInsteadName
	
	fetch next from bg_cur into @bgNumber, @bgGUID, @bgType, @bgCaption, @bgLatinCaption, @bgPictureID, @bgGroupGUID, @bgIsAutoRefresh, @bgIsAutoCaption, @bgWeekDays, @bgFromTime, @bgToTime, @IsSegmentedMaterial, @IsCodeInsteadName
END
close bg_cur
DEALLOCATE bg_cur

INSERT INTO POSInfos000 SELECT 
	[Number], 
	newid(), 
	@DestinationID, 
	[ValueIndex], 
	[Value], 
	[UpperMargin], 
	[Width], 
	[FontSize], 
	[ForegroundColor], 
	[BackgroundColor], 
	[BorderColor], 
	[RowIndex], 
	[ColumnIndex], 
	[FontStyle], 
	[IsBordered], 
	ColorsIndex
FROM [POSInfos000] WHERE ConfigID=@SourceID
################################################################################
CREATE PROCEDURE prcPOSUserCopySetting
	@SourceID UNIQUEIDENTIFIER,
	@DestinationID UNIQUEIDENTIFIER,
	@Name NVARCHAR(250) = ''
AS

 DELETE UserOP000 WHERE Name like 'AmnPOS%' AND [UserID]=@DestinationID

 INSERT INTO UserOP000 (Guid, [Name], Value, UserID) SELECT 
	newID(), 
	[Name], 
	[Value], 
	@DestinationID 
 FROM UserOP000 where Name like 'AmnPOS%' AND [UserID]=@SourceID
 
 DELETE POSCurrencyItem000 WHERE [UserID]=@DestinationID
 INSERT INTO POSCurrencyItem000 ([GUID], [Number], [CurID], [Used], [UserID], [CashAccID], [ResetAccID])
 SELECT NEWID(), Number, CurID, Used, @DestinationID, CashAccID, ResetAccID
 FROM POSCurrencyItem000
 WHERE UserID = @SourceID

################################################################################
CREATE VIEW vtPOSPayRecieveTable
AS
	SELECT * FROM POSPayRecieveTable000
################################################################################
CREATE view vbPOSPayRecieveTable
AS
	SELECT * FROM vtPOSPayRecieveTable
################################################################################
CREATE VIEW vwPOSPayEntry
AS
SELECT * FROM vbPOSPayRecieveTable
WHERE Type=1 
################################################################################
CREATE VIEW vwPOSReceiveEntry
AS
SELECT * FROM vbPOSPayRecieveTable 
WHERE Type=2
################################################################################
CREATE TRIGGER trgPOSPayRecieveTable_Delete ON POSPayRecieveTable000 FOR DELETE
NOT FOR REPLICATION
AS
		DECLARE @BillNumber INT
		DECLARE @BillName VARCHAR(255)
		SELECT @BillNumber = BillNumber, @BillName = BillName FROM DELETED
		DELETE FROM bp000
		FROM bu000 bu
		INNER JOIN bt000 bt ON bt.GUID=bu.TypeGUID
		INNER JOIN er000 er ON er.parentguid=bu.guid
		INNER JOIN ce000 ce ON er.EntryGUID=ce.guid 
		INNER JOIN en000 en ON en.ParentGUID = ce.guid 
		INNER JOIN bp000 bp ON bp.DebtGUID=en.GUID
		WHERE bu.Number = @BillNumber AND (bt.Name = @BillName OR bt.LatinName = @BillName)

		DELETE er000 WHERE ParentGUID in (SELECT GUID FROM DELETED)
################################################################################
CREATE proc prcPOSGetPayments
	@ID UNIQUEIDENTIFIER,
	@Dir INT = 2
AS
	SET NOCOUNT ON

	SELECT  
		bu.TypeGUID BillType, CASE WHEN @Dir = 2 THEN bt.Abbrev ELSE CASE WHEN bt.LatinAbbrev <> '' THEN bt.LatinAbbrev ELSE bt.Abbrev END END Abbrev,
		CASE WHEN @Dir = 2 THEN bt.Name ELSE CASE WHEN bt.LatinName <> '' THEN bt.LatinName ELSE bt.Name END END Name, bu.Number, bu.date, bu.Notes, 
		en.GUID, 
		(en.Debit - SUM(CASE ISNULL(billRel.RelatedBillGuid, 0x0) WHEN 0x0 THEN 0 ELSE [dbo].[fnCalcBillTotal](billRel.RelatedBillGuid, DEFAULT) END) - SUM(ISNULL(bp.Val, 0) )) Debit, 
		en.CurrencyVal, en.CurrencyGUID, my.Code 
	FROM 
		en000 en
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID
		INNER JOIN bu000 bu ON er.ParentGUID = bu.GUID
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
		INNER JOIN my000 my ON my.GUID = en.CurrencyGUID
		LEFT JOIN BillRelations000 billRel ON bu.GUID = billRel.BillGuid AND billRel.IsRefundFromBill = 1
		LEFT JOIN bp000 bp ON bp.DebtGUID = en.GUID
	WHERE 
		en.AccountGUID = @ID 
		AND 
		bu.TypeGUID <> 0x0
	GROUP BY 
		bt.Abbrev, bt.LatinAbbrev, bt.Name, bt.LatinName,bu.TypeGUID, bu.Number, bu.date, bu.Notes, en.GUID, en.Debit, en.CurrencyVal, en.CurrencyGUID, my.Code --, billRel.RelatedBillGuid
	HAVING 
		en.Debit - SUM(CASE ISNULL(billRel.RelatedBillGuid, 0x0) WHEN 0x0 THEN 0 ELSE [dbo].[fnCalcBillTotal](billRel.RelatedBillGuid, DEFAULT) END) > SUM(ISNULL(bp.Val, 0))
	
	UNION ALL
	
	SELECT  
		bu.TypeGUID BillType, CASE WHEN @Dir = 2 THEN bt.Abbrev ELSE CASE WHEN bt.LatinAbbrev <> '' THEN bt.LatinAbbrev ELSE bt.Abbrev END END Abbrev, 
		CASE WHEN @Dir = 2 THEN bt.Name ELSE CASE WHEN bt.LatinName <> '' THEN bt.LatinName ELSE bt.Name END END Name, bu.Number, bu.date, bu.Notes, 
		en.GUID, 
		(en.Debit - SUM(CASE ISNULL(billRel.RelatedBillGuid, 0x0) WHEN 0x0 THEN 0 ELSE [dbo].[fnCalcBillTotal](billRel.RelatedBillGuid, DEFAULT) END) - SUM(ISNULL(bp.Val, 0))) Debit, 
		en.CurrencyVal, en.CurrencyGUID, my.Code 
	FROM 
		en000 en 
		INNER JOIN (SELECT en.ParentGUID GUID, p.ParentGUID OrderID FROM en000 en INNER JOIN POSPaymentLink000 p ON en.GUID = p.EntryGUID) [entry] on [entry].GUID = en.ParentGUID
		INNER JOIN BillRel000 br ON br.ParentGUID = [entry].OrderID
		INNER JOIN bu000 bu ON bu.GUID = br.BillGUID
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
		INNER JOIN my000 my on my.GUID = en.CurrencyGUID
		LEFT JOIN BillRelations000 billRel ON bu.GUID = billRel.BillGuid AND billRel.IsRefundFromBill = 1
		LEFT JOIN bp000 bp ON bp.DebtGUID = en.GUID
	WHERE 
		en.AccountGUID = @ID 
		AND 
		bu.TypeGUID <> 0x0
	GROUP BY 
		bt.Abbrev, bt.LatinAbbrev, bt.Name, bt.LatinName,bu.TypeGUID, bu.Number, bu.date, bu.Notes, en.GUID, en.Debit, en.CurrencyVal, en.CurrencyGUID, my.Code --, billRel.RelatedBillGuid
	HAVING 
		en.Debit - SUM(CASE ISNULL(billRel.RelatedBillGuid, 0x0) WHEN 0x0 THEN 0 ELSE [dbo].[fnCalcBillTotal](billRel.RelatedBillGuid, DEFAULT) END) > SUM(ISNULL(bp.Val, 0))
################################################################################
CREATE PROCEDURE prcPOSAdd_Order
						@Mode				[INT] = -1, 
						@Delete				[INT] = 0, 
						@Number				[float] = 0, 
						@Guid				[uniqueidentifier] = 0x0, 
						@Serial				[float] = 0, 
						@Type				[int] = 0, 
						@CashierID			[uniqueidentifier] = 0x0, 
						@FinishCashierID	[uniqueidentifier] = 0x00, 
						@BranchID			[uniqueidentifier] = 0x00, 
						@State				[int] = 0, 
						@Date				[datetime] = '1/1/1980', 
						@Notes				[NVARCHAR](250) = '', 
						@Payment			[float] = 0, 
						@Cashed				[float] = 0, 
						@Discount			[float] = 0, 
						@Added				[float] = 0, 
						@Tax				[float] = 0, 
						@SubTotal			[float] = 0, 
						@CustomerID			[uniqueidentifier] = 0x00, 
						@DeferredAccountID	[uniqueidentifier] = 0x00, 
						@CurrencyID			[uniqueidentifier] = 0x00, 
						@IsPrinted			[int] = 0, 
						@HostName			[NVARCHAR](250) = '', 
						@BillNumber			[float] = 0, 
						@PaymentsPackageID	[uniqueidentifier] = 0x00, 
						@UserBillsID		[uniqueidentifier] = 0x00,
						@OrginalBillNumber	[NVARCHAR](250) = '', 
						@OrginalBillDate	[datetime] = '1/1/1980',
						@TextFld1			[NVARCHAR](250) = '', 
						@TextFld2			[NVARCHAR](250) = '', 
						@TextFld3			[NVARCHAR](250) = '', 
						@TextFld4			[NVARCHAR](250) = '',
						@SalesManID			[uniqueidentifier] = 0x00,
						@CustomerAddressID	[uniqueidentifier] = 0x00,
						@CurrencyValue		[float] = 1
AS 
	SET NOCOUNT ON 
	IF @Mode = 0 
	BEGIN 
		IF @Number <= 0  
		SELECT @Number = ISNULL(MAX(ISNULL(Number, 0)) + 1, 1) FROM POSOrdertemp000 
		INSERT INTO [POSOrderTemp000] (
		[Number] 
		,[Guid] 
		,[Serial] 
		,[Type] 
		,[CashierID] 
		,[FinishCashierID] 
		,[BranchID] 
		,[State] 
		,[Date] 
		,[Notes] 
		,[Payment] 
		,[Cashed] 
		,[Discount] 
		,[Added] 
		,[Tax] 
		,[SubTotal] 
		,[CustomerID] 
		,[DeferredAccountID] 
		,[CurrencyID] 
		,[IsPrinted] 
		,[HostName] 
		,[BillNumber] 
		,[PaymentsPackageID]
		,[UserBillsID]
		,[ReturendBillNumber]
		,[ReturendBillDate]
		,[TextFld1]
		,[TextFld2]
		,[TextFld3]
		,[TextFld4]
		,[SalesManID]
		,[CustomerAddressID]
		,[CurrencyValue]
		) 
		SELECT 
		@Number
		, @Guid
		, @Serial
		, @Type
		, @CashierID
		, @FinishCashierID
		, @BranchID
		, @State
		, @Date
		, @Notes
		, @Payment
		, @Cashed
		, @Discount
		, @Added
		, @Tax
		, @SubTotal
		, @CustomerID
		, @DeferredAccountID
		, @CurrencyID
		, @IsPrinted
		, @HostName
		, @BillNumber
		, @PaymentsPackageID
		, @UserBillsID
		, @OrginalBillNumber
		, @OrginalBillDate
		, @TextFld1
		, @TextFld2
		, @TextFld3
		, @TextFld4
		, @SalesManID
		, @CustomerAddressID
		, @CurrencyValue
	-------------------------------------------------------------
	END ELSE IF @Mode = 1 
	BEGIN 
		UPDATE [POSOrderTemp000] SET 
		[Number] = @Number 
		,[Serial] = @Serial 
		,[Type] = @Type 
		,[CashierID] = @CashierID 
		,[FinishCashierID] = @FinishCashierID 
		,[BranchID] = @BranchID 
		,[State] = @State 
		,[Date] = @Date 
		,[Notes] = @Notes 
		,[Payment] = @Payment 
		,[Cashed] = @Cashed 
		,[Discount] = @Discount 
		,[Added] = @Added 
		,[Tax] = @Tax 
		,[SubTotal] = @SubTotal 
		,[CustomerID] = @CustomerID 
		,[DeferredAccountID] = @DeferredAccountID 
		,[CurrencyID] = @CurrencyID 
		,[IsPrinted] = @IsPrinted 
		,[HostName] = @HostName 
		,[BillNumber] = @BillNumber 
		,[PaymentsPackageID] = @PaymentsPackageID
		,[UserBillsID] = @UserBillsID
		,[ReturendBillNumber] = @OrginalBillNumber
		,[ReturendBillDate] =  @OrginalBillDate
		,[TextFld1] = @TextFld1
		,[TextFld2] = @TextFld2
		,[TextFld3] = @TextFld3
		,[TextFld4] = @TextFld4
		,[SalesManID] = @SalesManID
		,[CustomerAddressID] = @CustomerAddressID
		,[CurrencyValue] = @CurrencyValue
			WHERE GUID = @GUID
	----------------------------------------------------------
	END ELSE IF @Mode = 2 
	BEGIN 
		SELECT @Number = ISNULL(MAX(ISNULL(Number, 0)) + 1, 1) FROM POSOrder000 
		INSERT INTO POSOrder000(
		[Number] 
		,[Guid] 
		,[Serial] 
		,[Type] 
		,[CashierID] 
		,[FinishCashierID] 
		,[BranchID] 
		,[State] 
		,[Date] 
		,[Notes] 
		,[Payment] 
		,[Cashed] 
		,[Discount] 
		,[Added] 
		,[Tax] 
		,[SubTotal] 
		,[CustomerID] 
		,[DeferredAccountID] 
		,[CurrencyID] 
		,[IsPrinted] 
		,[HostName] 
		,[BillNumber] 
		,[PaymentsPackageID]
		,[UserBillsID]
		,[ReturendBillNumber]
		,[ReturendBillDate]
		,[TextFld1]
		,[TextFld2]
		,[TextFld3]
		,[TextFld4]
		,[SalesManID]
		,[CustomerAddressID]
		,[CurrencyValue]
		,[LoyaltyCardGUID]
		,[LoyaltyCardTypeGUID]
		,[PointsCount]
		)
	SELECT @Number 
		,@GUID 
		,[Serial] 
		,[Type] 
		,[CashierID] 
		,[FinishCashierID] 
		,[BranchID] 
		,[State] 
		,[Date] 
		,REPLACE([Notes], 'OrderNumber', @Number)
		,[Payment] 
		,[Cashed] 
		,[Discount] 
		,[Added] 
		,[Tax] 
		,[SubTotal] 
		,[CustomerID] 
		,[DeferredAccountID] 
		,[CurrencyID] 
		,[IsPrinted] 
		,[HostName] 
		,[BillNumber] 
		,[PaymentsPackageID]
		,[UserBillsID]
		,[ReturendBillNumber]
		,[ReturendBillDate]
		,[TextFld1]
		,[TextFld2]
		,[TextFld3]
		,[TextFld4]
		,[SalesManID]
		,[CustomerAddressID]
		,[CurrencyValue]
		,[LoyaltyCardGUID]
		,[LoyaltyCardTypeGUID]
		,[PointsCount]
	FROM POSOrderTemp000 WHERE GUID=@GUID 
	-----------------------------------------------------------------------------	
		INSERT INTO [POSOrderItems000] 
				([Number]
				,[Guid]
				,[MatID]
				,[Type]
				,[Qty]
				,[MatPrice]
				,[VATValue]
				,[Price]
				,[PriceType]
				,[Unity]
				,[State] 
				,[Discount]
				,[Added]
				,[Tax]
				,[ParentID]
				,[ItemParentID]
				,[SalesmanID]
				,[PrinterID]
				,[ExpirationDate]
				,[ProductionDate] 
				,[AccountID]
				,[BillType]
				,[Note]
				,[SpecialOfferID]
				,[SpecialOfferIndex]
				,[OfferedItem]
				,[IsPrinted]
				,[SerialNumber]
				,[DiscountType]
				,[ClassPtr]
				,[RelatedBillID]
				,[BillItemID]
				,[MatBarcode])
			SELECT 
				[Number]
				,[Guid]
				,[MatID]
				,[Type]
				,[Qty]
				,[MatPrice]
				,[VATValue]
				,[Price]
				,[PriceType]
				,[Unity]
				,[State] 
				,[Discount]
				,[Added]
				,[Tax]
				,@GUID
				,[ItemParentID]
				,[SalesmanID]
				,[PrinterID]
				,[ExpirationDate]
				,[ProductionDate] 
				,[AccountID]
				,[BillType]
				,[Note]
				,[SpecialOfferID]
				,[SpecialOfferIndex]
				,[OfferedItem]
				,[IsPrinted]
				,[SerialNumber]
				,[DiscountType]
				,[ClassPtr]
				,[RelatedBillID]
				,[BillItemID]
				,[MatBarcode]
				 FROM [POSOrderItemsTemp000] WHERE ParentID=@GUID 
	-------------------------------------------
		INSERT INTO POSOrderadded000 (
				[Number] 
				,[Guid] 
				,[ParentID] 
				,[Value] 
				,[AccountID] 
				,[Notes] 
				,[OrderType]) 
		SELECT [Number] 
				,[Guid] 
				,@GUID 
				,[Value] 
				,[AccountID] 
				,[Notes] 
				,[OrderType] FROM POSOrderaddedtemp000  WHERE ParentID=@GUID 
	-----------------------------------------
		INSERT INTO POSOrderdiscount000 (
			[Number]
			,[Guid]
			,[ParentID]
			,[Value]
			,[AccountID]
			,[Notes]
			,[OrderType]
			,[SpecialOffer])
		SELECT [Number]
			,[Guid]
			,@GUID
			,[Value]
			,[AccountID]
			,[Notes]
			,[OrderType]
			,[SpecialOffer] FROM POSOrderdiscounttemp000  WHERE ParentID=@GUID 
	-------------------------------------
		INSERT INTO [POSOrderDiscountCard000](
			[GUID]
			,[DiscountCardID]
			,[CustomerID]
			,[CustomerName]
			,[CustomerNumber]
			,[UseDiscount] 
			,[PayByPoint]
			,[ParentID]) 
			SELECT [GUID]
			,[DiscountCardID]
			,[CustomerID]
			,[CustomerName]
			,[CustomerNumber]
			,[UseDiscount] 
			,[PayByPoint]
			,[ParentID] FROM [POSOrderDiscountCardTemp000]   WHERE ParentID=@GUID 

		DELETE POSOrderTemp000 WHERE GUID = @GUID 
	END ELSE IF @Mode=3 
	BEGIN 
	-----------------------------------------------------
		INSERT INTO POSOrderTemp000(
			[Number] 
			,[Guid] 
			,[Serial] 
			,[Type] 
			,[CashierID] 
			,[FinishCashierID] 
			,[BranchID] 
			,[State] 
			,[Date] 
			,[Notes] 
			,[Payment] 
			,[Cashed] 
			,[Discount] 
			,[Added] 
			,[Tax] 
			,[SubTotal] 
			,[CustomerID] 
			,[DeferredAccountID] 
			,[CurrencyID] 
			,[IsPrinted] 
			,[HostName] 
			,[BillNumber] 
			,[PaymentsPackageID]
			,[UserBillsID]
			,[ReturendBillNumber]
			,[ReturendBillDate]
			,[TextFld1]
			,[TextFld2]
			,[TextFld3]
			,[TextFld4]
			,[SalesManID]
			,[CustomerAddressID]
			,[CurrencyValue]
			)
			SELECT [Number] 
			,[GUID] 
			,[Serial] 
			,[Type] 
			,[CashierID] 
			,[FinishCashierID] 
			,[BranchID] 
			,[State] 
			,[Date] 
			,[Notes] 
			,[Payment] 
			,[Cashed] 
			,[Discount] 
			,[Added] 
			,[Tax] 
			,[SubTotal] 
			,[CustomerID] 
			,[DeferredAccountID] 
			,[CurrencyID] 
			,[IsPrinted] 
			,[HostName] 
			,[BillNumber] 
			,[PaymentsPackageID]
			,[UserBillsID]
			,[ReturendBillNumber]
			,[ReturendBillDate]
			,[TextFld1]
			,[TextFld2]
			,[TextFld3]
			,[TextFld4]
			,[SalesManID]
			,[CustomerAddressID]
			,[CurrencyValue]
				FROM POSOrder000 WHERE GUID = @GUID
	----------------------------------------------------------
		INSERT INTO POSOrderItemsTemp000 
			([Number]
			,[Guid]
			,[MatID]
			,[Type]
			,[Qty]
			,[MatPrice]
			,[VATValue]
			,[Price]
			,[PriceType]
			,[Unity]
			,[State] 
			,[Discount]
			,[Added]
			,[Tax]
			,[ParentID]
			,[ItemParentID]
			,[SalesmanID]
			,[PrinterID]
			,[ExpirationDate]
			,[ProductionDate] 
			,[AccountID]
			,[BillType]
			,[Note]
			,[SpecialOfferID]
			,[SpecialOfferIndex]
			,[OfferedItem]
			,[IsPrinted]
			,[SerialNumber]
			,[DiscountType]
			,[ClassPtr]
			,[RelatedBillID]
			,[BillItemID]) 
		SELECT [Number]
				,[GUID]
				,[MatID]
				,[Type]
				,[Qty]
				,[MatPrice]
				,[VATValue]
				,[Price]
				,[PriceType]
				,[Unity]
				,[State] 
				,[Discount]
				,[Added]
				,[Tax]
				,[ParentID]
				,[ItemParentID]
				,[SalesmanID]
				,[PrinterID]
				,[ExpirationDate]
				,[ProductionDate] 
				,[AccountID]
				,[BillType]
				,[Note]
				,[SpecialOfferID]
				,[SpecialOfferIndex]
				,[OfferedItem]
				,[IsPrinted]
				,[SerialNumber]
				,[DiscountType]
				,[ClassPtr]
				,[RelatedBillID]
				,[BillItemID]
				 FROM POSOrderItems000 WHERE ParentID=@GUID 
	-----------------------------------------------
		INSERT INTO [POSOrderDiscountCardTemp000](
			[GUID]
			,[DiscountCardID]
			,[CustomerID]
			,[CustomerName]
			,[CustomerNumber]
			,[UseDiscount] 
			,[PayByPoint]
			,[ParentID]) 
		SELECT [GUID]
			,[DiscountCardID]
			,[CustomerID]
			,[CustomerName]
			,[CustomerNumber]
			,[UseDiscount] 
			,[PayByPoint]
			,[ParentID] FROM [POSOrderDiscountCard000]   WHERE ParentID=@GUID
	----------------------------------------------	
		INSERT INTO POSOrderaddedtemp000 SELECT * FROM POSOrderadded000   WHERE ParentID=@GUID 
	----------------------------------------------	
		INSERT INTO POSOrderdiscounttemp000 select * FROM POSOrderdiscount000   WHERE ParentID=@GUID 
		IF @Delete = 1 
		BEGIN 
			DELETE POSOrder000 WHERE GUID = @GUID 
		END 
	END 
	SELECT @Number Number 
################################################################################
CREATE PROCEDURE prcPOSAdd_OrderItem
	@Mode	[INT] = -1,
	@Number [float] = 0,
	@Guid [uniqueidentifier] = 0x00,
	@MatID [uniqueidentifier] = 0x00,
	@Type [int] = 0,
	@Qty [float] = 0,
	@MatPrice [float] = 0,
	@VATValue [float] = 0,
	@Price [float] = 0,
	@PriceType [int] = 0,
	@Unity [int] = 0,
	@State [int] = 0,
	@Discount [float] = 0,
	@Added [float] = 0,
	@Tax [float] = 0,
	@ParentID [uniqueidentifier] = 0x00,
	@ItemParentID [uniqueidentifier] = 0x00,
	@SalesmanID [uniqueidentifier] = 0x00,
	@PrinterID [int] = 0,
	@ExpirationDate [datetime] = '1/1/1980',
	@ProductionDate [datetime] = '1/1/1980',
	@AccountID [uniqueidentifier] = 0x00,
	@BillType [uniqueidentifier] = 0x00,
	@Note [NVARCHAR](250) = '',
	@SpecialOfferID [uniqueidentifier] = 0x00,
	@SpecialOfferIndex [int] = 0,
	@OfferedItem [int] = 0,
	@IsPrinted [int] = 0,
	@SerialNumber [NVARCHAR](100) = '',
	@DiscountType [int] = 0,
	@ClassPtr [NVARCHAR](100) = '',
	@RelatedBillID [uniqueidentifier] = 0x0,
	@BillItemID [uniqueidentifier] = 0x0,
	@MatBarcodeEntered [NVARCHAR](250) = ''
AS
SET NOCOUNT ON
IF @Number = 0 
	SELECT @Number=ISNULL(MAX(ISNULL(Number, 0)), 0) + 1 From POSOrderItemsTemp000 WHERE ParentID = @ParentID
DECLARE @StoreID UNIQUEIDENTIFIER
SELECT 
    @StoreID = ISNULL([DefStoreGUID], 0x0)
FROM [BT000] bt WHERE [Guid] = @BillType
IF @Mode=0
BEGIN
	INSERT INTO [POSOrderItemsTemp000]
           ([Number]
           ,[Guid]
           ,[MatID]
           ,[Type]
           ,[Qty]
           ,[MatPrice]
           ,[VATValue]
           ,[Price]
           ,[PriceType]
           ,[Unity]
           ,[State]
           ,[Discount]
           ,[Added]
           ,[Tax]
           ,[ParentID]
           ,[ItemParentID]
           ,[SalesmanID]
           ,[PrinterID]
           ,[ExpirationDate]
           ,[ProductionDate]
           ,[AccountID]
           ,[BillType]
           ,[Note]
           ,[SpecialOfferID]
           ,[SpecialOfferIndex]
           ,[OfferedItem]
           ,[IsPrinted]
           ,[SerialNumber]
           ,[DiscountType]
           ,[ClassPtr]
		   ,[RelatedBillID]
		   ,[BillItemID] 
		   ,[MatBarCode])-- This Field Used In Returned Item Case
SELECT 
			@Number
			,@Guid
			,@MatID
			,@Type
			,@Qty
			,@MatPrice
			,@VATValue
			,@Price
			,@PriceType
			,@Unity
			,@State
			,@Discount
			,@Added
			,@Tax
			,@ParentID
			,@ItemParentID
			,@SalesmanID
			,@PrinterID
			,@ExpirationDate
			,@ProductionDate
			,@AccountID
			,@BillType
			,@Note
			,@SpecialOfferID
			,@SpecialOfferIndex
			,@OfferedItem
			,@IsPrinted
			,@SerialNumber
			,@DiscountType
			,@ClassPtr
			,@RelatedBillID
			,@BillItemID
			,@MatBarcodeEntered
END 
ELSE IF @Mode=1
BEGIN
	UPDATE [POSOrderItemsTemp000] SET 
	[Number] = @Number 
	,[MatID] = @MatID
	,[Type] = @Type
	,[Qty] = @Qty
	,[MatPrice] = @MatPrice
	,[VATValue] = @VATValue
	,[Price] = @Price
	,[PriceType] = @PriceType
	,[Unity] = @Unity
	,[State] = @State
	,[Discount] = @Discount
	,[Added] = @Added
	,[Tax] = @Tax
	,[ParentID] = @ParentID
	,[ItemParentID] = @ItemParentID
	,[SalesmanID] = @SalesmanID
	,[PrinterID] = @PrinterID
	,[ExpirationDate] = @ExpirationDate
	,[ProductionDate] = @ProductionDate
	,[AccountID] = @AccountID
	,[BillType] = @BillType
	,[Note] = @Note
	,[SpecialOfferID] = @SpecialOfferID
	,[SpecialOfferIndex] = @SpecialOfferIndex
	,[OfferedItem] = @OfferedItem
	,[IsPrinted] = @IsPrinted
	,[SerialNumber] = @SerialNumber
	,[DiscountType] = @DiscountType
	,[ClassPtr] = @ClassPtr
	,[RelatedBillID] = @RelatedBillID
	,[BillItemID] = @BillItemID
	,[MatBarCode] = @MatBarcodeEntered
	WHERE @Guid=Guid
END	

IF NOT EXISTS(
				SELECT  
				Qty 
				,@Guid GUID 
				,@Number Number FROM ms000 where MatGUID=@MatID AND StoreGUID=@StoreID )
	BEGIN
		SELECT Qty
		,@Guid GUID
		,@Number Number FROM mt000 where GUID=@MatID
	END
ELSE
BEGIN
SELECT  
				Qty 
				,@Guid GUID 
				,@Number Number FROM ms000 where MatGUID=@MatID AND StoreGUID=@StoreID
END
################################################################################
CREATE PROC prcPOSPayReceiveReport
	@StartDate		[DATETIME],
	@EndDate		[DATETIME],
	@BranchGUID		[UNIQUEIDENTIFIER],
	@AccountGUID	[UNIQUEIDENTIFIER] = 0x0,
	@Type			[INT] = 0,
	@CostGUID		[UNIQUEIDENTIFIER] = 0x0,
	@UserID			[UNIQUEIDENTIFIER] = 0x0,
	@IsPOS			[BIT] = 1
AS
	SET NOCOUNT ON

	CREATE TABLE [#Tbl] (
		GUID			[UNIQUEIDENTIFIER],
		number			FLOAT,
		type			INT,
		date			DATETIME,
		notes			[NVARCHAR](250) COLLATE ARABIC_CI_AI ,
		total			FLOAT,
		fromacc			[NVARCHAR](250) COLLATE ARABIC_CI_AI ,
		toacc			[NVARCHAR](250) COLLATE ARABIC_CI_AI ,
		brname			[NVARCHAR](250) COLLATE ARABIC_CI_AI ,
		billnumber		FLOAT,
		billname		[NVARCHAR](250) COLLATE ARABIC_CI_AI ,
		billvalue		FLOAT,
		customername	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		costname		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		currencyname	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		username		[NVARCHAR](250))

	INSERT INTO [#Tbl]
	SELECT
		pay.GUID,
		pay.Number, 
		pay.Type, 
		pay.Date, 
		pay.Notes, 
		pay.Total / (CASE pay.CurrencyValue WHEN 0 THEN 1 ELSE pay.CurrencyValue END), 
		ac1.Name,
		ac2.Name,
		ISNULL(br.Name, ''), 
		CASE WHEN pay.billnumber < 0 THEN -1 ELSE pay.BillNumber END, 
		pay.BillName,
		0, -- BillValue
		ISNULL(cu.CustomerName, ' '),
		ISNULL(co.Name, ' '),
		my.Name,
		us.LoginName
	FROM 
		POSPayrecieveTable000 pay
		INNER JOIN er000 er		ON pay.GUID = er.ParentGUID
		INNER JOIN ce000 ce		ON ce.GUID = er.EntryGUID
		INNER JOIN ac000 ac1	ON ac1.GUID = pay.FromAccGUID
		INNER JOIN ac000 ac2	ON ac2.GUID = pay.ToAccGUID
		INNER JOIN my000 my		ON my.GUID = pay.CurrencyGUID
		INNER JOIN us000 us		ON us.GUID = ce.CreateUserGUID
		LEFT JOIN cu000 cu		ON cu.GUID = pay.CustomerGUID
		LEFT JOIN br000 br		ON br.guid = pay.BranchGUID	
		LEFT JOIN co000 co		ON co.GUID = pay.CostGUID
	WHERE	
		(ISNULL(@BranchGUID, 0x0) = 0x0 OR @BranchGUID = pay.BranchGUID) 
		AND (@Type = 0 OR @Type = pay.Type)
		AND (pay.DATE BETWEEN @StartDate AND @EndDate)
		AND (@AccountGUID = 0x0 OR @AccountGUID = ac1.GUID OR @AccountGUID = ac2.GUID)
		AND (@CostGUID = 0x0 OR pay.CostGUID = @CostGUID)
		AND (@UserID = 0x0 OR ce.CreateUserGUID = @UserID)
	ORDER BY pay.number

	DECLARE @IsCalcCurrencyVal BIT = 0
	IF ISNULL(@IsPOS, 1) = 1
	BEGIN 
		DECLARE 
			@MainCurrencyID		[UNIQUEIDENTIFIER],
			@POSCurrencyID		[UNIQUEIDENTIFIER]

		SELECT TOP 1 @POSCurrencyID = ISNULL([Value], 0x0) 
		FROM FileOP000 
		WHERE [Name] = 'AmnPOS_DefaultCurrencyID'

		IF(@POSCurrencyID <> 0x0)
		BEGIN 
			SELECT TOP 1 @MainCurrencyID = [GUID] 
			FROM [my000]  
			WHERE CurrencyVal = 1
			
			IF(@MainCurrencyID <> @POSCurrencyID)
				SET @IsCalcCurrencyVal = 1
		END
	END 

	UPDATE [#Tbl]
	SET BillValue = (
		SELECT 
			CASE @IsCalcCurrencyVal WHEN 0 THEN ISNULL(bu.Total + bu.TotalExtra - bu.TotalDisc + bu.Vat, 0) 
			ELSE [dbo].fnGetFixedValue(bu.Total + bu.TotalExtra - bu.TotalDisc + bu.Vat, bu.Date) END
		FROM 
			bu000 bu 
			INNER JOIN bt000 bt ON  BT.GUID = BU.TypeGUID
		WHERE BillNumber = bu.Number AND BillName = bt.Name 
	)

	UPDATE [#Tbl] SET BillValue = ISNULL(BillValue, 0)

	SELECT * FROM [#Tbl]
################################################################################
CREATE PROCEDURE prcPOSGetExpireDate
	@MatID UNIQUEIDENTIFIER,
	@Qty  FLOAT = 1,
	@StoreID UNIQUEIDENTIFIER = 0x0
AS

SELECT bi.ExpireDate, ClassPtr,
	Sum
	(
		CASE WHEN bt.BillType in (0,3,4) THEN bi.Qty
		ELSE -1 * bi.Qty END
	) SumQty 
FROM bi000 bi 
	INNER JOIN bu000 bu ON bu.GUID=bi.ParentGUID 
	INNER JOIN bt000 bt ON bt.GUID=bu.TypeGUID
WHERE bi.ExpireDate >= GetDate() 
		AND (@StoreID=0x0 OR bi.StoreGUID=@StoreID)
		AND bi.MatGUID = @MatID 
		AND bi.ExpireDate <> '1980-01-01' 
Group BY bi.ExpireDate, ClassPtr, bi.MatGUID
HAVING @Qty <= Sum
	(
		CASE WHEN bt.BillType in (0,3,4) THEN bi.Qty
		ELSE -1 * bi.Qty END
	)
Order BY bi.ExpireDate
################################################################################
CREATE PROCEDURE prcPOSSummaryItemsReport
	@UserID UNIQUEIDENTIFIER,
	@StartTime DATETIME,
	@EndTime DATETIME,
	@UseUnit INT,
	@ShowGroups BIT,
	@CurrencyGUID UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

IF ISNULL(@CurrencyGUID, 0x0) = 0x0 
	SET @CurrencyGUID = dbo.fnGetDefaultCurr()

DECLARE @IsMainCurrency BIT = 0 
IF EXISTS(SELECT 1 FROM my000 WHERE GUID = @CurrencyGUID AND CurrencyVal = 1 )
	SET @IsMainCurrency = 1


CREATE TABLE #TotalMatSummary (
		grGuid UNIQUEIDENTIFIER,
		MtGuid UNIQUEIDENTIFIER,
		MtNumber UNIQUEIDENTIFIER,
		MtName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		MtLatinName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		MtUnit NVARCHAR(100),
		sQty FLOAT,
		sPrice FLOAT,
		rQty FLOAT,
		rPrice FLOAT,
		totalQty FLOAT,
		totalPrice FLOAT
		)


;WITH Orders 
AS 
(
SELECT Guid,(
				CASE @IsMainCurrency 
						WHEN 0 THEN CASE 
										WHEN @CurrencyGUID = CurrencyID  THEN [CurrencyValue]
										ELSE dbo.fnGetCurVal(@CurrencyGUID, [Date]) 
									END
						ELSE 1 
				END
			) AS [HistoryCurVal]	 
		FROM POSOrder000 
		WHERE  (FinishCashierID = @UserID OR @UserID = 0x0) 
				AND (Type = 0 OR Type = 1)
				AND Date BETWEEN @StartTime AND @EndTime
)
INSERT INTO #TotalMatSummary
SELECT 
	gr.GUID grGuid, mt.GUID mtGuid, mt.GUID, mt.Name, mt.LatinName,
	'',
	SUM(CASE WHEN [Item].[Type] = 0 THEN [Item].Qty * (CASE [Item].Unity WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END)ELSE 0 END),
	SUM(CASE [item].[TYPE] 
		WHEN 0 THEN    ( ( ([item].Price * [item].Qty)  - [item].Discount + [item].Added + [item].Tax) 
					+    ( (ISNULL(D.SalesOrderAdded, 0 )  *  ([item].Price * [item].Qty  + [item].Added) ) / IIF( D.SalesOrderSubTotalWithAdded = 0 , 1 , D.SalesOrderSubTotalWithAdded )  ) --totalAddedPercent
					-    ( (ISNULL(D.SalesDiscount, 0 )    *  ([item].Price * [item].Qty  - [item].Discount) ) / IIF( D.SalesOrderSubTotalWithDisc = 0, 1 , D.SalesOrderSubTotalWithDisc )  ) --totalDiscountPercent
					   ) / [HistoryCurVal]
															
		ELSE 0 END),
	SUM(CASE WHEN [Item].[Type] = 1 THEN -[Item].Qty * (CASE [Item].Unity WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END)ELSE 0 END),
	SUM(CASE [item].[TYPE] 
		WHEN 1 THEN    ( ( ([item].Price * [item].Qty)  - [item].Discount + [item].Added + [item].Tax) 
					+    (  (ISNULL(D.ReturnSalesAdded, 0 )    *   ([item].Price * [item].Qty + [item].Added) ) / IIF ( D.ReturnSalesSubTotalWithAdded = 0, 1 , D.ReturnSalesSubTotalWithAdded )  ) --totalAddedPercent
					-    (  (ISNULL(D.ReturnSalesDisount, 0 )  *   ([item].Price * [item].Qty - [item].Discount) ) / IIF( D.ReturnSalesOrderSubTotalWithDisc = 0 , 1 , D.ReturnSalesOrderSubTotalWithDisc ) ) --totalDiscountPercent  
					   ) / [HistoryCurVal]										 						
		ELSE 0 END), 
	0, 0
FROM Orders
	 INNER JOIN POSOrderItems000 Item ON Item.ParentID = Orders.Guid
	 INNER JOIN mt000 mt ON mt.GUID = Item.MatID
	 INNER JOIN gr000 gr ON gr.GUID = mt.GroupGUID
	 CROSS APPLY dbo.fnPOSGetOrderDiscAdded(Orders.Guid) D
GROUP BY  gr.GUID, mt.GUID, mt.Name, mt.LatinName

Update #TotalMatSummary
SET MtUnit = CASE @UseUnit WHEN 0 THEN mt.Unity
							 WHEN 1 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
							 WHEN 2 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
							 ELSE (CASE mt.DefUnit
									WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
									WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
									ELSE mt.Unity END)
				END,
				sQty = CASE  @UseUnit  WHEN 0 THEN sQty
							WHEN 1 THEN sQty / CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
							WHEN 2 THEN sQty / CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE  mt.Unit3Fact END
							ELSE sQty  / (CASE mt.defunit 
													WHEN 2 THEN mt.Unit2Fact       
													WHEN 3 THEN mt.Unit3Fact
													ELSE 1 END)
							END,
				rQty = CASE  @UseUnit  WHEN 0 THEN rQty
							WHEN 1 THEN rQty / CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
							WHEN 2 THEN rQty / CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE  mt.Unit3Fact END
							ELSE rQty  / (CASE mt.defunit 
													WHEN 2 THEN mt.Unit2Fact       
													WHEN 3 THEN mt.Unit3Fact
													ELSE 1 END)
							END,
				totalPrice = sPrice - ABS(rPrice)
FROM #TotalMatSummary totals
INNER JOIN mt000 mt ON mt.GUID = totals.MtGuid

UPDATE #TotalMatSummary SET totalQty = sQty - ABS(rQty)

IF(@ShowGroups = 1)
BEGIN
	INSERT INTO #TotalMatSummary
	SELECT  0x0, 0x0, gr.GUID , gr.Name , gr.LatinName , '' , SUM(sQty) , SUM(sPrice) , SUM(rQty) , SUM(rPrice) , SUM(totalQty) , SUM(totalPrice) 
	FROM #TotalMatSummary totals
	INNER JOIN gr000 gr ON gr.GUID = totals.grGuid
	GROUP BY gr.Code, gr.GUID, gr.Code, gr.Name, gr.LatinName
	ORDER BY gr.Code
END

SELECT * FROM #TotalMatSummary
ORDER BY MtName

################################################################################
CREATE PROCEDURE POSGetItemsPrinterID
	@ID UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

SELECT items.Guid ID, d.PrinterID FROM 
	department000 d 
	INNER JOIN DepartmentGroups000 r ON d.GUID=r.ParentID
	INNER JOIN mt000 mt ON mt.GroupGUID=r.GroupID
	INNER JOIN POSOrderItems000 items ON items.MatID=mt.GUID
WHERE items.ParentID=@ID AND d.printerid>=0
ORDER BY d.PrinterID
################################################################################
CREATE PROC prcPOSGetDiscountInfo
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@CustID [UNIQUEIDENTIFIER] = 0x0
AS

SELECT 
	Customer.CustomerName, 
	Card.GUID,
	Card.Code, 
	Card.StartDate, 
	Card.EndDate,
	Card.Notes/*,Card.TotalPoints, TotalBuy*/, 
	Status.Name NameStatus, 
	status.State,
	dtype.Name DNameType,
	CAST(dtype.DonateCond AS NVARCHAR(60)) DonateCond,
	CASE WHEN dtype.type=0 THEN CAST(dtype.value AS NVARCHAR(60)) +'%' ELSE CAST(dtype.value AS NVARCHAR(60)) END value, 
	isnull(Account.name,'') Account 
FROM discountcard000 card 
	INNER JOIN discountcardstatus000 status on status.guid=card.state
	INNER JOIN dbo.DiscountTypesCard000 type ON type.guid=card.type
	INNER JOIN discounttypes000 dtype ON dtype.guid=type.disctype
	INNER JOIN cu000 Customer ON Customer.GUID=card.CustomerGUID
	LEFT JOIN ac000 Account ON dtype.Account=account.GUID
WHERE 
	(Card.StartDate>=@StartDate AND Card.EndDate<=@EndDate)
	AND (Customer.GUID=@CustID OR ISNULL(@CustID, 0x0)=0x0) 
order by Customer.GUID
################################################################################
CREATE PROCEDURE prcPOSGetMatClassQty
	@MatID UNIQUEIDENTIFIER,
	@Qty  FLOAT = 1,
	@ClassPtr NVARCHAR(250),
	@ExpDate DATETIME,
	@StoreID UNIQUEIDENTIFIER = 0x0
AS

SELECT bi.ClassPtr, 
	Sum
	(
		CASE WHEN bt.BillType in (0,3,4) THEN bi.Qty
		ELSE -1 * bi.Qty END
	) SumQty 
FROM bi000 bi 
	INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID 
	INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
	WHERE	bi.MatGUID = @MatID
			AND bi.ClassPtr = @ClassPtr
			AND (@ExpDate = '1980-01-01' OR bi.ExpireDate = @ExpDate)
			AND (@StoreID = 0x0 OR bi.StoreGUID = @StoreID)
			AND bu.IsPosted = 1
	GROUP BY bi.ClassPtr
HAVING @Qty <= Sum
	(
		CASE WHEN bt.BillType in (0,3,4) THEN bi.Qty
		ELSE -1 * bi.Qty END
	)
################################################################################
#END
