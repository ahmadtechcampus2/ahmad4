###########################################################################
CREATE FUNCTION fnGetMatDataByRelatedEntry
(
)
RETURNS 
@table TABLE 
(
	AccGUID UNIQUEIDENTIFIER,
	MatGroup  UNIQUEIDENTIFIER,
	MatGUID UNIQUEIDENTIFIER,
	MatName NVARCHAR(256), 
	MatQuantity FLOAT,
	MatUnityName NVARCHAR(256),
	MatPrice FLOAT,
	EntryGUID UNIQUEIDENTIFIER,
	EnGUID UNIQUEIDENTIFIER,
	BiGUID UNIQUEIDENTIFIER
)
AS
BEGIN

	INSERT INTO @table
	SELECT
		en.enAccount,
		vbi.mtGroup,
		vbi.biMatPtr,
		vbi.mtName, 
		(CASE WHEN (en.enAccount = (SELECT DefaultCostAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))
					OR (en.enAccount = (SELECT DefaultStockAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))
			THEN 
				ISNULL((CASE WHEN en.enDebit <> 0 THEN en.enDebit ELSE en.enCredit END) / (SELECT [dbo].[fnGetMatDataAvgPrice](en.ceGUID, vbi.biMatPtr))
				/ 
				(CASE vbi.biUnity
					WHEN 1 THEN 1
					WHEN 2 THEN (CASE WHEN mtUnit2Fact <> 0 THEN mtUnit2Fact ELSE 1 END)
					WHEN 3 THEN (CASE WHEN mtUnit3Fact <> 0 THEN mtUnit3Fact ELSE 1 END)
					ELSE (CASE WHEN mtDefUnitFact <> 0 THEN mtDefUnitFact ELSE 1 END)
				END), 0)
			ELSE 
				(CASE WHEN (bt.btConsideredGiftsOfSales = 1) AND (en.enAccount = (SELECT DefaultMatsAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))
					THEN vbi.biBillBonusQnt + vbi.biBillQty
					ELSE
						(CASE WHEN (en.enAccount = (SELECT DefaultBonusAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID))) 
									OR (en.enAccount = (SELECT DefaultBonusContraAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))  
									OR ((bt.btConsideredGiftsOfSales = 1) AND (en.enAccount = vbi.buCustAcc)) 
							THEN vbi.biBonusQnt 
							ELSE vbi.biQty 
						END) /
						(CASE vbi.biUnity
							WHEN 1 THEN 1
							WHEN 2 THEN (CASE WHEN mtUnit2Fact <> 0 THEN mtUnit2Fact ELSE 1 END)
							WHEN 3 THEN (CASE WHEN mtUnit3Fact <> 0 THEN mtUnit3Fact ELSE 1 END)
							ELSE (CASE WHEN mtDefUnitFact <> 0 THEN mtDefUnitFact ELSE 1 END)
						END)
				END) 
		END),
		vbi.MtUnityName,
		vbi.biPrice,
		en.ceGUID,
		en.enGUID,
		en.enBiGUID
	FROM 
		vwEr er
		inner join vwExtended_en en on er.erEntryGUID = en.ceGUID
		inner join vwExtended_bi vbi on er.erParentGUID = vbi.buGuid AND en.enBiGUID = vbi.biGUID
		inner join vwBt bt on vbi.buType = bt.btGUID
	WHERE 
		en.enBiGUID <> 0x0

	INSERT INTO @table
	SELECT
		en.enAccount,
		vbi.mtGroup,
		vbi.biMatPtr,
		vbi.mtName, 
		(CASE WHEN (en.enAccount = (SELECT DefaultCostAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))
					OR (en.enAccount = (SELECT DefaultStockAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))
			THEN 
				ISNULL((CASE WHEN en.enDebit <> 0 THEN en.enDebit ELSE en.enCredit END) / (SELECT [dbo].[fnGetMatDataAvgPrice](en.ceGUID, vbi.biMatPtr))
				/ 
				(CASE vbi.biUnity
					WHEN 1 THEN 1
					WHEN 2 THEN (CASE WHEN mtUnit2Fact <> 0 THEN mtUnit2Fact ELSE 1 END)
					WHEN 3 THEN (CASE WHEN mtUnit3Fact <> 0 THEN mtUnit3Fact ELSE 1 END)
					ELSE (CASE WHEN mtDefUnitFact <> 0 THEN mtDefUnitFact ELSE 1 END)
				END), 0)
			ELSE 
				(CASE WHEN (bt.btConsideredGiftsOfSales = 1) AND (en.enAccount = (SELECT DefaultMatsAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))
					THEN vbi.biBillBonusQnt + vbi.biBillQty
					ELSE
						(CASE WHEN (en.enAccount = (SELECT DefaultBonusAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID))) 
									OR (en.enAccount = (SELECT DefaultBonusContraAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](en.ceGUID)))  
									OR ((bt.btConsideredGiftsOfSales = 1) AND (en.enAccount = vbi.buCustAcc)) 
							THEN vbi.biBonusQnt 
							ELSE vbi.biQty 
						END) /
						(CASE vbi.biUnity
							WHEN 1 THEN 1
							WHEN 2 THEN (CASE WHEN mtUnit2Fact <> 0 THEN mtUnit2Fact ELSE 1 END)
							WHEN 3 THEN (CASE WHEN mtUnit3Fact <> 0 THEN mtUnit3Fact ELSE 1 END)
							ELSE (CASE WHEN mtDefUnitFact <> 0 THEN mtDefUnitFact ELSE 1 END)
						END)
				END) 
		END),
		vbi.MtUnityName,
		vbi.biPrice,
		en.ceGUID,
		en.enGUID,
		en.enBiGUID
	FROM 
		vwEr er
		inner join vwExtended_en en on er.erEntryGUID = en.ceGUID
		inner join vwExtended_bi vbi on en.enBiGUID = vbi.biGUID
		inner join vwBt bt on vbi.buType = bt.btGUID 
		inner join vwPy py on er.erParentGUID = py.pyGUID
	WHERE 
		en.enBiGUID <> 0x0 
	RETURN 
END
###########################################################################
CREATE PROCEDURE prcGeneralLedger
	@IsCalledByWeb BIT,
	@Account [UNIQUEIDENTIFIER],			-- Account  
	@CustGUID [UNIQUEIDENTIFIER],			-- Customer
	@CostGuid [UNIQUEIDENTIFIER],			-- Cost Job 
	@MatGUID  [UNIQUEIDENTIFIER],
	@GroupGUID [UNIQUEIDENTIFIER],
	@FromCheckDate [INT], 				-- From Last Check Date  
	@StartDate [DATETIME],	             
	@EndDate [DATETIME],		             
	@CurGUID [UNIQUEIDENTIFIER],		     
	-- @CurVal [FLOAT],				     
	@Class [NVARCHAR](256),				-- Class     
	@ShowUnPosted [INT],  				   
	@Level [INT],  						-- Level For Account     
	@Contain [NVARCHAR](256),				-- The Note Of Entry contain ...     
	@NotContain [NVARCHAR](256),			-- The Note Of Entry Not contain ...     
	@PrevBalance [INT],					-- 0 Without PrvBalance - 1 PrvBalance Without CheckContain - 2 PrvBalance With CheckContain     
	@ObverseAcc [UNIQUEIDENTIFIER] = 0x0,-- Fillter Entry with Obverse Account      
	@UnifyAccEn [INT] = 0,				-- 0: let the entry , 1: merge the entry for same Account     
	@ShowIsCheck [INT] = 0,				-- إظهار حقل الدقيق
	@rid [FLOAT] = 0,					-- لتمييز rch بين تقرير دفتر الأستاذ وحركة إجمالي الفواتير 
	@ItemChecked		[INT] = 0,				-- إظهار المدقق / غير المدقق : 0, 1, 2, 3 
	@ShowEmptyBal		[INT] = 1,			-- إظهار الحسابات الفارغة 
	@CheckForUsers		[INT] = 0,			-- حقل التدقيق للمستخدم أم عام 
	@CollectCheck		[INT] = 0	,			-- دمج سندات الأوراق المالية ذات نفس الرقم 
	@User				UNIQUEIDENTIFIER = 0X00, 
	@ShwUser			BIT = 0, 
	@SrcGuid		    [UNIQUEIDENTIFIER] = 0X0,
	@EntryCond		[UNIQUEIDENTIFIER] = 0X0,
	@BillCond		[UNIQUEIDENTIFIER] = 0X0,
	@FromPostDate [DATETIME] = '1980-1-1',
	@ToPostDate [DATETIME] = '2100-1-1',
	@IsFilterByDate BIT = 1,
	@IsFilterByPostDate BIT = 1, 
	@DetialByAccountCurrency BIT = 0 ,-- تفصيل حسب عملة الحساب
	@ShowRelatedMatInfo BIT = 0,
	@IsGroupedByCost [BIT] = 0,
	@IsGroupedByClass [BIT] = 0,
	@ShowRunningBalance [BIT] = 0,
	@ShowObverseAcc   BIT = 0,
	@ShowMainAcc [BIT] = 0,
	@NoAccessStr [NVARCHAR](256)
