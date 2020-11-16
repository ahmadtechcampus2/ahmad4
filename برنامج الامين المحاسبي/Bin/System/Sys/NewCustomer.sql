###########################################################################
## exec repNewCustomer '1/1/2002', '12/30/2002', '56ceeb43-19f9-45cf-a7a2-89f566f2a345', '00000000-0000-0000-0000-000000000000' 
CREATE PROCEDURE repNewCustomer 
	@StartDate [DATETIME], 
	@EndDate [DATETIME],   
	@Src [UNIQUEIDENTIFIER],
	@AccPtr	[UNIQUEIDENTIFIER],
	@CustCondGuid [UNIQUEIDENTIFIER] = 0X00,
	@CostGUID [UNIQUEIDENTIFIER] = 0X00,
	@DetailCosts [bit] = 0
AS   
	SET NOCOUNT ON
	-------------------------------------------- 
	CREATE TABLE [#SrcTbl]( [Type] [UNIQUEIDENTIFIER], [Sec] [INT])
	INSERT INTO [#SrcTbl] select * from [dbo].[fnGetSourcesType](@Src)
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER]) 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] @Src
	DELETE src FROM [#SrcTbl] src INNER JOIN [#BillsTypesTbl] A ON [TypeGuid] = [Type]
	
	--?????? 
	-------------------------------------------- 
	CREATE TABLE [#Cust] ([Number] [UNIQUEIDENTIFIER], [Sec] [INT]) 
	INSERT INTO [#Cust] EXEC [prcGetCustsList]  NULL, @AccPtr,@CustCondGuid 
	--------------------------------------------------------------
	SELECT C.*,a.aCcountGuid [cuAccount]
	INTO [#Cust2]
	FROM [#Cust] C INNER JOIN cu000 a ON a.Guid = c.[Number]

	--??????? ??????? ??? ????????   
	-------------------------------------------- 
	DECLARE @BiTbl TABLE ( [Number] [UNIQUEIDENTIFIER],CustGuid [UNIQUEIDENTIFIER],[CostPtr] [UNIQUEIDENTIFIER])   
	INSERT INTO @BiTbl  
	SELECT  
		[cuAccount], cu.Number AS CustGuid, CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [Bill].biCostPtr END 
	FROM 
		vwbubi AS [Bill] 
		INNER JOIN [#Cust2] AS [cu] ON [cu].[Number] = [Bill].[buCustPtr]
		INNER JOIN [#BillsTypesTbl] AS [src] ON  [Bill].[buType]  = [src].[TypeGuid]
	WHERE  
		[BuDate] < @StartDate  
		AND [buCustPtr] IS NOT NULL  
		AND [BuSecurity] <= [Src].[UserSecurity] 
		--AND ( src.Type >= 1  and  src.Type <= 2048 ) 
		AND ([Bill].biCostPtr = @CostGUID OR @CostGUID = 0X00)
	GROUP BY  
		[cuAccount], cu.Number,	CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [Bill].biCostPtr END  
	
	
	---------------------------------------------   
	--??????? ??????? ?? ???????   
	DECLARE @EnTbl TABLE ( [Number] [UNIQUEIDENTIFIER], CustGuid [UNIQUEIDENTIFIER],[CostPtr] [UNIQUEIDENTIFIER])   
	INSERT INTO @EnTbl 
		SELECT [AccNumber], [CustGuid], [CostPtr]  
		FROM (
			SELECT
				[cuAccount] AS [AccNumber],cu.Number AS CustGuid,CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [EN].enCostPoint END [CostPtr]  
			FROM 
				[vwCEen] AS [En]    
				INNER JOIN [#Cust2] AS [cu] ON [cu].Number  = [EN].enCustomerGUID 
				--INNER JOIN vwER AS er ON Er.erEntryGUID = En.ceGUID
				INNER JOIN [#SrcTbl] AS [src] ON ISNULL( [En].[ceTypeGUID], 0x0) = [src].[Type]
			WHERE   
				[En].[ceDate] < @StartDate 
				AND [En].[CeSecurity] <= [Src].[Sec] 
				AND ([EN].[enCostPoint] = @CostGUID OR @CostGUID = 0X00)
			GROUP BY  
				[cuAccount],cu.Number,CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [EN].enCostPoint END) AS [Tabl2] 
	
	--------------------------------------------   
	--??????? ??? ????????? ?? ????????   
	DECLARE @BiTblNew TABLE([Number] [UNIQUEIDENTIFIER], CustGuid [UNIQUEIDENTIFIER], [MoveDate] [DATETIME], [CostGuid] [UNIQUEIDENTIFIER])   
	INSERT INTO @BiTblNew  SELECT [AccNumber], CustGuid, [MoveDate], [CostPtr] FROM  
			(SELECT   
				[cuAccount] AS [AccNumber],   
				cu.Number AS CustGuid,
				MIN( [buDate]) AS [MoveDate],
				CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [Bill].biCostPtr END AS  [CostPtr] 
			FROM   
				[vwbubi] AS [Bill]  
				INNER JOIN [#Cust2] AS [cu] On [cu].[Number] = [Bill].[buCustPtr]
				INNER JOIN [#BillsTypesTbl] AS [src] ON [Bill].[buType] = [Src].[TypeGuid]
			WHERE   
				[buCustPtr] IS NOT NULL  
				AND [buDate] BETWEEN @StartDate AND @EndDate 
				AND [Bill].[BuSecurity] <= [Src].[UserSecurity] 
				AND ([Bill].biCostPtr = @CostGUID OR @CostGUID = 0X00)
			GROUP BY 
				[cuAccount],cu.Number,
				CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [Bill].biCostPtr END ) AS [Tbl1]  
		
	-------------------------------------------- 
	-- ??????? ??? ????????? ?? ???????   
	DECLARE @EnTblNew TABLE ( [Number] [UNIQUEIDENTIFIER], CustGuid [UNIQUEIDENTIFIER], [MoveDate] [DATETIME], [CostGuid] [UNIQUEIDENTIFIER])   
	INSERT INTO @EnTblNew  SELECT [AccNumber],CustGuid, [MoveDate], [CostPtr] FROM  
		       ( SELECT   
				[cuAccount] AS [AccNumber],  
				cu.Number AS CustGuid, 
				MIN( [En].[ceDate]) AS [MoveDate],
				CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [EN].enCostPoint END AS CostPtr
			FROM   
				VWCEEN AS [En]  
				INNER JOIN [#Cust2] AS [cu] On [cu].Number = [en].enCustomerGUID --[cu].[cuAccount]  =  [EN].[enAccount]
				--INNER JOIN vwER AS er ON Er.erEntryGUID = En.ceGUID
				INNER JOIN [#SrcTbl] AS [src] ON ISNULL( [En].[ceTypeGUID], 0x0) = [src].[Type]
			WHERE   
				[En].[ceDate] BETWEEN @StartDate AND @EndDate 
				AND [En].[CeSecurity] <= [Src].[Sec] 
				AND ([EN].[enCostPoint] = @CostGUID OR @CostGUID = 0X00)
			GROUP BY   
				[cuAccount],cu.Number,
				CASE @DetailCosts WHEN 0 THEN 0X00 ELSE [en].enCostPoint END) AS [Tbl2]  
	
	---------------------------------------------   
	--????? ??????? ??????? ??????? ?? ???????? ???????? ?? ??????? ???? ???? ??? ?????????   
	CREATE TABLE #NewCustVar ( 
		[AccNumber] [UNIQUEIDENTIFIER], 
		[CustGuid] [UNIQUEIDENTIFIER], 
		[CostGuid] [UNIQUEIDENTIFIER],
		[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[LName] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Code] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[MoveDate] [DATETIME])   

	INSERT INTO #NewCustVar 
	SELECT 
		[NewCustTbl].[AccNumber],
		[NewCustTbl].[CustGuid],
		[NewCustTbl].[CostGuid],
		[NewCustTbl].[Name], 
		[NewCustTbl].[LName], 
		[NewCustTbl].[Code], 
		[NewCustTbl].[MoveDate] 
	FROM   
		(SELECT   
			[NewCust].[AccNumber] AS [AccNumber],
			[NewCust].[CostGuid],
			[NewCust].CustGuid,
			[ACC].[acName] AS [Name],
			[ACC].[acLatinName] AS [LName],
			[ACC].[acCode] AS [Code],
			MIN([NewCust].[MoveDate]) AS [MoveDate]
		FROM (
			SELECT [NewCustTemp].[AccNumber] AS [AccNumber], CustGuid, [NewCustTemp].[MoveDate] AS [MoveDate], [CostGuid] 
			FROM (   
					(SELECT [Number] AS [AccNumber],  CustGuid, [MoveDate], [CostGuid] FROM @EnTblNew)   
					UNION ALL
					(SELECT [Number] AS [AccNumber], CustGuid, [MoveDate], [CostGuid] FROM @BiTblNew)   
				) AS [NewCustTemp]   
			) AS [NewCust]   
		LEFT JOIN (
			SELECT [NewCustTemp2].[AccNumber] AS [AccNumber], CustGuid, [NewCustTemp2].[MoveDate] AS [MoveDate], [CostPtr] 
			FROM   
				(   
					(SELECT [Number] AS [AccNumber],0x AS CustGuid, '1/1/1980' AS [MoveDate], [CostPtr] FROM @EnTbl)   
					UNION ALL
					(SELECT [Number] AS [AccNumber], 0x AS CustGuid, '1/1/1980' AS [MoveDate], [CostPtr] FROM @BiTbl)   
				)As [NewCustTemp2]   
			) AS [OldCust] ON CAST([OldCust].[AccNumber] AS NVARCHAR(36)) + CAST([OldCust].CustGuid AS NVARCHAR(36))+ CAST([OldCust].[CostPtr] AS NVARCHAR(36)) = CAST([NewCust].[AccNumber] AS NVARCHAR(36))  + CAST([NewCust].CostGuid AS NVARCHAR(36)) + CAST([NewCust].[CostGuid] AS NVARCHAR(36))
		INNER JOIN [vwAc] AS [ACC] ON [NewCust].[AccNumber] = [ACC].[acGUID]
	WHERE   
		[OldCust].[AccNumber] IS NULL   
	GROUP BY   
		[NewCust].[AccNumber],
		[NewCust].CustGuid,
		[NewCust].[CostGuid],
		[acName],
		[acLatinName],   
		[acCode]   
	)AS [NewCustTbl]   

	IF @DetailCosts > 0
	BEGIN
		SELECT 
			[TblVar].*, [vwCu].*, [CO000].Code CostCode, [CO000].Name CostName 
		FROM 
			#NewCustVar AS [TblVar] 
			JOIN [vwCu] ON [TblVar].CustGuid = [vwCu].cuGUID
			LEFT JOIN [CO000] ON [TblVar].[CostGuid] = [CO000].[Guid]  
		ORDER BY 
			[TblVar].[CostGuid], TblVar.CODE 
	END
	ELSE
	BEGIN
		SELECT [TblVar].*, [cu].[cuGUID], [cu].[cuCustomerName], [cu].[cuLatinName] 
		FROM 
			#NewCustVar AS [TblVar]
			JOIN [vwCu] AS cu ON [TblVar].CustGuid = [cu].cuGUID
		ORDER BY TblVar.CODE
	END
/*
prcConnections_add2 'test'
 [repNewCustomer] '5/31/2007', '12/31/2008', '39815201-e006-469b-a5af-d3895c3144bd', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0
*/
################################################################################
#END
