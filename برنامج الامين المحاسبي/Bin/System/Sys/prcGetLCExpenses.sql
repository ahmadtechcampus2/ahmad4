##############################################
CREATE FUNCTION fnGetLCExpenses (@LCGuid UNIQUEIDENTIFIER )
RETURNS @Result 
	TABLE 
	(
		RowNumber			INT,
		TypeGUID			UNIQUEIDENTIFIER,
		SourceType			INT, -- 1: BILL , 0:ENTRY
		TypeName			NVARCHAR(250),
		AccountGUID			UNIQUEIDENTIFIER,
		AccountName			NVARCHAR(250),
		Notes				NVARCHAR(1000),
		[Date]				DATETIME,
		NetValue			FLOAT,
		CurrencyGUID		UNIQUEIDENTIFIER,
		CurrencyVal			FLOAT,
		ExpenseName			NVARCHAR(250),
		ExpenseGUID			UNIQUEIDENTIFIER,
		ExpenseDistMethod	INT,
		ItemNumber			INT,
		ItemGUID			UNIQUEIDENTIFIER,
		LCGuid				UNIQUEIDENTIFIER,
		IsTransfared		BIT
	)
AS
BEGIN
	DECLARE @language [INT]		
	SET @language = [dbo].[fnConnections_getLanguage]() 

	DECLARE @tmp TABLE 
	(
		TypeGUID			UNIQUEIDENTIFIER,
		SourceType			INT, -- 1: BILL , 0:ENTRY
		TypeName			NVARCHAR(250),
		AccountGUID			UNIQUEIDENTIFIER,
		AccountName			NVARCHAR(250),
		Notes				NVARCHAR(1000),
		[Date]				DATETIME,
		NetValue			FLOAT,
		CurrencyGUID		UNIQUEIDENTIFIER,
		CurrencyVal			FLOAT,
		ExpenseName			NVARCHAR(250),
		ExpenseGUID			UNIQUEIDENTIFIER,
		ExpenseDistMethod	INT,
		ItemNumber			INT,
		ItemGUID			UNIQUEIDENTIFIER,
		LCGuid				UNIQUEIDENTIFIER,
		IsTransfared		BIT
	)

	INSERT INTO @tmp
		SELECT  
			py.[pyGUID] AS TypeGUID, 
			0 AS SourceType, 
			(CASE WHEN @language <> 0 AND et.etLatinName <> '' THEN et.etLatinName ELSE et.etName END) + ': ' + CAST(en.ceNumber AS NVARCHAR) AS TypeName, 
			en.acGUID AS AccountGUID,
			'' AS AccountName,
			en.[enNotes]	AS Notes,  
			en.[enDate]		AS Date, 
			((en.[enDebit] - en.[enCredit]) / en.[enCurrencyVal]) AS NetValue, 
			en.[enCurrencyPtr] AS CurrencyGUID, 
			en.[enCurrencyVal] AS CurrencyVal,
			(CASE WHEN @language <> 0 AND ex.[LatinName] <> '' THEN ex.[LatinName] ELSE ex.[Name] END) AS ExpenseName,
			ex.[GUID]		AS ExpenseGUID,
			ex.[DistMethod] AS ExpenseDistMethod,
			en.[enNumber]	AS ItemNumber, 
			en.[enGUID]		AS ItemGUID,
			en.enLCGUID		AS LCGuid,
			expense.IsTransfared
		FROM vwExtended_en en
			INNER JOIN vwEt et ON en.ceTypeGUID = et.etGUID
			INNER JOIN vwER er on en.ceGUID = er.erEntryGUID 
			INNER JOIN vwPy py on py.pyGUID = er.erParentGUID
			INNER JOIN LC000 lc ON lc.GUID = en.enLCGUID
			LEFT JOIN LCRelatedExpense000 expense ON expense.ItemGUID = en.enGUID
			LEFT JOIN LCExpenses000 ex on expense.ItemExpenseGUID = ex.GUID
				WHERE en.enLCGUID = @LCGuid OR ISNULL(@LCGuid, 0x0) = 0x0

	INSERT INTO @tmp
		SELECT 
			bi.[buGUID] AS TypeGUID, 
			1 AS SourceType, 
			(CASE WHEN @language <> 0 AND bi.btLatinName <> '' THEN bi.btLatinName ELSE bi.btName END) + ': ' + CAST(bi.buNumber AS NVARCHAR) AS TypeName,
			CASE WHEN bi.[buMatAcc] <> 0x00 THEN bi.[buMatAcc] WHEN ma.[MatAccGUID] <> 0x00 THEN ma.[MatAccGUID] ELSE bi.[btDefBillAcc] END AS  AccountGUID,
			'' AS AccountName, 
			bi.[biNotes] AS Notes, 
			bi.[buDate] AS Date, 
			((bi.btDirection * (bi.biPrice * bi.biBillQty - bi.biDiscount - bi.biTotalDiscountPercent + bi.biExtra + bi.biTotalExtraPercent)) / bi.biCurrencyVal) AS NetValue,
			bi.[biCurrencyPtr] AS CurrencyGUID, 
			bi.[biCurrencyVal] AS CurrencyVal, 
			(CASE WHEN @language <> 0 AND ex.[LatinName] <> '' THEN ex.[LatinName] ELSE ex.[Name] END) AS ExpenseName, 
			ex.[GUID]		AS ExpenseGUID,
			ex.[DistMethod] AS ExpenseDistMethod, 
			bi.[biNumber]	AS ItemNumber, 
			bi.[biGUID]		AS ItemGUID,
			bi.buLCGUID		AS LCGuid,
			expense.IsTransfared
		FROM vwExtended_bi bi
			INNER JOIN LC000 lc ON lc.GUID = bi.buLCGUID
			LEFT JOIN LCRelatedExpense000 expense ON expense.ItemGUID = bi.biGUID
			LEFT JOIN LCExpenses000 ex on expense.ItemExpenseGUID = ex.GUID
			LEFT JOIN ma000 ma ON ma.[ObjGUID] = bi.[biMatPtr] AND ma.[BillTypeGUID] = bi.[buType]
				WHERE (bi.buLCGUID = @LCGuid OR ISNULL(@LCGuid, 0x0) = 0x0) AND bi.buLCType = 2 AND bi.mtType = 1

	INSERT INTO @tmp
		SELECT
			ItemParentGUID,
			IsBillItem,
			LCName,
			AccountGUID,
			'',
			Note,
			Date,
			NetVal,
			CurGUID,
			CurVal,
			(CASE WHEN @language <> 0 AND ex.[LatinName] <> '' THEN ex.[LatinName] ELSE ex.[Name] END),
			ItemExpenseGUID,
			ex.DistMethod,
			ItemNumber,
			ItemGUID,
			LCGuid,
			IsTransfared
		FROM LCRelatedExpense000 expense
		LEFT JOIN LCExpenses000 ex on expense.ItemExpenseGUID = ex.GUID
			WHERE expense.LCGUID = @LCGuid AND expense.IsTransfared = 1
			

	UPDATE tmp
		SET AccountName = ac.[acCode] + ' - ' +  (CASE WHEN @language <> 0 AND ac.[acLatinName] <> '' THEN ac.[acLatinName] ELSE ac.[acName] END)
			FROM @tmp tmp 
				INNER JOIN vwAc ac ON ac.[acGUID] = tmp.AccountGUID

	INSERT INTO @Result
		SELECT
			ROW_NUMBER() OVER(ORDER BY [Date], [TypeName], [ItemNumber] ASC) AS RowNumber,
			TypeGUID,
			SourceType,
			TypeName,
			AccountGUID,
			AccountName,
			Notes,
			[Date],
			NetValue,
			CurrencyGUID,
			CurrencyVal,
			ExpenseName,
			ExpenseGUID,
			ExpenseDistMethod,
			ItemNumber,
			ItemGUID,
			LCGuid,
			IsTransfared
				FROM @tmp 
					ORDER BY IsTransfared DESC, [Date], [TypeName], [ItemNumber]
