#include upgrade_core.sql
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002082
AS
	SET NOCOUNT ON 
	IF NOT EXISTS( SELECT name FROM sys.Indexes WHERE name = 'TrnTransferVoucher000_ndx_613')
		CREATE NONCLUSTERED INDEX [TrnTransferVoucher000_ndx_613] ON [dbo].[TrnTransferVoucher000] 
		(
			[Number] ASC
		)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

	IF NOT EXISTS( SELECT name FROM sys.Indexes WHERE name = 'TrnTransferVoucher000_ndx_614')
		CREATE NONCLUSTERED INDEX [TrnTransferVoucher000_ndx_614] ON [dbo].[TrnTransferVoucher000] 
		(
			[SourceBranch] ASC
		)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

	IF NOT EXISTS( SELECT name FROM sys.Indexes WHERE name = 'TrnTransferVoucher000_ndx_615')
		CREATE NONCLUSTERED INDEX [TrnTransferVoucher000_ndx_615] ON [dbo].[TrnTransferVoucher000] 
		(
			[DestinationBranch] ASC
		)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]


###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003003 
AS
	SET NOCOUNT ON 
	DECLARE 
		@c CURSOR,
		@Name	[VARCHAR](100),
		@Type  [INT],
		@SearchStr [VARCHAR](100),
		@FieldNum [INT],
		@CondType [INT],
		@Link     [INT],
		@Name2 	[VARCHAR](100),
		@Type2	[INT],
		@Guid	 [UNIQUEIDENTIFIER],
		@Num	[INT] 
	SET @Name2 = ''
	SET @Type2 = 0
	SET @Num = 0
	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT 
			[Type],[ASC1],[ASC3],[NUM1],[NUM2],[NUM3] 
		FROM 
			[MC000] 
		WHERE 
			[TYPE] = 17 OR [TYPE] = 23 
		ORDER BY 
			[ASC1],[NUMBER]
	OPEN @c FETCH FROM @c INTO @Type,@Name,@SearchStr, @FieldNum, @CondType, @Link
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF ((@Name2 <> @Name) OR ( @Type <> @Type2))
		BEGIN
			SET @Guid = NEWID()	
			SET @Name2 = @Name
			SET @Type2 = @Type
			INSERT INTO [dbo].[Cond000]
				([GUID],[Type],[Name],[Date],[State]) 
			VALUES
				(@Guid,@Type,@Name,GETDATE(),0)
			SET @Num = 0
		END
		INSERT INTO [dbo].[CondItems000] 
			([ParentGUID],[SearchStr],[FieldNum],[CondType],[Link], [Number]) 
		VALUES
			(@Guid,@SearchStr, @FieldNum, @CondType, @Link,@Num) 
		SET @Num = @Num + 1
		FETCH FROM @c INTO @Type,@Name,@SearchStr, @FieldNum, @CondType, @Link
	END
	CLOSE @c
	DEALLOCATE @c
	DELETE MC000  WHERE [TYPE] = 17 OR [TYPE] = 23
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003005 
AS
	SET NOCOUNT ON 
	EXECUTE	[prcAddGUIDFld] 'CheckAcc000', 'CostGUID'
	
###################################################
Create PROCEDURE prcUpgradeDatabase_From10003008 
AS
	SET NOCOUNT ON 
	IF NOT EXISTS ( SELECT * FROM SYSOBJECTS WHERE NAME = 'PS000')
		return 
	--if their is no data in old table just return 
	IF NOT  EXISTS ( SELECT * FROM PS000)
		return
	EXEC [prcExecuteSQL] '
	DECLARE @newParentGuid UNIQUEIDENTIFIER 

	--a new  parent guid for all current ps record that will be moved to psi 
	--this guid will occupy two places in ps.guid and in psi.parentguid 
	SET @newParentGuid = NEWID()


	--Define a cursor for old mnps000 table 
	DECLARE @PSCURSOR CURSOR 
	SET  @PSCURSOR = CURSOR  FORWARD_ONLY FOR 
	SELECT * FROM PS000
	OPEN @PSCURSOR

	-- variable for old ps table 
	DECLARE	 @GUID UNIQUEIDENTIFIER ,
			 @Number INT ,
			 @Code VARCHAR(100),		 
			 @Name varchar(250), 
			 @LatinName varchar(250), 
			 @FormGuid UNIQUEIDENTIFIER,
			 @Qty varchar(250),	
			 @StartDate DATETIME,
			 @EndDate DATETIME,
			 @Note VARCHAR(250),
			 @priority INT 
		

	FETCH NEXT FROM @PSCURSOR INTO 
	@GUID ,  @Number , @Code , @Name , @LatinName, @FormGuid , @Qty , @StartDate,
	@EndDate , @Note , @priority 

	--two variable that will hols storeguid from ( bt000 when bill type is out , 
	-- or from form default out store stored in  mn000 table ) 
	DECLARE @DefOutStore UNIQUEIDENTIFIER	 , @OutStoreGuid UNIQUEIDENTIFIER

	-- get default store from bt000
	SELECT  @DefOutStore = DefStoreGuid 
	FROM BT000 
	WHERE Type = 2 AND SortNum = 6

	SET @DefOutStore = ISNULL(@DefOutStore,0x00)

	-- ps startDate should be preivous  to all it children and endDate should be later to all children 
	-- and this is the job of @TempStartDate , TempEndDate variable 
	DECLARE @TempStartDate DateTime , @TempEndDate DateTime 
	--initalized two variable to current local time 
	SET @TempStartDate = GetDate()
	Set @TempEndDate = GetDate()

	WHILE @@FETCH_STATUS = 0 
	BEGIN 		 

	SELECT
		@OutStoreGuid = OutStoreGuid 
	FROM 
		mn000 
	WHERE 
		formguid = @FormGuid and type = 0
		
	SET @OutStoreGuid  = ISNULL( @OutStoreGuid ,@DefOutStore)

	INSERT INTO 
		psi000(
			[Guid], 
			[Code], 
			[StartDate], 
			[EndDate], 
			[Qty], 
			[FormGuid], 
			[Priority], 
			[StoreGuid],
			[Notes],
			[State],
			[ParentGuid])
	VALUES (
			NEWID(),
			@code,
			@startdate,
			@enddate,
			@qty,
			@FormGuid,
			@priority,
			@OutStoreGuid,
			@note,
			2,
			@newParentGuid)

	IF @TempStartDate > @startdate
		SET @TempStartDate  = @startdate

	IF @TempEndDate < @enddate 
		SET @TempEndDate = @enddate 

	FETCH NEXT FROM @PSCURSOR INTO 
		@GUID , @Number , @Code , @Name , @LatinName, @FormGuid , @Qty , @StartDate,
		@EndDate , @Note , @Priority 

	END 
	
	CLOSE 	@PSCURSOR
	DEALLOCATE @PSCURSOR

	INSERT INTO MNPS000
	VALUES(@newParentGuid,''000001'',@TempStartDate,@TempEndDate,
	''manufacturing plans before upgrade'',0,1,0x00)'

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003013
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld] 'DistDeviceBu000', 'VisitGUID'
	EXECUTE [prcAddGUIDFld] 'DistDeviceEn000', 'VisitGUID'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003020
AS
	SET NOCOUNT ON 
	--EXECUTE [prcAddGUIDFld] 'et000', 'DefCostCenterGUID'
	EXECUTE [prcAddGUIDFld] 'et000', 'DefCurrency'
	EXECUTE [prcAddBitFld]	'et000', 'FixedAccount'
	--EXECUTE [prcAddBitFld]	'et000', 'FixedCostCenter'
	EXECUTE [prcAddBitFld]	'et000', 'FixedCurrency'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003026
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 'DistDeviceMt000', 'SNFlag'
	EXECUTE [prcAddIntFld] 'DistDeviceMt000', 'ForceInSN'
	EXECUTE [prcAddIntFld] 'DistDeviceMt000', 'ForceOutSN'                         
	EXECUTE [prcAddBigIntFld] 'Distributor000', 'branchMask'                        
	EXECUTE [prcAddBigIntFld] 'DistHi000', 'branchMask'
	EXECUTE [prcAddBigIntFld] 'DistSalesman000', 'branchMask'
	EXECUTE [prcAddBigIntFld] 'DistVan000', 'branchMask'
	EXECUTE [prcAddGUIDFld] 'DisGeneralTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistCustMatTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistCustTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistDistributorTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DisTChTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistCustClassesTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistDeviceVi000', 'DistributorGUID'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003027
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld] 'abd000', 'Branch'
	EXECUTE [prcAddFloatFld] 'TrnStatementItems000', 'Amount2'
	EXECUTE [prcAddGUIDFld] 'TrnStatementItems000', 'CurrencyGUID2'
	EXECUTE [prcAddFloatFld] 'TrnStatementItems000', 'CurrencyVal2'
	EXECUTE [prcAddGUIDFld] 'TrnTransferTypes000', 'CashAccGuid'
	EXECUTE [prcAddGUIDFld] 'TrnTransferTypes000', 'PaidAccGuid'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003033 
AS
	SET NOCOUNT ON 
	EXECUTE	[prcAddGUIDFld] 'CheckAcc000', 'CostGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003038 
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddCharFld]  'InvReconcileItem000', 'StkSN', 100
	
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'CashBranch'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'AddBranch'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'NotifyBranch'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'CashDate'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'CashTime'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'NotifyDate'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'NotifyTime'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'PayBranch'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'PayDate'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'Status'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'Lost'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'OfficeGuid'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'Transferred'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'Delivered'
	EXEC [dbo].[prcDropFld] 'trnTransferVoucher000', 'Stopped'
	EXEC [dbo].[prcDropFld] 'TrnGenerator000',		 'BranchGUID'	
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'CommissionTypeGUID'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'MenuName'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'MenuLatinName'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'DefState'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'DefStatus'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'PaybranchMask'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'CashbranchMask'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'MainPayBranchGUID'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'AddBranchMask'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'bEntryOnCreate'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'bEntryOnPay'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'bHasSourceAcc'
	EXEC [dbo].[prcDropFld] 'TrnTransferTypes000', 'bHasDestAcc'
	
	IF [dbo].[fnObjectExists]( 'trnDriver000') <> 0 
		EXEC( 'DROP TABLE [trnDriver000]')
	IF [dbo].[fnObjectExists]( 'trnPachages000') <> 0 
		EXEC( 'DROP TABLE [trnPachages000]')
	IF [dbo].[fnObjectExists]( 'trnRetTrance000') <> 0 
		EXEC( 'DROP TABLE [trnRetTrance000]')
	IF [dbo].[fnObjectExists]( 'trnStoppedTrance000') <> 0 
		EXEC( 'DROP TABLE [trnStoppedTrance000]')
	IF [dbo].[fnObjectExists]( 'trnservices000') <> 0 
		EXEC( 'DROP TABLE [trnservices000]')
	IF [dbo].[fnObjectExists]( 'TrnTransportation000') <> 0 
		EXEC( 'DROP TABLE [TrnTransportation000]')
	
	EXECUTE [prcAddGUIDFld]  'trnTransferVoucher000', 'PayCurrency'
	EXECUTE [prcAddFloatFld] 'trnTransferVoucher000', 'PayCurrencyVal'
	EXECUTE [prcAddGUIDFld]  'trnTransferVoucher000', 'exchangeCurrency'
	EXECUTE [prcAddFloatFld] 'trnTransferVoucher000', 'exchangeCurrencyVal'
	EXECUTE [prcAddCharFld]  'TrnStatement000', 'CheckKey', 250
	
	EXECUTE [prcAddIntFld] 'TrnSenderReceiver000', 'WarnOnUse' 
	EXECUTE [prcAddIntFld] 'TrnSenderReceiver000', 'BlockOnUse' 
	EXECUTE [prcAddCharFld] 'TrnSenderReceiver000', 'UserName', 250
	EXECUTE [prcAddCharFld] 'TrnSenderReceiver000', 'Password', 250
	EXECUTE [prcAddGUIDFld]  'trnTransferTypes000', 'ProfitAccGUID'
	EXECUTE [prcAddCharFld] 'TrnStatementTypes000', 'CodedKey', 250
	
	EXECUTE [prcAddFloatFld] 'trnTransferVoucher000','DestBranchWages'
	EXECUTE [prcAddFloatFld] 'trnTransferVoucher000','DestRecordedAmount'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003041
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 'TrnStatementTypes000', 'IsOut' 
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003044
AS
	SET NOCOUNT ON 
	EXECUTE [prcAlterFld] 'lg000', 'RepId', 'float'
	EXECUTE [prcAddIntFld] 'AC000', 'IncomeBalsheetType'
	EXECUTE [prcAddIntFld] 'AC000', 'IncomeType'
	EXECUTE [prcAddIntFld] 'AC000', 'CashFlowType'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003047
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 'bt000', 'FldCount'
	EXECUTE [prcAddFloatFld] 'bi000', 'Count'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003051
AS
	SET NOCOUNT ON 
	EXEC [dbo].[prcDropFld] 'ac000', 'IncomeBalsheetType'
	EXECUTE [prcAddIntFld] 'AC000', 'IncomeType'
	EXECUTE [prcAddIntFld] 'AC000', 'BalsheetType'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003053
AS
	SET NOCOUNT ON 
	-- Converting Old Serial Number Schema to the new Schema
	IF NOT EXISTS(SELECT * FROM [SNC000])
	BEGIN
		INSERT INTO [SNC000] (  [SN], [MatGUID]) SELECT DISTINCT [SN], [MatGUID] FROM [SN000]
		SELECT guid ,[sn] + cast([MatGUID] as VARCHAR(36)) idd into #SNC from [SNC000]
		SELECT * 
		INTO #SN
		FROM
		(
			SELECT [Item],[Notes],inguid biGuid,[sn] + cast([MatGUID] as VARCHAR(36)) idd  from sn000 WHERE inguid <> 0x00
			UNION ALL
			SELECT [Item],[Notes],outguid biGuid,[sn] + cast([MatGUID] as VARCHAR(36))  from sn000 where outguid <> 0x00
		) a
		INSERT INTO [dbo].[snt000] ( [GUID], [Item], [biGUID], [ParentGUID], [Notes], [StGUID], [buGuid])
				SELECT  NewId(), [Item], biGuid, [snc].[GUID], [SN].[Notes], [bi].[StoreGUID], [BI].[ParentGUID]
				FROM [#SN] [SN] inner join [#snc] [snc] on [SN].idd = [snc].idd
				INNER JOIN [BI000] [BI] ON [BI].[GUID] = biGuid
	END	
	EXECUTE [prcAddGUIDFld]  'trnExchangeTypes000', 'CostGUID'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003056 
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]  'PA_CE000', 'DeviceGuid'	
	EXEC [dbo].[prcDropFld] 'PA_CE000', 'AcGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003058 
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 'TrnCurrencyClass000', 'Number'
	EXEC [dbo].[prcDropFld] 'TrnCloseCashier000', 'BranchMask'
	EXECUTE [prcAddGUIDFld] 'TrnCloseCashier000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'TrnCloseCashier000', 'EntryGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003059 
AS
	SET NOCOUNT ON 
	EXECUTE [dbo].[prcDropFld]	 'TrnExchange000', 'CashPayCurrencyVal'
	EXECUTE [dbo].[prcAddBitFld] 'TrnExchangeTypes000', 'bForceCurClasses'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003061
AS
	SET NOCOUNT ON 
	EXECUTE [prcDropFld]		'TrnBankTrans000','SourceGuid'
	EXECUTE [prcDropFld]		'TrnBankTrans000','SourceType'
	EXECUTE [prcAddGUIDFld]		'TrnExchange000', 'VoucherGuid'	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003063
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		 'TrnExchangeTypes000', 'RoundAccGuid'	
	EXECUTE [prcAddGUIDFld]		 'TrnExchangeTypes000', 'ExchangeAcc'	
	EXECUTE [prcAddGUIDFld]		 'TrnExchangeTypes000', 'DiffAcc'	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003065
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld]		 'TrnCloseCashier000', 'Type'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003067
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		 'TrnExchangeCurrClass000', 'CurGUID'	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003068
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld]		'ad000', 'Status'
	EXECUTE [prcAddCharFld]		'ad000', 'BarCode', 250
	EXECUTE [prcAddIntFld]		'ad000', 'Security'
	EXECUTE [prcAddGUIDFld]		'ad000', 'BrGuid'
	EXECUTE [prcAddGUIDFld]		'ad000', 'CoGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003070
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'TrnExchange000', 'VoucherGuid'
	EXECUTE [prcAddFloatFld]	'TrnExchange000', 'RoundValue'
	EXECUTE [prcAddIntFld]		'TrnExchange000', 'RoundDir'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003071
AS
	SET NOCOUNT ON 
	EXEC [prcAlterFld] 'prs000','LeftMargin','FLOAT'
	EXEC [prcAlterFld] 'prs000','TopMargin','FLOAT'
	EXEC [prcAlterFld] 'prs000','BottomMargin','FLOAT'
	EXEC [prcAlterFld] 'prs000','RightMargin','FLOAT'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003073
AS
	SET NOCOUNT ON 
	EXEC prcDropFld 'TrnExchangeCurrClass000' ,'Balance'
	EXEC [prcAddIntFld] 'TrnExchangeCurrClass000','PayValue'
	EXEC [prcAlterFld]  'TrnExchangeCurrClass000','Type','Integer'
	EXEC [prcAlterFld]  'TrnExchangeCurrClass000','Value','Integer'
	EXEC [prcAddIntFld] 'TrnExchangeTypes000' ,'ReportType'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003092
AS
	SET NOCOUNT ON 
	EXECUTE [dbo].[prcAddBitFld] 'TrnExchangeTypes000', 'bAutoContraAcc'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003093
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'TrnExchange000' ,'CustomerType'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003096
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'pt000', 'CustAcc'
	EXECUTE [prcAddFloatFld]	'pt000', 'Debit'
	EXECUTE [prcAddFloatFld]	'pt000', 'Credit'
	EXECUTE [prcAddGUIDFld]		'pt000', 'CurrencyGUID'
	EXECUTE [prcAddFloatFld]	'pt000', 'CurrencyVal'
	EXECUTE [prcAddDateFld]		'pt000', 'DueDate'
	EXECUTE [prcAddBitFld]		'pt000', 'IsTransfered'
	DECLARE @Sql  NVARCHAR(MAX)
	SET  @Sql = '
	UPDATE pt set CustAcc = bu.CustAccGuid,
	DueDate = [dbo].[fnDate_AddEx]( [bu].[Date], [pt].[Term], [pt].[Days]),
	Debit = CASE [bisoutput] WHEN 1 THEN bu.Total + bu.TotalExtra - bu.TotalDisc + bu.Vat ELSE 0 END,
	Credit = CASE [bisinput] WHEN 1 THEN bu.Total + bu.TotalExtra - bu.TotalDisc + bu.Vat ELSE 0 END,
	CurrencyGuid = bu.CurrencyGuid,
	CurrencyVal = bu.CurrencyVal
	FROM pt000 pt inner join bu000 bu on bu.guid = pt.refGuid
	INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid]'
	EXEC(@Sql)
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003098 
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'pt000', 'TypeGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003104  
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddDateFld]		'pt000', 'OriginDate'
	DECLARE @Sql  VARCHAR(8000)
	SET @Sql = 'ALTER TABLE ce000 DISABLE TRIGGER ALL '
	SET  @Sql = @Sql + 'UPDATE ce set TypeGuid = pt.TypeGuid
	
	FROM 
		ce000 ce inner join er000 er on er.entryGuid = ce.Guid INNER JOIN pt000 pt  on er.parentguid = pt.refGuid
	WHERE IsTransfered > 0'
	SET @Sql = @Sql + 'ALTER TABLE ce000 ENABLE TRIGGER ALL '
	EXEC(@Sql)	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003106
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld]		'hbt000', 'FldQtyFlds'

	DECLARE @Sql  VARCHAR(8000)
	SET  @Sql = '
	UPDATE hbt000
	set 
		[FldQtyFlds]	= 1, 
		[FldTotalQty]	= 2, 
		[FldPrice]		= 3, 
		[FldTotalPrice] = 4, 
		[FldDiscValue]	= 5, 
		[FldExtraValue] = 6,
		[FldDiscRatio]	= 7, 
		[FldExtraRatio] = 8 '
	EXEC(@Sql)
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003109
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddFloatFld]		'Trnexchange000', 'CashRoundAmount'
	EXECUTE [prcAddFloatFld]		'Trnexchange000', 'PayRoundAmount'
	EXECUTE	[prcAddGUIDFld]			'trnCurrencyAcc000', 'SellsAcc'	
	EXECUTE	[prcAddGUIDFld]			'trnCurrencyAcc000', 'SellsCostAcc'
	
	DECLARE @Sql  VARCHAR(8000)
	SET  @Sql = '
		update Trnexchange000
			Set CashRoundAmount = Round(CashAmount / CashCurrencyVal + RoundValue, 1),
			PayRoundAmount = Cast(payAmount / payCurrencyVal as int ) 
		where RoundDir = 0 AND (CashCurrencyVal <> 0 OR payCurrencyVal <> 0)

		update Trnexchange000
			Set CashRoundAmount = CashAmount / CashCurrencyVal,
			PayRoundAmount = Round (payAmount / payCurrencyVal + RoundValue, 1) 
		where RoundDir = 1 AND (CashCurrencyVal <> 0 OR payCurrencyVal <> 0)' 
	EXEC(@Sql)
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003119
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddFloatFld]		'Trnexchange000', 'CashCurBalance'
	EXECUTE [prcAddFloatFld]		'Trnexchange000', 'CashAvgVal'
	EXECUTE [prcAddFloatFld]		'Trnexchange000', 'PayCurBalance'
	EXECUTE [prcAddFloatFld]		'Trnexchange000', 'PayAvgVal'
######################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003121
AS
	SET NOCOUNT ON 
	EXECUTE	[prcAddGUIDFld]			'ad000', 'SnGuid'
	EXECUTE [prcAlterFld] 'TrnCurrencyClASs000', 'ClassVal', 'float'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003122
AS
	SET NOCOUNT ON 
    EXECUTE [prcDropFld]            'Custom_Field000', 'Format'
	EXECUTE	[prcAddGUIDFld]			'Custom_Field000', 'FormatGuid'
	EXECUTE	[prcAddIntFld]			'Custom_Field_Type000', 'Number'
	EXECUTE	[prcAddIntFld]			'Custom_Field_Format000', 'Number'
	EXECUTE	[prcAddGUIDFld]			'Custom_Field_Format000', 'TypeGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003128
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddCharFld] 'MultiFiles000', 'ServerName', 100
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003129
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 'trnStatementTypes000', 'bBriefEntry'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003134
AS
	SET NOCOUNT ON 
	EXECUTE [prcAlterFld] 'TrnStatementItems000', 'CurrencyVal', 'float'
	EXECUTE [prcAlterFld] 'TrnStatementItems000', 'CurrencyVal2', 'float'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003145
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld] 'TrnTransferVoucher000', 'WagesTypeGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003147
AS
	SET NOCOUNT ON 
	-- DistDistributionLines000
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route1Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route2Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route3Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route4Time'
	-- Distributor000
	IF [dbo].[fnObjectExists]('Distributor000.MatCondGUID') = 0
		EXECUTE [prcDropFld] 'Distributor000', 'MatCondGUID'
		
	IF [dbo].[fnObjectExists]('Distributor000.CustCondGUID') = 0
		EXECUTE [prcDropFld] 'Distributor000', 'CustCondGUID'
	
	EXECUTE [prcAddBitFld] 'Distributor000', 'CanChangeCustBarcode'
	-- distdd000
	EXECUTE [prcAddIntFld] 'distdd000', 'ObjectNumber'
	-- DistDisc000
	EXECUTE [prcAddGUIDFld] 'DistDisc000', 'MatTemplateGuid'
	-- DistDeviceBt000
	EXECUTE [prcAddIntFld] 'DistDeviceBt000', 'Type'	
	EXECUTE [prcAddGUIDFld] 'DistDeviceBt000', 'StoreGUID'
	EXECUTE [prcAddGUIDFld] 'DistDeviceBt000', 'btGUID'
	-- DistDeviceEt000
	EXECUTE [prcAddGUIDFld] 'DistDeviceEt000', 'etGUID'
	-- DistDeviceGr000
	EXECUTE [prcAddGUIDFld] 'DistDeviceGr000', 'grGUID'
	-- DistDeviceMt000
	EXECUTE [prcAddGUIDFld] 'DistDeviceMt000', 'MatTemplateGuid'
	EXECUTE [prcAddGUIDFld] 'DistDeviceMt000', 'mtGuid'
	--	'DistDeviceCu000'
	EXECUTE [prcAddCharFld] 'DistDeviceCu000', 'RouteTime', 10
	EXECUTE [prcAddIntFld] 'DistDeviceCu000', 'SortID'
	EXECUTE [prcAddGUIDFld] 'DistDeviceCu000', 'StoreGUID'
	EXECUTE [prcAddCharFld] 'DistDeviceCu000', 'Notes', 250
	EXECUTE [prcAddFloatFld] 'DistDeviceCu000', 'AroundBalance'
	EXECUTE [prcAddDateFld] 'DistDeviceCu000', 'LastBuDate'
	EXECUTE [prcAddFloatFld] 'DistDeviceCu000', 'LastBuTotal'
	EXECUTE [prcAddFloatFld] 'DistDeviceCu000', 'LastBuFirstPay'
	EXECUTE [prcAddDateFld] 'DistDeviceCu000', 'LastEnDate'
	EXECUTE [prcAddFloatFld] 'DistDeviceCu000', 'LastEnTotal'
	EXECUTE [prcAddGUIDFld] 'DistDeviceCu000', 'cuGuid'	
	EXECUTE [prcAddCharFld] 'DistDeviceCu000', 'CustomerType', 250
	EXECUTE [prcAddCharFld] 'DistDeviceCu000', 'TradeChannel', 250
	-- DistDeviceBu000
	EXECUTE [prcAddGUIDFld] 'DistDeviceBu000', 'StoreGUID'
	-- DistDeviceNewCu000
	EXECUTE [prcAddCharFld] 'DistDeviceNewCu000  ', 'NewNotes', 250	      
	-- DistDeviceDiscDetail000
	EXECUTE [prcAddGUIDFld] 'DistDeviceDiscDetail000', 'MatTemplateGuid'
	-- DistCC000
	EXECUTE [prcAddGUIDFld] 'DistCC000', 'CustStateGuid'	
	EXECUTE [prcAddGUIDFld] 'DistCC000', 'MatShowGuid'	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003153
