##################################################################
CREATE PROC prc_AuditOperationBill
	@Audit     BIT,
	@NonAudit  BIT,
	@Auditdate BIT,
	@FromDate DATETIME,
    @ToDate   DATETIME,
	@UserGuid    UNIQUEIDENTIFIER,
	@StoreGuid   UNIQUEIDENTIFIER,
	@CostGuid    UNIQUEIDENTIFIER,
	@CustomerGuid  UNIQUEIDENTIFIER,
	@BranchGuid    UNIQUEIDENTIFIER,
	@RepSrc        UNIQUEIDENTIFIER
AS
  SET NOCOUNT ON
	
	CREATE TABLE [#EntryTbl]([BillGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#EntryTbl1]([BillGuid] [UNIQUEIDENTIFIER], EntryBill int, posted int)  
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Name] [NVARCHAR](250)COLLATE ARABIC_CI_AI) 
	DECLARE @auditForParent BIT =  (Select TOP 1 op000.Value From op000 where name = 'AmncfBillOfManufactureIsAudited' )
	
	INSERT INTO [#BranchTbl]		SELECT [f].[Guid],[Security],[Name] FROM [fnGetBranchesList](@BranchGuid) [f] INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
	IF (@BranchGuid = 0X00)
		INSERT INTO [#BranchTbl] VALUES (0X00,0,'')
	INSERT INTO [#EntryTbl]	  
		SELECT [erParentGuid]   
		FROM [VWER] AS [er]   
		INNER JOIN [vwCE] AS [ce] ON [er].[erEntryGuid] = [ce].[ceGuid]   
		INNER JOIN [vwBu] AS [bu] ON [bu].[buGuid] = [er].[erParentGuid]  
		WHERE  (@Auditdate=0 AND (bu.buDate BETWEEN @FromDate AND @ToDate) ) OR  @Auditdate=1
	
	SELECT 
		Bu.*,
		biAu.Guid as biAuGuid,
		biAu.AuditDate [biAuditDate],
		biAu.AuditGuidType [biAuditGuidType],
		biAu.AuditRelGuid [biAuditRelGuid],
		biAu.UserGuid [biAuUserGuid],
		BU.GUID as buGuid,
		MB.ManGUID ,
		AU.Guid as [parentAuditGuid] ,
		AU.AuditGuidType as [parentAuditType] ,
		CASE  (select [BillGuid] from [#EntryTbl] WHERE [BillGuid] =  bu.GUID) WHEN  bu.GUID THEN 0 ELSE 1 END as isGenEntry,
		(SELECT 
				SUM(([bi].[Qty] + ISNULL(bonusqnt,0))/CASE [bi].[Unity] WHEN 1 THEN 1 WHEN 2 THEN CASE mt.unit2Fact WHEN 0 THEN 1 ELSE mt.unit2Fact END ELSE  CASE mt.unit3Fact WHEN 0 THEN 1 ELSE mt.unit3Fact END END)
				 AS
				 [Qty]
			FROM [bi000] [bi] INNER JOIN mt000 mt ON mt.Guid = bi.MatGuid where bi.ParentGUID=BU.GUID ) as buqty,
		(CASE WHEN [BuCe].[CeGUID] IS NULL THEN 0 ELSE [BuCe].[ceIsPosted] END) AS isEntryPosted,
		CASE WHEN ISNULL(BillGUID, 0x0) = 0x0 THEN 0 ELSE 1 END AS IsRelatedToManuf
	FROM 
		bu000 AS BU 	
		INNER JOIN RepSrcs AS RS ON BU.TypeGUID = RS.IdType
		INNER JOIN bt000 bt on bt.GUID=bu.TypeGUID
		LEFT JOIN mb000 As MB ON   BU.GUID = MB.BillGUID
		LEFT JOIN  Audit000 AS AU ON (@auditForParent = 1  And AU.AuditRelGuid = MB.ManGUID) 
		LEFT JOIN  Audit000 AS biAU ON ( biAU.AuditRelGuid = BU.GUID)  
		INNER JOIN [#BranchTbl] [br] ON br.Guid = BU.Branch
		LEFT JOIN vwBuCe [BuCe] ON BuCe.buGUID = BU.GUID
	WHERE 
		 rs.IdTbl = @RepSrc  
		 AND (@UserGuid = 0x0 OR Au.UserGUID = @UserGuid) 
		 AND (@StoreGuid = 0x0 OR BU.StoreGUID= @StoreGuid) 
		 AND (@CostGuid = 0x0 OR BU.CostGUID = @CostGuid) 
		 AND (@CustomerGuid = 0x0 OR BU.CustGUID = @CustomerGuid) 
		 AND ((@Auditdate=0 AND (BU.Date BETWEEN @FromDate AND @ToDate) )OR (@Auditdate=1 AND (AU.AuditDate BETWEEN @FromDate AND @ToDate)))
		 AND ( ISNULL(biAU.AuditGuidType,0) IN (CASE @Audit WHEN 1 THEN 1 ELSE -1 END,CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END)
		 OR  ISNULL(AU.AuditGuidType,0) IN (CASE @Audit WHEN 1 THEN 11 ELSE -1 END,CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END) )
		
	ORDER BY BU.Date 
	,(CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [bt].[Abbrev] ELSE (CASE [bt].[LatinAbbrev] WHEN '' THEN [bt].[Abbrev] ELSE [bt].[LatinAbbrev] END) END) 
			+ ': ' + CAST(bu.Number AS VARCHAR(10))
#################################################################
CREATE PROC prc_AuditOperationEntry
    @Audit     BIT,
	@NonAudit  BIT,
	@Auditdate BIT,
	@FromDate DATETIME,
    @ToDate   DATETIME,
	@UserGuid    UNIQUEIDENTIFIER,
	@BranchGuid    UNIQUEIDENTIFIER,
	@RepSrc        UNIQUEIDENTIFIER,
	@Bill Bit
AS
    SET NOCOUNT ON
	DECLARE @UserGUIDEn [UNIQUEIDENTIFIER], @UserSec [INT]
	SET @UserGUIDEn = [dbo].[fnGetCurrentUserGUID]()  
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Name] [NVARCHAR](250)COLLATE ARABIC_CI_AI) 
	
	INSERT INTO [#BranchTbl]		SELECT [f].[Guid],[Security],[Name] FROM [fnGetBranchesList](@BranchGuid) [f] INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
	IF (@BranchGuid = 0X00)
		INSERT INTO [#BranchTbl] VALUES (0X00,0,'')
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @RepSrc, @UserGUIDEn
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @RepSrc, @UserGUIDEn       
	
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])  
	 INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @RepSrc, @UserGUIDEn
	DECLARE @auditForManufacture BIT =  (Select TOP 1 op000.Value From op000 where name = 'AmncfBillOfManufactureIsAudited' )
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]  
	SELECT 
		[CeDate],
		[CeGuid],
		[CeNumber],
		[ParentGUID],
		[erParentType],
		[ParentTypeGuid],
		SUM(([EnDebiT]/enCurrencyVal )/ce.ceCurrencyVal) as Debit,
		SUM(([EnCredit]/enCurrencyVal)/ce.ceCurrencyVal) as Credit, 
		ceParentNumber,
		ceTypeAbbrev,
		ceTypeLatinAbbrev,
		Au.Guid as AuGuid,
		Au.AuditDate,
		Au.AuditGuidType,
		Au.AuditRelGuid,
		Au.UserGuid AuUserGuid,
		IIF( ([erParentType] = 3 OR [erParentType] = 4) AND ceAu.Guid IS NOT NULL  , [ParentGUID] , ceAu.Guid) as ceAuGuid,
		ceAu.AuditDate ceAuAuditDate,
		ceAu.AuditGuidType ceAuAuditGuidType,
		ceAu.AuditRelGuid  ceAuAuditRelGuid ,
		ceAu.UserGuid ceAuAuUserGuid,
		ce.ceIsPosted AS isEntryPosted
	FROM 
		[dbo].[fnExtended_En_Src]( @RepSrc) as ce
		--INNER JOIN [#EntryTbl] et on et.Type=ce.ParentTypeGUID
		LEFT JOIN  Audit000 AS AU ON   ( AU.AuditRelGuid = ce.ParentGUID )
		LEFT JOIN  Audit000 AS ceAu ON ceAu.AuditRelGuid = ce.ceGUID
		INNER JOIN [#BranchTbl] br on ce.ceBranch=br.GUID 
	WHERE 
		 (@UserGuid = 0x0 OR ceAu.UserGUID = @UserGuid) 
		 AND  ((@Auditdate=0 AND (ce.ceDate BETWEEN @FromDate AND @ToDate) )OR (@Auditdate=1 AND (ceAU.AuditDate BETWEEN @FromDate AND @ToDate)))
		 AND( ISNULL(ceAU.AuditGuidType,0) IN (CASE @Audit WHEN 1 THEN 3 ELSE -1 END,CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END)
		 OR ISNULL(AU.AuditGuidType,0) IN 
		 (CASE @Audit WHEN 1 THEN 4 ELSE -1 END,CASE WHEN (@Audit = 1  AND @Bill = 1)   THEN 1 ELSE -1 END , CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END))
	group by
		[CeDate],
		[CeGuid],
		[CeNumber],
		[CeNotes],
		[ParentGUID],
		[erParentType],
		[ParentTypeGuid],
		ceParentNumber,
		ceTypeAbbrev,
		ceTypeLatinAbbrev,
		Au.Guid ,
		Au.AuditDate,
		Au.AuditGuidType,
		Au.AuditRelGuid,
		Au.UserGuid ,
		ceAu.Guid ,
		ceAu.AuditDate,
		ceAu.AuditGuidType,
		ceAu.AuditRelGuid,
		ceAu.UserGuid,
		ce.ceIsPosted
	ORDER BY [CeDate],ce.ceNumber
#######################################################################################
CREATE PROC prc_AuditOperationCheque
	@Audit     BIT,
	@NonAudit  BIT,
	@Auditdate BIT,
	@FromDate DATETIME,
    @ToDate   DATETIME,
	@UserGuid    UNIQUEIDENTIFIER,
	@BranchGuid    UNIQUEIDENTIFIER,
	@Account	  UNIQUEIDENTIFIER,
	@Bank		    UNIQUEIDENTIFIER,
	@RepSrc        UNIQUEIDENTIFIER,
	@Bill Bit
AS
    SET NOCOUNT ON

	DECLARE @UserId [UNIQUEIDENTIFIER]
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()   
	

	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Name] [NVARCHAR](250)COLLATE ARABIC_CI_AI) 
	
	INSERT INTO [#BranchTbl]		SELECT [f].[Guid],[Security],[Name] FROM [fnGetBranchesList](@BranchGuid) [f] INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
	IF (@BranchGuid = 0X00)
		INSERT INTO [#BranchTbl] VALUES (0X00,0,'')

	SELECT 
		ch.chGUID,
		ch.chdate,
		ch.chParent,
		[nt].[Name] AS [chName],
		[nt].LatinName ,
		[ch].[chNum] AS [chNumber],
		ch.chDir,
		[ch].[chAccount] AS AccGuid,
		[ac].[acName] AS AccName,
		[ac].[acCode] as acCode,
		(CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [nt].[Abbrev] ELSE (CASE [nt].[LatinAbbrev] WHEN '' THEN [nt].[Abbrev] ELSE [nt].[LatinAbbrev] END) END) 
			+ ': ' + CAST(ch.chNumber AS VARCHAR(10)) as document,
		ch.chCurrencyPtr,
		ch.chCurrencyVal,
		ch.chVal,
		ch.chState,
		ch.chDueDate,
		CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN bk.BankName ELSE (CASE bk.BankLatinName WHEN '' THEN bk.BankName  ELSE bk.BankLatinName END) END AS bankName,
		bk.Number,
		cur.Name curName,
		Au.Guid as AuGuid,
		Au.AuditDate,
		Au.AuditGuidType,
		Au.AuditRelGuid,
		Au.UserGuid AuUserGuid,
		ceAu.Guid as ceAuGuid,
		ceAu.AuditDate ceAuAuditDate,
		ceAu.AuditGuidType ceAuAuditGuidType,
		ceAu.AuditRelGuid  ceAuAuditRelGuid ,
		ceAu.UserGuid ceAuAuUserGuid
	FROM 
		[vwCh] ch 
		INNER JOIN RepSrcs AS RS ON ch.chType = RS.IdType
		INNER JOIN [nt000] [nt] ON [nt].[GUID] = [ch].[chType]
		INNER JOIN [vwAc] [ac]  ON [ac].[acGUID] = [ch].[chAccount]
		INNER JOIN [#BranchTbl] br ON ch.chBranchGUID=br.GUID 
		INNER JOIN my000 cur  ON ch.chCurrencyPtr=cur.GUID 
		LEFT JOIN  bu000 bu   ON ch.chParent=bu.GUID
		LEFT JOIN  Audit000 AS AU ON AU.AuditRelGuid = bu.GUID
		LEFT JOIN  Audit000 AS ceAu ON ceAu.AuditRelGuid =  ch.chGUID
		LEFT JOIN  Bank000 bk ON ch.chBankGUID= bk.GUID 
	WHERE 
		rs.IdTbl = @RepSrc  
		AND (@Bank = 0x0 OR ch.chBankGUID = @Bank) 
		AND (@Account = 0x0 OR ch.chAccount = @Account) 
		AND ((@UserGuid = 0x0 OR Au.UserGUID = @UserGuid) 
			 OR (@UserGuid = 0x0 OR ceAu.UserGUID = @UserGuid) )
		AND (((@Auditdate=0 AND (ch.chDate BETWEEN @FromDate AND @ToDate) )OR (@Auditdate=1 AND (AU.AuditDate BETWEEN @FromDate AND @ToDate)))
			 OR ((@Auditdate=0 AND (ch.chDate BETWEEN @FromDate AND @ToDate) )OR (@Auditdate=1 AND (ceAU.AuditDate BETWEEN @FromDate AND @ToDate))))
	    AND( ISNULL(ceAU.AuditGuidType,0) IN (CASE @Audit WHEN 1 THEN 5 ELSE -1 END,CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END)
		 OR ISNULL(AU.AuditGuidType,0) IN 
		 (CASE @Audit WHEN 1 THEN 4 ELSE -1 END,CASE WHEN (@Audit = 1  AND @Bill = 1)   THEN 1 ELSE -1 END , CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END))
	
	ORDER BY ch.chdate,	(CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [nt].[Abbrev] ELSE (CASE [nt].[LatinAbbrev] WHEN '' THEN [nt].[Abbrev] ELSE [nt].[LatinAbbrev] END) END) 
			+ ': ' + CAST(ch.chNumber AS VARCHAR(10))
#######################################################################################
CREATE PROC prcAudit_disable
AS
    SET NOCOUNT ON
	
	DELETE FROM Audit000
#######################################################################################
CREATE PROC prc_AuditOperationManufacture
	@Audit     BIT,
	@NonAudit  BIT,
	@Auditdate BIT,
	@FromDate  DATETIME,
    @ToDate    DATETIME,
	@UserGuid    UNIQUEIDENTIFIER,
	@StoreGuid   UNIQUEIDENTIFIER,
	@CostGuid    UNIQUEIDENTIFIER,
	@FormGuid	 UNIQUEIDENTIFIER,
	@BranchGuid UNIQUEIDENTIFIER 
	
AS
	SET NOCOUNT ON
	DECLARE @UserId [UNIQUEIDENTIFIER]
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()  
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Name] [NVARCHAR](250))
	CREATE TABLE [#StoreTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT] , [Name] [NVARCHAR](250))
	CREATE TABLE [#CostTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT] , [Name] [NVARCHAR](250))
	CREATE TABLE [#FormTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT] , [Name] [NVARCHAR](250))
	CREATE TABLE [#AccountTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT] , [Name] [NVARCHAR](250))
	CREATE TABLE [#MatTbl] ( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT] , [Name] [NVARCHAR](250)    )
	INSERT INTO #StoreTbl 
	SELECT  [Guid],[Security],[Name] FROM  [st000] [st]  WHERE  @StoreGuid = 0x0 Or  [GUID] = @StoreGuid
																		
	INSERT INTO #CostTbl 												
	SELECT  [Guid],[Security],[Name] FROM  [co000] [co]  WHERE  @CostGuid = 0x0 Or  [GUID] = @CostGuid 
																		
	INSERT INTO #FormTbl												
	SELECT [Guid],[Security],[Name] FROM  [vcFm] [fm] WHERE  @FormGuid = 0x0  Or   [GUID] = @FormGuid
																		
	INSERT INTO #AccountTbl												
	SELECT [Guid], [Security] ,[Name] FROM  [ac000] [ac] 
	INSERT INTO [#BranchTbl]		
	SELECT [f].[Guid],[Security],[Name] FROM [fnGetBranchesList](@BranchGuid) [f] INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
	IF (@BranchGuid = 0X00) INSERT INTO [#BranchTbl] VALUES (0X00,0,'')
	
	;WITH MT AS
	(
		SELECT 
			mi.ParentGUID,
			MI.Unity ,
			Mi.Qty, 
			Mi.Qty2, 
			Mi.Qty3, 		
			mt.Name, 
			mt.Code , 
			mt.Unity As Unit 
		FROM 
			mi000 AS MI 
			INNER JOIN mt000 MT ON mi.MatGUID = mt.GUID 
		WHERE 
			Mi.Type = 0 AND Mi.Number = 1
	) , 
	 BU AS 
	 (
		Select ManGUID  , [0] + ISNULL([2],0)  As [InTotal]  , [1] As [OutTotal] , [2] As [SemiTotal]   From (  Select mb.ManGUID , Total ,  Type   FROM bu000 bu
		INNER JOIN MB000 mb ON mb.BillGUID = bu.[GUID] ) t
		PIVOT 
		(
			SUM(Total)
			For [Type] IN ([0] ,[1] , [2])
		) As PivotTable 
	 )
	Select	 
		IsNULL(stIn.Name,'')    AS [InStoreName],
		IsNULL(stOut.Name,'')   AS [OutStoreName],
		IsNULL(coIn.Name,'')    AS [InCostName],
		IsNULL(coOut.Name,'')   AS [OutCostName],
		IsNULL(coStep.Name,'')  AS [StepCostName],
		ISNULL(accIn.Name,'')   AS [InAccName],
		ISNULL(accOut.Name,'')  AS [OutAccName],
		ISNULL(accIn.Name,'')   AS [InAccName],
		ISNULL(accOutTemp.Name,'') AS [OutTempAccName],
		ISNULL(accInTemp.Name,'') AS [InTempAccName],
		mn.GUID  ,
		mn.[Date],
		mn.Notes , 
		mn.Number , 
		PhaseNumber ,
		my.Name As [currName] ,
		frm.Name As [formName] , 
		mn.CurrencyVal ,
		InDate, 
		OutDate,
		LOT , 
		(CASE MT.Unity WHEN 1 THEN MT.Qty WHEN 2 THEN MT.Qty2 ELSE MT.Qty3 END) As [Qty]   ,	
		MT.Unit ,
		UnitPrice / ( CASE ISNull(mn.CurrencyVal,0) WHEN 0 THEN 1 ELSE mn.CurrencyVal END) As[UnitPrice] ,
		TotalPrice / ( CASE ISNull(mn.CurrencyVal,0) WHEN 0 THEN 1 ELSE mn.CurrencyVal END) As [TotalPrice] ,
		ProductionTime,
		mn.PriceType ,
		Au.[Guid] As [AuGuid],
		Au.AuditDate,
		Au.AuditGuidType,
		Au.AuditRelGuid,
		Au.UserGuid ,
		Mt.Name As [matName], 
		InTotal  / ( CASE ISNull(mn.CurrencyVal,0) WHEN 0 THEN 1 ELSE mn.CurrencyVal END) As [InTotal] , 
		OutTotal  / ( CASE ISNull(mn.CurrencyVal,0) WHEN 0 THEN 1 ELSE mn.CurrencyVal END) As [OutTotal]
	 FROM 
		MN000 As MN 
		LEFT JOIN Audit000 AU ON AU.AuditRelGuid = MN.GUID  
		LEFT JOIN #FormTbl frm ON MN.FormGUID = frm.GUID 
		INNER JOIN #BranchTbl [br] ON [br].GUID = MN.BranchGUID
		LEFT JOIN #StoreTbl stIn ON MN.InStoreGUID = stIn.GUID 
		LEFT JOIN #StoreTbl stOut ON MN.OutStoreGUID = stOut.GUID 
		LEFT JOIN #CostTbl coIn ON MN.InCostGUID = coIn.GUID
		LEFT JOIN #CostTbl coOut ON MN.OutCostGUID = coOut.GUID
		LEFT JOIN #CostTbl coStep ON MN.StepCost = coStep.GUID
		LEFT JOIN #AccountTbl accIn ON MN.InAccountGUID = accIn.GUID 
		LEFT JOIN #AccountTbl accOut ON MN.OutAccountGUID = accOut.GUID 
		LEFT JOIN #AccountTbl accOutTemp ON MN.OutTempAccGUID = accOutTemp.GUID   
		LEFT JOIN #AccountTbl accInTemp ON MN.InTempAccGUID = accInTemp.GUID   
		INNER JOIN MT ON MT.ParentGUID = mn.GUID 
		INNER JOIN BU ON BU.ManGUID = mn.Guid
		INNER JOIN my000 my ON my.GUID = mn.CurrencyGUID 
	WHERE 
		(@UserGuid = 0x0  OR AU.UserGuid = @UserGuid) 
		AND ( @StoreGuid = 0x0 OR MN.InStoreGUID = @StoreGuid OR MN.OutStoreGUID = @StoreGuid ) 
		AND ( @CostGuid = 0x0 OR MN.InCostGUID = @CostGuid OR MN.OutCostGUID = @CostGuid OR MN.CostSemiGUID = @CostGuid ) 
		AND ( @FormGuid = 0x0 OR MN.FormGUID = @FormGuid )
		AND ((@Auditdate=0 AND (MN.Date BETWEEN @FromDate AND @ToDate) )OR (@Auditdate=1 AND (AU.AuditDate BETWEEN @FromDate AND @ToDate))) 
		AND ISNULL(AU.AuditGuidType,0) IN (CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END,CASE @Audit WHEN 1 THEN 11 ELSE -1 END)
	ORDER BY MN.Date 
 
#######################################################################################
#END