RETURN
END
#####################################################################################################################
CREATE PROC prcGetLCBills
	@LCGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	DECLARE @language [INT]		
	SET @language = [dbo].[fnConnections_getLanguage]() 

	CREATE TABLE #result
	(
		TypeName nvarchar(250),
		TypeLName nvarchar(250),
		BillGuid UNIQUEIDENTIFIER,
		BillNumber int,
		[Date] datetime,
		NetValue float,
		CurrencyGuid UNIQUEIDENTIFIER,
		CurrencyVal float,
		BillNote NVARCHAR(1000),
		OrderName NVARCHAR(250),
		OrderSerialNumberRelatedToBill INT
	)
	
	INSERT INTO #result
	SELECT 
		(CASE WHEN @language <> 0 AND bu.btLatinName <> '' 
			THEN bu.btLatinName 
			ELSE bu.btName END) + ': ' + CAST(bu.buNumber AS NVARCHAR),  
		bu.btLatinName, 
		bu.buGUID, 
		bu.buNumber, 
		bu.buDate, 
		CASE WHEN bu.buCurrencyVal = 0 THEN 0 ELSE (bu.buTotal + bu.buTotalExtra - bu.buTotalDisc) / bu.buCurrencyVal END,
		bu.buCurrencyPtr, bu.buCurrencyVal,
	    bu.buNotes AS billNote,
		(CASE WHEN (COUNT(orderPostedBillGuid) OVER(PARTITION BY buOr.orderPostedBillGuid) > 1 ) THEN '' ELSE 
				(CASE WHEN @language <> 0 AND buOr.orderLatinName <> '' THEN buOr.orderLatinName ELSE buOr.orderName END + ': ' 
			      + CAST(buOr.orderNumber AS NVARCHAR))END) AS orderName,
		ROW_NUMBER() OVER(PARTITION BY bu.buguid ORDER BY buOr.orderNumber ASC)
		
	FROM vwBu bu 
	LEFT JOIN vwOrderBuPosted buOr ON buOr.orderPostedBillGuid = bu.buguid
	WHERE bu.buLCGUID = @LCGuid AND bu.buLCType = 1

	DELETE FROM #result WHERE OrderSerialNumberRelatedToBill > 1 
	SELECT *
	FROM #result
	ORDER BY [Date],
			 TypeName,
			 BillNumber
			 
#####################################################################################################################
CREATE PROC prcAddBillItemLC
	@biGuid UNIQUEIDENTIFIER,
	@LCDisc FLOAT,
	@LCExtra FLOAT
AS
	SET NOCOUNT ON 

	EXEC prcDisableTriggers	'bi000' 

	UPDATE bi000 SET LCDisc = @LCDisc, LCExtra = @LCExtra  WHERE GUID = @biGuid

	UPDATE mt000 set AvgPrice = CASE WHEN (mt000.Qty - bi.biQty) = 0 THEN 0 ELSE ((AvgPrice * mt000.Qty) - (bi.biQty * (bi.biUnitPrice - biUnitDiscount + biUnitExtra))) / (mt000.Qty - bi.biQty) END
	FROM vwExtended_bi bi
	WHERE bi.biGUID = @biGuid AND mt000.GUID = bi.biMatPtr
	
	UPDATE mt000 SET AvgPrice = CASE mt000.Qty WHEN 0 THEN 0 ELSE ((AvgPrice *( mt000.Qty - bi.biQty)) + (bi.biQty * (bi.biUnitPrice - biUnitDiscount + biUnitExtra)) - bi.biLCDisc + bi.biLCExtra) / (mt000.Qty) END
	FROM vwExtended_bi bi
	WHERE bi.biGUID = @biGuid AND mt000.GUID = bi.biMatPtr

	EXEC prcEnableTriggers 'bi000' 
##################################################################
CREATE PROC prcRemoveBillItemLC
	@biGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 

	EXEC prcDisableTriggers	'bi000' 

	UPDATE bi000 SET LCDisc = 0, LCExtra = 0  WHERE GUID = @biGuid

	UPDATE mt000 SET AvgPrice = CASE WHEN (mt000.Qty - bi.biQty) = 0 THEN 0 ELSE ((AvgPrice * mt000.Qty) - (bi.biQty * (bi.biUnitPrice - biUnitDiscount)) - bi.biLCDisc + bi.biLCExtra) / (mt000.Qty - bi.biQty) END
	FROM vwExtended_bi bi
	WHERE bi.biGUID = @biGuid AND mt000.GUID = bi.biMatPtr
	
	UPDATE mt000 SET AvgPrice =  CASE mt000.Qty WHEN 0 THEN 0 ELSE ((AvgPrice *( mt000.Qty - bi.biQty)) + (bi.biQty * (bi.biUnitPrice - biUnitDiscount + biUnitExtra))) / (mt000.Qty) END
	FROM vwExtended_bi bi
	WHERE bi.biGUID = @biGuid AND mt000.GUID = bi.biMatPtr

	EXEC prcEnableTriggers 'bi000' 
#####################################################################################################################
CREATE PROCEDURE PrcUpdateMatAvgPrice 
	@MatGUID [UNIQUEIDENTIFIER]
