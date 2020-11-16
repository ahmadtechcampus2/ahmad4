#################################################################
CREATE PROCEDURE prcGetCloseDaysList
AS   
	SET NOCOUNT ON

	SELECT 
		DISTINCT CAST (CAST ([CE].[DATE] AS DATE) AS DATETIME) AS [DATE], 
		CASE ISNULL([PFCDays].[DATE], 0) WHEN 0 THEN 0 ELSE 1 END AS [IsClosed], 
		ISNULL([PFCDays].[IsPosted],0) AS [IsPosted],
		[PFCDays].EntryGUID,
		[PFCDays].DecreaseBillGUID,
		[PFCDays].IncreaseBillGUID
	FROM [CE000] [CE] LEFT JOIN et000 ET ON CE.TypeGUID = ET.[GUID] 
		LEFT JOIN [PFCClosedDays000] [PFCDays] ON [PFCDays].[DATE] = CAST ([CE].[DATE] AS DATE)
	WHERE et.SortNum IS NULL OR ET.SortNum <> 1
	ORDER BY [DATE]
#################################################################
CREATE FUNCTION FnCloseDayBillsUsed()
	RETURNS TABLE
AS
Return (
	SELECT BU.TypeGUID FROM bu000 BU
)
#################################################################
CREATE PROCEDURE prcGenerateCloseExpensesEntry
	@PYGuid		UNIQUEIDENTIFIER,
	@CEGuid		UNIQUEIDENTIFIER,
	@DayDate	DATE,
	@Notes		[NVARCHAR](256),
	@CloseStr   [NVARCHAR](256),
	@ForDayStr  [NVARCHAR](256) 
AS
	SET NOCOUNT ON
	
	DECLARE @CloseEntryType		UNIQUEIDENTIFIER   -- نمط سند إغلاق النقات 
	DECLARE @CurrentAccount		UNIQUEIDENTIFIER    -- حساب جاري الإدارة
	DECLARE @ExpensesAccount	UNIQUEIDENTIFIER   -- الحساب الختامي للنفقات  
	DECLARE @IsDetailed			BIT
	DECLARE @AutoPost			BIT
	DECLARE @MaxCENumber		INT
	DECLARE @MaxPYNumber		INT
	DECLARE @IsEntryAdded		INT  = 0
	DECLARE @DefCurrency		UNIQUEIDENTIFIER
	SET @CloseEntryType		= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_ExpenseClosePayType'))
	SET @ExpensesAccount	= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_ExpensecloseAcc'))
	SET @CurrentAccount		= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_CurrentMngAcc'))
	SET @IsDetailed			= (SELECT [bDetailed] FROM et000 WHERE GUID = @CloseEntryType)
	SET @AutoPost			= (SELECT [bAutoPost] FROM et000 WHERE GUID = @CloseEntryType)
	SET @DefCurrency		= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='AmnCfg_DefaultCurrency'))
     DECLARE @Expenses TABLE( 
	   [Number]				[INT] IDENTITY(0, 1), 
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
	   [AccountName]        [NVARCHAR](256)) 

    INSERT INTO @Expenses (Debit, Credit, AccountGUID, currencyVal, currencyGUID, AccountName)
    SELECT SUM(EN.Debit), SUM(EN.Credit), EN.AccountGUID, EN.CurrencyVal, EN.CurrencyGUID, AC.Name
    FROM en000 EN INNER JOIN ac000 AC ON EN.AccountGUID = AC.GUID
    WHERE AC.FinalGUID = @ExpensesAccount AND CAST(EN.Date AS DATE) = @DayDate
    GROUP BY EN.AccountGUID, EN.CurrencyVal, EN.CurrencyGUID, AC.Name

