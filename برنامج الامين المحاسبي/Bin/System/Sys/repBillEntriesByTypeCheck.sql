#################################################################
CREATE PROCEDURE repBillEntriesByTypeCheck
	@SrcGuid			UNIQUEIDENTIFIER,   
	@MatGuid			UNIQUEIDENTIFIER, 
	@GroupGuid			UNIQUEIDENTIFIER, 
	@StoreGuid			UNIQUEIDENTIFIER,
	@CostGuid			UNIQUEIDENTIFIER,
	@FromDate			DATETIME,
	@ToDate			DATETIME,
	@PriceType			INT, 
	@CompareBy			INT, 
	@ShowMatching		BIT, 
	@ShowZeroVlues		BIT
AS 
	SET NOCOUNT ON; 
	-- „‰⁄ „⁄«Ì‰… «· ﬁ—Ì— ›Ì Õ«· ⁄œ„  ›⁄Ì· ŒÌ«— «·€«¡ «·ﬁÌœ «·„Œ ’— ›Ì Ã„Ì⁄ √‰„«ÿ «·›Ê« Ì—
	DECLARE @IsPrefEntryEnabled INT
	SELECT @IsPrefEntryEnabled =  value FROM op000 WHERE Name = 'AmnCfg_CancelBillsPrefEntryCheck'
	IF ISNULL(@IsPrefEntryEnabled, 1) = 0
		RETURN

	CREATE TABLE #Res
	(
		BillTypeID		INT,
		BillTypeGuid	UNIQUEIDENTIFIER,
		BillTypeName	NVARCHAR(100) COLLATE ARABIC_CI_AI, 
		BillGuid		UNIQUEIDENTIFIER,
		BiGuid			UNIQUEIDENTIFIER,
		MatGuid			UNIQUEIDENTIFIER,
		BillName		NVARCHAR(100),
		BillDate		DATETIME,
		MatName			NVARCHAR(100) COLLATE ARABIC_CI_AI, 
		MatCode			NVARCHAR(100) COLLATE ARABIC_CI_AI, 
		GroupName		NVARCHAR(100) COLLATE ARABIC_CI_AI, 
		Quantity		FLOAT,
		Unit			NVARCHAR(100) COLLATE ARABIC_CI_AI, 
		CurrencyName	NVARCHAR(100) COLLATE ARABIC_CI_AI, 
		CurrencyVal		FLOAT,
		Price			FLOAT,
		ComputedValue	FLOAT,
		EntryValue		FLOAT,
		EntryPrice		FLOAT,
		Variance		FLOAT,
		AccName			NVARCHAR(100) COLLATE ARABIC_CI_AI, 
		ContraAccName	NVARCHAR(100) COLLATE ARABIC_CI_AI
	)
	EXECUTE repBillEntriesMoveByPrice2 @SrcGuid, @FromDate, @ToDate, @MatGuid, @GroupGuid, @StoreGuid, @CostGuid, @PriceType, @CompareBy, @ShowMatching, @ShowZeroVlues, 1, 1
	

	UPDATE #Res 
	SET 
		BillTypeID = -1,
		BillTypeGuid = 0x0, 
		BillTypeName = ''

	--master result
	SELECT DISTINCT BillGuid, BillName, BillDate, R.CurrencyName, R.CurrencyVal
	FROM #Res R
	ORDER BY BillDate

	--details result
	SELECT	BillGuid,
			R.AccName, 
			R.BiGuid, 
			R.ComputedValue, 
			R.ContraAccName, 
			R.EntryPrice, 
			R.EntryValue, 
			R.GroupName, 
			R.MatCode AS MtCode, 
			R.MatName AS MtName,
			R.MatGuid AS MtGuid, 
			R.Price, 
			R.Quantity, 
			R.Unit, 
			R.Variance
	FROM #Res R
	ORDER BY MatName