AS  
	SET NOCOUNT ON

	DECLARE @t_Result TABLE( 
		[GUID] [UNIQUEIDENTIFIER], 
		[Qnt] [FLOAT], 
		[AvgPrice] [FLOAT]) 
	---------------------------------------------------------------------- 
	DECLARE
		-- mt table variables declarations:
		@mtGUID [UNIQUEIDENTIFIER],
		@CurGUID [UNIQUEIDENTIFIER],
		@mtQnt [FLOAT], 
		@mtAvgPrice [FLOAT], 
		@mtValue [FLOAT], 
		@bNeg [BIT],
		-- bi cursor input variables declarations: 
		@buGUID				[UNIQUEIDENTIFIER],
		@buDate 			[DATETIME], 
		@buDirection 		[INT], 
		@biNumber 			[INT], 
		@biMatPtr 			[UNIQUEIDENTIFIER],
		@biQnt 				[FLOAT], 
		@biBonusQnt 		[FLOAT], 
		@biUnitPrice 		[FLOAT], 
		@biUnitDiscount 	[FLOAT], 
		@biDiscExtra		[FLOAT], 
		@biUnitExtra 		[FLOAT], 
		@biAffectsCostPrice [BIT], 
		@biDiscountAffectsCostPrice [BIT], 
		@biExtraAffectsCostPrice 	[BIT], 
		@biBaseBillType				[INT],
		@biLCDisc 					[FLOAT], 
		@biLCExtra					[FLOAT]
			 
	---------------------------------------------------------------------- 
	CREATE TABLE [#Result](
			[buGUID]					[UNIQUEIDENTIFIER],
			[buNumber]					[INT],
			[buDate] 					[DATETIME],
			[buDirection] 				[INT],
			[biNumber] 					[INT],
			[biMatPtr]					[UNIQUEIDENTIFIER],
			[biQnt]						[FLOAT],
			[biBonusQnt] 				[FLOAT],
			[biUnitPrice] 				[FLOAT],
			[biUnitDiscount] 			[FLOAT],
			[biUnitExtra] 				[FLOAT],
			[biDiscExtra] 				[FLOAT],
			[biAffectsCostPrice] 		[BIT],
			[biDiscountAffectsCostPrice][BIT],
			[biExtraAffectsCostPrice] 	[BIT],
			[biBaseBillType]			[INT],
			[buSortFlag] 				[INT],
			[buSortFlag2]				[INT], --Used to reorder 'cost cards' first (cost card added in same bill date)
			[LCDisc]					[FLOAT],
			[LCExtra]					[FLOAT],
			[buLCGUID]					[UNIQUEIDENTIFIER],
			[biGUID]					[UNIQUEIDENTIFIER]
		)
	---------------------------------------------------------------------- 
	SELECT @CurGUID = GUID FROM my000 WHERE CurrencyVal = 1
	----------------------------------------------------------------------
	INSERT INTO [#Result]
		SELECT
			[buGUID],
			[buNumber],
			[buDate],
			[buDirection],
			[biNumber],
			[biMatPtr],
			[biQty],
			[biBonusQnt],
			[FixedbiUnitPrice],
			[FixedbiUnitDiscount],
			[FixedbiUnitExtra],
			([FixedBiExtra] * [btExtraAffectCost]) - ([btDiscAffectCost] * [FixedBiDiscount]),
			[btAffectCostPrice],
			[btDiscAffectCost],
			[btExtraAffectCost],
			[btBillType],
			[buSortFlag],
			CASE [btBillType] WHEN 5 THEN -1 WHEN 4 THEN -1 ELSE 1 END,
			[r].biLCDisc,
			[r].biLCExtra,
			[r].buLCGUID,
			[r].biGUID
		FROM
			[dbo].[fnExtended_Bi_Fixed](@CurGUID) AS [r]
		WHERE
			[r].[biMatPtr] = @MatGUID
			AND [buIsPosted] > 0
	
	---------------------------------------------------------------------- 
	-- declare cursors: 
	DECLARE @c_bi CURSOR 

	-- helpfull vars: 
	DECLARE @Tmp [FLOAT] 

	-- setup bi cursor: 
	SET @c_bi = CURSOR FAST_FORWARD FOR 
			SELECT  
				[buGUID],  
				[buDate],  
				[buDirection],
				[biNumber],  
				[biMatPtr],  
				[biQnt],  
				[biBonusQnt],  
				[biUnitPrice],  
				[biUnitDiscount],  
				[biUnitExtra], 
				[biDiscExtra],
				[biAffectsCostPrice], 
				[biDiscountAffectsCostPrice],  
				[biExtraAffectsCostPrice], 
				[biBaseBillType],
				[LCDisc],
				[LCExtra] 
			FROM 
				[#Result]
			ORDER BY 
				[biMatPtr],  
				[buDate],  
				[buSortFlag2],  
				[buSortFlag],  
				[buNumber],
				[biNumber]

	--------------------------------------------------------------------------------------- 
	OPEN @c_bi FETCH NEXT FROM @c_bi INTO
			@buGUID,
			@buDate,  
			@buDirection,
			@biNumber,  
			@biMatPtr,  
			@biQnt,  
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra,
			@biDiscExtra, 
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType,
			@biLCDisc,
			@biLCExtra 

	-- get the first material 
	SET @mtGUID = @biMatPtr 
	-- reset variables: 
	SET @mtQnt = 0 
		
	SET @mtAvgPrice = 0 
	-- start @c_bi loop 
		
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- is this a new material ? 
		IF @mtGUID <> @biMatPtr
		BEGIN 
			-- insert the material record: 
			INSERT INTO @t_Result VALUES( 
				@mtGUID, 
				@mtQnt,   
				@mtAvgPrice) 
			-- reset mt variables: 
			SET @mtGUID = @biMatPtr 
			SET @mtQnt = 0 
			SET @bNeg = 0
			
			SET @mtAvgPrice = 0 
		END 
		-------------------------- 
		IF @biAffectsCostPrice = 0 
		BEGIN 
			SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)  
		END
		ELSE 
		BEGIN
			IF @mtQnt >= 0
			BEGIN
				IF @biQnt > 0
					SET @mtValue = (@mtAvgPrice * @mtQnt) + (@buDirection * @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice))
				ELSE IF @biQnt = 0
					SET @mtValue = (@mtAvgPrice * @mtQnt) + (@buDirection * @biDiscExtra)
			END
			ELSE
				IF @buDirection = 1 
				BEGIN
					IF @biQnt > 0	
						SET @mtValue = @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)
					ELSE IF @biQnt = 0
						SET @mtValue =  (@buDirection * @biDiscExtra)	
				END
			IF @mtQnt < 0
					set @bNeg = 1
			ELSE
				set @bNeg = 0
			SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)
			SET @mtValue = @mtValue - @biLCDisc + @biLCExtra
			IF @mtValue > 0 
			BEGIN
				IF ( @mtQnt > 0) AND @bNeg = 0
					SET @mtAvgPrice = @mtValue / @mtQnt
				ELSE IF (@biQnt > 0) AND (@buDirection = 1) 
				BEGIN
				IF (@biQnt + @biBonusQnt) > 0
					SET @mtAvgPrice = @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)/(@biQnt + @biBonusQnt)
				END
			END
			ELSE
			BEGIN
				IF (@biQnt + @biBonusQnt) > 0
					SET @mtAvgPrice = @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)/(@biQnt + @biBonusQnt)
				
			END
			SET @mtValue = 0
		END 
		----------------------------------- 

		FETCH FROM @c_bi INTO 
			@buGUID,
			@buDate,  
			@buDirection, 
			@biNumber,  
			@biMatPtr,  
			@biQnt,  
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra,
			@biDiscExtra, 
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType,
			@biLCDisc,
			@biLCExtra 
		 
	END -- @c_bi loop 		-- insert the last mt statistics:
	INSERT INTO @t_Result SELECT @mtGUID, @mtQnt, @mtAvgPrice

	CLOSE @c_bi DEALLOCATE @c_bi
	--return result Set
	UPDATE m
		SET AvgPrice = ISNULL( [r].[AvgPrice], 0)
	FROM mt000 AS m
	INNER JOIN @t_Result AS [r]ON [m].[GUID] = [r].[GUID]