AS
	SET NOCOUNT ON 
	-- Fix Modification of constant IDSC_REPORT From 0x3000 to 0x0000
	DECLARE @Rep3000 AS [FLOAT]
	DECLARE @Rep6000 AS [FLOAT]
	SET @Rep3000 = 12288
	SET @Rep6000 = 1610612736 
	IF EXISTS (SELECT * FROM [ui000] WHERE [ReportId] = @Rep3000)
		BEGIN
		UPDATE [ui000] SET [ReportId] = [ReportId] - @Rep6000 WHERE [ReportId] >= @Rep6000
		UPDATE [ui000] SET [ReportId] = [ReportId] - @Rep3000 WHERE [ReportId] >= @Rep3000

		UPDATE [lg000] SET [RepId] = [RepId] - @Rep3000 WHERE [RepId] >= @Rep3000
		UPDATE [lg000] SET [RepId] = [RepId] - @Rep6000 WHERE [RepId] >= @Rep6000

		UPDATE [us000] SET [Dirty] = 1
		EXECUTE [prcFlag_Set] 20 -- Rebuild user permissions
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003154
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddBitFld]	'sd000', 'bBonus'
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003155
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddCharFld]	'TrnExchangeTypes000', 'MenuName', 250
	EXECUTE [prcAddCharFld]	'TrnExchangeTypes000', 'MenuLatinName', 250
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003168
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld]	'CFMapping000', 'isMapped'
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003179
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]	'PosConfig000', 'ExtBranchID'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003183
AS
	SET NOCOUNT ON 
	--- hosPatient000 table 
	EXECUTE [prcAddGUIDFld] 'hosPatient000', 'PersonGUID'
	--EXECUTE [prcAddGUIDFld] 'HosPatient000', 'Kind'
	--EXECUTE [prcDropFld] 'HosPatient000', 'Kind'
	EXECUTE [prcAddCharFld] 'HosPatient000', 'Kind', 250	
	EXECUTE [prcAddGUIDFld] 'hosPatient000', 'PictureGUID'
		
	-- hosEmployee000
	EXECUTE [prcDropFld] 'hosEmployee000', 'AddToGUID'
	EXECUTE [prcAddIntFld] 'hosEmployee000', 'WorkNature'
	EXECUTE [prcAddGUIDFld] 'hosEmployee000', 'AccGUID'
	EXECUTE [prcAlterFld] 'hosEmployee000', 'speciality', 'VARCHAR (100) COLLATE ARABIC_CI_AI', 0, ''''''

	-- hosGeneralTest000
	EXECUTE [prcAddFloatFld] 'hosGeneralTest000', 'Discount'
	EXECUTE [prcAddIntFld] 'hosGeneralTest000', 'Type'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'AccGUID'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'EntryGUID'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'FileGUID'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'OperationGUID'
	EXECUTE [prcAddCharFld] 'hosGeneralTest000', 'Result', 250
	EXECUTE [prcAddFloatFld] 'hosGeneralTest000', 'Cost'
	EXECUTE [prcDropFld] 'hosGeneralTest000', 'FldFileGUID'
	EXECUTE [prcDropFld] 'hosGeneralTest000', 'FldOperationGUID'
	EXECUTE [prcDropFld] 'hosGeneralTest000', 'GeneralTestResult'
	EXECUTE [prcDropFld] 'hosGeneralTest000', 'FldCost'
	EXECUTE [prcAddIntFld] 'hosGeneralTest000', 'Security'	
	EXECUTE [prcAddIntFld] 'hosGeneralTest000', 'Type'
	EXECUTE [prcAddGUIDFld] 	'hosGeneraltest000', 'WorkerGUID'	
	EXECUTE [prcAddGUIDFld] 	'hosGeneraltest000', 'CurrencyGuid'	
	EXECUTE [prcAddFloatFld] 	'hosGeneraltest000', 'CurrencyVal'
	EXECUTE [prcAddFloatFld] 	'hosGeneraltest000', 'WorkerFee'

	--- hosSurgery000
	EXECUTE [prcAddCharFld] 'hosSurgery000', 'Name', 250
	EXECUTE [prcAddGUIDFld] 'hosSurgery000', 'SiteGuid'	
	EXECUTE [prcAddFloatFld] 'HosSurgery000', 'RoomCost'
	
	 -- HosFSurgery000
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'PatientBillGuid'
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'SurgeryBillGuid'
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'RoomCostEntryGUID'
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'WorkersEntryGUID'
	EXECUTE	[prcAddGUIDFld]  'hosFSurgery000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'hosFSurgery000', 'CurrencyVal'
	EXECUTE [prcAddGUIDFld] 'hosFSurgery000', 'OperationGuid'
	EXECUTE [prcAddGUIDFld] 'hosFSurgery000', 'AnesthetistEntryGuid'
	
	-- HosSurgeryMat000
	EXECUTE [prcAddIntFld] 'HosSurgeryMat000', 'Type'
	EXECUTE [prcAddFloatFld] 'HosSurgeryMat000', 'Unity'
	EXECUTE [prcAddGUIDFld] 'HosSurgeryMat000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'HosSurgeryMat000', 'CurrencyVal'
	EXECUTE [prcAddGUIDFld] 'HosSurgeryMat000', 'StoreGUID'

	 -- hosPFile000
	EXEC [prcAddGUIDFld]		'hosPFile000', 'MedConsEntryGUID'
	EXECUTE [prcAddGUIDFld]		'HosPFile000', 'BedGUID'
	EXECUTE [prcAddGUIDFld]		'HosPFile000', 'FirstStayGUID'
	EXECUTE [prcAddIntFld]		'HosPFile000', 'ClinicalTestSecurity'
	EXECUTE [prcAddIntFld]		'HosPFile000', 'StaySecurity'
	EXECUTE [prcAddIntFld]		'HosPFile000', 'GeneralOperationSecurity'
	EXECUTE [prcAddIntFld]		'HosPFile000', 'MedConsSecurity'
	EXECUTE [prcAddIntFld]		'HosPFile000', 'DoctorFollowingSecurity'
	EXECUTE [prcAddIntFld]		'HosPFile000', 'NurseFollowingSecurity'
	EXECUTE [prcAddIntFld]		'HosPFile000', 'ConsumedSecurity'
	EXECUTE [prcAddGUIDFld]		'HosPFile000', 'Branch'
	EXECUTE	[prcAddGUIDFld]		'HosPFile000', 'ConsumedBillGUID'
	EXECUTE [prcAddGUIDFld]		'HosPFile000', 'ReservationGuid'
	EXEC [prcAddIntFld] 			'HosPFile000', 'FileType'
	
	-- hosDailyFollowing000
	EXECUTE [prcAddIntFld] 'hosDailyFollowing000', 'Type'

	-- hosCons000
	EXEC [prcAddGUIDFld] 'hosCons000', 'FileGUID'
	EXEC [prcAddGUIDFld] 'hosCons000', 'DoctorGUID'
	EXEC [prcAddFloatFld] 'hosCons000', 'Cost'

	-- hosAnalysisOrderDetail000
	EXEC [prcAddGUIDFld] 'hosAnalysisOrderDetail000', 'ParentGUID'
	EXECUTE [prcAddGUIDFld] 'hosanalysisOrderdetail000', 'MainAnalysis'
	EXECUTE [prcAddBitFld] 'hosanalysisOrderdetail000', 'State'
	
	-- hosRadioGraphyOrderdetail000
	EXECUTE [prcAddGUIDFld] 'hosRadioGraphyOrderdetail000', 'MainRadioGraphy'
	EXECUTE [prcAddBitFld] 'hosRadioGraphyOrderdetail000', 'State'
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyOrderDetail000', 'Price'
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyOrderDetail000', 'Discount'
	EXECUTE [prcAlterFld]	 'hosradiographyorderdetail000', 'Result', 'VARCHAR (4000) COLLATE 

ARABIC_CI_AI', 0, ''''''

	-- site
	EXECUTE [prcAddGUIDFld] 'HosSite000', 'STATUS'
	EXECUTE [prcAddCharFld]	'HosSite000', 'Desc', 256
	--EXECUTE [prcAddBitFld] 'hossite000', 'bMultiPatient'
	--EXECUTE [prcDropFld] 'hossite000', 'bMultiPatient'

	-- HosSurgeryTimeCost000
	EXECUTE [prcAddGUIDFld] 'HosSurgeryTimeCost000', 'TypeGuid'
	
	 -- hossiteType000
	EXECUTE [prcAddBitFld] 'hossiteType000', 'bMultiPatient', '1'
	EXECUTE [prcAddIntFld]	'HosSiteType000', 'PricePolicy'
	EXECUTE ('UPDATE HosSiteType000 SET PricePolicy = 0 ')

	exec [prcDropProcedure] 'prcGetAnalysisTree'
	exec prcDropView 'vwAnalysis'

	-- HosRadioGraphyOrder000
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'PayGuid'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'DoctorGUID'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'BillGUID'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'StatusGUID'
	EXECUTE	[prcAddGUIDFld]  'HosRadioGraphyOrder000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyOrder000', 'CurrencyVal'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'Branch'
	EXECUTE [prcAddGUIDFld]		'HosRadioGraphyOrder000', 'EntryGuid'
		
	-- HosRadioGraphyMats000
	EXECUTE [prcAddIntFld] 'HosRadioGraphyMats000', 'Type'
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyMats000', 'Unity'
	EXECUTE	[prcAddGUIDFld]  'HosRadioGraphyMats000', 'StoreGUID'
	

	-- hosRadioGraphy000
	EXECUTE	[prcAddGUIDFld]  'hosRadioGraphy000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'hosRadioGraphy000', 'CurrencyVal'
	EXECUTE [prcAddGUIDFld] 'hosRadioGraphy000', 'TypeGUID'

	-- HosReservation000
	EXECUTE [prcAddGUIDFld] 'HosReservation000', 'Status'
	EXECUTE [prcAddIntFld] 'HosReservation000', 'State'
	
	-- HosReservationDetails000
	EXECUTE [prcAddGUIDFld]		'HosReservationDetails000', 'FileGuid'
	EXECUTE [prcAddGUIDFld]		'HosReservationDetails000', 'PayGuid'
	EXECUTE [prcAddGUIDFld]		'HosReservationDetails000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld]	'HosReservationDetails000', 'CurrencyVal'
	EXECUTE [prcAddIntFld]		'HosReservationDetails000', 'IsConfirm'

	-- HosSiteStatus000
	EXECUTE [prcAddIntFld] 'HosSiteStatus000', 'Type'
	
	-- hosConsumed000
	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Price'
	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Qty'
	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Discount'
	EXECUTE [prcAddGUIDFld] 'hosConsumed000', 'StoreGUID'
	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Unity'
	
	--EXECUTE [prcAddGUIDFld] 'hosConsumed000', 'CurrencyGuid'
	--EXECUTE [prcAddFloatFld] 'hosConsumed000', 'CurrencyVal'

	IF [dbo].[fnObjectExists]('Hosconsumed000.CurrencyGuid') = 0
		EXECUTE [prcDropFld] 'Hosconsumed000', 'CurrencyGuid'
	IF [dbo].[fnObjectExists]('Hosconsumed000.CurrencyVal') = 0
		EXECUTE [prcDropFld] 'Hosconsumed000', 'CurrencyVal'

	EXECUTE	[prcAddGUIDFld]  'hosConsumed000', 'ParentGuid'
	-- HosAnalysisOrder000	
	EXECUTE	[prcAddGUIDFld]  'HosAnalysisOrder000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'HosAnalysisOrder000', 'CurrencyVal'
	EXECUTE [prcAddGUIDFld] 'HosAnalysisOrder000', 'BillGuid'
	EXECUTE [prcAddGUIDFld] 'HosAnalysisOrder000', 'Branch'
	EXECUTE [prcAddFloatFld] 'HosAnalysisOrder000', 'Total'
	EXECUTE [prcAddGUIDFld] 'hosAnalysisOrder000', 'PayGuid'
	
	-- hosStay000
	EXECUTE [prcAddGUIDFld] 'hosStay000', 'SiteGuid'
	EXECUTE [prcAddGUIDFld] 'hosStay000', 'AccGuid'
	EXECUTE [prcAddBitFld] 'hosStay000', 'IsAuto'
	EXECUTE [prcAddGUIDFld] 'hosStay000', 'BedGuid'
	EXECUTE [prcAddGUIDFld]		'hosStay000', 'EntryGuid'
	EXECUTE [prcAddGUIDFld] 	'hosStay000', 'CurrencyGuid'	
	EXECUTE [prcAddFloatFld] 	'hosStay000', 'CurrencyVal'	


	-- hosConsumedMaster000
	EXECUTE [prcAddDateFld] 'hosConsumedMaster000', 'Date'
	EXECUTE [prcAddGUIDFld]		'hosConsumedMaster000', 'BillGUID'

	-- hosAnalysis000
	EXECUTE	[prcAddGUIDFld]  'hosAnalysis000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'hosAnalysis000', 'CurrencyVal'
	EXECUTE [prcAddFloatFld] 'hosAnalysis000', 'ExternalPrice'

	-- hosOperation000
	EXECUTE [prcAddDateFld]  'hosOperation000', 'date'
	EXECUTE	[prcAddGUIDFld]  'hosOperation000', 'CurrencyGuid'
	EXECUTE	[prcAddFloatFld]  'hosOperation000', 'CurrencyVal'
	EXECUTE [prcAddFloatFld] 'hosOperation000', 'Cost'
	EXECUTE [prcAddIntFld] 'hosOperation000', 'Type'
	EXECUTE [prcAddCharFld] 'hosOperation000', 'Notes', 250	
	EXECUTE [prcAddIntFld] 'hosOperation000', 'Security'

	
	-- HosTreatmentPlan000
	EXECUTE [prcAddGUIDFld]		'HosTreatmentPlan000', 'BillGuid'
	EXECUTE [prcAddCharFld]		'HosTreatmentPlan000', 'Code', 100
	EXECUTE [prcAddIntFld]		'HosTreatmentPlanDetails000', 'Status'
	EXECUTE [prcAddFloatFld]	'HosTreatmentPlanDetails000', 'Dose'
	EXECUTE [prcAddIntFld]		'HosTreatmentPlan000', 'unity'
	EXECUTE [prcAddIntFld]		'HosTreatmentPlanDetails000', 'unity'

	-- HosgeneralOperation000
	EXECUTE [prcAddFloatFld] 	'HosgeneralOperation000', 'WorkerFee'	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003202
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld]  	'TrnExchange000', 'OpType'		
	EXECUTE [prcAddGUIDFld] 	'TrnExchange000', 'RoundCurrency'	
	EXECUTE [prcAddFloatFld] 	'TrnExchange000', 'RoundCurrencyVal'	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003209
AS
	SET NOCOUNT ON 
	EXECUTE [prcDropProcedure] 'prcGenExchangeEntry3'  
	EXECUTE [prcDropProcedure] 'TrnExchangeGenerateEntry'  
	EXECUTE [prcDropProcedure] 'prcGenerateExchangeEntry'
	EXECUTE [prcDropProcedure] 'prcExchange_ReGenEntry' 
	EXECUTE [prcDropProcedure] 'TrnExchange_ReGenerateFifo'
	EXECUTE [prcDropProcedure] 'TrnExchangeMaintainCurrency'  
	EXECUTE [prcDropProcedure] 'TrnExchangeMaintain'  
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003219
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]  	'TrnCloseCashier000', 'CurrencyGuid'		
	EXECUTE [prcAddFloatFld] 	'TrnCloseCashier000', 'CurrencyVal'	
	EXECUTE [prcAddFloatFld] 	'TrnCloseCashier000', 'Amount'	
	EXECUTE [prcAddCharFld]		'TrnCloseCashier000', 'Notes', 250

	EXECUTE [prcAddDateFld]		'TrnExchangeCurrClass000', 'Date'
	
	DECLARE @Sql  VARCHAR(1000)
	SET  @Sql = '
		update TrnExchangeCurrClass000
		set [Date] = e.[Date]
		From TrnExchange000 as e
		inner join TrnExchangeCurrClass000 as c on c.ParentGuid = e.Guid '
	EXEC(@Sql)
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003225
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddBitFld] 'TrnExchangeTypes000', 'bCanAddnegBalance', '0'
	EXECUTE [prcAddBitFld] 'TrnMhCurrencySort000', 'bMulConst', '0'
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003228
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]  	'POSOrder000', 'PaymentsPackageID'		
	EXECUTE [prcAddGUIDFld]  	'POSOrderTemp000', 'PaymentsPackageID'		
	
	DECLARE @Sql  VARCHAR(8000)
	SET  @Sql = 'UPDATE ad000 SET snGuid = snc.Guid FROM ad000 ad INNER JOIN snc000 snc ON  snc.sn = ad.sn'
	EXEC(@Sql)
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003229
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'TrnTransferVoucher000', 'OutStatementGuid'
	EXECUTE [prcAddIntFld]		'TrnTransferVoucher000', 'AgentPaid'
	-- EXECUTE [prcAlterFld]		'CustomReport000', 'frxFile', 'Text'
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003235
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld]		'TrntransferVoucher000', 'SourceType'
	EXECUTE [prcAddIntFld]		'TrntransferVoucher000', 'DestinationType'
	EXECUTE [prcAddGUIDFld]		'TrntransferVoucher000', 'AgentBranch'
	
	EXECUTE [prcAddGUIDFld]		'TrnTransferTypes000', 'AgentBranchGuid'
	EXECUTE [prcAddGUIDFld]		'TrnTransferTypes000', 'SourceOfficeGuid'
	EXECUTE [prcAddGUIDFld]		'TrnTransferTypes000', 'DestinationOfficeGuid'
	EXECUTE [prcAddIntFld]		'TrnTransferTypes000', 'SourceType'
	EXECUTE [prcAddIntFld]		'TrnTransferTypes000', 'DestinationType'
	
	EXECUTE [prcAddIntFld]		'TrnStatementTypes000', 'bOffice'
	EXECUTE [prcAddGUIDFld]		'TrnStatementTypes000', 'OfficeGuid'
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003237
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'TrnTransferTypes000', 'WagesType2GUID'
	EXECUTE [prcAddFloatFld]	'TrnStatementItems000', 'WagesCost'
	EXECUTE [prcAddFloatFld]	'TrnTransferVoucher000', 'WagesCost'
	
	EXECUTE [prcAddBigIntFld]	'DiscountTypes000', 'BranchMask'
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003238
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddCharFld]	'TrnTransferVoucher000', 'PayVoucherCode', 250
	EXECUTE [prcAddGUIDFld]	'TrnTransferVoucher000', 'DestinationGUID'
	EXECUTE [prcAddGUIDFld]	'TrnStatementItems000', 'DestinationGUID'
	
##########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003241
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'Dp000', 'MatGuid'
	EXECUTE [prcAddGUIDFld]		'Dp000', 'GroupGuid'
	EXECUTE [prcAddGUIDFld]		'Dp000', 'StoreGuid'
	EXECUTE [prcAddFloatFld]	'DD000', 'PrevDep'

	EXECUTE [prcAddGUIDFld]		'sm000', 'MatCondGUID'
	EXECUTE [prcAddGUIDFld]		'sm000', 'CustCondGUID'	
	EXECUTE [prcAddGUIDFld]		'sm000', 'CostGUID'		
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003242
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]	'AssetExclude000', 'BillTypeGuid'
	EXECUTE [prcAddBitFld]	'sm000', 'bActive', '1'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003244
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddCharFld] 'sm000', 'ClassStr', 250
	EXECUTE [prcAddCharFld] 'sm000', 'GroupStr', 250

	EXECUTE [prcAddCharFld] 'TrnExchange000', 'CustomerName', 250
	EXECUTE [prcAddCharFld] 'TrnExchange000', 'CutomerIdentityNo', 250
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003245
AS	
	SET NOCOUNT ON 
	EXECUTE [prcAddFloatFld] 'cp000', 'CurrencyVal'
	EXECUTE [prcAddGUIDFld] 'cp000', 'CurrencyGUID'
##########################################################################################		
CREATE PROCEDURE prcUpdateCustomersPrices
AS
	SET NOCOUNT ON 

	EXEC prcDisableTriggers 'cu000', 1
	UPDATE [cu000]
	SET [DefPrice] = 
		(CASE [DefPrice] 
				WHEN 0 THEN 0x4
				WHEN 1 THEN 0x8
				WHEN 2 THEN 0x10
				WHEN 3 THEN 0x20
				WHEN 4 THEN 0x40
				ELSE 0x80
			END) 
	EXEC [prcEnableTriggers] 'cu000'
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003246
AS
	SET NOCOUNT ON 
	DECLARE @bUpdateCustomers BIT 
	SET @bUpdateCustomers = 0
	
	IF [dbo].[fnObjectExists]( 'POSInfos000') <> 0
	BEGIN 
		IF [dbo].[fnObjectExists]( 'POSInfos000.IsBordered') = 0
		BEGIN
			SET @bUpdateCustomers = 1
			EXECUTE [prcAddBitFld] 'POSInfos000', 'IsBordered', '1'
		END 
	END 
	
	IF @bUpdateCustomers = 0
	BEGIN 
		IF EXISTS( SELECT * FROM [cu000] WHERE ([DefPrice] = 0) OR ([DefPrice] = 1) OR ([DefPrice] = 2) 

OR ([DefPrice] = 3) OR ([DefPrice] = 5))
			SET @bUpdateCustomers = 1
	END 
	IF @bUpdateCustomers = 1
		EXEC prcUpdateCustomersPrices
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003250  
AS
	SET NOCOUNT ON 
	DECLARE @C Cursor ,@Sql varchar(100)
	SET @C = CURSOR FAST_FORWARD FOR 
	select 'ALTER TABLE ' + c.name +' DROP CONSTRAINT ' + b.Name from sysconstraints a 
	inner join sysobjects b on constid = b.id
	inner join sysobjects c on a.id = c.id
	WHERE  b.Name like '%Pk%' AND C.Name LIKE '%000'

	OPEN @C FETCH FROM @C INTO @Sql
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		exec (@Sql)
		FETCH FROM @C INTO @Sql
	end 
	CLOSE @C
	DEALLOCATE @c
	EXEC [prcAlterFld] 'mt000','Number','INT'
	EXEC [prcAlterFld] 'bu000','Number','INT'
	EXEC [prcAlterFld] 'bi000','Number','INT'
	EXEC [prcAlterFld] 'CH000','Number','INT'
	EXEC [prcAlterFld] 'ST000','Number','INT'
	EXEC [prcAlterFld] 'gr000','Number','INT'
	EXEC [prcAlterFld] 'my000','Number','INT'
	EXEC [prcAlterFld] 'ac000','Number','INT'
	EXEC [prcAlterFld] 'PY000','Number','INT'
	EXEC [prcAlterFld] 'ce000','Number','INT'
	EXEC [prcAlterFld] 'co000','Number','INT'
	EXEC [prcAlterFld] 'ci000','Number','INT'
	EXEC [prcAlterFld] 'sm000','Number','INT'
	EXEC [prcAlterFld] 'br000','Number','INT'
	EXECUTE [prcFlag_set] 1 -- re-index
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003251
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddCharFld] 'TrnExchange000', 'CashNote', 250
	EXECUTE [prcAddCharFld] 'TrnExchange000', 'PayNote', 250

##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003252
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'Pl000', 'DistributorPassword', 20
	EXEC [prcAddCharFld] 'Pl000', 'SupervisorPassword', 20
	EXEC [prcAddCharFld] 'Pl000', 'License', 50
	
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003254
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddBigIntFld] 'sm000', 'branchMask'
	
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003257
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 'POSOrderAdded000', 'OrderType'
	EXECUTE [prcAddIntFld] 'POSOrderAddedTemp000', 'OrderType'

	EXECUTE [prcAddIntFld] 'POSOrderDiscount000', 'OrderType'
	EXECUTE [prcAddIntFld] 'POSOrderDiscountTemp000', 'OrderType'
	
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003264
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'dd000', 'StoreGUID'	
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003270
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld]		'TrnCloseCashier000', 'CostGuid'	
##########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003282
AS
	SET NOCOUNT ON 
	Exec [prcAddBitFld] 	'DistCt000', 'PayTypeCashOnly'
	EXEC [prcAddIntFld]	'Distributor000',  'PrintPrice'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'Price5'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'Price6'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'Price5Unit2'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'Price6Unit2'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'Price5Unit3'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'Price6Unit3'
	EXEC [prcAddBitFld] 	'DistDeviceVi000', 'UseCustBarcode', '0'
	EXEC [prcAddBitFld] 	'DistVi000',	   'UseCustBarcode', '0'
	EXEC [prcAddGUIDFld]	'DistCe000',	   'StoreGuid'
	EXEC [prcAddIntFld]	'DistDeviceCu000', 'DefPrice'
	EXEC prcAddCharFld 'DistDeviceCu000', 'Phone', 30
	EXEC prcAddCharFld 'DistDeviceCu000', 'Mobile', 30

	Exec prcAddFld 'DistDeviceNewCu000', 'Name',			 '[VARCHAR](100) COLLATE ARABIC_CI_AI 

DEFAULT ('''') '      
	Exec prcAddFld 'DistDeviceNewCu000', 'Area',			 '[VARCHAR](50) COLLATE ARABIC_CI_AI 

