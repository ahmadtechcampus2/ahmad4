##########################################################
CREATE PROCEDURE repBillNoSn
	@StartDate 		[DATETIME],
	@EndDate 		[DATETIME],
	@SrcTypesguid	[UNIQUEIDENTIFIER],
	@MatGUID 		[UNIQUEIDENTIFIER],
	@GroupGUID 		[UNIQUEIDENTIFIER],
	@PostedValue 	[INT],
	@CustGUID 		[UNIQUEIDENTIFIER],
	@AccGUID 		[UNIQUEIDENTIFIER],
	@MatCondGuid	[UNIQUEIDENTIFIER] = 0X00,
	@CostGUID 		[UNIQUEIDENTIFIER] = 0x00
AS
	SET NOCOUNT ON
	-- Creating temporary tables
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER])
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT])
	--Filling temporary tables
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid,-1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] @SrcTypesguid
	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGuid, @AccGuid
	IF (@AccGUID = 0X00) AND (@CustGUID = 0X00)
		INSERT INTO [#CustTbl]	VALUES (0X00,0)
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	SELECT [MatGuid] , [mtSecurity],[Name] AS [mtName],[SNFlag] AS  [mtSNFlag],[ForceInSN] AS [mtForceInSN] ,[ForceOutSN]AS [mtForceOutSN] 
	INTO [#MatTbl2] 
	FROM [#MatTbl] INNER JOIN [mt000] ON [Guid] = [MatGuid]
	WHERE [SNFlag] = 1
	CREATE TABLE [#Result]
	(
		[buType] 				[UNIQUEIDENTIFIER],
		[buNumber] 				[UNIQUEIDENTIFIER] NOT NULL, 
		[biGUID]				[UNIQUEIDENTIFIER] NOT NULL, 
		[biMatPtr]				[UNIQUEIDENTIFIER],
		[mtName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[buDate]				[DATETIME],
		[buVendor]				[FLOAT],
		[buSalesManPtr]			[FLOAT],
 		[buCust_Name]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[buNotes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[buFormatedNumber]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[buLatinFormatedNumber]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[biQty]				[FLOAT],
		[Security]			[INT],
		[UserSecurity] 		[INT],
		[MtSecurity]		[INT],
		[btDirection]		[INT]
	)
	--- we use left join cause inner join did'nt get bills that has no sn 
	INSERT INTO [#Result]
	SELECT
		[bi].[butype],
		[bi].[buGUID],
		[bi].[biGUID],
		[bi].[biMatPtr],
		[mtTbl].[mtName],
		[bi].[buDate],
		[bi].[buVendor],
		[bi].[buSalesManPtr],
		[bi].[buCust_Name],
		[bi].[buNotes],
		[bi].[buFormatedNumber],
		[bi].[buLatinFormatedNumber],
		[biQty] + [biBonusQnt],
		[buSecurity],
		CASE [buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnPostedSecurity] END,
		[mtTbl].[mtsecurity],
		[btDirection]
		
	FROM
		[vwbubi] AS [bi]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [bi].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [bi].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN [#CustTbl] AS [cu] ON [BuCustPtr]= [CustGUID]
		INNER JOIN  [#CostTbl] AS [co] ON [co].[CostGUID] = [Bi].[biCostPtr]
	WHERE
		(
			(([mtForceOutSN] = 1)	AND ([bi].[btIsOutput] = 1))
			OR  (([mtForceINSN] = 1)	AND ([bi].[btIsInput] = 1))
			
		)
		AND budate BETWEEN @StartDate AND @EndDate 
		AND( (@PostedValue = -1) 				OR ([BuIsPosted] = @PostedValue))
	ORDER BY [buDate],[buSortFlag],[buNumber],[biNumber]
	EXEC [prcCheckSecurity]	
	SELECT [b].[biGUID],ISNULL(SN,'') AS [SN]
	INTO [#SN]
	FROM
		(SELECT [r].[biGUID]   FROM [#Result] [r] LEFT JOIN (select count(*) cnt ,biguid from vcSNS group by biguid ) AS [SN] ON [SN].[biguid] = [r].[biGUID] where ISNULL(cnt,0) <> [biQty]    ) AS B LEFT JOIN [vcSNS] [S] ON [b].[biGUID] = [s].[biGuid]
	---return result set
	SELECT 
		[r].[buType],
		[r].[buNumber],
		[r].[buDate] AS BuDate,
		[r].[buCust_Name] AS BuCustomerName,
		[r].[buFormatedNumber],
		[r].[buLatinFormatedNumber],
		[r].[biMatPtr],
		[r].[mtName] AS MtName,
		[sn]
	FROM
		[#Result] AS [r] INNER JOIN [#SN] AS [sn] ON [r].[biGUID] = [sn].[biGUID]
	ORDER BY
		[r].[buDate]

	SELECT *FROM [#SecViol]
	SET NOCOUNT OFF

/*
prcConnections_add2 'rawa'
exec   [repBillNoSn] '1/1/2008 0:0:0.0', '9/13/2008 23:59:59.998', '06daf02d-3064-4907-9617-487e76830c15', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 1, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000'
*/
#########################################################
#END