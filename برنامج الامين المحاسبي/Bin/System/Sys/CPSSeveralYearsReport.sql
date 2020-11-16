############################################################################################
CREATE PROCEDURE prcCPSSeveralYearsReport
-- Params -------------------------------   
  @Custmer					UNIQUEIDENTIFIER,
  @CustmerName				NVARCHAR(250),
  @CostCenterGUID			UNIQUEIDENTIFIER,
  @StartDate				DATETIME,
  @EndDate					DATETIME,
  @Contain					NVARCHAR(200),    
  @NotContain				NVARCHAR(200),
  @CurrGUID					UNIQUEIDENTIFIER,
  @ShowCash					BIT,
  @ShowLater				BIT,
  @ShowPosted				BIT,
  @ShowUnPosted				BIT,
  @ShowOnlyCheckEntry		BIT,
  @SearchByName				INT,
  @BalanceZeroOnFirstPeriod	BIT,
  @BillDetails				BIT,
  @DiscAndExtraDetails		BIT,
  @ReportSourceFlag			INT
-----------------------------------------   
AS
    SET NOCOUNT ON
-------------------------------------------------------------------------  
CREATE TABLE #MasterResult
  (
	Number			  INT IDENTITY(1,1),
	DatabaseName	  NVARCHAR(256),
	FirstPeriodDate   DATETIME,
	EndPeriodDate	  DATETIME,
	PreviousBalance   FLOAT,
	MasterDebit		  FLOAT,
	MasterCredit	  FLOAT,
	MasterMoveBalance FLOAT,
	CurrentBalance    FLOAT,
	AccountCode		  NVARCHAR(256),
	AccountName		  NVARCHAR(256),
	CustomerName	  NVARCHAR(256),
	IsLocalDb			BIT
  )


