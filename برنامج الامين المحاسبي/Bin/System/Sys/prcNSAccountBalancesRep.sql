################################################################################
CREATE  PROCEDURE NSAccBalRep
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@AccountGUID		[UNIQUEIDENTIFIER],
	@CostGuid			[UNIQUEIDENTIFIER],
	@BranchGuid			[UNIQUEIDENTIFIER],
	@SrcGuid			[UNIQUEIDENTIFIER] = 0X0,
	@FinalBalances		[FLOAT] = 0.0 OUTPUT

AS
BEGIN
	SET NOCOUNT ON;

	DECLARE  @AccCurGuid UNIQUEIDENTIFIER
	SET @AccCurGuid = (SELECT CurrencyGUID FROM ac000 WHERE GUID = @AccountGUID)
	CREATE TABLE #Accounts ([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [VARCHAR](8000), 
							[acSecurity] INT, acType INT, acNsons INT, acNotes NVARCHAR(250),[CurGuid] [UNIQUEIDENTIFIER])
	INSERT INTO 
		#Accounts 
	SELECT 
		a.*,
		ac.acsecurity,
		ac.acType,
		ac.acNsons,
		ac.acNotes,
		ac.acCurrencyPtr
	FROM 
		[dbo].[fnGetAcDescList](@AccountGUID) a 
		INNER JOIN 	vwAc ac ON a.guid = ac.acguid
		
	CREATE TABLE [#BillTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT, [ReadPriceSecurity] INT)
	CREATE TABLE [#EntryTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT)   

	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, 0x0
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, 0x0       
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, 0x0
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl]   
	DECLARE @Cost_Tbl TABLE( [GUID] UNIQUEIDENTIFIER) 
	INSERT INTO @Cost_Tbl SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)
	IF ISNULL(@CostGUID, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)
		 
	DECLARE @Branch_Tbl TABLE( [GUID] UNIQUEIDENTIFIER) 
	INSERT INTO @Branch_Tbl SELECT [GUID] FROM [dbo].[fnGetBranchesList]( @BranchGUID)
	IF ISNULL(@BranchGuid, 0x0) = 0x0   
		INSERT INTO @Branch_Tbl VALUES(0x0)   
	-----------------------------------------------------------
	CREATE TABLE [#Result](
		[AccountGUID]	UNIQUEIDENTIFIER, 
		[Debit]			FLOAT,
		[Credit]		FLOAT,
		[Security]		INT,
		[AccSecurity]	INT)
	CREATE TABLE [#EndResult](
		[AccountGUID]	UNIQUEIDENTIFIER, 
		[Debit]			FLOAT,
		[Credit]		FLOAT,
		[Balanc]		FLOAT,
		[PrevBalance]	FLOAT)
	
	INSERT INTO [#Result]
	SELECT
		[ac].[Guid],
		[fn].[FixedEnDebit],
		[fn].[FixedEnCredit],
		[fn].[ceSecurity],
		[ac].[acSecurity]
	FROM
		([dbo].[fnExtended_En_Fixed_Src]( @SrcGuid , @AccCurGuid) AS [fn]
		INNER JOIN #Accounts AS [ac] ON [fn].[enAccount] = [ac].[Guid]
		INNER JOIN @Cost_Tbl AS [Cost] ON [fn].[enCostPoint] = [Cost].[GUID]
		INNER JOIN @Branch_Tbl AS [Branch] ON [fn].[ceBranch] = [Branch].[GUID])
		LEFT JOIN [#EntryTbl] src ON [fn].[ParentTypeGUID] = src.[Type]
	WHERE
		[fn].[enDate] BETWEEN @StartDate AND @EndDate
		AND [fn].[ceIsPosted] = 1
		AND [ac].[acType] <> 2 AND  [ac].[acNSons] = 0

	INSERT INTO [#EndResult]
	SELECT 
		[r].[AccountGUID],
		SUM([r].[Debit]),
		SUM([r].[Credit]),
		CASE [ac].[acWarn]
			WHEN 2 THEN - (SUM([r].[Debit]) - SUM([r].[Credit]))
			ELSE  SUM( [r].[Debit]) - SUM( [r].[Credit])
		END,
		0
	FROM
		[#Result] As [r] 
		INNER JOIN [vwAc] AS [ac] ON [r].[AccountGUID] = [ac].[acGUID]
	GROUP BY
		[r].[AccountGUID],
		[ac].[acWarn]

	SELECT @FinalBalances = (SELECT
		sum([Res].[Debit] - [Res].[Credit]) AS Balance
	FROM
		[#EndResult] AS [Res] 
		)
		
END
################################################################################
CREATE PROCEDURE PrcNSGetAccountBalancesDate
	@DateType INT,
    @Date DATETIME OUTPUT

AS
BEGIN 
SET NOCOUNT ON;
Declare @startOfWeekDay INT = (SELECT [dbo].[fnOption_get]('AmnCfg_StartOfWeekDay', '6'))
SET DATEFIRST @startOfWeekDay;


SELECT 
    @Date = CASE @DateType
                        WHEN 0 
							THEN
								-- «Ê· «·„œ… 
								(SELECT CAST((SELECT value FROM op000 where name = 'AmnCfg_FPDate' )as datetime))
                        WHEN 1 
							THEN 
								-- «Ê· «·‘Â— «·”«»ﬁ
								(select DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0))
						WHEN 2 
							THEN 
								-- ‰Â«Ì… «·‘Â— «·”«»ﬁ
								(select DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) )
						WHEN 3 
							THEN 
								-- «Ê· «·‘Â— «·Õ«·Ì 
								(SELECT DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0))
						WHEN 4 
							THEN 						
								-- «Ê· «·«”»Ê⁄ «·”«»ﬁ
								(SELECT DATEADD(dd, -(DATEPART(dw, getdate())-1)-7, DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)))
						WHEN 5 
							THEN 						
								-- ‰Â«Ì… «·«”»Ê⁄ «·”«»ﬁ
								(SELECT DATEADD(dd, -(DATEPART(dw, getdate())-1)-1, DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)))
						WHEN 6 
							THEN 
								-- «Ê· «·«”»Ê⁄ «·Õ«·Ì 
								(SELECT DATEADD(dd, -(DATEPART(dw, getdate())-1), DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)))
						WHEN 7 
							THEN 
								-- «·ÌÊ„ «·”«»ﬁ 
								(SELECT	DATEADD(day, DATEDIFF(day, 0, GETDATE()), -1))
						ELSE  
								-- «·ÌÊ„ «·Õ«·Ì 
								(SELECT DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0))
						 END
END
################################################################################
#END
