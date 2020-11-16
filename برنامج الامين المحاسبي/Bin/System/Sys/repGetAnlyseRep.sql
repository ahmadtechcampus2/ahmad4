##############################################################
CREATE PROCEDURE repGetAnlyseRep
AS
	SELECT 
		GUID AS RgGUID,
		Name AS RgName,
		LatinName AS RgLatinName,
		Number AS RgNumber
	FROM 
		RG000 AS RG
	ORDER BY
		Number
	
	----------------
	SELECT
		ParentGUID AS RgGUID,
		GUID AS ReGUID,
		Name AS ReName,
		LatinName AS ReLatinName,
		Notes AS ReNotes,
		LatinNotes AS ReLatinNotes,
		Number AS ReNumber
	FROM 
		RE000 AS RE --ON RG.GUID = RE.ParentGUID 
	ORDER BY
		ParentGUID,
		Number
	----------------
	SELECT 
		RE.ParentGUID AS RgGuid,
		EI.Number AS EiNumber,
		EI.ParentGUID AS ReGUID,
		EI.GUID AS EiGUID,
		EI.Name AS EiName,
		EI.LatinName AS EiLatinName,
		EI.Type AS EiType,
		EI.SubType AS EiSubType,
		EI.ObjGUID AS EiObjGUID,
		EI.StoreGUID AS EiStoreGUID,
		EI.CostGUID AS EiCostGUID,
		EI.ConstantValue AS EiConstantValue
	FROM 
		EI000 AS EI INNER JOIN RE000 AS RE 
		ON EI.ParentGUID = RE.GUID
	ORDER BY 
		RE.ParentGUID,
		EI.ParentGUID,
		EI.Number
	----------------
	SELECT 
		RE.ParentGUID AS RgGUID,
		EI.ParentGUID AS ReGUID,
		ES.ParentGUID AS EiGUID,
		ES.SrcGUID AS EsSrcGUID
	FROM 
		ES000 AS ES INNER JOIN EI000 AS EI 
		ON ES.ParentGUID = EI.GUID
		INNER JOIN RE000 AS RE 
		ON EI.ParentGUID = RE.GUID
################################################################################
## —’Ìœ Õ”«» √Ê ﬂ· «·Õ”«»«  ÊÌ” Œœ„ ›Ì „Ê·œ «· ﬁ«—Ì—
CREATE PROCEDURE prcGetAccBal
	@AccGUID		UNIQUEIDENTIFIER, --«·Õ”«»
	@CostGUID	UNIQUEIDENTIFIER, --„—ﬂ“ «·ﬂ·›…
	@StartDate	DATETIME,	  -- «—ÌŒ «·»œ«Ì…
	@EndDate	DATETIME,	  -- «—ÌŒ «·‰Â«Ì…
	@Src		UNIQUEIDENTIFIER, --„’«œ— «·”‰œ« 
	@CurGUID		UNIQUEIDENTIFIER, --«·⁄„·…
	@CurVal		FLOAT		  --”⁄— «· ⁄«œ·
AS
	SET NOCOUNT ON
	--------------------------
	DECLARE @Acc TABLE ( GUID UNIQUEIDENTIFIER)
	INSERT INTO @Acc SELECT GUID FROM dbo.fnGetAccountsList( @AccGUID , DEFAULT)
	--------------------------
	DECLARE @Cost TABLE ( GUID UNIQUEIDENTIFIER)
	INSERT INTO @Cost SELECT GUID FROM dbo.fnGetCostsList( @CostGUID)
	IF ISNULL( @CostGUID, 0x0) = 0x0 
		INSERT INTO @Cost VALUES(0x0)
	--------------------------
	SELECT
		ISNULL( SUM( vwEx.enDebit - vwEx.enCredit), 0)AS AccBalance
	FROM
		fnExtended_en_Fixed_Src( @Src, @CurGUID) AS vwEx
		INNER JOIN @Acc AS a ON vwEx.acGUID = a.GUID
		INNER JOIN @Cost AS c ON vwEx.enCostPoint = c.GUID
	WHERE
		vwEx.enDate BETWEEN @StartDate AND @EndDate
##############################################################
CREATE PROCEDURE repGetMatBal
	@StartDate DATETIME,      -- «—ÌŒ «·»œ«Ì…
	@EndDate DATETIME,        -- «—ÌŒ«·‰Â«Ì…
	@MatPtr UNIQUEIDENTIFIER, --«·„«œ…
	@GrpPtr UNIQUEIDENTIFIER, --«·„Ã„Ê⁄…
	@Cost UNIQUEIDENTIFIER,  --„—ﬂ“ «·ﬂ·›…
	@Store UNIQUEIDENTIFIER, --«·„” Êœ⁄
	@Src UNIQUEIDENTIFIER,    --„’«œ— «· ﬁ—Ì—
	@CurGUID UNIQUEIDENTIFIER, --«·⁄„·…
	@CurVal FLOAT,		  --«· ⁄«œ·
	@PriceType INT,       --‰Ê⁄ «·”⁄—
	@PricePolicy INT = 121
AS
	SET NOCOUNT ON
	CREATE TABLE #SecViol( Type INT, Cnt INTEGER) 
	-------------
	CREATE TABLE #MatTbl( MatGUID UNIQUEIDENTIFIER, mtSecurity INT)   
	INSERT INTO #MatTbl EXEC prcGetMatsList  @MatPtr, @GrpPtr
	-------------
	CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER) 
	INSERT INTO #BillsTypesTbl EXEC prcGetBillsTypesList @Src
	-------------
	CREATE TABLE #StoreTbl(	StoreGUID UNIQUEIDENTIFIER, Security INT) 
	INSERT INTO #StoreTbl EXEC prcGetStoresList @Store
	-------------
	CREATE TABLE #CostTbl( CostGUID UNIQUEIDENTIFIER, Security INT) 
	INSERT INTO #CostTbl EXEC prcGetCostsList @Cost
	IF ISNULL( @Cost,0x0) = 0x0
		INSERT INTO #CostTbl VALUES(0x0, 1)
	-------------
	/*
	DECLARE @CostLs TABLE(GUID UNIQUEIDENTIFIER)
	DECLARE @StoreLs TABLE(GUID UNIQUEIDENTIFIER)

	IF ISNULL( @Cost,0x0) = 0x0
		INSERT INTO @CostLs VALUES(0x0)
	INSERT INTO @StoreLs SELECT GUID FROM dbo.fnGetStoresOfStore( @Store)
	*/
	---------------------------------------------------	
	CREATE TABLE #t_Prices 
	( 
		mtNumber 	UNIQUEIDENTIFIER, 
		APrice 		FLOAT 
	) 
	IF @PriceType = 7 AND @PricePolicy = 122 -- LastPrice 
		EXEC prcGetLastPrice @StartDate , @EndDate , @MatPtr, @GrpPtr, @Store, @Cost, -1, @CurGUID, @Src, 0, 0
	ELSE IF @PriceType = 7 AND @PricePolicy = 120 -- MaxPrice
		EXEC prcGetMaxPrice @StartDate , @EndDate , @MatPtr, @GrpPtr, @Store, @Cost, -1, @CurGUID, @CurVal, @Src, 0, 0
	ELSE IF @PriceType = 7 AND @PricePolicy = 121 -- COST And AvgPrice 
		EXEC prcGetAvgPrice @StartDate,	@EndDate, @MatPtr, @GrpPtr, @Store, @Cost, -1, @CurGUID, @CurVal, @Src, 0, 0
	ELSE 
		EXEC prcGetMtPrice @MatPtr, @GrpPtr, -1, @CurGUID, @CurVal, @Src, @PriceType, @PricePolicy, 0, 0
	-----------------------------------------
	CREATE TABLE #t_Qtys 
	( 
		mtNumber 	UNIQUEIDENTIFIER, 
		Qnt 		FLOAT, 
		Qnt2 		FLOAT, 
		Qnt3 		FLOAT, 
		StoreGUID	UNIQUEIDENTIFIER
	) 
	EXEC prcGetQnt @StartDate, @EndDate, @MatPtr, @GrpPtr, @Store, @Cost, -1, 0, @Src, 0
	------------------------------------------
	SELECT
		ISNULL( SUM( isnull( t_Qtys.Qnt, 0)),0) AS SumQty,
		ISNULL( SUM( t_Qtys.Qnt * t_Prices.APrice),0) AS PriceMat
	FROM
		#t_Qtys AS t_Qtys INNER JOIN #t_Prices AS t_Prices
		ON t_Qtys.mtNumber = t_Prices.mtNumber
