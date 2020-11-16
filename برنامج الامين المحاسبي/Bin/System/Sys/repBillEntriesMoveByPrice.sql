#####################################################################
CREATE PROCEDURE repBillEntriesMoveByPrice
	@SrcGuid			UNIQUEIDENTIFIER,    
	@FromDate			DATETIME,    
	@ToDate				DATETIME,    
	@Material			UNIQUEIDENTIFIER,  
	@Group				UNIQUEIDENTIFIER,  
	@Store				UNIQUEIDENTIFIER,    
	@Cost				UNIQUEIDENTIFIER,  
	@PriceType			INT,  
	@CompareBy			INT,  
	@ShowMode			INT,  
	@ShowMatching		BIT,  
	@ShowNoneMatching	BIT,  
	@ShowZeroValues		BIT,  
	@ShowAccount		BIT,  
	@ShowContraAccount	BIT,  
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
		MatGuid			UNIQUEIDENTIFIER, 
		ItemGuid		UNIQUEIDENTIFIER, 
		CurrencyGuid	UNIQUEIDENTIFIER, 
		BillDate		DATETIME, 
		BillName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		MatName			NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		UnitName		NVARCHAR(250),
		Unit			FLOAT,
		CurrencyVal		FLOAT, 
		Price			FLOAT,   
		Qty				FLOAT, 
		EntryValue		FLOAT, 
		MatAccGuid		UNIQUEIDENTIFIER, 
		CostAccGuid		UNIQUEIDENTIFIER, 
		BonusAccGuid	UNIQUEIDENTIFIER, 
		ContraAccount	UNIQUEIDENTIFIER,
		StoreGuid		UNIQUEIDENTIFIER, 
		CostGuid		UNIQUEIDENTIFIER, 
		MatSecurity		TINYINT,
		StoreSecurity	TINYINT,
		CostSecurity	TINYINT
	);
	 
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	INSERT INTO #Result 
	SELECT 
		I.buGUID, 
		I.buType, 
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
		CASE I.biUnity 
			WHEN 1 THEN (CASE WHEN @CompareBy = 2 THEN I.biBonusQnt ELSE I.biQty END) 
			WHEN 2 THEN (CASE WHEN @CompareBy = 2 THEN I.biBonusQnt / I.mtUnit2Fact ELSE I.biQty / I.mtUnit2Fact END) 
			WHEN 3 THEN (CASE WHEN @CompareBy = 2 THEN I.biBonusQnt / I.mtUnit3Fact ELSE I.biQty / I.mtUnit3Fact END) 
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
		vwExtended_bi I JOIN fnGetBillsTypesList(@SrcGuid, dbo.fnGetCurrentUserGUID()) S ON I.buType = S.GUID
		JOIN bu000 B ON B.GUID = I.buGUID 
		JOIN #mt M ON I.biMatPtr = M.Guid 
		JOIN #st T ON I.biStorePtr = T.Guid   
		JOIN #co C ON I.biCostPtr = C.Guid   
	WHERE    
		I.buDate BETWEEN @FromDate AND @ToDate;
	
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
			#Result R JOIN dbo.fnGetBillMaterialsCost(@Material, @Group) C ON R.ItemGuid = C.BiGuid  
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
		R.BonusAccGuid = CASE WHEN R.BonusAccGuid = 0x0 THEN (SELECT TOP 1 bt000.DefBonusAccGUID from #Result INNER JOIN bt000 ON #Result.TypeGuid = bt000.GUID) ELSE R.BonusAccGuid END 
	FROM 
		#Result R JOIN bt000 T ON R.TypeGuid = T.GUID
	 
	EXEC prcCheckSecurity; 
	WITH E AS 
	( 
		SELECT  
			ER.ParentGUID, EN.AccountGUID, EN.ContraAccGUID, EN.Notes, EN.Debit, EN.Credit , vwB.btIsInput AS IsInput
		FROM  
			er000 ER JOIN ce000 CE ON CE.GUID = ER.EntryGUID 
			JOIN en000 EN ON EN.ParentGUID = CE.GUID 
			JOIN ac000 AC ON AC.GUID = EN.AccountGUID 
			JOIN vwBuBi vwB ON ER.ParentGUID = vwB.buGUID
	) 
	
	UPDATE R 
		SET EntryValue = ISNULL( 
			( 
				SELECT ISNULL(E.Debit + E.Credit, 0)  
				FROM E  
				WHERE  
					E.ParentGUID = R.BillGuid AND  
					E.AccountGUID =  
						CASE @CompareBy 
							WHEN 0 THEN R.MatAccGuid 
							WHEN 1 THEN R.CostAccGuid  
							WHEN 2 THEN R.BonusAccGuid 
						END AND  
					R.MatName =  
						CASE  
							WHEN @CompareBy = 2 THEN  
								SUBSTRING(E.NOTES, 0, CHARINDEX('(', E.Notes)) COLLATE Arabic_CI_AI  
							ELSE  
								E.NOTES COLLATE Arabic_CI_AI  
						END 
						AND		
						(
							@CompareBy <> 2
							 OR 
							(E.IsInput = 0 AND E.Debit > 0) OR (E.IsInput = 1 AND E.Credit > 0 )

								-- *The previous  query was added to fix BUG #58596
								--*This query solved the issue of assigning multiple values to a single value
								-- in case Account = ContraAccount
								-- *Use basic boolean algebra to understand how the bug was solved
						)
			), 0), 
			ContraAccount =  
			( 
				SELECT E.ContraAccGUID  
				FROM E  
				WHERE  
					E.ParentGUID = R.BillGuid AND  
					E.AccountGUID =  
						CASE @CompareBy 
							WHEN 0 THEN R.MatAccGuid 
							WHEN 1 THEN R.CostAccGuid  
							WHEN 2 THEN R.BonusAccGuid 
						END AND  
					R.MatName =  
						CASE  
							WHEN @CompareBy = 2 THEN  
								SUBSTRING(E.NOTES, 0, CHARINDEX('(', E.Notes)) COLLATE Arabic_CI_AI  
							ELSE  
								E.NOTES COLLATE Arabic_CI_AI  
						END 
							AND 
						(
							@CompareBy <> 2
							 OR 
							(E.IsInput = 0 AND E.Debit > 0) OR (E.IsInput = 1 AND E.Credit > 0 )
						)
			) 
	FROM #Result R; 
	
	IF @ShowZeroValues = 0 
		DELETE FROM #Result WHERE Price * Qty = 0; 
	
	IF @ShowMatching = 0 
		DELETE FROM #Result WHERE (Price * Qty <> 0) AND (Price * Qty - EntryValue = 0); 
	
	IF @ShowNoneMatching = 0 
		DELETE FROM #Result WHERE (Price * Qty <> 0) AND (Price * Qty - EntryValue <> 0);
		 
	IF @UseBillCurrency = 1
		UPDATE R
		SET R.Price /= R.CurrencyVal, R.EntryValue /= R.CurrencyVal
		FROM #Result R;
		
	IF @ShowMode = 0 
		SELECT  
			R.BillGuid, 
			R.MatGuid, 
			MIN(R.BillName) AS BillName,  
			MIN(R.BillDate) AS BillDate,  
			MIN(R.MatName) AS MatName,  
			SUM(R.Qty) AS Quantity, 
			MIN(R.UnitName) AS Unit,
			MIN(CASE @Lang WHEN 0 THEN M.Name ELSE (CASE M.LatinName WHEN '' THEN M.Name ELSE M.LatinName END) END) AS Currency, 
			MIN(R.CurrencyVal) AS CurrencyVal,  
			MIN(R.Price) AS Price,  
			MIN(R.Price) * SUM(R.Qty) AS ComputedValue,  
			MIN(R.EntryValue) AS EntryValue,  
			CASE WHEN @ShowEntryPrice = 1 THEN MIN(R.EntryValue) / SUM(R.Qty) ELSE 0 END AS EntryPrice, 
			MIN(R.Price) * SUM(R.Qty) - MIN(R.EntryValue) AS Variance, 
			CASE 
			WHEN @ShowAccount = 1
			THEN	
				CASE 
					WHEN @CompareBy = 1
					THEN 
						CASE 
							WHEN ((SELECT bContInv from bt000 WHERE BillType = 1) = 1)
							THEN MIN(A.Name) ELSE NULL
						END
					ELSE MIN(A.Name) 
				END
			ELSE '' 
			END AS Account,
			CASE WHEN @ShowContraAccount = 1 THEN MIN(CA.Name) ELSE '' END AS ContraAccount 
		FROM  
			#Result R
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
			R.BillGuid, 
			R.MatGuid 
		ORDER BY 
			BillDate, BillName; 
	ELSE 
		SELECT 
			R.BillGuid, 
			MIN(R.BillName) AS BillName,  
			MIN(R.BillDate) AS BillDate,  
			MIN(CASE @Lang WHEN 0 THEN M.Name ELSE (CASE M.LatinName WHEN '' THEN M.Name ELSE M.LatinName END) END) AS Currency, 
			MIN(R.CurrencyVal) AS CurrencyVal,  
			SUM(R.Price * R.Qty) AS ComputedValue, 
			SUM(R.EntryValue) AS EntryValue, 
			SUM(R.Price * R.Qty) - SUM(EntryValue) AS Variance 
		FROM #Result R LEFT JOIN my000 M ON M.GUID = R.CurrencyGuid
		WHERE @CompareBy <> 2 OR Qty > 0 
		GROUP BY BillGuid 
		ORDER BY BillDate, BillName; 
				 
	SELECT * FROM #SecViol; 
#####################################################################
#END