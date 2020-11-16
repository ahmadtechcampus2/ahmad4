#########################################
CREATE PROCEDURE prcRestDrawerDetials
	@id UNIQUEIDENTIFIER
	,@start DATETIME
	,@end DATETIME
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
	[pySecurity]	INT
)
INSERT INTO #Result
SELECT 
	ce.ceDate,
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
	ISNULL(CAST(py.pySecurity AS INT), 0)
FROM 
		en000 en
		LEFT JOIN my000 my ON my.GUID = en.CurrencyGUID
		LEFT JOIN vwCe ce On en.ParentGuid=ce.ceGUID 
		LEFT JOIN er000 er On er.EntryGuid=ce.ceGUID
		LEFT JOIN vwbu bu On er.parentGuid = bu.buGUID
		LEFT JOIN vwBt bt On bu.buType = bt.btGUID
		LEFT JOIN vwpy py on er.parentGuid = py.pyGUID
		LEFT JOIN #BillsTypesTbl bttbl on bttbl.TypeGuid = bu.buType
WHERE en.AccountGUID=@id AND en.Date between @start AND @end AND (dbo.fnGetUserEntrySec_Browse(dbo.fnGetCurrentUserGUID(), py.pyTypeGUID) >= pySecurity OR py.pyTypeGUID IS NULL)
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
###########################
CREATE PROCEDURE prcRestDrawerEntrys
	@CashAccountID	UNIQUEIDENTIFIER,
	@ConfigID	UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

DECLARE @BranchID UNIQUEIDENTIFIER
SELECT @BranchID = BranchID from RestConfig000 where GUID=@ConfigID

SELECT 
	My.Guid AS CurrencyID,
	My.CurrencyVal AS CurrencyValue, 
	Sum( (En.Debit / En.CurrencyVal)- (En.Credit / En.CurrencyVal)) As Balance 
FROM En000 En
	INNER JOIN ce000 ce on ce.guid=en.parentguid
	INNER JOIN Ac000 Ac 	ON En.AccountGuid = Ac.Guid 
	LEFT JOIN My000 My	ON En.CurrencyGuid = My.Guid
WHERE	(Ac.Guid = @CashAccountID) 
	-- AND (ce.Branch=@BranchID) 
Group BY Ac.Guid, My.Guid, My.CurrencyVal, My.Number
ORDER BY My.Number
#########################################
CREATE PROCEDURE prcRestZeroingEntry
	@ZeroingID UNIQUEIDENTIFIER,
	@BranchID UNIQUEIDENTIFIER,
	@DrawerID UNIQUEIDENTIFIER,
	@IncAdjustID UNIQUEIDENTIFIER,
	@DecAdjustID UNIQUEIDENTIFIER,
	@FinalDrawerID  UNIQUEIDENTIFIER,
	@Note nvarchar(250) = ''
AS
DECLARE @currencyID UNIQUEIDENTIFIER,
		@currencyValue FLOAT,
		@UserID UNIQUEIDENTIFIER,
		@UserNum FLOAT,
		@Date DateTime,
		@EntryNumber Float,
		@CeID UNIQUEIDENTIFIER,
		@PricePrec INTEGER

--Add to Note's Entry Cashier Nameو exa: تصفير مدير - كاشيير1
SELECT @Note = @Note + ' - ' + [Name] FROM ac000 WHERE GUID = @DrawerID	
SELECT
	@UserID = [User],
	@Date = [Date]
FROM RestResetDrawer000 WHERE @ZeroingID=GUID
SELECT @UserNum = ISNULL(Number, 1) FROM us000 WHERE GUID=@UserID 
Set @CeID = newid()
SELECT @EntryNumber = ISNULL(Max(Number), 0) + 1 FROM ce000
SELECT @PricePrec = CAST(ISNULL(Value, 2) AS INTEGER) FROM Op000 WHERE Name = 'AmnCfg_PricePrec'
IF @PricePrec <= 0
 SET @PricePrec = 2

DECLARE @CeTable TABLE
(
	ID INT IDENTITY(1, 1) NOT NULL,
	DEBIT FLOAT,
	CREDIT FLOAT,
	CurValue FLOAT,
	CurID UNIQUEIDENTIFIER,
	AccountID UNIQUEIDENTIFIER,
	ContraAccountID  UNIQUEIDENTIFIER
)

