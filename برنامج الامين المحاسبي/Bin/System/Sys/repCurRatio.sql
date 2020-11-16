################################################################################
CREATE FUNCTION fnGetBalanceByDate( 
		@StartDate	[DATETIME],	 
		@EndDate	[DATETIME],	
		@accGuid 	[uniqueidentifier], 
		@PostedType	[INT]	 		--- 1 posted, 0 unposted -1 both       
) 
	returns [float] 
AS 
BEGIN
	DECLARE @result [float] 
	
	SET @result = ( 
			SELECT  
				SUM([enDebit])  
					- SUM([enCredit])  
			FROM
				[vwCeEn] INNER JOIN [vwac] On [enAccount] = [acGuid]
				inner join [fnGetAccountsList](@accGuid, 0) [f] on [enAccount] = [f].[guid]
			WHERE 
				[enDate] BETWEEN @StartDate AND @EndDate 
				AND( (@PostedType = -1) OR ( @PostedType = 1 AND [ceIsPosted] = 1)       
					OR (@PostedType = 0 AND [ceIsPosted] = 0) )   
			)   
	
	RETURN ISNULL(@result, 0.0) 
END 


/*

select dbo.fnGetBalanceByDate( 
'1/1/2002',--		@StartDate	DATETIME,	 
'4/5/2004',--		@EndDate	DATETIME,	
'A2DE26B6-E048-4AA9-980F-C106E6BF96D6',--		@accGuid 	uniqueidentifier, 
'80CA8DC5-8486-4D90-BDE9-0C0C0686EA71',--		@curGuid 	uniqueidentifier = 0x0,
1) --		@ShowPosted	INT	 		--- 1 posted, 0 unposted -1 both       

*/
################################################################################
CREATE VIEW vdAcCurr
AS
	SELECT * FROM vdAc WHERE NSons > 0 OR currencyGuid <>(select guid from my000 where currencyval = 1) 
################################################################################
CREATE PROCEDURE repCurRatio 
	@StartDate		[DATETIME],	 
	@EndDate		[DATETIME],		 
	@AccGUID 		[UNIQUEIDENTIFIER],			 
	@ShowPosted		[INT],
	@ShowUnPosted	[INT],
	@CostGuid		[UNIQUEIDENTIFIER] = 0X00,
	@ShowDetails	[BIT] = 0,
	@BranchGUID		[UNIQUEIDENTIFIER] = 0x0