##############################################################
CREATE PROCEDURE bill_print 
	( 
		@guid UNIQUEIDENTIFIER = 0x0
	) 
	AS	
	SET NOCOUNT ON  
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])  
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2]  
	 
	DECLARE 
		@currencyGuid UNIQUEIDENTIFIER = 0x0
		, @CurrencyVal FLOAT = 0
		, @CurrencyName NVARCHAR(255)
		, @CurrencyPartName NVARCHAR(250)
		, @CurrentLanguage INT = 0
		, @CurrencyPartPrecision nVARCHAR(250)
		, @CurrencyString AS NVARCHAR(max) = ''  
	
	-----------------------------accounts---------------------------------------------------
DECLARE @bi_account TABLE( 
		[biNumber]					[INT],
		[biMatPtr]					[UNIQUEIDENTIFIER], 
		[biMatAccGUID]				[UNIQUEIDENTIFIER], 
		[biDiscAccGUID]				[UNIQUEIDENTIFIER], 
		[biExtraAccGUID]			[UNIQUEIDENTIFIER]) 

DECLARE @bi_account_name TABLE(
		[biNumber]				[INT],
		[biMatPtr]				NVARCHAR(250),
		[biMatAccName]			NVARCHAR(250),
		[biDiscAccName]			NVARCHAR(250),
		[biExtraAccName]		NVARCHAR(250))
    

	INSERT INTO @bi_account 
		SELECT 
			---- New Update For SpecailOffer System
			bi.biNumber,
			bi.biMatPtr,
			CASE
				WHEN ISNULL([bi].[biSOGuid], 0x0) <> 0x0 AND (SELECT [Type] FROM SpecialOffers000 WHERE [GUID] = [so].[SOGuid]) = 4 THEN
					CASE ISNULL( [so].[SOMatAccAccount], 0x00) WHEN 0x0 THEN CASE bu.buMatAcc WHEN 0x0 THEN CASE ISNULL([ma_user].[maMatAccGUID], 0x0) WHEN 0x0 THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0) WHEN 0x0 THEN bu.btDefBillAcc ELSE [ma_mat].[maMatAccGUID] END ELSE [ma_user].[maMatAccGUID] END ELSE bu.buMatAcc END ELSE [so].[SOMatAccAccount] END 
				ELSE
				CASE ISNULL( [bi].[biSOType], -1)
					WHEN 1 THEN CASE ISNULL( [so].[SOMatAccAccount], 0x00) WHEN 0x0 THEN CASE bu.buMatAcc WHEN 0x0 THEN CASE ISNULL([ma_user].[maMatAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0)			WHEN 0x0 THEN bu.btDefBillAcc			ELSE [ma_mat].[maMatAccGUID]			END ELSE [ma_user].[maMatAccGUID] END ELSE bu.buMatAcc END ELSE [so].[SOMatAccAccount] END 
					WHEN 2 THEN CASE ISNULL( [so].[SOMatAccAccount], 0x00) WHEN 0x0 THEN CASE bu.buMatAcc WHEN 0x0 THEN CASE ISNULL([ma_user].[maMatAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0)			WHEN 0x0 THEN bu.btDefBillAcc			ELSE [ma_mat].[maMatAccGUID]			END ELSE [ma_user].[maMatAccGUID] END ELSE bu.buMatAcc END ELSE [so].[SOMatAccAccount] END 
					ELSE 
						CASE ISNULL( [soC].[SOMatAccAccount], 0x00) WHEN 0x00 THEN
							CASE bu.buMatAcc WHEN 0x0 THEN CASE ISNULL([ma_user].[maMatAccGUID], 0x0)		WHEN 0x0 THEN CASE ISNULL([ma_mat].[maMatAccGUID], 0x0)			WHEN 0x0 THEN bu.btDefBillAcc			ELSE [ma_mat].[maMatAccGUID]			END ELSE [ma_user].[maMatAccGUID] END ELSE bu.buMatAcc END
						ELSE [soC].[SOMatAccAccount] END	
				END
			END,
			----
			---- Check SpecialOffer Discounts
			-- CASE @buItemsDiscAccGUID	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		WHEN 0x0 THEN @btDefDiscAccGUID			ELSE [ma_mat].[maDiscAccGUID]			END ELSE [ma_user].[maDiscAccGUID]			END ELSE @buItemsDiscAccGUID END, 
			CASE
				WHEN ISNULL([bi].[biSOGuid], 0x0) <> 0x0 AND (SELECT [Type] FROM SpecialOffers000 WHERE [GUID] = [so].[SOGuid]) = 4 
					THEN CASE ISNULL( [so].[SODiscAccAccount], 0x0) WHEN 0x0 THEN CASE buItemsDiscAcc	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0) WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0) WHEN 0x0 THEN [bt].[btDefDiscAcc]  ELSE [ma_mat].[maDiscAccGUID] END ELSE [ma_user].[maDiscAccGUID]	END ELSE buItemsDiscAcc  END ELSE [so].[SODiscAccAccount] END 
				ELSE
				CASE ISNULL( [bi].[biSOType], -1)
					WHEN 1 THEN CASE ISNULL( [so].[SODiscAccAccount], 0x0) WHEN 0x0 THEN CASE buItemsDiscAcc	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		WHEN 0x0 THEN [bt].[btDefDiscAcc]			ELSE [ma_mat].[maDiscAccGUID]			END ELSE [ma_user].[maDiscAccGUID]			END ELSE buItemsDiscAcc  END ELSE [so].[SODiscAccAccount] END 
					WHEN 2 THEN CASE ISNULL( [so].[SODiscAccAccount], 0x0) WHEN 0x0 THEN CASE buItemsDiscAcc	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		WHEN 0x0 THEN [bt].[btDefDiscAcc]			ELSE [ma_mat].[maDiscAccGUID]			END ELSE [ma_user].[maDiscAccGUID]			END ELSE buItemsDiscAcc END ELSE [so].[SODiscAccAccount] END 
					ELSE
						CASE ISNULL( [soC].[SODiscAccAccount], 0x00) WHEN 0x00 THEN
							CASE buItemsDiscAcc	WHEN 0x0 THEN CASE ISNULL([ma_user].[maDiscAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maDiscAccGUID], 0x0)		WHEN 0x0 THEN [bt].[btDefDiscAcc]			ELSE [ma_mat].[maDiscAccGUID]			END ELSE [ma_user].[maDiscAccGUID]			END ELSE buItemsDiscAcc END
						ELSE [soC].[SODiscAccAccount] END	
				END
			END,
			----
			CASE ISNULL(buItemsExtraAcc, 0x0)	WHEN 0x0 THEN CASE ISNULL([ma_user].[maExtraAccGUID], 0x0)			WHEN 0x0 THEN CASE ISNULL([ma_mat].[maExtraAccGUID], 0x0)		WHEN 0x0 THEN [bt].[btDefExtraAcc]		ELSE [ma_mat].[maExtraAccGUID]			END ELSE [ma_user].[maExtraAccGUID]			END ELSE buItemsExtraAcc END
		FROM 
			[vwExtended_bi] AS [bi]  
			LEFT JOIN [vwbu] [bu] on [bu].[buGUID] = [bi].[buGUID] 
			LEFT JOIN [vwBt] [bt] on [bu].[buType] = [bt].[btGUID] 
			LEFT JOIN [vwMa] AS [ma_mat]  ON [bi].[biMatPtr] = [ma_mat].[maObjGUID] AND [bi].[buType] = [ma_mat].[maBillTypeGUID] 
			LEFT JOIN [vwMa] AS [ma_user] ON [ma_user].[maBillTypeGUID] = [bi].[buType] AND ma_user.[maObjGUID] = bu.buUserGUID
			---- New Update For SpecailOffer System	
			LEFT JOIN [ContractBillItems000]AS [cbi]	ON [cbi].[BillItemGuid] = [bi].[biGuid] 
			LEFT JOIN [vwSOAccounts]		AS [so]		ON [so].[SODetailGuid] = [bi].[biSOGuid]
			LEFT JOIN [vwSOAccounts]		AS [soC]	ON [soC].[SODetailGuid] = [cbi].[ContractItemGuid] 
		WHERE ma_user.[maType] = 5 AND [bu].[buGUID] = @guid
		
		INSERT INTO @bi_account_name
			SELECT biNumber, biMatPtr, ac.Name, dac.Name, eac.name 
			FROM @bi_account AS bi 
				INNER JOIN ac000 AS ac  ON biMatAccGUID = ac.GUID
				INNER JOIN ac000 AS dac ON biDiscAccGUID = dac.GUID
				INNER JOIN ac000 AS eac ON biExtraAccGUID = eac.GUID
	
			-----------------------------------------accounts------------------------------------
		declare @SalesTax int = 
						(
							SELECT	SUM( 	 
							CASE  TAX.ValueType
								WHEN 0 THEN [VALUE]
							Else  
							 CASE TAX.[TaxType]
									WHEN 1
									then
										CASE [TaxBeforeDiscount]
										WHEN 1
										THEN 
											([Total] - [TotalDisc] + [TotalExtra])-(([Total] - [TotalDisc] + [TotalExtra])/(1+( TAX.[VALUE]/100))) 
									else	

											([Total])-(([Total])/(1+( TAX.[VALUE]/100)))
									END
								else
		
									CASE [TaxBeforeDiscount]
										WHEN 1
											THEN 
												([Total] - [TotalDisc] + [TotalExtra])* TAX.[VALUE] / 100
										else
												([Total] * TAX.[VALUE]) / 100
											END
								END
							END) SALESTAX
							FROM salestax000 as Tax
							INNER JOIN [vtBu] ON TypeGUID =  BillTypeGuid
							INNER JOIN bt000 ON bt000.GUID =  BillTypeGuid
							WHERE 
							 [vtBu].GUID = @guid
							AND [UseSalesTax] = 1
						)
			 Declare @CF_Table NVARCHAR(255), @mtSql NVARCHAR(255),@stSql NVARCHAR(255),@bistSql NVARCHAR(255),@cuSql NVARCHAR(255), @buSql NVARCHAR(255), @sql NVARCHAR(max) --Mapped Table for Custom Fields 
	-----------------Cash,Credit,Other---------------------------------------------------
	DECLARE
		@Language INT,
		@PayType_Cash NVARCHAR(MAX),
		@PayType_Credit NVARCHAR(MAX);
	
	SET @Language = [dbo].[fnConnections_getLanguage]();
	SET @PayType_Cash = [dbo].[fnStrings_get](N'MISC\PAYTYPE_CASH', @language);
	SET @PayType_Credit = [dbo].[fnStrings_get](N'MISC\PAYTYPE_CREDIT', @language);

	print @PayType_Cash 
	print @PayType_Credit
	-----------------nt000--------------------------------------------------------------
	DECLARE @Securities_Papers NVARCHAR(255)
	SET @Securities_Papers = ISNULL((SELECT 
										CASE @Language when 1 then LatinName 
										ELSE Name END
										FROM nt000 NT
	inner join bu000 BU on BU.CheckTypeGUID=NT.GUID and BU.GUID=@guid),'')
	-----------------mt000--------------------------------------------------------------
	 SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000')  -- Mapping Table	 
	 SET @mtSql = ' LEFT JOIN ' + @CF_Table + ' as mtTb ON [#Result].[mat_Guid] = mtTb.Orginal_Guid ' 	 
	 DECLARE @mtNames NVARCHAR(max) 
	 SELECT @mtNames = COALESCE(@mtNames + ', ', '') + 'mtTb.'+ISNULL(ColumnName, 'N/A') + ' "Material_'+ Name + '"' 
	 FROM CFFlds000
	 where gguid = (select CFGroup_Guid FROM CFMapping000 WHERE Orginal_Table = 'mt000' )
	 IF @mtNames <> ''
	 set @mtNames =','+ @mtNames
			
	 -----------------st000--------------------------------------------------------------
	 --Bu_store
	 SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'st000')  -- Mapping Table	 
	 SET @stSql = ' LEFT JOIN ' + @CF_Table + ' as stTb ON [#Result].[store_Guid] = stTb.Orginal_Guid ' 	 
	 DECLARE @stNames NVARCHAR(max) 
	 SELECT @stNames = COALESCE(@stNames + ', ', '') + 'stTb.'+ISNULL(ColumnName, 'N/A') + ' as "Bill_Store_'+ Name + '"'
	 FROM CFFlds000
	 where gguid = (select CFGroup_Guid FROM CFMapping000 WHERE Orginal_Table = 'st000' )
	 IF @stNames <> ''
	 set @stNames =','+ @stNames
	 --Bi_store
	 SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'st000')  -- Mapping Table	 
	 SET @bistSql = ' LEFT JOIN ' + @CF_Table + ' as bistTb ON [#Result].[biStore_Guid] = bistTb.Orginal_Guid ' 	 
	 DECLARE @bistNames NVARCHAR(max) 
	 SELECT @bistNames = COALESCE(@bistNames + ', ', '') + 'stTb.'+ISNULL(ColumnName, 'N/A') + ' as "Bill_Item_Store_'+ Name + '"'
	 FROM CFFlds000
	 where gguid = (select CFGroup_Guid FROM CFMapping000 WHERE Orginal_Table = 'st000' )
	 IF @bistNames <> ''
	 set @bistNames =','+ @bistNames

	 -----------------cu000--------------------------------------------------------------
	 SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000')  -- Mapping Table	 
	 SET @cuSql = ' LEFT JOIN ' + @CF_Table + ' as cuTb ON [#Result].[Cust_Guid] = cuTb.Orginal_Guid ' 	 
	 DECLARE @cuNames NVARCHAR(max) 
	 SELECT @cuNames = COALESCE(@cuNames + ', ', '') + 'cuTb.'+ISNULL(ColumnName, 'N/A') + ' as " Customer_'+ Name + '"'
	 FROM CFFlds000
	 where gguid = (select CFGroup_Guid FROM CFMapping000 WHERE Orginal_Table = 'cu000' )
	 IF @cuNames <> ''
	 set @cuNames =',' + @cuNames
	 -----------------bu000--------------------------------------------------------------
	 SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000')  -- Mapping Table	 
	 SET @buSql = ' LEFT JOIN ' + @CF_Table + ' as buTb ON [#Result].[bu_Guid] = buTb.Orginal_Guid ' 	 
	 DECLARE @buNames NVARCHAR(max) 
	 SELECT @buNames = COALESCE(@buNames + ', ', '')+ 'buTb.'+ ISNULL(ColumnName, 'N/A') + ' as "Bill_'+ Name + '"'
	 FROM CFFlds000
	 where gguid = (select CFGroup_Guid FROM CFMapping000 WHERE Orginal_Table = 'bu000' )
	 IF @buNames <> ''
	 set @buNames =',' + @buNames
	 -------------------------------------------------------------------------------------------------

	SET @CurrentLanguage = (select dbo.fnConnections_GetLanguage())
	SELECT 
			@currencyGuid = bu.CurrencyGUID,
			@CurrencyName = CASE WHEN @CurrentLanguage = 0 THEN NAME ELSE LatinName END,
			@CurrencyPartName = CASE WHEN @CurrentLanguage = 0 THEN PartName ELSE LatinPartName END,
			@CurrencyVal = bu.CurrencyVal,
			@CurrencyPartPrecision = PartPrecision
	FROM my000 my
	INNER JOIN bu000 AS bu ON my.GUID = bu.CurrencyGUID
	WHERE bu.GUID = @guid 

	DECLARE @TAFQEET NVARCHAR(250),
			@TAFQEET_Net NVARCHAR(250),
			@bu_Total FLOAT,
			@bu_Net FLOAT

	SELECT @bu_Total = buTotal / ISNULL(@CurrencyVal, 1)  FROM vwBu WHERE buGUID = @guid
	SELECT @bu_Net = (buTotal + buTotalExtra - buTotalDisc + buVAT) / ISNULL(@CurrencyVal, 1) FROM vwBu  WHERE buGUID = @guid
	
	SET   @TAFQEET = dbo.Tafkeet(@bu_Total, @CurrencyName, @CurrencyPartName, @CurrencyPartPrecision)
	SET	  @TAFQEET_Net = dbo.Tafkeet(@bu_Net, @CurrencyName, @CurrencyPartName, @CurrencyPartPrecision)
	SELECT 
		 CASE ISNULL(@TAFQEET, N'NULL') WHEN N'NULL' THEN  N'  ' ELSE  @TAFQEET  END  AS TotalWords
		,CASE ISNULL(@TAFQEET_Net, N'NULL') WHEN N'NULL' THEN  N'  ' ELSE  @TAFQEET_Net  END  AS NetWords
		,btName bt_Type_Name
		,btLatinName bt_Type_Lname
		,btAbbrev bt_Name 
		, Data.buType btGuid 
		, buCust_Name cust_Name 
		, buCustPtr Cust_Guid
		, ISNULL(vwCuAc.acDebit - vwCuAc.acCredit, '') AS current_Cust_Balance 
		, ISNULL(Data.budate, '') bu_Date 
		, my.Name currency_Name 
		, Data.buCurrencyVal currency_Val 
		, Data.bupaytype paytype 
		, Data.buNotes bu_Notes 
		, st.name store_Name 
		, st.guid store_Guid
		, ISNULL(co.Name, '') cost_Center_Name 
		, Data.buVendor bu_Vendor 
		, Data.buSalesManPtr bu_SalesManPtr 
		, Data.buNumber bu_Number 
		, Data.buSecurity bu_Security 
		, ISNULL(pt.DueDate, '') bu_DueDate 
		, mt.name mat_Name 
		, mt.guid mat_Guid
		, mt.Number AS Material_Number
    , mt.Name AS Material_Name
    , mt.Code AS Material_Code
    , mt.LatinName AS Material_LatinName
    , mt.BarCode AS Material_BarCode
    , mt.CodedCode AS Material_CodedCode
    , mt.Unity AS Material_Unity
    , mt.Spec AS Material_Spec
    , mt.Qty AS Material_Qty
    , mt.High AS Material_High
    , mt.Low AS Material_Low
    , mt.Whole AS Material_Whole
    , mt.Half AS Material_Half
    , mt.Retail AS Material_Retail
    , mt.EndUser AS Material_EndUser
    , mt.Export AS Material_Export
    , mt.Vendor AS Material_Vendor
    , mt.MaxPrice / biCurrencyVal AS Material_MaxPrice
    , mt.AvgPrice / biCurrencyVal AS Material_AvgPrice
    , mt.LastPrice / biCurrencyVal  AS Material_LastPrice
    , mt.PriceType AS Material_PriceType
    , mt.SellType AS Material_SellType
    , mt.BonusOne AS Material_BonusOne
    , mt.CurrencyVal AS Material_CurrencyVal
    , mt.UseFlag AS Material_UseFlag
    , mt.Origin AS Material_Origin
    , mt.Company AS Material_Company
    , mt.Type AS Material_Type
    , mt.Security AS Material_Security
    , mt.LastPriceDate AS Material_LastPriceDate
    , mt.Bonus AS Material_Bonus
    , mt.Unit2 AS Material_Unit2
    , mt.Unit2Fact AS Material_Unit2Fact
    , mt.Unit3 AS Material_Unit3
    , mt.Unit3Fact AS Material_Unit3Fact
    , mt.Flag AS Material_Flag
    , mt.Pos AS Material_Pos
    , mt.Dim AS Material_Dim
    , mt.ExpireFlag AS Material_ExpireFlag
    , mt.ProductionFlag AS Material_ProductionFlag
    , mt.Unit2FactFlag AS Material_Unit2FactFlag
    , mt.Unit3FactFlag AS Material_Unit3FactFlag
    , mt.BarCode2 AS Material_BarCode2
    , mt.BarCode3 AS Material_BarCode3
    , mt.SNFlag AS Material_SNFlag
    , mt.ForceInSN AS Material_ForceInSN
    , mt.ForceOutSN AS Material_ForceOutSN
    , mt.VAT AS Material_VAT
    , mt.Color AS Material_Color
    , mt.Provenance AS Material_Provenance
    , mt.Quality AS Material_Quality
    , mt.Model AS Material_Model
    , mt.Whole2 AS Material_Whole2
    , mt.Half2 AS Material_Half2
    , mt.Retail2 AS Material_Retail2
    , mt.EndUser2 AS Material_EndUser2
    , mt.Export2 AS Material_Export2
    , mt.Vendor2 AS Material_Vendor2
    , mt.MaxPrice2 / biCurrencyVal  AS Material_MaxPrice2
    , mt.LastPrice2 / biCurrencyVal  AS Material_LastPrice2
    , mt.Whole3 AS Material_Whole3, mt.Half3 AS Material_Half3
    , mt.Retail3 AS Material_Retail3
    , mt.EndUser3 AS Material_EndUser3
    , mt.Export3 AS Material_Export3
    , mt.Vendor3 AS Material_Vendor3
    , mt.MaxPrice3 AS Material_MaxPrice3
    , mt.LastPrice3 AS Material_LastPrice3
    , mt.GUID AS Material_GUID
    , mt.GroupGUID AS Material_GroupGUID
    , mt.PictureGUID AS Material_PictureGUID
    , mt.CurrencyGUID AS Material_CurrencyGUID
    , mt.DefUnit AS Material_DefUnit
    , mt.bHide AS Material_bHide
    , mt.branchMask AS Material_branchMask
    , mt.OldGUID AS Material_OldGUID
    , mt.NewGUID AS Material_NewGUID
    , mt.Assemble AS Material_Assemble
    , mt.OrderLimit AS Material_OrderLimit
    , mt.CalPriceFromDetail AS Material_CalPriceFromDetail
    , mt.ForceInExpire AS Material_ForceInExpire
    , mt.ForceOutExpire AS Material_ForceOutExpire
    , mt.CreateDate AS Material_CreateDate
		, CASE biunity WHEN 1 THEN biqty WHEN 2 THEN biqty/CASE WHEN mt.Unit2Fact = 0 then 1 ELSE mt.Unit2Fact END ELSE biqty/CASE WHEN mt.Unit3Fact= 0 then 1 ELSE mt.Unit3Fact END END qty 
		, CASE biunity WHEN 1 THEN mt.unity WHEN 2 THEN mt.unit2 ELSE mt.unit3 END unit 
		, CASE btVATSystem WHEN 2 THEN data.biprice * (1 + (biVATr / 100)) ELSE data.biprice END / data.biCurrencyVal bi_Price
		,( CASE biunity WHEN 1 THEN biqty WHEN 2 THEN biqty/CASE WHEN mt.Unit2Fact = 0 then 1 ELSE mt.Unit2Fact END ELSE biqty/CASE WHEN mt.Unit3Fact= 0 then 1 ELSE mt.Unit3Fact END END ) * CASE btVATSystem WHEN 2 THEN data.biprice * (1 + (biVATr / 100)) ELSE data.biprice END / data.biCurrencyVal bi_TotalPrice 
		, data.biDiscount / data.biCurrencyVal AS biDiscount
		, data.biExtra / data.biCurrencyVal AS biExtra
		, Data.biBonusDisc / data.biCurrencyVal AS biBonusDisc
		, Data.biBonusQnt AS biBonusQnt
		, Data.biVAT / data.biCurrencyVal AS bi_VAT
		, Data.buVAT / data.biCurrencyVal AS bu_VAT
		, bi_St.Name bi_Store_Name 
		, bi_St.Guid biStore_Guid
		, ISNULL(bi_Co.Name, '') bi_Cost_Name 
		, biClassPtr bi_Class 
		, biExpireDate bi_ExpireDate 
		, biProductionDate bi_ProductionDate 
		, biNotes bi_Notes 
		, biHeight bi_Height 
		, biWidth bi_Width 
		, biLength bi_Length 
		, biCount bi_Count 
		, Data.FixedBuTotal total_Bis -- «·„Ã„Ê⁄ «·Ã“∆Ì 
		, (Data.FixedBuTotal + Data.FixedBuTotalExtra - Data.FixedBuTotalDisc + (Data.buVAT / data.biCurrencyVal)) bu_Total-- «·’«›Ì 
		, Data.FixedBuTotalExtra buTotalExtra
		, Data.FixedBuTotalDisc buTotalDisc
		, mt.Security MtSecurity 
		, ISNULL(vwCuAc.acSecurity, 0) AccSecurity 
		, ISNULL(vwCuAc.cuSecurity, 0) cuSecurity 
		, Data.buSecurity buSecurity 
		, CASE WHEN ISNULL(co.Security, 0) > ISNULL(bi_Co.Security, 0) THEN ISNULL(co.Security, 0) ELSE ISNULL(bi_Co.Security, 0) END coSecurity 
		, CASE WHEN st.Security > ISNULL(bi_St.Security, 0) THEN st.Security ELSE ISNULL(bi_St.Security, 0) END stSecurity 
		, CASE Data.buIsPosted WHEN 1 THEN Src.Sec ELSE Src.UnPostedSec END UserSecurity 
		, buSecurity Security
		, buNumber 
		, data.biNumber
		, ms.Qty mat_Store_qty
		, mt.qty total_mat_qty
		, [MaxCustDate].[LastCustomerDate] AS [LastCustomerDate]
		, Data.buUserGuid
		-------bi accounts name-----------
		, [biMatAccName]     [Bill_Item_Material_Account_name]
		, [biDiscAccName]	 [Bill_Item_Discount_Account_name]	
		, [biExtraAccName]    [Bill_Item_Extra_Account_name]
	    ------ Customer Info----
		,vwCu.[cuNationality] AS [Bill_Customer_Nationality]
		,vwCu.[cuAddress] AS [Bill_Customer_Address]
		,vwCu.[cuPhone1] AS [Bill_Customer_Phone1]
		,vwCu.[cuPhone2] AS [Bill_Customer_Phone2]
		,vwCu.[cuFAX] AS [Bill_Customer_FAX]
		,vwCu.[cuTELEX] AS [Bill_Customer_TELEX]
		,vwCu.[cuNotes] AS [Bill_Customer_Notes]
		,vwCu.[cuDiscRatio] AS [Bill_Customer_DiscRatio]
		,vwCu.[cuDefPrice] AS [Bill_Customer_DefPrice]
		,vwCu.[cuState] AS [Bill_Customer_State]
		,vwCu.[cuStreet] AS [Bill_Customer_Street]
		,vwCu.[cuArea] AS [Bill_Customer_Area]
		,vwCu.[cuLatinName] AS [Bill_Customer_LatinName]
		,vwCu.[cuEMail] AS [Bill_Customer_EMail]
		,vwCu.[cuHomePage] AS [Bill_Customer_HomePage]
		,vwCu.[cuPrefix] AS [Bill_Customer_Prefix]
		,vwCu.[cuSuffix] AS [Bill_Customer_Suffix]
		,vwCu.[cuGPSX] AS [Bill_Customer_GPSX]
		,vwCu.[cuGPSY] AS [Bill_Customer_GPSY]
		,vwCu.[cuGPSZ] AS [Bill_Customer_GPSZ]
		,vwCu.[cuCity] AS [Bill_Customer_City]
		,vwCu.[cuPOBox] AS [Bill_Customer_POBox]
		,vwCu.[cuZipCode] AS [Bill_Customer_ZipCode]
		,vwCu.[cuMobile] AS [Bill_Customer_Mobile]
		,vwCu.[cuPager] AS [Bill_Customer_Pager]
		,vwCu.[cuCountry] AS [Bill_Customer_Country]
		,vwCu.[cuHobbies] AS [Bill_Customer_Hobbies]
		,vwCu.[cuGender] AS [Bill_Customer_Gender]
		,vwCu.[cuCertificate] AS [Bill_Customer_Certificate]
		,vwCu.[cuDateOfBirth] AS [Bill_Customer_DateOfBirth]
		,vwCu.[cuJob] AS [Bill_Customer_Job]
		,vwCu.[cuJobCategory] AS [Bill_Customer_JobCategory]
		,vwCu.[cuUserFld1] AS [Bill_Customer_UserFld1]
		,vwCu.[cuUserFld2] AS [Bill_Customer_UserFld2]
		,vwCu.[cuUserFld3] AS [Bill_Customer_UserFld3]
		,vwCu.[cuUserFld4] AS [Bill_Customer_UserFld4]
		,vwCu.[cuBarCode] AS [Bill_Customer_BarCode]
		,vwCu.[cuHide] AS [Bill_Customer_Hide]
		--------Store Info----------
		,st.[Code] AS [Bill_Store_Code]
		,st.[Notes] AS [Bill_Store_Notes]
		,st.[Address] AS [Bill_Store_Address]
		,st.[Keeper] AS [Bill_Store_Keeper]
		,st.[LatinName] AS [Bill_Store_latinName]
		,st.[Type] AS [Bill_Store_Type]
		,buGuid bu_Guid
		,ISNULL(@SalesTax,0) SalesTax
		--------
	INTO #Result 
	FROM [dbo].[fnExtended_bi_Fixed](@currencyGuid) AS Data 
	LEFT JOIN vwCuAc ON vwCuAc.cuGuid = buCustPtr 
	LEFT JOIN vwCu on vwCu.cuGuid = buCustPtr
	LEFT JOIN co000 co ON Data.buCostPtr = co.Guid 
	LEFT JOIN pt000 pt ON pt.RefGuid  = Data.buGuid 
	LEFT JOIN st000 bi_St ON bi_St.Guid = Data.biStorePtr 
	LEFT JOIN co000 bi_Co ON Data.biCostPtr = bi_Co.Guid 
	INNER JOIN my000 my ON Data.buCurrencyPtr = my.Guid 
	INNER JOIN st000 st ON Data.bustoreptr = st.guid 
	INNER JOIN mt000 mt ON mt.guid = Data.bimatptr 
	LEFT JOIN ms000 ms ON mt.guid = ms.MatGuid AND ms.StoreGUID = Data.buStorePtr
	LEFT JOIN (SELECT buCustPtr AS [CustGuid] , MAX([buDate]) AS [LastCustomerDate] FROM vwbubi WHERE btType = 1 GROUP BY [buCustPtr] )  AS [MaxCustDate] ON [MaxCustDate].[CustGuid] = vwCu.cuGuid
	INNER JOIN #Src AS Src ON Data.buType = Src.Type 
	LEFT JOIN @bi_account_name [an] on [an].biMatPtr = Data.bimatptr AND data.biNumber = an.biNumber
	WHERE buGuid = @guid 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]); 
	
	EXEC [prcCheckSecurity] 
	