INSERT @CeTable(DEBIT, CREDIT, CurValue, CurID, AccountID, ContraAccountID) 
SELECT 
	CASE WHEN Recycled > value THEN (Recycled - Value)*CurrencyValue ELSE 0.0 END,  
	CASE WHEN Recycled > value THEN 0.0 ELSE Paid*CurrencyValue + (CASE WHEN Value>(Paid+Recycled) THEN (Value-(Paid+Recycled))*CurrencyValue  ELSE 0.0 END) - (CASE WHEN Value<(Paid+Recycled) THEN ((Paid+Recycled)-Value)*CurrencyValue  ELSE 0.0 END) END ,  
	CurrencyValue,
	CurrencyID,  
	@DrawerID, 
	@FinalDrawerID  
FROM RestResetDrawerItem000 WHERE ParentID=@ZeroingID AND Value>0 AND ROUND (Recycled, @PricePrec) <> ROUND (Value, @PricePrec)

INSERT @CeTable(DEBIT, CREDIT, CurValue, CurID, AccountID, ContraAccountID)SELECT 
	Paid*CurrencyValue, 
	0.0, 
	CurrencyValue, 
	CurrencyID, 
	@FinalDrawerID, 
	@DrawerID  
FROM RestResetDrawerItem000 WHERE ParentID=@ZeroingID AND Paid>0  AND ROUND (Recycled, @PricePrec) <> ROUND (Value, @PricePrec)

INSERT @CeTable(DEBIT, CREDIT, CurValue, CurID, AccountID, ContraAccountID)SELECT 
	CASE WHEN Value>(Paid+Recycled) THEN (Value-(Paid+Recycled))*CurrencyValue  ELSE 0.0 END,  
	CASE WHEN Value<(Paid+Recycled) THEN ((Paid+Recycled)-Value)*CurrencyValue  ELSE 0.0 END,  
	CurrencyValue, 
	CurrencyID, 
	CASE WHEN Value>(Paid+Recycled) THEN @DecAdjustID ELSE @IncAdjustID END, 
	@FinalDrawerID  
FROM RestResetDrawerItem000 WHERE ParentID=@ZeroingID AND Value>0 AND Paid>=0 AND (Paid + Recycled)<>Value  AND ROUND (Recycled, @PricePrec) <> ROUND (Value, @PricePrec)

SELECT @currencyID=CurID, @currencyValue=CurValue 
FROM @CeTable WHERE CurValue = (SELECT Min(CurValue) FROM @CeTable)
IF @@ROWCOUNT <= 0 --Ignore Generating Entry When Recycled equals Total Value
	RETURN
INSERT INTO [CE000]  
  ([Type],[Number],[Date], [PostDate],[Debit],[Credit],[Notes],[CurrencyVal],[IsPosted]  
   ,[State],[Security],[Branch],[GUID],[CurrencyGUID],[TypeGUID])  
SELECT 1,@EntryNumber,@Date, @Date, SUM(DEBIT),SUM(CREDIT),@Note,@currencyValue,  
	0,--IsPosted  
	0,--State  
	1,--Security  
	@BranchID, @CeID,--GUID  
	@currencyID,--CurrencyGUID  
	0x0 -- typeguid
FROM @CeTable

INSERT INTO [en000] ([Number],[Date],[Debit],[Credit]
      ,[Notes],[CurrencyVal] ,[SalesMan] ,[GUID]
      ,[ParentGUID],[AccountGUID],[CurrencyGUID],[ContraAccGUID])
SELECT ce.ID, @Date, ce.DEBIT, ce.CREDIT, @Note, ce.CurValue, @UserNum, NEWID(), 
		@CeID, ce.AccountID, ce.CurID, ce.ContraAccountID
FROM @CeTable ce
	INNER JOIN my000 my ON my.[GUID] = ce.CurID
ORDER BY my.Number

--Generate Entry Pay Type for Zeroing Entry
DECLARE @EntryTypeID UNIQUEIDENTIFIER
SELECT TOP 1
		@EntryTypeID = CAST(value as uniqueidentifier)
	FROM UserOp000 
	where NAME = 'AmnRest_ZeroEntryID' AND UserID = @UserID
IF (@EntryTypeID = 0x0 OR @@ROWCOUNT = 0) --No Entry Type Selected
BEGIN
	UPDATE CE000 SET ISPOSTED=1 WHERE GUID=@CeID
	RETURN 