AS        
	SET NOCOUNT ON   
	  
	DECLARE @strContain AS [NVARCHAR]( 1000)       
	DECLARE @strNotContain AS [NVARCHAR]( 1000)       
	SET @strContain = N'%'+ @Contain + '%'       
	SET @strNotContain = N'%'+ @NotContain + '%'       
	DECLARE 
		@IsSingl		[BIT],
		@IsNormalAcc	[BIT],
		@cmpUnmctch		[BIT]
	SET @IsSingl = 1	
	SET @cmpUnmctch	= 1	-- default option value 1 
	SET @IsNormalAcc = 1
	IF EXISTS(SELECT * FROM [ac000] WHERE [ParentGUID] = @Account) 
		OR EXISTS(SELECT * FROM [ac000] WHERE [GUID] = @Account AND [Type] != 1)
		SET @IsSingl = 0
	IF EXISTS(SELECT * FROM [ac000] WHERE [GUID] = @Account AND [Type] != 1)
		SET @IsNormalAcc = 0
	IF EXISTS(SELECT * FROM [op000] WHERE [Name] = 'AmnCfg_UnmatchedMsg' AND [Type] = 0 AND Value = '0')
		SET @cmpUnmctch	= 0
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#ENTRY]  ([GUID] UNIQUEIDENTIFIER ,[SEC] INT ) 
	CREATE TABLE [#BILLENTRY]  ([GUID] UNIQUEIDENTIFIER ,[SEC] INT ) 
	CREATE TABLE [#Bill]  ([GUID] UNIQUEIDENTIFIER ,[SEC] INT) 
	INSERT INTO [#ENTRY] EXEC prcGetEntriesList @EntryCond 
	CREATE TABLE [#RelatedMat] (
		AccGUID UNIQUEIDENTIFIER,
		MatGroup  UNIQUEIDENTIFIER,
		MatGUID UNIQUEIDENTIFIER,
		MatName NVARCHAR(256), 
		MatQuantity FLOAT,
		MatUnityName NVARCHAR(256),
		EntryGUID UNIQUEIDENTIFIER,
		EnGUID UNIQUEIDENTIFIER,
		BiGUID UNIQUEIDENTIFIER,
		MatPrice FLOAT
	)
	
	------------------------------------------------------------------ 
	DECLARE @HaveCFldCondition int ,@Criteria NVARCHAR (max) 
	SET @HaveCFldCondition = 0 
	IF @BillCond <> 0X00  
	BEGIN  
		SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCond,@CurGUID)  
		IF @Criteria <> ''  
		BEGIN  
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields  
			BEGIN  
				SET @HaveCFldCondition = 1  
				SET @Criteria = REPLACE(@Criteria,'<<>>','')   
			 
			END  
			SET @Criteria = '(' + @Criteria + ')'  
		END  
	END 
	ELSE  
		SET @Criteria = ''  

	DECLARE @lang INT 
	SET @lang = [dbo].[fnConnections_GetLanguage]()
------------------------------------------------------------------------------------------------------- 
-- Inserting Condition Of Custom Fields  
--------------------------------------------------------------------------------------------------------  
	DECLARE @S NVARCHAR(max) 
	IF(@BILLCOND <> 0x0) 
	BEGIN 
		SET @s = ' SELECT buGuid, buSecurity FROM vwBuBi_Address' 
		IF (@HaveCFldCondition =  1) 
		BEGIN  
			DECLARE @CF_Table1 NVARCHAR(255)  
			SET @CF_Table1 = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000') 	 
			SET @s = @s + ' INNER JOIN ' + @CF_Table1 + ' ON buGuid = ' + @CF_Table1 + '.Orginal_Guid '  
		END  
		SET @s = @s + ' WHERE 1=1 ' 
		IF @Criteria <> '' 
			SET @s = @s + ' AND ' + @Criteria 
		INSERT INTO [#BILL] EXEC (@s) 
		INSERT INTO [#BILLENTRY] SELECT ce.GUID , ce.SECURITY FROM CE000 ce INNER JOIN ER000 er ON Ce.GUID = er.ENTRYGUID WHERE PARENTTYPE = 2 AND PARENTGUID IN (SELECT GUID FROM [#BILL]) 
	END 
	------------------------------------------------------------------ 
	--INSERT INTO [#BILL] EXEC PrcGetBillsList @BillCond 
	------------------------------------------      
	CREATE TABLE #Account_Tbl(
		[GUID] [UNIQUEIDENTIFIER],
		[Level] [INT],
		CheckDate [DATETIME],
		[Path] [NVARCHAR](4000) ,
		acCode [NVARCHAR](250) ,
		[acName] [NVARCHAR](250) ,
		[acLatinName] [NVARCHAR](250) ,
		[acSecurity] INT,
		CurrencyGUID UNIQUEIDENTIFIER);
	IF( @IsSingl <> 1)  
		INSERT INTO #Account_Tbl SELECT [fn].[GUID], [fn].[Level], '1-1-1980', [fn].[Path],[Code],[Name],[LatinName],[Security], ac.CurrencyGUID FROM [dbo].[fnGetAccountsList]( @Account, 1) AS [Fn] INNER JOIN [ac000] AS [ac] ON [Fn].[GUID] = [ac].[GUID]  WHERE ((@DetialByAccountCurrency = 1 AND AC.Type = 1 AND AC.NSons = 0) OR @DetialByAccountCurrency = 0)
	ELSE  
		INSERT INTO #Account_Tbl SELECT [acGUID], 0, '1-1-1980', '',[acCode],[acName],[acLatinName], [acSecurity], acCurrencyPtr  FROM [vwAc] WHERE [acGUID] = @Account AND ((@DetialByAccountCurrency = 1 AND acType = 1 AND acNSons = 0) OR @DetialByAccountCurrency = 0)
	IF( @FromCheckDate = 1)  
		UPDATE Acc SET CheckDate = ch.CheckedToDate  
		FROM   
			#Account_Tbl Acc  
			INNER JOIN (   
				SELECT AccGUID, MAX( CheckedToDate) CheckedToDate   
				FROM checkAcc000   
				WHERE CheckedToDate < @EndDate GROUP BY AccGUID) ch  
			ON Acc.Guid = ch.AccGUID  
	CREATE CLUSTERED INDEX  Account_TblIND ON #Account_Tbl(Guid)  
	CREATE TABLE #AccObverse_Tbl  ( [GUID] [UNIQUEIDENTIFIER],  
					[acCode] [NVARCHAR](250) ,  
					[acName] [NVARCHAR](250) ,  
					[acLatinName] [NVARCHAR](250) ,  
					[acSecurity] [INT])   
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])        
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])    
	IF( ISNULL( @ObverseAcc, 0x0) = 0x0)   
	BEGIN  
		INSERT INTO #AccObverse_Tbl  
			SELECT   
				[GUID], [Code], [Name], [LatinName], [Security]   
			FROM [ac000]   
			union all   
			select   
				0x00, '', '', '', 0  
			-- IF @ShowContraAcc = 0  
			--	UPDATE #AccObverse_Tbl SET  [acCode] = '', [acName] = '', [acLatinName] = '', [acSecurity]  = 0  
			  
	END  
	ELSE   
		INSERT INTO #AccObverse_Tbl   
			SELECT   
				[fn].[GUID], [ac].[Code], [ac].[Name], [ac].[LatinName], [ac].[Security]  
			FROM   
				[ac000] as [ac] INNER JOIN [dbo].[fnGetAccountsList]( @ObverseAcc, 0) AS [Fn]   
				ON [ac].[GUID] = [fn].[GUID]  
	CREATE CLUSTERED INDEX  AccObverse_TblIND ON #AccObverse_Tbl(Guid)  
	------------------------------------------   
	CREATE TABLE #Cost_Tbl ( [GUID] [UNIQUEIDENTIFIER])   
	INSERT INTO #Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGuid)    
	IF ISNULL( @CostGuid, 0x0) = 0x0     
		INSERT INTO #Cost_Tbl VALUES(0x00)    
	-------------------------------------------------------------------------------------- 
	CREATE TABLE [#MatTbl]( [MatGUID] UNIQUEIDENTIFIER, [mtSecurity] [INT])
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID
	IF (ISNULL( @GroupGUID, 0x0) = 0x0 AND ISNULL( @MatGUID, 0x0) = 0x0)    
		INSERT INTO #MatTbl VALUES(0x00, 0) 
	IF (@ShowRelatedMatInfo = 1)
	BEGIN
		INSERT INTO [#RelatedMat]
		SELECT 
			AccGUID, 
			MatGroup,
			E.MatGUID,
			MatName,
			MatQuantity,
			MatUnityName,
			EntryGUID,
			EnGUID,
			BiGUID,
			MatPrice
		FROM 
			fnGetMatDataByRelatedEntry() AS E
			JOIN #MatTbl AS M ON E.MatGUID = M.MatGUID 
	END
	ELSE
	BEGIN
		INSERT INTO [#RelatedMat]
		SELECT
			0x0,
			0x0,
			0x0,
			'',
			0,
			'',
			0x0,
			0x0,
			0x0,
			0
	END
	--------------------------------------------------------------------------------------
	--Source   
	DECLARE  @UserId [UNIQUEIDENTIFIER],@HosGuid [UNIQUEIDENTIFIER]  
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()  
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID 
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID        
      
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID        
	    
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]    
	DECLARE @str NVARCHAR(1000) 
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0    
	BEGIN		    
		SET @str = 'INSERT INTO [#EntryTbl]    
		SELECT    
					[IdType],    
					[dbo].[fnGetUserSec](''' + CAST(@UserID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1)    
				FROM    
					[dbo].[RepSrcs] AS [r]     
					INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid]    
				WHERE    
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + ''''    
		EXEC(@str)    
	END    
	 
	IF [dbo].[fnObjectExists]( 'vwTrnExchangeTypes') <> 0    
	BEGIN		    
		SET @str = 'INSERT INTO [#EntryTbl]    
		SELECT    
					[IdType],    
					[dbo].[fnGetUserSec](''' + CAST(@UserID AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1)    
				FROM    
					[dbo].[RepSrcs] AS [r]     
					INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid]    
				WHERE    
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + ''''    
		EXEC(@str)    
	END 			    
				    
	DECLARE @IsOneCurrency BIT;
	
	IF (SELECT COUNT(GUID) FROM my000 ) = 1
		SET @IsOneCurrency = 1;
	ELSE
		SET @IsOneCurrency = 0;

	IF EXISTS(SELECT * FROM [dbo].[RepSrcs] WHERE [IDSubType] = 303)    
		INSERT INTO [#EntryTbl] VALUES(@HosGuid,0)     
	------------------------------------------------------------------------------------------------------------------------   
	--  1 - Get the balance of Accounts     
	--  2 - Get the Previos balance of Accounts (option)      
	------------------------------------------------------------------------------------------------------------------------      
	-- STEP 1   
	
	CREATE TABLE [#Result] (      
			[CeGUID] [UNIQUEIDENTIFIER],      
			[enGUID] [UNIQUEIDENTIFIER],   
			[CeNumber] [FLOAT],      
			[ceDate] [DATE],      
			[enNumber] [FLOAT],      
			[AccGUID] [UNIQUEIDENTIFIER],      
			[acCode] [NVARCHAR](250) ,  
			[acName] [NVARCHAR](250) ,  
			[acLatinName] [NVARCHAR](250) ,
			[matGUID] [UNIQUEIDENTIFIER],      
			[matName]   [NVARCHAR](250) ,
			[matQuantity] [FLOAT],
			[matUnityName]  [NVARCHAR](250),
			[enDebit]	[FLOAT],      
			[enCredit] [FLOAT],      
			[enFixDebit] [FLOAT],      
			[enFixCredit] [FLOAT],      
			[enCurPtr] [UNIQUEIDENTIFIER],      
			[enCurCode] [NVARCHAR](250) ,  
			[enCurVal] [FLOAT] DEFAULT 0,      
			[ObvacGUID] [UNIQUEIDENTIFIER],      
			[ObvacCode] [NVARCHAR](250),  
			[ObvacName] [NVARCHAR](250),  
			[ObvacLatinName] [NVARCHAR](250),  
			[Class] [NVARCHAR](250),
			[CostGuid] [UNIQUEIDENTIFIER],      
			[enNotes] [NVARCHAR](1000),
			[ceNotes] [NVARCHAR](1000),
			[ceParentGUID] [UNIQUEIDENTIFIER],       
			[ceRecType] [INT],       
			[Path] [NVARCHAR](4000),      
			[Type] [INT],      
			[PrevBalance] [FLOAT],      
			[Security] [INT],      
			[accSecurity] [INT],    
			--AccSecurity [INT],  
			[ParentNumber] [INT],   
			[ParentName] [NVARCHAR](250) ,   
			[IsCheck]  [INT] DEFAULT 0,  
			[ceTypeGuid] [UNIQUEIDENTIFIER],  
			[NtNumber] [NVARCHAR](250) , -- Note Number  
			[NtFlg] INT,  
												-- Consolidate Notes?   
			[Branch] [UNIQUEIDENTIFIER],  
			[UserName] NVARCHAR(100) ,  
			[Posted] BIT DEFAULT 1, 
			[CeParentType]	INT, 
			[UserSecurity]		[INT], 
			[PostDate] [DATETIME],
			[IsDetail] [BIT] DEFAULT (0), 
			[BillGUID] UNIQUEIDENTIFIER DEFAULT (0x0),
			[PaymentGUID] UNIQUEIDENTIFIER DEFAULT (0x0),
			[ChequeGUID] UNIQUEIDENTIFIER DEFAULT (0x0),
			[SumCheckedBalance] FLOAT DEFAULT(0),
			[MatPrice] FLOAT
			)     
	---------------------------------------------------------------------------------------------  
	DECLARE @Sec INT 
	SET @Sec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](),0X00) 

	INSERT INTO [#Result]      
		SELECT      
			[ceGUID],       
			CASE WHEN @UnifyAccEn = 1 THEN 0x00 ELSE [CE].[enGUID] END,   
			[ceNumber],       
			[enDate],      
			CASE WHEN @UnifyAccEn = 1 THEN 0 ELSE [enNumber] END,   
			[enAccount],      
			[ac].[acCode],  
			[ac].[acName],  
			[ac].[acLatinName], 
			[Mat].[MatGUID],
			[Mat].[MatName],
			[Mat].[MatQuantity],
			[Mat].[MatUnityName],
			SUM([enDebit]),      
			SUM([enCredit]),      
			SUM([EnDebit] * FACTOR),      
			SUM([EnCredit] * FACTOR),      
			[enCurrencyPtr],      
			[my].[Code],      
			[enCurrencyVal], 
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN 0x0 ELSE [AcObv].[GUID] END,
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN '' ELSE [AcObv].[acCode] END,     
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN '' ELSE [AcObv].[acName] END,     
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN '' ELSE [AcObv].[acLatinName] END,  
			CASE @UnifyAccEn 
				WHEN 1 THEN CASE @IsGroupedByClass WHEN 1 THEN [enClass] ELSE 0x0 END
				ELSE [enClass]
			END,
			CASE @UnifyAccEn 
				WHEN 1 THEN CASE @IsGroupedByCost WHEN 1 THEN [enCostPoint] ELSE 0x0 END
				ELSE [enCostPoint]
			END,
			CASE WHEN @UnifyAccEn = 1 THEN [ceNotes] ELSE [enNotes] END,  
			[ceNotes],      
			ISNULL(ER.ParentGUID, 0x0),		--ParentGUID,    
			CASE WHEN @CollectCheck = 0 THEN ISNULL(ER.ParentType, 0) ELSE 0 END,		--ceRecType,    
			[AC].[Path],      
			1, 		-- 0 Main Account 1 Sub Account      
			0,      
			[ceSecurity],      
			[ac].[acSecurity],    
			--AcObv.acSecurity,  
			ISNULL(er.ParentNumber,0),		--ceParentNumber,   
			CASE WHEN [bt].btGUID IS NULL THEN N'' ELSE (case @lang when 0 then [bt].[btAbbrev] else [bt].[btLatinAbbrev]  end) END,	--ceTypeAbbrev,   
			0, 		-- isCheck   
			[ceTypeGuid],  
			'', 		-- NtNumber  
			0, 
			[ceBranch],
			'',
			ceIsPosted,
			er.ParentType,
			ISNULL(src.[Security],@Sec),
			CePostDate,
			1,
			CASE WHEN [bt].btGUID IS NULL THEN 0x0 ELSE ISNULL(ER.ParentGUID, 0x0) END,
			0x0,
			0x0,
			0,
			Mat.MatPrice * FACTOR
		FROM     
			vwCeEn CE
			INNER JOIN #Account_Tbl AS [AC] ON [CE].[enAccount] = [AC].[GUID]
			JOIN ac000 AS ACD ON ACD.[GUID] = [AC].[GUID]
			INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]    
			INNER JOIN #AccObverse_Tbl AS [AcObv] ON  [CE].[enContraAcc] = [AcObv].[GUID]  
			INNER JOIN my000 AS [my] ON  [my].[GUID] = [enCurrencyPtr]
			INNER JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]  
			LEFT JOIN ER000 er ON er.EntryGuid = ceGuid AND er.ParentType <> 1000/*1000 توزيع الدفعات الشهرية*/
			LEFT JOIN [#RelatedMat] AS [Mat] ON  [Mat].[EnGUID] = [CE].[enGUID]
			CROSS APPLY (
				SELECT 
					CASE WHEN @IsOneCurrency = 1 THEN 1 ELSE
					1 /	CASE 
							WHEN
								CASE 
									WHEN enCurrencyPtr = (CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END) THEN [enCurrencyVal] 
									ELSE dbo.fnGetCurVal((CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END), enDate)
								END = 0 
							THEN  1 
							ELSE 
								CASE 
									WHEN enCurrencyPtr = (CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END) THEN [enCurrencyVal] 
									ELSE dbo.fnGetCurVal((CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END), enDate)
								END
						END 
					END AS FACTOR 
				WHERE
					ISNULL(enCustomerGUID, 0x0) = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN ISNULL(@CustGUID, 0x0) ELSE ISNULL(enCustomerGUID, 0x0) END
			) AS F
			LEFT JOIN [vwBt] AS [bt] ON ceTypeGuid = [bt].[btGuid]  
		WHERE      
			(
				(@IsFilterByDate = 1 AND ((@FromCheckDate = 0 AND CE.enDate BETWEEN @StartDate AND @EndDate) OR (@FromCheckDate = 1 AND CE.enDate BETWEEN DATEADD(dd,1,AC.CheckDate) AND @EndDate))) 
				OR @IsFilterByDate = 0  
			)
			AND 
			(
				(@IsFilterByPostDate = 1 AND ((@FromCheckDate = 0 AND (ceIsPosted = 0 OR (ceIsPosted = 1 AND CePostDate BETWEEN @FromPostDate AND @ToPostDate))) OR (@FromCheckDate = 1 AND CePostDate BETWEEN DATEADD(dd,1,AC.CheckDate) AND @ToPostDate)))  
				OR @IsFilterByPostDate = 0  
			)
			AND ( @Class = '' OR [enClass] = @Class)      
			AND ( @ShowUnPosted = 1 OR [ceIsPosted] = 1)      
			AND ( @Contain = '' or [enNotes] Like @strContain or [ceNotes] Like @strContain)      
			AND ( @NotContain = '' or ( [enNotes] NOT Like @strNotContain and [ceNotes] NOT Like @strNotContain))      
			AND ((src.[Type] IS NOT NULL) OR er.ParentType = 303)
			AND ( 
				(@ShowRelatedMatInfo = 1 AND (ISNULL(@MatGUID, 0x0) <> 0x0 OR ISNULL(@GroupGUID, 0x0) <> 0x0) AND [Mat].[EnGUID] IS NOT NULL) 
				OR (@ShowRelatedMatInfo = 1 AND (ISNULL(@MatGUID, 0x0) = 0x0 AND ISNULL(@GroupGUID, 0x0) = 0x0)) 
				OR @ShowRelatedMatInfo = 0
				)
		GROUP BY     
			[ceGUID],       
			CASE WHEN @UnifyAccEn = 1 THEN 0x00 ELSE [CE].[enGUID] END,   
			[ceNumber],       
			[enDate],      
			CASE WHEN @UnifyAccEn = 1 THEN 0 ELSE [enNumber] END,  
			[enAccount],      
			[ac].[acCode],  
			[ac].[acName],  
			[ac].[acLatinName],
			[Mat].[MatGUID],
			[Mat].[MatName],
			[Mat].[MatQuantity],
			[Mat].[MatUnityName],  
			[enCurrencyPtr],      
			[my].[Code],
			[enCurrencyVal],      
			--enContraAcc,      
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN 0x0 ELSE [AcObv].[GUID] END,     
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN '' ELSE [AcObv].[acCode] END,     
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN '' ELSE [AcObv].[acName] END,     
			CASE WHEN @UnifyAccEn = 1 AND @ShowObverseAcc = 0 THEN '' ELSE [AcObv].[acLatinName] END, 
			CASE @UnifyAccEn 
				WHEN 1 THEN CASE @IsGroupedByClass WHEN 1 THEN [enClass] ELSE 0x0 END
				ELSE [enClass]
			END,
			CASE @UnifyAccEn 
				WHEN 1 THEN CASE @IsGroupedByCost WHEN 1 THEN [enCostPoint] ELSE 0x0 END
				ELSE [enCostPoint]
			END,
			CASE WHEN @UnifyAccEn = 1 THEN [ceNotes] ELSE [enNotes] END,  
			[ceNotes],      
			[AC].[Path],      
			[ceSecurity],      
			[ac].[acSecurity],    
			ISNULL(er.ParentNumber,0),  
			ISNULL(ER.ParentGUID, 0x0),		--ParentGUID,    
			CASE WHEN @CollectCheck = 0 THEN ISNULL(ER.ParentType, 0) ELSE 0 END,		--ceRecType,   
			[ceTypeGuid],   
			[ceBranch],ceIsPosted,er.ParentType,ISNULL(src.[Security],@Sec),
			CePostDate,
			[Mat].[MatPrice],
			[bt].btGUID,
			[bt].[btAbbrev],
			[bt].[btLatinAbbrev],
			FACTOR
	  
	
	IF( @CollectCheck = 1)  
	BEGIN 
		-- Set flag for entries to merged  
		UPDATE [Res] SET   
			[NtNumber] = [ch].[chNum],  
			[enNotes] = [ch].[chNotes],			  
			[NtFlg] = 1  
		FROM  
			[#Result] AS [Res]  
			INNER JOIN [vwEr] AS [er]   
			ON [Res].[ceGuid] = [er].[erEntryGuid]    
			INNER JOIN [vwch] AS [ch]  
			ON [ch].[chGuid] = [er].[erParentGuid]  
		-- insert merged entry  
		INSERT INTO [#Result]  
		SELECT  
			0x0, --[CE].[ceGUID],       
			0x0, --CASE WHEN @UnifyAccEn = 1 THEN 0x0 ELSE [CE].[enGUID] END,   
			0, --[CE].[ceNumber],       
			[Res].[ceDate],  
			0, --CASE WHEN @UnifyAccEn = 1 THEN 0 ELSE [CE].[enNumber] END,   
			[Res].[AccGuid],      
			[Res].[acCode],  
			[Res].[acName],  
			[Res].[acLatinName], 
			[Res].[matGUID],
			[Res].[matName],
			[Res].[matQuantity],
			[Res].[matUnityName], 
			SUM( [Res].[enDebit]),      
			SUM( [Res].[enCredit]),      
			SUM( [Res].[enFixDebit]),      
			SUM( [Res].[enFixCredit]),      
			[Res].[enCurPtr],  
			[Res].[enCurCode],  
			[Res].[enCurVal],      
			--enContraAcc,      
			0x0,--[AcObv].[acGUID],  	
			'', --[AcObv].[acCode],  
			'', --[AcObv].[acName],  
			'', --[AcObv].[acLatinName],  
			[Res].[class], 
			ISNULL([Res].[CostGUID],0x0),  
			[Res].[NtNumber] + (case @lang when 0 then ' (??????: ' else ' (Note: '  end) +   
				max( [Res].[enNotes]) + ')', --CASE WHEN @UnifyAccEn = 1 THEN [CE].[ceNotes] ELSE [CE].[enNotes] END,  
			'',  
			0x0,		--ParentGUID,    
			[RES].[ceRecType],--ceRecType,    
			[Res].[Path],  
			1, 		-- 0 Main Account 1 Sub Account      
			0,   
			[Res].[Security],  
			[Res].[accSecurity],  
			--AcObv.acSecurity,  
			0,		--ceParentNumber,   
			ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''),	--ceTypeAbbrev,   
			0, 		-- isCheck   
			--0x0 		-- UserCheckGuid   
			[Res].[ceTypeGuid],  
			'',  
			0,  			 
			[Res].[Branch], 
			[UserName], 
			[Posted], 
			0, 
			0, 
			MAX([Res].PostDate), 1,
			0x0, 0x0, 0x0, 0,
			[Res].MatPrice
		FROM     
			[#Result] AS [Res]  
			INNER JOIN [vwNt] AS [nt]  
			ON [Res].[ceTypeGUID] = [nt].[ntGuid]  
		WHERE      
			[Res].[NtFlg] = 1  
		GROUP BY     
			--[CE].[ceGUID],       
			--CASE WHEN @UnifyAccEn = 1 THEN 0x0 ELSE [CE].[enGUID] END,   
			--[CE].[ceNumber],       
			[Res].[ceDate],      
			--CASE WHEN @UnifyAccEn = 1 THEN 0 ELSE [CE].[enNumber] END,  
			[Res].[AccGuid],  
			[Res].[acCode],  
			[Res].[acName],  
			[Res].[acLatinName], 
			[Res].[matGUID],
			[Res].[matName],
			[Res].[matQuantity],
			[Res].[matUnityName], 
			[Res].[enCurPtr],  
			[Res].[enCurCode],  
			[Res].[enCurVal],  
			--enContraAcc,  
			--[AcObv].[acGUID],  
			--[AcObv].[acCode],  
			--[AcObv].[acName],  
			--[AcObv].[acLatinName],  
			[Res].[class], 
			[Res].[CostGUID],      
			[Res].[NtNumber],--CASE WHEN @UnifyAccEn = 1 THEN [CE].[ceNotes] ELSE [CE].[enNotes] END,      
			--ParentGUID,    
			--ceRecType,    
			[Res].[Path],  
			[RES].[ceRecType],  
			[Res].[Security],      
			[Res].[accSecurity],    
			--AcObv.acSecurity,  
			ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''),  
			[Res].[ceTypeGuid],   
			[Res].[Branch], 
			[UserName], 
			[Posted],
			[Res].MatPrice
		--///////////////////////////////////////////////////////  
		-----------------------------------  
		-- delete flaged entries  
		DELETE FROM #Result WHERE [NtFlg] = 1  

		UPDATE [#Result] SET
			[ceRecType] = [er].[erParentType]
		FROM  
			[#Result] AS [Res]   
			INNER JOIN [vwEr] AS [er] ON [Res].[ceGuid] = [er].[erEntryGuid] 
	END  
	
	IF (@User <> 0X00)  
	BEGIN  
		DELETE r FROM #Result r   
		left join er000 er on r.ceguid = er.entryguid LEFT JOIN   
			( 
				SELECT a.[RecGuid],[LoginName] FROM LOG000 a join  
				(  
				select max(logTime) as logTime,[RecGuid] from [LOG000] WHERE  [RecGuid] <> 0X00 /*and DrvRID = -1*/ group by  [RecGuid] ) b  
				ON a.[RecGuid] = b.[RecGuid]   
				INNER JOIN us000 u ON [USerGuid] = u.Guid  
				WHERE a.logTime = b.logTime and u.Guid = @User AND Operation <> 1 
				UNION ALL 
				SELECT bu.Guid,[LoginName] FROM bu000 bu INNER JOIN us000 u ON [USerGuid] = u.Guid  WHERE [USerGuid] = @User 
				 
				) v ON v.RecGuid = er.parentguid OR v.RecGuid = r.CeGUID 
				WHERE v.[RecGuid] IS NULL  
	END  
	
	---------------------------------------------  
	UPDATE [#Result] SET  
		PaymentGUID = [ceParentGUID], 
		[ParentName] = (case [dbo].[fnConnections_GetLanguage]() when 0 then [et].[etAbbrev] else [et].[etLatinAbbrev]  end)--[et].[etAbbrev]  
	FROM   
		[#Result] AS [Res] INNER JOIN [vwEt] AS [et]   
		ON [Res].[ceTypeGUID] = [et].[etGuid] 
	-------------------------------------------  
	UPDATE [#Result] SET  
		ChequeGUID = [ceParentGUID], 
		[ParentName] = (case [dbo].[fnConnections_GetLanguage]() when 0 then [nt].[ntAbbrev] else [nt].[ntLatinAbbrev]  end)
	FROM   
		[#Result] AS [Res] INNER JOIN [vwNt] AS [nt]  
		ON [Res].[ceTypeGUID] = [nt].[ntGuid]  
	-------------------------------------------
				 
	UPDATE R 
	SET [ParentName] = R.[ParentName] + ':' + NUM 
		FROM [#Result] r INNER JOIN CH000 CH ON ch.Guid = [ceParentGUID] 
		WHERE [ceRecType] IN (5,6,7,8) 
	-------------------------------------------  
	------------------------ For Exchange System By Muhammad Qujah  ----------  
	UPDATE [#Result] SET   
		[ParentName] = [et].[Abbrev]  
	FROM  
		TrnExchange000 as ex   
		INNER JOIN TrnExchangeTypes000 AS [et]  
			ON [ex].[TypeGuid] = [et].[Guid]  
	where ceRecType = 507  
	------------------------ For Exchange System By Muhammad Qujah  ---------  
	------------------------ For Hospital System By Bassam Najeeb  ----------   
	UPDATE [#Result] SET    
		[ParentName] = dbo.fnStrings_get('GL\SURGEON_FEES', DEFAULT)
	WHERE ceRecType = 202    
	------------------------------   
	UPDATE [#Result] SET    
		[ParentName] = dbo.fnStrings_get('GL\OPERATIONS_ROOM_COST', DEFAULT)
	WHERE ceRecType = 304    
	-------------------------------------------   
	UPDATE [#Result] SET    
		[ParentName] = dbo.fnStrings_get('GL\RESIDENCE', DEFAULT)
	WHERE ceRecType = 303   
	-------------------------------------------   
	UPDATE [#Result] SET    
		[ParentName] = dbo.fnStrings_get('GL\GENERAL_WORK', DEFAULT)
	WHERE ceRecType = 300   
	UPDATE [#Result] SET
	[ParentName] = dbo.fnStrings_get('GL\COMPANY_OUTGOING_TRANSFER', DEFAULT)
	FROM   
	[#Result] AS [Res] INNER JOIN OutCardCompany AS outC ON [Res].[ceParentGUID] = outC.Guid  
	UPDATE [#Result] SET
	[ParentName] = dbo.fnStrings_get('GL\COMPANY_INCOMING_TRANSFER', DEFAULT)
	FROM   
	[#Result] AS [Res] INNER JOIN inCardCompany AS outC ON [Res].[ceParentGUID] = outC.Guid 
	UPDATE [#Result] SET
	[ParentName] = 
		CASE WHEN IsCenter = 0 
			THEN dbo.fnStrings_get('GL\RESET_CASH_DRAWER', DEFAULT)
			ELSE dbo.fnStrings_get('GL\RECEIPT_DELIVERY_CENTERS', DEFAULT)
		END
	FROM   
	[#Result] AS [Res] INNER JOIN TrnCloseCashier000 AS ca ON [Res].[ceParentGUID] = ca.Guid 
	UPDATE [#Result] SET
	[ParentName] = 
		CASE WHEN ca.TYPE = 1 
			THEN dbo.fnStrings_get('GL\EXCHANGE_RECEIPT_VOUCHER', DEFAULT)
			ELSE dbo.fnStrings_get('GL\EXCHANGE_PAYMENT_VOUCHER', DEFAULT)
		END
	FROM   
	[#Result] AS [Res] INNER JOIN TrnDeposit000 AS ca ON [Res].[ceParentGUID] = ca.Guid 
	UPDATE [#Result] SET
		[ParentName] = dbo.fnStrings_get('GL\INTERNAL_TRANSFER', DEFAULT),
		ParentNumber = outc.Number
	FROM   
	[#Result] AS [Res] INNER JOIN TrnTransferVoucher000 AS outC ON [Res].[ceParentGUID] = outC.Guid
	
	------------------------------------------- 
	--* Made a conflict with main vouchers name in general call.
				
	--UPDATE [#Result] SET    
	--	[ParentName] = 'سندات'   
	--WHERE ceRecType = 4  
	-------------------------------------------   
	UPDATE [#Result] SET    
		[ParentName] = dbo.fnStrings_get('GL\RADIOGRAPH_ORDER', DEFAULT),
		[ParentNumber] = radio.code   
	FROM   
		[#Result] AS [Res]    
		INNER JOIN [vwEr] AS [er] ON [Res].[ceGuid] = [er].[erEntryGuid]     
		INNER JOIN HosRadioGraphyOrder000 AS radio ON radio.Guid = [er].[erParentGuid]   
	WHERE ceRecType = 309   
	-------------------------------------------   
	UPDATE [#Result] SET    
		[ParentName] = 
			CASE ceRecType 
				WHEN 302 THEN dbo.fnStrings_get('GL\CLOSE_DOSSIER', DEFAULT)
				WHEN 301 THEN dbo.fnStrings_get('GL\MEDICAL_CONSULTATION', DEFAULT)
			END   
	WHERE ceRecType = 302 OR ceRecType = 301	   
	------------------------ For Hospital System By Bassam Najeeb  --------- 
	IF(@ENTRYCOND <> 0x0) 
	BEGIN 
		DELETE R FROM [#RESULT] R WHERE R.CeParentType = 4 AND R.ceGUID NOT IN (SELECT GUID FROM [#ENTRY]) 
	END  
	 
	IF(@BILLCOND <> 0x0) 
	BEGIN 
		DELETE R FROM [#RESULT]  R WHERE R.CeParentType = 2 AND R.ceGUID NOT IN (SELECT GUID FROM [#BILLENTRY]) 
	END  
	-------------------------------------------------------------------------------------      
	EXEC [prcCheckSecurity]     
	-----------------------------------------------------------------------------    
	
	IF( @ShowIsCheck = 1)   
	BEGIN   
		DECLARE @UserGuid [UNIQUEIDENTIFIER]   
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()   
		  
		UPDATE [Res]  
		SET    
			[isCheck] = 1   
			--UserCheckGuid = RCH.UserGuid   
		FROM    
			[#Result] AS [Res] INNER JOIN [RCH000] As [RCH]   
			ON [Res].[enGuid] = [RCH].[ObjGUID]  
		WHERE    
			@rid  = [RCH].[Type]  
			AND( (@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGuid))  
		IF( @ItemChecked <> 3)  
		BEGIN    
			IF( @ItemChecked = 1)   
				DELETE FROM [#Result] WHERE [isCheck] <> 1   
			ELSE   
				DELETE FROM [#Result] WHERE [isCheck] = 1   
		END   
	END   
	
	-------------------------------------------------------------------------------   
	DECLARE @BalanceTbl TABLE(      
				[AccGUID] [UNIQUEIDENTIFIER],      
				[AccParent] [UNIQUEIDENTIFIER],      
				[FixDebit] [FLOAT],      
				[FixCredit] [FLOAT],      
				[PrevBalance] [FLOAT],     
				[Lv] [INT] DEFAULT 0,
				CurrencyGuid UNIQUEIDENTIFIER,
				[SumCheckedBalance] FLOAT
				)     
	-- create initial balance for the result table  
	INSERT INTO @BalanceTbl 
		SELECT     
			[AC].[GUID],      
			[acParent],     
			SUM( ISNULL([Res].[enFixDebit],0)),     
			SUM( ISNULL([Res].[enFixCredit],0)),     
			0 AS [PrevBal],     
			0 AS [Lv],
			AC.CurrencyGuid,
			SUM(CASE ISNULL(RES.IsCheck, 0) WHEN 0 THEN 0 ELSE ISNULL([res].[enFixDebit], 0) - ISNULL([res].[enFixCredit], 0) END)
		FROM     
			#Account_Tbl AS [AC] 
			INNER JOIN [vwAc] ON [vwAc].[acGUID] = [AC].[GUID]     
			LEFT JOIN [#Result] AS [Res] ON [AC].[GUID] = [Res].[AccGUID]  
			--INNER JOIN [en000] [en] on [en].[GUID] = [Res].[enGUID]
			--LEFT JOIN [vwCu] AS [CU] on [cu].[cuGUID] = [en].[CustomerGUID] 
		--WHERE
			--ISNULL([CU].[cuGUID], 0x0) = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN @CustGUID ELSE ISNULL([CU].[cuGUID], 0x0) END   
		GROUP BY     
			[AC].[GUID],      
			[acParent],
			AC.CurrencyGuid

	-- STEP 2 THE PREVIOS BALANCE      
	-- calc previous balances for result and accounts not in result and   
	-- has only a previous balance  
		CREATE TABLE [#Prev_B_Res] (  
						[AccGUID]		[UNIQUEIDENTIFIER],   
						[enDebit]		[FLOAT],   
						[enCredit]		[FLOAT],   
						--[ceSecurity]	[INT],   
						[Security]		[INT],   
						[acSecurity]	[INT],  
						[ceGuid]		UNIQUEIDENTIFIER, 
						IsCheck INT,
						[UserSecurity]	[INT],
						[CustGUID] [UNIQUEIDENTIFIER],
						[enGuid]		UNIQUEIDENTIFIER Default 0x0
						) 
	IF @PrevBalance	> 0      
	BEGIN  
		IF ( @IsFilterByDate = 1 ) OR ( @IsFilterByPostDate = 1 )
		BEGIN 
			INSERT INTO [#Prev_B_Res]   
			SELECT   
				[CE].[enAccount] AS [Account],     
				[CE].[EnDebit] * FACTOR AS [Debit],      
				[CE].[enCredit] * FACTOR AS [Credit],   
				[CE].[ceSecurity],   
				[Acc].[acSecurity], 
				[ceGuid], 
				0,
				ISNULL(src.[Security], @Sec),
				[CE].[enCustomerGUID],
				ISNULL([CE].enGUID, 0x0)
			FROM      
				vwCeEn AS CE
				LEFT JOIN #Account_Tbl AS [Acc] On [Acc].[Guid] = [CE].[enAccount]
				CROSS APPLY (
					SELECT 
						CASE WHEN @IsOneCurrency = 1 THEN 1 ELSE
						1 /	CASE 
								WHEN
									CASE 
										WHEN enCurrencyPtr = (CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE [Acc].CurrencyGuid END) THEN [enCurrencyVal] 
										ELSE dbo.fnGetCurVal((CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE [Acc].CurrencyGuid END), enDate)
									END = 0 
								THEN  1 
								ELSE 
									CASE 
										WHEN enCurrencyPtr = (CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE [Acc].CurrencyGuid END) THEN [enCurrencyVal] 
										ELSE dbo.fnGetCurVal((CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE [Acc].CurrencyGuid END), enDate)
									END
							END 
						END AS FACTOR 
						WHERE
							ISNULL(enCustomerGUID, 0x0) = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN ISNULL(@CustGUID, 0x0) ELSE ISNULL(enCustomerGUID, 0x0)  END
				) AS F
				INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]     
				INNER JOIN #AccObverse_Tbl AS [AcObv] ON ISNULL( [CE].[enContraAcc], 0x0) = [AcObv].[GUID]   
				LEFT JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]  
				LEFT JOIN ER000 er ON er.EntryGuid = ceGuid 
				LEFT JOIN [#RelatedMat] AS [Mat] ON [Mat].[EnGUID] = [CE].[enGUID]
			WHERE      
				( 
					((@IsFilterByDate = 1 AND ( (@FromCheckDate = 0 AND CE.enDate BETWEEN '01-01-1980' AND DATEADD(second,-1,@StartDate))
												OR (@FromCheckDate = 1 AND [CE].[enDate] < DATEADD(mi,1439,[Acc].[CheckDate])))) 
					 OR @IsFilterByDate = 0  )
					 AND
					 ((@IsFilterByPostDate = 1 AND ( (@FromCheckDate = 0 AND CE.CePostDate BETWEEN '01-01-1980' AND DATEADD(second,-1,@FromPostDate))
												OR (@FromCheckDate = 1 AND CE.CePostDate < DATEADD(mi,1439,[Acc].[CheckDate]))))
					 OR @IsFilterByPostDate = 0  )
				)   
				AND ( @Class = '' OR [CE].[enClass] = @Class)     
				AND ([CE].[ceIsPosted] = 1 OR @ShowUnPosted = 1 )      
				AND (  
						@PrevBalance = 1  
						OR       
						(  
							@PrevBalance = 2      
							AND ( @Contain = '' or [CE].[enNotes] Like @strContain or [CE].[ceNotes] Like @strContain)      
							AND ( @NotContain = '' or ( [CE].[enNotes] NOT Like @strNotContain and [CE].[ceNotes] NOT Like @strNotContain))  
						)  
				)
				AND ( 
					(@ShowRelatedMatInfo = 1 AND (ISNULL(@MatGUID, 0x0) <> 0x0 OR ISNULL(@GroupGUID, 0x0) <> 0x0) AND [Mat].[EnGUID] IS NOT NULL) 
					OR (@ShowRelatedMatInfo = 1 AND (ISNULL(@MatGUID, 0x0) = 0x0 AND ISNULL(@GroupGUID, 0x0) = 0x0)) 
					OR @ShowRelatedMatInfo = 0
				)
		END
		 
		 --تحديث قيم الجدول من اجل ربط مبلغ المدقق وغير المدقق
		  UPDATE p
		  SET  IsCheck = (CASE 
							WHEN EXISTS 
									(SELECT DISTINCT en.ParentGUID 
											FROM en000 en 
													INNER  JOIn rch000 r ON  r.ObjGUID = en.guid 
											WHERE p.enGuid = en.guid) 
							THEN 1 ELSE 0 END
						 )
		  FROM [#Prev_B_Res] p 
		/*IF (@ShowEmptyBal = 0)  
				DELETE a FROM [#Prev_B_Res] a LEFT JOIN (SELECT [AccGUID],[CeGUID] FROM  [#result] GROUP BY [AccGUID] ,[CeGUID]) r ON r.[AccGUID] = a.[AccGUID] WHERE r.[CeGUID] = a.[ceGuid]
		*/
		IF (@User <> 0X00)  
		BEGIN  
			DELETE r FROM [#Prev_B_Res] r   
			LEFT JOIN er000 er on r.ceguid = er.entryguid LEFT JOIN    
				(SELECT a.[RecGuid],[LoginName] FROM LOG000 a join  
					(  
					select max(logTime) as logTime,[RecGuid] from [LOG000] WHERE  [RecGuid] <> 0X00 /*and DrvRID = -1*/ group by  [RecGuid] ) b  
					ON a.[RecGuid] = b.[RecGuid]   
					INNER JOIN us000 u ON [USerGuid] = u.Guid  
					WHERE a.logTime = b.logTime ) v ON v.[RecGuid] = ISNULL(er.ParentGuid,r.[CeGUID]) WHERE v.[RecGuid] IS NULL  
		END  
		--------------------------------------------------   
		EXEC [prcCheckSecurity] @result = '#Prev_B_Res'    
		--------------------------------------------------   
		--------------------------------------------------------------------------------------------------------------------------------------------------- 
		IF(@ENTRYCOND <> 0x0) 
		BEGIN 
			DELETE R FROM [#RESULT] R WHERE R.CeParentType = 4 AND R.ceGUID NOT IN (SELECT GUID FROM [#ENTRY]) 
		END  
		 
		IF(@BILLCOND <> 0x0) 
		BEGIN 
			DELETE R FROM [#RESULT]  R WHERE R.CeParentType = 2 AND R.ceGUID NOT IN (SELECT GUID FROM [#BILLENTRY]) 
		END  
---------------------------------------------------------------------------------------------------------------------------------  
		-- insert into result previous balance records  
		DECLARE @Prev_Balance TABLE ( [AccGUID] [UNIQUEIDENTIFIER],    
						[enDebit]	[FLOAT],   
						[enCredit]	[FLOAT],
						ischeck [INT],
						[CustGUID] [UNIQUEIDENTIFIER] ) --من اجل تحديد مجموع  قيم الرصيد السابق المدققة وغير المدققة      
			    
			INSERT INTO @Prev_Balance    
			SELECT      
				[AccGUID] AS [Account],     
				SUM( [enDebit]) AS [Debit],      
				SUM( [enCredit]) AS [Credit] ,
				0,
				[CustGUID] AS [Customer]    -- مجموع كامل الرصيد السابق
			FROM      
				[#Prev_B_Res]   
			GROUP BY       
				[AccGUID],
				[CustGUID]  
		-----------------------------------------------------------------      
		-- update the current balance by adding the previous balance  
		UPDATE [Balanc]      
			SET [PrevBalance] = [Prev].PrevBalance
			FROM @BalanceTbl [Balanc] 
			INNER JOIN 
			(SELECT AccGUID, SUM([enDebit] - [enCredit]) AS PrevBalance 
			FROM     
				@Prev_Balance    
			WHERE 
				isCheck = 0  
			GROUP BY
				AccGUID) AS [Prev] 
			ON [Prev].[AccGUID] = [Balanc].AccGUID
	END  
	
	---------------------------------------------------------------------------------------------------------------------- 
	---------------------------------------------------------------------------------------------------------------------- 
	-------------------------------------------------------------------------------------------      
	-- C O L L E C T  B A L A N C E   O F  A C C O U N T S     
	-------------------------------------------------------------------------     
	IF( @IsSingl <> 1) -- is this a general account (has sons)  
	BEGIN  
		-- calc balance by adding balances of sons (and previous balance)  
		DECLARE @Continue [INT], @Lv [INT]     
		SET @Continue = 1     
		SET @Lv = 0     
		WHILE @Continue <> 0   
		BEGIN     
			SET @Lv = @Lv + 1     
			INSERT INTO @BalanceTbl  
			SELECT     
				[Bal].[AccParent],      
				[acParent],     
				SUM([Bal].[FixDebit]),
				SUM([Bal].[FixCredit]),
				SUM([Bal].[PrevBalance]),
				@Lv,
				vwAc.acCurrencyPtr,
				SUM([Bal].[SumCheckedBalance])
			FROM     
				@BalanceTbl AS [Bal]     
				INNER JOIN #Account_Tbl AS [AC] ON [AC].[GUID] = [Bal].[AccParent]
				INNER JOIN [vwAc] ON [vwAc].[acGUID] = [AC].[GUID]
			WHERE     
				[Lv] = @Lv - 1     
			GROUP BY     
				[Bal].[AccParent],     
				[acParent],
				vwAc.acCurrencyPtr
			SET @Continue = @@ROWCOUNT      
		END	   
		 
		IF EXISTS(SELECT * from ac000 WHERE GUID = @Account AND Type = 4)  
		BEGIN  
			INSERT INTO @BalanceTbl  
				SELECT @Account,0X00,  
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					SUM( [Bal].[PrevBalance]),  
					-1,
					0x,
					SUM([Bal].[SumCheckedBalance])
					FROM     
						@BalanceTbl AS [Bal]
						INNER JOIN ci000 CI ON ci.SonGUID = [Bal].[AccGUID]
					WHERE 
						ci.ParentGUID = @Account
		END    
	END 
	 
	-----------------------------------------------------------------------     
	-- now the final result  
	INSERT INTO [#Result] (      
		[AccGUID],      
		[acCode],  
		[acName],  
		[acLatinName],  
		[Path],      
		[enDebit],     
		[enCredit],     
		[enFixDebit],     
		[enFixCredit],     
		[PrevBalance],     
		[Type],      
		[Security],      
		[accSecurity],
		SumCheckedBalance)     
	SELECT     
		[AC].[GUID],      
		[AC].[acCode],  
		[AC].[acName],  
		[AC].[acLatinName],  
		[AC].[Path],      
		0,     
		0,     
		SUM( [Bal].[FixDebit]),     
		SUM( [Bal].[FixCredit]),     
		SUM( [Bal].[PrevBalance]) as perv,   
		0,     
		0, -- 0 it suggest hi security for entry       
		[AC].[acSecurity],
		SUM([Bal].[SumCheckedBalance])
	FROM     
		#Account_Tbl AS [AC]   
		INNER JOIN @BalanceTbl AS [Bal]     
		ON [AC].[GUID] = [Bal].[AccGUID]  
	GROUP BY     
		[AC].[GUID],      
		[acCode],  
		[acName],  
		[acLatinName],  
		[AC].[Path],      
		[AC].[acSecurity]     
	HAVING   
	(  
		(@ShowEmptyBal = 1) OR  
		( (@ShowEmptyBal = 0) AND   
		( (SUM( [Bal].[FixDebit]) > 0 OR SUM([Bal].[FixCredit]) > 0) ) )  
	) 
	--------------------------------------------------------------------------------------------      
	EXEC [prcCheckSecurity]     
	-------------------------------------------------------------------------------------------  
	IF @ShwUser > 0  
	BEGIN  
		UPDATE r SET UserName = ISNULL([LoginName],'') FROM #Result r   
		left join er000 er on r.ceguid = er.entryguid  
		LEFT JOIN    
			(SELECT a.[RecGuid],[LoginName] FROM LOG000 a join  
				(  
				select max(logTime) as logTime,[RecGuid] from [LOG000] WHERE  [RecGuid] <> 0X00 /*and DrvRID = -1*/ group by  [RecGuid] ) b  
				ON a.[RecGuid] = b.[RecGuid]   
				INNER JOIN us000 u ON [USerGuid] = u.Guid  
				WHERE a.logTime = b.logTime ) v ON v.RecGuid = er.parentguid OR v.RecGuid = r.CeGUID
	END  

	--------------------------------------------------------------------------------------------      
	CREATE TABLE #Res (     
		[AccGuid] [UNIQUEIDENTIFIER],      
		[AccCode] [NVARCHAR](200) ,    
		[AccName] [NVARCHAR](250) ,    
		[AccLName] [NVARCHAR](250) ,
		AcCurrencyCode NVARCHAR(100),
		[MatGUID] [UNIQUEIDENTIFIER],
		[MatName]  [NVARCHAR](250) ,
		[MatQuantity] [float],
		[MatUnity]  [NVARCHAR](250),
		[ceGuid] [UNIQUEIDENTIFIER],      
		[enGuid] [UNIQUEIDENTIFIER] DEFAULT 0x0,      
		[ceNumber] [INT],      
		[ceDate] [DATETIME],   
		[enNumber] [INT],   
		[Debit] [FLOAT],      
		[Credit] [FLOAT],
		[MoveBalance] FLOAT,
		[curDebit] [FLOAT],      
		[curCredit] [FLOAT],      
		[CurGuid] [UNIQUEIDENTIFIER],      
		[CurCode] [NVARCHAR](250) ,    
		[CurVal] [FLOAT],      
		[Class] [NVARCHAR](250), 
		[CostGuid] [UNIQUEIDENTIFIER],   
		[enNotes] [NVARCHAR](1000),
		[ceNotes] [NVARCHAR](1000),
		[ObverseGUID] [UNIQUEIDENTIFIER],  
		[ObverseCode] [NVARCHAR](250),
		[ObverseName] [NVARCHAR](250),
		[ObverseLName] [NVARCHAR](250),
		[ceParentGUID] [UNIQUEIDENTIFIER],      
		[RepType] [INT],      
		[AccType] [INT],	-- 0 Main Account 1 Sub Account      
		[PrevBalance] [FLOAT],     
		[PATH] [NVARCHAR](4000),    
		[ParentNumber] [INT],   
		[ParentName] [NVARCHAR](250) ,   
		[Level] [INT],   
		[IsCheck] [INT],  	 
		[BranchGuid] [UNIQUEIDENTIFIER],  
		[Branch] [NVARCHAR](250) ,  
		[LatinBranch] [NVARCHAR](250) ,  
		[UserName] [NVARCHAR](100) 	,[Posted] BIT, [PostDate] [DATETIME]
		,PrevBalanceCheck FLOAT,--الرصيدالسابق المدقق
		PrevBalanceNotCheck FLOAT,
		IsDetail BIT DEFAULT (0),
		[BillGUID] UNIQUEIDENTIFIER DEFAULT (0x0),
		[PaymentGUID] UNIQUEIDENTIFIER DEFAULT (0x0),
		[ChequeGUID] UNIQUEIDENTIFIER DEFAULT (0x0),
		IsDifferentBalance [BIT] DEFAULT (0),
		[SumCheckedBalance] FLOAT DEFAULT (0),
		[HasDetails] BIT DEFAULT (0),
		[MatPrice] FLOAT,
		HasDocuments INT DEFAULT (0))
		--الرصيد السابق غير المدقق
		--UserCheckGuid [UNIQUEIDENTIFIER] DEFAULT 0x0)   
	
	DECLARE @browseAccSec INT = [dbo].[fnGetUserAccountSec_Browse]([dbo].[fnGetCurrentUserGUID]())

	INSERT INTO #Res      
	SELECT       
		[RES].[AccGuid],      
		[RES].[acCode],      
		[RES].[acName],      
		[RES].[acLatinName],
		my.myCode,
		[Res].[MatGUID],
		[Res].[MatName],
		[Res].[MatQuantity],
		[Res].[MatUnityName],      
		[RES].[ceGuid],      
		[RES].[enGuid],   
		[RES].[ceNumber],      
		[RES].[ceDate],      
		[RES].[enNumber],   
		ISNULL([RES].[enFixDebit], 0),      
		ISNULL([RES].[enFixCredit], 0),      
		ISNULL([RES].[enFixDebit], 0) - ISNULL([RES].[enFixCredit], 0),
		ISNULL([RES].[enDebit], 0),      
		ISNULL([RES].[enCredit], 0),      
		[RES].[enCurPtr],      
		[RES].[enCurCode],      
		[RES].[enCurVal],    
		[Class],
		ISNULL( [RES].[CostGUID], 0x0),   
		[RES].[enNotes],  
		[RES].[ceNotes],      
		CASE WHEN A.Code IS NULL THEN 0x0 WHEN A.Security > @browseAccSec THEN 0x0 ELSE ISNULL([ObvacGUID], 0x0) END AS [ObverseGUID],   
		CASE WHEN A.Code IS NULL THEN N'' WHEN A.Security > @browseAccSec THEN @NoAccessStr ELSE ISNULL([ObvacCode], N'') END AS [ObverseCode],   
		CASE WHEN A.Code IS NULL THEN N'' WHEN A.Security > @browseAccSec THEN @NoAccessStr ELSE ISNULL([ObvacName], N'') END AS [ObverseName],   
		CASE WHEN A.Code IS NULL THEN N'' WHEN A.Security > @browseAccSec THEN @NoAccessStr ELSE ISNULL([ObvacLatinName], N'') END AS [ObverseLName],       
		[RES].[ceParentGUID],      
		[RES].[ceRecType],      
		[RES].[Type],	-- AccType: 0 Main Account 1 Sub Account      
		ISNULL( [RES].[PrevBalance], 0),     
		[RES].[Path],    
		[RES].[ParentNumber],   
		[RES].[ParentName],   
		CASE WHEN [RES].[ceGuid] IS NULL THEN [Level] ELSE [Level] + 1 END,   
		[IsCheck] ,  
		[Branch],
		'',
		'',
		[UserName],
		[Posted] 
		,[Res].[PostDate] 
		,0
		,0
		,[RES].[IsDetail], 
		[RES].[BillGUID],
		[RES].[PaymentGUID],
		[RES].[ChequeGUID],
		0,
		ISNULL(res.SumCheckedBalance, 0),
		0,
		[RES].MatPrice,
		CASE WHEN parentDoc.Guid IS NULL THEN 
			CASE WHEN ceDoc.Guid IS NULL THEN 0 ELSE 1 END 
		ELSE 1 END 
	FROM      
		[#Result] AS [RES] 
		INNER JOIN #Account_Tbl AS [AC] ON [RES].[AccGUID] = [AC].[GUID]      
		JOIN vwMy my ON ac.CurrencyGuid = my.myGUID
		LEFT JOIN vtAc AS A ON A.GUID = res.[ObvacGUID]
        LEFT JOIN vwObjectRelatedDocument ceDoc ON res.CeGuid = ceDoc.Guid
        LEFT JOIN vwObjectRelatedDocument parentDoc ON res.ceParentGUID = parentDoc.Guid
	WHERE    
		[RES].[Type] = 0 OR [RES].[enDebit] <> 0 OR [RES].[enCredit] <> 0 OR [RES].[PrevBalance] <> 0  
		 
	IF @IsSingl = 0
	BEGIN 
		UPDATE p
		SET [HasDetails] = 1
		FROM 
			#Res ch
			INNER JOIN #Res p ON ch.[AccGuid] = p.[AccGuid]
		WHERE 
			ch.IsDetail = 1 AND p.IsDetail = 0
	END 

	CREATE TABLE #AccountsRealBalances(AccountGUID UNIQUEIDENTIFIER, Balance FLOAT)
	IF ( @cmpUnmctch > 0 ) 
	BEGIN 
		INSERT INTO #AccountsRealBalances
		SELECT [enAccount], SUM(enBal)
		FROM 
			( 
				SELECT 
					en.GUID [enGUID],
					en.AccountGuid [enAccount],
					en.ParentGUID [ceGUID], 
					en.[Date] enDate, 
					en.Class [enClass],
					(en.Debit - en.Credit) * FACTOR enBal,
					c.IsPosted ceIsposted,
					[en].[Notes] [enNotes],
					[c].[Notes] [ceNotes],
					en.CostGuid enCostPoint,
					en.ContraAccGUID enContraAcc 
				FROM  
					(SELECT 
						EN.*,
						1 / CASE
								WHEN 
									CASE 
										WHEN EN.CurrencyGUID = (CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END) THEN CurrencyVal
										ELSE dbo.fnGetCurVal((CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END), [Date])
									END = 0
								THEN 1 
								ELSE 
									CASE 
										WHEN EN.CurrencyGUID = (CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END) THEN CurrencyVal
										ELSE dbo.fnGetCurVal((CASE WHEN @DetialByAccountCurrency = 0 THEN @CurGUID ELSE ac.CurrencyGuid END), [Date])
									END
							END AS FACTOR 
					FROM 
						en000 EN
						JOIN #Account_Tbl ac ON EN.AccountGUID = ac.Guid
					WHERE en.CustomerGUID = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN @CustGUID ELSE en.CustomerGUID END
					) AS EN 
					JOIN ce000 c ON c.Guid = en.ParentGuid
			) AS [CE]  
			INNER JOIN #Account_Tbl AS [AC] ON [CE].[enAccount] = [AC].[GUID] 
			INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]    
			INNER JOIN #AccObverse_Tbl AS [AcObv] ON  [CE].[enContraAcc] = [AcObv].[GUID] 
			LEFT JOIN [#RelatedMat] AS [Mat] ON [Mat].[EnGUID] = [CE].[enGUID]
		WHERE      
			( [CE].[enDate] <= @EndDate )     
			AND ( @Class = '' OR [enClass] = @Class)      
			AND ( @ShowUnPosted = 1 OR [ceIsPosted] = 1)      
			AND ( @Contain = '' or [enNotes] Like @strContain or [ceNotes] Like @strContain) 
			AND ( 
					(@ShowRelatedMatInfo = 1 AND (ISNULL(@MatGUID, 0x0) <> 0x0 OR ISNULL(@GroupGUID, 0x0) <> 0x0) AND [Mat].[EnGUID] IS NOT NULL) 
					OR (@ShowRelatedMatInfo = 1 AND (ISNULL(@MatGUID, 0x0) = 0x0 AND ISNULL(@GroupGUID, 0x0) = 0x0)) 
					OR @ShowRelatedMatInfo = 0
				)
		GROUP BY [enAccount]  
		 
		UPDATE r
		SET IsDifferentBalance = 1 
		FROM 
			#Res r 
			INNER JOIN #AccountsRealBalances acc ON r.AccGuid = acc.AccountGUID
		WHERE 
			r.IsDetail = 0
			AND 
			ABS(r.Debit - r.Credit + r.PrevBalance - acc.Balance) > 0.01
	END
	 
	UPDATE r
	SET 
		PrevBalanceCheck = (SELECT sum(enDebit - enCredit) FROM [#Prev_B_Res] p WHERE ischeck = 1 and r.[AccGuid] = p.[AccGuid]) ,--المدقق
		PrevBalanceNotCheck = (SELECT sum(enDebit - enCredit) FROM [#Prev_B_Res] p WHERE ischeck = 0 and r.[AccGuid] = p.[AccGuid]) --غير المدقق
	FROM #Res r WHERE CeGuid IS NULL AND ceNumber IS NULL
	
	IF @IsCalledByWeb = 0
	BEGIN 
	
		SELECT 
				[AccGuid],  
				CASE @DetialByAccountCurrency 
					WHEN 1 THEN ''
					ELSE REPLICATE(' ', [Level] * 5) 
				END + [AccCode] + '-'  + CASE @lang WHEN 0 THEN [AccName] ELSE CASE [AccLName] WHEN '' THEN [AccName] ELSE [AccLName] END END AS [AccName],  
				[Debit] AS [Debit],  
				[Credit] AS [Credit],  
				CAST([PrevBalance] AS MONEY) AS [PrevBalance],
				CAST(([MoveBalance] + [PrevBalance]) AS MONEY) AS [Balance],  
				CAST([MoveBalance] AS MONEY) AS [MoveBalance],
				[HasDetails] AS [HasDetails],
				(CASE [Level] WHEN 0 THEN 1 ELSE 0 END) AS IsLevelZero,
				IsDifferentBalance AS IsDifferentBalance,
				AcCurrencyCode,		-- *
				CAST(SumCheckedBalance AS MONEY) AS SumCheckedBalance,	-- *
				CAST(([MoveBalance] + [PrevBalance] - SumCheckedBalance) AS MONEY) AS SumUnCheckedBalance,	-- *
				CAST(PrevBalanceCheck AS MONEY) AS PrevBalanceCheck, -- *
				CAST(PrevBalanceNotCheck AS MONEY) AS PrevBalanceNotCheck	-- *
				,CostGuid
			FROM 
				#Res
			WHERE 
				(@Level = 0 OR [Level] < @Level) 
			AND 
				([IsDetail] = 0)
			AND
				([HasDetails] = CASE @ShowMainAcc WHEN 1 THEN [HasDetails] ELSE (CASE @IsNormalAcc WHEN 0 THEN [HasDetails] ELSE CASE @IsSingl WHEN 1 THEN [HasDetails] ELSE 1 END END) END )
			ORDER BY [Path], [AccType]
		
		;WITH CO AS 
		(
			SELECT
				GUID,
				[Code] + '-'  + CASE @lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [CostName]
			FROM 
				co000
		),
		BR AS 
		(
			SELECT
				GUID,
				CASE @lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [BrName]
			FROM 
				br000
		)
		SELECT 
			[AccGuid],
			ISNULL( [ceGuid], 0x0) AS [ceGuid],
			[ceNumber],  
			ISNULL([enNotes], '') AS [enNotes], 
			ISNULL([ceNotes], '') AS [ceNotes],  
			[res].[Debit] AS [Debit],  
			[res].[Credit] AS [Credit],  
			[ceDate],
			CASE 
				WHEN ISNULL([RepType], 0) > 1 THEN ISNULL([ParentName], '') + ': ' + CAST(ISNULL([ParentNumber], 0) AS VARCHAR(250))
				ELSE ''
			END AS [Document],
			CASE ISNULL([ObverseCode], '') 
				WHEN '' THEN '' 
				WHEN @NoAccessStr THEN @NoAccessStr
				ELSE [ObverseCode] + '-'  + 
					CASE @lang 
						WHEN 0 THEN [ObverseName] 
						ELSE CASE [ObverseLName] WHEN '' THEN [ObverseName] ELSE [ObverseLName] END
					END 
			END COLLATE database_default AS [ObverseName],  
			ISNULL(CO.CostName, N'') AS [CostName],  
			ISNULL([co].[GUID], 0x0) AS [CostGuid],
			ISNULL( [IsCheck], 0) AS [IsCheck],  
			[res].Class,
			ISNULL(BR.BrName, N'') AS BrName,
			[UserName], 
			[MatGUID],
			[MatName],
			[MatQuantity],
			[MatUnity],  
			[MoveBalance] + [parent_res].[ParentPrevBalance] AS [Balance],  
			[MoveBalance] AS [MoveBalance],
			ISNULL([Posted], 0) AS [Posted], 
			[PostDate], 
			ISNULL( enNumber, 0) AS enNumber,  
			ISNULL( [enGuid], 0x0) AS [enGuid], 
			ISNULL( [RepType], 0) AS [RepType], 
			'' AS [OrginalCurrency],
			CASE @ShowRunningBalance
				WHEN 0 THEN 0.0
				ELSE 
					[parent_res].[ParentPrevBalance] + SUM([MoveBalance]) OVER(PARTITION BY [AccGuid] ORDER BY [ceDate], [ceNumber], [enNumber] 
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
			END AS  [RunningBalance], 				 
			[res].BillGUID AS BillGUID, 
			[res].PaymentGUID AS PaymentGUID, 
			[res].ChequeGUID AS ChequeGUID,
			ISNULL( [curDebit], 0) AS [curDebit],  
			ISNULL( [curCredit], 0) AS [curCredit],  
			ISNULL( [CurGuid], 0x0) AS [CurGuid],  
			ISNULL( [CurCode], '') AS [CurCode],  
			ISNULL( [CurVal], 0) AS [CurVal],
			MatPrice,
			cu.cuCustomerName As EnCustomerName,
			HasDocuments
		FROM 
			#Res [res]
			INNER JOIN (SELECT [AccGuid] AS [ParentAccGUID], [PrevBalance] AS [ParentPrevBalance] 
					FROM #Res WHERE (@Level = 0 OR [Level] < @Level) AND ([IsDetail] = 0)) [parent_res] ON [parent_res].[ParentAccGUID] = res.AccGuid
			LEFT JOIN CO ON co.GUID = [res].CostGuid
			LEFT JOIN BR ON br.GUID = [res].[BranchGuid]
			LEFT JOIN en000 en ON en.GUID = [res].[enGuid]
			LEFT JOIN vwCu cu ON cu.cuGUID = en.CustomerGUID
		WHERE 
			(@Level = 0 OR [Level] < @Level) 
			AND 
			([IsDetail] = 1)
		ORDER BY [ceDate], [ceNumber], [enNumber], EnCustomerName
		
	END ELSE BEGIN 
		DECLARE @SQL NVARCHAR (MAX) 
		DECLARE @SQL2 NVARCHAR (MAX) 
		SET @SQL = 'SELECT   
			[AccGuid],  
			[AccCode],  
			[AccName],  
			[AccLName],
			0x0 AS [ParentAccountGUID],
			AcCurrencyCode,
			[MatGUID],
			[MatName],
			[MatQuantity],
			[MatUnity],  
			ISNULL( [ceGuid], 0x0) AS [ceGuid],  
			ISNULL( [enGuid], 0x0) AS [enGuid],  
			ISNULL( [ceNumber], 0) AS [ceNumber],  
			ISNULL( [ceDate],'''+ CAST (GetDate() AS NVARCHAR(50))+''') AS [ceDate],  
			ISNULL( enNumber, 0) AS enNumber,  
			ISNULL( [res].[Debit], 0) AS [Debit],  
			ISNULL( [res].[Credit], 0) AS [Credit],  
			ISNULL( [res].[Debit], 0) - ISNULL( [res].[Credit], 0) + 
				ISNULL( [PrevBalance], 0) AS [Balance],  
			ISNULL( [res].[Debit], 0) - ISNULL( [res].[Credit], 0) AS [MoveBalance],  
			ISNULL( [curDebit], 0) AS [curDebit],  
			ISNULL( [curCredit], 0) AS [curCredit],  
			ISNULL( [CurGuid], 0x0) AS [CurGuid],  
			ISNULL( [CurCode], '''') AS [CurCode],  
			ISNULL( [CurVal], 0) AS [CurVal],  
			--@Account AS ObverseGUID,  
			ISNULL( [res].[CostGuid], 0x0) AS [CostGuid],  
			ISNULL( [co].[Code], '''') AS [CostCode],  
			ISNULL( [co].[Name], '''') AS [CostName],  
			ISNULL( [co].[LatinName], '''') AS [CostLatinName],  
			ISNULL( [enNotes], '''') AS [enNotes],  
			ISNULL( [ceNotes], '''') AS [ceNotes],  
			ISNULL( [ObverseCode], '''') AS [ObverseCode],  
			ISNULL( [ObverseName], '''') AS [ObverseName],  
			ISNULL( [ObverseLName], '''') AS [ObverseLName],  
			ISNULL( [ceParentGUID], 0x0) AS [ceParentGUID],  
			ISNULL( [RepType], 0) AS [RepType], 
			CASE 
				WHEN ISNULL([RepType], 0) > 1 THEN ISNULL([ParentName], '''') + '': '' + CAST(ISNULL([ParentNumber], 0) AS VARCHAR(250))
				ELSE ''''
			END AS [Document],
			ISNULL( [AccType], 0) AS [AccType],  
			ISNULL( [PrevBalance], 0) AS [PrevBalance],  
			ISNULL(PrevBalanceCheck,0) as PrevBalanceCheck,
			ISNULL(PrevBalanceNotCheck,0) as PrevBalanceNotCheck,
			ISNULL( [ParentNumber], 0) AS [ParentNumber],  
			ISNULL( [ParentName], '''') AS [ParentName],  
			ISNULL( [IsCheck], 0) AS [IsCheck],  
			ISNULL([Class],'''') AS [Class],  
			ISNULL([Branch],'''') AS [BrName],  
			ISNULL([LatinBranch],'''') AS [BrLatinName],  
			[UserName], ISNULL([Posted], 0) AS [Posted], [PostDate], [IsDetail], ' 
			IF @DetialByAccountCurrency = 1
				SET @SQL = @SQL + ''''''
			ELSE
			  SET @SQL = @SQL + ' REPLICATE('' '', [Level] * 5) '
			SET @SQL = @SQL + ' AS LevelIndent,
			[res].BillGUID AS BillGUID, 
			[res].PaymentGUID AS PaymentGUID, 
			[res].ChequeGUID AS ChequeGUID, 
			[res].IsDifferentBalance AS IsDifferentBalance,
			[res].SumCheckedBalance AS SumCheckedBalance,
			(CASE [Level] WHEN 0 THEN 1 ELSE 0 END) AS IsLevelZero,
			[res].[HasDetails] AS [HasDetails],
			[res].MatPrice,
			[res].HasDocuments'
		SET @SQL = @SQL + ' FROM  #Res [res] ' 
		SET @SQL = @SQL + ' LEFT JOIN co000 co ON co.GUID = [res].CostGuid '  
		SET @SQL = @SQL + ' WHERE ( ' 
		SET @SQL = @SQL + CAST (@Level AS NVARCHAR(4)) 
		SET @SQL = @SQL + ' = 0 OR [Level] < ' 
		SET @SQL = @SQL + CAST( @Level AS NVARCHAR (4)) + ') '
		
		DECLARE @SQL_ORD VARCHAR(250)
		SET @SQL_ORD = ' ORDER BY [Path], [AccType], dbo.fnGetDateFromTime([ceDate]) , [ceNumber], [enNumber] ' 
		IF @IsCalledByWeb = 0
		BEGIN 
			SET @SQL2 = @SQL + ' AND ([IsDetail] = 0) '
			SET @SQL2 = @SQL2 + @SQL_ORD
			EXEC (@SQL2) 
			SET @SQL2 = @SQL + ' AND ([IsDetail] = 1) '
			SET @SQL2 = @SQL2 + @SQL_ORD
			EXEC (@SQL2) 
		END ELSE BEGIN 
			SET @SQL = @SQL + @SQL_ORD
			EXEC (@SQL) 
		END
	END 

	IF @DetialByAccountCurrency = 1
	BEGIN
		SELECT
			CurrencyGuid,
			MY.myName,
			MY.myLatinName,
			SUM([FixDebit]) AS [Debit],   
			SUM([FixCredit]) AS [Credit],   
			SUM([FixDebit]) - SUM([FixCredit]) AS [MoveBalance],
			SUM([PrevBalance]) AS [PrevBalance],
			SUM([FixDebit]) - SUM([FixCredit]) + SUM([PrevBalance]) AS [Balance]
		FROM
			@BalanceTbl AS B
			JOIN vwmy AS MY ON MY.myGuid = B.CurrencyGuid
		WHERE
			[Lv] = 0
		GROUP BY
			CurrencyGuid,
			MY.myName,
			MY.myLatinName;
	END
	SELECT * FROM [#SecViol]
###########################################################################
CREATE PROC repSaveRepCheck
		@Type [FLOAT], 
		@ObjGuid [UNIQUEIDENTIFIER],
		@IsCheck [INT],
		@CheckForUsers [INT] = 0
AS	
	DECLARE @UserGuid [UNIQUEIDENTIFIER], @Date [DATETIME]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()

	IF( @IsCheck <> 0)
	BEGIN
		SET @Date = GetDate()
		DELETE FROM [rch000] 
		WHERE 
			[ObjGUID] = @ObjGuid 
			AND [Type] = @Type 
			AND ( (@CheckForUsers = 1) OR ([UserGuid] = @UserGuid))

		INSERT INTO [rch000] values( newid(), @ObjGuid, @UserGuid, @Date, @Type)
	END
	ELSE
	BEGIN 
		DELETE FROM [rch000] 
		WHERE 
			[ObjGUID] = @ObjGuid 
			AND [Type] = @Type 
			AND [UserGuid] = @UserGuid
	END	
###########################################################################
#END