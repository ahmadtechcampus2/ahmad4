################################################################################
## ‰”»… «· Õ’Ì·
CREATE PROCEDURE repAccCollectRate 
	@StartDate			[DATETIME],  
	@EndDate			[DATETIME],  
	@AccPtr				[UNIQUEIDENTIFIER],  
	@CurGUID			[UNIQUEIDENTIFIER],  
	@CurVal				[INT],  
	@Src				[UNIQUEIDENTIFIER],  
	@CostGUID			[UNIQUEIDENTIFIER],  
	@BrevBal			[INT] = 0,  
	@ShowMainAcc		[INT] = 0,  
	@Level				[INT] = 0,  
	@ShowEmptyAcc		[INT] = 0,  
	@Str				[NVARCHAR](max) = '',  
	@ShwEmptyPeriod		[BIT] = 0,  
	@ShowLatPayDate		[BIT] = 0,  
	@ShowLatDebitDate	[BIT] = 0,  
	@ShowLatCreditDate	[BIT] = 0,  
	@CustOnly			[BIT] = 0,
	@CustGUID			[UNIQUEIDENTIFIER] = 0x0 
AS
	SET NOCOUNT ON  
	  
	DECLARE		-- Constant  
		@NoDate DATETIME,  
		@EntrySecurity INT  
		  
	SET @NoDate = '1/1/1980'  
	SET @EntrySecurity = 0  
		  
	DECLARE @Admin [INT],  
			@UserGUID [UNIQUEIDENTIFIER]  
	 
	--#Tables for resources check security. 
	DECLARE @Sec INT  
	SET @Sec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](),0X00)  
	 
	CREATE TABLE [#CostTbl]([CostGUID] [UNIQUEIDENTIFIER], [Security] SMALLINT)   
	CREATE TABLE [#BillTbl]([Type] [UNIQUEIDENTIFIER], [Security] SMALLINT, [ReadPriceSecurity] SMALLINT) 
	CREATE TABLE [#EntryTbl]([Type] [UNIQUEIDENTIFIER], [Security] SMALLINT)   
	CREATE TABLE [#ACCLV] ([GUID] [UNIQUEIDENTIFIER], [Level] INT , [ParentGUID] [UNIQUEIDENTIFIER], [Security] INT)   
	CREATE TABLE [#CustTbl]([CustGUID] [UNIQUEIDENTIFIER], [Security] SMALLINT) 

	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()        
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID  
	IF  ISNULL(@CostGUID,0X00) = 0X0 
		INSERT INTO [#CostTbl] VALUES(0X0, 0) 
	 
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @Src, @UserGUID       
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @Src, @UserGUID 
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @Src, @UserGUID    
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]   
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] @CustGUID, @AccPtr, 0x0

	IF @CustGUID = 0x0 AND @CustOnly = 0
		INSERT INTO [#CustTbl] VALUES(0x00, 0)

	IF [dbo].[fnObjectExists]('prcGetTransfersTypesList') <> 0	   
		INSERT INTO [#EntryTbl]	EXEC [prcGetTransfersTypesList] @Src   
	 
	DECLARE @SQL [NVARCHAR](max)   
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0   
	BEGIN		   
		SET @SQL = ' 
		INSERT INTO [#EntryTbl]   
		SELECT   
			[IdType],   
			[dbo].[fnGetUserSec](''' + CAST(@UserGUID AS NVARCHAR(36)) + ''', 0X2000F200, [IdType], 1, 1)   
		FROM 
			[dbo].[RepSrcs] AS [r]    
			INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid] 
		WHERE 
			[IdTbl] = ''' + CAST(@Src AS NVARCHAR(36)) + '''' 
		EXEC(@SQL) 
	END 
	
	IF [dbo].[fnObjectExists]('vwTrnExchangeTypes') <> 0 
	BEGIN		   
		SET @SQL = ' 
		INSERT INTO [#EntryTbl]   
		SELECT 
			[IdType],   
			[dbo].[fnGetUserSec](''' + CAST(@UserGUID AS NVARCHAR(36)) + ''', 0X2000F200, [IdType], 1, 1)   
		FROM   
			[dbo].[RepSrcs] AS [r]    
			INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid]   
		WHERE   
			[IdTbl] = ''' + CAST(@Src AS NVARCHAR(36)) + ''''   
		EXEC(@SQL)   
	END 				   
	--END OF #Tables for resources check security. 
	 
	--DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER])   
	DECLARE @MaxLevel [INT]  
	DECLARE @StDate [DATETIME],  
			@EnDate [DATETIME]	  
	--INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)    
	--IF ISNULL( @CostGUID, 0x0) = 0x0     
	--	INSERT INTO @Cost_Tbl VALUES(0x0)  
	 
	CREATE TABLE [#PeriodsResult] ([STARTDATE] [DATETIME],[ENDDATE] [DATETIME], [periodID] INT IDENTITY(1,1))  
	IF (@Str <> '')  
		INSERT INTO  [#PeriodsResult] SELECT * FROM fnGetStrToPeriod(@Str)  
	ELSE  
		INSERT INTO  [#PeriodsResult] VALUES ('1/1/1980','1/1/2150')   
	  
	  
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])    
	CREATE TABLE [#Result](      
		[AccPtr]		[UNIQUEIDENTIFIER],  
		[Debit]			[FLOAT],  
		[Credit]		[FLOAT],  
		[acSecurity]	[INT],  
		[ParentAcc]		[UNIQUEIDENTIFIER],  
		[Level]			[INT],  
		[StartDate]		[DATETIME],  
		[EndDate]		[DATETIME],  
		[LastPayDate]	[DATETIME],  
		[LastDebitDate] [DATETIME],  
		[LastCreditDate][DATETIME],
		[CustPtr]		[UNIQUEIDENTIFIER]
		--[ce_Security]	[INT] 
		--, 
		--[UserSecurity]	[INT], 
		--[ceTypeGuid] [UNIQUEIDENTIFIER] 
		)  
	--------------------------------------  
	CREATE TABLE [#T_Result](      
		[AccPtr] [UNIQUEIDENTIFIER],  
		[Bal] [FLOAT],
		[CustPtr] [UNIQUEIDENTIFIER])  
		  
	CREATE TABLE #ACC(  
		GUID [UNIQUEIDENTIFIER])  
		  
	INSERT INTO #ACC ([GUID])
	SELECT ACList.[GUID] FROM [dbo].[fnGetAccountsList]( @AccPtr, DEFAULT)  AS ACList
	INNER JOIN [ac000] ON [ac000].[GUID] = [ACList].[GUID] AND [ac000].[Type] = 1
	-------------------------------------  
	INSERT INTO [#Result]  
	SELECT  
		[e].[enAccount],  
		SUM([e].[FixedEnDebit]),  
		SUM([e].[FixedEnCredit]),   
		[e].[acSecurity],  
		0x0,  
		0,  
		[r].[StartDate],  
		[r].[EndDate],  
		MAX(CASE WHEN @ShowLatPayDate > 0 AND erParentType = 4 AND enCredit > 0 THEN enDate ELSE '1/1/1980' END),  
		MAX(CASE WHEN @ShowLatDebitDate > 0  AND enDebit > 0 THEN enDate ELSE '1/1/1980' END),  
		MAX(CASE WHEN @ShowLatCreditDate > 0  AND enCredit > 0 THEN enDate ELSE '1/1/1980' END),
		CASE WHEN [cu].[AccountGUID] = [e].[enAccount] THEN [cutbl].[CustGUID] ELSE 0x0 END 
	FROM  
		[dbo].[fnExtended_En_Fixed_Src](@Src, @CurGUID) AS [e]  
		INNER JOIN [#CostTbl] AS [Cost] ON [e].[enCostPoint] = [Cost].[CostGUID]  
		INNER JOIN #ACC AS [f] ON [e].[enAccount] = [f].[GUID]  
		INNER JOIN [#PeriodsResult] AS [r] ON [e].[enDate] BETWEEN [r].[StartDate] AND [r].[EndDate] 
		LEFT JOIN [#EntryTbl] AS [t]  ON [e].[ParentTypeGUID] = [t].[Type]
		LEFT JOIN [#CustTbl] AS [cutbl] ON [cutbl].[CustGUID] = [e].[enCustomerGUID]
		LEFT  JOIN [cu000] AS [cu] ON [cu].[GUID] = [cutbl].[CustGUID] AND [cu].[AccountGUID] = [e].[enAccount] 
	WHERE  
		[e].[enDate] BETWEEN @StartDate  AND @EndDate  
		AND [e].[acType] <> 2   
		AND [e].[acNSons] = 0  
		AND (([t].[Type] IS NOT NULL) OR [e].[erParentType] = 303)   
		AND [e].[ceSecurity] <= ISNULL([t].[Security],@Sec) 
		AND ((@CustOnly = 1 AND EXISTS(SELECT * FROM vwcu cu WHERE cu.cuAccount = [f].[GUID])) OR @CustOnly = 0)
	GROUP BY  
		[e].[enAccount],  
		[e].[acSecurity],  
		[r].[StartDate],  
		[r].[EndDate],
		CASE WHEN [cu].[AccountGUID] = [e].[enAccount] THEN [cutbl].[CustGUID] ELSE 0x0 END 

	IF (@ShowEmptyAcc = 1)  
	BEGIN  
		SELECT TOP 1 @StDate = [StartDate], @EnDate = [EndDate] FROM [#PeriodsResult]  
		INSERT INTO [#Result]   
		SELECT  
			[a].[acGUID],  
			0,  
			0,  
			[a].[acSecurity],  
			0x0,  
			0,  
			@StDate,  
			@EnDate,  
			@NoDate,  
			@NoDate,  
			@NoDate,
			[cu].[GUID]
		FROM  
			[vwAc] AS [a]  
			INNER JOIN #ACC [f] ON [a].[acGUID] = [f].[GUID]  
			LEFT JOIN (SELECT DISTINCT [AccPtr], [CustPtr] FROM [#Result])r ON  r.[AccPtr] = [acGUID]
			LEFT JOIN cu000 [cu] ON [cu].[AccountGUID] = [a].[acGUID]
			
		WHERE  
			r.[AccPtr] IS NULL  
			AND [acNSons] = 0  
			AND ((@CustOnly = 1 AND EXISTS(SELECT * FROM vwcu cu WHERE cu.cuAccount = [f].[GUID])) OR @CustOnly = 0)

	END
	IF @BrevBal = 1  
	BEGIN  
		INSERT INTO [#T_Result]  
		SELECT  
			[a].[acGUID] AS [AccPtr],  
			SUM( [e].[FixedEnDebit]) -SUM( [e].[FixedEnCredit]),
			[e].[enCustomerGUID]   
		FROM  
			[dbo].[fnExtended_En_Fixed_Src]( @Src, @CurGUID)AS [e]  
			INNER JOIN [#CostTbl] AS [Cost] ON [e].[enCostPoint] = [Cost].[CostGUID]  
			INNER JOIN [dbo].[fnGetAccountsList]( @AccPtr, DEFAULT) AS [f] ON [e].[enAccount] = [f].[GUID]  
			INNER JOIN [vwAc] AS [a] ON [e].[enAccount] = [a].[acGUID]  
			INNER JOIN [#EntryTbl] AS [t]  ON [e].[ParentTypeGUID] = [t].[Type] 
			INNER JOIN [#CustTbl] AS [cutbl] ON [cutbl].[CustGUID] = [e].[enCustomerGUID]
			LEFT  JOIN [cu000] AS [cu] ON [cu].[GUID] = [cutbl].[CustGUID] AND [cu].[AccountGUID] = [e].[enAccount] 
		WHERE  
			[e].[enDate] < @StartDate    
			AND [a].[acType] <> 2   
			AND [a].[acNSons] = 0  
		GROUP BY  
			[a].[acGUID],
			[e].[enCustomerGUID]  
	END  
	-----------------------------------------------------------------------------    
	EXEC [prcCheckSecurity]   @Check_AccBalanceSec = 1    
	-----------------------------------------------------------------------------    
	IF @ShowMainAcc = 1 OR @Level > 0  
	BEGIN  
		INSERT INTO   
			[#ACCLV] 
		SELECT   
			[f].[GUID],  
			[f].[Level],  
			[ParentGUID],  
			[Security]     
		FROM   
			[dbo].[fnGetAccountsList](@AccPtr,0) AS [f]   
			INNER JOIN [ac000] AS [ac] ON [f].[GUID] = [ac].[GUID]   
			  
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
		SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x0))  
		IF @Admin = 0  
		BEGIN  
			DECLARE @Updated [INT]  
			SET @Updated = 1  
			  
			UPDATE [#ACCLV]   
			SET [Security] = -1   
			WHERE [Security] > [dbo].[fnGetUserAccountSec_Browse](@UserGUID)  
			  
			WHILE @Updated > 0  
			BEGIN  
				UPDATE [ac]   
				SET   
					[ParentGUID] = [ac2].[ParentGUID],  
					[Level] = [ac2].[Level]   
				FROM   
					[#ACCLV] AS [ac]   
					INNER JOIN [#ACCLV] AS [ac2] ON [ac2].[GUID] = [ac].[ParentGUID]   
				WHERE  
					[ac2].[Security] = -1  
					  
				SET @Updated = @@ROWCOUNT  
			END  
			DELETE [#ACCLV] WHERE [Security] = -1  
			IF @@ROWCOUNT <> 0  
			BEGIN  
				IF EXISTS(SELECT * FROM [#SecViol] WHERE [Type] = 5)  
					INSERT INTO [#SecViol] VALUES(@Level,5)  
			END  
		END  
		UPDATE [res]   
		SET   
			[ParentAcc] = [l].[ParentGUID],  
			[Level] = [l].[Level]  
		FROM    
			#Result AS [res]   
			INNER JOIN [#ACCLV] AS [l] ON  [res].[AccPtr] = [l].[GUID]  
		CREATE INDEX SDDF ON [#ACCLV] ([GUID])  
		IF @ShowMainAcc = 1   
		BEGIN  
			SELECT @MaxLevel = MAX([Level]) FROM [#ACCLV]  
			WHILE @MaxLevel >= 0   
			BEGIN  
				INSERT INTO [#Result]  
					SELECT   
						[GUID],  
						SUM([Debit]),  
						SUM([Credit]),  
						[Security],  
						[ParentGUID],  
						@MaxLevel - 1,  
						[res].[StartDate],  
						[res].[EndDate],  
						MAX([LastPayDate]),  
						MAX([LastDebitDate]),  
						MAX([LastCreditDate]),
						0x0 
					FROM  
						[#Result] AS [res]   
						INNER JOIN [#ACCLV] AS [l] ON  [res].[ParentAcc] = [l].[GUID]  
					WHERE   
						[res].[Level] = @MaxLevel  
					GROUP BY  
						[GUID],  
						[Security],  
						[ParentGUID],  
						[res].[StartDate],  
						[res].[EndDate]  
						  
				IF @BrevBal = 1  
				BEGIN  
					INSERT INTO [#T_Result]  
					SELECT   
						[l].[GUID],  
						SUM([Bal]),
						0x0  
					FROM  
						[#T_Result] AS [t]  
						INNER JOIN (SELECT DISTINCT  
										[AccPtr],  
										[ParentAcc]  
									FROM   
										[#Result]   
									WHERE   
										[Level] = @MaxLevel  
									) AS [Res] ON [Res].[AccPtr] = [t].[AccPtr]  
						INNER JOIN [#ACCLV] AS [l] ON  [res].[ParentAcc] = [l].[GUID]  
					GROUP BY   
						[l].[GUID]  
				END		  
				SET @MaxLevel = @MaxLevel - 1  
			END  
		END  
	END	  

	IF (@Str <> '')  
	BEGIN  
		IF @ShwEmptyPeriod = 1  
		BEGIN
			INSERT INTO [#Result]
			SELECT
			(select top 1 [AccPtr] FROM [#Result]),
			0,
			0,
			(select top 1 [acSecurity] FROM [#Result]),
			(select top 1 [parentAcc] FROM [#Result]),
			0,
			[#PeriodsResult].[STARTDATE],
			[#PeriodsResult].[ENDDATE],
			@NoDate,  
			@NoDate,  
			@NoDate,
			0x0 
			FROM [#PeriodsResult]
			WHERE [#PeriodsResult].[STARTDATE] NOT IN (SELECT DISTINCT [StartDate] FROM [#Result])

		END
	END

	IF @BrevBal = 0  
		SELECT  
			[acc].[acGUID] AS [AccPtr],  
			[acc].[acName] AS [AccName],  
			[acc].[acLatinName] AS [AccLatinName],  
			[acc].[acCode] AS [AccCode],  
			[acc].[acNotes] AS [AccNotes],  
			ISNULL([Res].[Debit], 0) AS [SumDebit],  
			ISNULL([Res].[Credit], 0) AS [SumCredit],  
			ISNULL([cu].[GUID], 0x0) AS [CustomerGUID],
			[Res].[ParentAcc],  
			[acc].[acNSons],  
			[res].[StartDate],  
			[res].[EndDate],
			case @Str WHEN '' THEN 0 ELSE [#PeriodsResult].[periodID] END AS [periodID],
			[LastPayDate],   
			[LastDebitDate],  
			[LastCreditDate],
			(CASE WHEN [dbo].[fnConnections_getLanguage]() <> 0 AND [cu].[LatinName] <> '' THEN [cu].[LatinName] ELSE [cu].[CustomerName] END) AS CustomerName,
			CASE ISNULL([cu].[GUID], 0x0) WHEN 0x0 THEN [acc].[acGUID] ELSE [cu].[GUID] END AS [RecGUID]
		FROM  
			[#Result] AS [Res]   
			INNER JOIN [vwAc] AS [acc] ON [Res].[AccPtr] = [acc].[acGUID]  
			LEFT JOIN [cu000] AS [cu] ON [Res].[AccPtr] = [cu].[AccountGUID] AND [Res].[CustPtr] = [cu].[GUID]
			INNER JOIN [#PeriodsResult] ON [res].[StartDate] = [#PeriodsResult].[STARTDATE] and [res].[EndDate] = [#PeriodsResult].[ENDDATE]
		WHERE  
			[Level] < @Level   
			OR @Level = 0  
		ORDER BY  
			[acc].[acCode],  
			(CASE WHEN [dbo].[fnConnections_getLanguage]() <> 0 AND [cu].[LatinName] <> '' THEN [cu].[LatinName] ELSE [cu].[CustomerName] END),
			[res].[StartDate]
	ELSE  
		SELECT  
			[acc].[acGUID] AS [AccPtr],  
			[acc].[acName] AS [AccName],  
			[acc].[acLatinName] AS [AccLatinName],  
			[acc].[acCode] AS [AccCode],  
			[acc].[acNotes] AS [AccNotes],  
			ISNULL([Res].[Debit], 0) AS [SumDebit],  
			ISNULL([Res].[Credit], 0) AS [SumCredit],  
			ISNULL([t].[Bal], 0) AS [PrevBal],  
			ISNULL([cu].[GUID],0x0) AS [CustomerGUID],
			[Res].[ParentAcc],  
			[acc].[acNSons],  
			[res].[StartDate],  
			[res].[EndDate],
			case @Str WHEN '' THEN 0 ELSE [#PeriodsResult].[periodID] END AS [periodID],
			[LastPayDate],   
			[LastDebitDate],  
			[LastCreditDate],
			(CASE WHEN [dbo].[fnConnections_getLanguage]() <> 0 AND [cu].[LatinName] <> '' THEN [cu].[LatinName] ELSE [cu].[CustomerName] END) AS CustomerName,
			CASE ISNULL([cu].[GUID], 0x0) WHEN 0x0 THEN [acc].[acGUID] ELSE [cu].[GUID] END AS [RecGUID]
		FROM  
			[#Result] AS [Res]   
			INNER JOIN [vwAc] AS [acc] ON [Res].[AccPtr] = [acc].[acGUID]  
			LEFT JOIN [cu000] AS [cu] ON [Res].[AccPtr] = [cu].[AccountGUID] AND [Res].[CustPtr] = [cu].[GUID]
			LEFT JOIN [#T_Result] AS [t] ON [t].[AccPtr] = [acc].[acGUID] AND [t].[CustPtr] = [Res].[CustPtr] 
			INNER JOIN [#PeriodsResult] ON [res].[StartDate] = [#PeriodsResult].[STARTDATE] and [res].[EndDate] = [#PeriodsResult].[ENDDATE]
		WHERE   
			[Level] < @Level   
			OR @Level = 0  
		ORDER BY  
			[acc].[acCode],  
			(CASE WHEN [dbo].[fnConnections_getLanguage]() <> 0 AND [cu].[LatinName] <> '' THEN [cu].[LatinName] ELSE [cu].[CustomerName] END),
			[res].[StartDate]  


	--IF ((@ShowLatPayDate  > 0) OR (@ShowLatDebitDate > 0) OR (@ShowLatCreditDate > 0))  
	--	SELECT   
	--		[AccPtr],  
	--		MAX([LastPayDate]) [LastPayDate],   
	--		MAX([LastDebitDate]) [LastDebitDate],  
	--		MAX([LastCreditDate]) [LastCreditDate]   
	--	FROM    
	--		[#Result]   
	--	GROUP BY   
	--		[AccPtr]  

	--IF (@CustOnly > 0)  
	--	SELECT   
	--		cu.*   
	--	FROM   
	--		cu000 cu   
	--		INNER JOIN (SELECT DISTINCT   
	--						[AccPtr]   
	--					FROM #Result  
	--					) r ON r.[AccPtr] = cu.AccountGUID  
	SELECT * FROM [#SecViol]  
	 
/* 
	PRCCONNECTIONS_ADD2'Œ«·œ' 
	[repAccCollectRate] '1/1/2013 0:0:0.0', '5/20/2013 23:59:6.55', '00000000-0000-0000-0000-000000000000', 'ca6b758d-1d20-480e-bf4c-ab55bc2c3302', 1.000000, '5cc0a2d7-ae2f-42c6-b020-95e79bb6b24e', '00000000-0000-0000-0000-000000000000', 0, 0, 0, 0, '', 0, 0, 0, 0, 0
*/ 

################################################################################
#END

