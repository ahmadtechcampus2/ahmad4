######################################################################################
###
###
CREATE PROCEDURE repInputBillSn
	@CustPtr	[UNIQUEIDENTIFIER],
	@BillType	[UNIQUEIDENTIFIER],
	@BillNumber	[INT],
	@Posted		[INT],
	@UnPosted	[INT],
	@Lang		[INT] = 0
AS
	SET NOCOUNT ON

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSec] [INT],[UnpostedSec] [INT])
	CREATE TABLE [#Result] 
		( 
			[buGUID] [UNIQUEIDENTIFIER], 
			[BillType] [UNIQUEIDENTIFIER], 
			[Security]				[INT], 
			[UserSecurity] 			[INT], 
			[BillName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[CustName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[BillNum] [INT],
			[cnt] [INT],
			[BillDate] [DATETIME], 
			[Qty] [FLOAT]
		)

	-- fill the variable with data 

	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList2] 0X00
	INSERT INTO [#Result]
		SELECT DISTINCT
			[bu].[buGuid], 
			[buType], 
			[buSecurity], 
			CASE [buIsPosted] WHEN 1 THEN [Security] ELSE [UnpostedSec] END,
			CASE @Lang WHEN 0 THEN [btAbbrev] ELSE CASE [btLatinAbbrev] WHEN '' THEN [btAbbrev] ELSE [btLatinAbbrev] END END,
			
			[bu].[buCust_Name],
			[bu].[buNumber],
			COUNT( [sn].[sn]),
			[buDate],
			[biQty] 
		FROM 
			[vwExtended_bi] as [bu] 
			INNER JOIN [#BillTbl] as [b] ON [bu].[buType] = [b].[Type]
			LEFT JOIN [vcsns] as [sn] ON [bu].[biGuid] = [sn].[biGuid]
		WHERE 
			[mtSNFlag] = 1 AND
			( @UnPosted <> 0 OR [bu].[buIsPosted] = 1) AND
			( @Posted <> 0 OR [bu].[buIsPosted] = 0) AND
			( ISNULL( @CustPtr, 0x0) = 0x0 OR [bu].[buCustPtr] = @CustPtr) AND
			( ISNULL( @BillType, 0x0) = 0x0 OR [bu].[buType] = @BillType) AND
			( @BillNumber = 0 OR [bu].[buNumber] = @BillNumber) AND
			[btIsInput] = 0 AND [btType] = 1
		GROUP BY
			[bu].[buGuid], 
			[bu].[biGuid], 
			[buType], 
			[buSecurity], 
			[Security],
			[btAbbrev],
			[btLatinAbbrev],
			[buCust_Name],
			[buNumber],
			[buDate],
			[biQty],
			[buIsPosted],
			[UnpostedSec]
		HAVING ISNULL(COUNT( [sn].[sn]),0) < [biQty]

		EXEC [prcCheckSecurity] 
	SELECT DISTINCT [buGuid], [BillName], [CustName], [BillDate], [BillNum] FROM [#Result] order By [BillDate], [BillNum]
	SELECT * FROM [#SecViol]
	SET NOCOUNT OFF

-- exec  [repInputBillSn] '00000000-0000-0000-0000-000000000000', 'b13028d7-3cbf-4fb3-92f5-3b20b29febc3', 0, 0, 1, 0
######################################################################################
#END