SET @sql='
	SELECT  
		bt_Type_Name AS Bill_Type_Name, bt_Type_Lname AS Bill_Type_Lname, bt_Name Bill_Type_Apprev , Material_Number, Material_Name, Material_Code, Material_LatinName, Material_BarCode, Material_CodedCode, Material_Unity, Material_Spec, Material_Qty, Material_High, Material_Low, Material_Whole, Material_Half, Material_Retail, Material_EndUser, Material_Export, Material_Vendor, Material_MaxPrice, Material_AvgPrice, Material_LastPrice, Material_PriceType, Material_SellType, Material_BonusOne, Material_CurrencyVal, Material_UseFlag, Material_Origin, Material_Company, Material_Type, Material_Security, Material_LastPriceDate, Material_Bonus, Material_Unit2, Material_Unit2Fact, Material_Unit3, Material_Unit3Fact, Material_Flag, Material_Pos, Material_Dim, Material_ExpireFlag, Material_ProductionFlag, Material_Unit2FactFlag, Material_Unit3FactFlag, Material_BarCode2, Material_BarCode3, Material_SNFlag, Material_ForceInSN, Material_ForceOutSN, Material_VAT, Material_Color, Material_Provenance, Material_Quality, Material_Model, Material_Whole2, Material_Half2, Material_Retail2, Material_EndUser2, Material_Export2, Material_Vendor2, Material_MaxPrice2, Material_LastPrice2, Material_Whole3, Material_Half3, Material_Retail3, Material_EndUser3, Material_Export3, Material_Vendor3, Material_MaxPrice3, Material_LastPrice3, Material_GUID, Material_GroupGUID, Material_PictureGUID, Material_CurrencyGUID, Material_DefUnit, Material_bHide, Material_branchMask, Material_OldGUID, Material_NewGUID, Material_Assemble, Material_OrderLimit, Material_CalPriceFromDetail, Material_ForceInExpire, Material_ForceOutExpire, Material_CreateDate'
    	+ ISNULL(@mtNames,'')+' '+
		', bu_Number Bill_Number 
		, cust_Name Customer_Name' 
  		+ISNULL(@cuNames,'')+' '+ 
		+', current_Cust_Balance Current_Customer_Balance 
		, bu_Date Bill_Date 
		, currency_Name Currency_Name 
		, currency_Val Currency_Value 
		, CASE payType WHEN 0 THEN N'''+ ISNULL(@PayType_Cash, N'') + '''
					   WHEN 1 THEN N'''+ ISNULL(@PayType_Credit, N'') + '''
					   ELSE N'''+ ISNULL(@Securities_Papers, N'') + ''' END AS Pay_Type 
		, bu_Notes Bill_Notes 
		, store_Name Bill_Store_Name '
	  	+isnull(@buNames,'')+' '+
		', cost_Center_Name Cost_Center_Name 
		, bu_Vendor Bill_Vendor 
		, bu_SalesManPtr Bill_SalesMan 
		, bu_Security Bill_Security 
		, bu_DueDate Bill_Due_Date 
		, mat_Name Bill_Item_Material_Name 
		, qty Bill_Item_Material_Quantity 
		, unit Bill_Item_Material_Unit 
		, bi_Price Bill_Item_Price 
		, bi_TotalPrice Bill_Item_Total_Price 
		, biDiscount Bill_Item_Discount 
		, biExtra Bill_Item_Extra 
		, biBonusDisc Bill_Item_Bonus 
		, biBonusQnt Bill_Item_Bonus_Quantity
		, bi_Store_Name Bill_Item_Store_Name'  
  		+ISNULL(@bistNames,'')+' '+
		', bi_Cost_Name Bill_Item_Cost_Cente_Name 
		, bi_Class Bill_Item_Class 
		, bi_ExpireDate Bill_Item_Expire_Date 
		, bi_ProductionDate Bill_Item_Production_Date 
		, bi_Notes Bill_Item_Notes 
		, bi_Height Bill_Item_Height 
		, bi_Width Bill_Item_Width 
		, bi_Length Bill_Item_Length 
		, bi_Count Bill_Item_Count 
		, bi_VAT   Bill_Item_VAT
		, bu_VAT   Bill_VAT
		,[SalesTax]  Bill_SalesTax
		, total_Bis Bill_Sub_Total 
		, bu_Total Bill_Total 
		, butotalextra Bill_Total_Extra 
		, butotaldisc Bill_Total_Discount 
		, buNumber Bill_Number
		, mat_store_qty Bill_Item_Store_Quantity
		, total_mat_qty Bill_Item_total_Quantity
		, [LastCustomerDate] Bill_Customer_LastSellDate
		, dbo.fnGetCurrentUserName() CurrentUser
		-----------kml;m------
		
		,[Bill_Item_Material_Account_name]
		,[Bill_Item_Discount_Account_name]	
		,[Bill_Item_Extra_Account_name]
	 
	    ------ Customer Info----
		,[Bill_Customer_Nationality]
		,[Bill_Customer_Address]
		,[Bill_Customer_Phone1]
		,[Bill_Customer_Phone2]
		,[Bill_Customer_FAX]
		,[Bill_Customer_TELEX]
		,[Bill_Customer_Notes]
		,[Bill_Customer_DiscRatio]
		,[Bill_Customer_DefPrice]
		,[Bill_Customer_State]
		,[Bill_Customer_Street]
		,[Bill_Customer_Area]
		,[Bill_Customer_LatinName]
		,[Bill_Customer_EMail]
		,[Bill_Customer_HomePage]
		,[Bill_Customer_Prefix]
		,[Bill_Customer_Suffix]
		,[Bill_Customer_GPSX]
		,[Bill_Customer_GPSY]
		,[Bill_Customer_GPSZ]
		,[Bill_Customer_City]
		,[Bill_Customer_POBox]
		,[Bill_Customer_ZipCode]
		,[Bill_Customer_Mobile]
		,[Bill_Customer_Pager]
		,[Bill_Customer_Country]
		,[Bill_Customer_Hobbies]
		,[Bill_Customer_Gender]
		,[Bill_Customer_Certificate]
		,[Bill_Customer_DateOfBirth]
		,[Bill_Customer_Job]
		,[Bill_Customer_JobCategory]
		,[Bill_Customer_UserFld1]
		,[Bill_Customer_UserFld2]
		,[Bill_Customer_UserFld3]
		,[Bill_Customer_UserFld4]
		,[Bill_Customer_BarCode]
		,[Bill_Customer_Hide]
		--------Store Info----------
		,[Bill_Store_Code]
		,[Bill_Store_Notes]
		,[Bill_Store_Address]
		,[Bill_Store_Keeper]
		,[Bill_Store_latinName]
		,[Bill_Store_Type]'
		+ ISNULL(@stNames,' ')
		+ ',[TotalWords]
		,[NetWords] '
		+' FROM #Result '+ ISNULL(@mtSql, ' ') +' '+ ISNULL(@stSql, '') +' '+ISNULL(@bistSql, '')+' '+ ISNULL(@cuSql , '')+' '+ ISNULL(@buSql, '')
 		EXEC(@sql)