#################################################################
CREATE PROCEDURE repBillEntriesMoveByPrice2
	@SrcGuid			UNIQUEIDENTIFIER,    
	@FromDate			DATETIME,    
	@ToDate				DATETIME,    
	@Material			UNIQUEIDENTIFIER,  
	@Group				UNIQUEIDENTIFIER,  
	@Store				UNIQUEIDENTIFIER,    
	@Cost				UNIQUEIDENTIFIER,  
	@PriceType			INT,  
	@CompareBy			INT,  
	@ShowMatching		BIT,  
	@ShowZeroValues		BIT,  
	@ShowEntryPrice		BIT,
	@UseBillCurrency	BIT
AS  
	SET NOCOUNT ON; 
	CREATE TABLE #SecViol (Type INT, Cnt INT);  
	CREATE TABLE #mt (Guid UNIQUEIDENTIFIER, Security INT); 
	INSERT INTO  #mt EXEC prcGetMatsList @Material, @Group; 
	
	CREATE TABLE #st (Guid UNIQUEIDENTIFIER, Security INT); 
	INSERT INTO  #st EXEC prcGetStoresList @Store; 
	
	CREATE TABLE #co (Guid UNIQUEIDENTIFIER, Security INT); 
	INSERT INTO  #co EXEC prcGetCostsList @Cost; 
	IF @Cost = 0x   
		INSERT INTO #co SELECT 0x, 1;  
	CREATE TABLE #Result 
	(   
		BillGuid		UNIQUEIDENTIFIER, 
		TypeGuid		UNIQUEIDENTIFIER, 
		BiGuid			UNIQUEIDENTIFIER,
		MatGuid			UNIQUEIDENTIFIER, 
		ItemGuid		UNIQUEIDENTIFIER, 
		CurrencyGuid	UNIQUEIDENTIFIER, 
		BillDate		DATETIME, 
		BillName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		MatName			NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		UnitName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		Unit			FLOAT, 
		CurrencyVal		FLOAT, 
		Price			FLOAT,   
		Qty				FLOAT DEFAULT 0, 
		EntryValue		FLOAT, 
		MatAccGuid		UNIQUEIDENTIFIER, 
		CostAccGuid		UNIQUEIDENTIFIER, 
		BonusAccGuid	UNIQUEIDENTIFIER,
		ContraAccount	UNIQUEIDENTIFIER,
		StoreGuid		UNIQUEIDENTIFIER, 
		CostGuid		UNIQUEIDENTIFIER, 
		MatSecurity		TINYINT,
		StoreSecurity	TINYINT,
		CostSecurity	TINYINT,
		ConsideredGiftsOfSales BIT DEFAULT 0 
	);

	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	INSERT INTO #Result 
	(
		BillGuid,
		TypeGuid, 
		BiGuid,
		MatGuid,
		ItemGuid,
		CurrencyGuid,
		BillDate,
		BillName, 
		MatName, 
		UnitName,
		Unit,
		CurrencyVal, 
		Price,		
		EntryValue, 
		MatAccGuid,
		CostAccGuid,
		BonusAccGuid,
		ContraAccount,
		StoreGuid,
		CostGuid,
		MatSecurity,
		StoreSecurity,
		CostSecurity
	)
	SELECT
		I.buGUID, 
		I.buType, 
		I.BiGuid, 
		I.biMatPtr, 
		I.biGUID,
		I.buCurrencyPtr,
		I.buDate,
		CASE @Lang WHEN 0 THEN I.buFormatedNumber ELSE (CASE I.buLatinFormatedNumber WHEN '' THEN I.buFormatedNumber ELSE I.buLatinFormatedNumber END) END, 
		CASE @Lang WHEN 0 THEN I.mtName ELSE (CASE I.mtLatinName WHEN '' THEN I.mtName ELSE I.mtLatinName END) END, 
		CASE I.biUnity WHEN 1 THEN I.mtUnity WHEN 2 THEN I.mtUnit2 WHEN 3 THEN I.mtUnit3 END,
		I.biUnity,
		I.buCurrencyVal,
		CASE @PriceType  
			WHEN 0x4    THEN CASE I.biUnity WHEN 1 THEN I.mtWhole     WHEN 2 THEN I.mtWhole2     WHEN 3 THEN I.mtWhole3 END
			WHEN 0x8    THEN CASE I.biUnity WHEN 1 THEN I.mtHalf      WHEN 2 THEN I.mtHalf2      WHEN 3 THEN I.mtHalf3 END
			WHEN 0x10   THEN CASE I.biUnity WHEN 1 THEN I.mtExport    WHEN 2 THEN I.mtExport2    WHEN 3 THEN I.mtExport3 END
			WHEN 0x20   THEN CASE I.biUnity WHEN 1 THEN I.mtVendor    WHEN 2 THEN I.mtVendor2    WHEN 3 THEN I.mtVendor3 END
			WHEN 0x40   THEN CASE I.biUnity WHEN 1 THEN I.mtRetail    WHEN 2 THEN I.mtRetail2    WHEN 3 THEN I.mtRetail3 END
			WHEN 0x80   THEN CASE I.biUnity WHEN 1 THEN I.mtEndUser	  WHEN 2 THEN I.mtEndUser2   WHEN 3 THEN I.mtEndUser3 END
			WHEN 0x200  THEN CASE I.biUnity WHEN 1 THEN I.mtLastPrice WHEN 2 THEN I.mtLastPrice2 WHEN 3 THEN I.mtLastPrice3 END
			WHEN 0x8000 THEN dbo.fnGetOutbalanceAveragePrice(I.biMatPtr, I.buDate)
		END,
		0, 
		B.MatAccGUID,
		B.CostAccGUID,
		B.BonusAccGUID, 
		0x0,
		T.Guid,
		C.Guid,
		M.Security,
		T.Security,
		C.Security 
	FROM    
		vwExtended_bi I --JOIN fnGetBillsTypesList(@SrcGuid, dbo.fnGetCurrentUserGUID()) S ON I.[buType] = S.[GUID]
		JOIN bu000 B ON B.[GUID] = I.[buGUID] 
		JOIN #mt M ON I.[biMatPtr] = M.[Guid] 
		JOIN #st T ON I.[biStorePtr] = T.[Guid]   
		JOIN #co C ON I.[biCostPtr] = C.[Guid]   
	WHERE    
		I.buDate BETWEEN @FromDate AND @ToDate
		AND EXISTS (SELECT 1 FROM fnGetBillsTypesList(@SrcGuid, dbo.fnGetCurrentUserGUID()) AS S WHERE S.[GUID] = I.[buType]);

	
	UPDATE R
	SET ConsideredGiftsOfSales = bt.ConsideredGiftsOfSales			
	FROM #Result R 
	INNER JOIN bt000 bt ON R.[TypeGuid] = bt.[Guid]					
	UPDATE R
	SET  QTY = CASE I.biUnity 
			WHEN 1 THEN (CASE WHEN @CompareBy = 2 THEN I.biBonusQnt ELSE CASE R.ConsideredGiftsOfSales WHEN 1 THEN (I.biQty+I.biBonusQnt) ELSE I.biQty END END) 
			WHEN 2 THEN (CASE WHEN @CompareBy = 2 THEN I.biBonusQnt / I.mtUnit2Fact ELSE CASE R.ConsideredGiftsOfSales WHEN 1 THEN (I.biQty+I.biBonusQnt) / I.mtUnit2Fact ELSE I.biQty/ I.mtUnit2Fact END END) 
			WHEN 3 THEN (CASE WHEN @CompareBy = 2 THEN I.biBonusQnt / I.mtUnit3Fact ELSE CASE R.ConsideredGiftsOfSales WHEN 1 THEN (I.biQty+I.biBonusQnt)/ I.mtUnit3Fact ELSE I.biQty/ I.mtUnit3Fact END END) 
			END 						
	FROM vwExtended_bi I INNER JOIN #Result R 
	ON I.[biGUID] = R.[BiGuid]
	
	IF @PriceType = 0x2 
	BEGIN 
		UPDATE R 
		SET Price =  
			CASE Unit 
				WHEN 1 THEN C.Cost 
				WHEN 2 THEN C.Cost * (CASE M.Unit2Fact WHEN 0 THEN 1 ELSE M.Unit2Fact END) 
				WHEN 3 THEN C.Cost * (CASE M.Unit3Fact WHEN 0 THEN 1 ELSE M.Unit3Fact END) 
			END 
		FROM  
			#Result R JOIN dbo.fnGetBillMaterialsCost(@Material, @Group, 0x0, @ToDate) C ON R.ItemGuid = C.BiGuid  
			JOIN mt000 M ON R.MatGuid = M.GUID 
	END
	UPDATE R 
	SET 
		R.MatAccGuid = CASE WHEN R.MatAccGUID = 0x0 THEN A.MatAccGUID ELSE R.MatAccGuid END, 
		R.CostAccGuid = CASE WHEN R.CostAccGuid = 0x0 THEN A.CostAccGUID ELSE R.CostAccGuid END, 
		R.BonusAccGuid = CASE WHEN R.BonusAccGuid = 0x0 THEN A.BonusAccGUID ELSE R.BonusAccGuid END 
	FROM 
		#Result R JOIN ma000 A ON R.TypeGuid = A.BillTypeGUID AND A.ObjGUID = dbo.fnGetCurrentUserGUID();
	UPDATE R 
	SET 
		R.MatAccGuid = CASE WHEN R.MatAccGUID = 0x0 THEN A.MatAccGUID ELSE R.MatAccGuid END, 
		R.CostAccGuid = CASE WHEN R.CostAccGuid = 0x0 THEN A.CostAccGUID ELSE R.CostAccGuid END, 
		R.BonusAccGuid = CASE WHEN R.BonusAccGuid = 0x0 THEN A.BonusAccGUID ELSE R.BonusAccGuid END 
	FROM 
		#Result R JOIN ma000 A ON R.TypeGuid = A.BillTypeGUID AND A.ObjGUID = R.MatGuid;
	UPDATE R 
	SET 
		R.MatAccGuid = CASE WHEN R.MatAccGUID = 0x0 THEN T.DefBillAccGUID ELSE R.MatAccGuid END, 
		R.CostAccGuid = CASE WHEN R.CostAccGuid = 0x0 THEN T.DefCostAccGUID ELSE R.CostAccGuid END, 
		R.BonusAccGuid = CASE WHEN R.BonusAccGuid = 0x0 THEN T.DefBonusAccGUID ELSE R.BonusAccGuid END 
	FROM 
		#Result R JOIN bt000 T ON R.TypeGuid = T.GUID; 
	EXEC prcCheckSecurity;
	WITH E AS 
	( 
		SELECT  
			ER.ParentGUID, EN.AccountGUID, EN.ContraAccGUID, EN.Notes, EN.BiGUID, EN.Debit, EN.Credit 
		FROM  
			er000 ER JOIN ce000 CE ON CE.GUID = ER.EntryGUID 
			JOIN en000 EN ON EN.ParentGUID = CE.GUID 
			JOIN ac000 AC ON AC.GUID = EN.AccountGUID 
	) 
	UPDATE R 
		SET EntryValue = ISNULL( 
			( 
				SELECT ISNULL(SUM(E.Debit + E.Credit), 0)  
				FROM E  
				WHERE  
					E.ParentGUID = R.BillGuid AND  
					E.AccountGUID =  
						CASE @CompareBy 
							WHEN 0 THEN R.MatAccGuid 
							WHEN 1 THEN R.CostAccGuid  
							WHEN 2 THEN R.BonusAccGuid 
						END AND  
					R.BiGuid = E.BiGUID
						--CASE  
						--	WHEN @CompareBy = 2 THEN  
						--		SUBSTRING(E.NOTES, 0, CHARINDEX('(', E.Notes)) COLLATE Arabic_CI_AI  
						--	ELSE  
						--		E.NOTES COLLATE Arabic_CI_AI  
						--END 
			), 0), 
			ContraAccount =  
			( 
				SELECT TOP 1 E.ContraAccGUID
				FROM E  
				WHERE  
					E.ParentGUID = R.BillGuid AND  
					E.AccountGUID =  
						CASE @CompareBy 
							WHEN 0 THEN R.MatAccGuid 
							WHEN 1 THEN R.CostAccGuid  
							WHEN 2 THEN R.BonusAccGuid 
						END AND  
					R.BiGuid = E.BiGUID
						--CASE  
						--	WHEN @CompareBy = 2 THEN  
						--		SUBSTRING(E.NOTES, 0, CHARINDEX('(', E.Notes)) COLLATE Arabic_CI_AI  
						--	ELSE  
						--		E.NOTES COLLATE Arabic_CI_AI  
						--END 
			) 
	FROM #Result R;