END
DECLARE @PaymentGuid UNIQUEIDENTIFIER
DECLARE @Number BIGINT
SET @PaymentGuid = newid() 
Select @Number=ISNULL(Max(Number),0)+1 From py000
INSERT INTO py000(Number, [Date], Notes, CurrencyVal, [Security], [Guid], TypeGuid, AccountGuid, CurrencyGuid, BranchGuid)
			Values
		(@Number,@Date,@Note,@CurrencyValue,1,@PaymentGuid,	@EntryTypeID, 0x0,	@currencyID,0x0)
	
	INSERT INTO er000 ([GUID],EntryGUID,ParentGUID,ParentType,ParentNumber) VALUES (newid(), @CeID, @paymentGuid, 4, @Number)
UPDATE CE000 SET ISPOSTED=1 WHERE GUID=@CeID
#########################################
CREATE PROCEDURE prcRestTotalsByPayType
	@CashierGuid  [uniqueidentifier],
	@PeriodNo [INT],
	@showGroups [BIT],
	@showMat [BIT],
	@showCur [BIT],
	@showNotes [BIT],
	@showDefAcc [BIT],
	@showBillDetails [BIT],
	@showChecksDetails [BIT]
AS
	SET NOCOUNT ON
	DECLARE @selectedOrders TABLE( [GUID] UNIQUEIDENTIFIER )
	
	INSERT INTO @selectedOrders
	SELECT 
		[Order].[GUID] 
	FROM 
		RestOrder000 [Order]
		INNER JOIN RestPeriod000 RP ON RP.Number = [Order].[Period]
	WHERE 
		(@CashierGuid = 0x0 OR @CashierGuid = [Order].FinishCashierID)
		AND 
		(((@PeriodNo = -1) AND (RP.IsClosed = 0)) OR [Order].[Period] = @PeriodNo)
	IF (@showBillDetails = 1)
	BEGIN
		SELECT bu.buNumber AS Number, bu.buDate AS [Date], bt.btAbbrev AS Abbrev, bt.btLatinAbbrev AS LatinAbbrev, ([Order].SubTotal - [Order].Discount + [Order].Added + [Order].Tax + buVAT + [Order].DeliveringFees ) AS Total
		FROM 
			RestOrder000 [Order]
			INNER JOIN BillRel000 rel ON rel.ParentGUID = [Order].GUID
			INNER JOIN vwBu bu ON bu.buGUID = rel.BillGUID
			INNER JOIN vwBt bt ON bu.buType = bt.btGUID
			INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
		ORDER BY bt.btAbbrev, bu.buNumber
		RETURN
	END ELSE
		IF (@showChecksDetails = 1)
		BEGIN
			SELECT ch.Number AS Number, nt.Name, nt.LatinName, chk.Paid / (CASE  chk.CurrencyValue WHEN 0 THEN 1 ELSE chk.CurrencyValue END ) AS  Total
			FROM 
				RestOrder000 [Order]
				INNER JOIN pospaymentspackage000 pack ON pack.[GUID] = [Order].PaymentsPackageID
				INNER JOIN pospaymentspackageCheck000 chk ON chk.ParentID = pack.[GUID]
				INNER JOIN ch000 ch ON chk.ChildID = ch.[GUID]
				INNER JOIN nt000 nt ON nt.GUID = chk.[Type]
				INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
			ORDER BY nt.Name, ch.Number
			
			RETURN
		END
	ELSE BEGIN
		DECLARE @master TABLE( [ID] [INT] )

		DECLARE @showPoints BIT
		SET @showPoints = 0
		IF (@showCur = 1) AND EXISTS(
									SELECT 
										1
									FROM 
										RestOrder000 [Order] 
										INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
										INNER JOIN POSPaymentsPackagePoints000 pp  ON [Pack].[Guid] = [pp].ParentGuid
										INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
									HAVING ISNULL(SUM(pp.PointsValue),0) > 0)
			SET @showPoints = 1
				
		IF @showGroups = 1
			INSERT INTO @master VALUES (0)
		IF @showMat = 1
			INSERT INTO @master VALUES (1)
		IF @showCur = 1
			INSERT INTO @master VALUES (2)
		IF @showNotes = 1
			INSERT INTO @master VALUES (3)
		IF @showDefAcc = 1
			INSERT INTO @master VALUES (4)
		IF @showPoints = 1
			INSERT INTO @master VALUES (5)
		SELECT * FROM @master
		SELECT 
			0 [Type], '', [gr].Name, [gr].LatinName, SUM((CASE [order].[Type] WHEN 4 THEN -1 ELSE 1 END) * [Item].Qty ) Total, 
			SUM((CASE [order].[Type] WHEN 4 THEN -1 ELSE 1 END) * [Item].Qty * ((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) 
			- (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[Discount])  
			+ (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[Added])
			+ (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[DeliveringFees])		
			+ (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[Tax])			
			)) Total2, 1 Equal
		FROM 
			RestOrder000 [Order] 
			INNER JOIN RestOrderItem000 [Item] ON [Order].[Guid] = [Item].[ParentID]
			INNER JOIN mt000 [Mt] ON [Item].[MatID] = [Mt].[GUID]
			INNER JOIN gr000 [gr] ON [Mt].[GroupGUID] = [gr].[GUID]
			INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
		WHERE 
			@showGroups = 1
		GROUP BY 
			[gr].Name, [gr].LatinName
		UNION ALL
		SELECT 
			1 [Type], '', [Mt].Name, [Mt].LatinName, SUM((CASE [order].[Type] WHEN 4 THEN -1 ELSE 1 END) * [Item].Qty) Total, 
			SUM((CASE [order].[Type] WHEN 4 THEN -1 ELSE 1 END) * [Item].Qty * ((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) 	
			- (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END)  / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[Discount])  
			+ (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END)  / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[Added])
			+ (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[DeliveringFees])		
			+ (((CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price ELSE [Item].Price END) / (CASE [Order].SubTotal WHEN 0 THEN 1 ELSE [Order].SubTotal END)) * [Order].[Tax])
			)) Total2,1 Equal
		FROM 
			RestOrder000 [Order] 
			INNER JOIN RestOrderItem000 [Item] ON [Order].[Guid] = [Item].[ParentID]
			INNER JOIN mt000 [Mt] ON [Item].[MatID] = [Mt].[GUID]
			INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
		WHERE 
			@showMat = 1
		GROUP BY 
			[Mt].Name, [Mt].LatinName
		UNION ALL
		SELECT 
			2 [Type], [Cur].Code, [My].Name, [My].LatinName, 0 Total, SUM((CASE [order].[Type] WHEN 4 THEN -1 ELSE 1 END) * (Paid - Returned) * Cur.Equal )  Total2,
			Cur.Equal Equal
		FROM 
			RestOrder000 [Order] 
			INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
			INNER JOIN POSPaymentsPackageCurrency000 [Cur] ON [Pack].[Guid] = [Cur].ParentID
			INNER JOIN my000 [My] ON [Cur].CurrencyID = [My].[GUID]
			INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
		WHERE 
			@showCur = 1
		GROUP BY 
			[Cur].Code, [My].Name, [My].LatinName,Cur.Equal
		UNION ALL
		SELECT 
			3 [Type], '', [Nt].Name, [Nt].LatinName, 0 Total, SUM(Paid ) Total2,
			[Ch].CurrencyValue Equal
		FROM 
			RestOrder000 [Order] 
			INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
			INNER JOIN POSPaymentsPackageCheck000 [Ch] ON [Pack].[Guid] = [Ch].ParentID
			INNER JOIN nt000 [Nt] ON [Ch].[Type] = [Nt].[GUID]
			INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
		WHERE 
			@showNotes = 1
		GROUP BY 
			[Nt].Name, [Nt].LatinName,[Ch].CurrencyValue
		UNION ALL
		SELECT 
			4 [Type], '', [Cu].CustomerName, [Cu].LatinName, 0 Total, SUM(DeferredAmount) Total2,
			1 Equal
		FROM 
			RestOrder000 [Order] 
			INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
			INNER JOIN cu000 [Cu] ON [Pack].[DeferredAccount] = [Cu].[GUID]
			INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
		WHERE 
			@showDefAcc = 1
		GROUP BY 
			[Cu].CustomerName, [Cu].LatinName

		UNION ALL
		SELECT 
			5 [Type], '', '', '', 0 Total, ISNULL(SUM(pp.PointsValue),0) Total2,
			1 Equal
		FROM 
			RestOrder000 [Order] 
			INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
			INNER JOIN POSPaymentsPackagePoints000 pp  ON [Pack].[Guid] = [pp].ParentGuid
			INNER JOIN @selectedOrders so ON so.GUID = [Order].[Guid]
		WHERE 
			 @showPoints = 1
		HAVING ISNULL(SUM(pp.PointsValue),0) > 0
		
		ORDER BY [Type]
		
	END
#####################################################################
#END