DEFAULT ('''') '     
	Exec prcAddFld 'DistDeviceNewCu000', 'Street',			 '[VARCHAR](50) COLLATE ARABIC_CI_AI 

DEFAULT ('''') '	
	Exec prcAddFld 'DistDeviceNewCu000', 'Phone',			 '[VARCHAR](20) COLLATE ARABIC_CI_AI 

DEFAULT ('''') '	
	Exec prcAddFld 'DistDeviceNewCu000', 'Mobile',			 '[VARCHAR](20) COLLATE ARABIC_CI_AI 

DEFAULT ('''') '	
	Exec prcAddFld 'DistDeviceNewCu000', 'PersonalName',	 '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT 

('''') '			
	Exec prcAddFld 'DistDeviceNewCu000', 'CustomerTypeGuid', '[UNIQUEIDENTIFIER] DEFAULT (0x00)'  
	Exec prcAddFld 'DistDeviceNewCu000', 'TradeChannelGuid', '[UNIQUEIDENTIFIER] DEFAULT (0x00)'  
	Exec prcAddFld 'DistDeviceNewCu000', 'Contracted',		 '[BIT] DEFAULT (0)'				
	
	EXEC prcAddFld 'DistVd000', 'CustNotes', '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXEC prcAddFld 'DistVd000', 'DistNotes', '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXEC [prcAddGUIDFld] 'DistCg000', 'CompanyGuid'
	EXEC [prcAddGUIDFld] 'DistCg000', 'VisitGuid'
	EXEC [prcAddGUIDFld] 'DistCm000', 'VisitGuid'
	EXEC('
			UPDATE DistVd000 SET CustNotes = '''' WHERE CustNotes IS Null
			UPDATE DistVd000 SET DistNotes = '''' WHERE DistNotes IS Null
		')

	EXEC prcAddbitFld 'DistDeviceBu000', 'IsSync'
	EXEC prcAddbitFld 'DistDeviceEn000', 'IsSync'
##########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003285
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]	'DistDeviceCm000', 'Unity'	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003289
AS
	SET NOCOUNT ON 
	EXEC prcAddBitFld 'cu000', 'bHide'
##########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003290
AS
	SET NOCOUNT ON 
	EXEC prcAddFloatFld 'ch000', 'CollectedVal'
##########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003291
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'SpecialOffer000', 'Active'
	EXEC ('Update SpecialOffer000 Set Active=1')	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003292
AS
	SET NOCOUNT ON 
	IF [dbo].[fnObjectExists]('TAH000.buGuid') = 1
	BEGIN
		EXEC [prcDropFld] 'TAH000', 'buGuid'
		EXEC [prcAddGUIDFld]	'TAH000', 'OutbuGuid'
		EXEC [prcAddGUIDFld]	'TAH000', 'OutbuTypeGuid'
		EXEC [prcAddGUIDFld]	'TAH000', 'InbuGuid'
		EXEC [prcAddGUIDFld]	'TAH000', 'InbuTypeGuid'
	END
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003293
AS
	SET NOCOUNT ON 
	IF [dbo].[fnObjectExists]('TAH000') = 1
	BEGIN
		DROP TABLE TAH000
		DROP TABLE TAD000
	END
	IF [dbo].[fnObjectExists]('nt000.bManualCollect') = 0
	BEGIN
		EXEC [prcAddIntFld] 'nt000', 'bManualCollect'
		EXEC [prcAddIntFld] 'nt000', 'bManualEndorse'
		EXEC [prcAddIntFld] 'nt000', 'bManualReturn'
	END
##########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003295
AS
	SET NOCOUNT ON 
	IF [dbo].[fnObjectExists]('MsgHeader000') = 1
	BEGIN
		IF [dbo].[fnObjectExists]('MsgHeader000.Number') = 0
		BEGIN
			DROP TABLE [MsgHeader000]
			DROP TABLE [MsgDetails000]
		END
	END
	IF [dbo].[fnObjectExists]('SpecialOffer000.Active') = 0
	BEGIN
	     EXEC [prcAddIntFld] 'SpecialOffer000', 'Active'
	     EXEC ('Update SpecialOffer000 Set Active=1')
	END
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003302
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'SpecialOfferDetails000', 'Group'	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003307
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 		'TrntransferVoucher000', 'Number2'
	EXECUTE [prcAddGUIDFld]		'TrnStatementItems000', 'SourceBranch'
	EXECUTE [prcAddGUIDFld]		'TrnStatementItems000', 'DestinationBranch'
	EXECUTE [prcAddIntFld]		'TrnStatementItems000', 'DestinationType'
	EXECUTE [prcAddGUIDFld]		'TrnStatement000', 'OfficeGuid'
	EXECUTE [prcAddBigIntFld]	'TrnOffice000', 'BranchMask'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003309
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 		'bgi000', 'PictureAlignment'
	EXECUTE [prcAddFloatFld]	'bgi000', 'PictureFactor'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003310
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddIntFld] 'POSOrderDiscount000', 'SpecialOffer'
	EXECUTE [prcAddIntFld] 'POSOrderDiscountTemp000', 'SpecialOffer'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003315
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld] 'Distributor000', 'MatCondGuid'
	EXECUTE [prcAddGUIDFld] 'Distributor000', 'CustCondGuid'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003318
AS
	SET NOCOUNT ON 
	exec prcChangeDefault 'lg000','LogTime','GetDate()'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003323
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]  'DistPromotions000', 'CondType'          
	EXEC [prcAddIntFld]  'DistPromotions000', 'FreeType'           
	EXEC prcAddbitFld  'DistPromotions000', 'IsActive', 1         
	EXEC [prcAddIntFld]  'DistPromotionsDetail000', 'Unity', 1
	EXEC prcAddbitFld  'Distributor000', 'ExportOffers'
	EXEC prcAddbitFld  'Distributor000', 'CheckBillOffers'
	EXEC prcAddbitFld  'Distributor000', 'CanAddBonus', 1
	EXEC prcAddbitFld  'Distributor000', 'AddMatByBarcode'
	EXEC [prcAddFloatFld] 'DistPromotionsBudget000', 'RealPromQty'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003324
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddGUIDFld] 'TrnExchangeTypes000', 'GroupCurrencyAccGUID'
	EXECUTE [prcAddFloatFld]'TrnCloseCashierDetail000', 'Amount'
	-- DELETE 
	EXECUTE [prcDropFld]	'TrnCloseCashierDetail000', 'AccGUID'
	EXECUTE [prcDropFld]	'TrnCloseCashierDetail000', 'Debit'
	EXECUTE [prcDropFld]	'TrnCloseCashierDetail000', 'Credit'
	EXECUTE [prcDropFld]	'TrnCloseCashierDetail000', 'CurrencyVal'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003327
AS
	SET NOCOUNT ON 
	EXECUTE [prcDropFld] 'TrnExchangeTypes000', 'CostAccGUID'
	EXECUTE [prcDropFld] 'TrnExchangeTypes000', 'bContainCostFld'
	EXECUTE [prcDropFld] 'TrnExchangeTypes000', 'bCanChangeCostFld'
	EXECUTE [prcDropFld] 'TrnExchangeTypes000', 'bCanChangePayType'
	EXECUTE [prcAddIntFld] 'TrnExchangeTypes000', 'BillFormType'

	EXECUTE [prcAddGUIDFld] 'pospayrecievetable000', 'PayGUID'
	EXECUTE [prcAddFld] 'pospayrecievetable000', 'CheckNumber', '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXECUTE ('UPDATE ce SET ce.guid=temp.guid FROM
	(
		SELECT	t.guid, 
				er.entryguid 
		FROM er000 er 
			INNER JOIN pospayrecievetable000 t ON t.guid=er.parentguid 
	) temp INNER JOIN ce000 ce ON ce.guid=temp.entryguid
	UPDATE er SET er.entryguid = t.guid FROM er000 er 
		INNER JOIN pospayrecievetable000 t ON t.guid=er.parentguid')
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003329
AS
	SET NOCOUNT ON 
	EXEC [prcAddFloatFld] 'DistPromotionsBudget000', 'RealPromQty' 
	EXEC [prcAddIntFld] 'DistDeviceBi000', 'ProNumber'	
	EXEC [prcAddIntFld] 'DistDeviceBi000', 'ProType'		
	EXEC [prcAddIntFld] 'DistDevicePro000', 'ProNumber'	
	EXEC [prcAddIntFld] 'DistDevicePro000', 'CondType'	
	EXEC [prcAddIntFld] 'DistDevicePro000', 'FreeType'		
	EXEC [prcAddIntFld] 'DistDeviceProDetail000', 'Unity', 1
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003335
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'DiscountTypesCard000', 'UsePoint' 
	EXEC [prcAddFloatFld] 'DiscountTypesCard000', 'CollectPoint'
	EXEC [prcAddFloatFld] 'DiscountTypesCard000', 'SpendPoint'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003337
AS
	SET NOCOUNT ON 
	EXECUTE [prcAlterFld] 'mt000', 'Spec', 'VARCHAR(1000)'
	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003339
AS
	SET NOCOUNT ON 
	EXEC prcAddbitFld  'Distributor000', 'CanUpdateOffer' 
	EXEC prcAddbitFld  'DistPromotions000' , 'ChkExactlyQty'    
	EXEC prcAddbitFld  'DistDevicePro000' , 'ChkExactlyQty'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003341
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld]	'mn000', 'CostSemiGUID'

##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003347
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld]	'TrnStatementTypes000', 'ExcahngeRatesAccGuid'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003348
AS
	SET NOCOUNT ON 
	EXEC prcAddIntFld  'Distributor000', 'DeviceType'
	EXEC prcAddbitFld  'Distributor000', 'CanAddCustomer'
	EXEC prcAddbitFld  'Distributor000', 'ChangeCustCard'
	EXEC prcAddbitFld  'Distributor000', 'ExportCustAcc'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003349
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 	'DistDeviceBu000', 'IsOrder'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'OrderQty'
	EXEC [prcAddIntFld]	'DistDeviceMt000', 'OrderUnity'
	EXEC prcDropFld 	'DistDeviceBu000', 'TripGuid'
	EXEC prcDropFld 	'DistDeviceBu000', 'EntryGuid'
	EXEC [prcAddBitFld] 	'Distributor000' , 'ExportAfterZeroAcc'
    EXEC [prcAddGUIDFld]	'fm000', 'ParentForm'
	EXEC [prcAddBitFld] 	'bu000', 'IsPrinted'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003353
AS
	SET NOCOUNT ON 
	--EXEC [prcAddBitFld] 	'Distributor000'  , 'ExportExpireDates'
	--EXEC [prcAddBitFld] 	'Distributor000'  , 'FIFOExpireDate'
	--EXEC [prcAddBitFld] 	'Distributor000'  , 'ExportClasses'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003358
AS
	SET NOCOUNT ON 
	EXEC prcDropFld 	'Distributor000'  , 'ExportExpireDates'
	EXEC prcDropFld 	'Distributor000'  , 'FIFOExpireDate'
	EXEC prcDropFld 	'Distributor000'  , 'ExportClasses'
	EXEC [prcAddGuidFld] 'POSOrder000', 'UserBillsID'
	EXEC [prcAddGuidFld] 'POSOrderTemp000', 'UserBillsID'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003362
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'Pl000', 'DistributorPassword', 20
	EXEC [prcAddCharFld] 'Pl000', 'SupervisorPassword', 20
	EXEC [prcAddCharFld] 'Pl000', 'License', 50
	EXEC [prcAddGUIDFld]	'Pl000' , 'MatCondGuid'
	EXEC [prcAddGUIDFld]	'Pl000' , 'CustCondGuid'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003365
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]	'POSConfig000', 'CeNumber'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003367
AS
	SET NOCOUNT ON 
	IF [dbo].[fnObjectExists]('TrnVoucherPayInfo000.IdentityVard') <> 0
		EXECUTE [prcRenameFld] 'TrnVoucherPayInfo000', 'IdentityVard', 'IdentityCard'
	
	EXECUTE [prcAddBitFld]	'TrnOffice000', 'bLocal'		
	EXECUTE prcAddCharFld 'TrnOffice000', 'Company', 250
	EXECUTE prcAddCharFld 'TrnOffice000', 'City', 250
	EXECUTE prcAddCharFld 'TrnOffice000', 'State', 250
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003370
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld]	'POSPayRecieveTable000', 'CostGUID'
	EXEC prcAddDateFld 'POSPayRecieveTable000', 'InsertTime'
	EXEC [prcAddGUIDFld]	'dp000', 'EntryType'
	EXEC [prcAddGUIDFld]  'assTransferHeader000', 'SrcEntryType'
	EXEC [prcAddGUIDFld]  'assTransferHeader000', 'DesEntryType'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003372
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'TrnBankTrans000', 'Code', 100
	EXEC [prcAddCharFld] 'TrnBankTrans000', 'SecurityNumber', 100
	EXEC [prcAddCharFld] 'TrnBankTrans000', 'Notes', 250
	EXEC [prcAddGUIDFld] 'TrnBankTrans000', 'ExchangeGuid'
	EXEC [prcAddGUIDFld]	'assTransferHeader000', 'SrcEntryParent'
	EXEC [prcAddGUIDFld]	'assTransferHeader000', 'DesEntryParent'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003374
AS
	SET NOCOUNT ON 
	EXEC [prcAddFloatFld] 'ori000', 'BonusPostedQty', 0
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003375
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld]	'scpurchases000', 'OrderID'
	EXEC [prcAddFloatFld] 'scpurchases000', 'Points', 0
	EXEC [prcAddIntFld]	'scpurchases000', 'Type', 0
	EXEC [prcRenameFld]   'expQtyRepHdr000', 'BillGuid',     'InBillGuid'
	EXEC [prcRenameFld]   'expQtyRepHdr000', 'BillTypeGuid', 'InBillTypeGuid'
	EXEC [prcRenameFld]   'expQtyRepHdr000', 'StoreGuid',	  'InStoreGuid'
	EXEC [prcRenameFld]   'expQtyRepHdr000', 'RepDate',	  'InRepDate'
	EXEC [prcAddGUIDFld]  'expQtyRepHdr000', 'InAgentAcc'
	EXEC [prcAddGUIDFld]  'expQtyRepHdr000', 'OutBillGuid'
	EXEC [prcAddGUIDFld]  'expQtyRepHdr000', 'OutBillTypeGuid'
	EXEC [prcAddGUIDFld]  'expQtyRepHdr000', 'OutStoreGuid'
	EXEC prcAddDateFld  'expQtyRepHdr000', 'OutRepDate'
	EXEC [prcAddGUIDFld]  'expQtyRepHdr000', 'OutAgentAcc'
	EXEC [prcAddIntFld]   'expQtyRepHdr000', 'InGenBill'
	EXEC [prcAddIntFld]   'expQtyRepHdr000', 'OutGenBill'
	EXEC [prcAddFloatFld] 'MnPs000', 'Number'
	EXEC [prcAddGUIDFld]	'Psi000',  'operationGuid'
	EXEC [prcAddFloatFld] 'Psi000',  'deviation'
	EXEC [prcAddFloatFld] 'Psi000',  'Done'
	
	EXEC [prcAddCharFld] 'TrnExchangeTypes000', 'CashTerm', 100
	EXEC [prcAddCharFld] 'TrnExchangeTypes000', 'PayTerm', 100
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003376
AS
	SET NOCOUNT ON 
	EXEC [prcAddFloatFld] 'fm000', 'StandardTime', 0
	EXEC [prcAddFloatFld] 'Mn000', 'ActualTime', 0
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003382
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'TrntransferVoucher000', 'Reason', 250
	EXEC [prcAlterFld] 'TrnCloseCashierDetail000','Balance','FLOAT'
	EXEC [prcAddBitFld] 	'TrnExchange000','bSimple', '1'

	DECLARE @SQL VARCHAR(200)
	SET @SQL =	
		'UPDATE TrnExchange000    
		SET bSimple = 0 
		FROM TrnExchange000 AS Ex 
		INNER JOIN TrnExchangeDetail000 AS det ON ex.Guid = det.ExchangeGuid'

	EXEC (@SQL)
	
	EXEC [prcAddIntFld]  'DistPromotions000', 'Security'    
	EXEC [prcAddCharFld] 'DistPromotions000', 'Code', 100   
	EXEC [prcAddIntFld]  'DistPromotionsdetail000', 'MatType'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003385
AS
	SET NOCOUNT ON 
	EXEC [prcDropFld] 'TrnTransferVoucher000', 'ParentGUID'
	EXEC [prcDropFld] 'TrnStatementItems000', 'TransferTypeGuid'
	IF [dbo].[fnObjectExists]( 'TrnTransferTypes000') <> 0 
		EXEC( 'DROP TABLE TrnTransferTypes000')
		
	EXEC [prcAddIntFld]  'TrnTransferVoucher000', 'Closed'
		
	DECLARE @SQL VARCHAR(100)
	SET @SQL =	
		'DELETE BRT
		WHERE TableName = ''TrnTransferTypes000'''

	EXEC (@SQL)	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003389
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 'Distributor000', 'IsSync'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'BonusOne'
	EXEC [prcAddFloatFld] 'DistDeviceMt000', 'Bonus'

	EXEC [prcDropFld] 'TrnExchange000', 'CashType'
	EXEC [prcDropFld] 'TrnExchange000', 'PayType'
	EXEC [prcDropFld] 'TrnExchange000', 'CashDueDate'
	EXEC [prcDropFld] 'TrnExchange000', 'PayDueDate'
	EXEC [prcDropFld] 'TrnExchange000', 'CostVal'
	EXEC [prcDropFld] 'TrnExchange000', 'CostRatio'
	EXEC [prcDropFld] 'TrnExchange000', 'CostAcc'
	EXEC [prcDropFld] 'TrnExchange000', 'CostCurrencty'
	EXEC [prcDropFld] 'TrnExchange000', 'CostCurrencyVal'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003394 
AS
	SET NOCOUNT ON 
	EXEC prcAddBitFld 'TrnExchangeTypes000', 'bIncludeCurValRange'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003395
AS
	SET NOCOUNT ON 
	EXEC [prcAddGuidFld]	'evmi000', 'Guid'
	EXEC [prcAddGuidFld]	'evsi000', 'Guid'	
	DECLARE @SQL VARCHAR(100)
	SET @SQL = ' UPDATE evmi000 SET Guid = NewId()
				 UPDATE evsi000 SET Guid = NewId() '
	EXEC (@SQL)	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003396
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeOpenVIn'  , '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeOpenVOut' , '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeSenderApp', '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeSaveStIn' , '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodePrintStIn', '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeGenStIn'  , '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeModStIn'  , '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeSaveStOut', '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeModStOut' , '1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodePrintStOut','1'
	EXEC [prcAddBitFld] 	'TrnUserConfig000','bSecretCodeGenStOut',  '1'
	EXEC [prcAddGuidFld] 'POSOrder000', 'UserBillsID'
	EXEC [prcAddGuidFld] 'POSOrderTemp000', 'UserBillsID'

	--EXEC [prcAddGuidFld] 'TrnUserConfig000', 'DepartmentCostGuid'
	EXEC [prcAddGuidFld] 'TrnUserConfig000', 'CenterGuid'
	EXEC [prcAddGuidFld] 'TrnBranch000', 'CostGuid'
	EXEC [prcAddGuidFld] 'TrnOffice000', 'CostGuid'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003397
AS
	SET NOCOUNT ON 
	EXEC [prcAddFloatFld] 'TrnCloseCashierDetail000', 'CurrencyAvg', 0	
	EXEC [prcAddFloatFld] 'TrnDepositDetail000', 'CurrencyAvg', 0	
	EXEC [prcAddIntFld] 'nt000', 'bManualGenEntry'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003399
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'HosStay000', 'PersonCount'
	EXEC [prcAddCharFld] 'TrnSenderReceiver000', 'Nation', 250
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003400
AS
	SET NOCOUNT ON 
	EXEC [prcAddGuidFld] 'TrnTransferVoucher000', 'SenderUserGuid'
	EXEC [prcAddGuidFld] 'TrnTransferVoucher000', 'RecieverUserGuid'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003402
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'POSPaymentsPackage000', 'PayType'
	EXEC [prcAddGuidFld] 'TrnTransferVoucher000', 'ReciverBankGuid'
	EXEC [prcAddCharFld] 'TrnTransferVoucher000', 'RecieverBankAccountNum', 250
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003403
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'TrnVoucherPayInfo000', 'ActualReceiverNation', 250
	EXEC [prcAddCharFld] 'TrnVoucherPayInfo000', 'ActualReceiverAddress', 250

	DECLARE @Sql  VARCHAR(8000)
	SET  @Sql = 
			'INSERT INTO [FavAcc000]( [Guid], [AccGuid], [CostGuid], [UserGuid])
			SELECT 
				newid(), 
				CAST (SUBSTRING ( [value], 1, 36) as UNIQUEIDENTIFIER),
				CASE  SUBSTRING ( [value], 38, 36) when '''' THEN CAST( 0x00 as UNIQUEIDENTIFIER) ELSE CAST( SUBSTRING ( [value], 38, 36)  AS UNIQUEIDENTIFIER) END, 
				
				UserGuid 
			FROM 
				[op000]
			WHERE [name] LIKE ''%AmnCfg_Favorite Accounts%''
			DELETE [op000] WHERE [name] LIKE ''%AmnCfg_Favorite Accounts%'''
			
	EXEC(@Sql)
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003406
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]	'DistDeviceCm000', 'Unity'	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003407
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]  'TrnStatementTypes000', 'bChangeDestOffice'	
	EXEC [prcAddGUIDFld]   'TrnExchange000', 'EvlCurrency'
	EXEC [prcAddFloatFld]  'TrnExchange000', 'EvlCurrencyVal' , 1
	EXEC [prcAddIntFld]  'pl000', 'DeviceType'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003409
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]  'oit000', 'Security', 1
	EXEC [prcAddIntFld]  'evc000', 'Security', 1
	EXEC [prcAddIntFld]  'evs000', 'Security', 1
	EXEC [prcAddIntFld]  'evm000', 'Security', 1
	EXEC [prcAddIntFld]  'ordoc000', 'Security', 1
	EXEC [prcAddIntFld]  'POSOrderDiscount000', 'Type', 0
	EXEC [prcAddIntFld]  'POSOrderDiscountTemp000', 'Type', 0
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003412
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 	'Distributor000','AccessByRFID'  , '0'              
	EXEC [prcAddBitFld] 	'Distributor000','IgnoreNoDetailsVisits'  , '0'     
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003413
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]  'TrnStatementTypes000', 'bForBankTransfer'	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003414
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld]   'TrnExchangeTypes000', 'MngerGroupCurrencyAccGUID'
	EXEC ('UPDATE POSOrder000 SET Serial=1 WHERE Serial=0')
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003418
AS
	SET NOCOUNT ON 
	EXEC prcAddGuidFld   'DisTChTarget000', 'PeriodGUID'
	EXEC ('DELETE FROM DistChTarget000')
	IF [dbo].[fnObjectExists]('colch000.CurrentCurVal') = 0
	BEGIN
		EXEC [prcAddFloatFld] 'colch000', 'CurrentCurVal'
		
		EXEC('
			UPDATE [ColCh000]
			SET [CurrentCurVal] = ISNULL([dbo].[fnGetCurVal]([CurrencyGUID], [date]), 1)
			WHERE ISNULL([CurrentCurVal], 0) = 0')
	END	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003419
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'TrnBank000', 'PrintForm', 250
	IF [dbo].[fnObjectExists]('TrnExchangeTypes000.bIsManagerType') = 0
	BEGIN
		EXEC [prcAddBitFld]  'TrnExchangeTypes000', 'bIsManagerType', '0'
		EXEC('UPDATE TrnExchangeTypes000 SET bIsManagerType = ''1'' WHERE groupCurrencyAccGUID in (SELECT CAST(VALUE AS UNIQUEIDENTIFIER) FROM OP000 WHERE NAME LIKE ''TrnCfg_CurrencyAccount'')')
	END
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003420
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'TrnVoucherPayInfo000', 'MotherName', 250
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003421
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'ManMachines000', 'MachineName', 250
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003422
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]  'TrnNotify000', 'PersonKind'	
	EXEC [prcAddIntFld]  'DiscountCard000', 'Locked'	
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003423
AS
	SET NOCOUNT ON 
	EXEC prcAddGuidFld   'TrnVoucherProc000', 'UserGuid'	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003424
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]  'TrnTransferVoucher000', 'PrintTimes'
	EXEC [prcAddIntFld]  'DistCustTarget000', 'PriceType'
	EXEC [prcAddIntFld]  'DistDistributorTarget000', 'PriceType'
	EXEC prcAddGuidFld   'ac000', 'BalsheetGuid'
	EXEC [dbo].[prcDropFld] 'ac000', 'BalsheetType'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003425
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]  'RestOrderTemp000', 'Period'
	EXEC [prcAddIntFld]  'RestOrder000',     'Period'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003426
AS
	SET NOCOUNT ON 
	EXEC [prcAddGuidFld] 'POSOrder000', 'UserBillsID'
	EXEC [prcAddGuidFld] 'POSOrderTemp000', 'UserBillsID'
	EXEC [prcAddCharFld] 'TrnVoucherPayInfo000', 'BirthPlace', 250
	EXEC [prcAddDateFld] 'TrnVoucherPayInfo000', 'BirthDate'
	EXEC [prcAddCharFld] 'TrnVoucherPayInfo000', 'PayNotes', 250
	EXEC [prcAddGUIDFld] 'TrnVoucherPayInfo000', 'PayAccount'
	EXEC [prcAddBitFld] 'tt000', 'ClassBelongsToIn', '1'
	EXEC [prcAddBitFld] 'tt000', 'ClassBelongsToOut', '1'
	EXEC [prcAddIntFld]  'md000', 'bPrintInBill'
	EXEC [prcAddIntFld]  'md000', 'bPrintPriceInBill'
	EXEC [prcAddIntFld]  'md000', 'bSharedFld'
	EXEC('UPDATE md000 SET bPrintInBill = 1 , bPrintPriceInBill = 1')
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003428
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 'bt000', 'bNoExpiredDate', '0'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003431
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'TrnVoucherPayInfo000', 'PayRecieptCode', 250
	EXEC [prcAddCharFld] 'TrnTransferVoucher000', 'CashRecieptCode', 250
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003432
AS
	SET NOCOUNT ON 
	UPDATE [er000] 
	SET 
		[ParentType] = 13
	FROM 
		[er000] [er]
		INNER JOIN [ch000] [ch] ON [ch].[GUID] = [er].[ParentGUID]
	WHERE 
		([ch].[State] = 2) AND ([er].[ParentType] = 6)

	EXEC [prcAddIntFld] 'RestTaxes000', 'OrderType'
	EXEC [prcAddGUIDFld] 'RestTaxes000', 'DepartmentID'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003433
AS
	SET NOCOUNT ON 
	EXEC [prcAddBigIntFld] 'disgeneraltarget000', 'PeriodsMask'
	EXEC [prcAddFloatFld] 'distcusttarget000', 'CustDistRatio'
	EXEC [prcAddGUIDFld]  'TrnStatementTypes000', 'WagesAccGuid'
	EXEC [prcAddFloatFld] 'TrnStatementTypes000', 'WagesRatio'
	EXEC [prcAddBitFld]   'TrnStatementTypes000', 'bValBaseField', '1'
	EXEC [prcAddBigIntFld]	'pl000', 'VisiblePricesMask', 0
	EXEC [prcAddIntFld]	'pl000', 'ItemDiscType', 0
	EXEC [prcAddIntFld]	'pl000', 'DefaultPayType', 0
	EXEC [prcAddBitFld]	'pl000', 'CanChangePrice', '0'
	EXEC [prcAddBitFld]	'pl000', 'AccessByBarcode', '0'
	EXEC [prcAddBitFld]	'pl000', 'AccessByRFID', '0'
	EXEC [prcAddBigIntFld] 'pl000', 'BranchMask', 0
	EXEC [prcAddBitFld] 'pl000', 'OutNegative'  , '0'
	EXEC [prcAddIntFld] 'TrnUserConfig000',  'FldTRANSNUMBER' ,       '1'	
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldTRANSCODE'   ,       '2'		
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldRECEIVER'    ,       '3'		
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldTRANSDATE'   ,       '4'		
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldBRANCHSEND'	 ,       '5' 
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldBRANCHSENDTO',	     '6'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldTRANSFERSTATE',      '7'	
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldMUSTCASHEDAMOUNT',   '8'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldCASHCURRENCY',       '9'	
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldMUSTPAIDAMOUNT',     '10'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldPAYCURRENCYNAME',    '11'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldAMOUNT'         ,    '0'		
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldCASHCURRENCYVAL',    '0'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldTRANSFEREDAMNT' ,    '0'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldTRANSFERCURRENCY',   '0'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldTRANSFERVAL'	 ,   '0'
	EXEC [prcAddIntFld] 'TrnUserConfig000',	'FldPAYCURRENCYVAL'  ,   '0'
	
	EXEC [prcAddIntFld] 'HosFileFlds000',	'FldChecks'			,	 '0'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003435
AS
	SET NOCOUNT ON 
	EXEC [prcAddFloatFld] 'md000', 'BounsFld'
	EXEC [prcAddGUIDFld] 'TrnTransferVoucher000', 'UpdatedReciever1'
	EXEC [prcAddGUIDFld] 'TrnTransferVoucher000', 'UpdatedReciever2'
	EXEC [prcAddBitFld] 'mt000', 'CalPriceFromDetail','0'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003437
AS
	SET NOCOUNT ON 
	EXEC [prcAddDateFld] 'hosReservationDetails000', 'CancleDate'
	EXEC [prcAddCharFld] 'hosPFile000', 'FileNotes', 1000
	EXEC [prcAddBitFld] 'TrnTransferVoucher000', 'bPayedAnyBranch','0'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003439
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld] 'TrnVoucherPayInfo000', 'PaymentGuid'	
	EXEC [prcAddGUIDFld] 'TrnVoucherPayeds000',	 'PayerUserGuid'
	EXEC [prcAddIntFld]  'TrnUserConfig000',	'FldRECEIVER2'    ,       '0'
	EXEC [prcAddCharFld] 'TrnExchange000',		'Reason', 100
	EXEC [prcAddGUIDFld] 'RestDiscTaxTemp000',	 'DepartmentID'
	EXEC [prcAddGUIDFld] 'RestDiscTax000',	 'DepartmentID'
	EXEC [prcAddCharFld] 'PSI000', 'orderNo', 250
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003440
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 'ch000', 'TransferCheck', '0'
	EXEC [prcAddGUIDFld] 'pospaymentspackageCheck000',	 'CurrencyID'
	EXEC [prcAddFloatFld] 'pospaymentspackageCheck000',	 'CurrencyValue'
	EXEC ('UPDATE pospaymentspackageCheck000 SET CurrencyID=se.CurID, CurrencyValue=se.CurVal From posCheckItem000 se
		WHERE se.CheckID=[Type] AND CurrencyID=0x0')
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003442
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 'ce000', 'IsPrinted', '0'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003444
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]			'SpecialOffer000',		'DiscountType'
	EXEC [prcAddBigIntFld]		'specialoffer000',		'BranchMask'
	EXEC [prcChangeDefault]		'cu000','DefPrice',		'0x80'
	EXEC [prcAddGUIDFld]		'distpromotions000',	'CustCondGUID'	
	EXEC [prcAddBigIntFld]		'distpromotions000',	'branchMask'   
	EXEC [prcAddGUIDFld]		'DistDisc000',			'CustCondGUID'
	EXEC [prcAddBigIntFld]		'DistDisc000',			'branchMask'
	EXEC [prcAddIntFld]			'DistDeviceBt000',		'VatSystem'
	EXEC [prcAddFloatFld]		'DistDeviceBu000',		'VAT'
	EXEC [prcAddFloatFld]		'DistDeviceBi000',		'VAT'
	EXEC [prcAddFloatFld]		'DistDeviceMt000',		'VAT'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003446