#####################################################################################################################
CREATE PROC prcUpdateBillItemLC
	@biGuid UNIQUEIDENTIFIER,
	@LCDisc FLOAT = 0,
	@LCExtra FLOAT = 0
AS
	SET NOCOUNT ON 

	EXEC prcDisableTriggers	'bi000' 
	
	UPDATE bi000 SET LCDisc = @LCDisc, LCExtra = @LCExtra  WHERE GUID = @biGuid

	UPDATE ad000
		Set InVal = [bi].[biUnitPrice] + [bi].[biUnitExtra] - [bi].[biUnitDiscount] +
					CASE bi.biQty WHEN 0 THEN 0 ELSE (bi.biLCExtra - bi.biLCDisc) / bi.biQty END
		FROM  [vwExtended_sn] AS [bi] INNER JOIN [ad000] AS [ad] ON [ad].[SnGUID] = [bi].[snGUID]   
		INNER JOIN As000 As ASS ON [ASS].ParentGuid = [bi].biMatPtr   
		WHERE [bi].biGUID = @biGuid
	
	DECLARE @MatGuid UNIQUEIDENTIFIER = (SELECT biMatPtr FROM vwExtended_bi WHERE biGUID = @biGuid )
	EXEC PrcUpdateMatAvgPrice @MatGuid

	EXEC prcEnableTriggers 'bi000' 

#####################################################################################################################
CREATE PROC prcCloseLC
	@LCGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 

	UPDATE lc000 
		SET [state] = 0,
			[CloseDate] = GetDate() 
	WHERE [GUID] = @LCGuid
#####################################################################################################################
CREATE PROC prcUncloseLC
	@LCGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 
	UPDATE ce000 SET IsPosted = 0 WHERE GUID IN (SELECT EntryGUID FROM er000 WHERE ParentGUID IN (SELECT EntryGUID FROM LCEntries000 WHERE LCGUID = @LCGuid))
	DELETE ce000 WHERE GUID IN (SELECT EntryGUID FROM er000 WHERE ParentGUID IN (SELECT EntryGUID FROM LCEntries000 WHERE LCGUID = @LCGuid))
	DELETE py000 WHERE GUID IN (SELECT EntryGUID FROM LCEntries000 WHERE LCGUID = @LCGuid)
	UPDATE lc000 SET [state] = 1 WHERE [GUID] = @LCGuid
