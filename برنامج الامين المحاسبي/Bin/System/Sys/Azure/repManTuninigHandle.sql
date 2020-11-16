###########################################################
### „⁄«·Ã… «·«‰Õ—«›

CREATE PROCEDURE GENENTRY_Deviation_Gen
AS
SET NOCOUNT ON
DECLARE  
 @BillGuidOut   UNIQUEIDENTIFIER,
 @BillGuidIn    UNIQUEIDENTIFIER,
 @entryGUIDOut  UNIQUEIDENTIFIER,
 @entryGUIDIN   UNIQUEIDENTIFIER,
 @Cur           UNIQUEIDENTIFIER,
 @BillNumberOut INT,
 @BillNumberIn  INT,
 @entryNumOut   INT,
 @entryNumIN    INT,
 @Total         FLOAT,
 @InBillType    UNIQUEIDENTIFIER,
 @OutBillType   UNIQUEIDENTIFIER,
 @InBillTypeGenEntry    BIT,
 @OutBillTypeGenEntry   BIT,
 @InStore	    UNIQUEIDENTIFIER,
 @OutStore	    UNIQUEIDENTIFIER,
 @InDate	    DATETIME,
 @OutDate	    DATETIME,
 @SpendAccount  UNIQUEIDENTIFIER,
 @TURING_STORAGE_COST   FLOAT

	EXECUTE prcNotSupportedInAzureYet