AS
	SET NOCOUNT ON 
	UPDATE [er000] 
	SET [ParentNumber] = [ch].[Number]
	FROM 
		[er000] [er] 
		INNER JOIN [ch000] [ch] ON [ch].[Guid] = [er].[ParentGuid] 
	WHERE [er].[ParentNumber] != [ch].[Number]
	
	EXEC [prcAddCharFld] 'DistDeviceCu000', 'Promotions', 200
	EXEC [prcAddCharFld] 'DistDeviceCu000', 'Discounts', 200
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003447
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld] 'assTransferDetails000', 'SourceCost'
	EXEC [prcAddGUIDFld] 'assTransferDetails000', 'DestinationCost'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003452
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'TrnStatementItems000', 'Reason', 250

	DECLARE @Sql  VARCHAR(150)
	SET  @Sql ='UPDATE TrnExchange000 
	SET EvlCurrency = (SELECT GUID FROM My000 WHERE Number = 1)
	WHERE EvlCurrency = 0X0'
	EXEC(@Sql)
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003453
AS
	SET NOCOUNT ON 
	EXEC [prcRenameFld] 'oit000', 'PostToBill', 'Operation'
	EXEC [prcAddIntFld]	'Department000',	'PrinterID'
	UPDATE rch000 SET [TYPE] = CASE [TYPE] WHEN -2147479360 THEN  536875200 WHEN -2147467216 THEN 536887344 WHEN -2147466784 THEN 536887776 ELSE [Type] END
	WHERE [TYPE] IN (-2147479360, -2147467216,-2147466784)
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003460
AS
	SET NOCOUNT ON 
	EXEC [prcRenameFld] 'TrnStatementTypes000', 'Cur1', 'ExchangeCurrency'
	EXEC [prcRenameFld] 'TrnStatementTypes000', 'Cur2', 'PayCurrency'
	EXEC [prcAddFloatFld] 'TrnStatementTypes000', 'ExchangeCurrencyVal'
	EXEC [prcAddFloatFld] 'TrnStatementTypes000', 'PayCurrencyVal'
	EXEC [prcAddGuidFld] 'TrnUserConfig000', 'CenterGuid'
	--EXEC [prcRenameFld] 'TrnUserConfig000', 'DepartmentCostGuid', 'CenterGuid'
	EXEC [prcAddGUIDFld]	'TrnTransferVoucher000', 'SenderCenterGuid'
	EXEC [prcAddGUIDFld]	'TrnTransferVoucher000', 'RecieverCenterGuid'		
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003464
AS
	SET NOCOUNT ON 
	EXEC prcAddFld 'DistDeviceBu000', 'CurNumber', 'INT DEFAULT(0)'
	EXEC prcAddFld 'DistDeviceBu000', 'CurVal', 'FLOAT DEFAULT(0)'

	IF dbo.fnObjectExists('or000') <> 0 AND NOT EXISTS( SELECT [GUID] FROM [op000] WHERE [Name] = 'Rest upgrade from 2004 to 8')
		BEGIN
		EXEC ('
			INSERT INTO  [RestVendor000] ([Number],[GUID],[Type]
					  ,[Code],[Name],[LatinName],[Phone],[Address]
					  ,[Certificate],[BirthDate],[Work]
					  ,[Notes],[Security],[AccountGUID],[BranchMask])
					  SELECT [Number],[GUID],[Type] - 1
					  ,[Code],[Name],[LatinName],[Phone],[Address]
					  ,[Cirtificate],[Date],[Work],[Notes],[Security]
				  ,[AccountGUID],[BranchMask]
			FROM [Vn000]
			INSERT INTO [RestDepartment000]( [Number]
				  ,[GUID] ,[Code],[Name],[LatinName]      
				  ,[Notes],[Security],[BranchMask])  
			SELECT [Number],[GUID],[Code],[Name]
				  ,[LatinName],[Notes],[Security],[BranchMask]
			FROM [od000]
			INSERT INTO  [RestTable000]([Number]
				  ,[GUID],[Code],[Cover]
				  ,[DepartmentID],[Security],[BranchMask])
			SELECT [Number]
				  ,[GUID]
				  ,[Code]
				  ,[Cover]
				  ,[DepartGUID]
				  ,[Security]      
				  ,[BranchMask]
			  FROM [tb000]
			INSERT INTO [RestKitchen000] ([Number]
				  ,[GUID],[Code],[Name],[LatinName],[Chief]
				  ,[Work],[Notes],[PrinterID],[Security],[BranchMask])  
			SELECT [Number],[GUID],[Code],[Name],[LatinName]
				  ,[ChefName],[KitchenSpec],[Notes],-1,[Security]
				  ,[BranchMask]
			FROM [kn000]')
		IF dbo.fnObjectExists( 'POSSpecialOffer000') <> 0
			EXEC ('
				INSERT INTO [SpecialOffer000] ([Number]
				  ,[Guid],[Name],[CustomersAccountID]
				  ,[AccountID],[MatAccountID],[DiscountAccountID],[DivDiscount]
				  ,[Type],[Condition],[Qty],[StartDate],[EndDate]
				  ,[Discount],[Security],[Active],[DiscountType],[BranchMask])
				SELECT [Number]
					  ,[Guid],[Name],0x0
					  ,[AccountID],0x0,0x0,0,0,[Type]
					  ,[Qty],[StartDate],[EndDate],[Discount]
					  ,[Security],1,1,[BranchMask]
				FROM [POSSpecialOffer000]
				INSERT INTO [SpecialOfferDetails000]([Number]
					  ,[Guid]
					  ,[ParentID]
					  ,[MatID]
					  ,[Qty]
					  ,[Unit]
					  ,[Group])
				SELECT [Number]
					  ,[Guid],[ParentID],[MatID],[Qty],1,0
				FROM [POSSpecialOfferDetails000]  
				  ')	
		EXEC ('INSERT INTO op000 (Guid, Name, Value) VALUES (newID(), ''Rest upgrade from 2004 to 8'', ''1'')')
	END
	
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003467
AS
	SET NOCOUNT ON 
	EXECUTE [prcAddCharFld] 'nt000', 'MenuName', 250
	EXECUTE [prcAddCharFld] 'nt000', 'MenuLatinName', 250
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003469
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 'Distributor000', 'ExportCustAccDays', '0'
	EXEC [prcAddIntFld] 'Distributor000', 'ExportCustAccDaysNumber'
	EXEC [prcAddIntFld] 'Distributor000', 'OutRouteVisitsNumber', 500
	EXEC [prcAddBitFld] 'Distributor000', 'ExportDetailedCustAcc', '0'
	EXEC [prcAddBitFld] 'Distributor000', 'ExportCustInRouteOnly', '0'
	EXEC [prcAddBitFld] 'Distributor000', 'CanUpdateBill', '0'
	EXEC [prcAddBitFld] 'Distributor000', 'CanDeleteBill', '1'                     
	EXEC [prcAddFloatFld] 'DistDeviceStatement000', 'Qty'
	EXEC [prcAddCharFld] 'DistDeviceStatement000', 'Unit', 250
	EXEC [prcAddFloatFld] 'DistDeviceStatement000', 'Price'
	EXEC [prcAddIntFld]  'DistDeviceStatement000', 'ItemNumber'
	
	EXEC [prcAddIntFld]  'TrnTransferVoucher000', 'PayPrintTimes'	
	
	IF [dbo].[fnObjectExists]('AssemBillType000.bOldAssemType') = 0
		EXEC [prcAddBitFld] 'AssemBillType000', 'bOldAssemType', '0'
	IF [dbo].[fnObjectExists]('AssemBillType000.bAllowModify') = 0
		EXEC [prcAddBitFld] 'AssemBillType000', 'bAllowModify', '0'
		
	EXEC ('INSERT INTO AssemBillType000 (Guid, OutTypeGuid, InTypeGuid, FinalVirtualTypeGUID, FinalTypeGUID)
		   SELECT 	NEWID(),
					tt.OutTypeGUID ,
					tt.InTypeGUID,
					0x00,
					0x00 	
		   FROM tt000 tt INNER JOIN bt000 bt on bt.Guid = OutTypeGUID 
		   WHERE bt.Type = 7 
		   
		   INSERT INTO AssemBill000 (GUID, OutBillGUID, InBillGUID, FinalBillGuid, Bold)
		   SELECT  NEWID(),
					ts.OutBillGUID,
					ts.InBillGUID,
					0x0,
					1
		   FROM ts000 ts INNER JOIN bu000 bu ON bu.GUID = ts.OutBillGuid
		                 INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
		   WHERE bt.Type = 7
		   
		   DELETE ts 
		   FROM ts000 ts INNER JOIN bu000 bu ON bu.GUID = ts.OutBillGuid
		    			 INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
		   WHERE bt.Type = 7
		   
		   DELETE tt 
		   FROM tt000 tt INNER JOIN bt000 bt on bt.Guid = OutTypeGUID 
		   WHERE bt.Type = 7
		   UPDATE AssemBillType000
		   SET bOldAssemType = 1,
			   ballowModify = 0
		   
		   INSERT INTO bmd000 (GUID, MatGUID, BiGUID, ParentMatGUID, Qty, BounsFld, Unity,Price, DiscRatio, ExtraRatio,
							   Notes, Class, bPrintInBill, bPrintPriceInBill,BiParentGUID, bFlexible, bRequired, bSharedFld)
		   SELECT NEWID(),
				  mt.GUID,
				  bi.GUID,--TO BE SURE OF
				  mt1.GUID,
				  bi.Qty,
				  bi.BonusQnt,
				  bi.Unity,
				  bi.Price,
				  CASE WHEN bi.Price = 0 THEN 0
				       ELSE (100 * bi.Discount)/(bi.Price * bi.Qty)
				  END,
				  CASE WHEN bi.Price = 0 THEN 0
					   ELSE (100 * bi.Extra)/(bi.Price * bi.Qty)
				  END,
				  bi.Notes,
				  bi.ClassPtr,
				  md.bPrintInBill,
				  md.bPrintPriceInBill,
				  bi.ParentGUID,
				  md.bFlexible,
				  md.bRequired,
				  md.bSharedFld
		   FROM bi000 bi INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
						 INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
						 INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID
						 INNER JOIN md000 md ON md.MatGUID = bi.MatGUID
						 INNER JOIN mt000 mt1 ON mt1.GUID = md.ParentGUID
		   WHERE bt.Type = 7
		   
		   INSERT INTO BillOperationState000 (GUID, InBillGUID, OutBillGUID, UserGUID, BuState)
		   SELECT  NEWID(), 
				   ab.InBillGUID, 
				   ab.OutBillGUID,
				   bu.UserGUID,
				   3 --Bills are stored as (Assembled = STATE 3)
		   FROM AssemBill000 ab INNER JOIN bu000 bu ON bu.GUID = ab.OutBillGUID')
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003471
AS
	SET NOCOUNT ON 
	EXEC [prcRenameFld] 'TrnCurrencyBalance000', 'BaseBalacne', 'CurBalance'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003472
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]	'POSPaymentsPackageCheck000',	'NewVoucher'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003473
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld] 'TrnVoucherProc000', 'CenterGuid'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003479
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'TrnExchange000', 'InternalNumber'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003486
AS
	SET NOCOUNT ON 
	EXECUTE('declare @ngGuid  uniqueidentifier
		declare @ng_MatGuid uniqueidentifier
		declare @ng_mt_Code nvarchar(100)
		declare @ng_mt_Name nvarchar(250)
		declare @ni_mt_Guid uniqueidentifier
		declare @ni_mt_Name nvarchar(250)
		declare @mi_mt_qty float
		declare @mi_mt_unity int
		declare @InStoreGUID uniqueidentifier
		declare @OutStoreGUID uniqueidentifier
		declare @currencyGuid uniqueidentifier 
		declare @ni_mt_Code nvarchar(100)
		declare @mn_Num int
		declare @fm_Num int
		declare @mi_number int
		declare @MediatorAcc  uniqueidentifier
		declare @mn_Guid  uniqueidentifier

		IF ISNULL(OBJECT_ID(''ng000''), 0) > 0 AND ISNULL(OBJECT_ID(''ni000''), 0) > 0
		BEGIN
			select @InStoreGUID = bt.defStoreGuid from [bt000] bt 
				where SortNum = 5
			select @OutStoreGUID = bt.defStoreGuid from [bt000] bt 
				where SortNum = 6
			select @currencyGuid = GUID from [my000] my
				where CurrencyVal = 1
			select @MediatorAcc = value from [op000] 
				where name like ''AmnRest_MediatorAccID''	
			declare ngItems_Cur cursor for
				select ng.Guid ng_Guid,  ng.MatGuid ng_MatGuid , mt.[Name] gn_mt_Name
					,mt.Code ng_mt_Code
				from ng000 ng 
					inner join mt000 mt on mt.Guid = ng.MatGuid	
					where ng.guid not in (select guid from fm000)	

			open ngItems_Cur 
			fetch next from ngItems_Cur into @ngGuid , @ng_MatGuid ,  @ng_mt_Name , @ng_mt_Code 
			while(@@fetch_status = 0)
			begin
					select @fm_Num = isnull(max(ISNULL(number ,0)), 0)+1 from fm000
					insert into fm000(Number, Guid, name , code ,ParentForm) 					
						values(@fm_Num , @ngGuid ,@ng_mt_Name ,  @ng_mt_Code , 0x0)
					select @mn_Num = isnull( max(isnull(number,0)), 0) + 1 from mn000
					set @mn_Guid = newid()
					insert into mn000(number, Guid ,Security,  CurrencyVal , formGuid, InStoreGuid, outStoreGuid , CurrencyGuid , InAccountGUID , OutAccountGUID
							, InCostGUID , OutCostGUID , InTempAccGUID , OutTempAccGUID , BranchGUID , CostSemiGUID )
							values(@mn_Num, @mn_Guid ,1, 1,@ngGuid,@InStoreGUID,@OutStoreGUID,@currencyGuid , 0x0,0x0,0x0,0x0,@MediatorAcc , @MediatorAcc,0x0,0x0   )

					select @mi_number = isnull(max(ISNULL(number ,0)), 0)+1 from mi000
				
					insert into mi000 (type, number, unity, qty,CurrencyVal  ,parentGuid, MatGuid, storeGuid, CurrencyGUID  )
							values(0,@mi_number ,1 , 1, 1, @mn_Guid , @ng_MatGuid , @InStoreGUID , @CurrencyGUID)				 
					 insert into mi000 (type , number , unity, qty,CurrencyVal  ,parentGuid, MatGuid, storeGuid, CurrencyGUID  )
							select  1 , ni.number , ni.unity ni_unity,  ni.qty ni_qty , 1 ,@mn_Guid , ni.MatGuid, @OutStoreGUID ,@CurrencyGUID 
							from [ni000] ni 
							inner join mt000 mt on mt.Guid = ni.MatGuid	
							where  ni.ParentGuid = @ngGuid		 	
				  fetch from ngItems_Cur into  @ngGuid ,@ng_MatGuid ,@ng_mt_Name,  @ng_mt_Code 
			end

			CLOSE ngItems_Cur
			DEALLOCATE ngItems_Cur
		END')
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003489
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'TrnExchangeDetail000', 'InternalNumber'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003493
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld]	'Distributor000', 'EndVisitByBarcode', '0'
	SELECT 	Guid AS DistGuid, UseStockOfCust, UseShelfShare, UseActivity, UseCustTarget, ShowCustInfo INTO #TempFields	FROM Distributor000
	
	EXEC [prcAlterFld] 'Distributor000', 'UseStockOfCust', 'INT', 0, '0' 
	EXEC [prcAlterFld] 'Distributor000', 'UseShelfShare', 'INT', 0, '0'
	EXEC [prcAlterFld] 'Distributor000', 'UseActivity', 'INT', 0, '0'
	EXEC [prcAlterFld] 'Distributor000', 'UseCustTarget', 'INT', 0, '0'
	EXEC [prcAlterFld] 'Distributor000', 'ShowCustInfo', 'INT', 0, '0'
	
	UPDATE Distributor000
		SET UseStockOfCust = CASE t.UseStockOfCust WHEN 0 THEN 0 ELSE 1 END,
			UseShelfShare = CASE t.UseShelfShare WHEN 0 THEN 0 ELSE 1 END,
			UseActivity = CASE t.UseActivity WHEN 0 THEN 0 ELSE 1 END,
			UseCustTarget = CASE t.UseCustTarget WHEN 0 THEN 0 ELSE 1 END,
			ShowCustInfo = CASE t.ShowCustInfo WHEN 0 THEN 0 ELSE 1 END
		FROM
			Distributor000 AS d
			INNER JOIN #TempFields AS t ON d.Guid = t.DistGuid		
	DROP TABLE #TempFields
	
	EXEC [prcAddIntFld] 'Distributor000', 'ShowQuestionnaire'
	EXEC [prcAddIntFld] 'Distributor000', 'ShowBills', 1
	EXEC [prcAddIntFld] 'Distributor000', 'ShowEntries', 1
	EXEC [prcAddIntFld] 'Distributor000', 'ShowRequiredMaterials'
	EXEC [prcAddBitFld]	'Distributor000', 'SpecifyOrder', '0'
	EXEC [prcAddCharFld] 'DistPromotions000', 'ImagePath', 1000      
	EXEC [prcAddGuidFld] 'DistPromotions000', 'MatCondGUID'			
	EXEC [prcAddCharFld] 'DistDevicePro000', 'ImagePath', 1000
	EXEC [prcAddFloatFld] 'RestCommand000', 'Value'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003494
AS
	SET NOCOUNT ON 
	EXEC [prcAddBitFld]	'mt000', 'ForceInExpire', '0'
	EXEC [prcAddBitFld]	'mt000', 'ForceOutExpire', '0'
	EXEC [prcAddGUIDFld] 'dp000', 'Ad_Guid'
	EXEC [prcAddGUIDFld] 'dp000', 'SrcGuid'
	
	Exec prcAddFld 'AssemBillType000', 'Name','[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'AssemBillType000', 'AbbName','[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'AssemBillType000', 'LatinName','[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'AssemBillType000', 'AbbLatinName','[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
###########################################################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10003497
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld]	'CFFlds000', 'IsUnique', 0
	
	EXEC [prcAddFloatFld]	'TrnMh000',	'BuyTransferVal'
	EXEC [prcAddFloatFld]	'TrnMh000',	'SellTransferVal'
	
	EXEC [prcAddBitFld]		'bt000',	'bForceCost'
	EXEC [prcAddIntFld]		'sm000',	'DiscountType', 0
	
	EXEC [prcAddIntFld] 'Distributor000', 'LastBuNumber', 0
	EXEC [prcAddIntFld] 'Distributor000', 'LastEnNumber', 0
	EXEC [prcAddCharFld] 'Distributor000', 'UploadPassword', 100
	EXEC [prcAddIntFld] 'PDAStTr_Bu', 'Number', 0
	EXEC [prcAddBitFld]		'bt000',	'bForcePayType'
	
	EXEC [prcAddBitFld] 'AssemBillType000', 'bDefTypePrice', '1'
	
	EXEC [prcAddIntFld] 'Ad000', 'Age', 0
    EXEC [prcAddGUIDFld] 'assTransferReportHeader000', 'MidAccDesGuid'
    EXEC [prcAddIntFld] 'assTransferReportHeader000', 'IncludeAllCostCenters', 0
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003498
AS
	SET NOCOUNT ON 
	EXEC [prcAddCharFld] 'DistDeviceCu000', 'Routes', 20
	EXEC [prcAddCharFld] 'DistDeviceMt000', 'Promotions', 200
	EXEC [prcAddCharFld] 'DistDeviceMt000', 'Discounts', 200
	Exec [prcAddBitFld]  'DistDisc000', 'DiscForItems'	
	EXEC [prcAddGUIDFld] 'DistDisc000',	'MatCondGUID'
	EXEC [prcAddGUIDFld] 'SpecialOffer000',	'CustCondID'
	EXEC [prcAddDateFld] 'mt000', 'CreateDate'
	EXEC [prcAlterFld]	'TrnParticipator000', 'ParticipateRate', 'FLOAT'
	EXEC [prcAlterFld]	'TrnParticipator000', 'ParticipateVal', 'FLOAT'
	EXEC [prcAddBitFld]	'TrnTransferVoucher000', 'IsRecycled'
	
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003499
AS
	SET NOCOUNT ON 
	EXEC [prcAlterFld]		'TrnTransferVoucher000', 'CurrencyVal', 'FLOAT'
	EXEC [prcAddFloatFld]	'TrnTransferVoucher000', 'RoundAmount'
	EXEC [prcAddFloatFld]	'TrnTransferVoucher000', 'ReturnAmount'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003500
AS
	SET NOCOUNT ON 
	EXEC prcAddCharFld 'DistCm000', 'Notes', 100
	EXEC prcAddFld 'DistDeviceCm000', 'Notes', '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXEC ('DELETE op000 WHERE Name like ''AmnPOS%'' OR Name like ''AmnRest%''')	
	EXEC [prcAddGUIDFld] 'RestVendor000',	'DepartID'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003501
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'DiscountTypesCard000', 'IsFinishedDate' , 0
	IF [dbo].[fnObjectExists]('AssemBillType000.bOldAssemType') = 0
		EXEC [prcAddBitFld] 'AssemBillType000', 'bOldAssemType', '0'
	IF [dbo].[fnObjectExists]('AssemBillType000.bAllowModify') = 0
		EXEC [prcAddBitFld] 'AssemBillType000', 'bAllowModify', '0'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003502
AS
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'BLMain000', 'QuantityPrec' , 0
	
	EXEC [prcAddBitFld] 'btstateorder000', 'bLock', '0'
	EXEC [prcAddGUIDFld] 'bmd000', 'AssemInBillGuid'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003506
AS
	SET NOCOUNT ON 
	EXEC prcAddCharFld 'DistQuestionnaire000', 'Code', 255
	EXEC prcAddCharFld 'DistQuestionnaire000', 'Name', 255
	EXEC prcAddIntFld  'DistQuestionnaire000', 'Security'
	IF [dbo].[fnObjectExists]('DistQuestionnaire000.GroupGuid') = 1
		EXEC ('	UPDATE DistQuestionnaire000 SET Name = gr.Name FROM 
				DistQuestionnaire000 AS dq INNER JOIN gr000 AS gr ON gr.Guid = dq.GroupGuid
			  ')
	EXEC prcDropFld 'DistQuestionnaire000', 'GroupGuid'
	EXEC [prcAddBitFld] 'bt000', 'bForceDate'

	EXEC prcDropTable 'DistDeviceSn000'	
	
	IF [dbo].[fnObjectExists]('bmd000.AssemInBillGuid') = 0
		EXEC [prcAddGUIDFld] 'bmd000', 'AssemInBillGuid'
	
	EXEC ('	SELECT InBillGUID, OutBillGUID
			INTO #t1							
			FROM AssemBill000
			WHERE OutBillGUID IN
				(SELECT BiParentGUID FROM bmd000 WHERE AssemInBillGuid = 0x00)


			UPDATE bmd000
			SET AssemInBillGuid = t1.InBillGUID,
				BiParentGUID = 0x00
			FROM bmd000 bmd
				INNER JOIN #t1 t1 ON t1.OutBillGUID = bmd.BiParentGUID
			WHERE AssemInBillGuid = 0x00

			SELECT MatGUID,
				   COUNT(*) RepMatCnt
			INTO #AssMatGUIDS
			FROM bi000
				INNER JOIN #t1 t1 ON t1.InBillGUID = bi000.ParentGUID
			GROUP BY MatGUID
			HAVING COUNT(*)>1


			SELECT DISTINCT A.MatGUID,
				   A.RepMatCnt,
				   ParentGUID BillGuid
			INTO #AssemMatGUIDS
			FROM bi000 bi
				INNER JOIN #t1 t1 ON t1.InBillGUID = bi.ParentGUID
				INNER JOIN #AssMatGUIDS A ON A.MatGUID = bi.MatGUID

			DECLARE @COUNT INT
			SELECT @COUNT = COUNT(*) FROM #AssemMatGUIDS

			IF( @COUNT > 0 )
			BEGIN

				DECLARE @repMatCurs		CURSOR,
						@repMatGUID		UNIQUEIDENTIFIER,
						@repCnt			INT,
						@InBillGUID		UNIQUEIDENTIFIER--,
						
				SET @repMatCurs = CURSOR FAST_FORWARD FOR 
								  SELECT *
								  FROM #AssemMatGUIDS
											 
				OPEN @repMatCurs FETCH FROM @repMatCurs INTO @repMatGUID,@repCnt,@InBillGUID

				WHILE @@FETCH_STATUS = 0
				BEGIN
				
					DECLARE @bmdMatsCurs CURSOR,
							@bmdGUID	 UNIQUEIDENTIFIER,
							@bmdMatGUID  UNIQUEIDENTIFIER

					SET @bmdMatsCurs = CURSOR FAST_FORWARD FOR 
									   SELECT GUID,
											  MatGUID
									   FROM bmd000
									   WHERE ParentMatGUID = @repMatGUID
									   AND AssemInBillGuid = @InBillGUID
									   ORDER BY MatGUID,Qty
									   
					SELECT bi.GUID
					INTO #BiMatGUIDS
					FROM #AssemMatGUIDS A INNER JOIN bi000 bi ON (bi.MatGUID = A.MatGUID 
															  AND bi.ParentGUID = A.BillGuid)
					WHERE bi.ParentGUID = @InBillGUID 
					ORDER BY bi.Qty
					
					OPEN @bmdMatsCurs FETCH FROM @bmdMatsCurs INTO @bmdGUID,@bmdMatGUID
					
					CREATE TABLE #Mats (
						MatGUID		UNIQUEIDENTIFIER,
						ScanMatCnt	INT)
					
					CREATE TABLE #UsedBiGUIDS (
						AssemMatBiGUID	UNIQUEIDENTIFIER,
						MatGUID			UNIQUEIDENTIFIER)
						
					DECLARE @Found INT
					SET @Found = 0
					
					WHILE @@FETCH_STATUS = 0
					BEGIN
						
						SELECT @Found = COUNT(*)
						FROM #Mats
						WHERE MatGUID = @bmdMatGUID
						
						IF (@Found = 0)
						BEGIN
							DECLARE @ParentBiGUID UNIQUEIDENTIFIER
							SELECT TOP 1 @ParentBiGUID = GUID FROM #BiMatGUIDS
							
							INSERT INTO #Mats VALUES (@bmdMatGUID,1)
							INSERT INTO #UsedBiGUIDS VALUES (@ParentBiGUID, @bmdMatGUID)
							
							UPDATE bmd000 
							SET BiParentGUID = @ParentBiGUID
							WHERE GUID = @bmdGUID
						END
						ELSE
						BEGIN
							UPDATE #Mats SET ScanMatCnt = ScanMatCnt +1
							WHERE MatGUID = @bmdMatGUID
							
							DECLARE @UsedBiGUID UNIQUEIDENTIFIER
							
							SELECT TOP 1 @UsedBiGUID = GUID 
							FROM #BiMatGUIDS 
							WHERE GUID NOT IN (SELECT AssemMatBiGUID FROM #UsedBiGUIDS WHERE MatGUID = @bmdMatGUID)
														
							INSERT INTO #UsedBiGUIDS VALUES (@UsedBiGUID , @bmdMatGUID)
							
							UPDATE bmd000
							SET BiParentGUID = @UsedBiGUID
							WHERE GUID = @bmdGUID
						END
						
						FETCH FROM @bmdMatsCurs INTO @bmdGUID,@bmdMatGUID
					END
					CLOSE @bmdMatsCurs
					DEALLOCATE @bmdMatsCurs
					DROP TABLE #BiMatGUIDS
					DROP TABLE #Mats
					DROP TABLE #UsedBiGUIDS
					FETCH FROM @repMatCurs INTO @repMatGUID,@repCnt,@InBillGUID
				END
				CLOSE @repMatCurs
				DEALLOCATE @repMatCurs
			END

			UPDATE bmd000 
			SET BiParentGUID = bi.GUID
			FROM bmd000 bmd 
			INNER JOIN bi000 bi ON bi.ParentGUID = bmd.AssemInBillGuid AND bi.MatGUID = bmd.ParentMatGUID
			WHERE bmd.BiParentGUID = 0x00 ')
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003507
AS
	SET NOCOUNT ON 
	EXEC ('	SELECT	OutBillGUID,
					InBillGUID,
					bu.StoreGUID OutStoreGUID,
					bu1.StoreGUID InStoreGUID,
					bu.IsPosted IsOutBillPosted,
					bu1.IsPosted IsInBillPosted
			INTO #AssemBillsWithStores
			FROM AssemBill000 a INNER JOIN bu000 bu ON bu.GUID = A.OutBillGUID
			INNER JOIN bu000 bu1 ON bu1.GUID = A.InBillGUID

			SELECT InBillGUID
			INTO #PostedBills
			FROM #AssemBillsWithStores 
			WHERE IsInBillPosted <> 0

			UPDATE bu000
			SET IsPosted = 0
			WHERE GUID IN (SELECT InBillGUID FROM #PostedBills)


			UPDATE bi000
			SET StoreGUID = bu.StoreGUID
			FROM bi000 bi
			INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
			WHERE bi.ParentGUID IN (SELECT InBillGUID FROM #AssemBillsWithStores)
			AND bi.StoreGUID = (SELECT StoreGUID FROM bu000 WHERE GUID = (
											SELECT OutBillGUID FROM #AssemBillsWithStores WHERE InBillGUID = bi.ParentGUID))
										
			UPDATE bu000
			SET IsPosted = 1
			WHERE GUID IN (SELECT InBillGUID FROM #PostedBills)')
			
			EXEC prcAddIntFld 'FavAcc000', 'Num'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003508
AS
	SET NOCOUNT ON 
	EXEC	prcAddGUIDFld 'DistPaid000', 'SalesManGuid'
	EXEC	prcAddGUIDFld 'DistPaid000', 'EntryTypeGuid'
	EXEC	[prcAddBitFld] 'CustomReport000', 'ApplyStyle', '0'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003509
AS
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld] 'ax000', 'EntryTypeGuid'

	UPDATE op000 
	SET Value = REPLACE(Value, '''''', '''')
	WHERE [Name] LIKE 'AmnCfg_HTML_Panel_%'
	
	EXEC('DELETE FROM ORADDINFO000 WHERE ParentGuid NOT IN 
	     (SELECT bu.GUID FROM bt000 bt INNER JOIN bu000 bu ON bt.GUID = bu.TypeGUID WHERE bt.Type IN (5, 6))')

	EXEC prcAlterFld 'OrAddInfo000', 'Finished', 'INT', 1, '0'

	EXEC('UPDATE OrAddInfo000 
		SET Finished = 2 
		WHERE ParentGuid IN (SELECT oq.OrderGuid  
							 FROM 
								(SELECT 
									bu.Guid      AS OrderGuid,  
									SUM(bi.Qty)  AS OrderQty 
								FROM   
									bt000 AS bt
									INNER JOIN bu000  AS bu  ON bt.GUID = bu.TypeGUID
									INNER JOIN bi000  AS bi  ON bi.ParentGuid = bu.Guid
								WHERE bt.Type IN (5, 6)
								GROUP BY bu.Guid ) AS oq 
								
								INNER JOIN 
								
								(SELECT 
									bu.GUID   AS OrderGuid, 
									ISNULL((SELECT SUM(ISNULL(ORI.Qty, 0))					
											FROM ori000 ORI
											WHERE ORI.POGuid = bu.GUID AND ORI.TypeGuid = (SELECT TOP 1 OIT.Guid 
																						   FROM oit000 OIT INNER JOIN oitvs000 OITVS ON OIT.Guid = OITVS.ParentGuid 
																						   WHERE OITVS.OtGuid = bt.GUID AND OITVS.Selected = 1 ORDER BY OIT.PostQty DESC
																						   )
									), 0) AS AchievedQty 
								FROM  
									bt000 AS bt
									INNER JOIN bu000  AS bu  ON bt.GUID = bu.TypeGUID
								WHERE bt.Type IN (5, 6)) AS ao
								  
								ON oq.OrderGuid = ao.OrderGuid AND ao.AchievedQty >= oq.OrderQty)')
								
	
		
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003510  
AS
	SET NOCOUNT ON 
	EXEC	prcAddGUIDFld 'DistPaid000', 'SalesManStoreGuid'
###########################################################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10003512
AS	
	SET NOCOUNT ON 
	INSERT INTO op000
	SELECT
		NEWID(),
		op.Name,
		op.Value,
		op.PrevValue,
		op.Computer,
		op.[Time],
		1,
		op.OwnerGUID,
		us.[GUID]
	FROM
		us000 us,
		(SELECT  
			*
		FROM 
			op000 
		WHERE 
			Name like '%Chk%'
			AND 
			[Type] = 0) op

	DELETE op000 
	WHERE 
		[Name] LIKE '%Chk%'
		AND 
		[Type] = 0

	EXECUTE [prcAddDateFld]	'ce000', 'PostDate'
	EXECUTE [prcAddBitFld]	'nt000', 'bAutoGenerateNote', 1 	
	EXECUTE [prcAddBitFld]	'nt000', 'bAutoGenerateContraNote', 1
	EXECUTE [prcAddBitFld]	'nt000', 'bAutoPrintAfterAdd', 0	
	EXECUTE [prcAddBitFld]	'nt000', 'bAutoPrintAfterCollect', 0	
	
	EXEC 
		('	EXEC prcDisableTriggers ''CE000'' 
			UPDATE ce000 SET
				[PostDate] = [Date]
			WHERE [IsPosted] = 1 AND [PostDate] = ''1980-01-01''	
			ALTER TABLE ce000 ENABLE TRIGGER ALL 
		')

	-- Specail Offers Upgrade		
	EXECUTE	[prcAddGUIDFld] 'cu000', 'ContraDiscAccGUID'
	EXECUTE [prcAddIntFld]	'bi000', 'SOGroup'

	-- Upgrade SpecailOffers data From Old tables to new tables

	DECLARE @sql VARCHAR(8000)
	-- SpecialOffers000
	SET @sql = '
	INSERT INTO SpecialOffers000(
		[Guid],
		Number,
		Code,
		Name,
		LatinName,
		[Type],
		StartDate,
		EndDate,
		AccountGuid,
		CostGuid,
		IsAllBillTypes,
		CustCondGuid,
		IsActive,
		Class,
		[Group],
		ItemsCondition,
		OfferedItemsCondition,
		Quantity,
		Unit, 
		ItemsAccount,
		ItemsDiscountAccount,
		OfferedItemsAccount,
		OfferedItemsDiscountAccount,
		BranchMask,
		IsApplicableToCombine)
	SELECT
		sm.[GUID], 
		sm.Number, 
		CAST(sm.Number AS VARCHAR(200)),
		sm.Notes,
		'''',
		sm.[Type] - 1, 
		sm.StartDate,
		sm.EndDate,
		sm.CustAccGuid,
		sm.CostGuid,
		sm.bAllBt,
		sm.CustCondGuid,
		sm.bActive,
		sm.ClassStr,
		sm.GroupStr,
		0,
		0,
		0,
		0,
		sm.OfferAccGuid,
		0x0,
		sm.IOfferAccGuid,	
		0x0,
		sm.BranchMask,
		0
	FROM
		sm000	AS sm
		LEFT JOIN SpecialOffers000 AS so ON so.Guid = sm.Guid
	WHERE
		so.Guid IS NULL '
	EXEC (@sql)	

	-- SOItems
	SET @sql = '
	INSERT INTO SOItems000(
		[GUID],
		SpecialOfferGuid,
		ItemType,
		ItemGuid,
		IsSpecified,
		IsIncludeGroups,
		Number,
		Quantity,
		Unit,
		PriceKind,
		PriceType,
		Price,
		DiscountType,
		Discount,
		OfferedItemGuid,
		BonusQuantity,
		DiscountRatio)	
	SELECT
		NEWID(),
		sm.GUID,
		CASE MatCondGuid 
			WHEN 0x0 THEN 
				(CASE GroupGuid 
					WHEN 0x0 THEN 0 
					ELSE 1 
				END) 
			ELSE 2 
		END,
		CASE MatCondGuid
			WHEN 0x0 THEN 
				CASE GroupGuid
					WHEN 0x0 THEN MatGUID
					ELSE GroupGuid
				END
			ELSE MatCondGuid
		END,
		0,
		bIncludeGroups,
		@@ROWCOUNT,
		Qty,
		CASE MatGUID
			WHEN 0x0 THEN 
				CASE 
					WHEN Unity > 0 THEN Unity - 1
					ELSE 3
				END
			ELSE Unity
		END,
		0,
		sm.PriceType,
		0,
		CASE ISNULL(sm.DiscountType, 0) WHEN 0 THEN 0 ELSE sm.DiscountType - 1 END AS DiscountType,
		sm.Discount,
		0x0,
		0,
		0
	FROM
		sm000	AS sm
		LEFT JOIN SOItems000 AS so ON so.SpecialOfferGuid = sm.Guid
	WHERE 
		so.Guid IS NULL '
	EXEC (@sql)	

	-- SOOfferedItems
	SET @sql = '
	INSERT INTO SOOfferedItems000(
		GUID, 
		SpecialOfferGuid,
		ItemType,
		ItemGuid,
		IsIncludeGroups,
		Number,
		Quantity,
		Unit,
		PriceKind,
		PriceType,
		Price,
		CurrencyGuid,
		CurrencyValue,
		IsBonus,
		DiscountType,
		Discount)	
	SELECT
		sd.GUID,
		ParentGuid,
		0,
		MatGuid,
		0,
		Item,
		Qty,
		Unity,
		PriceFlag + 1,
		PolicyType,
		sd.Price,
		sd.CurrencyGuid,
		sd.CurrencyVal,
		bBonus,
		0,
		0
	FROM
		sd000	AS sd
		LEFT JOIN SOOfferedItems000		AS so ON so.Guid = sd.Guid
	WHERE 
		so.Guid IS NULL	'
	EXEC (@sql)		

	-- SOBillTypes
	SET @sql = '
	INSERT INTO SOBillTypes000(
		GUID,
		SpecialOfferGuid,
		BillTypeGuid)
	SELECT
		sm.GUID,
		sm.ParentGuid,
		sm.BtGuid
	FROM
		smbt000	AS sm
		LEFT JOIN SOBillTypes000 AS so ON so.Guid = sm.Guid
	WHERE 
		so.Guid IS NULL	'
	EXEC (@sql)

	-- Disable Triggers
	SET @sql = '
	ALTER TABLE bi000 DISABLE TRIGGER trg_bi000_CheckConstraints

	-- Update bills
	UPDATE bi
	SET bi.SOGuid = so.Guid
	FROM 
		bi000 bi
		INNER JOIN SOItems000 AS so ON so.SpecialOfferGUID = bi.SoGuid
	WHERE
		bi.SOType = 1

	UPDATE bi
	SET bi.SOGuid = so.[GUID]
	FROM
		bi000 bi
		INNER JOIN SOOfferedItems000 so ON so.SpecialOfferGUID = bi.SOGuid
	WHERE
		bi.MatGUID = so.ItemGUID
		
	UPDATE bi
	SET bi.SOGuid = so.[GUID]
	FROM
		bi000 bi
		INNER JOIN (
					SELECT soo.GUID, soo.SpecialOfferGUID
					FROM 
						SOOfferedItems000 soo 
						INNER JOIN SOItems000 soi ON soi.SpecialOfferGUID = soo.SpecialOfferGUID
					WHERE 
						soi.ItemType <> 0
						AND soo.ItemGUID = 0x0
					)so ON so.SpecialOfferGUID = bi.SOGuid
	
	ALTER TABLE bi000 ENABLE TRIGGER trg_bi000_CheckConstraints '
	EXEC (@sql)	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003513
AS	
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'CFFlds000', 'Number', 0
	
	DECLARE @sql VARCHAR(8000)
	SET @sql = 'CREATE TABLE #CFFlds (Guid UNIQUEIDENTIFIER, Id INT IDENTITY(1, 1))
				INSERT INTO #CFFlds(Guid) SELECT GUID FROM CFFlds000 WHERE Number = 0 ORDER BY GGuid, SortNumber
				UPDATE CFFlds000 SET [Number] = [tcf].[Id] FROM #CFFlds [tcf] INNER JOIN CFFlds000 [cf] ON [tcf].Guid = [cf].Guid WHERE [cf].Number = 0'
	EXEC (@sql)	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003514
AS	
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'RestOrder000', 'PrintTimes'	
	EXEC [prcAddIntFld] 'RestOrderTemp000', 'PrintTimes'	
	EXEC prcDropTable 'DistDeviceStatement000'		
#########################################
CREATE PROCEDURE prcUpgradeDatabase_From10003515
AS
	SET NOCOUNT ON 
	DECLARE @sql VARCHAR(8000)
	SET @sql = 'UPDATE abt
				SET abt.Name = btDetails.Name,
					abt.AbbName = btDetails.Abbrev,
					abt.LatinName = btDetails.LatinName,
					abt.AbbLatinName = btDetails.LatinAbbrev
				FROM 
					AssemBillType000 abt
					INNER JOIN (SELECT	GUID,
										SUBSTRING(Name, LEN(''إد.'')+1, LEN(Name)) AS Name,
										SUBSTRING(Abbrev, LEN(''إد.'')+1, LEN(Abbrev)) AS Abbrev,
										SUBSTRING(LatinName, LEN(''إد.'')+1, LEN(LatinName)) AS LatinName,
										SUBSTRING(LatinAbbrev, LEN(''إد.'')+1, LEN(LatinAbbrev)) AS LatinAbbrev
								FROM bt000 
								WHERE Type = 7) 
								AS btDetails ON btDetails.GUID = abt.OutTypeGUID
				
				UPDATE bt000 SET Type = 9 WHERE Type = 7
				UPDATE bt000 SET Type = 10 WHERE Type = 8'
	EXEC (@sql)
	
	DECLARE 
		@Version INT,
		@VersionStr VARCHAR(100)
	
	SET @VersionStr = (SELECT CAST([Value] AS VARCHAR(100)) FROM [dbo].[fnListExtProp]( 'AmnDBVersion'))
	SELECT @Version = CAST(SUBSTRING(@VersionStr, CHARINDEX('.', @VersionStr, 1) + 1, LEN(@VersionStr)) AS INT)

	IF @Version < 3507
	BEGIN
		IF NOT EXISTS(SELECT * FROM mc000 WHERE Number = 1055 AND Asc1 = 'UpdateBillLayout' AND Num1 = 1)
		BEGIN
			UPDATE BLItems000
			SET FldIndex = FldIndex + 1
			WHERE FldIndex >= 1055 	AND FldIndex <> 1134
			
			INSERT INTO mc000(Number, Asc1, Num1)
			VALUES (1055, 'UpdateBillLayout', 1)
		END
	END

	IF [dbo].[fnObjectExists]('TrnExchange000.EvlCashCurrencyVal') = 0
		EXECUTE [prcDropFld] 'TrnExchange000', 'EvlCashCurrencyVal'
	
	IF [dbo].[fnObjectExists]('TrnExchange000.EvlPayCurrencyVal') = 0
		EXECUTE [prcDropFld] 'TrnExchange000', 'EvlPayCurrencyVal'
		
	EXECUTE	[prcAddGUIDFld] 'TrnExchange000', 'CustomerGuid'
#########################################
CREATE PROCEDURE prcUpgradeDatabase_From10003518
AS
	SET NOCOUNT ON 
	Exec PrcAddGuidFld 'DistPaid000', 'BranchGuid'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003521
AS	
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld] 'POSPaymentsPackageCheck000', 'ChildID'	
	EXEC [prcAddGUIDFld] 'cu000', 'ConditionalContraDiscAccGUID'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003523
AS	
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld] 'SOContractPeriodEntries000', 'BranchGUID'				    
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003525
AS    
	SET NOCOUNT ON 
	EXEC [prcAddIntFld] 'POSOrderItemsTemp000', 'DiscountType'
	EXEC [prcAddIntFld] 'POSOrderItems000', 'DiscountType'
	EXEC [prcRenameFld] 'ProductionLine000', 'AccountGuid', 'ExpensesAccount'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003527
AS    
	SET NOCOUNT ON 
   	EXEC [prcAddBitFld]	 'TrnStatementTypes000', 'bAutoGenerateVoucher', 0		
	EXEC [prcAddBitFld]	 'TrnStatementTypes000', 'bAutoPaied', 0		
	EXEC [prcAddBitFld]	 'TrnStatementTypes000', 'bDiscountAllWages', 0		
	EXEC [prcAddBitFld]	 'TrnStatementTypes000', 'bLocalCurrencyWages', 0	
	
	EXEC [prcAddBitFld]	 'TrnTransferVoucher000', 'bLocalCurrencyWages', 0		
	EXEC [prcAddBitFld]	 'TrnTransferVoucher000', 'bDiscountAllWages', 0

	EXEC [prcAddBitFld]	 'ori000', 'bIsRecycled', 0	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003528
AS        
	SET NOCOUNT ON 
	EXEC prcAddCharFld  'restorder000',     'ExternalcustomerName', 100
	EXEC prcAddCharFld  'RestOrderTemp000', 'ExternalcustomerName', 100
	EXEC prcAddFloatFld	'DiscountTypesCard000', 'CalPoints'
	EXEC prcAddGUIDFld  'DiscountCard000', 'BranchGUID'
	EXEC prcAddCharFld	'DiscountCard000', 'Password', 250
	EXEC prcAddFloatFld 'DiscountCard000', 'Point'
	EXEC prcAddIntFld	'DiscountCard000', 'ID'
	EXEC prcAddFloatFld 'DiscountCard000', 'TotalBuy'
	EXEC prcAddFloatFld 'DiscountCard000', 'TotalPoints'

	EXEC prcDisableTriggers 'mt000'
	EXEC('
		DECLARE @FPDate DATE;
		SET @FPDate  = (SELECT CONVERT(DATETIME, (SELECT Value FROM op000 WHERE name LIKE ''%AmnCfg_FPDate%''), 105))
		UPDATE mt000 
          SET CreateDate = @FPDate
          WHERE CreateDate = ''1/1/1980''')
	EXEC prcEnableTriggers 'mt000'
    
    
    IF EXISTS(SELECT * FROM op000 WHERE NAME LIKE '%AmnCfg_QtyByBillStore%')
	BEGIN
		DECLARE @prevValue VARCHAR(100)

		SELECT @prevValue = VALUE FROM op000 WHERE NAME LIKE '%AmnCfg_QtyByBillStore%'

		INSERT INTO op000([GUID], Name, Value, [Type], UserGuid)
		SELECT
			NEWID(),
			'AmnCfg_QtyByBillStore',
			@prevValue,
			1,
			us.[GUID]
		FROM
			us000 us

		DELETE FROM op000 WHERE Name LIKE '%AmnCfg_QtyByBillStore%' AND [Type] = 0
	END    
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003529
AS               
	SET NOCOUNT ON      
	EXEC [prcRenameFld] 'TrnTransferVoucher000', 'OriginalVoucherGuid', 'InStatementPayedGuid'
	
	EXEC [prcAddGUIDFld] 'bt000', 'DefBranchGUID'	
	EXEC [prcAddBitFld]	 'bt000', 'FixedDefaultValues', 0		
	EXEC [prcAddBitFld]	 'bt000', 'IsStopDate', 0
	EXEC [prcAddDateFld] 'bt000', 'StopDate'
	EXEC [prcAddBitFld]	 'mt000', 'IsIntegerQuantity', 0

	EXEC [prcAddGUIDFld] 'et000', 'DefBranchGUID'
	EXEC [prcAddBitFld]	 'et000', 'FixedNumber', 0	
	EXEC [prcAddBitFld]	 'et000', 'FixedBranch', 0	
	EXEC [prcAddBitFld]	 'et000', 'FixedDate', 0	
	EXEC [prcAddBitFld]	 'et000', 'IsStopDate', 0	
	EXEC [prcAddDateFld] 'et000', 'StopDate'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003530
AS        
	SET NOCOUNT ON 
    EXEC [prcRenameFld] 'ProductionLineGroup000', 'ProductionLineGuid', 'ProductionLine'	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003531
AS  
	SET NOCOUNT ON 
    EXEC [prcAddGUIDFld] 'DistRequiredMaterials000', 'CustomerTypeGUID'
	EXEC [prcAddGUIDFld] 'DistRequiredMaterials000', 'MaterialTemplateGUID'
	EXEC [prcAddGUIDFld] 'DistRequiredMaterials000', 'TradeChannelGUID'
	Exec PrcAddIntFld 'DistDisc000', 'AroundType'
	Exec prcAddBitFld 'Distributor000', 'ResetDaily'
	Exec prcAddBitFld 'Distributor000', 'UseCustomerPrice'
	Exec prcAddIntFld 'Distpromotions000', 'QuantityUnit'
	Exec prcAddIntFld 'Distpromotions000', 'BonusUnit'
	EXEC [prcAddGUIDFld] 'bt000', 'DefCurrencyGUID'	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003533
AS  
	SET NOCOUNT ON 
	EXEC [prcAddGUIDFld] 'et000', 'DefBranchGUID'
	EXEC [prcAddBitFld]	 'et000', 'FixedNumber', 0	
	EXEC [prcAddBitFld]	 'et000', 'FixedBranch', 0	
	EXEC [prcAddBitFld]	 'et000', 'FixedDate', 0	
	EXEC [prcAddBitFld]	 'et000', 'IsStopDate', 0	
	EXEC [prcAddDateFld] 'et000', 'StopDate'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003534
AS  
	SET NOCOUNT ON 
	Exec prcDropFld 'Distpromotions000', 'QuantityUnit'
	Exec prcDropFld 'Distpromotions000', 'BonusUnit'
	Exec prcAddIntFld 'Distpromotions000', 'CondUnity'             
	Exec prcAddIntFld 'Distpromotions000', 'FreeUnity'             
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003535
AS  
	SET NOCOUNT ON 
	Exec PrcAddIntFld 'DistDevicePro000', 'CondUnity'
	Exec PrcAddIntFld 'DistDevicePro000', 'FreeUnity'
	EXEC prcAddCharFld  'POSOrderItemsTemp000',     'ClassPtr', 100
	EXEC prcAddCharFld  'POSOrderItems000',     'ClassPtr', 100
	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003538
AS  
	SET NOCOUNT ON 
    Exec prcRenameFld 'JobOrder000', 'FinishedGoodsGuid', 'FormGuid'
	Exec prcAddFloatFld 'ProductionLineGroup000', 'ConversionFactor'
	EXEC prcAddFloatFld 'ProductionLine000', 'EstimatedCost'
	EXEC prcAddFloatFld 'ProductionLine000', 'CalculationMethod'
	EXEC prcAddGUIDFld 'ProductionLine000'		, 'IndustrialAccount'
	Exec prcDropFld 'JobOrder000', 'Derivation'
	EXEC prcAddGUIDFld 'JobOrder000', 'DerivationEntryGuid'
	/*
	EXEC(' UPDATE JobOrder000 
			SET FormGuid = Mn.FormGuid
			FROM JobOrder000 Jo 
			     INNER JOIN Mi000 Mi ON Mi.MatGuid = Jo.FormGuid
			     INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid
			WHERE
					Mn.Type = 0 AND Mi.Type = 0
				
			INSERT INTO Mi000

			SELECT 
				Mi.Type,Mi.Number,Mi.Unity,Mi.Qty,Mi.Notes,Mi.CurrencyVal,Mi.Price,Mi.Class,NEWID(),Mi.Qty2,Mi.Qty3,Jo.Guid
				,Mi.MatGuid,Mi.StoreGuid,Mi.CurrencyGuid,Mi.ExpireDate,Mi.ProductionDate,Mi.Length,Mi.Width,Mi.Height,Mi.CostGuid,0
			FROM Mi000 Mi
			INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid
			INNER JOIN JobOrder000 Jo ON Jo.FormGuid = Mn.FormGuid
			WHERE Mn.Type = 0    
				AND Jo.Guid NOT IN (SELECT ParentGuid FROM Mi000)
	')
	*/

	EXEC prcAddBitFld 'TrnExchangeTypes000', 'bActivateCommission'
	EXEC prcAddBitFld 'TrnExchangeTypes000', 'bModifyCommission'

	EXEC prcAddFloatFld 'TrnExchange000', 'CommissionAmount'
	EXEC prcAddFloatFld 'TrnExchange000', 'CommissionRatio'
	EXEC prcAddFloatFld 'TrnExchange000', 'CommissionNet'
	EXEC prcAddGUIDFld  'TrnExchange000', 'CommissionCurrency'
	EXEC prcAddCharFld  'TrnCustomer000', 'LastName', 250
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003539
AS	
	SET NOCOUNT ON 
	EXEC prcDropFld		'trnTransferVoucher000', 'IsSent'
	EXEC prcDropFld		'trnTransferVoucher000', 'ReciverBankGuid'
	EXEC prcDropFld		'trnTransferVoucher000', 'RecieverBankAccountNum'
	EXEC prcDropFld		'trnTransferVoucher000', 'bPayedAnyBranch'
	EXEC prcAddFloatFld 'TrnTransferVoucher000', 'WagesRatio'
	EXEC prcAddBitFld	'TrnTransferVoucher000', 'InverseExchangeCurrencyVal'
	EXEC prcAddBitFld	'TrnTransferVoucher000', 'InverseCashCurrencyVal'
	EXEC prcAddGUIDFld	'TrnTransferVoucher000', 'BankOrderGuid'		

	EXEC prcAddCharFld 'TrnSenderReceiver000', 'FatherName', 100
	EXEC prcAddCharFld 'TrnSenderReceiver000', 'LastName', 100


	EXEC prcDropFunction 'fbTrnTransferVoucherOut'
	EXEC prcDropFunction 'fbTrnTransferVoucherIn'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003541
AS  
	SET NOCOUNT ON 
	EXEC prcAddGUIDFld 'AssTransferReportHeader000'		, 'EntryTypeGuid'
	EXECUTE [prcDropFld]	'ProductionLine000', 'claculationmethod'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003543
AS  
	SET NOCOUNT ON 
	EXEC prcAddFloatFld 'bt000', 'PurchaseMaxLimit'
	EXEC prcAddIntFld 'bt000', 'DefaultDeliveryDays'
	EXEC prcAddBitFld 'bt000', 'bNoPrepareCmd'
	EXEC prcAddBitFld 'bt000', 'bNoGenerateCmd'
	EXEC prcAddBitFld 'bt000', 'bNoPostCmd'
	EXEC prcAddBitFld 'bt000', 'bNoDivideOrder'
	EXEC prcAddIntFld 'UsrApp000', 'Order'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003544
AS  
	SET NOCOUNT ON 
	EXEC prcAddGUIDFld	'ProductionLine000'		, 'DeviationAccount'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003545
AS  
	SET NOCOUNT ON 
	EXEC [prcAddBitFld] 'DistDeviceMt000', 'bHide'
	EXEC [prcAddIntFld] 'DistDeviceCu000', 'PayTypeTerm'
	EXEC [prcAddBitFld] 'DistDevicecu000', 'bHide'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003546
AS  
	SET NOCOUNT ON 
	EXEC prcAddBitFld 'TrnExchangeTypes000', 'bActivateCommission'
	EXEC prcAddBitFld 'TrnExchangeTypes000', 'bModifyCommission'

	EXEC prcAddFloatFld 'TrnExchange000', 'CommissionAmount'
	EXEC prcAddFloatFld 'TrnExchange000', 'CommissionRatio'
	EXEC prcAddFloatFld 'TrnExchange000', 'CommissionNet'
	EXEC prcAddGUIDFld  'TrnExchange000', 'CommissionCurrency'
	EXEC prcAddCharFld  'TrnCustomer000', 'LastName', 250
		
	EXEC prcDropFld		'trnTransferVoucher000', 'IsSent'
	EXEC prcDropFld		'trnTransferVoucher000', 'ReciverBankGuid'
	EXEC prcDropFld		'trnTransferVoucher000', 'RecieverBankAccountNum'
	EXEC prcDropFld		'trnTransferVoucher000', 'bPayedAnyBranch'
	EXEC prcAddFloatFld 'TrnTransferVoucher000', 'WagesRatio'
	EXEC prcAddBitFld	'TrnTransferVoucher000', 'InverseExchangeCurrencyVal'
	EXEC prcAddBitFld	'TrnTransferVoucher000', 'InverseCashCurrencyVal'
	EXEC prcAddGUIDFld	'TrnTransferVoucher000', 'BankOrderGuid'		

	EXEC prcAddCharFld 'TrnSenderReceiver000', 'FatherName', 100
	EXEC prcAddCharFld 'TrnSenderReceiver000', 'LastName', 100

	EXEC prcDropFunction 'fbTrnTransferVoucherOut'
	EXEC prcDropFunction 'fbTrnTransferVoucherIn'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003547
AS  
	SET NOCOUNT ON 
	EXEC [prcAddFloatFld] 'TrnVoucherPayInfo000', 'PaidAmount'
	EXEC prcAddGUIDFld	'TrnVoucherPayInfo000', 'PaidCurrencyGuid'
	EXEC [prcAddFloatFld] 'TrnVoucherPayInfo000', 'ExchangeDiff'
	EXEC [prcAddFloatFld] 'TrnVoucherPayInfo000', 'PaidCurrencyVal'				
	EXEC [prcAddFloatFld] 'TrnVoucherPayInfo000', 'PaidRoundAmount'			
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003548
AS  
	SET NOCOUNT ON 
	exec [PrcAddbitFld] 'Distributor000', 'HideEmptyMatInEntryBills'
	exec [prcAddBitFld] 'Distributor000', 'CanUseGPRS'
	exec [prcAddGuidFld] 'Distributor000', 'VerificationStore'
	exec [prcAddGuidFld] 'Distributor000', 'GPRSTransferType'
	exec [prcAddGuidFld] 'Distributor000', 'UploadBranch'
	exec [prcAddBitFld] 'DistDeviceCu000', 'bHide'
	exec [PrcAddBitFld] 'DistDeviceGr000', 'AllChildMatsIsEmpty'
	exec [prcRenameFld] 'DistDeviceGr000', 'flag', 'HasMats'
	exec [PrcAddbitFld] 'bu000', 'IsGeneratedByPocket'
	EXEC [prcAddFloatFld] 'RestOrderTemp000', 'Ordernumber'
	EXEC [prcAddFloatFld] 'RestOrder000', 'Ordernumber'
	EXEC [prcAddDateFld] 'OrApp000', 'ApprovalDate'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003549
AS  
	SET NOCOUNT ON 
	exec PrcAddbitFld 'Distributor000', 'HideEmptyMatInEntryBills'
	exec prcAddBitFld 'Distributor000', 'CanUseGPRS'
	exec prcAddGuidFld 'Distributor000', 'VerificationStore'
	exec prcAddGuidFld 'Distributor000', 'GPRSTransferType'
	exec prcAddGuidFld 'Distributor000', 'UploadBranch'
	exec prcAddIntFld 'DistDeviceCu000', 'PayTypeTerm'
	exec prcAddBitFld 'DistDeviceCu000', 'bHide'
	exec PrcAddBitFld 'DistDeviceGr000', 'AllChildMatsIsEmpty'
	exec prcAddCharFld 'DistDeviceGr000', 'LatinName', 100
	exec prcRenameFld 'DistDeviceGr000', 'flag', 'HasMats'
	exec PrcAddbitFld 'bu000', 'IsGeneratedByPocket'
	EXEC prcAddFloatFld 'RestOrderTemp000', 'Ordernumber'
	EXEC prcAddFloatFld 'RestOrder000', 'Ordernumber'
	EXEC prcAddDateFld 'OrApp000', 'ApprovalDate'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003557
AS  
	SET NOCOUNT ON 
	exec PrcAddbitFld 'Distributor000', 'HideEmptyMatInEntryBills'
	exec prcAddBitFld 'Distributor000', 'CanUseGPRS'
	exec prcAddGuidFld 'Distributor000', 'VerificationStore'
	exec prcAddGuidFld 'Distributor000', 'GPRSTransferType'
	exec prcAddGuidFld 'Distributor000', 'UploadBranch'
	exec prcAddIntFld 'DistDeviceCu000', 'PayTypeTerm'
	exec prcAddBitFld 'DistDeviceCu000', 'bHide'
	exec PrcAddBitFld 'DistDeviceGr000', 'AllChildMatsIsEmpty'
	exec prcAddCharFld 'DistDeviceGr000', 'LatinName', 100
	exec prcRenameFld 'DistDeviceGr000', 'flag', 'HasMats'
	exec PrcAddbitFld 'bu000', 'IsGeneratedByPocket'
	EXEC prcAddFloatFld 'RestOrderTemp000', 'Ordernumber'
	EXEC prcAddFloatFld 'RestOrder000', 'Ordernumber'
	EXEC prcAddDateFld 'OrApp000', 'ApprovalDate'
	EXECUTE	[prcAddCharFld] 'ProductionLine000', 'LatinName', 250
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003559
AS  
	SET NOCOUNT ON 
	-- ST
	EXEC [prcAddFld] 'st000', 'Kind', 'TINYINT NOT NULL DEFAULT 0'
	EXEC [prcAddFloatFld] 'st000', 'StorageCapacity'
	EXEC [prcAddBitFld] 'st000', 'IsActive', 0

	-- AC
	exec [PrcAddbitFld]  'ac000', 'ForceCostCenter','0'
	exec [prcAddGuidFld] 'ac000', 'CostGuid'
	EXEC [prcAddGuidFld]  'ac000', 'AddedValueAccGUID'
	EXEC [PrcAddbitFld]   'ac000', 'IsUsingAddedValue', '0'
	EXEC [prcAddFloatFld] 'ac000', 'DefaultAddedValue'
	EXEC [PrcAddbitFld]   'ac000', 'IsDefaultAddedValueFixed', '0'
	
	-- BT
	EXEC [PrcAddbitFld] 'bt000','bRepeatedPhrase','1'
	EXEC [PrcAddbitFld]  'bt000', 'taxBeforeDiscount', '0'
	EXEC [PrcAddbitFld]  'bt000', 'useSalesTax', '0'
	EXEC [PrcAddbitFld]  'bt000', 'isApplyTaxOnGifts', '0'
	EXEC [prcAddBitFld] 'bt000', 'IsTimeScheduleEnabled'

	-- NT
	exec [PrcAddbitFld] 'nt000','bRepeatedPhrase','1'

	-- CH
	exec [PrcAddbitFld] 'ch000','IsPrinted','0'

	-- ET
	exec [PrcAddbitFld] 'et000', 'bRepeatedPhrase','1'
	exec [PrcAddbitFld] 'et000', 'ForceCostCenter','0'
	EXEC [PrcAddbitFld] 'et000', 'IsUsingAddedValue', '0'
	EXEC [prcAddIntFld] 'et000', 'FldAddedValue', '0'

	-- CU
	exec [prcAddGuidFld] 'cu000', 'AddedValueAccountGUID'
	EXEC [prcAddGUIDFld]	'cu000', 'CostGUID'

	-- CH
	exec [PrcAddbitFld]  'ch000', 'IsPrinted','0'

	EXEC [prcAddFloatFld] 'ProductionLine000', 'ProductionCapacity'

	EXEC [prcAddFloatFld] 'en000', 'AddedValue', '0'

	EXEC [prcAddGuidFld]  'RestDiscTaxTemp000', 'ParentTaxID'
	EXEC [prcAddGuidFld]  'RestDiscTax000', 'ParentTaxID'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003562 
AS  
	SET NOCOUNT ON 
	EXECUTE	[prcAddIntFld]	'MN000', 'PhaseNumber'
	EXECUTE	[prcAddGuidFld]	'MI000', 'ReadyMatGUID'
	EXECUTE	[prcAddGuidFld]	'MI000', 'AltMainGuid'
	EXECUTE	[prcAddGuidFld]	'MX000', 'ReadyMatGUID'
	EXECUTE [prcAddGuidFld]  'en000', 'ParentVATGuid'
#########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003566
AS  
	SET NOCOUNT ON 
	-------------------------------------------------------------------------------------
	---------تعديل صلاحية المستخدم على القوائم بعد اضافة قائمة "مالية" إلى القوائم الرئيسية
	-------------------------------------------------------------------------------------
	IF [dbo].[fnObjectExists]('Allotment000.Notes') = 0 
	BEGIN
		UPDATE ui000 SET ReportId = ReportId + 1 WHERE ReportId BETWEEN 5382 AND 5396
		UPDATE uix SET ReportID = ReportID + 1 WHERE ReportID BETWEEN 5382 AND 5396
	END
	-------------------------------------------------------------------------------------
	EXEC prcAddCharFld	'Allotment000', 'Notes', 250
	EXEC prcAddIntFld	'gr000',		'Kind'
	EXEC prcAddGuidFld	'en000',		'MatGuid'
	EXEC prcAddBitFld 'BLMain000', 'bShowDebtAgesForCreditBills'
	EXEC prcAddGUIDFld	'ma000', 'CashAccGUID'
	EXEC prcAddIntFld 'UserMaxDiscounts000', 'MinPrice', '1'
	EXEC prcAddGuidFld 'NT000', 'DefaultCostcenter'
	EXEC PrcAddBitFld 'NT000', 'bFoceInCostcenter'
	EXEC prcAddIntFld 'BLMain000', 'SortBy'
	EXEC prcAddGuidFld 'ti000', 'DiscountAccGUID'
	exec prcAddBitFld 'di000', 'IsGeneratedByPayTerms'
	EXEC [prcAlterFld] 'bu000', 'Notes', 'VARCHAR(1000)'
	EXEC [prcAlterFld] 'mt000', 'BarCode', 'VARCHAR(500)'
	EXEC [prcAlterFld] 'mt000', 'BarCode2', 'VARCHAR(500)'
	EXEC [prcAlterFld] 'mt000', 'BarCode3', 'VARCHAR(500)'
	-- ONF02
	EXEC prcAddIntFld 'OrAddInfo000', 'PTType'
	EXEC prcAddIntFld 'OrAddInfo000', 'PTOrderDate'
	EXEC prcAddDateFld 'OrAddInfo000', 'PTDate'
	EXEC prcAddIntFld 'OrAddInfo000', 'PTDaysCount'
	EXEC prcAddCharFld 'DocAch000', 'Path', 100
	EXEC prcAddCharFld 'OrAddInfo000', 'ShippingType', 250
	EXEC prcAddCharFld 'OrAddInfo000', 'ShippingCompany', 250
	EXEC prcAddCharFld 'OrAddInfo000', 'DeliveryConditions', 250
	EXEC prcAddCharFld 'OrAddInfo000', 'ArrivalPosition', 250
	EXEC prcAddCharFld 'OrAddInfo000', 'Bank', 250
	EXEC prcAddCharFld 'OrAddInfo000', 'AccountNumber', 250
	EXEC prcAddCharFld 'OrAddInfo000', 'CreditNumber', 250
	EXEC prcAddDateFld 'OrAddInfo000', 'ExpectedDate'
	EXEC prcAddIntFld 'bt000', 'StopDaysCount'
	EXEC prcAddBitFld 'ppo000', 'IsNotAvailableQuantity'
	EXEC prcAddFloatFld 'ppi000', 'Quantity'
	EXEC prcAddBitFld 'ppi000', 'IsQuantityNotCalculated'
	EXEC prcAddDateFld 'ppi000', 'PreparationDate'
	EXEC prcAddIntFld 'bp000', 'DebitType'


	EXEC prcDisableTriggers 'OrAddInfo000'

	UPDATE OrAddInfo000 SET SADATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.SADATE < bu.[Date]

	UPDATE OrAddInfo000 SET SDDATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.SDDATE < bu.[Date]

	UPDATE OrAddInfo000 SET SSDATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.SSDATE < bu.[Date]

	UPDATE OrAddInfo000 SET SPDATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.SPDATE < bu.[Date]

	UPDATE OrAddInfo000 SET AADATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.AADATE < bu.[Date]

	UPDATE OrAddInfo000 SET ADDATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.ADDATE < bu.[Date]

	UPDATE OrAddInfo000 SET APDATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.APDATE < bu.[Date]

	UPDATE OrAddInfo000 SET ASDATE = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.ASDATE < bu.[Date]

	EXEC('UPDATE OrAddInfo000 SET ExpectedDate = bu.[Date] 
	FROM OrAddInfo000 ori INNER JOIN bu000 bu on bu.[guid] = ori.ParentGuid 
	WHERE ori.ExpectedDate < bu.[Date]')

	ALTER TABLE OrAddInfo000 ENABLE TRIGGER ALL 

	IF [dbo].[fnObjectExists]('OrApp000') <> 0 
	BEGIN 
		IF NOT EXISTS (SELECT * FROM OrderApprovals000)
		BEGIN 
			EXEC('ALTER TABLE OrderApprovals000 DISABLE TRIGGER ALL;
			INSERT INTO OrderApprovals000 ([GUID], [Number], OrderGuid, UserGuid)
			SELECT NEWID(), app.[Order], bu.[Guid], app.[UserGuid]			
			FROM 
				UsrApp000 app 
				INNER JOIN bt000 bt ON bt.[GUID] = app.ParentGuid
				INNER JOIN bu000 bu ON bu.[TypeGUID] = [bt].[GUID];
				ALTER TABLE OrderApprovals000 ENABLE TRIGGER ALL;
				')
		END 
		
		IF NOT EXISTS (SELECT * FROM OrderApprovalStates000)
		BEGIN 
		EXEC prcDisableTriggers 'OrderApprovalStates000'
			EXEC('
			INSERT INTO OrderApprovalStates000 ([GUID], [Number], ParentGuid, UserGuid, AlternativeUserGUID, IsApproved, OperationTime, ComputerName)
			SELECT NEWID(), 1, ora.[GUID], ora.UserGUID, 0x0, 1, app.ApprovalDate, HOST_NAME()
			FROM 
				OrApp000 app 
				INNER JOIN OrderApprovals000 ora ON ora.[OrderGuid] = app.OrderGuid AND ora.[UserGuid] = app.UserGuid
			WHERE 
				app.Approved != 0

			INSERT INTO OrderApprovalStates000 ([GUID], [Number], ParentGuid, UserGuid, AlternativeUserGUID, IsApproved, OperationTime, ComputerName)
			SELECT NEWID(), 1, [GUID], UserGUID, 0x0, 1, ApprovalDate, HOST_NAME()
			FROM 
				MgrApp000;
			ALTER TABLE OrderApprovalStates000 ENABLE TRIGGER ALL
			')
		END 

		DROP TABLE OrApp000
	END 
#########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003567
AS 
	SET NOCOUNT ON 
	EXEC prcConvertDBToUnicode

	EXECUTE	[PrcAddbitFld]	'ac000', 'IsSync'	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003569
AS
	SET NOCOUNT ON 
	IF [dbo].[fnObjectExists]('ProductionPlan000.ShowJobOrderAvarageQty') = 0
	BEGIN 	
		EXEC PrcAddBitFld 'ProductionPlan000', 'ShowJobOrderAvarageQty'
		UPDATE [BLHeader000] SET Id = Id + 1 WHERE Id >= 2126 AND Id < 2200
	END 
#########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003570
AS 
	SET NOCOUNT ON 
	EXEC prcConvertDBToUnicode 
	-------------------------------------------------------------------------------------
	---------تعديل صلاحية المستخدم على القوائم بعد اضافة قائمة "مراكز ربحية" إلى القوائم الرئيسية
	-------------------------------------------------------------------------------------
	IF [dbo].[fnObjectExists]('ac000.IsSync') = 0 
	BEGIN
		UPDATE ui000 SET ReportID = ReportID + 1 WHERE ReportID BETWEEN 5383 AND 5396
		UPDATE uix SET ReportID = ReportID + 1 WHERE ReportID BETWEEN 5383 AND 5396
	END
	-------------------------------------------------------------------------------------
	EXEC [PrcAddbitFld]	'ac000', 'IsSync'	
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003571
AS  
	SET NOCOUNT ON 
	EXEC prcAddDateFld 'us000', 'FixedDate'
	EXEC prcAddGUIDFld 'oit000', 'BillGuid'
	EXEC PrcAddBitFld 'oit000', 'QtyStageCompleted'
	EXEC PrcAddBitFld 'oit000', 'FixedDefaultBillType'
	EXEC prcAddIntFld 'oit000', 'BillType'	
	EXEC prcAddIntFld 'oitvs000', 'StateOrder'
	EXEC PrcAddBitFld 'ac000', 'IsChangeableRatio'
	EXEC PrcAddBitFld 'co000', 'IsChangeableRatio'
	
	IF (NOT EXISTS(SELECT * FROM op000
     WHERE Name = 'AmnCfg_UPDATEORDERSTATES'))
	BEGIN
	EXEC('
   UPDATE oit
   SET 
	FixedDefaultBillType = 0, 
			BillType = oit.Type,
			BillGuid = 0x0,
			QtyStageCompleted = 1
   FROM
	oit000 AS oit
   WHERE 
	Operation = 1')

   EXEC('UPDATE Oit000 SET Operation = 1, BillType = 4, BillGuid = 0x0, QtyStageCompleted = 0 ,FixedDefaultBillType = 0
       WHERE Operation = 4 and Type = 1')
	   
	   insert Into op000 values (NEWID(),'AmnCfg_UPDATEORDERSTATES',0, 0, '' ,NULL, 0, 0x0, 0x0 )	
END
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003572
AS  
	SET NOCOUNT ON 
	UPDATE sh000 SET [Key] = 1078067200 WHERE [Cmd16] = 701
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003573
AS  
	SET NOCOUNT ON 
	EXECUTE	[prcAddGUIDFld] 'SubProfitCenter000', 'MainDebitorsAccGuid'
	EXECUTE	[prcAddGUIDFld] 'SubProfitCenter000', 'MainCreditorsAccGuid'
	EXECUTE	[prcAddIntFld] 'SubProfitCenter000', 'DirectPurchasingEnablingFlag'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003574
AS  
	SET NOCOUNT ON 
	EXECUTE	[prcAddBitFld]	'DP000', 'isEntryDetailed'
	EXECUTE	[prcAddGUIDFld] 'TrnTransferVoucher000', 'CommissionCurrencyGUID'
	EXECUTE	[prcAddGUIDFld] 'TrnOffice000', 'CurrencyGUID'
	EXECUTE	[prcAddFloatFld] 'TrnOffice000', 'CurrencyVal'	
		EXEC ('		
		UPDATE [ac000] 
		SET CostGuid = 0x0 
		WHERE ForceCostCenter = 0 AND CostGuid != 0x0
	')

	IF EXISTS (select * from dbo.sysobjects where id = object_id(N'[dbo].[DistTempDeleted]'))
	BEGIN
		EXEC prcAddDateFld 'DistTempDeleted', 'Route1Time'
		EXEC prcAddDateFld 'DistTempDeleted', 'Route2Time'
		EXEC prcAddDateFld 'DistTempDeleted', 'Route3Time'
		EXEC prcAddDateFld 'DistTempDeleted', 'Route4Time'
	END
	EXEC PrcAddBitFld 'bt000', 'IncludeTTCDiffOnSales'	
	EXEC PrcAddBitFld 'bt000', 'ConsideredGiftsOfSales'
	EXEC prcAddGUIDFld 'en000', 'BiGUID'
	EXEC prcDropFld		'en000', 'MatGUID'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003575
AS  
	SET NOCOUNT ON 
	IF [dbo].[fnObjectExists]('nt000.bCanGenRetEnt') <> 0
		EXECUTE [prcRenameFld] 'nt000', 'bCanGenRetEnt', 'bCanGenDisEnt'
	IF [dbo].[fnObjectExists]('nt000.bManualReturn') <> 0
		EXECUTE [prcRenameFld] 'nt000', 'bManualReturn', 'bManualDiscount'

	EXEC prcAddBitFld  'nt000', 'bManualRecOrPay'
	EXEC prcAddBitFld  'nt000', 'bCanRecOrPay'
	EXEC prcAddBitFld  'nt000', 'bCanGenRecOrPayEnt'
	EXEC prcAddGuidFld 'nt000', 'DefRecOrPayAccGUID'
	EXEC prcAddGuidFld 'nt000', 'DefUnderDisAccGUID'
	EXEC prcAddGuidFld 'nt000', 'DefComAccGUID'
	EXEC prcAddGuidFld 'nt000', 'DefChargAccGUID'
	EXEC prcAddGuidFld 'nt000', 'DefEndorseAccGUID'
	EXEC prcAddBitFld 'nt000', 'bCanDiscount'
	EXEC prcAddBitFld 'nt000', 'bCanGenReturnEnt'
	EXEC prcAddBitFld 'nt000', 'bPayDeliveryGenEnt'
	EXEC prcAddBitFld  'nt000', 'bCanFinishing'
	EXEC prcAddBitFld  'nt000', 'ForceDistenationBank'
	EXEC prcAddBitFld  'nt000', 'ForceDefaultAccounts'
	EXEC prcAddGuidFld 'nt000', 'DefDisAccGUID'
	EXEC prcAddBitFld 'ac000', 'ConsiderChecksInBudget'
	EXEC prcAddIntFld 'ch000', 'TransferState'
	
	--/*------------------------------------------------------------
	------------------------------تعديلات الجهة----------------------
	--------------------------------------------------------------*/
	IF [dbo].[fnObjectExists]('nt000.BankGUID') = 0
	BEGIN	
		EXEC [prcAddGuidFld] 'nt000', 'BankGUID'
		EXEC [prcAddGuidFld] 'ch000', 'BankGUID'

		EXEC('
		INSERT INTO Bank000 (Number, Code, [Guid], BankName, BankLatinName, [Security])
		SELECT 
				ROW_NUMBER() over (order by DestName) ,
				ROW_NUMBER() over (order by DestName) ,
				NEWID(),
				nt.DestName,
				nt.LatinDestName,
				1	 
		FROM (
				SELECT distinct
						DestName,
						LatinDestName
					FROM nt000 nt
					WHERE  (IsNull(nt.DestName, '') <> '''' 
					OR   IsNull(nt.LatinDestName, '') <> '''' )
					) nt
		'
		)
		EXEC ('
			UPDATE nt
			SET     nt.[BankGUID] = b.[GUID]
			FROM   nt000 nt
			INNER JOIN Bank000 b
			ON nt.DestName = b.BankName  ')
		EXEC ('
			UPDATE nt
			SET     nt.[BankGUID] = b.[GUID]
			FROM   nt000 nt
			INNER JOIN Bank000 b
			ON nt.LatinDestName = b.BankLatinName 
			AND nt.LatinDestName <> '''' ')
	
		EXEC ('
		DECLARE @MAXNUMBER INT
		SELECT @MAXNUMBER = ISNULL(MAX(Number), 0) FROM Bank000	
		INSERT INTO Bank000 (Number, Code, [Guid], BankName, BankLatinName, [Security])
				SELECt 
				ROW_NUMBER()
				OVER (ORDER BY chbank) + @MAXNUMBER,
				ROW_NUMBER()
				OVER (ORDER BY chbank) + @MAXNUMBER,
				NEWID(),
				chbank,
				'''',
				1
				FROM 
				(SELECT DISTINCT  ch.Bank AS chbank FROM ch000 ch 
				WHERE ch.Bank <> '''') ch
				WHERE  ch.chbank NOT IN (SELECT BankName FROM Bank000)')
	
			EXEC ('
			UPDATE ch
			SET     ch.[BankGUID] = b.[GUID]
			FROM    ch000 ch
			INNER JOIN Bank000 b
			ON ch.Bank = b.BankName ')
	
			EXEC prcDropFld		'ch000', 'Bank'
			EXEC prcDropFld		'nt000', 'DestName'
			EXEC prcDropFld		'nt000', 'LatinDestName'
	END
	EXEC [prcAddGuidFld] 'nt000', 'ExchangeRatesAccGUID'	
	----////////////////////////////////////////////////////////////////////////////////////////////////
	IF [dbo].[fnObjectExists]('ch000.EndorseAccGUID') =  0
	BEGIN	
		EXEC prcAddGuidFld 'ch000', 'EndorseAccGUID'

		UPDATE ch000 SET [State] = 0 WHERE ([State] = 2 OR [State] = 22) AND Dir = 2 -- تظهير و مدفوعة تصبح غير مدفوعة
		UPDATE ch000 SET [State] = 0 WHERE [State] = 6 OR [State] = 54 -- استرداد تظهير
		UPDATE ch000 SET [State] = 4 WHERE [State] = 2 OR [State] = 22 -- التظهير 
		UPDATE ch000 SET [State] = 3 WHERE [State] = 8	OR [State] = 14 OR [State] = 62 -- إرجاع إلى الأصل 
		UPDATE ch000 SET [State] = 1 WHERE [State] = 7	OR [State] = 55 -- مقبوضة أو مدفوعة 
		UPDATE ch000 SET [State] = 2 WHERE [State] = 64	-- قبص جزئي

		UPDATE er000 SET [ParentType] = 254 WHERE [ParentType] = 7 OR [ParentType] = 11 -- استرداد تظهير
		UPDATE er000 SET [ParentType] = 7 WHERE [ParentType] = 10 OR [ParentType] = 13	-- تظهير
		-- update lg000
		DECLARE @Str NVARCHAR(MAX)
		SET @Str = '
		UPDATE nt000 
		SET 
			bCanRecOrPay = bCanCollect, 
			bManualRecOrPay = bManualCollect, 
			bCanGenRecOrPayEnt = bCanGenColEnt,
			DefPayAccGUID = 0x0, 
			DefRecAccGUID = 0x0, 
			DefColAccGUID = 0x0

		UPDATE nt000 
		SET 
			bCanCollect = 0, 
			bManualCollect = 1, 
			bCanGenColEnt = 0,
			-- bManualEndorse = 1,
			bManualDiscount = 1,			
			-- bCanGenEndEnt = 0,
			bCanGenDisEnt = 0,
			bAutoPost = 1
			
		UPDATE nt000 SET bAutoPost = 0 WHERE bAutoEntry = 0
		
		UPDATE ch000 
		SET EndorseAccGUID = ISNULL((SELECT TOP 1 AccountGUID FROM en000 WHERE ParentGUID = ce.GUID AND Debit > 0 ORDER BY Number), 0x0)
		FROM 
			ch000 ch 
			INNER JOIN er000 er ON er.ParentGUID = ch.GUID 
			INNER JOIN ce000 ce ON er.EntryGUID = ce.GUID 
		WHERE 
			er.[ParentType] = 7
			AND 
			ch.Dir = 1 '
		
		EXEC (@Str)

		SET @Str = '
			DECLARE 
				@c CURSOR,
				@chGUID UNIQUEIDENTIFIER,
				@chState INT 
	
			SET @c = CURSOR FAST_FORWARD FOR SELECT guid, State FROM ch000 ORDER BY Number 
			OPEN @c FETCH NEXT FROM @c INTO @chGUID, @chState 
			WHILE @@FETCH_STATUS = 0
			BEGIN 
				IF NOT EXISTS(SELECT * FROM ChequeHistory000 WHERE chequeGUID = @chGUID AND EventNumber = 33)
				BEGIN 
					IF EXISTS (SELECT * FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
						WHERE ch.GUID = @chGUID AND er.ParentType = 5)
					BEGIN 
						INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
							EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
						SELECT 
							1, newid(), ch.GUID, ch.Date, 0, 33, ce.Number, 
							ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Debit > 0 ORDER BY en.Number), 0x0),
							ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Credit > 0 ORDER BY en.Number), 0x0),
							ch.Val, 5, ce.guid, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
						FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
						WHERE ch.GUID = @chGUID AND er.ParentType = 5
					END ELSE BEGIN 
						INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
							EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit)
						SELECT 1, newid(), ch.GUID, ch.Date, 0, 33, 0, 
							0x0, 0x0, ch.Val, 5, 0x0, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
						FROM ch000 ch WHERE ch.GUID = @chGUID
					END 
				END 

				IF (@chState = 1)
				BEGIN 
					IF NOT EXISTS(SELECT * FROM ChequeHistory000 WHERE ChequeGUID = @chGUID AND EventNumber = 0)
					BEGIN 
						IF EXISTS (SELECT * FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 6)
						BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							SELECT 
								ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, newid(), 
								ch.GUID, ce.Date, @chState, 0, ce.Number, 
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Debit > 0 ORDER BY en.Number), 0x0),
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Credit > 0 ORDER BY en.Number), 0x0),
								ch.Val, 6, ce.guid, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
							FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 6
						END ELSE BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							SELECT 
								ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, newid(), 
								ch.GUID, ch.Date, @chState, 0, 0, 
								0x0, 0x0, 0, 6, 0x0, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
							FROM ch000 ch WHERE ch.GUID = @chGUID
						END 
					END 	
				END 

				IF (@chState = 3)
				BEGIN 
					IF NOT EXISTS(SELECT * FROM ChequeHistory000 WHERE ChequeGUID = @chGUID AND EventNumber = 5)
					BEGIN 
						IF EXISTS (SELECT * FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 8)
						BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							SELECT 
								ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, newid(), 
								ch.GUID, ce.Date, @chState, 5, ce.Number, 
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Debit > 0 ORDER BY en.Number), 0x0),
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Credit > 0 ORDER BY en.Number), 0x0),
								ch.Val, 8, ce.guid, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
							FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 8
						END ELSE BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							SELECT 
								ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, newid(), 
								ch.GUID, ch.Date, @chState, 5, 0, 
								0x0, 0x0, 0, 8, 0x0, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
							FROM ch000 ch WHERE ch.GUID = @chGUID
						END 
					END 	
				END 

				IF (@chState = 4)
				BEGIN 
					IF NOT EXISTS(SELECT * FROM ChequeHistory000 WHERE ChequeGUID = @chGUID AND EventNumber = 7)
					BEGIN 
						IF EXISTS (SELECT * FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 7)
						BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							select 
								ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, newid(), 
								ch.GUID, ce.Date, @chState, 7, ce.Number, 
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Debit > 0 ORDER BY en.Number), 0x0),
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Credit > 0 ORDER BY en.Number), 0x0),
								ch.Val, 7, ce.guid, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
							FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 7
						END ELSE BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							SELECT 
								ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, newid(), 
								ch.GUID, ch.Date, @chState, 7, 0, 
								0x0, 0x0, 0, 7, 0x0, ch.CurrencyGUID, ch.CurrencyVal, 0x0, 0, 0x0, 0x0
							FROM ch000 ch WHERE ch.GUID = @chGUID
						END 
					END 	
				END 

				IF (@chState = 2)
				BEGIN 
					IF NOT EXISTS(SELECT * FROM ChequeHistory000 WHERE ChequeGUID = @chGUID AND EventNumber = 2)
					BEGIN 
						IF EXISTS (SELECT * FROM ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 12)
						BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							SELECT 
								(ROW_NUMBER() OVER(ORDER BY c.Number)) + ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, 
								newid(), ch.GUID, ce.Date, @chState, 2, ce.Number, 
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Debit > 0 ORDER BY en.Number), 0x0),
								ISNULL((SELECT TOP 1 en.AccountGUID FROM en000 en WHERE en.ParentGUID = ISNULL(ce.GUID, 0x0) AND en.Credit > 0 ORDER BY en.Number), 0x0),
								c.Val, 12, ce.guid, c.CurrencyGUID, c.CurrencyVal, c.guid, 0, 0x0, 0x0
							FROM 
								ce000 ce INNER JOIN er000 er ON er.EntryGUID = ce.GUID INNER JOIN ch000 ch ON ch.guid = er.ParentGUID 
								INNER JOIN colch000 c ON c.EntryGUID = ce.GUID 
							WHERE ch.GUID = @chGUID AND er.ParentType = 12
						END ELSE BEGIN 
							INSERT INTO ChequeHistory000 (Number, GUID, ChequeGUID, Date, State, EventNumber, EntryNumber, DebitAccount, CreditAccount,
								EventVal, [EntryRelType ], EntryGUID, CurrencyGUID, CurrencyVal, ColChGuid, ExchangeRatesValue, CostDebit, CostCredit) 
							SELECT 
								(ROW_NUMBER() OVER(ORDER BY c.Number)) + ISNULL((SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = @chGUID), 0) + 1, 
								newid(), ch.GUID, c.Date, @chState, 2, 0, 
								0x0, 0x0, 
								c.Val, 12, 0x0, c.CurrencyGUID, c.CurrencyVal, c.guid, 0, 0x0, 0x0
							FROM ch000 ch INNER JOIN colch000 c ON c.chguid = ch.GUID WHERE ch.GUID = @chGUID
						END 
					END 	
				END 
				FETCH NEXT FROM @c INTO @chGUID, @chState 
			END close @c DEALLOCATE @c '

		EXEC (@Str)
	END
	EXECUTE [prcAddIntFld] 'AccCostNewRatio000', 'Entry_Rel'
	EXECUTE [prcAddIntFld] 'AccCostNewRatio000', 'Debit'
	EXECUTE [prcAlterFld] 'ce000', 'Notes', 'nvarchar(1000)'
	EXECUTE [prcAlterFld] 'en000', 'Notes', 'nvarchar(1000)'
###########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003576
AS
	SET NOCOUNT ON 
	EXECUTE	[prcAddGUIDFld] 'RestDepartment000', 'TableDesignID'
	EXECUTE	[prcAddGUIDFld] 'bp000', 'ParentDebitGUID'
	IF [dbo].[fnObjectExists]('bp000.ParentPayGUID') =  0
	BEGIN	
		EXECUTE	[prcAddGUIDFld] 'bp000', 'ParentPayGUID'
		EXEC ('
			UPDATE bp000 
			SET ParentDebitGUID = bu.GUID  
			FROM 
				bp000 bp 
				INNER JOIN en000 en ON en.GUID = bp.DebtGUID 
				INNER JOIN ce000 ce ON ce.GUID =  en.ParentGUID 
				INNER JOIN er000 er ON ce.GUID =  er.EntryGUID 
				INNER JOIN bu000 bu ON bu.GUID =  er.ParentGUID')
		EXEC ('
			UPDATE bp000 
			SET ParentPayGUID = bu.GUID  
			FROM 
				bp000 bp 
				INNER JOIN en000 en ON en.GUID = bp.PayGUID 
				INNER JOIN ce000 ce ON ce.GUID =  en.ParentGUID 
				INNER JOIN er000 er ON ce.GUID =  er.EntryGUID 
				INNER JOIN bu000 bu ON bu.GUID =  er.ParentGUID')
	END 
	EXECUTE [prcAlterFld] 'bi000', 'Notes', 'nvarchar(1000)'
##########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003578
AS 
	SET NOCOUNT ON 
	EXEC PrcAddBitFld 'bt000', 'IncludeTTCDiffOnSales'	
	EXEC PrcAddBitFld 'bt000', 'ConsideredGiftsOfSales'
	EXEC prcAddGUIDFld 'en000', 'BiGUID'
	EXEC prcDropFld		'en000', 'MatGUID'
	EXECUTE	[prcAddIntFld] 'AccCostNewRatio000', 'Number'
	EXEC('exec prcCheckDBProc_init')

	EXECUTE [prcAlterFld] 'di000', 'Notes', 'nvarchar(1000)'
	EXECUTE [prcAlterFld] 'py000', 'Notes', 'nvarchar(1000)'
	--EXEC prcDropFld		'Allocations000', 'AccountName'
	--EXEC prcDropFld		'Allocations000', 'CounterAccountName'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003579
AS
	SET NOCOUNT ON 
	--RE-ARRANGE ORDER-TYPES PERMISSIONS IN USERS-MANAGER DIALOG
	IF NOT EXISTS(SELECT * FROM SYSCOLUMNS WHERE ID = OBJECT_ID('OrderAlternativeUsers000') AND  Name = 'IsLimitedActive')
	BEGIN
		DECLARE @PermissionID INT = 268500992; 
		--Shift permissions from index 10 by 1 because inserting new permission in orders-types
		UPDATE ui 
			SET PermType = PermType + 1				
			FROM ui000 ui
				INNER JOIN bt000 bt ON bt.[GUID] = ui.SubId AND bt.[Type] IN (5, 6)
			WHERE ReportId = @PermissionID
				AND ui.PermType BETWEEN 10 AND 12
	END
	EXEC  [prcAddBitFld]		'OrderAlternativeUsers000', 'IsLimitedActive'
	EXEC  [prcAddDateFld]		'OrderAlternativeUsers000', 'StartDate'
	EXEC  [prcAddDateFld]		'OrderAlternativeUsers000', 'ExpireDate'
	EXEC  [prcAddDateFld]		'ORAddInfo000', 'FDATE'
	EXEC  [prcAddBitFld]		'bt000', 'IsDetermineCustomer'
	EXEC  [prcAddBitFld]		'bt000', 'ShowItemsCount'
	EXEC('UPDATE bt000
		 SET bPayTerms = 0
		 WHERE Type IN (5, 6)')

		EXEC('INSERT INTO
			    MaturityBills000 ([BillTypeGuid], [BillTypeName], [DaysCount], [Type] , [IsChecked])
		      SELECT
				[bt].[GUID],
				CASE [dbo].[fnConnections_getLanguage]()  WHEN 0 THEN [bt].[Name] ELSE [bt].[LatinName] END,
				0,
				[bt].[Type],
				0
		     FROM 
			    [bt000] [bt] 
		     WHERE
				([bt].[bPayTerms] = 1   --فواتير بشرط مسبقة الدفع
				OR [bt].[Type] = 5 OR [bt].[Type] = 6) --طلبيات
				AND NOT EXISTS(SELECT * FROM MaturityBills000 MB WHERE MB.BillTypeGuid = bt.[Guid])')

			EXEC [prcAddGuidFld] 'psi000', 'orderNumGuid'
			EXEC [prcAddIntFld] 'fm000', 'IsHideForm'
			EXEC('
			UPDATE mi000 SET ExpireDate=''1980-01-01 00:00:00.000''
			UPDATE bi000  
			SET expiredate =''1980-01-01 00:00:00.000''
			 WHERE MatGUID in
			( 
				SELECT mt.guid  FROM mt000 mt 
						 INNER JOIN bi000 bi on mt.guid= bi.MatGUID and mt.ExpireFlag =  0
						 INNER JOIN bu000 bu on bi.ParentGUID=bu.GUID
						 INNER JOIN bt000 bt on bt.guid= bu.TypeGUID
				where mt.ExpireFlag =  0
				AND ((bt.type=2 and bt.SortNum=5)
				 OR (bt.type=2 and bt.sortnum=6)
				OR bt.Guid = (cast((SELECT [VALUE] FROM op000 WHERE [NAME] =''man_semiconduct_outbilltype'')as uniqueidentifier)  )
				 )
			)

			');

	SELECT * INTO #tempDD FROM [dbo].[DD000]
	DELETE [DD000]
	drop table [dbo].[dd000]
	CREATE TABLE [dbo].[dd000](
		[GUID] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
		[Number] [float] NULL,
		[ParentGUID] [uniqueidentifier] NULL,
		[ADGUID] [uniqueidentifier] NULL,
		[Value] [float] NULL,
		[CurrencyGUID] [uniqueidentifier] NULL,
		[CurrencyVal] [float] NULL,
		[ToDate] [datetime] NULL,
		[CostGUID] [uniqueidentifier] NULL,
		[Notes] [nvarchar](250) NULL,
		[Percent] [float] NULL,
		[AddedVal] [float] NULL,
		[DeductVal] [float] NULL,
		[TotalDep] [float] NULL,
		[CurrAssVal] [float] NULL,
		[ReCalcVal] [float] NULL,
		[FromDate] [datetime] NULL,
		[PrevDep] float NULL,
		[StoreGUID] [uniqueidentifier] NULL,
	PRIMARY KEY CLUSTERED 
	(
		[GUID] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]

	INSERT INTO dd000 SELECT [GUID], [Number], [ParentGUID],[ADGUID], [Value], [CurrencyGUID],
		[CurrencyVal], [ToDate], [CostGUID], [Notes], [Percent], [AddedVal], [DeductVal],
		[TotalDep], [CurrAssVal] , [ReCalcVal] , [FromDate], CAST([PrevDep] AS FLOAT), [StoreGUID]  FROM #tempDD
	
	drop table #tempDD
#########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003580
AS 
	SET NOCOUNT ON 
	EXECUTE	prcAddFloatFld 'DistDeviceCu000', 'GPSX'
	EXECUTE	prcAddFloatFld 'DistDeviceCu000', 'GPSY'

	EXECUTE	prcAddFloatFld 'DistDeviceNewCu000', 'GPSX'	
	EXECUTE	prcAddFloatFld 'DistDeviceNewCu000', 'GPSY'	

	EXECUTE	prcAddFloatFld 'DistCustUpdates000', 'GPSX'
	EXECUTE	prcAddFloatFld 'DistCustUpdates000', 'GPSY'

	EXECUTE prcAddCharFld	'DistDeviceMt000', 'PicturePath', 1000
	EXECUTE prcAddCharFld	'DistDeviceMt000', 'LatinName', 100
	EXECUTE PrcAddBitFld	'DistVi000', 'UseCustGPS'
	EXECUTE PrcAddBitFld	'DistDeviceVi000', 'UseCustGPS'
	EXECUTE prcAddCharFld 'CU000',  'Head' , 100
	EXECUTE	prcAddFloatFld 'Distributor000', 'AverageVisitPeriod', 0

	EXECUTE [prcAlterFld] 'Distributor000', 'DeviceType', 'int'

	DECLARE @License1 varchar(100)
	DECLARE @Guid1 UNIQUEIDENTIFIER
	DECLARE @License2 varchar(100)
	DECLARE @Guid2 UNIQUEIDENTIFIER
	DECLARE @i INT
	SET @i = 0
	DECLARE List cursor FAST_FORWARD FOR
	SELECT Guid, License FROM Distributor000 
    
	OPEN List
	FETCH NEXT FROM List INTO @Guid1, @License1
	WHILE @@FETCH_STATUS = 0
	BEGIN	
		DECLARE c cursor FAST_FORWARD FOR  
		SELECT Guid, License FROM Distributor000 WHERE Guid <> @Guid1 AND License = @License1
	
		OPEN c
		FETCH NEXT FROM c INTO @Guid2, @License2
		WHILE @@FETCH_STATUS = 0
		BEGIN
			UPDATE Distributor000 
			SET License = @i
			WHERE Guid = @Guid2		
			SET @i = @i +1		
			FETCH NEXT FROM c INTO @Guid2, @License2
		END
		CLOSE c
		DEALLOCATE c
  
		FETCH NEXT FROM List INTO @Guid1, @License1
	END
	CLOSE List
	DEALLOCATE List

	IF NOT EXISTS (SELECT * FROM sys.indexes 
		WHERE object_id = OBJECT_ID(N'[Distributor000]') AND name = N'unique_license')
	Begin
	ALTER TABLE Distributor000 ADD CONSTRAINT unique_license UNIQUE NONCLUSTERED (License)
	End;
#########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003583
AS 
	SET NOCOUNT ON 
	EXECUTE prcAddGUIDFld 'DistDeviceEn000', 'CurrencyGuid'
	EXECUTE prcAddFloatFld 'DistDeviceEn000', 'CurrencyVal', 1
	
	EXECUTE	prcAddFloatFld 'bp000', 'PayVal'
	IF [dbo].[fnObjectExists]('bp000.PayCurVal') =  0
	BEGIN	
		EXECUTE	prcAddFloatFld 'bp000', 'PayCurVal'
		EXEC ('
			UPDATE bp000 SET PayVal = Val, PayCurVal = CurrencyVal')
	END 
	EXECUTE prcAddGUIDFld 'PFCShipmentBill000', 'AssociatedBillGuid'
#########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003584
AS 
	SET NOCOUNT ON 
	EXECUTE prcAddIntFld 'Allocations000', 'AllocNumber'

#########################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003587
AS 
	SET NOCOUNT ON 
	EXECUTE prcAddGUIDFld 'DistDeviceEn000', 'CurrencyGuid'
	EXECUTE prcAddFloatFld 'DistDeviceEn000', 'CurrencyVal', 1
	EXECUTE PrcAddBitFld  'Distributor000', 'ShowNearbyCustomersOnly', 0
	EXECUTE [prcAddIntFld] 'Distributor000', 'NewCustomerDefaultPrice', 1
	EXECUTE [prcAddBitFld] 'Distributor000', 'CanUseExpenses', 1
	EXECUTE [prcAlterFld] 'Distributor000', 'CanUseExpenses', 'int'

	IF  NOT EXISTS (
		SELECT * FROM sys.objects 
				WHERE object_id = OBJECT_ID(N'DistExpenses000') AND type in (N'U'))
		BEGIN
			CREATE TABLE DistExpenses000(
						Number int, 
						GUID uniqueidentifier Unique, 
						Name varchar(255), 
						LatinName varchar(255), 
						Code varchar(255), 
						AccountGUID uniqueidentifier, 
						EntryTypeGUID uniqueidentifier, 
						Security int)
		END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10003588
AS
	SET NOCOUNT ON 
	EXEC [prcAddFloatFld] 'OrderPayments000', 'UpdatedValue'
	EXEC [prcAddGUIDFld] 'ori000', 'PostGuid'
	EXEC [prcAddIntFld]  'ori000', 'PostNumber'
	EXEC [prcAddGUIDFld] 'ori000', 'BiGuid'
	
	insert Into op000 values (NEWID(),'NotShowBillAfterPost',0, 0, '' ,NULL, 0, 0x0, 0x0 )

	EXEC [prcAddBitFld] 'bt000', 'TotalDiscRegardlessItemDisc'
	EXEC [prcAddBitFld] 'bt000', 'TotalExtraRegardlessItemExtra'
	EXEC [prcAddBitFld]	'bt000', 'taxBeforeExtra'

	insert Into op000 values (NEWID(),'NoRepeatedMaterials',0, 0, '' ,NULL, 0, 0x0, 0x0 )

	UPDATE UI000
	SET Permission = 0
	WHERE ReportId IN (536965944, 536965945)

	--------------------------------------------
	-- SMF Project
	--------------------------------------------
	IF NOT EXISTS(SELECT * FROM [msdb].[dbo].[syscategories] WHERE [name] = N'[Ameen SJ]')
		EXECUTE [msdb].[dbo].[sp_add_category] @name = N'[Ameen SJ]'
	
	DECLARE 
		@job_id UNIQUEIDENTIFIER,
		@job_name NVARCHAR(250)

	IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name LIKE '![Ameen %' ESCAPE '!')
	BEGIN
		SELECT TOP 1 @job_id = job_id, @job_name = name FROM msdb.dbo.sysjobs 
		WHERE 
			((name LIKE '![Ameen ABJ!]%' ESCAPE '!') OR (name LIKE '![Ameen CPJ!]%' ESCAPE '!') OR (name LIKE '![Ameen RCJ!]%' ESCAPE '!') 
				OR (name LIKE '![Ameen ShrinkDBJ!]%' ESCAPE '!') OR (name LIKE '![Ameen REINDEX!]%' ESCAPE '!')
			)
			AND 
			(name LIKE '%![' + db_name() + '!]%' ESCAPE '!') 
	
		WHILE ISNULL(@job_id, 0x0) != 0x0
	BEGIN
			DECLARE @temp_name NVARCHAR(200)
			SET @temp_name = @job_name 

			SET @temp_name = REPLACE(@temp_name, '[Ameen ABJ]', 'Backup DB')
			SET @temp_name = REPLACE(@temp_name, '[Ameen CPJ]', 'Reprice Materials')
			SET @temp_name = REPLACE(@temp_name, '[Ameen RCJ]', 'Check Accounts')
			SET @temp_name = REPLACE(@temp_name, '[Ameen ShrinkDBJ]', 'Shrink DB')
			SET @temp_name = REPLACE(@temp_name, '[Ameen REINDEX]', 'Reindex DB')

			SET @temp_name = REPLACE(@temp_name, '[D]', ' Daily')
			SET @temp_name = REPLACE(@temp_name, '[W]', ' Weekly')
			SET @temp_name = REPLACE(@temp_name, '[M]', ' Monthly')

			SET @temp_name = REPLACE(@temp_name, '[' + db_name() + ']', '')
			
			SET @temp_name = '[Ameen SJ][' + db_name() + ']' + @temp_name
			EXEC msdb.[dbo].[sp_update_job] @job_id = @job_id, @new_name = @temp_name, @description = N'Job added from Al-Ameen Program.', @category_name = N'[Ameen SJ]'

			DECLARE @step_id INT, @step_uid UNIQUEIDENTIFIER, @ignoreLastPriceAndCost NVARCHAR(10)

			SELECT TOP 1 @step_id = step_id, @step_uid = step_uid FROM msdb.dbo.sysjobsteps WHERE job_id = @job_id ORDER BY step_id

			IF ISNULL(@step_id, 0) != 0
			BEGIN
				IF (@job_name LIKE '![Ameen CPJ!]%' ESCAPE '!')
				BEGIN 
					DECLARE @command NVARCHAR(250) 
					SET @command = (SELECT command FROM msdb.dbo.sysjobsteps WHERE job_id = @job_id AND step_id = @step_id)
					IF ISNULL(@command, '') != ''
						SET @ignoreLastPriceAndCost = SUBSTRING(@command, LEN(@command), 1)
	END

				DECLARE 
					@new_step_name NVARCHAR(500),
					@new_command NVARCHAR(500)
				
				SET @new_step_name = 
						(CASE 
							WHEN (@job_name LIKE '![Ameen ABJ!]%' ESCAPE '!') THEN 'Backup DB'
							WHEN (@job_name LIKE '![Ameen CPJ!]%' ESCAPE '!') THEN 'Reprice Materials'
							WHEN (@job_name LIKE '![Ameen RCJ!]%' ESCAPE '!') THEN 'Check Accounts'
							WHEN (@job_name LIKE '![Ameen ShrinkDBJ!]%' ESCAPE '!') THEN 'Shrink DB'
							WHEN (@job_name LIKE '![Ameen REINDEX!]%' ESCAPE '!') THEN 'Reindex DB'
							ELSE ''
						END)
				SET @new_command = 
						(CASE 
							WHEN (@job_name LIKE '![Ameen ABJ!]%' ESCAPE '!') THEN 'EXEC prc_SJ_Backup @TaskID = ''' + CAST(@step_uid AS NVARCHAR(250)) + ''''
							WHEN (@job_name LIKE '![Ameen CPJ!]%' ESCAPE '!') THEN 'EXEC prc_SJ_RepriceMaterials @TaskID = ''' + CAST(@step_uid AS NVARCHAR(250)) + ''''
							WHEN (@job_name LIKE '![Ameen RCJ!]%' ESCAPE '!') THEN 'EXEC prcEntry_rePost'
							WHEN (@job_name LIKE '![Ameen ShrinkDBJ!]%' ESCAPE '!') THEN 'EXEC prc_SJ_ShrinkDB @TaskID = ''' + CAST(@step_uid AS NVARCHAR(250)) + ''''
							WHEN (@job_name LIKE '![Ameen REINDEX!]%' ESCAPE '!') THEN 'EXEC prcReIndexDatabase'
							ELSE ''
						END)					
				
				EXEC msdb.[dbo].[sp_update_jobstep] @job_id = @job_id, @step_id = @step_id, @step_name = @new_step_name, @command = @new_command

				IF (@job_name LIKE '![Ameen ABJ!]%' ESCAPE '!')
				BEGIN
					DECLARE @BAK_NUM NVARCHAR(10)
					IF (@job_name LIKE '![Ameen ABJ!]![D!]%' ESCAPE '!')
						SET @BAK_NUM = (SELECT TOP 1 Value FROM op000 WHERE Name = 'AmnCfg_DailyBackupNum' AND Type = 0)
					IF (@job_name LIKE '![Ameen ABJ!]![W!]%' ESCAPE '!')
						SET @BAK_NUM = (SELECT TOP 1 Value FROM op000 WHERE Name = 'AmnCfg_WeeklyBackupNum' AND Type = 0)
					IF (@job_name LIKE '![Ameen ABJ!]![M!]%' ESCAPE '!')
						SET @BAK_NUM = (SELECT TOP 1 Value FROM op000 WHERE Name = 'AmnCfg_MonthlyBackupNum' AND Type = 0)
					IF ISNULL(@BAK_NUM, '') != ''
					BEGIN
						INSERT INTO ScheduledJobOptions000(GUID, JobGUID, TaskGUID, Name, Value) 
						SELECT NEWID(), @job_id, CAST(@step_uid AS NVARCHAR(250)), 'BAK_Num', @BAK_NUM
					END
				END
				IF (@job_name LIKE '![Ameen CPJ!]%' ESCAPE '!')
				BEGIN
					IF (ISNULL(@ignoreLastPriceAndCost, '') IN ('0', '1'))
					BEGIN 
						INSERT INTO ScheduledJobOptions000(GUID, JobGUID, TaskGUID, Name, Value) 
						SELECT NEWID(), @job_id, CAST(@step_uid AS NVARCHAR(250)), 'REPM_PreserveLast', @ignoreLastPriceAndCost
					END ELSE BEGIN
						INSERT INTO ScheduledJobOptions000(GUID, JobGUID, TaskGUID, Name, Value) 
						SELECT NEWID(), @job_id, CAST(@step_uid AS NVARCHAR(250)), 'REPM_PreserveLast', '0'
					END
				END
			END 

			SET @job_id = NULL
			SET @job_name = NULL

			SELECT TOP 1 @job_id = job_id, @job_name = name FROM msdb.dbo.sysjobs 
			WHERE 
				((name LIKE '![Ameen ABJ!]%' ESCAPE '!') OR (name LIKE '![Ameen CPJ!]%' ESCAPE '!') OR (name LIKE '![Ameen RCJ!]%' ESCAPE '!') 
					OR (name LIKE '![Ameen ShrinkDBJ!]%' ESCAPE '!') OR (name LIKE '![Ameen REINDEX!]%' ESCAPE '!')
				)
				AND 
				(name LIKE '%![' + db_name() + '!]%' ESCAPE '!') 
		END
	END
	
	EXEC [prcAddIntFld] 'bt000', 'FldClassPrice'
	EXEC [prcAddFloatFld] 'bi000', 'TotalDiscountPercent'
	EXEC [prcAddFloatFld] 'bi000', 'TotalExtraPercent'
	EXEC [prcAddFloatFld] 'bi000', 'ClassPrice'
	EXEC [prcAddFloatFld] 'bi000', 'MatCurVal'
    EXECUTE [prcAddBitFld]  'mt000', 'ClassFlag'
    EXECUTE [prcAddBitFld]  'mt000', 'ForceInClass'
	IF [dbo].[fnObjectExists]('mt000.ForceOutClass') =  0
	BEGIN
	
		IF NOT EXISTS(SELECT * FROM mc000 WHERE Number = 1024 AND Asc1 = 'ReCalcBillCP' AND Num1 = 1)
		BEGIN
			INSERT INTO mc000(Number, Asc1, Num1)
			VALUES (1024, 'ReCalcBillCP', 1)
		END

        EXECUTE [prcAddBitFld]  'mt000', 'ForceOutClass'
		EXEC(N'UPDATE BLItems000 SET FldIndex = FldIndex + 1 WHERE FldIndex > 1081');
		EXEC(N'UPDATE mt SET ClassFlag = 1 FROM mt000 mt INNER JOIN bi000 bi ON bi.MatGUID = mt.GUID WHERE bi.[ClassPtr] != ''''')
	END 
      
	EXECUTE [prcAddBitFld] 'mt000', 'DisableLastPrice'
	EXECUTE [prcAddFloatFld] 'mt000', 'LastPriceCurVal'
	EXEC prcAddDateFld 'cp000', 'Date'

	DECLARE 
		@c CURSOR,
		@mtGuid [UNIQUEIDENTIFIER]

	SET @c = CURSOR FAST_FORWARD FOR 
			SELECT GUID FROM mt000

	OPEN @c FETCH FROM @c INTO @mtGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
			DECLARE @buDate DATE, @biPrice FLOAT, @biUnitFact FLOAT, @buCurrencyGUID UNIQUEIDENTIFIER, @buCurrencyVal FLOAT, @mtCurrencyGUID UNIQUEIDENTIFIER
			SELECT TOP 1 
				@buDate = bu.date,
				@biPrice = [bi].[Price],
				@biUnitFact = 
					(CASE [bi].[Unity]
						WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE bi.[Qty] / (CASE bi.[Qty2] WHEN 0 THEN 1 ELSE bi.[Qty2] END) END)
						WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE bi.[Qty] / (CASE bi.[Qty3] WHEN 0 THEN 1 ELSE bi.[Qty3] END) END)
						ELSE 1
					END),
				@buCurrencyGUID = bu.CurrencyGUID,
				@buCurrencyVal = bu.CurrencyVal,
				@mtCurrencyGUID = mt.CurrencyGUID
			FROM
				bu000 bu 
				INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID 
				INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID 
				INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
			WHERE 
				bt.bAffectLastPrice = 1 
				AND 
				bi.matguid = @mtGuid
			ORDER BY 
				bu.date DESC,
				bt.[SortFlag] DESC,
				bu.Number DESC,
				bi.Number DESC

			DECLARE @LastPriceStr NVARCHAR(MAX);
			IF (@buDate IS NULL)
			BEGIN 
                SET @LastPriceStr = 'UPDATE mt000 SET DisableLastPrice = 0 WHERE guid = ''' + CAST(@mtGuid AS NVARCHAR(250))+ ''' AND DisableLastPrice <> 0 ';
                EXEC(@LastPriceStr);
			END ELSE BEGIN 
				DECLARE @LastPrice FLOAT 
				DECLARE @LastPrice_CurrencyVal FLOAT 
				
				SET @LastPrice = (CASE @biUnitFact WHEN 0 THEN 0 ELSE @biPrice / @biUnitFact END)
				SET @LastPrice_CurrencyVal = @buCurrencyVal

				IF @buCurrencyGUID <> @mtCurrencyGUID
				BEGIN 
					DECLARE @mtCurrencyVal_ByDate FLOAT 
					SET @mtCurrencyVal_ByDate = [dbo].fnGetCurVal(@mtCurrencyGUID, @buDate);
					IF ISNULL(@mtCurrencyVal_ByDate, 0) <> 0
					BEGIN 
						SET @LastPrice_CurrencyVal = @mtCurrencyVal_ByDate
						--SET @LastPrice = @LastPrice* @buCurrencyVal/ @mtCurrencyVal_ByDate
					END
				END 

                        SET @LastPriceStr =
                        'UPDATE mt000 
                             SET [DisableLastPrice] = 1,
                              [LastPriceDate] =' + CAST(@buDate  AS NVARCHAR(50))+',
                              [LastPrice] = ' +CAST( @LastPrice  AS NVARCHAR(50))+ ' ,
                              [LastPrice2] = ' +CAST( @LastPrice  AS NVARCHAR(50)) + ' * Unit2Fact,
                              [LastPrice3] = ' +CAST( @LastPrice  AS NVARCHAR(50))+' * Unit3Fact, 
                              [LastPriceCurVal] = ' +CAST( @LastPrice_CurrencyVal  AS NVARCHAR(50))+ '
				WHERE 
                              [GUID] = ''' +CAST(@mtGuid AS NVARCHAR(50))+'''';
                        EXEC(@LastPriceStr)
			END

		FETCH FROM @c INTO @mtGuid
	END
	CLOSE @c
	DEALLOCATE @c

	IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'CanselCheckingAvailableSpace' AND Value = '1')
	BEGIN 
		IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'NumberDaysAfterShrink')
		BEGIN 
			INSERT INTO op000([GUID], Name, Value, [Type])
			SELECT NEWID(), 'NumberDaysAfterShrink', '10', 0
		END 	
		IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'NumberDaysOFShrink')
		BEGIN 
			INSERT INTO op000([GUID], Name, Value, [Type])
			SELECT NEWID(), 'NumberDaysOFShrink', '7', 0
		END 	
		IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'AllowedWaste')
		BEGIN 
			INSERT INTO op000([GUID], Name, Value, [Type])
			SELECT NEWID(), 'AllowedWaste', '75', 0
		END 	
	END

	-------------------------------------------------------------------------------------------
	----
	----							Distributor000
	----
	-------------------------------------------------------------------------------------------
	IF (SELECT object_id('#TempDistributor000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistributor000
	END

	SELECT * INTO #TempDistributor000 FROM Distributor000
	DROP TABLE Distributor000

	--Recreate Original With Constrains 
	--BEGIN

	CREATE TABLE Distributor000
	(
		[Number] [float] NULL DEFAULT ((0)),
		[GUID] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[Code] [nvarchar](100) NULL DEFAULT (''),
		[Name] [nvarchar](250) NULL DEFAULT (''),
		[LatinName] [nvarchar](250) NULL DEFAULT (''),
		[HierarchyGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Security] [int] NULL DEFAULT ((0)),
		[VanGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[StoreGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[PalmUserName] [nvarchar](250) NULL DEFAULT (''),
		[MatGroupGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[CustAccGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[AccountGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[ExportStoreGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[ExportCostGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[MatSortFld] [nvarchar](250) NULL DEFAULT (''),
		[CustSortFld] [nvarchar](250) NULL DEFAULT (''),
		[GLStartDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[GLEndDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[GLStartDateFlag] [int] NULL DEFAULT ((0)),
		[ExportAccFlag] [int] NULL DEFAULT ((0)),
		[ExportStoreFlag] [int] NULL DEFAULT ((0)),
		[ExportCostsFlag] [int] NULL DEFAULT ((0)),
		[MatCondId] [int] NULL DEFAULT ((0)),
		[CustCondId] [int] NULL DEFAULT ((0)),
		[ExportSerialNumFlag] [int] NULL DEFAULT ((0)),
		[ExportEmptyMaterialFlag] [int] NULL DEFAULT ((0)),
		[License] [nvarchar](250) NULL DEFAULT (''),
		[PrimSalesmanGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[AssisSalesmanGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[DriverAccGUID] [uniqueidentifier] NULL DEFAULT (0x00), 
		[TypeGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[CurrSaleMan] [int] NULL DEFAULT ((0)),
		[VisitPerDay] [int] NULL DEFAULT ((0)),
		[ItemDiscType] [int] NULL DEFAULT ((0)),
		[CustomersAccGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[AutoPostBill] [bit] NULL DEFAULT ((0)),
		[AutoGenBillEntry] [bit] NULL DEFAULT ((0)),
		[AccessByBarcode] [bit] NULL DEFAULT ((0)),
		[NoOvertakeMaxDebit] [bit] NULL DEFAULT ((0)),
		[CustBalanceByJobCost] [bit] NULL DEFAULT ((0)),
		[OutNegative] [bit] NULL DEFAULT ((0)),
		[CanChangePrice] [bit] NULL DEFAULT ((0)),
		[ShowTodayRoute] [bit] NULL DEFAULT ((0)),
		[UseCustLastPrice] [bit] NULL DEFAULT ((0)),
		[ExportAllCustDetailFlag] [bit] NULL DEFAULT ((0)),
		[CustBarcodeHasValidate] [bit] NULL DEFAULT ((0)),
		[DefaultPayType] [int] NULL DEFAULT ((0)),
		[DistributorPassword] [nvarchar](250) NULL DEFAULT (''),
		[SupervisorPassword] [nvarchar](250) NULL DEFAULT (''), 
		[branchMask] [bigint] NULL DEFAULT ((0)),
		[CanChangeCustBarcode] [bit] NULL DEFAULT ((0)),
		[PrintPrice] [int] NULL DEFAULT ((0)),
		[ExportOffers] [bit] NULL DEFAULT ((0)),
		[CheckBillOffers] [bit] NULL DEFAULT ((0)),
		[CanAddBonus] [bit] NULL DEFAULT ((0)),
		[AddMatByBarcode] [bit] NULL DEFAULT ((0)),
		[CanUpdateOffer] [bit] NULL DEFAULT ((0)),
		[ExportAfterZeroAcc] [bit] NULL DEFAULT ((0)),
		[CanAddCustomer] [bit] NULL DEFAULT ((0)),
		[ChangeCustCard] [bit] NULL DEFAULT ((0)),
		[IsSync] [bit] NULL DEFAULT ((0)),
		[MatCondGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[CustCondGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[DeviceType] [int] NULL DEFAULT ((0)),
		[ExportCustAcc] [bit] NULL DEFAULT ((0)),
		[AccessByRFID] [bit] NULL DEFAULT ((0)),
		[IgnoreNoDetailsVisits] [bit] NULL DEFAULT ((0)),
		[ExportCustAccDays] [bit] NULL DEFAULT ((0)),
		[ExportCustAccDaysNumber] [int] NULL DEFAULT ((0)),
		[ExportDetailedCustAcc] [bit] NULL DEFAULT ((0)),
		[ExportCustInRouteOnly] [bit] NULL DEFAULT ((0)),
		[OutRouteVisitsNumber] [int] NULL DEFAULT ((0)),
		[CanUpdateBill] [bit] NULL DEFAULT ((0)),
		[CanDeleteBill] [bit] NULL DEFAULT ((0)),
		[EndVisitByBarcode] [bit] NULL DEFAULT ((0)),
		[UseStockOfCust] [int] NULL DEFAULT ((0)),
		[UseShelfShare] [int] NULL DEFAULT ((0)),
		[UseActivity] [int] NULL DEFAULT ((0)),
		[UseCustTarget] [int] NULL DEFAULT ((0)),
		[ShowCustInfo] [int] NULL DEFAULT ((0)),
		[ShowQuestionnaire] [int] NULL DEFAULT ((0)),
		[ShowBills] [int] NULL DEFAULT ((0)),
		[ShowEntries] [int] NULL DEFAULT ((0)),
		[ShowRequiredMaterials] [int] NULL DEFAULT ((0)),
		[SpecifyOrder] [bit] NULL DEFAULT ((0)),
		[LastBuNumber] [int] NULL DEFAULT ((0)),
		[LastEnNumber] [int] NULL DEFAULT ((0)),
		[UploadPassword] [nvarchar](250) NULL DEFAULT (''),
		[ResetDaily] [int] NULL DEFAULT ((0)),
		[UseCustomerPrice] [int] NULL DEFAULT ((0)),
		[HideEmptyMatInEntryBills] [bit] NULL DEFAULT ((0)),
		[CanUseGPRS] [bit] NULL DEFAULT ((0)),
		[VerificationStore] [uniqueidentifier] NULL DEFAULT (0x00),
		[GPRSTransferType] [uniqueidentifier] NULL DEFAULT (0x00),
		[UploadBranch] [uniqueidentifier] NULL DEFAULT (0x00),
		[AverageVisitPeriod] [float] NULL DEFAULT ((0)),
		[ShowNearbyCustomersOnly] [bit] NULL DEFAULT ((0)),
		[NewCustomerDefaultPrice] [int] NULL DEFAULT ((0)),
		[CanUseExpenses] [int] NULL DEFAULT ((0))
		
		PRIMARY KEY CLUSTERED 
		([GUID] ASC)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
	--END

	INSERT INTO Distributor000 
		(
			[Number], [GUID], [Code], [Name], [LatinName], [HierarchyGUID], [Security], [VanGUID], [StoreGUID], [PalmUserName], [MatGroupGUID], [CustAccGUID], [AccountGUID],
			[ExportStoreGUID], [ExportCostGUID], [MatSortFld], [CustSortFld], [GLStartDate], [GLEndDate], [GLStartDateFlag], [ExportAccFlag], [ExportStoreFlag], [ExportCostsFlag],
			[MatCondId], [CustCondId], [ExportSerialNumFlag], [ExportEmptyMaterialFlag], [License], [PrimSalesmanGUID], [AssisSalesmanGUID], [DriverAccGUID], [TypeGuid],
			[CurrSaleMan], [VisitPerDay], [ItemDiscType], [CustomersAccGUID], [AutoPostBill], [AutoGenBillEntry], [AccessByBarcode], [NoOvertakeMaxDebit], [CustBalanceByJobCost],
			[OutNegative], [CanChangePrice], [ShowTodayRoute], [UseCustLastPrice], [ExportAllCustDetailFlag], [CustBarcodeHasValidate], [DefaultPayType], [DistributorPassword],
			[SupervisorPassword], [branchMask], [CanChangeCustBarcode], [PrintPrice], [ExportOffers], [CheckBillOffers], [CanAddBonus], [AddMatByBarcode], [CanUpdateOffer], 
			[ExportAfterZeroAcc], [CanAddCustomer], [ChangeCustCard], [IsSync], [MatCondGUID], [CustCondGUID], [DeviceType], [ExportCustAcc], [AccessByRFID], [IgnoreNoDetailsVisits], 
			[ExportCustAccDays], [ExportCustAccDaysNumber], [ExportDetailedCustAcc], [ExportCustInRouteOnly], [OutRouteVisitsNumber], [CanUpdateBill], [CanDeleteBill], [EndVisitByBarcode],
			[UseStockOfCust], [UseShelfShare], [UseActivity], [UseCustTarget], [ShowCustInfo], [ShowQuestionnaire], [ShowBills], [ShowEntries], [ShowRequiredMaterials], [SpecifyOrder],
			[LastBuNumber], [LastEnNumber], [UploadPassword], [ResetDaily], [UseCustomerPrice], [HideEmptyMatInEntryBills], [CanUseGPRS], [VerificationStore], [GPRSTransferType],
			[UploadBranch], [AverageVisitPeriod], [ShowNearbyCustomersOnly], [NewCustomerDefaultPrice]
		)

	Select 
			[Number], [GUID], [Code], [Name], [LatinName], [HierarchyGUID], [Security], [VanGUID], [StoreGUID], [PalmUserName], [MatGroupGUID], [CustAccGUID], [AccountGUID],
			[ExportStoreGUID], [ExportCostGUID], [MatSortFld], [CustSortFld], [GLStartDate], [GLEndDate], [GLStartDateFlag], [ExportAccFlag], [ExportStoreFlag], [ExportCostsFlag],
			[MatCondId], [CustCondId], [ExportSerialNumFlag], [ExportEmptyMaterialFlag], [License], [PrimSalesmanGUID], [AssisSalesmanGUID], [DriverAccGUID], [TypeGuid],
			[CurrSaleMan], [VisitPerDay], [ItemDiscType], [CustomersAccGUID], [AutoPostBill], [AutoGenBillEntry], [AccessByBarcode], [NoOvertakeMaxDebit], [CustBalanceByJobCost],
			[OutNegative], [CanChangePrice], [ShowTodayRoute], [UseCustLastPrice], [ExportAllCustDetailFlag], [CustBarcodeHasValidate], [DefaultPayType], [DistributorPassword],
			[SupervisorPassword], [branchMask], [CanChangeCustBarcode], [PrintPrice], [ExportOffers], [CheckBillOffers], [CanAddBonus], [AddMatByBarcode], [CanUpdateOffer], 
			[ExportAfterZeroAcc], [CanAddCustomer], [ChangeCustCard], [IsSync], [MatCondGUID], [CustCondGUID], [DeviceType], [ExportCustAcc], [AccessByRFID], [IgnoreNoDetailsVisits], 
			[ExportCustAccDays], [ExportCustAccDaysNumber], [ExportDetailedCustAcc], [ExportCustInRouteOnly], [OutRouteVisitsNumber], [CanUpdateBill], [CanDeleteBill], [EndVisitByBarcode],
			[UseStockOfCust], [UseShelfShare], [UseActivity], [UseCustTarget], [ShowCustInfo], [ShowQuestionnaire], [ShowBills], [ShowEntries], [ShowRequiredMaterials], [SpecifyOrder],
			[LastBuNumber], [LastEnNumber], [UploadPassword], [ResetDaily], [UseCustomerPrice], [HideEmptyMatInEntryBills], [CanUseGPRS], [VerificationStore], [GPRSTransferType],
			[UploadBranch], [AverageVisitPeriod], [ShowNearbyCustomersOnly], [NewCustomerDefaultPrice]
	FROM #TempDistributor000

	IF (SELECT object_id('#TempDistributor000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistributor000
	END

	-------------------------------------------------------------------------------------------
	----
	----							TrnStatementItems000
	----
	------------------------------------------------------------------------------------------- 
	IF (SELECT object_id('#TempTrnStatementItems000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempTrnStatementItems000
	END

	SELECT * INTO #TempTrnStatementItems000 FROM TrnStatementItems000
	DROP TABLE TrnStatementItems000

	--Recreate Original With Constrains 
	--BEGIN
	
	CREATE TABLE TrnStatementItems000
	(
		[Number] [int] NULL DEFAULT ((0)),
		[GUID] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[Type] [int] NULL DEFAULT ((0)),
		[ParentGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Code] [nvarchar](100) NULL DEFAULT (''),
		[OriginalCode] [nvarchar](100) NULL DEFAULT (''),
		[Date] [datetime] NULL DEFAULT ('1/1/1980'),
		[DueDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[StatementNumber] [nvarchar](100) NULL DEFAULT (''),
		[SenderGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Receiver1_GUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Receiver2_GUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Receiver3_GUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[PayType] [int] NULL DEFAULT ((0)),
		[AccountGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Amount] [float] NULL  DEFAULT ((0)),
		[Wages] [float] NULL  DEFAULT ((0)),
		[CurrencyGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[CurrencyVal] [float] NULL DEFAULT ((0)),
		[WagesType] [int] NULL DEFAULT ((0)),
		[Notes] [nvarchar](100) NULL DEFAULT (''),
		[branchMask] [bigint] NULL DEFAULT ((0)),
		[Discount] [float] NULL DEFAULT ((0)),
		[MustCashedAmount] [float] NULL DEFAULT ((0)),
		[MustPaidAmount] [float] NULL DEFAULT ((0)),
		[IsVoucherGenerated] [int] NULL DEFAULT ((0)),
		[VoucherState] [int] NULL DEFAULT ((0)),
		[TransferVoucherGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[CreditAcc] [uniqueidentifier] NULL DEFAULT (0x00),
		[NetWages] [float] NULL DEFAULT ((0)),
		[Amount2] [float] NULL DEFAULT ((0)),
		[CurrencyGUID2] [uniqueidentifier] NULL DEFAULT (0x00),
		[CurrencyVal2] [float] NULL DEFAULT ((0)),
		[WagesCost] [float] NULL DEFAULT ((0)),
		[DestinationGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[SourceBranch] [uniqueidentifier] NULL DEFAULT (0x00),
		[DestinationBranch] [uniqueidentifier] NULL DEFAULT (0x00),
		[DestinationType] [int] NULL DEFAULT ((0)),
		[Reason] [nvarchar](250) NULL DEFAULT ('')

		PRIMARY KEY CLUSTERED 
		([GUID] ASC)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
	--END

	INSERT INTO TrnStatementItems000 
		(
			[Number], [GUID], [Type], [ParentGUID], [Code], [OriginalCode], [Date], [DueDate], [StatementNumber], [SenderGUID], [Receiver1_GUID], [Receiver2_GUID], [Receiver3_GUID],
			[PayType], [AccountGUID], [Amount], [Wages], [CurrencyGUID], [CurrencyVal], [WagesType], [Notes], [branchMask], [Discount], [MustCashedAmount], [MustPaidAmount],
			[IsVoucherGenerated], [VoucherState], [TransferVoucherGuid], [CreditAcc], [NetWages], [Amount2], [CurrencyGUID2], [CurrencyVal2], [WagesCost], [DestinationGUID],
			[SourceBranch], [DestinationBranch], [DestinationType], [Reason]
		)

	Select 
			[Number], [GUID], [Type], [ParentGUID], [Code], [OriginalCode], [Date], [DueDate], [StatementNumber], [SenderGUID], [Receiver1_GUID], [Receiver2_GUID], [Receiver3_GUID],
			[PayType], [AccountGUID], [Amount], [Wages], [CurrencyGUID], [CurrencyVal], [WagesType], [Notes], [branchMask], [Discount], [MustCashedAmount], [MustPaidAmount],
			[IsVoucherGenerated], [VoucherState], [TransferVoucherGuid], [CreditAcc], [NetWages], [Amount2], [CurrencyGUID2], [CurrencyVal2], [WagesCost], [DestinationGUID],
			[SourceBranch], [DestinationBranch], [DestinationType], [Reason]
	FROM #TempTrnStatementItems000

	IF (SELECT object_id('#TempTrnStatementItems000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempTrnStatementItems000
	END

	-------------------------------------------------------------------------------------------
	----
	----							DistDeviceProBudget000
	----
	-------------------------------------------------------------------------------------------
	IF (SELECT object_id('#TempDistDeviceProBudget000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDeviceProBudget000
	END

	SELECT * INTO #TempDistDeviceProBudget000 FROM DistDeviceProBudget000
	DROP TABLE DistDeviceProBudget000
	
	--Recreate Original With Constrains 
	--BEGIN

	CREATE TABLE [dbo].[DistDeviceProBudget000]
	(
		[GUID] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[DistributorGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[ProGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[ProQty] [float] NULL DEFAULT ((0))

		PRIMARY KEY CLUSTERED 
		([GUID] ASC)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
	--END

	INSERT INTO DistDeviceProBudget000 
		(
			[GUID], [DistributorGuid], [ProGuid], [ProQty]
		)

	Select 
			[GUID], [DistributorGuid], [ProGuid], [ProQty]
	FROM #TempDistDeviceProBudget000

	IF (SELECT object_id('#TempDistDeviceProBudget000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDeviceProBudget000
	END

	-------------------------------------------------------------------------------------------
	----
	----							DistPromotions000
	----
	-------------------------------------------------------------------------------------------
	IF (SELECT object_id('#TempDistPromotions000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistPromotions000
	END

	SELECT * INTO #TempDistPromotions000 FROM DistPromotions000
	DROP TABLE DistPromotions000
	
	--Recreate Original With Constrains 
	--BEGIN

	CREATE TABLE DistPromotions000
	(
		[Number] [int] NULL DEFAULT ((0)),
		[GUID] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[FDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[LDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[Name] [nvarchar](100) NULL DEFAULT (''), 
		[CondQty] [float] NULL DEFAULT ((0)),
		[FreeQty] [float] NULL DEFAULT ((0)),
		[Type] [int] NULL DEFAULT ((0)),
		[DiscType] [int] NULL DEFAULT ((0)),
		[CondType] [int] NULL DEFAULT ((0)),
		[FreeType] [int] NULL DEFAULT ((0)),
		[IsActive] [bit] NULL DEFAULT ((0)),
		[ChkExactlyQty] [bit] NULL DEFAULT ((0)),
		[Security] [int] NULL DEFAULT ((0)),
		[Code] [nvarchar](100) NULL DEFAULT (''),
		[CustCondGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[branchMask] [bigint] NULL DEFAULT ((0)),
		[ImagePath] [nvarchar](1000) NULL DEFAULT (''),
		[MatCondGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[CondUnity] [int] NULL DEFAULT ((0)),
		[FreeUnity] [int] NULL DEFAULT ((0))

		PRIMARY KEY CLUSTERED 
		([GUID] ASC)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
		ON [PRIMARY]
	) ON [PRIMARY]

	--END

	INSERT INTO DistPromotions000
		(
			[Number], [GUID], [FDate], [LDate], [Name], [CondQty], [FreeQty], [Type], [DiscType], [CondType], [FreeType], [IsActive], [ChkExactlyQty],
			[Security], [Code], [CustCondGUID], [branchMask], [ImagePath], [MatCondGUID], [CondUnity], [FreeUnity]
		)

	Select 
			[Number], [GUID], [FDate], [LDate], [Name], [CondQty], [FreeQty], [Type], [DiscType], [CondType], [FreeType], [IsActive], [ChkExactlyQty],
			[Security], [Code], [CustCondGUID], [branchMask], [ImagePath], [MatCondGUID], [CondUnity], [FreeUnity]
	FROM #TempDistPromotions000


	-------------------------------------------------------------------------------------------
	----
	----							DistDeviceNewCu000
	----
	-------------------------------------------------------------------------------------------
	IF (SELECT object_id('#TempDistDeviceNewCu000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDeviceNewCu000
	END

	SELECT * INTO #TempDistDeviceNewCu000 FROM DistDeviceNewCu000
	DROP TABLE DistDeviceNewCu000
	
	--Recreate Original With Constrains 
	--BEGIN

	CREATE TABLE DistDeviceNewCu000
	(
		[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[DistributorGuid] [uniqueidentifier] NULL  DEFAULT (0x00),
		[CustomerGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[NewBarcode] [nvarchar](250) NULL DEFAULT (''),
		[NewNotes] [nvarchar](250) NULL DEFAULT (''),
		[Name] [nvarchar](250) NULL DEFAULT (''),
		[LatinName] [nvarchar](250) NULL DEFAULT (''),
		[Area] [nvarchar](50) NULL DEFAULT (''),
		[Street] [nvarchar](50) NULL DEFAULT (''),
		[Phone] [nvarchar](30) NULL DEFAULT (''),
		[Mobile] [nvarchar](30) NULL DEFAULT (''),
		[PersonalName] [nvarchar](100) NULL DEFAULT (''),
		[CustomerTypeGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[TradeChannelGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[Contracted] [bit] NULL DEFAULT ((0)),
		[GPSX] [float] NULL DEFAULT ((0)),
		[GPSY] [float] NULL DEFAULT ((0))

		PRIMARY KEY CLUSTERED 
		(
			[Guid] ASC
		)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]) 
		ON [PRIMARY]

	--END

	INSERT INTO DistDeviceNewCu000 
		(
			[Guid], [DistributorGuid], [CustomerGuid], [NewBarcode], [NewNotes], [Name], [LatinName], [Area], [Street], [Phone], [Mobile], [PersonalName], [CustomerTypeGuid],
			[TradeChannelGuid], [Contracted], [GPSX], [GPSY]
		)

	Select 
			[Guid], [DistributorGuid], [CustomerGuid], [NewBarcode], [NewNotes], [Name], '', [Area], [Street], [Phone], [Mobile], [PersonalName], [CustomerTypeGuid],
			[TradeChannelGuid], [Contracted], [GPSX], [GPSY]
	FROM #TempDistDeviceNewCu000

	IF (SELECT object_id('#TempDistDeviceNewCu000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDeviceNewCu000
	END

	-------------------------------------------------------------------------------------------
	----
	----							DistDeviceST000
	----
	-------------------------------------------------------------------------------------------
	IF (SELECT object_id('#TempDistDeviceST000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDeviceST000
	END
	
	SELECT * INTO #TempDistDeviceST000 FROM DistDeviceST000
	DROP TABLE DistDeviceST000
	
	--Recreate Original With Constrains 
	--BEGIN
	
	CREATE TABLE DistDeviceST000
	(
		[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[DistributorGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[ParentGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[CustGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[Name] [nvarchar](250) NULL DEFAULT (''),
		[LatinName] [nvarchar](250) NULL DEFAULT (''),
		[stGuid] [uniqueidentifier] NULL DEFAULT (0x00)
	
		PRIMARY KEY CLUSTERED 
		(
			[Guid] ASC
		)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
	
	--END
	
	INSERT INTO DistDeviceST000 
		(
			[Guid], [DistributorGUID], [ParentGuid], [CustGuid], [Name], [LatinName],[stGuid] 
		)
	
	Select 
			[Guid], [DistributorGUID], [ParentGuid], [CustGuid], [Name], '',[stGuid]
	FROM #TempDistDeviceST000
	
	IF (SELECT object_id('#TempDistDeviceST000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDeviceST000
	END

	-------------------------------------------------------------------------------------------
	----
	----							DistDevicePro000
	----
	-------------------------------------------------------------------------------------------
	IF (SELECT object_id('#TempDistDevicePro000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDevicePro000
	END

	SELECT * INTO #TempDistDevicePro000 FROM DistDevicePro000
	DROP TABLE DistDevicePro000
	
	--Recreate Original With Constrains 
	--BEGIN

	CREATE TABLE DistDevicePro000
	(
		[GUID] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[DistributorGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[ProGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Name] [nvarchar](250) NULL DEFAULT (''), 
		[StartDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[EndDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[CondQty] [float] NULL DEFAULT ((0)),
		[FreeQty] [float] NULL DEFAULT ((0)),
		[ProBudget] [int] NULL DEFAULT ((0)),
		[ProQty] [int] NULL DEFAULT ((0)),
		[ProNumber] [int] NULL DEFAULT ((0)),
		[CondType] [int] NULL DEFAULT ((0)),
		[FreeType] [int] NULL DEFAULT ((0)),
		[ChkExactlyQty] [bit] NULL DEFAULT ((0)),
		[ImagePath] [nvarchar](1000) NULL DEFAULT (''),
		[CondUnity] [int] NULL DEFAULT ((0)),
		[FreeUnity] [int] NULL DEFAULT ((0))

		PRIMARY KEY CLUSTERED 
		(
			[GUID] ASC
		)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

	--END

	INSERT INTO DistDevicePro000 
		(
			[GUID], [DistributorGUID], [ProGUID], [Name], [StartDate], [EndDate], [CondQty], [FreeQty], [ProBudget], [ProQty], [ProNumber],
			[CondType], [FreeType], [ChkExactlyQty], [ImagePath], [CondUnity], [FreeUnity] 
		)

	Select 
			[GUID], [DistributorGUID], [ProGUID], [Name], [StartDate], [EndDate], [CondQty], [FreeQty], [ProBudget], [ProQty], [ProNumber],
			[CondType], [FreeType], [ChkExactlyQty], [ImagePath], [CondUnity], [FreeUnity] 
	FROM #TempDistDevicePro000

	IF (SELECT object_id('#TempDistDevicePro000')) IS NOT NULL
	BEGIN
		DROP TABLE #TempDistDevicePro000
	END
######################################################################################
#END