CREATE TABLE #Result
  (
	[GUID]					UNIQUEIDENTIFIER,
	PaymentGUID				UNIQUEIDENTIFIER,
	CustomerGUID			UNIQUEIDENTIFIER,
	AccountGUID				UNIQUEIDENTIFIER,
	Note					NVARCHAR(1000),
	[Date]					DATETIME,
	DueDate					DATETIME,
	FormatedNumber			NVARCHAR(250),
	CostName				NVARCHAR(250),
	Debit					FLOAT,
	Credit					FLOAT,
	Dir						INT,
	BillPayType				INT,
	BillTotalExtra			FLOAT,
	BillTotalDisc			FLOAT,
	BillVat					FLOAT,
	BillStore				NVARCHAR(250),
	BillCol1				NVARCHAR(100),
	BillCol2				NVARCHAR(100),
	BillCol3				NVARCHAR(100),
	BillCol4				NVARCHAR(100),
	BillSaleMan				FLOAT,
	BillVendor				FLOAT,
	BillBranch				NVARCHAR(100),
	BillFPay				FLOAT,
	ChequeAutoGenerateEntry BIT,
	BiGUID					UNIQUEIDENTIFIER,
	MatGUID					UNIQUEIDENTIFIER,
	MatName					NVARCHAR(250),
	biMatQty				FLOAT,
	biMatPrice				FLOAT,
	biMatUnitFact			FLOAT,
	biMatUnitName			NVARCHAR(250),
	biStoreName				NVARCHAR(250),
	biNote					NVARCHAR(1000),
	biDiscount				FLOAT,
	biExtra					FLOAT,
	biVat					FLOAT,
	BiClass					NVARCHAR(250), 
	BiCostCenter			NVARCHAR(250), 
	biQty2					FLOAT, 
	MtUnit2					NVARCHAR(100), 
	biQty3					FLOAT, 
	MtUnit3					NVARCHAR(100), 
	biWidth					FLOAT, 
	biHeight				FLOAT,
	biLength				FLOAT, 
	biExpireDate			DATETIME, 
	MatCreateDate			DATETIME,
	RecType					NVARCHAR(10),
	DatabaseName			NVARCHAR(256),
	IsLocalDb				BIT,
	UserSecurity			INT,
	Security				INT
  )

   CREATE TABLE #DiscAndExtraDetailsResult		
  (		
	BillGuid				UNIQUEIDENTIFIER,		
	AccountGuid				UNIQUEIDENTIFIER,		
	AccountName				NVARCHAR(256),		
	Discount				FLOAT,		
	Extra					FLOAT		
	)

	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 

	DECLARE @CustmerGUID			UNIQUEIDENTIFIER;
  	DECLARE @GetBill				NVARCHAR(MAX);
	DECLARE @GetCheque				NVARCHAR(MAX);
	DECLARE @GetEnrty				NVARCHAR(MAX);
	DECLARE @DataBaseName			NVARCHAR(128);
	DECLARE @FirstPeriodDate		DATETIME;
	DECLARE @EndPeriodDate			DATETIME;
	DECLARE @firstLoop				BIT;
	DECLARE @GetPrevBalance			NVARCHAR(300);
	DECLARE @prevBalance			FLOAT;
	DECLARE @GetCustomerGuid		NVARCHAR(300);
	DECLARE @Query					NVARCHAR(300);
	DECLARE @CustmerAccGUID			UNIQUEIDENTIFIER;
	DECLARE @AccountCode			NVARCHAR(256);
	DECLARE @AccountName			NVARCHAR(256);
	DECLARE @CustomerName			NVARCHAR(256);
	DECLARE @UserId					UNIQUEIDENTIFIER;
	DECLARE @Lang					INT;

	EXEC @Lang = [dbo].fnConnections_GetLanguage;

  	DECLARE AllDatabases CURSOR FOR				 
	SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate) ORDER BY [FirstPeriod]
	OPEN AllDatabases;	    
	
	
	SET @firstLoop   = 1;
	FETCH NEXT FROM AllDatabases INTO @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
		SET @CustmerGUID = 0x0;
		---------------- Search By Name
		IF(@SearchByName = 1) 
		BEGIN
			SET @GetCustomerGuid = N'SELECT  @CustmerGUID = [GUID] FROM ' + @DataBaseName + '.dbo.cu000 WHERE CustomerName = '''+@CustmerName+''' '
			EXEC sp_executesql @GetCustomerGuid, N'@CustmerGUID UNIQUEIDENTIFIER out', @CustmerGUID OUT
		END
	   ELSE
	   BEGIN
		SET @CustmerGUID = @Custmer;
	   END

	   ---------------- Customer Account Guid
	   SET @Query = 'SELECT @GUIDOut = AccountGUID FROM  [' + @DataBaseName + '].[dbo].[cu000] WHERE GUID = ''' + CONVERT(NVARCHAR(38), @CustmerGUID) + '''';
	   EXEC sp_executesql @Query, N'@GUIDOut  UNIQUEIDENTIFIER OUTPUT', @GUIDOut=@CustmerAccGUID OUTPUT;

	   ---------------- Account Name
	   SET @AccountName = ''; SET @AccountCode = '';
	   SET @Query = 'SELECT @NameOut = Name, @CodeOut = Code FROM  [' + @DataBaseName + '].[dbo].[ac000] WHERE GUID = ''' + CONVERT(NVARCHAR(38), @CustmerAccGUID) + '''';
	   EXEC sp_executesql @Query, N'@NameOut  NVARCHAR(256) OUTPUT, @CodeOut NVARCHAR(256) OUTPUT', @NameOut=@AccountName OUTPUT, @CodeOut=@AccountCode OUTPUT;

	   ---------------- Customer Name
	   SET @CustomerName = '';
	   SET @Query = 'SELECT @NameOut = CustomerName FROM  [' + @DataBaseName + '].[dbo].[cu000] WHERE GUID = ''' + CONVERT(NVARCHAR(38), @CustmerGUID) + '''';
	   EXEC sp_executesql @Query, N'@NameOut  NVARCHAR(256) OUTPUT', @NameOut=@CustomerName OUTPUT;

	   ---------------- Previous Balance For First Data
		IF(@firstLoop = 1)
		BEGIN
			SET @GetPrevBalance = 
			
			'SET @prevBalance = 
			(SELECT [' + @DataBaseName + '].[dbo].prcGetPrevBalance(''' + CONVERT(NVARCHAR(38),@CustmerAccGUID) + 
			''', ''' + CONVERT(NVARCHAR(38),@CurrGUID) + 
			''', ''' + CONVERT(NVARCHAR(38),@FirstPeriodDate) + ''', ''' + CONVERT(NVARCHAR(38),@StartDate) + '''))';

			EXEC sp_executesql @GetPrevBalance, N'@prevBalance FLOAT out', @prevBalance OUT
		END

	   ---------------- Get user id for security
	   IF @DataBaseName = DB_NAME()
	   BEGIN
			SELECT @UserId = [dbo].[fnGetCurrentUserGUID]()
	   END
	   ELSE
	   BEGIN 
		   SET @Query = 'SELECT TOP 1 @UserIdOut=GUID  FROM [' + @DataBaseName + N'].[dbo].us000 WHERE bAdmin = 1'
		   EXEC sp_executesql @Query, N' @UserIdOut UNIQUEIDENTIFIER OUTPUT', @UserIdOut = @UserId OUTPUT;   
	   END

		---------------- BILL
		SET @GetBill =  N'INSERT INTO #Result EXEC [' + @DataBaseName + '].[dbo].[prcBillCPSPerYear] ' +
			'''' + CONVERT(NVARCHAR(38), @CustmerGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CustmerAccGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CostCenterGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(50), @StartDate) + ''',' +
			'''' + CONVERT(NVARCHAR(50), @EndDate) + ''',' +
			'''' + @Contain + ''',' +
			'''' + @NotContain + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CurrGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @UserId)   + ''',' +
			CONVERT(NVARCHAR(10), @ShowCash) + ','  +
			CONVERT(NVARCHAR(10), @ShowLater) + ','  +
			CONVERT(NVARCHAR(10), @ShowPosted) + ','  +
			CONVERT(NVARCHAR(10), @ShowUnPosted) + ','  +
			CONVERT(NVARCHAR(10), @ReportSourceFlag) + ','  +
			CONVERT(NVARCHAR(10), @Lang) 
			
		---------------- CHEQUE
		SET @GetCheque =  N'INSERT INTO #Result EXEC [' + @DataBaseName + '].[dbo].[prcChequeCPSPerYear] ' +
			'''' + CONVERT(NVARCHAR(38), @CustmerGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CustmerAccGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CostCenterGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(50), @StartDate) + ''',' +
			'''' + CONVERT(NVARCHAR(50), @EndDate) + ''',' +
			'''' + @Contain + ''',' +
			'''' + @NotContain + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CurrGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @UserId)   + ''',' +
			CONVERT(NVARCHAR(10), @ReportSourceFlag) + ','  +
			CONVERT(NVARCHAR(10),@ShowOnlyCheckEntry)+ ','  +
			CONVERT(NVARCHAR(10), @Lang) 

		---------------- ENTRY
		SET @GetEnrty =  N'INSERT INTO #Result EXEC [' + @DataBaseName + '].[dbo].[prcEntryCPSPerYear] ' +
			'''' + CONVERT(NVARCHAR(38), @CustmerGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CustmerAccGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CostCenterGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(50), @StartDate) + ''',' +
			'''' + CONVERT(NVARCHAR(50), @EndDate) + ''',' +
			'''' + @Contain + ''',' +
			'''' + @NotContain + ''',' +
			'''' + CONVERT(NVARCHAR(38), @CurrGUID) + ''',' +
			'''' + CONVERT(NVARCHAR(38), @UserId)   + ''',' +
			CONVERT(NVARCHAR(10), @ReportSourceFlag) + ','  +
			CONVERT(NVARCHAR(10), @Lang) 

	   EXEC sp_executesql @GetBill;
	   EXEC sp_executesql @GetCheque;
	   EXEC sp_executesql @GetEnrty;
	   ----------------------------------------------------Update Cash Bill Debit and Credit
	    UPDATE #Result SET Credit = Debit 
		WHERE RecType = 'B' AND BillPayType = 0 AND Credit = 0

		UPDATE #Result SET Debit = Credit 
		WHERE RecType = 'B' AND BillPayType = 0 AND Debit = 0
		----------------------------------------------------		GET Disc And Extra Details Result
		IF(@DiscAndExtraDetails = 1)		
		BEGIN 		
			DECLARE @GetBillDiscAndExtraDet				NVARCHAR(300);		
			SET @GetBillDiscAndExtraDet =  N'INSERT INTO #DiscAndExtraDetailsResult EXEC [' + @DataBaseName + '].[dbo].[prcBillDiscAndExtraDetCPSPerYear] ' +		
			'''' + CONVERT(NVARCHAR(38), @CurrGUID) + ''',' +		
			CONVERT(NVARCHAR(10), @Lang)		
			 EXEC sp_executesql @GetBillDiscAndExtraDet;		
		END 
	   ----------------------------------- MASTER RESULT
	   SELECT Debit + (Case RecType WHEN 'B' THEN (CASE Dir WHEN 0 THEN 0 ELSE BillFPay END) ELSE 0 END) AS Debit INTO #CalcDebit  FROM #Result WHERE DatabaseName = @DataBaseName GROUP BY [GUID], Debit,RecType,Dir,BillFPay
	   SELECT Credit + (Case RecType WHEN 'B' THEN (CASE Dir WHEN 0 THEN BillFPay ELSE 0 END) ELSE 0 END) AS Credit INTO #CalcCredit FROM #Result WHERE DatabaseName = @DataBaseName GROUP BY [GUID], Credit,RecType,Dir,BillFPay

	   	INSERT INTO #MasterResult( DatabaseName, FirstPeriodDate, EndPeriodDate, PreviousBalance, MasterDebit, MasterCredit, 
								   MasterMoveBalance, CurrentBalance, AccountCode, AccountName, CustomerName,IsLocalDb )
		VALUES( @DataBaseName,
				CASE @firstLoop WHEN 1 THEN @StartDate ELSE @FirstPeriodDate END,
				@EndPeriodDate,
				CASE @firstLoop WHEN 1 THEN @prevBalance ELSE 0 END,
				ISNULL((SELECT SUM(Debit) FROM #CalcDebit), 0),
				ISNULL((SELECT SUM(Credit) FROM #CalcCredit),0),
				ISNULL((SELECT SUM(Debit) FROM #CalcDebit), 0) - ISNULL((SELECT SUM(Credit) FROM #CalcCredit),0),
				CASE @firstLoop WHEN 1 THEN (ISNULL((SELECT SUM(Debit) FROM #CalcDebit), 0) - ISNULL((SELECT SUM(Credit) FROM #CalcCredit),0)) + (CASE @BalanceZeroOnFirstPeriod WHEN 1 THEN 0 ELSE @prevBalance END)  ELSE 0 END,
				@AccountCode,
				@AccountName,
				@CustomerName,
				CASE @DataBaseName WHEN  DB_NAME() THEN 1 ELSE 0 END)

		DROP TABLE #CalcDebit;
		DROP TABLE #CalcCredit;
		------------------------------------------------


	   FETCH NEXT FROM AllDatabases INTO  @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	   SET @firstLoop   = 0;
	   SET @prevBalance = 0;
	END

	CLOSE      AllDatabases;
	DEALLOCATE AllDatabases;

	EXEC prcCheckSecurity

--set the end period date of the last database to be the EndDate from report parameters
	
	UPDATE #MasterResult
	SET EndPeriodDate = @EndDate
	WHERE DatabaseName = @DataBaseName
--------Prossicing the current balance and previous balance in Master Result--------

	DECLARE @RowNumber INT = 1
	WHILE (SELECT COUNT(*) FROM #MasterResult) > @RowNumber
	BEGIN
		UPDATE #MasterResult SET PreviousBalance = (SELECT CurrentBalance 
													FROM #MasterResult 
													WHERE Number = @RowNumber)
		WHERE Number = @RowNumber + 1

		UPDATE #MasterResult SET CurrentBalance = (SELECT ISNULL(MasterMoveBalance, 0) + ISNULL(PreviousBalance, 0) 
												   FROM #MasterResult 
												   WHERE Number = @RowNumber + 1)
		WHERE Number = @RowNumber + 1

		SET @RowNumber = @RowNumber + 1
	END

	DECLARE @PrevBalanceOnFirstPeriod FLOAT = (SELECT PreviousBalance FROM #MasterResult WHERE Number = 1)

	IF (@BalanceZeroOnFirstPeriod = 1)
	BEGIN
		UPDATE #MasterResult SET PreviousBalance = 0
		WHERE Number = 1
	END
------------------------------------------------------------------------------------
UPDATE #Result SET IsLocalDb = CASE DatabaseName WHEN  DB_NAME() THEN 1 ELSE 0 END

------------------------------------------ Frormated Number To Entry Generated From Cheques
DECLARE @FormatedNumber NVARCHAR(100)
DECLARE @Item UNIQUEIDENTIFIER
DECLARE @payment UNIQUEIDENTIFIER

SELECT * 
INTO #TempResul 
FROM #Result
WHERE RecType = 'E'

		WHILE (SELECT COUNT(*) FROM #TempResul) > 0
		BEGIN
			SELECT TOP 1 @FormatedNumber = FormatedNumber ,@Item = [GUID] FROM #TempResul	

			IF(@FormatedNumber IS NULL) ---- get frormated number to Entry generated from cheques that is containing customer account
			BEGIN
				SET @payment = (SELECT PaymentGUID    FROM #Result WHERE [GUID] = @Item)
				SET @FormatedNumber = (SELECT FormatedNumber FROM #Result WHERE [GUID] = @payment)
				UPDATE #Result SET FormatedNumber  = @FormatedNumber
				WHERE [GUID] = @Item

				IF(@FormatedNumber IS NULL) ---- get frormated number to Entry generated from cheques that is not containing customer account
				BEGIN
					SET @FormatedNumber = (	SELECT (CASE 0 WHEN 0 THEN NT.Abbrev 
														   ELSE CASE NT.LatinAbbrev WHEN '' THEN NT.Abbrev 
																					ELSE NT.LatinAbbrev END END) + ': ' + CH.Num + ' : ' + CAST(CH.Number AS NVARCHAR(50)) 
											FROM ch000 CH LEFT JOIN nt000 NT ON CH.TypeGUID = NT.[GUID]  
											WHERE CH.[GUID] = @payment)

					UPDATE #Result SET FormatedNumber  = @FormatedNumber
					WHERE [GUID] = @Item
				END
			END

			DELETE #TempResul WHERE [GUID] = @Item
		END

----------------------------------------------------------------------

	SELECT 
		Number			
		,DatabaseName	
		,FirstPeriodDate 
		,EndPeriodDate	
		,ISNULL(PreviousBalance ,0) AS PreviousBalance
		,MasterDebit		
		,MasterCredit	
		,MasterMoveBalance
		,ISNULL(CurrentBalance ,0) AS CurrentBalance
		,AccountCode		
		,AccountName		
		,CustomerName	
		,IsLocalDb		
	FROM #MasterResult

	SELECT  [GUID],   
			[PaymentGUID],  
			[date], 
	        FormatedNumber,
			BillFPay,
			Debit,
			Credit,
			Dir,
			BillTotalDisc, 
			BillTotalExtra,
			BillVat,  
			BillPayType,
			BillCol1,
			BillCol2,   
			BillCol3,    
			BillCol4,
			BillStore, 
			Note,        
			BillSaleMan,
			BillVendor,   
			BillBranch,
			CostName,  
			DueDate,
			RecType,
			DatabaseName,
			IsLocalDb
	FROM #Result
	GROUP BY [GUID],
			[PaymentGUID],
			 FormatedNumber,
			 Note,
			 Debit,
			 Credit,
			 [date],
			 DueDate,
			 BillStore,
			 CostName,
			 BillFPay,
			 BillTotalDisc,
			 BillTotalExtra,
			 BillVat,
			 BillPayType,
			 BillCol1,
			 BillCol2,
			 BillCol3,
			 BillCol4,
			 BillSaleMan,
			 BillVendor,
			 BillBranch,
			 Dir,
			 RecType,
			 DatabaseName,
			IsLocalDb
	ORDER BY [date]
IF(@BillDetails = 1)
BEGIN
	SELECT [GUID],
	       biGUID,
		   MatGUID,
		   MatName,
		   biMatQty,
		   biMatUnitName, 
		   biMatUnitFact, 
		   biMatPrice,
		   biMatPrice * biMatQty AS MatValue,
		   biDiscount,
		   biExtra,
		   biVat,
		   biNote,
		   BiClass,
		   biStoreName,
		   BiCostCenter,
		   biQty2,
		   MtUnit2,
		   biQty3,
		   MtUnit3,
		   biLength,
		   biWidth,
		   biHeight,
		   biExpireDate,
		   MatCreateDate,
		   IsLocalDb
	 FROM #Result
	 WHERE RecType = 'B'
END
IF(@DiscAndExtraDetails = 1)
SELECT * FROM #DiscAndExtraDetailsResult 
SELECT ISNULL(@PrevBalanceOnFirstPeriod, 0) AS PrevBalanceOnFirstPeriod

SELECT * FROM #SecViol

############################################################################################
CREATE PROCEDURE prcBillCPSPerYear
-- Params -------------------------------   
  @CustmerGUID			UNIQUEIDENTIFIER,
  @CustmerAccGUID		UNIQUEIDENTIFIER,
  @CostCenterGUID		UNIQUEIDENTIFIER,
  @StartDate			DATETIME,
  @EndDate				DATETIME,
  @Contain				NVARCHAR(200),    
  @NotContain			NVARCHAR(200),
  @CurrGUID				UNIQUEIDENTIFIER,
  @UserID				UNIQUEIDENTIFIER = 0x0,
  @ShowCash				BIT,
  @ShowLater			BIT,
  @ShowPosted			BIT,
  @ShowUnPosted			BIT,
  @ReportSourceFlag		INT,
  @Lang					INT
-----------------------------------------   
AS  
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------- 

DECLARE @BillPurchase		INT = 2
DECLARE @BillSell			INT = 4
DECLARE @BillReturnPurchase INT = 8
DECLARE @BillReturnSell		INT = 16
DECLARE @BillInput			INT = 32
DECLARE @BillOutput			INT = 64

SELECT D.buGUID				   AS [GUID], 
		0x0,
	   D.buCustPtr			   AS CustomerGUID,
	   AC.[GUID]			   AS AccountGUID,
	   D.buNotes			   AS Note,
	   D.buDate				   AS [Date],
	   D.buMaturityDate		   AS DueDate,

	   CASE @Lang WHEN 0 THEN D.buFormatedNumber 
				  ELSE CASE D.buLatinFormatedNumber WHEN '' THEN D.buFormatedNumber 
													ELSE D.buLatinFormatedNumber END END  AS FormatedNumber,

	   ISNULL(CASE @Lang WHEN 0 THEN CO.Name 
						 ELSE CASE CO.LatinName WHEN '' THEN CO.Name 
												ELSE CO.LatinName END END , '') AS  CostName,

	   CASE D.btIsInput WHEN 0 THEN ISNULL(dbo.[fnCurrency_fix]((D.buTotal + D.buTotalExtra - D.buTotalDisc + D.buVAT), D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate) ,D.buTotal) 
						ELSE (CASE D.buPayType WHEN 0 THEN (CASE D.btIsInput WHEN 0 THEN 0 
																			 ELSE ISNULL(dbo.[fnCurrency_fix](D.buTotal, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate),D.buTotal)  END ) 
											   ELSE 0 END) END AS Debit, 

	   CASE D.btIsInput WHEN 0 THEN 0 
						ELSE ISNULL(dbo.[fnCurrency_fix]((D.buTotal + D.buTotalExtra - D.buTotalDisc + D.buVAT), D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate),D.buTotal)  END AS Credit,

	   D.btIsInput			   AS Dir,
	   D.buPayType			   AS BillPayType,

	   ISNULL(dbo.[fnCurrency_fix](D.buTotalExtra, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate), D.buTotalExtra)	AS BillTotalExtra,
	   ISNULL(dbo.[fnCurrency_fix](D.buTotalDisc, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate), D.buTotalDisc)	AS BillTotalDisc,
	   ISNULL(dbo.[fnCurrency_fix](D.buVAT, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate), D.buVAT)				AS BillVat,


	   ISNULL(CASE @Lang WHEN 0 THEN BUST.Name 
						 ELSE CASE BUST.LatinName WHEN '' THEN BUST.Name
												  ELSE BUST.LatinName END END , '') AS  BillStore,

	   D.buTextFld1			   AS BillCol1,
	   D.buTextFld2			   AS BillCol2,
	   D.buTextFld3			   AS BillCol3,
	   D.buTextFld4			   AS BillCol4,
	   D.buSalesmanPtr		   AS BillSalesMan,
	   D.buVendor			   AS BillVendor,
	   ISNULL(BR.Name, '')	   AS BillBranch,
	   ISNULL(dbo.[fnCurrency_fix](D.buFirstPay, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate),D.buFirstPay) AS BillFPay, 
	   -1,
	   ----------- BI
	   D.biGUID				   AS BiGUID,
	   D.biMatPtr			   AS MatGUID,
	   D.mtCode+' - '+D.mtName AS MatName,
	   D.biBillQty			   AS biMatQty, 
	   ISNULL(dbo.[fnCurrency_fix](D.biPrice, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate), D.biPrice)   AS biMatPrice,
	   [mtUnitFact]			   AS biMatUnitFact, 
	   [mtUnityName]		   AS biMatUnitName,
	   BUST.Name				   AS biStoreName,
	   D.biNotes			   AS biNote,
	   ISNULL(dbo.[fnCurrency_fix](D.biDiscount, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate), D.biDiscount) AS biDiscount,
	   ISNULL(dbo.[fnCurrency_fix](D.biExtra, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate), D.biExtra)	   AS biExtra,
	   ISNULL(dbo.[fnCurrency_fix](D.biVAT, D.buCurrencyPtr, D.buCurrencyVal, @CurrGUID, D.buDate), D.biVAT)		   AS biVat,
	   D.biClassPtr			   AS BiClass, 
	   ISNULL(CoBI.Name, '')   AS BiCostCenter, 
	   D.biQty2				   AS biQty2, 
	   D.MtUnit2			   AS MtUnit2, 
	   D.biQty3				   AS biQty3, 
	   D.MtUnit3			   AS MtUnit3, 
	   D.biWidth			   AS biWidth, 
	   D.biHeight			   AS biHeight,
	   D.biLength			   AS biLength, 
	   D.biExpireDate		   AS biExpireDate, 
	   D.biProductionDate	   AS MatCreateDate,

	   'B'					   AS RecType,
	   DB_NAME()			   AS DatabaseName,
	   0,
	   BuTbl.Security			AS UserSecurity,
	   D.buSecurity				AS Security

FROM vwExtended_bi D 
	INNER JOIN vwExtended_AC AC ON @CustmerAccGUID  = AC.[GUID]
	LEFT  JOIN st000 BUST ON D.buStorePtr = BUST.[GUID] 
	LEFT  JOIN co000 CO	  ON D.buCostPtr  = CO.[GUID]
	LEFT  JOIN mt000 MT	  ON D.biMatPtr	  = MT.[GUID]
	LEFT  JOIN co000 CoBI ON D.biCostPtr  = CoBI.[GUID]
	LEFT  JOIN br000 BR   ON D.buBranch   = BR.[GUID]
	LEFT  JOIN [dbo].[fnGetBillsTypesList](null, @UserID)  BuTbl ON BuTbl.Guid = D.buType

WHERE D.buCustPtr = @CustmerGUID
	AND   (@CostCenterGUID = 0x0 OR @CostCenterGUID = D.buCostPtr)
	AND   D.buDate BETWEEN @StartDate AND @EndDate
	AND   ((@ShowCash	  = 0 AND D.buPayType != 0) OR @ShowCash     = 1)
	AND   ((@ShowLater    = 0 AND D.buPayType  = 0) OR @ShowLater    = 1)
	AND   ((@ShowPosted   = 0 AND D.buIsPosted = 0) OR @ShowPosted   = 1)
	AND   ((@ShowUnPosted = 0 AND D.buIsPosted = 1) OR @ShowUnPosted = 1)
	AND   (@Contain	   = '' OR D.buNotes LIKE	  '%'+ @Contain	   + '%')
	AND   (@NotContain = '' OR D.buNotes NOT LIKE '%'+ @NotContain + '%')
	AND	  (
			(D.btBillType = 0 AND @ReportSourceFlag & @BillPurchase		   = @BillPurchase)		 ------ ÔÑÇÁ
		 OR (D.btBillType = 1 AND @ReportSourceFlag & @BillSell			   = @BillSell)			 ------ ãÈíÚ
		 OR (D.btBillType = 2 AND @ReportSourceFlag & @BillReturnPurchase  = @BillReturnPurchase)------ ãÑÊÌÚ ÔÑÇÁ
		 OR (D.btBillType = 3 AND @ReportSourceFlag & @BillReturnSell	   = @BillReturnSell)	 ------ ãÑÊÌÚ ãÈíÚ
		 OR (D.btBillType = 4 AND @ReportSourceFlag & @BillInput		   = @BillInput)		 ------ ÅÏÎÇá
		 OR (D.btBillType = 5 AND @ReportSourceFlag & @BillOutput		   = @BillOutput) )		 ------ ÅÎÑÇÌ

END
############################################################################################
CREATE PROCEDURE prcChequeCPSPerYear
-- Params -------------------------------   
  @CustmerGUID			UNIQUEIDENTIFIER,
  @CustmerAccGUID		UNIQUEIDENTIFIER,
  @CostCenterGUID		UNIQUEIDENTIFIER,
  @StartDate			DATETIME,
  @EndDate				DATETIME,
  @Contain				NVARCHAR(200),    
  @NotContain			NVARCHAR(200),
  @CurrGUID				UNIQUEIDENTIFIER,
  @UserID				UNIQUEIDENTIFIER = 0x0,
  @ReportSourceFlag		INT,
  @ShowOnlyCheckEntry	BIT,
  @Lang					INT
-----------------------------------------   
AS
    SET NOCOUNT ON
-------------------------------------------------------------------------  

DECLARE @InCheques  INT = 128
DECLARE @OutCheques INT = 256

SELECT CH.[GUID] AS ChGUID, 
	   0x0,
	   CU.[GUID] AS CustGUID,
	   AC.[GUID],
	   CH.Notes,
	   CH.[Date],
	   CH.DueDate,

	   (CASE @Lang WHEN 0 THEN NT.Abbrev 
				   ELSE CASE NT.LatinAbbrev WHEN '' THEN NT.Abbrev 
						ELSE NT.LatinAbbrev END END) + ': ' + CH.Num + ' : ' + CAST(CH.Number AS NVARCHAR(50)) AS FormatedNumber,

	   ISNULL(CASE @Lang WHEN 0 THEN CO.Name 
						 ELSE CASE CO.LatinName WHEN '' THEN CO.Name 
												ELSE CO.LatinName END END , '') AS CostCenter,

	   CASE CH.Dir WHEN 1 THEN  0 
				   ELSE ISNULL([dbo].[fnCurrency_fix](CH.Val, CH.CurrencyGUID, CH.CurrencyVal, @CurrGUID , CH.[Date]),CH.Val) END AS Debit, 

	   CASE CH.Dir WHEN 1 THEN ISNULL([dbo].[fnCurrency_fix](CH.Val, CH.CurrencyGUID, CH.CurrencyVal, @CurrGUID , CH.[Date]),CH.Val) 
				   ELSE 0 END AS Credit,

	   CH.Dir, -1, 0, 0, 0, '' ,'' ,'' ,'' ,'' ,0 ,0 ,'' ,0 ,
	   NT.bAutoEntry,
	   ----------- BI
	   0x0 ,0x0 ,'' ,-1 ,-1 ,-1 ,'' ,'' ,'' ,-1 ,-1 ,-1 ,
	   '' ,'' ,0 ,'' ,0 ,'' ,0 ,0 ,0 ,0 ,0 ,

	   'C'		 AS RecType,
	   DB_NAME() AS DatabaseName,
	   0,
	   NtTbl.Security AS UserSecurity,
	   CH.Security	 AS Security

FROM ch000 CH 
	 LEFT JOIN nt000 NT ON CH.TypeGUID = NT.[GUID] 
	 LEFT JOIN cu000 CU ON CH.AccountGUID = CU.AccountGUID 
	 LEFT JOIN co000 CO ON CH.Cost1GUID = CO.[GUID]
	 LEFT JOIN vwExtended_AC AC ON CH.AccountGUID = AC.[GUID]
	 LEFT JOIN [dbo].[fnGetNotesTypesList](null, @UserID)  NtTbl ON NtTbl.Guid = NT.Guid

WHERE CH.AccountGUID = @CustmerAccGUID
	  AND   CH.CustomerGuid = @CustmerGUID
	  AND  ((@ShowOnlyCheckEntry = 1 AND NT.bAutoEntry = 1) OR  @ShowOnlyCheckEntry = 0)
	  AND   (@CostCenterGUID = 0x0 OR @CostCenterGUID = Ch.Cost1GUID)
	  AND   CH.[Date] BETWEEN @StartDate AND @EndDate
	  AND   CH.TransferCheck = 0
	  AND   (@Contain	 = '' OR CH.Notes LIKE     '%'+ @Contain	+ '%')
	  AND   (@NotContain = '' OR CH.Notes NOT LIKE '%'+ @NotContain + '%')
	  AND   (
	  			(CH.Dir = 1 AND @ReportSourceFlag & @InCheques  = @InCheques)    -------------- ÃæÑÇÞ ãÇáÈÉ ãÞÈæÖÉ
	  		 OR (CH.Dir = 2 AND @ReportSourceFlag & @OutCheques = @OutCheques) ) -------------- ÃæÑÇÞ ãÇáíÉ ãÏÝæÚÉ	
############################################################################################
CREATE PROCEDURE prcEntryCPSPerYear
-- Params -------------------------------   
  @CustmerGUID			UNIQUEIDENTIFIER,
  @CustmerAccGUID		UNIQUEIDENTIFIER,
  @CostCenterGUID		UNIQUEIDENTIFIER,
  @StartDate			DATETIME,
  @EndDate				DATETIME,
  @Contain				NVARCHAR(200),    
  @NotContain			NVARCHAR(200),
  @CurrGUID				UNIQUEIDENTIFIER,
  @UserID				UNIQUEIDENTIFIER = 0x0,
  @ReportSourceFlag		INT,
  @Lang					INT
-----------------------------------------   
AS
    SET NOCOUNT ON
-------------------------------------------------------------------------  
DECLARE @OpeningEntryTypeGuid   UNIQUEIDENTIFIER = 'EA69BA80-662D-4FA4-90EE-4D2E1988A8EA'
SELECT CE.[GUID] AS ceGUID, -- enGUID !?
	 ISNULL(ER.ParentGUID,0x0),
	   CU.[GUID],
	   AC.[GUID],
	   EN.Notes,
	   EN.[Date],
	   '1980-01-01',
	   (CASE CE.TypeGUID WHEN 0x0 THEN CAST(CE.Number AS NVARCHAR(100) ) ELSE 
	   (CASE @Lang WHEN 0 THEN ET.Abbrev 
				   ELSE CASE ET.LatinAbbrev WHEN '' THEN ET.Abbrev
											ELSE ET.LatinAbbrev END END)+' : '+CAST(ER.ParentNumber AS NVARCHAR(100))END) AS FormatedNumber,
	   ISNULL(CASE @Lang WHEN 0 THEN CO.Name 
						 ELSE CASE CO.LatinName WHEN '' THEN CO.Name 
												ELSE CO.LatinName END END , '') AS CostCenter,
	   ISNULL([dbo].[fnCurrency_fix](EN.Debit, EN.CurrencyGUID, EN.CurrencyVal, @CurrGUID, EN.[Date]),EN.Debit)   AS Debit,
	   ISNULL([dbo].[fnCurrency_fix](EN.Credit, EN.CurrencyGUID, EN.CurrencyVal, @CurrGUID, EN.[Date]),EN.Credit) AS Credit,
	   -1, -1, 0, 0, 0, '', '', '', '', '', 0, 0, '', 0, -1,
	   ----------- BI
	   EN.[GUID],
	   0x0 ,'' ,-1 , -1, -1,'' ,-1 ,-1 ,-1 ,-1 ,-1 ,
	    '' ,'' ,0 ,'' ,0 ,'' ,0 ,0 ,0 ,0 ,0 ,
	   'E' AS RecType,
	   DB_NAME() AS DatabaseName,
	   0,
	   EnTbl.Security   AS UserSecurity,
	   CE.Security		AS Security
FROM en000 EN 
	 INNER JOIN ce000 CE ON EN.ParentGUID = CE.[GUID] 
	 LEFT JOIN er000 ER ON ER.EntryGUID = CE.[GUID] 
	 LEFT JOIN et000 ET ON CE.TypeGUID = ET.[GUID]
	 LEFT  JOIN cu000 CU ON CU.AccountGUID = EN.AccountGUID 
	 LEFT  JOIN co000 CO ON EN.CostGUID = CO.[GUID] 
	 LEFT  JOIN vwExtended_AC AC ON en.AccountGUID = AC.[GUID] 
	 LEFT  JOIN [dbo].[fnGetEntriesTypesList](null, @UserID)  EnTbl ON EnTbl.GUID = ET.Guid
WHERE EN.AccountGUID = @CustmerAccGUID
	  AND EN.CustomerGUID = @CustmerGUID
	  AND((ER.ParentType IN (4, 6, 7, 8, 12)) OR (CE.TypeGUID = 0x0))
	  AND (@CostCenterGUID = 0x0 OR @CostCenterGUID = EN.CostGUID)
	  AND CE.[Date] BETWEEN @StartDate AND @EndDate
	  AND (CE.TypeGuid != @OpeningEntryTypeGuid OR (CE.TypeGuid = @OpeningEntryTypeGuid AND CE.[Date] >= @StartDate))
	  AND (@Contain	= ''	OR En.Notes LIKE	 '%'+ @Contain	  + '%')
	  AND (@NotContain = '' OR En.Notes NOT LIKE '%'+ @NotContain + '%')
	  AND (@ReportSourceFlag & 1 = 1)

ORDER BY  EN.[Date]
############################################################################################
CREATE FUNCTION prcGetPrevBalance
(
	@CustmerAccGUID			UNIQUEIDENTIFIER,
	@CurrGUID				UNIQUEIDENTIFIER,
	@DataFirstPeriod		DATETIME,
	@ToDate					DATETIME
)  
	RETURNS [FLOAT]  
AS BEGIN 


DECLARE @PrevBalance FLOAT


	SET @PrevBalance = ( SELECT ISNULL(SUM([dbo].[fnCurrency_fix](enDebit, enCurrencyPtr, enCurrencyVal, @CurrGUID, enDate)) - 
									   SUM([dbo].[fnCurrency_fix](enCredit, enCurrencyPtr, enCurrencyVal, @CurrGUID, enDate)), 0) 

						 FROM vwEN

						 WHERE enAccount = @CustmerAccGUID 
						 AND   enDate BETWEEN @DataFirstPeriod AND @ToDate -1
						 AND   @ToDate >  @DataFirstPeriod )


	RETURN @PrevBalance;
END
############################################################################################
CREATE PROCEDURE prcCPSSeveralYearsCheckCustmerHasDiffName
@Custmer					UNIQUEIDENTIFIER,
@CustmerName				NVARCHAR(250),
@StartDate					DATETIME,
@EndDate					DATETIME

 AS
    SET NOCOUNT ON

	DECLARE @CustName			NVARCHAR(250);
	DECLARE @Query					NVARCHAR(300);
	DECLARE @DataBaseName			NVARCHAR(128);
	DECLARE @FirstPeriodDate		DATETIME;
	DECLARE @EndPeriodDate			DATETIME;

	CREATE TABLE #CustomerGuidTable
  (
  [Name]			NVARCHAR(250)
  )

	DECLARE AllDatabases CURSOR FOR				 
	SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate)
	OPEN AllDatabases;	    
	
	SET @CustName = @CustmerName;
	FETCH NEXT FROM AllDatabases INTO @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  

	
			SET @Query = 'SELECT @CustName = CustomerName FROM  [' + @DataBaseName + '].[dbo].[cu000] WHERE GUID = ''' + CONVERT(NVARCHAR(38), @Custmer) + '''';
			EXEC sp_executesql @Query, N'@CustName  NVARCHAR(250) OUTPUT', @CustName OUTPUT;
		
		INSERT INTO #CustomerGuidTable SELECT @CustName;

	FETCH NEXT FROM AllDatabases INTO  @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	END
	CLOSE      AllDatabases;
	DEALLOCATE AllDatabases;

	DECLARE @HasDifferentName INT

	IF ( SELECT COUNT(*) FROM #CustomerGuidTable ) = (SELECT COUNT(Name) FROM #CustomerGuidTable where Name =  @CustmerName)
	BEGIN 
	set @HasDifferentName = 0
	END
	ELSE 
	BEGIN
	set @HasDifferentName = 1
	END

	SELECT @HasDifferentName AS HasDifferentName
############################################################################################
CREATE PROCEDURE prcCPSSeveralYearsCheckCustmerHasDiffAccountGuid
@Custmer					UNIQUEIDENTIFIER,
@CustmerName				NVARCHAR(250),
@StartDate					DATETIME,
@EndDate					DATETIME,
@SearchByName				INT

 AS
    SET NOCOUNT ON
	DECLARE @CustmerAccountGUID			UNIQUEIDENTIFIER;
	DECLARE @Query					NVARCHAR(300);
	DECLARE @DataBaseName			NVARCHAR(128);
	DECLARE @FirstPeriodDate		DATETIME;
	DECLARE @EndPeriodDate			DATETIME;
	CREATE TABLE #CustomerGuidTable
  (
  [GUID]			UNIQUEIDENTIFIER,
  )
	DECLARE @CurrCutAccGuid UNIQUEIDENTIFIER = (SELECT AccountGUID  FROM cu000 WHERE guid = @Custmer)
	DECLARE AllDatabases CURSOR FOR				 
	SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate)
	OPEN AllDatabases;	    
	
	
	FETCH NEXT FROM AllDatabases INTO @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
		SET @CustmerAccountGUID = 0x0;
		IF(@SearchByName = 1) 
		BEGIN
			SET @Query = N'SELECT  @CustmerAccountGUID = [AccountGUID] FROM ' + @DataBaseName + '.dbo.cu000 WHERE CustomerName = '''+@CustmerName+''' '
			EXEC sp_executesql @Query, N'@CustmerAccountGUID UNIQUEIDENTIFIER out', @CustmerAccountGUID OUT
		END
		ELSE
		BEGIN
			SET @Query = 'SELECT @GUIDOut = AccountGUID FROM  [' + @DataBaseName + '].[dbo].[cu000] WHERE GUID = ''' + CONVERT(NVARCHAR(38), @Custmer) + '''';
			EXEC sp_executesql @Query, N'@GUIDOut  UNIQUEIDENTIFIER OUTPUT', @GUIDOut=@CustmerAccountGUID OUTPUT;
		END
		
		INSERT INTO #CustomerGuidTable SELECT @CustmerAccountGUID;
	FETCH NEXT FROM AllDatabases INTO  @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	END
	CLOSE      AllDatabases;
	DEALLOCATE AllDatabases;
	DECLARE @HasDifferentGuid INT
	IF ( SELECT COUNT(*) FROM #CustomerGuidTable ) = (SELECT COUNT(GUID) FROM #CustomerGuidTable where GUID =  @CurrCutAccGuid OR GUID =0x0)
	BEGIN 
	set @HasDifferentGuid = 0
	END
	ELSE 
	BEGIN
	set @HasDifferentGuid = 1
	END
	SELECT @HasDifferentGuid AS HasDifferentGuid
############################################################################################
CREATE PROCEDURE prcBillDiscAndExtraDetCPSPerYear
 @CurrGUID				UNIQUEIDENTIFIER,
 @Lang					INT
AS  
BEGIN
	SET NOCOUNT ON;
		INSERT INTO #DiscAndExtraDetailsResult
		SELECT 	
		di2.ParentGUID
		,di2.AccountGUID
		, [ac].[acCode] +'-' +  CASE @Lang WHEN 0 THEN ac.acName
				  ELSE ac.acLatinName END
		,dbo.[fnCurrency_fix]([di2].[Discount], bu.CurrencyGUID, bu.CurrencyVal, @CurrGUID, bill.Date)
		,dbo.[fnCurrency_fix]([di2].[Extra], bu.CurrencyGUID, bu.CurrencyVal, @CurrGUID, bill.Date)

		FROM ([di000] AS [di2]  
		INNER JOIN (SELECT DISTINCT [GUID],Date FROM  [#Result] 	WHERE RecType = 'B' ) AS bill ON [bill].[GUID] = [di2].[ParentGuid])
		INNER JOIN bu000 bu on bu.GUID = bill.Guid
		INNER JOIN [vwAc] AS [ac] ON [ac].[acGuid] = [di2].[AccountGuid] 
END
############################################################################################
#END