/*
SELECT @InBillType   = InBillType,
	   @OutBillType  = OutBillType,
	   @InStore      = InStore,
	   @OutStore     = OutStore,
	   @InDate       = InDate,
	   @OutDate      = OutDate,
	   @SpendAccount = SpendAccount
FROM ##Deviation_Gen_Params





SET @InBillTypeGenEntry = (SELECT TOP 1 bNoEntry FROM BT000 WHERE GUID = @InBillType)
SET @OutBillTypeGenEntry = (SELECT TOP 1 bNoEntry FROM BT000 WHERE GUID = @OutBillType)


SET	   @BillGuidOut		=  NEWID()
SET	   @BillGuidIn		=  NEWID()

SET	   @entryGUIDOut	=  NEWID()
SET	   @entryGUIDIn		=  NEWID()

SET	   @Cur				= (SELECT TOP 1 Guid			FROM my000	WHERE [CurrencyVal] = 1)
SELECT @BillNumberIn	= ISNULL(MAX(Number),  0 ) + 1	FROM bu000	WHERE  TypeGuid  = @InBillType

SELECT 
	FMGUID		,
	PARENTFORM	,
	FORMNAME	,
	MATGUID		,
	MATNAME		,
	INCOST		,
	OUTCOST		,
	INQTY		,
	STD_BALANCE ,
	MODEL_PRICE ,
	MODEL_COST	, 
	ACT_BALANCE ,
	ACT_BALANCE_PLUS_PREV_TURNING,
	ACT_PRICE   ,
	TURING      ,
	UNIT_TURING ,
	OUTQTY ,
	NEXT_LEVEL_TUNING,	   
	STORAGE,
	STD_STORAGE_COST,
	ACT_STORAGE_COST,
	TURING_STORAGE_COST,
	PREV_TURNING,
	Lvl
INTO #GENRESULT
FROM ##Deviation_Gen

BEGIN TRANSACTION

SELECT @Total						= ISNULL(SUM(STD_STORAGE_COST), 0)	FROM #GENRESULT		WHERE STD_STORAGE_COST > 0
SELECT @TURING_STORAGE_COST			= ISNULL(SUM(TURING_STORAGE_COST), 0)	FROM #GENRESULT

IF  (@Total > 0 AND @TURING_STORAGE_COST <> 0)
BEGIN 
		SELECT @BillNumberOut	=   ISNULL(MAX(Number),  0 ) + 1		
									FROM bu000			
									WHERE  TypeGuid = @OutBillType
									GROUP BY TypeGuid
		INSERT INTO Bu000
						   (
							  Guid			,
							  number		,
							  [Date]		,
							  Notes			,
							  PayType		,
							  TypeGuid		,
							  CurrencyGuid  ,
							  Total			,
							  CurrencyVal	,
							  StoreGuid		,
							  CustAccGUID
						  )    
		VALUES 
						  (		   
							  @BillGuidOut,
							  ISNULL(@BillNumberOut, 0x0 ) + 1,
							  @OutDate,
							  '›« Ê—… «Œ—«Ã „⁄«·Ã… «‰Õ—«› «·„Œ“Ê‰',
							  0,
							  @OutBillType ,
							  @Cur,
							  @Total,
							  1,
							  @OutStore,
							  @SpendAccount
						  )

		SELECT @BillNumberOut =  ISNULL( MAX(Number)	,0) + 1 FROM bi000

		INSERT  INTO bi000 
						(
							 Guid ,
							 Number,
							 Qty  ,
							 Unity,
							 Price,
							 CurrencyGuid,
							 CurrencyVal,
							 StoreGuid,
							 ParentGuid,
							 CostGuid,
							 MatGuid
						)    
		SELECT 	   
							NEWID() ,
							@BillNumberOut,
							STORAGE,
							1,
							ISNULL(STD_STORAGE_COST / STORAGE,0),
							@Cur,
							1.0,
							@OutStore,
							@BillGuidOut,
							ISNULL(INCOST , 0x0),
							MATGUID    
		FROM #GENRESULT 
		WHERE TURING_STORAGE_COST <> 0

		EXEC 	prcBill_post @BillGuidOut, 1
		IF (@OutBillTypeGenEntry = 0)
		BEGIN
			EXEC    prcBill_GenEntry @BillGuidOut
		END

		UPDATE bu000 set isposted = 1 WHERE guid = @BillGuidOut 
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------		SELECT @BillNumberIn	=   ISNULL( MAX(Number),  0 ) + 1		
---------------------------------------------------------------------------------------------------------------------------------------		
		SELECT @BillNumberIn	=   ISNULL( MAX(Number),  0 ) + 1		
									FROM      bu000			
									WHERE    TypeGuid = @InBillType
									GROUP BY TypeGuid

		SELECT @Total		 =  ISNULL( SUM(ACT_STORAGE_COST),0) FROM #GENRESULT WHERE ACT_STORAGE_COST > 0
		INSERT INTO Bu000
						   (
							  Guid			,
							  number		,
							  [Date]		,
							  Notes			,
							  PayType		,
							  TypeGuid		,
							  CurrencyGuid  ,
							  Total,
							  CurrencyVal,
							  StoreGUID,
							  CustAccGUID
						  )    
		VALUES 
						  (		   
							  @BillGuidIn,
							  ISNULL( @BillNumberIn , 0x0) ,
							  @InDate,
							  '›« Ê—… «œŒ«· „⁄«·Ã… «‰Õ—«› «·„Œ“Ê‰',
							  0,
							  @InBillType ,
							  @Cur,
							  @Total,
							  1,
							  @InStore,
							  @SpendAccount
						  )

		SELECT @BillNumberIn =  ISNULL( MAX(Number)	,0) + 1 FROM bi000

		INSERT  INTO bi000 
						(
							 Guid ,
							 Number,
							 Qty  ,
							 Unity,
							 Price,
							 CurrencyGuid,
							 CurrencyVal,
							 StoreGuid,
							 ParentGuid,
							 CostGuid,
							 MatGuid 
						)    
		SELECT 	   
							NEWID() ,
							@BillNumberIn,
							STORAGE,
							1,
							ISNULL(ACT_STORAGE_COST / STORAGE,0),
							@Cur,
							1.0,
							@InStore,
							@BillGuidIn,
							ISNULL(INCOST , 0x0),
							MATGUID    
		FROM #GENRESULT 
		WHERE TURING_STORAGE_COST <> 0
				
		EXEC 	prcBill_post @BillGuidIn, 1
		IF (@InBillTypeGenEntry = 0)
		BEGIN
			EXEC    prcBill_GenEntry @BillGuidIn
		END

		UPDATE bu000 set isposted = 1 WHERE guid = @BillGuidIn 
		DECLARE @NewBillNumberOut INT
		DECLARE @NewBillNumberIn INT
		
		SELECT @NewBillNumberOut	=   ISNULL(MAX(Number),  0 ) + 1		 
									FROM bu000			 
									WHERE  TypeGuid = @OutBillType 
									GROUP BY TypeGuid
		
		SELECT @NewBillNumberIn	=   ISNULL( MAX(Number),  0 ) + 1		 
									FROM      bu000			 
									WHERE    TypeGuid = @InBillType 
									GROUP BY TypeGuid 
		IF(@NewBillNumberOut <> @BillNumberOut)
			SELECT 1
		ELSE
			IF(@NewBillNumberIn <> @NewBillNumberIn)
				SELECT 1
END
COMMIT TRANSACTION
*/
###########################################################

