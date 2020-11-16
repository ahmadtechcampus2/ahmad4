##########################################################################
CREATE PROCEDURE prcDDEGetMatStoreQty
	@MatName	[NVARCHAR](256),
	@StoreName	[NVARCHAR](256),
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@BillType	[UNIQUEIDENTIFIER] = 0x0
AS
	SET NOCOUNT ON
	DECLARE @StGuid [UNIQUEIDENTIFIER]
	IF @StoreName <> ''
		SELECT @StGuid = Guid FROM [st000] WHERE [Name] = @StoreName
	ELSE
		SET  @StGuid = 0X00
	CREATE TABLE [#BillTbl]([Type] [UNIQUEIDENTIFIER],[Security] [INT], [ReadPriceSecurity] [INT])
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @BillType
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StGuid 
	SELECT
		SUM(([bu].[biQty] + [bu].[biBonusQnt]) * [buDirection] /** btIsInput */) AS [Qty]
		--[mt].[name],
		--[st].[name] 
	FROM 
		[vwbubi] AS [bu] 
		INNER join [mt000] AS [mt] ON [mt].[guid] = [bu].[bimatptr] 
		INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bu].[biStorePtr]
		INNER JOIN [#BillTbl] AS [bt] ON [buType] = [bt].[Type]
	WHERE
		mt.name = @MatName
		--AND ( ( @StoreName = '') OR (st.name = @StoreName))
		AND bu.buDate BETWEEN @StartDate AND @EndDate
	GROUP BY
		mt.name

/*

EXEC [prcDDEGetMatStoreQty] 'Õ«ÊÌ… „Ì—ﬂÊ—Ì 181', '„” Êœ⁄ ’«·Õ', '8/28/2007', '1/13/2008'
select * from ac000
*/
##########################################################################
CREATE PROCEDURE prcDDEGetGroupValue
	@GrCode	[NVARCHAR](256),
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@BillType	[UNIQUEIDENTIFIER] = 0x0,
	@CurrGuid	[UNIQUEIDENTIFIER] = 0x0,
	@BuSec		[INT],
	@MtSec		[INT],
	@AcCode		[NVARCHAR](256) = ''
AS
	SET NOCOUNT ON
	DECLARE @Gr UNIQUEIDENTIFIER,@Ac UNIQUEIDENTIFIER
	IF (@AcCode = '')
		SET @Ac = 0X00
	ELSE
		SELECT @Ac = [Guid] FROM [ac000] WHERE [Code] = @AcCode 
	CREATE TABLE [#BillTbl]([Type] [UNIQUEIDENTIFIER],[Security] [INT], [ReadPriceSecurity] [INT])
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @BillType
	SELECT @Gr = [Guid] FROM [gr000] WHERE CODE = @GrCode
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Security] [INT])    
	INSERT INTO [#Cust]( [Number], [Security]) EXEC [prcGetCustsList] 0X00, @Ac
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		0x00, @Gr ,-1
	IF (@Ac = 0X00)
		INSERT INTO [#Cust] VALUES(0X00,-3)
	SELECT ISNULL(SUM([buDirection]*[FixedBiTotal]),0) AS [Total]  
	FROM [fnExtended_bi_Fixed](@CurrGuid) AS [bu]
	INNER JOIN [#MatTbl] as [mt] ON [mt].[MatGUID] = [biMatPtr]
	INNER JOIN [#Cust] AS [cu] ON [cu].[Number] = [buCustPtr]
	INNER JOIN [#BillTbl] AS [bt] ON [buType] = [bt].[Type]
	WHERE [buSecurity] <= @BuSec AND [mt].[mtSecurity] <= @MtSec
	AND [buIsPosted] > 0 AND [buDate] BETWEEN @StartDate AND @EndDate
	AND ([cu].[Security] < dbo.fnGetUserCustomerSec_Browse([dbo].[fnGetCurrentUserGUID]()))
##########################################################################
CREATE PROCEDURE prcDDEGetGroupQnt
	@GrCode	[NVARCHAR](256),
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@BillType	[UNIQUEIDENTIFIER] = 0x0,
	@BuSec		[INT],
	@MtSec		[INT],
	@Unit		[INT] = 0,
	@AcCode		[NVARCHAR](256) = ''
AS
	SET NOCOUNT ON
	DECLARE @Gr [UNIQUEIDENTIFIER],@Ac [UNIQUEIDENTIFIER] 
	SELECT @Gr = [Guid] FROM [gr000] WHERE CODE = @GrCode
	
	IF (@AcCode = '')
		SET @Ac = 0X00
	ELSE
		SELECT @Ac = [Guid] FROM [ac000] WHERE [Code] = @AcCode 
	CREATE TABLE [#BillTbl]([Type] [UNIQUEIDENTIFIER],[Security] [INT], [ReadPriceSecurity] [INT])
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @BillType	
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Security] [INT])    
	INSERT INTO [#Cust]( [Number], [Security]) EXEC [prcGetCustsList] 0X00, @Ac
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		0x00, @Gr ,-1
	
	IF (@Ac = 0X00)
		INSERT INTO [#Cust] VALUES(0X00,-3)
	
	SELECT SUM([buDirection]*[biQty]/ CASE @Unit WHEN 0 THEN 1 
	WHEN 1 THEN CASE [mt2].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt2].[Unit2Fact] END
	WHEN 2 THEN CASE [mt2].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt2].[Unit3Fact] END
	ELSE
		CASE [mt2].[DefUnit]
			WHEN 2 THEN CASE [mt2].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt2].[Unit2Fact] END
			WHEN 3 THEN CASE [mt2].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt2].[Unit3Fact] END
			ELSE
			 1
		END
	END ) AS [Qnt]
	FROM [vwBuBi] AS [bu]
	INNER JOIN [#MatTbl] as [mt] ON [mt].[MatGUID] = [biMatPtr]
	INNER JOIN [#Cust] AS [cu] ON [cu].[Number] = [buCustPtr]
	INNER JOIN [mt000] AS [mt2] ON [mt].[MatGUID] = [mt2].[Guid]
	INNER JOIN [#BillTbl] AS [bt] ON [buType] = [bt].[Type]
	WHERE  [buSecurity] <= @BuSec AND [mt].[mtSecurity] <= @MtSec
	AND [buIsPosted] > 0 AND [buDate] BETWEEN @StartDate AND @EndDate
	AND ([cu].[Security] < dbo.fnGetUserCustomerSec_Browse([dbo].[fnGetCurrentUserGUID]()))
##########################################################################
CREATE PROCEDURE prcDDEGetGroupCount
	@GrCode	[NVARCHAR](256),
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@BillType	[UNIQUEIDENTIFIER] = 0x0,
	@BuSec		[INT],
	@MtSec		[INT],
	@AcCode		[NVARCHAR](256) = ''
AS
	SET NOCOUNT ON
	DECLARE @Gr [UNIQUEIDENTIFIER],@Ac [UNIQUEIDENTIFIER] 
	SELECT @Gr = [Guid] FROM [gr000] WHERE CODE = @GrCode
	
	IF (@AcCode = '')
		SET @Ac = 0X00
	ELSE
		SELECT @Ac = [Guid] FROM [ac000] WHERE [Code] = @AcCode 
	CREATE TABLE [#BillTbl]([Type] [UNIQUEIDENTIFIER],[Security] [INT], [ReadPriceSecurity] [INT])
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @BillType	
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Security] [INT])    
	INSERT INTO [#Cust]( [Number], [Security]) EXEC [prcGetCustsList] 0X00, @Ac
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		0x00, @Gr ,-1
	
	IF (@Ac = 0X00)
		INSERT INTO [#Cust] VALUES(0X00,-3)
	
	SELECT COUNT(DISTINCT CAST([buGuid] AS NVARCHAR(40))) AS [Count]
	FROM [vwBuBi] AS [bu]
	INNER JOIN [#MatTbl] as [mt] ON [mt].[MatGUID] = [biMatPtr]
	INNER JOIN [#Cust] AS [cu] ON [cu].[Number] = [buCustPtr]
	INNER JOIN [#BillTbl] AS [bt] ON [buType] = [bt].[Type]
	WHERE  [buSecurity] <= @BuSec AND [mt].[mtSecurity] <= @MtSec
	AND [buDate] BETWEEN @StartDate AND @EndDate
	AND ([cu].[Security] < dbo.fnGetUserCustomerSec_Browse([dbo].[fnGetCurrentUserGUID]()))
##########################################################################
CREATE PROCEDURE prcDDGetAccountsCount
	@AccCode	[NVARCHAR](256)
AS
	SET NOCOUNT ON
	DECLARE @Guid [UNIQUEIDENTIFIER]
	SELECT @Guid = [Guid] FROM [ac000] WHERE [Code] = @AccCode
	SELECT COUNT(*) -1 AS [Cnt] FROM [dbo].[fnGetAccountsList](@Guid,0) 
######################################################################################
#END