#####################################################################################################################
CREATE PROCEDURE prcGenerateCloseLCEntry
	@LCGuid UNIQUEIDENTIFIER,
	@Notes	NVARCHAR(500),
	@BillNotes	[NVARCHAR](256),
	@MatNotes	[NVARCHAR](256),
	@CostCenterGuid UNIQUEIDENTIFIER,
	@BranchGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	DECLARE 
		@CloseEntryType				UNIQUEIDENTIFIER,
		@LCAccount					UNIQUEIDENTIFIER,
		@CEGuid						UNIQUEIDENTIFIER,
		@DefCurrency				UNIQUEIDENTIFIER,
		@PYGuid						UNIQUEIDENTIFIER,
		@CurrentBuGuid				UNIQUEIDENTIFIER,
		@IsDetailed					BIT,
		@AutoPost					BIT,
		@MaxCENumber				INT,
		@MaxPYNumber				INT,
		@Count						INT,
		@CurrentBuDate				DATE,
		@CurrentBuFormatedName		NVARCHAR(256),
		@CurrentCeNotes				NVARCHAR(256)

	SELECT @CloseEntryType = EnTypeGUID, @LCAccount = AccountGUID FROM LC000 WHERE GUID = @LCGuid
	SELECT @IsDetailed = bDetailed, @AutoPost = bAutoPost FROM et000 WHERE GUID = @CloseEntryType
	
	SET @DefCurrency = ISNULL((SELECT TOP 1 GUID FROM my000 WHERE currencyVal = 1 ORDER BY Number), 0x0)
	
	IF @DefCurrency = 0x0 
		RETURN 

     DECLARE @Expenses TABLE( 
	   [Number]				[INT] IDENTITY(1, 1), 
	   [Debit]				[FLOAT], 
	   [Credit]				[FLOAT], 
	   [date]				[DATETIME], 
	   [notes]				[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
	   [currencyVal]		[FLOAT], 
	   [class]				[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
	   [vendor]				[INT], 
	   [salesMan]			[INT], 
	   [parentGUID]			[UNIQUEIDENTIFIER], 
	   [accountGUID]		[UNIQUEIDENTIFIER], 
	   [currencyGUID]		[UNIQUEIDENTIFIER], 
	   [costGUID]			[UNIQUEIDENTIFIER], 
	   [contraAccGUID]		[UNIQUEIDENTIFIER],
	   [MatGuid]			[UNIQUEIDENTIFIER],
	   [BuGuid]				[UNIQUEIDENTIFIER],
	   [BuDate]				[DATE],
	   [BuFormatedName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
	   [BiGuid]				[UNIQUEIDENTIFIER])
	    
	  DECLARE @BuGUIDS TABLE(
	  [Number]				[INT] IDENTITY(1, 1), 
	  [BuGuid]				[UNIQUEIDENTIFIER])
	  
	  INSERT INTO @Expenses (Debit, Credit, AccountGUID, currencyVal, currencyGUID, notes, BuGuid, BuDate, BuFormatedName, BiGuid)
	  SELECT 
			0, 
			(bi.biLCExtra),
			CASE ISNULL([ma_user].[maMatAccGUID], 0x0) WHEN 0x0 
				THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0) WHEN 0x0 
					THEN CASE ISNULL([ga_mat].maMatAccGUID, 0X0) WHEN 0x0 
						THEN bi.btDefBillAcc			
					ELSE [ga_mat].maMatAccGUID END 
				ELSE [ma_mat].[maMatAccGUID] END 
			ELSE [ma_user].[maMatAccGUID] END,
			1, 
			@DefCurrency, 
			@BillNotes + ' - ' + BI.btName + ' ' + CAST(BI.buNumber AS nvarchar(50)) + ' - ' +  @MatNotes + BI.mtCode + '-'  + bi.mtName,
			BuGuid,
			BuDate,
			' ' +  BI.btName + ' ' + CAST(BI.buNumber AS nvarchar(50)),
			Bi.biGUID
		FROM 
			vwExtended_bi bi
			LEFT JOIN [vwMa] AS [ma_mat] ON [bi].[biMatPtr] = [ma_mat].[maObjGUID] AND [bi].[buType] = [ma_mat].[maBillTypeGUID] 
			LEFT JOIN [vwMa] AS [ga_mat] ON [bi].[mtGroup]  = [ga_mat].[maObjGUID] AND [bi].[buType] = [ga_mat].[maBillTypeGUID] 
			LEFT JOIN [vwMa] AS [ma_user] ON ([ma_user].[maBillTypeGUID] = [bi].[buType]) AND ([ma_user].[maObjGUID] = [bi].[buUserGUID]) AND ([ma_user].[maType] = 3)
			LEFT JOIN [as000] AS [Asset] ON [Asset].[ParentGUID] = [bi].[biMatPtr]
		WHERE bi.buLCType = 1 AND bi.buLCGUID = @LCGuid

	INSERT INTO @BuGUIDS (BuGUID) SELECT DISTINCT BuGUID FROM @Expenses

	Set @Count = (SELECT ISNULL (COUNT (buGUID), 0) FROM @BuGUIDS)

	WHILE (@Count > 0)
	BEGIN
		DECLARE @EntryTypeDefAcc UNIQUEIDENTIFIER = (SELECT DefAccGUID FROM et000 WHERE Guid = @CloseEntryType)
		DECLARE @pyAccGuid UNIQUEIDENTIFIER = CASE WHEN @entryTypeDefAcc <> 0x0 THEN @LCAccount ELSE @entryTypeDefAcc END
		
		SET @CEGuid = newid()
		SET @PYGuid = newid()
		SET @CurrentBuGuid = (SELECT BuGUID FROM @BuGUIDS WHERE Number = @Count)
		SET @CurrentBuDate = (SELECT TOP 1 BuDate FROM @Expenses WHERE BuGUID = @CurrentBuGuid)
		SET @CurrentBuFormatedName = (SELECT TOP 1 BuFormatedName FROM @Expenses WHERE BuGUID = @CurrentBuGuid)
		SET @MaxCENumber = ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1
		SET @CurrentCeNotes = @Notes + @CurrentBuFormatedName
		
		INSERT INTO ce000 (GUID, Type, Number, Security, Date, Debit, Credit, TypeGUID, PostDate, CurrencyGUID, CurrencyVal, Notes, Branch) 
		values (@CEGuid, 1, @MaxCENumber, 1, @CurrentBuDate, 0, 0, @CloseEntryType, @CurrentBuDate, @DefCurrency, 1, @Notes, @BranchGuid)
	
		SET @MaxPYNumber = ISNULL((SELECT MAX(Number) FROM py000), 0) + 1
	
		INSERT INTO py000 (GUID, Number, Security, Date, AccountGUID, TypeGUID, CurrencyGUID, CurrencyVal, Notes, BranchGUID)
		SELECT @PYGuid, @MaxPYNumber, 1, @CurrentBuDate, @pyAccGuid, @CloseEntryType, @DefCurrency, 1, @CurrentCeNotes, @BranchGuid
		
		INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)
		SELECT @CEGuid, @PYGuid, 4, @MaxPYNumber
		
		INSERT INTO LCEntries000 VALUES (NEWID(), @LCGuid, @PYGuid)
		
		IF(@IsDetailed = 1)
		BEGIN
			INSERT INTO [en000] (
						[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
						[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
					SELECT 
						(Number * 2), @CurrentBuDate, 
						CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
						CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END, 
						@Notes + ' ' + notes, currencyVal, '', 0, 0, @CEGuid, accountGUID, currencyGUID, 0x0, @LCAccount, BiGuid
					FROM @Expenses WHERE BuGuid = @CurrentBuGuid
			INSERT INTO [en000] (
						[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
						[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
					SELECT 
						(Number * 2) + 1, @CurrentBuDate, 
						CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END, 
						CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
						@Notes, currencyVal, '', 0, 0, @CEGuid, @LCAccount, currencyGUID, 0x0, accountGUID, 0x0
					FROM @Expenses WHERE BuGuid = @CurrentBuGuid
		END

		ELSE
		BEGIN
			INSERT INTO [en000] (
						[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
						[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
					SELECT 
						Number, @CurrentBuDate, 
						CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
						CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END,
						@CurrentCeNotes + notes, currencyVal, '', 0, 0, @CEGuid, accountGUID, currencyGUID, 0x0, 0x0, BiGuid
					FROM @Expenses WHERE BuGuid = @CurrentBuGuid
			DECLARE @MaxENNumber INT SET @MaxENNumber = (SELECT COUNT(*) FROM @Expenses)
			INSERT INTO [en000] (
						[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
						[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
					SELECT 
						@MaxENNumber, @CurrentBuDate, 
						CASE WHEN SUM(Debit - Credit) > 0 THEN SUM(Debit - Credit) ELSE 0 END, 
						CASE WHEN SUM(Debit - Credit) < 0 THEN SUM(-(Debit - Credit)) ELSE 0 END,  
						@CurrentCeNotes, currencyVal, '', 0, 0, @CEGuid, @LCAccount, currencyGUID, @CostCenterGuid, 0x0, 0x0
					FROM @Expenses WHERE BuGuid = @CurrentBuGuid
					GROUP BY currencyVal, currencyGUID
		END

		UPDATE ce000 SET Debit = SEN.DEBIT, Credit = SEN.CREDIT, IsPosted = @AutoPost
		FROM 
			(SELECT ParentGUID, SUM(Debit) DEBIT, SUM(Credit) CREDIT
			FROM en000 EN WHERE EN.ParentGUID = @CEGuid
			GROUP BY EN.ParentGUID) SEN
			WHERE GUID = SEN.ParentGUID
		Set @Count = @Count-1
	END
#####################################################################################################################
CREATE FUNCTION fnLCGetDistValue
(
	@biGUID	[UNIQUEIDENTIFIER],
	@DistMethod		[INT]
)
RETURNS [FLOAT]
AS  
BEGIN 
	DECLARE @DistValue [FLOAT]
	SET @DistValue = -1 
	SET @DistValue = 
	(
		SELECT 
		(CASE @DistMethod
		WHEN 1 THEN CAST(mtDim AS float) 
		WHEN 2 THEN CAST(mtOrigin AS float)
		WHEN 3 THEN CAST(mtPos AS float)
		WHEN 4 THEN CAST(mtCompany AS float)
		WHEN 5 THEN CAST(mtColor AS float)
		WHEN 6 THEN CAST(mtProvenance AS float)
		WHEN 7 THEN CAST(mtQuality AS float)
		WHEN 8 THEN CAST(mtModel AS float)
		WHEN 9 THEN 1
		WHEN 10 THEN biUnitPrice
		WHEN 11 THEN biLength
		WHEN 12 THEN biWidth
		WHEN 13 THEN biHeight
		WHEN 14 THEN biCount
		WHEN 15 THEN (biLength * biWidth)
		WHEN 16 THEN (biLength * biWidth * biHeight)
		ELSE biUnitPrice
		END ) * biQty
		FROM vwExtended_bi bi
		WHERE biGUID = @biGUID
	)

	RETURN ISNULL(@DistValue, 0)  
END
#####################################################################################################################
CREATE FUNCTION fnLC_CalcBillItemsDiscExtra (@LCGuid UNIQUEIDENTIFIER = 0x0)
RETURNS @Result TABLE(
		buGuid				UNIQUEIDENTIFIER,
		biGUID				UNIQUEIDENTIFIER,
		matGUID				UNIQUEIDENTIFIER,
		expenseDistMethod	UNIQUEIDENTIFIER,
		LCExtra				FLOAT,
		LCDisc				FLOAT,
		LCGuid				UNIQUEIDENTIFIER)
AS
BEGIN
	DECLARE @BillItems AS TABLE
	(
		buGuid				UNIQUEIDENTIFIER,
		biGUID				UNIQUEIDENTIFIER,
		matGUID				UNIQUEIDENTIFIER,
		expenseDistMethod	UNIQUEIDENTIFIER,
		LCExtra				FLOAT,
		LCDisc				FLOAT,
		LCGuid				UNIQUEIDENTIFIER
	)

	DECLARE @Expenses AS TABLE
	(
		expenseNumber		INT,
		expenseGUID			UNIQUEIDENTIFIER,
		DistMethod			INT		
	)

	INSERT INTO @Expenses
	SELECT	Number,
			GUID, 
			DistMethod 
	FROM LCExpenses000
	ORDER BY Number

	INSERT INTO @BillItems
		SELECT 
			bi.[buGUID],
			bi.biGUID,
			bi.[biMatPtr] AS MatGUID,
			0x00			AS ExpenseGUID, 
			0				AS LCExtra,
			0				AS LCDisc,
			bi.buLCGUID
		FROM vwExtended_bi bi
		WHERE (bi.buLCGUID = @LCGuid OR ISNULL(@LCGuid, 0x0) = 0x0) AND bi.buLCType = 1

	-- Calc expenses dist
	DECLARE @ExpensesList AS TABLE
	(
		RowNumber			INT,
		TypeGUID			UNIQUEIDENTIFIER,
		SourceType			INT, -- 1: BILL , 0:ENTRY
		TypeName			nvarchar(250),
		AccountName			nvarchar(250),
		Notes				nvarchar(1000),
		[Date]				datetime,
		NetValue			float,
		CurrencyGUID		UNIQUEIDENTIFIER,
		CurrencyVal			float,
		ExpenseName			nvarchar(250),
		ExpenseGUID			UNIQUEIDENTIFIER,
		ExpenseDistMethod	INT,
		ItemNumber			int,
		ItemGUID			UNIQUEIDENTIFIER,
		LCGuid				UNIQUEIDENTIFIER
	)

	-- Get Expenses
	INSERT INTO @ExpensesList
		SELECT 
			RowNumber,		
			TypeGUID,			
			SourceType,		
			TypeName,		
			AccountName,
			Notes,		
			[Date],
			NetValue,
			CurrencyGUID,
			CurrencyVal,
			ExpenseName,
			ExpenseGUID,
			ExpenseDistMethod,
			ItemNumber,
			ItemGUID,
			LCGuid
		 FROM dbo.fnGetLCExpenses(@LCGuid)

	DECLARE @TotalDistValue AS TABLE
	(
		ExpenseGUID		UNIQUEIDENTIFIER,
		TotalDistValue	FLOAT
	)

	INSERT INTO @TotalDistValue
		SELECT ex.[expenseGUID] , SUM(dbo.fnLCGetDistValue(bi.[biGUID], ex.[DistMethod]))
		FROM @BillItems bi
		CROSS JOIN @Expenses ex
		GROUP BY ex.[expenseGUID]

	INSERT INTO @Result
		SELECT buGuid, mat.biGUID ,matGUID,  ex.expenseGUID, 0, 0, LCGuid
		FROM @BillItems mat
		CROSS JOIN @Expenses ex
		ORDER BY buGuid, expenseNumber

	DECLARE @MAXCNT INT, 
			@CNT INT, 
			@DistMethod INT, 
			@ExpenseGUID UNIQUEIDENTIFIER,
			@NetValue	FLOAT,
			@CurrencyVal	FLOAT

	SELECT @MAXCNT = MAX(RowNumber) FROM @ExpensesList WHERE ISNULL(ExpenseGUID, 0x0) <> 0x0
	SET @CNT = 1 
	SET @DistMethod = 1
	SET @ExpenseGUID = 0x00

	WHILE @CNT <= @MAXCNT
	BEGIN
		
		SELECT TOP 1  @DistMethod = DistMethod, 
					  @ExpenseGUID = exList.ExpenseGUID, 
					  @CNT = [RowNumber],
					  @NetValue = exList.[NetValue],
					  @CurrencyVal = exList.[CurrencyVal] 
		FROM 
			@ExpensesList exList
			INNER JOIN @Expenses ex ON ex.expenseGUID = exList.ExpenseGUID
		WHERE RowNumber >=  @CNT
		ORDER BY RowNumber
		
		IF @@ROWCOUNT > 0
		BEGIN 
			UPDATE R
			SET R.LCExtra += CASE 
								WHEN (@NetValue >= 0 AND (total.[TotalDistValue]) > 0) THEN 
									(dbo.fnLCGetDistValue(R.[biGUID], @DistMethod) / (total.[TotalDistValue]))
									* (@NetValue * @CurrencyVal)
								ELSE 0 END,
				R.LCDisc += CASE 
								WHEN ( @NetValue < 0 AND (total.[TotalDistValue]) > 0)THEN 
									ABS((dbo.fnLCGetDistValue(R.[biGUID], @DistMethod) / (total.[TotalDistValue]))
									* (@NetValue * @CurrencyVal))
								ELSE 0 END
			FROM 
				@Result R
				INNER JOIN @TotalDistValue total ON total.ExpenseGUID = R.expenseDistMethod
			WHERE 
				R.expenseDistMethod = @ExpenseGUID
		END
		SET @CNT = @CNT + 1
	END
	------------------------------

	RETURN
END
###########################################################################
CREATE FUNCTION fnLCGetBillItemsDiscExtra
(
	@LCGuid UNIQUEIDENTIFIER = 0x0
)
RETURNS TABLE AS
RETURN(
	SELECT fn.buGUID, fn.biGUID, fn.matGUID, SUM(fn.LCExtra) LCExtra, SUM(fn.LCDisc) LCDisc 
		FROM 
			dbo.fnLC_CalcBillItemsDiscExtra (@LCGuid) fn
			INNER JOIN LCExpenses000 [ex] ON [ex].[Guid] = [fn].[expenseDistMethod]
		GROUP BY fn.buGUID, fn.biGUID, fn.matGUID
)
#####################################################################################################################
CREATE PROC prcLCGetBillItemsDiscExtra
(@LCGuid UNIQUEIDENTIFIER = 0x0)
AS
BEGIN

	SELECT fn.buGUID, fn.biGUID, fn.matGUID, SUM(fn.LCExtra) LCExtra, SUM(fn.LCDisc) LCDisc 
	FROM 
		dbo.fnLC_CalcBillItemsDiscExtra (@LCGuid) fn 
		INNER JOIN LCExpenses000 [ex] ON [ex].[Guid] = [fn].[expenseDistMethod]
	GROUP BY fn.buGUID, fn.biGUID, fn.matGUID

END
#####################################################################################################################
CREATE PROC prcLCExpensesReport
	@LCGuid UNIQUEIDENTIFIER = 0x0,
	@GroupBy INT = 0 -- 0:None, 1:Material, 2:Bill, 3:Supplier
AS
	SET NOCOUNT ON

	DECLARE @language [INT]		
	SET @language = [dbo].[fnConnections_getLanguage]() 
	

	DECLARE @BillItemsDist AS TABLE
	(
		buGuid				UNIQUEIDENTIFIER,
		biGUID				UNIQUEIDENTIFIER,
		matGUID				UNIQUEIDENTIFIER,
		expenseDistMethod	UNIQUEIDENTIFIER,
		LCExtra				FLOAT,
		LCDisc				FLOAT,
		LCGuid				UNIQUEIDENTIFIER
	)

	INSERT INTO @BillItemsDist
		SELECT * FROM fnLC_CalcBillItemsDiscExtra(@LCGuid)

	DECLARE @Result AS TABLE
	(
		buNumber			INT,
		buGuid				UNIQUEIDENTIFIER,
		buName				NVARCHAR(250),
		matGUID				UNIQUEIDENTIFIER,
		matName				NVARCHAR(250),
		matQty				FLOAT,
		matQty2				FLOAT,
		matQty3				FLOAT,
		biPrice				FLOAT,
		biValue				FLOAT,
		biDisc				FLOAT,
		biExtra				FLOAT,
		biNetValue			FLOAT,
		expenseDistMethod	UNIQUEIDENTIFIER,
		expenseDistValue	FLOAT,
		expenseDistExtra	FLOAT,
		expenseDistDisc		FLOAT,
		TotalExpenseValue	FLOAT,
		CalcMatCost			FLOAT,
		expenseNumber		INT,
		biGUID				UNIQUEIDENTIFIER,
		biNumber			INT,
		CustGUID			UNIQUEIDENTIFIER,
		CustName			NVARCHAR(250),
		buNotes				NVARCHAR(1000),
		orderName			NVARCHAR(250)
	)

	INSERT INTO @Result
		SELECT 	bi.[buNumber] AS buNumber,
				Dist.[buGuid] AS buGuid,
				(CASE WHEN @language <> 0 AND bi.btLatinName <> '' THEN bi.btLatinName ELSE bi.btName END) + ': ' 
				+ CAST(bi.buNumber AS NVARCHAR) AS buName,
				Dist.[matGUID]		AS matGUID,
				bi.[mtCode] + ' - ' + (CASE WHEN @language <> 0 AND bi.[mtLatinName] <> '' THEN bi.[mtLatinName] ELSE bi.[mtName] END) 	AS MatName,
			bi.[biQty]			AS matQty,
			bi.[biCalculatedQty2]	AS matQty2,
			bi.[biCalculatedQty3]	AS matQty3,
			bi.[biPrice]			AS biPrice,
			bi.[biPrice] * bi.[biBillQty] AS biValue,
			bi.[biUnitDiscount] * bi.[biBillQty]	AS biDisc,
			bi.[biUnitExtra] *    bi.[biBillQty]	AS biExtra,
			0 AS biNetValue, 
			Dist.[expenseDistMethod] AS expenseDistMethod,
			(Dist.[LCExtra] - Dist.[LCDisc]) AS  expenseDistValue,
			Dist.[LCExtra],
			Dist.[LCDisc],
			0				AS TotalExpenseValue,
			0				AS CalcMatCost,
			ex.[Number]		AS expenseNumber,
			Dist.[biGUID]	AS biGUID,
			bi.biNumber		AS biNumber,
			bi.[buCustPtr]	AS CustGUID,
			(CASE WHEN @language <> 0 AND cu.cuLatinName <> '' THEN cu.cuLatinName ELSE cu.cuCustomerName END) AS custName,
			bi.buNotes AS buNotes,
			(CASE WHEN @language <> 0 AND BuBiOr.orderLatinName <> '' THEN BuBiOr.orderLatinName ELSE BuBiOr.orderName END) + ': ' 
				+ CAST(BuBiOr.orderNumber AS NVARCHAR) AS orderName
		FROM @BillItemsDist Dist
		INNER JOIN vwExtended_bi bi ON bi.biGUID = Dist.biGUID
		INNER JOIN LCExpenses000 ex ON ex.GUID = Dist.expenseDistMethod
		LEFT JOIN vwCu cu ON cu.cuGUID = bi.[buCustPtr]
		LEFT JOIN [vwOrderBuBiPosted] BuBiOr ON 
				( bi.biGUID  = (CASE WHEN @GroupBy = 0 THEN BuBiOr.orderPostedBiGuid ELSE 0x0 END))
	
	---- Update NetValue -------------------------------
	UPDATE R
	SET R.biNetValue = ((bi.btDirection * 
							(bi.biPrice - bi.[biUnitDiscount] + bi.[biUnitExtra]) * bi.biBillQty))
	FROM @Result R
	INNER JOIN vwExtended_bi bi ON bi.biGUID = R.biGUID
	----------------------------------------------------
	
	----------- TotalExpenseValue for BillItem ---------
	UPDATE R
		SET R.TotalExpenseValue = 
		(
			SELECT SUM(expenseDistValue)
			FROM @Result r1
			WHERE r1.biGUID = R.biGUID
			GROUP BY buGuid, biGUID, matGUID		
		)
	FROM @Result R
	----------------------------------------------------

	-- TO DO: Calculate mat cost --
	UPDATE R
		SET R.CalcMatCost = R.TotalExpenseValue + R.biNetValue
	FROM @Result R
	-------------------------------

	DECLARE @EmptyGUID UNIQUEIDENTIFIER = 0x00

	IF(@GroupBy = 1) -- Material
	BEGIN
		SELECT
				0 AS buNumber,			
				@EmptyGUID AS buGuid,				
				''	AS buName,				
				matGUID,				
				matName,				
				SUM(matQty) AS matQty,				
				SUM(matQty2)	AS matQty2,				
				SUM(matQty3)	AS matQty3,				
				SUM(biPrice)	AS biPrice,
				SUM(biValue)	AS biValue, 				
				SUM(biDisc)		AS biDisc,				
				SUM(biExtra)	AS biExtra,				
				SUM(biNetValue)	AS biNetValue,		
				expenseDistMethod,	
				SUM(expenseDistValue) AS expenseDistValue,	
				SUM(expenseDistExtra)	AS expenseDistExtra,	
				SUM(expenseDistDisc)	AS expenseDistDisc,		
				SUM(TotalExpenseValue)	AS TotalExpenseValue,	
				SUM(CalcMatCost) AS CalcMatCost,			
				expenseNumber,		
				@EmptyGUID AS biGUID,				
				0 AS biNumber,			
				@EmptyGUID AS CustGUID,			
				'' AS CustName,
				'' AS buNotes,
				'' AS orderName			 
		FROM @Result
		GROUP BY matGUID, matName, expenseDistMethod, expenseNumber
		ORDER BY matName, expenseNumber							   
	END
	ELSE IF(@GroupBy = 2) -- Bill
	BEGIN
		SELECT 
			DISTINCT orderPostedBillGuid,
			(CASE WHEN (COUNT(orderPostedBillGuid) OVER(PARTITION BY buOr.orderPostedBillGuid) > 1 ) THEN '' 
					ELSE
						(CASE WHEN 0 <> 0 AND BuOr.orderLatinName <> '' THEN BuOr.orderLatinName
								ELSE  (BuOr.orderName) 
						END) 
							+ ': ' + CAST(BuOr.orderNumber AS NVARCHAR) 
				END) AS orderName		
		INTO #Orders		 
		FROM [vwOrderBuPosted] BuOr
		
		SELECT
				buNumber,			
				buGuid,				
				buName,				
				@EmptyGUID AS matGUID,				
				'' AS matName,				
				SUM(matQty) AS matQty,				
				SUM(matQty2)	AS matQty2,				
				SUM(matQty3)	AS matQty3,				
				SUM(biPrice)	AS biPrice, 
				SUM(biValue)	AS biValue,				
				SUM(biDisc)		AS biDisc,				
				SUM(biExtra)	AS biExtra,				
				SUM(biNetValue)	AS biNetValue,		
				expenseDistMethod,	
				SUM(expenseDistValue) AS expenseDistValue,	
				SUM(expenseDistExtra)	AS expenseDistExtra,	
				SUM(expenseDistDisc)	AS expenseDistDisc,		
				SUM(TotalExpenseValue)	AS TotalExpenseValue,	
				SUM(CalcMatCost) AS CalcMatCost,			
				expenseNumber,		
				@EmptyGUID AS biGUID,				
				0 AS biNumber,			
				@EmptyGUID AS CustGUID,			
				'' AS CustName,
				buNotes,
				[or].orderName
		FROM @Result r
		LEFT JOIN #Orders [or] ON [or].orderPostedBillGuid = r.buGuid
		GROUP BY buNumber, buGuid , buName, expenseDistMethod, expenseNumber ,buNotes,[or].orderName
		ORDER BY buNumber, biNumber, expenseNumber
	END
	ELSE IF(@GroupBy = 3) -- Supplier
	BEGIN
		SELECT
				0 AS buNumber,			
				@EmptyGUID AS buGuid,				
				'' AS buName,				
				@EmptyGUID AS matGUID,				
				'' AS matName,				
				SUM(matQty) AS matQty,				
				SUM(matQty2)	AS matQty2,				
				SUM(matQty3)	AS matQty3,				
				SUM(biPrice)	AS biPrice,
				SUM(biValue)	AS biValue, 				
				SUM(biDisc)		AS biDisc,				
				SUM(biExtra)	AS biExtra,				
				SUM(biNetValue)	AS biNetValue,		
				expenseDistMethod,	
				SUM(expenseDistValue) AS expenseDistValue,	
				SUM(expenseDistExtra)	AS expenseDistExtra,	
				SUM(expenseDistDisc)	AS expenseDistDisc,		
				SUM(TotalExpenseValue)	AS TotalExpenseValue,	
				SUM(CalcMatCost) AS CalcMatCost,			
				expenseNumber,		
				@EmptyGUID AS biGUID,				
				0 AS biNumber,			
				CustGUID,			
				CustName,
				'' AS buNotes,
				'' AS orderName			 
		FROM @Result
		GROUP BY CustGUID, CustName, expenseDistMethod, expenseNumber
		ORDER BY CustName, expenseNumber

	END
	ELSE
	BEGIN
		SELECT * 
		FROM @Result 
		ORDER BY buNumber, biNumber, expenseNumber
	END
#####################################################################################################################
#END