##############################################################
CREATE PROCEDURE bill_print_dis
	(
		@guid UNIQUEIDENTIFIER
	)
	AS
	SET NOCOUNT ON 
	
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT]) 
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2]
	
	SELECT 
	  bu.Date buDate
	, ac.Name acName
	, di.Extra / di.CurrencyVal diExtra
	, di.Discount / di.CurrencyVal diDiscount
	, di.Notes diNotes
	, co.Name coName
	, contra_ac.Name contra_acName
	, my.Name myName
	, di.CurrencyVal diCurrencyVal
	, ISNULL(co.Security, 0) CostSecurity
	, CASE bu.isPosted WHEN 1 THEN Src.Sec ELSE Src.UnPostedSec END UserSecurity
	, bu.Security Security
	, CASE WHEN ac.Security > ISNULL(contra_ac.Security, 0) THEN ac.Security ELSE ISNULL(contra_ac.Security, 0) END accSecurity
	INTO #RESULT
		FROM bu000 bu  
		INNER JOIN di000 di ON bu.guid = di.parentguid
		LEFT JOIN ac000 ac ON ac.Guid = di.AccountGuid
		LEFT JOIN co000 co ON co.Guid = di.CostGuid
		LEFT JOIN ac000 contra_ac ON contra_ac.Guid = di.ContraAccGuid
		LEFT JOIN my000 my ON my.Guid = di.CurrencyGuid
		LEFT JOIN #Src AS Src ON bu.typeGuid = Src.Type
	WHERE bu.Guid = @guid
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]);
	EXEC [prcCheckSecurity]
	
	SELECT 
		  buDate Bill_Date
		, acName Details_Account_Name
		, diExtra Details_Extra
		, diDiscount Details_Discount
		, diNotes Details_Notes
		, coName Details_CostCenter
		, contra_acName Details_Contra_Account_Name
		, myName Details_Currency_Name
		, diCurrencyVal Details_Currency_Value
	FROM #RESULT
	DROP TABLE #RESULT
