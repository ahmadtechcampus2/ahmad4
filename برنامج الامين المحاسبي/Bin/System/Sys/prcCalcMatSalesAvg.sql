####################################
CREATE PROCEDURE prcCalcMatSalesAvg
	@MatGUID 		UNIQUEIDENTIFIER,
	@PeriodGUID		UNIQUEIDENTIFIER,
	@CustGUID 		UNIQUEIDENTIFIER,
	@AccGUID 		UNIQUEIDENTIFIER,
	@UseUnit		INT,
	@IsGroupByCust	BIT = 0
AS
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #SecViol( Type INT, Cnt INTEGER)

	-- Creating temporary tables
	CREATE TABLE #MatTbl( MatGUID UNIQUEIDENTIFIER, mtSecurity INT)
	CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)
	CREATE TABLE #StoreTbl(	StoreGUID UNIQUEIDENTIFIER, Security INT)
	CREATE TABLE #CostTbl( CostGUID UNIQUEIDENTIFIER, Security INT)
	CREATE TABLE #CustTbl( CustGUID UNIQUEIDENTIFIER, Security INT)
	CREATE TABLE #TmpCustTbl( CustGUID UNIQUEIDENTIFIER, Security INT)
	-- Filling temporary tables
	INSERT INTO #MatTbl			EXEC prcGetMatsList 		@MatGUID, 0x0 -- @GroupGUID
	DELETE #MatTbl FROM DistMe000 AS me, #MatTbl AS mt WHERE mt.MatGUID = me.MtGUID AND me.State = 1
	INSERT INTO #BillsTypesTbl	EXEC prcGetBillsTypesList 	0x0 -- @SrcTypesGUID
	INSERT INTO #TmpCustTbl		EXEC prcGetCustsList 		@CustGUID, @AccGUID

	INSERT INTO #CustTbl SELECT t.CustGUID, t.Security FROM #TmpCustTbl AS t
	FULL JOIN DistCE000 AS c ON t.CustGUID = c.CustomerGUID WHERE c.State <> 1 OR c.State Is NULL

	CREATE TABLE #Result
	( 
		buType 				UNIQUEIDENTIFIER,
		buNumber 			UNIQUEIDENTIFIER NOT NULL,  
		buDate 				DATETIME NOT NULL,
		Period				INT,
		BuSortFlag			INT NOT NULL, 
		BiNumber			INT NOT NULL, 
		buNotes 			NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		buCust_Name 		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		buCustPtr 			UNIQUEIDENTIFIER, 
		buItemsDisc			FLOAT, 
		biStorePtr			UNIQUEIDENTIFIER, 
		biNotes				NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		biUnity				FLOAT,
		biPrice				FLOAT,
		biCurrencyPtr		UNIQUEIDENTIFIER,
		biCurrencyVal		FLOAT,
		biDiscount			FLOAT,
		biExtra				FLOAT,
		biBillQty			FLOAT,
	--------- 
		biMatPtr			UNIQUEIDENTIFIER, 
		mtName				NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		mtCode				NVARCHAR(256) COLLATE ARABIC_CI_AI,  
		mtLatinName			NVARCHAR(256) COLLATE ARABIC_CI_AI,	
		mtUnitName			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		mtDefUnitName		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		mtDefUnitFact		FLOAT,	  
		btIsInput 			INT, 
		biQty				FLOAT, 
		btIsOutput			INT, 
		--biBonusQnt			FLOAT, 
		FixedBiPrice		FLOAT, 
		MtUnitFact			FLOAT, 
		FixedBuTotalExtra	FLOAT, 
		FixedBuTotal		FLOAT, 
		FixedBuTotalDisc	FLOAT, 
		FixedBiDiscount		FLOAT, 
	--------- 
		mtFlag				FLOAT, 
		mtUnit2Fact			FLOAT,  
		mtUnit3Fact			FLOAT,
		mtUnity				NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		mtUnit2				NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		mtUnit3				NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		Security				INT, 
		UserSecurity 			INT, 
		UserReadPriceSecurity	INT, 
		MtSecurity			INT,
		StartDate			DATETIME,

		PeriodStart			DATETIME,
		PeriodEnd			DATETIME,
		Cust				UNIQUEIDENTIFIER
	)

	CREATE TABLE #MainRes
	(
		BiMatPtr		UNIQUEIDENTIFIER, 
		MtName			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		MtCode			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		MtLatinName		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		mtUnitName		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		UnitNameInBill	NVARCHAR(256) COLLATE ARABIC_CI_AI,
		Unit			INT,
		MtUnit2 		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		MtUnit3			NVARCHAR(256) COLLATE ARABIC_CI_AI,

		mtUnitFact		FLOAT,
	
		[Avg]				FLOAT,
		-- pCount			FLOAT,
		Cust			UNIQUEIDENTIFIER
	)
	EXEC prcPrepareCalcMatSalesAvg  @MatGUID, @PeriodGUID, @CustGUID, @AccGUID,	@UseUnit, @IsGroupByCust

	DELETE #MainRes FROM DistMe000 AS me, #MainRes AS mt WHERE mt.BiMatPtr = me.mtGUID AND me.State = 1

	CREATE TABLE #FinalRes
	(
		BiMatPtr		UNIQUEIDENTIFIER, 
		MtName			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		MtCode			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		MtLatinName		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		mtUnitName		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		UnitNameInBill	NVARCHAR(256) COLLATE ARABIC_CI_AI,
		Unit			INT,
		MtUnit2 		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		MtUnit3			NVARCHAR(256) COLLATE ARABIC_CI_AI,

		mtUnitFact		FLOAT,
	
		[Avg]				FLOAT,
		-- pCount			FLOAT,
		Cust			UNIQUEIDENTIFIER,
		UnitFact		FLOAT
	)
	INSERT INTO #FinalRes
	SELECT 
		m.BiMatPtr,
		m.MtName,
		m.MtCode,
		m.MtLatinName,
		m.mtUnitName,
		(CASE m.UnitNameInBill WHEN '' THEN mt.mtUnity ELSE m.UnitNameInBill END ) AS UnitNameInBill,
		m.Unit,
		mt.MtUnit2,
		mt.MtUnit3,
		m.mtUnitFact,
		m.[Avg],
		m.Cust,
		CASE m.Unit WHEN 1 THEN 1
					WHEN 2 THEN mt.mtUnit2Fact
					WHEN 3 THEN mtUnit3Fact END AS UnitFact
	FROM #MainRes AS m INNER JOIN vwmt AS mt On mt.mtGuid = m.BiMatPtr order by m.mtName

	DECLARE @CurrencyGUID UNIQUEIDENTIFIER
	SELECT @CurrencyGUID = GUID From my000 WHERE Number = 1
	-- return result set
	SELECT
		f.BiMatPtr,
		f.MtName,
		f.MtCode,
		F.MtLatinName,
		F.mtUnitName,
		f.UnitNameInBill,
		f.Unit,
		f.mtUnitFact,
		f.[Avg],
		f.Cust,
		f.UnitFact
	FROM 
		#FinalRes AS f
	SELECT *FROM #SecViol
END
###########################################
#END