CREATE PROCEDURE repManTuninigHandle
(	
	 @FROMDATE     DATETIME = '1-1-1980',
	 @TODATE       DATETIME   = '1-1-2070',
	 @STD_ACCGUID  UNIQUEIDENTIFIER = 0x0,
	 @ACT_ACCGUID  UNIQUEIDENTIFIER = 0x0,
	 @InBillType   UNIQUEIDENTIFIER = 0x0,
	 @OutBillType  UNIQUEIDENTIFIER = 0x0,
	 @InStore	   UNIQUEIDENTIFIER = 0x0,
	 @OutStore	   UNIQUEIDENTIFIER = 0x0,
	 @InDate	   DATETIME = '1-1-1980',
	 @OutDate	   DATETIME   = '1-1-2070',
	 @SpendAccount UNIQUEIDENTIFIER = 0x0,
	 @FormGuid	   UNIQUEIDENTIFIER = 0x0,
	 @DamagedBillTypeGuid	   UNIQUEIDENTIFIER = 0x0
)
AS
	EXECUTE prcNotSupportedInAzureYet
/*
	SET NOCOUNT ON
	DECLARE @SEMICONDUCT_OUTBILLTYPE UNIQUEIDENTIFIER
	DECLARE @Type INT
	SET @Type = 0

	SELECT SUM(q.BALANCE) BALANCE, q.COSTGUID COSTGUID
	INTO #STD_ACC
	FROM
	(
		SELECT CAST(SUM(EN.CREDIT) - SUM(EN.DEBIT) AS FLOAT) BALANCE ,COSTGUID
		FROM EN000 EN
		INNER JOIN CE000 CE												ON CE.GUID		= EN.PARENTGUID
		INNER JOIN [dbo].[fnGetAccountsList]( @STD_ACCGUID , 1) AccList ON AccList.GUID = EN.ACCOUNTGUID
		WHERE CE.[DATE] >= @FROMDATE AND CE.[DATE] <= @TODATE AND COSTGUID <> 0x0
		GROUP BY COSTGUID
	) q
	GROUP BY q.COSTGUID


	SELECT SUM(q.BALANCE) BALANCE, q.COSTGUID COSTGUID
	INTO #ACT_ACC
	FROM
	(
		SELECT CAST(SUM(EN.DEBIT) - SUM(EN.CREDIT) AS FLOAT)   BALANCE  ,COSTGUID
		FROM EN000 EN
		INNER JOIN CE000 CE												ON CE.GUID		= EN.PARENTGUID
		INNER JOIN [dbo].[fnGetAccountsList]( @ACT_ACCGUID , 1) AccList ON AccList.GUID = EN.ACCOUNTGUID
		WHERE CE.[DATE] >= @FROMDATE AND CE.[DATE] <= @TODATE  AND COSTGUID <> 0x0
		GROUP BY COSTGUID
	)q
	GROUP BY q.COSTGUID


	SELECT q.GUID GUID, SUM(q.QTY) QTY, q.COSTGUID COSTGUID
	INTO #IN_QTY
	FROM
	(
		SELECT MT.GUID , CAST(SUM(BI.QTY) AS FLOAT)  QTY , BI.COSTGUID
		FROM MT000 MT
		INNER JOIN BI000 BI ON BI.MATGUID    = MT.GUID
		INNER JOIN BU000 BU ON BU.GUID       = BI.PARENTGUID
		INNER JOIN BT000 BT ON BT.GUID       = BU.TYPEGUID
		WHERE BT.BILLTYPE =  4 AND BT.TYPE = 2  AND BU.[DATE] >=  @FROMDATE AND BU.[DATE] <= @TODATE AND BU.COSTGUID <> 0x0
		GROUP BY MT.GUID, BI.COSTGUID
	)q
	GROUP BY q.GUID , q.COSTGUID


	SET @SEMICONDUCT_OUTBILLTYPE = ISNULL(CAST((SELECT TOP 1 VALUE FROM OP000 WHERE NAME LIKE 'man_semiconduct_outbilltype') AS UNIQUEIDENTIFIER) , 0x0)

	SELECT q.GUID GUID, SUM(q.QTY) QTY, q.COSTGUID COSTGUID
	INTO #OUT_QTY
	FROM
	(
		SELECT MT.GUID , CAST(SUM(BI.QTY) AS FLOAT) QTY , BU.COSTGUID
		FROM MT000 MT
		INNER JOIN BI000 BI ON BI.MATGUID    = MT.GUID
		INNER JOIN BU000 BU ON BU.GUID       = BI.PARENTGUID
		INNER JOIN BT000 BT ON BT.GUID       = BU.TYPEGUID
		WHERE BT.GUID = @SEMICONDUCT_OUTBILLTYPE AND BU.[DATE] >=  @FROMDATE AND BU.[DATE] <= @TODATE AND BU.COSTGUID <> 0x0
		GROUP BY MT.GUID , BU.COSTGUID 
	)q
	GROUP BY q.GUID , q.COSTGUID

	SELECT 
		   FM.GUID					 FMGUID,
		   FM.PARENTFORM			 PARENTFORM,
		   MN.INCOSTGUID			 INCOSTGUID,
		   MN.OUTCOSTGUID			 OUTCOSTGUID,
		   MT.GUID					 MATGUID,
		   MI.PRICE / CASE MI.Unity WHEN 2 THEN MT.Unit2Fact WHEN 3 THEN Unit3Fact ELSE 1 END					 PRICE, 
		   MI.QTY					 QTY,
		   MI.PERCENTAGE / 100		 PERC
	INTO #FRMS_NAMES
	FROM MI000 MI
	INNER JOIN MN000 MN  ON MN.GUID       = MI.PARENTGUID
	INNER JOIN FM000 FM  ON FM.GUID       = MN.FORMGUID
	INNER JOIN MT000 MT  ON MT.GUID       = MI.MATGUID
	WHERE MI.TYPE = 0 AND MN.TYPE = 0 


	SELECT SUM(q.QTY) QTY, (SELECT TOP 1 MT.AVGPRICE FROM MT000 MT WHERE MT.GUID = q.MATGUID) PRICE , q.MATGUID MATGUID
	INTO #STORAGE_QTY
	FROM 
	( 
		SELECT ( (bi.QTY + bi.BonusQnt) * ( CASE bt.BillType 
							WHEN 0 THEN CASE bt.Type WHEN 3 THEN -1 WHEN 7 THEN -1 ELSE 1 END --„‘ —Ì«  
							WHEN 1 THEN -1 --„»Ì⁄« 
							WHEN 2 THEN -1 --„— Ã⁄ „‘ —Ì« 
							WHEN 3 THEN  1 --„— Ã⁄ „»Ì⁄« 
							WHEN 4 THEN  1 --«œŒ«·
							WHEN 5 THEN -1 --«Œ—«Ã
							ELSE 0 
							END  )) QTY,
	--			(bi.PRICE) PRICE,
				bi.MATGUID MATGUID,
				bt.name
		FROM bi000 bi
		INNER JOIN bu000 bu ON bu.GUID = bi.PARENTGUID
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
		WHERE bu.IsPosted = 1 AND BU.[DATE] >=  @FROMDATE AND BU.[DATE] <= @TODATE
	)q
	GROUP BY q.MATGUID
	--@DamagedBillTypeGuid

	SELECT -1 * SUM(q.QTY) QTY, q.MATGUID MATGUID
	INTO #DAMAGED_QTY
	FROM 
	( 
		SELECT (bi.QTY * ( CASE bt.BillType 
							WHEN 0 THEN  1 --„‘ —Ì« 
							WHEN 1 THEN -1 --„»Ì⁄« 
							WHEN 2 THEN -1 --„— Ã⁄ „‘ —Ì« 
							WHEN 3 THEN  1 --„— Ã⁄ „»Ì⁄« 
							WHEN 4 THEN  1 --«œŒ«·
							WHEN 5 THEN -1 --«Œ—«Ã
							ELSE 0 
							END  )) QTY,
				bi.MATGUID MATGUID,
				bt.name
		FROM bi000 bi
		INNER JOIN bu000 bu ON bu.GUID = bi.PARENTGUID
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
		WHERE bu.IsPosted = 1 AND bt.GUID = @DamagedBillTypeGuid AND BU.[DATE] >=  @FROMDATE AND BU.[DATE] <= @TODATE
	)q
	GROUP BY q.MATGUID

	SELECT 
		   FRM.FMGUID,
		   FRM.PARENTFORM,
		   CAST(FM.CODE AS NVARCHAR (255)) + '-' + FM.NAME																							FORMNAME		,
		   FRM.MATGUID																										,
		   MT.NAME																							MATNAME			,
		   ISNULL(FRM.INCOSTGUID  ,0x0)																		INCOST			,
		   ISNULL((		SELECT TOP 1	 
							   OUT_QTY.COSTGUID
						FROM   #OUT_QTY OUT_QTY  
						WHERE  OUT_QTY.GUID = FRM.MATGUID)  ,0x0) 											OUTCOST			,
		   ISNULL( (	SELECT TOP 1 
							   IN_QTY.QTY     
						FROM   #IN_QTY IN_QTY    
						WHERE  IN_QTY.GUID = FRM.MATGUID AND IN_QTY.COSTGUID = FRM.INCOSTGUID ) ,0 )		INQTY			,
		   ISNULL((		SELECT TOP 1 
							   BALANCE 
						FROM   #STD_ACC STD_ACC  
						WHERE  STD_ACC.COSTGUID = FRM.INCOSTGUID) ,0)										STD_BALANCE		,
		   FRM.PRICE																						MODEL_PRICE		,
		   FRM.PRICE * ISNULL( (	SELECT TOP 1 
							   IN_QTY.QTY     
						FROM   #IN_QTY IN_QTY    
						WHERE  IN_QTY.GUID = FRM.MATGUID AND IN_QTY.COSTGUID = FRM.INCOSTGUID ) ,0 )		MODEL_COST		,
		   ISNULL((		SELECT TOP 1 
							   BALANCE 
						FROM   #ACT_ACC ACT_ACC  
						WHERE  ACT_ACC.COSTGUID = FRM.INCOSTGUID) ,0)										ACT_BALANCE		,
		   CAST(0 AS FLOAT)																					LOAD_COST		,
		   CAST(0 AS FLOAT)																					ACT_BALANCE_PLUS_PREV_TURNING,
		   CAST(0 AS FLOAT)																					ACT_PRICE		,
		   CAST(0 AS FLOAT)																					TURING			,
		   CAST(0 AS FLOAT)																					UNIT_TURING		,
		   ISNULL( (	SELECT TOP 1 
						OUT_QTY.QTY
						FROM   #OUT_QTY OUT_QTY  
						WHERE  OUT_QTY.GUID = FRM.MATGUID 
						   AND OUT_QTY.COSTGUID = ISNULL((		SELECT TOP 1	 
												  OUT_QTY.COSTGUID
												  FROM   #OUT_QTY OUT_QTY  
												  WHERE  OUT_QTY.GUID = FRM.MATGUID)  ,0x0)) ,0 )			OUTQTY			,
		   CAST(0 AS FLOAT)																					NEXT_LEVEL_TUNING,	   
		   CAST(ISNULL( STRG_QTY.QTY   ,0 ) AS FLOAT)														STORAGE			,
		   CAST(0 AS FLOAT)																					STD_STORAGE_COST,
		   CAST(0 AS FLOAT)																					ACT_STORAGE_COST,
		   CAST(0 AS FLOAT)    																				TURING_STORAGE_COST,
		   CAST(ISNULL( STRG_QTY.PRICE ,0 ) AS FLOAT)														AVG_STORE_PRICE,
		   ISNULL( (	SELECT TOP 1 
						DAMAGED_QTY.QTY
						FROM   #DAMAGED_QTY DAMAGED_QTY  
						WHERE  DAMAGED_QTY.MATGUID = FRM.MATGUID ) ,0)											DAMAGED_QTY
	INTO #RESULT
	FROM #FRMS_NAMES			FRM
	INNER JOIN FM000			FM			 ON FRM.FMGUID		     = FM.GUID
	INNER JOIN MT000			MT			 ON FRM.MATGUID		     = MT.GUID
	LEFT JOIN #STORAGE_QTY		STRG_QTY	 ON STRG_QTY.MATGUID	 = MT.GUID	
	ORDER BY FM.Code, FM.NAME

	DECLARE @Level INT
	DECLARE @RES1CNT INT
	SET @Level = 0
	SET @RES1CNT = 1

	CREATE TABLE #RESSSSS
	(
		FMGUID UNIQUEIDENTIFIER,
		PARENTFORM UNIQUEIDENTIFIER,
		LVL INT
	)


	IF (@FormGuid <> 0x0)
	BEGIN
		INSERT INTO #RESSSSS
		SELECT FMGUID,PARENTFORM , 0 LVL
		FROM #RESULT
		WHERE FMGUID = @FormGuid
	END
	ELSE
	BEGIN
		INSERT INTO #RESSSSS
		SELECT FMGUID,PARENTFORM , 0 LVL
		FROM #RESULT
		WHERE PARENTFORM = @FormGuid
	END

 
	WHILE (@RES1CNT > 0)
	BEGIN
		INSERT INTO #RESSSSS
		 SELECT FMGUID,PARENTFORM , @Level + 1 LVL
		 FROM #RESULT
		 WHERE PARENTFORM IN ( SELECT FMGUID FROM #RESSSSS WHERE LVL = @Level)
		SET @Level = @Level + 1

		SET @RES1CNT = ( SELECT COUNT(*) FROM  #RESULT WHERE PARENTFORM IN ( SELECT FMGUID FROM #RESSSSS WHERE LVL = @Level)  ) 
	END

	SET @Level = (SELECT MAX(LVL) FROM #RESSSSS)
	SET @RES1CNT = 1

	SELECT *,CAST(0 AS FLOAT) PREV_TURNING, @Level Lvl 
	INTO #RESULT1
	FROM #RESULT 
	WHERE FMGUID IN (SELECT FMGUID FROM #RESSSSS WHERE LVL = @Level)


	DECLARE @TempNumb BIT 
	SET @TempNumb = 0

	WHILE (@RES1CNT > 0)
	BEGIN
			UPDATE #RESULT1 
				SET  ACT_BALANCE_PLUS_PREV_TURNING = ISNULL(PREV_TURNING,0)                   + ISNULL(ACT_BALANCE,0) 
      
			UPDATE #RESULT1 
				SET  ACT_PRICE					   = ISNULL(ACT_BALANCE_PLUS_PREV_TURNING,0)  / (INQTY - DAMAGED_QTY)
						WHERE (INQTY - DAMAGED_QTY) <> 0             

			UPDATE #RESULT1 
				SET  TURING					       = ISNULL(ACT_BALANCE_PLUS_PREV_TURNING,0)  - ISNULL(STD_BALANCE,0) 
      
			UPDATE #RESULT1 
				SET  UNIT_TURING				   = ISNULL(ACT_PRICE,0)                      - ISNULL(MODEL_PRICE,0)
  
			UPDATE #RESULT1 
				SET  LOAD_COST					   = ISNULL(ABS(STD_BALANCE),0)			      - ISNULL(ABS(MODEL_COST),0)
       
			UPDATE #RESULT1 
				SET  NEXT_LEVEL_TUNING		       = (ISNULL(OUTQTY,0)		                  * ISNULL(UNIT_TURING,0))

       		UPDATE #RESULT1 
				SET  NEXT_LEVEL_TUNING		       = 0		
				WHERE INQTY = 0

			UPDATE #RESULT1 
				SET  ACT_STORAGE_COST		       = ISNULL(STORAGE,0)						  * ISNULL(ACT_PRICE,0)
         
			UPDATE #RESULT1 
				SET  STD_STORAGE_COST		       = ISNULL(STORAGE,0)		                  * ISNULL(AVG_STORE_PRICE,0)
        
			UPDATE #RESULT1 
				SET  TURING_STORAGE_COST		   = ISNULL(ACT_STORAGE_COST,0)			      - ISNULL(STD_STORAGE_COST,0)

		INSERT INTO #RESULT1
		SELECT DISTINCT
				 *,
				 (  SELECT SUM(NEXT_LEVEL_TUNING)
					FROM #RESULT1 
					WHERE PARENTFORM = RES.FMGUID 
					GROUP BY PARENTFORM)  - (ISNULL(ABS(STD_BALANCE),0)  - ISNULL(ABS(MODEL_COST),0)) PREV_TURNING,
				 @Level - 1										Lvl  
		FROM  #RESULT RES
		WHERE FMGUID IN ( SELECT FMGUID FROM #RESSSSS WHERE LVL = @Level - 1)

		SET @Level = @Level - 1

		SET @RES1CNT = ( SELECT COUNT(*) FROM #RESSSSS WHERE LVL = @Level - 1) 

		IF (@RES1CNT = 0 AND @TempNumb = 0)
		BEGIN
			SET @TempNumb = 1
			SET @RES1CNT  = 1
		END
	END
		IF EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '##Deviation_Gen')
			DROP TABLE ##Deviation_Gen

		IF EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '##Deviation_Gen_Params')
			DROP TABLE ##Deviation_Gen_Params

	DELETE FROM #RESULT1 WHERE INQTY = 0

	SELECT * 
		INTO ##Deviation_Gen
		FROM #RESULT1 
		ORDER BY Lvl

	SELECT @InBillType   InBillType,
		   @OutBillType  OutBillType,
		   @InStore      InStore,
		   @OutStore     OutStore,
		   @InDate		 InDate,
		   @OutDate		 OutDate,
		   @SpendAccount SpendAccount
	INTO ##Deviation_Gen_Params

	SELECT MatGuid,
		MatName, 
		INQTY, 
		DAMAGED_QTY, 
		(INQTY - DAMAGED_QTY) SavedQty,
		CO.NAME InCostName,
		OUTQTY,
		CO2.NAME OutCostName,
		MODEL_PRICE,
		MODEL_COST,
		STD_BALANCE,
		LOAD_COST,
		ACT_BALANCE,
		PREV_TURNING,
		ACT_BALANCE_PLUS_PREV_TURNING,
		ACT_PRICE,
		TURING,
		UNIT_TURING,
		NEXT_LEVEL_TUNING,
		STORAGE,
		AVG_STORE_PRICE,
		STD_STORAGE_COST,
		ACT_STORAGE_COST,
		TURING_STORAGE_COST	
	FROM #RESULT1 RES
		INNER JOIN CO000 CO ON RES.INCOST = CO.GUID
		LEFT JOIN CO000 CO2 ON RES.OUTCOST = CO2.GUID
	*/
###########################################################
#END