--return 	
	IF @ShowZeroValues = 0 
		DELETE FROM #Result WHERE Price * Qty = 0; 
		DECLARE @PriceRound INT
        SELECT @PriceRound = CAST([Value] AS INT) from op000 where Name = 'AmnCfg_PricePrec'
	IF @ShowMatching = 0 
		DELETE FROM #Result WHERE (ROUND(Price * Qty, @PriceRound) <> 0) AND (ROUND(Price * Qty - EntryValue, @PriceRound) = 0);
	IF @UseBillCurrency = 1
		UPDATE R
		SET R.Price /= R.CurrencyVal, R.EntryValue /= R.CurrencyVal
		FROM #Result R;
	insert into #Res
	SELECT  
		bt.BillType,
		bt.Guid,
		bt.Name,
		R.BillGuid, 
		R.BiGuid, 
		R.MatGuid, 
		MIN(R.BillName) AS BillName,  
		MIN(R.BillDate) AS BillDate,  
		MIN(R.MatName) AS MatName,  
		MIN(mtGr.mtCode) AS MatCode,
		MIN(mtGr.grName) AS GroupName,
		SUM(R.Qty) AS Quantity, 
		MIN(R.UnitName) AS Unit,
		MIN(CASE @Lang WHEN 0 THEN M.Name ELSE (CASE M.LatinName WHEN '' THEN M.Name ELSE M.LatinName END) END) AS Currency, 
		MIN(R.CurrencyVal) AS CurrencyVal,  
		MIN(R.Price) AS Price,  
		MIN(R.Price) * SUM(R.Qty) AS ComputedValue,  
		MIN(R.EntryValue) AS EntryValue,  
		CASE WHEN @ShowEntryPrice = 1 THEN MIN(R.EntryValue) / (CASE SUM(R.Qty) WHEN 0 THEN 1 ELSE SUM(R.Qty) END) ELSE 0 END AS EntryPrice, 
		MIN(R.Price) * SUM(R.Qty) - MIN(R.EntryValue) AS Variance, 
		MIN(A.Name) AS Account, 
		MIN(CA.Name)AS ContraAccount 
	FROM  
		#Result R
		INNER JOIN bt000 as bt on bt.Guid = R.TypeGuid
		INNER JOIN vwMtGr as mtGr on mtGr.mtGuid = R.MatGuid
		LEFT JOIN ac000 A ON A.GUID =  
			CASE @CompareBy 
				WHEN 0 THEN R.MatAccGuid 
				WHEN 1 THEN R.CostAccGuid  
				WHEN 2 THEN R.BonusAccGuid 
			END 
		LEFT JOIN ac000 CA ON CA.GUID = R.ContraAccount
		LEFT JOIN my000 M ON M.GUID = R.CurrencyGuid 
	WHERE 
		@CompareBy <> 2 OR R.Qty > 0 
	GROUP BY 
		bt.BillType,
		bt.Guid,
		bt.Name,
		R.BillGuid, 
		R.BiGuid,
		R.MatGuid
	ORDER BY 
		BillDate, BillName; 
#################################################################
CREATE PROCEDURE prcCheckNegativeMat
	@StartDate DATE,
	@EndDate DATE
AS
	SET NOCOUNT ON

	IF EXISTS (	SELECT biMatPtr, SUM((biQty + biBonusQnt) * buDirection) FROM vwbubi
	INNER JOIN mt000 AS mt on mt.GUID = biMatPtr
		WHERE buDate BETWEEN @StartDate AND @EndDate  AND buIsPosted = 1 AND mt.Type <> 1 
		GROUP BY biMatPtr  HAVING SUM((biQty + biBonusQnt) * buDirection) < 0 )
	BEGIN
		SELECT 1
	END	

#################################################################
#END