AS    
	SET NOCOUNT ON
	DECLARE @FirstCurr UNIQUEIDENTIFIER
	--- 1 posted, 0 unposted -1 both       
	DECLARE @PostedType AS  [INT]      
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 0) )		         
		SET @PostedType = 1      
	IF( (@ShowPosted = 0) AND (@ShowUnPosted = 1))         
		SET @PostedType = 0      
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 1))         
		SET @PostedType = -1      
	SELECT @FirstCurr = [Guid] FROM my000 WHERE NUMBER = 1  AND CurrencyVal = 1 
	DECLARE @UserGUID [UNIQUEIDENTIFIER]
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	CREATE TABLE [#CostTbl]		( [Cost] [UNIQUEIDENTIFIER], [CostSec] [INT])
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	-- Security Table ---------------------------------------------------------------- 
	CREATE TABLE [#SecViol] 
	(     
		[Type] 	[INT],    
		[Cnt]  	[INT]    
	)  
	----------------------------------------------------------------------------------
	------- Main Result table --------------------------------------------------------  
	CREATE TABLE [#Result](
		[EnDebit]		[FLOAT],    
		[EnCredit]		[FLOAT],   
		[Balance]		[FLOAT],   
		[CurBalance]	[FLOAT], 
		[AccGUID]		[UNIQUEIDENTIFIER],
		[AccName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[AccCode]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[AccLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[AccSecurity] 	[INT],	 
		[MhCurGUID]		[UNIQUEIDENTIFIER], 
		[MhCurVal] 		[FLOAT],
		[EntryNumber]	[INT] default 0,
		[EntryDate]		[DATETIME],
		[EntryGUID]		[UNIQUEIDENTIFIER],
		[IsDetail]		[BIT] default 0,
		[MYCODE] [NVARCHAR](50)
	)   
	---------------------------------------------------------------------------------
	--------- Details Result Table --------------------------------------------------
	CREATE TABLE [#ResultDetails](
		[DetailsEnDebit]		[FLOAT],    
		[DetailsEnCredit]		[FLOAT],   
		[DetailsBalance]		[FLOAT],   
		[DetailsCurBalance]	[FLOAT], 
		[DetailsAccGUID]		[UNIQUEIDENTIFIER],
		[DetailsAccName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[DetailsAccCode]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[DetailsAccLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[DetailsAccSecurity] 	[INT],	 
		[DetailsMhCurGUID]		[UNIQUEIDENTIFIER], 
		[DetailsMhCurVal] 		[FLOAT],
		[DetailsEntryNumber]	[INT] default 0,
		[DetailsEntryDate]		[DATETIME],
		[DetailsEntryGUID]		[UNIQUEIDENTIFIER],
		[DetailsMYCODE] [NVARCHAR](50)
	) 
	--------------------------------------------------------------------------------
	INSERT INTO [#Result]
		SELECT 	
			SUM([enDebit]),
			SUM([enCredit]),
			--[dbo].[fnGetBalanceByDate]( @StartDate, @EndDate, [acGUID], @PostedType), 
			SUM([enDebit]) - SUM([enCredit]),
			sum([dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], [acCurrencyPtr], [endate])) 
				- sum([dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal], [acCurrencyPtr], [endate])), 		
			[acGUID],    
			[acName],
			[acCode],
			[acLatinName],    
			[acSecurity], 
			[acCurrencyPtr],
			[dbo].[fnGetCurVal]([acCurrencyPtr], @EndDate),
			0,
			'1/1/1980',
			0x0,
			0,
			''
		FROM
			[vwCeEn] INNER JOIN [vwac] On [enAccount] = [acGuid]
			INNER JOIN [fnGetAccountsList](@AccGuid, 0) [f] on [enAccount] = [f].[guid]
			INNER JOIN [#CostTbl] [co] ON [co].[Cost] = [enCostPoint]
		WHERE 
			[enDate] BETWEEN @StartDate AND @EndDate 
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND [ceIsPosted] = 1)       
				OR (@PostedType = 0 AND [ceIsPosted] = 0) ) 
			AND [acCurrencyPtr] <>  @FirstCurr 
			AND [vwCeEn].[ceBranch] = @BranchGUID
		GROUP BY 
			[acGuid], [acCode], [acName], [acLatinName], [acSecurity], [acCurrencyPtr]
	IF @ShowDetails = 1
	BEGIN
		-------------- Details Table --------------------------------------------------------------------
		INSERT INTO [#ResultDetails]
		SELECT 	
			[enDebit],
			[enCredit],
			([enDebit] - [enCredit]) ,
			[dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], [acCurrencyPtr], [endate])
				- [dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal], [acCurrencyPtr], [endate]),
			[acGUID],    
			[acName],
			[acCode],
			[acLatinName],    
			[acSecurity], 
			[acCurrencyPtr],
			[dbo].[fnGetCurVal]([acCurrencyPtr], @EndDate),
			[vwCeEn].[ceNumber],
			[vwCeEn].[ceDate],
			[vwCeEn].[ceGuid],
			''
		FROM
			[vwCeEn] INNER JOIN [vwac] On [enAccount] = [acGuid]
			INNER JOIN [fnGetAccountsList](@AccGuid, 0) [f] on [enAccount] = [f].[guid]
			INNER JOIN [#CostTbl] [co] ON [co].[Cost] = [enCostPoint]
		WHERE 
			[enDate] BETWEEN @StartDate AND @EndDate 
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND [ceIsPosted] = 1)       
				OR (@PostedType = 0 AND [ceIsPosted] = 0) ) 
			AND [acCurrencyPtr] <>  @FirstCurr
			AND [vwCeEn].[ceBranch] = @BranchGUID
		-------------------------------------------------------------------------------------------------
	END
	EXEC [prcCheckSecurity] @UserGUID 
	
	-------- Main Result -------------------------------------------------
		SELECT
			[EnDebit],
			[EnCredit],
			[Balance],
			[CurBalance],
			[AccGUID],
			[AccCode],
			[AccName],
			[AccLatinName],
			([AccCode] + '-' + [AccName]) AS AccNameCode,
			( [AccCode] + '-' + [AccLatinName]) AS AccLatinNameCode,
			[AccSecurity],
			[MhCurGUID],
			[MhCurVal],
			[EntryNumber],
			[EntryDate],
			[EntryGUID],
			[IsDetail],
			m.Code AS MyCode
		FROM
			[#Result] r
			INNER JOIN my000 m ON m.[GUID] = r.MhCurGUID
		ORDER BY
			[accCode],
			[AccGUID],
			[IsDetail]
	---------------------------------------------------------------------------
	---------- Details result -------------------------------------------------
		SELECT
			[DetailsEnDebit],
			[DetailsEnCredit],
			[DetailsBalance],
			[DetailsCurBalance],
			[DetailsAccGUID],
			[DetailsAccCode],
			[DetailsAccName],
			[DetailsAccLatinName],
			[DetailsAccSecurity],
			[DetailsMhCurGUID],
			[DetailsMhCurVal],
			[DetailsEntryNumber],
			[DetailsEntryDate],
			[DetailsEntryGUID],
			m.Code AS DetailsMyCode
		FROM
			[#ResultDetails] r
			INNER JOIN my000 m ON m.[GUID] = r.DetailsMhCurGUID
		ORDER BY
			[DetailsaccCode],
			[DetailsAccGUID],
			[DetailsEntryDate],
			[DetailsEntryNumber],
			[DetailsBalance],
			[DetailsEnDebit],
			[DetailsEnCredit]
	---------------------------------------------------------------------------
	SELECT * FROM [#SecViol] 
/* 
prcConnections_Add2 'ãÏíÑ' 
exec repCurRatio '1/1/2002','4/5/2004',--	@EndDate DATETIME,		-- ????? ?????? ??????    
'A2DE26B6-E048-4AA9-980F-C106E6BF96D6',--	@AccGUID INT,			-- ?????? ?????? ????? ?????? ????? ????? ??    
'80CA8DC5-8486-4D90-BDE9-0C0C0686EA71',
1,1--	@CurGUID INT,			-- ?????? ??????? ?? ???????    
*/ 
################################################################################
#END