##############################################################
CREATE PROCEDURE prcBillPrint
	 @BillType UNIQUEIDENTIFIER,
	 @BilllNumber int
	AS
	SELECT 
		cu.*, 
		v.* 
	FROM dbo.vo_bill_dtails_extended v	INNER JOIN bu000 bu ON v.Bill_Guid = bu.Guid
							LEFT JOIN cu000 cu ON  cu.Guid = bu.CustGUID
	WHERE Bill_Number = @BilllNumber and bu.TypeGuid = @BillType
	ORDER BY billitem_number

	UPDATE BU000 SET isprinted = 1 where TypeGuid = @BillType AND Number = @BilllNumber
##############################################################
CREATE PROCEDURE prcSetBillPrinted
	 @BillGuid UNIQUEIDENTIFIER
	AS
	UPDATE bu000 SET isprinted = 1 WHERE Guid = @BillGuid
##############################################################
CREATE PROCEDURE RepPyEntryPrint
	 @guid UNIQUEIDENTIFIER = '8CD0E8FA-761D-4C94-AF02-E27E39C52BC3',
	 @currencyGuid UNIQUEIDENTIFIER = 0x0
	AS
	SET NOCOUNT ON 
	
	IF(ISNULL(@currencyGuid, 0x0) = 0x0)
		SELECT @currencyGuid = Guid FROM My000 WHERE Number = 1
	DECLARE @CurrencyVal  FLOAT
	DECLARE @CurrencyName NVARCHAR(255)
	DECLARE @CurrencyPartName NVARCHAR(250)
	Declare @CurrencyPartPrecision nvarchar(250) 
	DECLARE @CurrentLanguage INT = 0 
	 
	SET @CurrentLanguage = (select dbo.fnConnections_GetLanguage())
	IF @CurrentLanguage = 0 
	SELECT @CurrencyName = CASE WHEN @currentLanguage = 0 then  NAME ELSE LatinName END  FROM My000 WHERE Number = 1
	 
	DECLARE @CurrencyString AS NVARCHAR(max) = ''
	SET @CurrencyVal = 1 
	SELECT @CurrencyName = CASE WHEN @CurrentLanguage = 0 THEN NAME ELSE LatinName END,
		   @CurrencyPartName = CASE WHEN @CurrentLanguage = 0 THEN PartName ELSE LatinPartName END,
		   @CurrencyPartPrecision = PartPrecision, 
		   @CurrencyVal = CurrencyVal
	FROM my000
	WHERE GUID = @currencyGuid
	
	SELECT
		number = IDENTITY(int,1,1)
		,Ac.Code + ' - ' + Ac.Name AS Account 
		,ROUND(En.Debit / En.CurrencyVal, 3) Debit
		,ROUND(En.Credit / En.CurrencyVal, 3) Credit
		,ISNULL(Co.Name, '') CostCenter
		,@CurrencyName CurrencyName
		,En.CurrencyVal EnCurrencyVal 
		,Py.Notes PyNotes
		,En.Notes
		,En.Class
		,En.Date
		,ContraAc.Code + ' - ' + ContraAc.Name AS ContraAccount
		,Py.Number PyNumber
		,ce.CurrencyVal CeCurrencyVal 
		,Ce.Guid CeGuid
		,Py.Guid PyGuid
		,Ce.Security ceSecurity
		, CAST( 0 AS FLOAT ) Entry_Total
		,@CurrencyString AS TotalWords 
	INTO #Result
	FROM Ce000 Ce
	INNER JOIN Er000 Er ON Er.EntryGuid = Ce.Guid
	INNER JOIN Py000 Py ON Py.Guid = Er.ParentGuid
	INNER JOIN Et000 Et ON Et.Guid = Py.TypeGuid
	INNER JOIN En000 En ON En.ParentGuid = Ce.Guid
	LEFT JOIN Ac000 Ac ON Ac.Guid = En.AccountGuid
	LEFT JOIN Co000 Co ON Co.Guid = En.CostGuid
	LEFT JOIN My000 My ON My.Guid = En.CurrencyGuid
	LEFT JOIN Ac000 ContraAc ON ContraAc.Guid = En.ContraAccGuid
	WHERE Py.guid = @guid AND ( ( Et.FldDebit <> 0 AND En.Debit <> 0 ) OR ( Et.FldCredit <> 0 AND En.Credit <> 0 ) )
	ORDER By En.Number
	UPDATE #Result SET Entry_Total = ( SELECT SUM(Debit * EnCurrencyVal / CeCurrencyVal) FROM #Result )
	
	UPDATE #Result SET Entry_Total = ( SELECT SUM(Debit) FROM #Result )
	
	DECLARE @Entry_Total FLOAT
	SELECT @Entry_Total = Entry_Total FROM #Result
	IF(@Entry_Total = 0)
		UPDATE #Result SET Entry_Total = ( SELECT SUM(Credit * EnCurrencyVal / CeCurrencyVal) FROM #Result )
	
	SELECT @Entry_Total = Entry_Total FROM #Result
	SET @CurrencyString = (SELECT dbo.Tafkeet(@Entry_Total, @CurrencyName, @CurrencyPartName, @CurrencyPartPrecision)) 
	UPDATE #Result SET TotalWords = @CurrencyString
	
	CREATE TABLE #SecViol( Type INT, Cnt INTEGER) 
	EXEC prcCheckSecurity 
	
	-----------------ce000 Custom Fields--------------------------------------------------------------
	Declare @CF_Table NVARCHAR(255), @pySql NVARCHAR(255), @sql NVARCHAR(max)
	 SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'py000')  -- Mapping Table	 
	 SET @pySql = ' LEFT JOIN ' + @CF_Table + ' as pyTb ON [#Result].[PyGuid] = pyTb.Orginal_Guid ' 	 
	 DECLARE @pyNames NVARCHAR(max) 
	 SELECT @pyNames = COALESCE(@pyNames + ', ', '')+ 'pyTb.'+ ISNULL(ColumnName, 'N/A') + ' as "Voucher_'+ Name + '"'
	 FROM CFFlds000
	 where gguid = (select CFGroup_Guid FROM CFMapping000 WHERE Orginal_Table = 'py000' )
	 IF @pyNames <> ''
	 SET @pyNames =',' + @pyNames
	 
	 SET @sql='
	 SELECT * 
		'+isnull(@pyNames,'')+' '+'
	 FROM #Result '+ ISNULL(@pySql, ' ')
	 EXEC(@sql)
