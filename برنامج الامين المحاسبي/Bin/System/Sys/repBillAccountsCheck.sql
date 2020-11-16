#################################################################
CREATE PROC repBillAccountsCheck
	@SrcGuid			UNIQUEIDENTIFIER,
	@GroupGuid			UNIQUEIDENTIFIER, 
	@CostGuid			UNIQUEIDENTIFIER, 
	@AccGuid			UNIQUEIDENTIFIER, 
	@FromDate			DATE,   
	@ToDate				DATE,   
	@PriceType			INT, 
	@ComparisonType		INT,
	@IgnoreDiscount		BIT,
	@IgnoreExtra		BIT,
	@IgnoreBonus		BIT,
	@ShowMatching		BIT
AS
	/*
		@PriceType
			0x2		Cost
			0x8000	Outbalance avg price

		@ComparisonType
			0		Bill cost
			1		Bill value
			2		Bonus cost
			3		Discount value
			4		Extra value
	*/

	SET NOCOUNT ON; 
	
	CREATE TABLE #tmp (tmpv FLOAT, BillGuid	UNIQUEIDENTIFIER,BillName NVARCHAR(250) COLLATE ARABIC_CI_AI, BillDate DATETIME, AccValue FLOAT);

	CREATE TABLE #SecViol (Type INT, Cnt INT);  
	DECLARE @mt TABLE (Guid UNIQUEIDENTIFIER, Security INT); 
	INSERT INTO  @mt EXEC prcGetMatsList 0x, @GroupGuid; 
	
	DECLARE @co TABLE (Guid UNIQUEIDENTIFIER, Security INT); 
	INSERT INTO  @co EXEC prcGetCostsList @CostGuid; 

	IF @CostGuid = 0x   
		INSERT INTO @co SELECT 0x, 1; 
		
	CREATE TABLE #ac (acGUID UNIQUEIDENTIFIER, acSecurity INT);

	WITH C AS
	(
		SELECT GUID, ParentGUID, Security
		FROM ac000 
		WHERE GUID = @AccGuid
		
		UNION ALL
		
		SELECT A.GUID, A.ParentGUID, A.Security
		FROM C JOIN vtAc A ON A.ParentGUID = C.Guid
	)
	INSERT INTO #ac(acGUID, acSecurity)
	SELECT Guid, Security FROM C;
	
	EXEC prcCheckSecurity @result = '#ac';

	CREATE TABLE #Result 
	(   
		BillGuid		UNIQUEIDENTIFIER, 
		BillName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		BillDate		DATETIME, 
		Qty				FLOAT, 
		Price			FLOAT,   
		Value			FLOAT,
		AccValue		FLOAT, 
		ItemGuid		UNIQUEIDENTIFIER, 
		MatGuid			UNIQUEIDENTIFIER, 
		CostGuid		UNIQUEIDENTIFIER, 
		MatSecurity		TINYINT,
		CostSecurity	TINYINT
	);
	 
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();

	INSERT INTO #Result
	SELECT
		I.buGUID,
		CASE @Lang WHEN 0 THEN I.buFormatedNumber ELSE I.buLatinFormatedNumber END,
		I.buDate,
		CASE @ComparisonType
			WHEN 0 THEN I.biQty + (CASE @IgnoreBonus WHEN 1 THEN I.biBonusQnt ELSE 0 END)
			WHEN 1 THEN I.biQty
			WHEN 2 THEN I.biBonusQnt
			ELSE 0
		END,
		CASE 
			WHEN @PriceType = 0x8000 AND (@ComparisonType = 0 OR @ComparisonType = 2) THEN
				dbo.fnGetOutbalanceAveragePrice(I.biMatPtr, I.buDate)
			ELSE 0
		END,
		CASE @ComparisonType
			WHEN 1 THEN I.biUnitPrice * I.biQty + 
				CASE @IgnoreExtra	 WHEN 0 THEN I.biUnitExtra * I.biQty  ELSE 0 END -
				CASE @IgnoreDiscount WHEN 0 THEN I.biUnitDiscount * I.biQty ELSE 0 END 
			WHEN 3 THEN I.biUnitDiscount * I.biQty
			WHEN 4 THEN I.biUnitExtra * I.biQty
			ELSE 0
		END,
		E.Value,
		I.biGUID,
		I.biMatPtr,
		I.biCostPtr,
		M.Security,
		C.Security
	FROM
		vwExtended_bi I JOIN fnGetBillsTypesList(@SrcGuid, dbo.fnGetCurrentUserGUID()) S ON I.buType = S.GUID
		JOIN @mt M ON M.Guid = I.biMatPtr
		JOIN @co C ON C.Guid = I.biCostPtr
		OUTER APPLY
		(
			SELECT EN.AccountGUID, ABS(SUM(EN.Debit - EN.Credit)) AS Value
			FROM 
				er000 ER JOIN ce000 CE ON CE.GUID = ER.EntryGUID 
				JOIN en000 EN ON EN.ParentGUID = CE.GUID
			WHERE
				ER.ParentGUID = I.buGUID 
				AND EN.AccountGUID IN (SELECT acGUID FROM #ac) 
				AND (@CostGuid = 0x OR @CostGuid = EN.CostGUID)
			GROUP BY EN.AccountGUID
		) E
		Where I.buDate >= @FromDate AND I.buDate <= @ToDate ;

	EXEC prcCheckSecurity;

	IF @ComparisonType = 0 OR @ComparisonType = 2
	BEGIN
		IF @PriceType = 0x2
			UPDATE R
			SET 
				Price = C.Cost,
				Value = C.Cost * R.Qty
			FROM #Result R JOIN dbo.fnGetBillMaterialsCost(0x, @GroupGuid, 0x, @ToDate) C ON R.ItemGuid = C.BiGuid;
		ELSE
			UPDATE #Result SET Value = Price * Qty;
	END

	DECLARE @PriceRound INT
    SELECT @PriceRound = CAST([Value] AS INT) from op000 where Name = 'AmnCfg_PricePrec'
	IF @PriceRound IS NULL 
		SET @PriceRound = 2
	SELECT
		BillGuid AS Guid,
		MIN(BillName) AS Name,
		MIN(BillDate) AS Date,
		ISNULL(SUM(Value), 0) AS Value,
		ISNULL(MIN(AccValue), 0) AS AccountValue
	FROM #Result
	GROUP BY BillGuid
	HAVING @ShowMatching = 1 OR ROUND(ISNULL(SUM(Value), 0), @PriceRound) <> ROUND(ISNULL(MIN(AccValue), 0), @PriceRound)
	ORDER BY Date, Name
	
	SELECT * FROM #SecViol;
#################################################################
#END