IF EXISTS(SELECT * FROM @Expenses)
BEGIN
	EXEC prcDisableTriggers 'ce000', 0
	EXEC prcDisableTriggers 'py000', 0
	EXEC prcDisableTriggers 'er000', 0
	EXEC prcDisableTriggers 'en000', 0

	SET @MaxCENumber = ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1
	INSERT INTO ce000 (GUID, Type, Number, Security, Date, Debit, Credit, TypeGUID, IsPosted, PostDate, CurrencyGUID, CurrencyVal, Notes)
	values (@CEGuid, 1, @MaxCENumber, 1, @DayDate, 0, 0, @CloseEntryType, @AutoPost, @DayDate, @DefCurrency, 1, @Notes)

	SET @MaxPYNumber = ISNULL((SELECT MAX(Number) FROM py000), 0) + 1

	INSERT INTO py000 (GUID, Number, Security, Date, AccountGUID, TypeGUID, CurrencyGUID, CurrencyVal, Notes)
	SELECT @PYGuid, @MaxPYNumber, 1, @DayDate, @CurrentAccount, @CloseEntryType, @DefCurrency, 1, @Notes

	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)
	SELECT @CEGuid, @PYGuid, 4, @MaxPYNumber

	IF(@IsDetailed = 1)
	BEGIN
		INSERT INTO [en000] (
					[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
					[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
				SELECT 
					(Number * 2), @DayDate, 
					CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
					CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END, 
					CONCAT(@CloseStr, AccountName, @ForDayStr), currencyVal, '', 0, 0, @CEGuid, accountGUID, currencyGUID, 0x0, @CurrentAccount, 0x0
				FROM @Expenses

		INSERT INTO [en000] (
					[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
					[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
				SELECT 
					(Number * 2) + 1, @DayDate, 
					CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END, 
					CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
					CONCAT(@CloseStr, AccountName, @ForDayStr), currencyVal, '', 0, 0, @CEGuid, @CurrentAccount, currencyGUID, 0x0, accountGUID, 0x0
				FROM @Expenses
	END
	ELSE
	BEGIN
		INSERT INTO [en000] (
					[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
					[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
				SELECT 
					Number, @DayDate, 
					CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
					CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END,
					CONCAT(@CloseStr, AccountName, @ForDayStr), currencyVal, '', 0, 0, @CEGuid, accountGUID, currencyGUID, 0x0, 0x0, 0x0
				FROM @Expenses

		DECLARE @MaxENNumber INT SET @MaxENNumber = (SELECT COUNT(*) FROM @Expenses)

		INSERT INTO [en000] (
					[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
					[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid]) 
				SELECT 
					@MaxENNumber, @DayDate, 
					CASE WHEN SUM(Debit - Credit) > 0 THEN SUM(Debit - Credit) ELSE 0 END, 
					CASE WHEN SUM(Debit - Credit) < 0 THEN SUM(-(Debit - Credit)) ELSE 0 END,  
					CONCAT(@CloseStr, AccountName, @ForDayStr), currencyVal, '', 0, 0, @CEGuid, @CurrentAccount, currencyGUID, 0x0, 0x0, 0x0
				FROM @Expenses
				GROUP BY currencyVal, currencyGUID, AccountName
	END

	UPDATE ce000 SET Debit  = SEN.DEBIT, Credit = SEN.CREDIT
	FROM 
		(SELECT ParentGUID, SUM(Debit) DEBIT, SUM(Credit) CREDIT
		FROM en000 EN WHERE EN.ParentGUID = @CEGuid
		GROUP BY EN.ParentGUID) SEN
	WHERE GUID = SEN.ParentGUID

	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'py000'
	EXEC prcEnableTriggers 'er000'	
	EXEC prcEnableTriggers 'en000'
	SET @IsEntryAdded = 1
	
	INSERT INTO RepSrcs(Guid,IdTbl,IdType,IdSubType) VALUES(@CloseEntryType, @CloseEntryType, @CloseEntryType , 0 ) 
	SET @DayDate = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_FPDate', default)) 
	EXEC prcEntry_reNumber 0 , @CloseEntryType , @DayDate 
	DELETE FROM RepSrcs WHERE IdTbl = @CloseEntryType
END
SELECT 	@IsEntryAdded IsEntryAdded
#########################################################
CREATE PROCEDURE prcCheckCurrentAccount
	@DayDate	DATE
AS
	SET NOCOUNT ON

	DECLARE @CurrentTestAccount		UNIQUEIDENTIFIER   -- ���� ������ ������ 
	SET @CurrentTestAccount		= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_CurrentTestAcc'))
	
	SELECT SUM(EN.Debit - EN.Credit) AS Balance
	FROM en000 EN INNER JOIN ac000 AC ON EN.AccountGUID = AC.GUID
	WHERE CAST(EN.Date AS DATE) = @DayDate AND AC.FinalGUID = @CurrentTestAccount
#########################################################
CREATE PROCEDURE prcCloseDay
@Date		AS DATE,
@Entry		AS UNIQUEIDENTIFIER,
@DecreaseBillGuid		AS UNIQUEIDENTIFIER,
@IncreaseBillGuid	AS UNIQUEIDENTIFIER
AS   
	UPDATE [bu000]
	SET [Security] = 3
	WHERE CAST([Date] AS DATE) = @Date
		
	UPDATE [ce000]
	SET [Security] = 3
	WHERE CAST([Date] AS DATE) = @Date

	UPDATE [py000]
	SET [Security] = 3
	WHERE CAST([Date] AS DATE) = @Date

	DECLARE @Size INT
	SET @Size = (SELECT ISNULL(MAX(Number), 0) FROM [PFCClosedDays000])
		
	INSERT [PFCClosedDays000](Number, Guid, Date, IsPosted, EntryGUID, DecreaseBillGUID, IncreaseBillGUID)
	Values ( @Size + 1, newId(), @Date, 0, @Entry, @DecreaseBillGuid, @IncreaseBillGuid)
#################################################################
CREATE PROCEDURE prcUnCloseDay
@Date		AS DATE
AS  
	UPDATE [bu000]
	SET [Security] = 1
	WHERE CAST([Date] AS DATE) = @Date
		
	UPDATE [ce000]
	SET [Security] = 1
	WHERE CAST([Date] AS DATE) = @Date

	UPDATE [py000]
	SET [Security] = 1
	WHERE CAST([Date] AS DATE) = @Date

	DELETE FROM [PFCClosedDays000]
	WHERE [Date] = @Date
#################################################################
CREATE FUNCTION fnStock_getBalance( 
		@MatGuid [uniqueidentifier] = 0x00,
		@StoreGuid [UNIQUEIDENTIFIER] =0x00,
		@StartDate [DATETIME] = '1/1/1980', 
		@EndDate [DATETIME] = '1/1/2100',
		@PriceType INT = 128
		) 
	returns [float] 
AS BEGIN 
/* 
this function: 
	- returns the balance of a given @MatGuid in the given @STOREGuid by accumulating posted bills 
	- ignores @STOREGuid when 0x0. 
	- deals with core tables directly, ignoring branches and itemSecurity features. 
*/
declare @result [float] 
	BEGIN 
	DECLARE @DayDate DATE =
	ISNULL( (SELECT Top(1) MTP.DATE	FROM  MaterialPriceHistory000 MTP
	WHERE MTP.DATE<= @EndDate ORDER BY DATE desc), '1/1/1980')

	DECLARE @TEMP TABLE
		(
			[Guid]		[UNIQUEIDENTIFIER] ,
			[Name]		NVARCHAR(250) ,
			[LatinName] NVARCHAR(250) ,
			[Code]		NVARCHAR(100) ,
			[Type]		[INT]	,
			[LastPrice] [FLOAT]	,
			[LastPrice2][FLOAT]	,
			[LastPrice3][FLOAT]	,
			[Unit2Fact] [FLOAT]	,
			[Unit3Fact] [FLOAT]	,
			[Whole]		[FLOAT]	,
			[Half]		[FLOAT] ,
			[Retail]	[FLOAT] ,
			[EndUser]	[FLOAT] ,
			[Export]	[FLOAT] ,
			[Vendor]	[FLOAT] ,
			[Whole2]	[FLOAT] ,
			[Half2]		[FLOAT] ,
			[Retail2]	[FLOAT] ,
			[EndUser2]	[FLOAT] ,
			[Export2]	[FLOAT] ,
			[Vendor2]	[FLOAT] ,
			[Whole3]	[FLOAT] ,
			[Half3]		[FLOAT] ,
			[Retail3]	[FLOAT] ,
			[EndUser3]	[FLOAT] ,
			[Export3]	[FLOAT] ,
			[Vendor3]	[FLOAT]
		)

	INSERT INTO @TEMP
	SELECT
		MT.Guid,
		MT.Name,
		MT.LatinName,
		MT.Code,
		MT.Type, 
		Mt.LastPrice,
		Mt.LastPrice2,
		Mt.LastPrice3,
		Mt.Unit2Fact,
		Mt.Unit3Fact,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Whole		ELSE  MTP.Whole		END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Half		ELSE  MTP.Half		END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Retail	ELSE  MTP.Retail	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.EndUser	ELSE  MTP.EndUser	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Export	ELSE  MTP.Export	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Vendor	ELSE  MTP.Vendor	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Whole2	ELSE  MTP.Whole2	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Half2		ELSE  MTP.Half2		END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Retail2	ELSE  MTP.Retail2	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.EndUser2	ELSE MTP.EndUser2	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Export2	ELSE MTP.Export2	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Vendor2	ELSE  MTP.Vendor2	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Whole3	ELSE  MTP.Whole3	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Half3		ELSE  MTP.Half3		END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Retail3	ELSE  MTP.Retail3	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.EndUser3	ELSE MTP.EndUser3	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Export3	ELSE  MTP.Export3	END	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Vendor3	ELSE  MTP.Vendor3	END
	FROM
		MaterialPriceHistory000 MTP
		INNER JOIN mt000 MT ON MTP.MatGuid = MT.GUID
	WHERE
		(@DayDate = '1/1/1980') OR( MTP.DATE = @DayDate)
	ORDER BY
		MTP.DATE DESC

		set @result = (
			SELECT
			SUM(
				ISNULL(
						(
							(CASE Bi.Unity	WHEN 1 THEN (Bi.Qty+Bi.BonusQnt)    
											WHEN 2 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit2Fact])      
											WHEN 3 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit3Fact])   
							END
							)
						*
						CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END
						)
				, 0)
				*
				(
				CASE WHEN @PriceType = 4 THEN (CASE Bi.Unity	WHEN 1 THEN Mt.Whole   
																WHEN 2 THEN Mt.Whole2     
																WHEN 3 THEN Mt.Whole3
												  
												END
												)
					WHEN @PriceType = 8 THEN (CASE Bi.Unity	WHEN 1 THEN Mt.Half   
																WHEN 2 THEN Mt.Half2     
																WHEN 3 THEN Mt.Half3
											  
												END
												)
					WHEN @PriceType = 32 THEN (CASE Bi.Unity	WHEN 1 THEN Mt.Vendor   
																WHEN 2 THEN Mt.Vendor2     
																WHEN 3 THEN Mt.Vendor3
												 
												END
												)
					WHEN @PriceType = 16 THEN (CASE Bi.Unity	WHEN 1 THEN Mt.Export   
																WHEN 2 THEN Mt.Export2     
																WHEN 3 THEN Mt.Export3
												  
												END
												)
					WHEN @PriceType = 64 THEN (CASE Bi.Unity	WHEN 1 THEN Mt.Retail   
																WHEN 2 THEN Mt.Retail2     
																WHEN 3 THEN Mt.Retail3
												  
												END
												)
					WHEN @PriceType = 128 THEN (CASE Bi.Unity	WHEN 1 THEN Mt.EndUser   
																WHEN 2 THEN Mt.EndUser2     
																WHEN 3 THEN Mt.EndUser3
												   
												END
												)
					ELSE (CASE Bi.Unity	WHEN 1 THEN Mt.LastPrice   
										WHEN 2 THEN Mt.LastPrice2     
										WHEN 3 THEN Mt.LastPrice3
							   
							END
						)
				END
				)
			)
			FROM
				@TEMP Mt   
				LEFT JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid
				LEFT JOIN Bu000 Bu on Bu.Guid = Bi.ParentGuid   
				LEFT JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
			WHERE    
			(@StoreGuid = 0x0 OR Bi.StoreGuid = @StoreGuid)
			AND (@MatGuid = 0x0 OR Bi.MatGUID = @MatGuid)
			AND bu.IsPosted = 1
			AND CAST (Bu.Date AS DATE) BETWEEN @StartDate AND @EndDate)
			
	END 
	RETURN isnull(@result, 0.0) 
END 
#################################################################
CREATE PROC repCheckStock
		@StartDate DATETIME = '1/1/1980', 
		@EndDate DATETIME = '1/1/2100',
		@PriceType INT = 128,
		@ShowClosedError BIT = 0
AS
	SET NOCOUNT ON;
  
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	DECLARE @SaleGoodsAcc UNIQUEIDENTIFIER    
	SET @SaleGoodsAcc	= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_SaleGoodsAcc'))

	CREATE TABLE #MATHistTBL ([Whole] [FLOAT], [Half] [FLOAT], [Retail] [FLOAT], [EndUser] [FLOAT], [Export] [FLOAT], [Vendor] [FLOAT],
						[Guid] [UNIQUEIDENTIFIER], [LatinName] [VARCHAR](500), [Name] [VARCHAR](500), [LastPrice] [FLOAT])

	INSERT INTO  #MATHistTBL EXEC PrcGetMatPriceHistory @EndDate

	---------------------------------------------------------------------------------------
	
	DECLARE @itemBalance TABLE
	(
		biGuid UNIQUEIDENTIFIER,
		entryGuid UNIQUEIDENTIFIER,
		balance FLOAT
	)

	INSERT INTO @itemBalance
	SELECT	
		ISNULL(bi.biGUID, 0x0),
		en.ParentGUID,
		SUM(ISNULL(En.Debit, 0) - ISNULL(En.Credit, 0)) AS Balance
	FROM
		vwExtended_bi AS Bi 
		FULL OUTER JOIN en000 En ON En.BiGUID = Bi.biGUID 
		INNER JOIN ce000 CE ON EN.ParentGUID = CE.GUID
	WHERE 
		CE.IsPosted = 1
		AND en.Date BETWEEN @StartDate AND @EndDate 
		AND en.AccountGUID = @SaleGoodsAcc
		AND (bi.buDate IS NULL OR CAST (bi.buDate AS DATE) BETWEEN @StartDate AND @EndDate)
	GROUP BY bi.biGUID, en.ParentGUID
	--------------------------------------------------------------------------------------------
	SELECT
		ISNULL(Mt.Guid, 0x0) AS MatGuid,
		CASE @Lang WHEN 0 THEN Mt.Name ELSE (CASE Mt.LatinName WHEN N'' THEN Mt.Name ELSE Mt.LatinName END) END AS MatName,
		SUM(
			CASE ISNULL(bu.IsPosted, 0) WHEN 0 THEN 0
			ELSE 
				ISNULL(
							(
								(Bi.Qty + Bi.BonusQnt)
								*
								(CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END)
							)
					, 0)
			END
		) AS Qty,
		ISNULL(CASE WHEN @PriceType = 4 THEN Mt.Whole
					WHEN @PriceType = 8 THEN Mt.Half
					WHEN @PriceType = 32 THEN Mt.Vendor
					WHEN @PriceType = 16 THEN Mt.Export
					WHEN @PriceType = 64 THEN Mt.Retail
					WHEN @PriceType = 128 THEN Mt.EndUser
					ELSE Mt.LastPrice
				END, 0) MatPrice,
	   SUM(ISNULL(ib.balance, 0)) AS Balance
	FROM
		#MATHistTBL Mt   
		LEFT JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid
		LEFT JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		LEFT JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid 
		FULL OUTER JOIN @itemBalance Ib ON Ib.BiGUID = Bi.GUID 
	WHERE 
		bu.Date IS NULL OR	CAST (Bu.Date AS DATE) BETWEEN @StartDate AND @EndDate
	GROUP BY   
		Mt.Guid,
		Mt.Name,
		Mt.LatinName,
		Mt.Whole,
		Mt.Half,
		Mt.Vendor,
		Mt.Export,
		Mt.Retail,
		Mt.EndUser,
		Mt.LastPrice
	-------------------------------------------------------------------------------------------

	DECLARE @pricePrec INT = dbo.fnOption_GetInt('AmnCfg_PricePrec', 2)
	DECLARE @IncreaseBillTypeGUID UNIQUEIDENTIFIER, @DecreaseBillTypeGUID UNIQUEIDENTIFIER

	SET	@IncreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_IncreasePricesBillType'))
	SET	@DecreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_DecreasePricesBillType'))

	SELECT ISNULL(bi.biMatPtr, 0x0) AS MatGuid,
		   bi.buFormatedNumber AS BillType,
		   bi.buDate AS BillDate,
		   ISNULL(Bi.biQty, 0) + ISNULL(Bi.biBonusQnt, 0) AS Qty,
		   ISNULL(f.HPrice, 0) AS MatPrice,
		   ISNULL(Bi.biUnitPrice, 0) AS UnitPrice,
		   ISNULL(ib.balance, 0) AS Balance,
		   ib.entryGuid AS EntryGuid,
		   bi.buGUID AS BillGuid
	FROM
		vwExtended_bi AS bi 
		LEFT JOIN PFCClosedDays000 CD ON CAST(buDate AS DATE) = CD.Date
		FULL OUTER JOIN @itemBalance Ib ON Ib.biGuid = Bi.biGUID 
		OUTER APPLY fnGetMatHistoryPrice(bi.biMatPtr, bi.buDate, @PriceType) AS f
	WHERE 
		(bi.buType IS NULL OR bi.buType NOT IN (@IncreaseBillTypeGUID, @DecreaseBillTypeGUID))
		AND (bi.buDate IS NULL OR CAST (bi.buDate AS DATE) BETWEEN @StartDate AND @EndDate)
		AND (@ShowClosedError = 1 OR CD.Date IS NULL)
		AND (ISNULL(bi.biMatPtr, 0x0) = 0x0 
			OR (ROUND(ISNULL((biQty + biBonusQnt) * F.HPrice, 0), @pricePrec) - ROUND(ABS(ISNULL(balance, 0)), @pricePrec) <> 0)
			OR (ROUND(F.HPrice, @pricePrec) - ROUND(biUnitPrice, @pricePrec) <> 0))
#################################################################
CREATE PROC getPFCMatInventory
		@StartDate DATETIME = '1/1/1980', 
		@EndDate DATETIME = '1/1/2100',
		@PriceType INT = 128
AS
	SET NOCOUNT ON;

	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	DECLARE @SaleGoodsAcc UNIQUEIDENTIFIER    
	SET @SaleGoodsAcc	= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_SaleGoodsAcc'))

	CREATE TABLE #MATHistTBL ([Whole] [FLOAT], [Half] [FLOAT], [Retail] [FLOAT], [EndUser] [FLOAT], [Export] [FLOAT], [Vendor] [FLOAT],
						[Guid] [UNIQUEIDENTIFIER], [LatinName] [VARCHAR](500), [Name] [VARCHAR](500), [LastPrice] [FLOAT])

	INSERT INTO  #MATHistTBL EXEC PrcGetMatPriceHistory @EndDate

	---------------------------------------------------------------------------------------
	
	DECLARE @itemBalance TABLE
	(
		biGuid UNIQUEIDENTIFIER,
		entryGuid UNIQUEIDENTIFIER,
		balance FLOAT
	)

	INSERT INTO @itemBalance
	SELECT	
		ISNULL(bi.biGUID, 0x0),
		en.ParentGUID,
		SUM(ISNULL(En.Debit, 0) - ISNULL(En.Credit, 0)) AS Balance
	FROM
		vwExtended_bi AS Bi 
		FULL OUTER JOIN en000 En ON En.BiGUID = Bi.biGUID 
	WHERE 
		en.Date BETWEEN @StartDate AND @EndDate 
		AND en.AccountGUID = @SaleGoodsAcc
		AND (bi.buDate IS NULL OR CAST (bi.buDate AS DATE) BETWEEN @StartDate AND @EndDate)
	GROUP BY bi.biGUID, en.ParentGUID
	--------------------------------------------------------------------------------------------
	SELECT
		ISNULL(Mt.Guid, 0x0) AS MatGuid,
		CASE @Lang WHEN 0 THEN Mt.Name ELSE (CASE Mt.LatinName WHEN N'' THEN Mt.Name ELSE Mt.LatinName END) END AS MatName,
		SUM(
			CASE bu.IsPosted WHEN 0 THEN 0
			ELSE 
				ISNULL(
							(
								(Bi.Qty + Bi.BonusQnt)
								*
								(CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END)
							)
					, 0)
			END
		) AS Qty,
		ISNULL(CASE WHEN @PriceType = 4 THEN Mt.Whole
					WHEN @PriceType = 8 THEN Mt.Half
					WHEN @PriceType = 32 THEN Mt.Vendor
					WHEN @PriceType = 16 THEN Mt.Export
					WHEN @PriceType = 64 THEN Mt.Retail
					WHEN @PriceType = 128 THEN Mt.EndUser
					ELSE Mt.LastPrice
				END, 0) MatPrice,
	   SUM(ISNULL(ib.balance, 0)) AS Balance
	FROM
		#MATHistTBL Mt   
		LEFT JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid
		LEFT JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		LEFT JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid 
		RIGHT JOIN @itemBalance Ib ON Ib.BiGUID = Bi.GUID 
	WHERE 
		bu.Date IS NULL OR	CAST (Bu.Date AS DATE) BETWEEN @StartDate AND @EndDate
	GROUP BY   
		Mt.Guid,
		Mt.Name,
		Mt.LatinName,
		Mt.Whole,
		Mt.Half,
		Mt.Vendor,
		Mt.Export,
		Mt.Retail,
		Mt.EndUser,
		Mt.LastPrice
#################################################################
CREATE PROC PrcGetMatPriceHistory  
		@EndDate DATETIME = '1/1/2100'
AS
	SET NOCOUNT ON;
	DECLARE @DayDate DATE =
	ISNULL( (SELECT Top(1) MTP.DATE	FROM  MaterialPriceHistory000 MTP
	WHERE MTP.DATE <= @EndDate ORDER BY DATE desc), '1/1/1980')

	SELECT
		CASE @DayDate WHEN '1/1/1980' THEN MT.Whole		ELSE  MTP.Whole		END	AS [Whole]		,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Half		ELSE  MTP.Half		END	AS [Half]		,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Retail	ELSE  MTP.Retail	END	AS [Retail]	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.EndUser	ELSE  MTP.EndUser	END	AS [EndUser]	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Export	ELSE  MTP.Export	END	AS [Export]	,
		CASE @DayDate WHEN '1/1/1980' THEN MT.Vendor	ELSE  MTP.Vendor	END	AS [Vendor]	,
		MT.Guid,
		MT.LatinName, MT.Name, Mt.LastPrice
	FROM
		MaterialPriceHistory000 MTP
		INNER JOIN mt000 MT ON MTP.MatGuid = MT.GUID
	WHERE
		(@DayDate = '1/1/1980') OR( MTP.DATE = @DayDate)
	ORDER BY
		MTP.DATE DESC
#################################################################
CREATE FUNCTION fnGetMatHistoryPrice
(
 @MatGuid UNIQUEIDENTIFIER,
 @buDate Date,
 @PriceType INT
)
RETURNS @rtnTable TABLE
(HPrice FLOAT)
AS
BEGIN
	INSERT INTO @rtnTable
	SELECT Top(1) 
		CASE WHEN @PriceType = 4 THEN MTP.Whole
			 WHEN @PriceType = 8 THEN MTP.Half
			 WHEN @PriceType = 32 THEN MTP.Vendor
			 WHEN @PriceType = 16 THEN MTP.Export
			 WHEN @PriceType = 64 THEN MTP.Retail
			 WHEN @PriceType = 128 THEN MTP.EndUser
		 END
	FROM  MaterialPriceHistory000 MTP       
	WHERE MTP.DATE <= @buDate AND MTP.MatGuid = @MatGuid 
	ORDER BY DATE desc
 RETURN
END
###################################################################
CREATE FUNCTION fnPFCIsLastWorkDay(
	@date datetime
)
RETURNS BIT
AS
BEGIN
	DECLARE @DecreaseBillTypeGUID UNIQUEIDENTIFIER, @IncreaseBillTypeGUID UNIQUEIDENTIFIER

	SET	@IncreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_IncreasePricesBillType'))
	SET	@DecreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_DecreasePricesBillType'))

	if EXISTS (
		SELECT ce.Guid 
		FROM [ce000] ce 
			INNER JOIN er000 er ON ce.GUID = er.EntryGUID
			INNER JOIN bu000 bu ON bu.GUID = er.ParentGUID
		WHERE 
			CAST(ce.[DATE] AS DATE) >= @date
			AND bu.TypeGUID NOT IN (@IncreaseBillTypeGUID, @DecreaseBillTypeGUID)
		)
		return 0
	
	if EXISTS (SELECT Guid FROM [bu000] 
		WHERE 
			CAST([DATE] AS DATE) >= @date
			AND TypeGUID NOT IN (@IncreaseBillTypeGUID, @DecreaseBillTypeGUID)
		)
		RETURN 0

	RETURN 1
END
###################################################################
#END