##############################################################
CREATE PROCEDURE SetPyEntryPrinted
		@guid UNIQUEIDENTIFIER = '8CD0E8FA-761D-4C94-AF02-E27E39C52BC3',
		@currencyGuid UNIQUEIDENTIFIER = 0x0 -- it's not used but we need to pass it to fix fastreport printing bug
	AS
	SET NOCOUNT ON
	DECLARE @CeGuid UNIQUEIDENTIFIER
	SELECT @CeGuid = Ce.Guid FROM Ce000 Ce
	INNER JOIN Er000 Er ON Er.EntryGuid = Ce.Guid
	INNER JOIN Py000 Py ON Py.Guid = Er.ParentGuid
	UPDATE Ce000 Set IsPrinted = 1 WHERE Guid = @CeGuid
##############################################################
CREATE PROCEDURE repentryprint
		@guid UNIQUEIDENTIFIER = 0x0,
		@currencyGuid UNIQUEIDENTIFIER = 0x0
	AS
	SET NOCOUNT ON
	IF(ISNULL(@currencyGuid, 0x0) = 0x0)
		SELECT @currencyGuid = Guid FROM My000 WHERE Number = 1
	DECLARE @CurrencyVal FLOAT
	DECLARE @CurrencyName NVARCHAR(255)
	DECLARE @CurrencyPartName NVARCHAR(250)
	DECLARE @CurrentLanguage INT = 0
	Declare @CurrencyPartPrecision nvarchar(250)
	DECLARE @CurrencyString AS NVARCHAR(max) = ''
	SET @CurrencyVal = 1
	
	SET @CurrentLanguage = (select dbo.fnConnections_GetLanguage())
	SELECT @CurrencyName = CASE WHEN @CurrentLanguage = 0 THEN NAME ELSE LatinName END,
		   @CurrencyPartName = CASE WHEN @CurrentLanguage = 0 THEN PartName ELSE LatinPartName END,
	       @CurrencyVal = CurrencyVal,
	       @CurrencyPartPrecision = PartPrecision
	FROM my000
	WHERE GUID = @currencyGuid
	SELECT
		number = IDENTITY(int,1,1)
		,Ac.Code + ' - ' + Ac.Name AS Account 
		,ROUND(En.Debit / en.CurrencyVal, 3) Debit
		,ROUND(En.Credit / en.CurrencyVal, 3) Credit
		,ISNULL(Co.Name, '') CostCenter
		,@CurrencyName CurrencyName
		,En.CurrencyVal EnCurrencyVal
		,En.Notes
		,En.Class
		,En.Date
		,ContraAc.Code + ' - ' + ContraAc.Name AS ContraAccount
		,Ce.Guid CeGuid
		,Ce.Number CeNumber
		,Ce.Notes CeNotes
		,Ce.Security ceSecurity
		,Ce.CurrencyVal CeCurrencyVal
		, CAST( 0 AS FLOAT ) Entry_Total
		,@CurrencyString AS TotalWords
	INTO #Result
	FROM Ce000 Ce
	INNER JOIN En000 En ON En.ParentGuid = Ce.Guid
	LEFT JOIN Ac000 Ac ON Ac.Guid = En.AccountGuid
	LEFT JOIN Co000 Co ON Co.Guid = En.CostGuid
	LEFT JOIN My000 My ON My.Guid = En.CurrencyGuid
	LEFT JOIN Ac000 ContraAc ON ContraAc.Guid = En.ContraAccGuid
	WHERE Ce.guid = @guid
	ORDER By En.Number

	UPDATE #Result SET Entry_Total = ( SELECT SUM(Debit  * EnCurrencyVal / CeCurrencyVal) FROM #Result )
	
	DECLARE @Entry_Total FLOAT
	SELECT @Entry_Total = Entry_Total FROM #Result
	IF(@Entry_Total = 0)
		UPDATE #Result SET Entry_Total = ( SELECT SUM(Credit * EnCurrencyVal / CeCurrencyVal) FROM #Result )
		
	SELECT @Entry_Total = Entry_Total FROM #Result
	SET @CurrencyString = (SELECT dbo.Tafkeet(@Entry_Total, @CurrencyName, @CurrencyPartName, @CurrencyPartPrecision))
	UPDATE #Result SET TotalWords = @CurrencyString
	CREATE TABLE #SecViol( Type INT, Cnt INTEGER)
	EXEC prcCheckSecurity
	SELECT * FROM #Result
##############################################################
CREATE PROCEDURE SetEntryPrinted
		@guid UNIQUEIDENTIFIER = '8CD0E8FA-761D-4C94-AF02-E27E39C52BC3',
		@currencyGuid UNIQUEIDENTIFIER = 0x0 -- it's not used but we need to pass it to fix fastreport printing bug
	AS
	SET NOCOUNT ON
	UPDATE Ce000 Set IsPrinted = 1 WHERE Guid = @guid
##############################################################
#END	
