#########################################################
CREATE  PROCEDURE repMatMoveByUnits
	@StartDate 			[DateTime] ,
	@EndDate 			[DateTime] ,
	@SrcTypesguid		[UNIQUEIDENTIFIER] ,
	@MatGUID 			[UNIQUEIDENTIFIER] , -- 0 All Mat or MatNumber
	@GroupGUID 			[UNIQUEIDENTIFIER] ,
	@StoreGUID 			[UNIQUEIDENTIFIER] , --0 all stores so don't check store or list of stores
	@CostGUID 			[UNIQUEIDENTIFIER] , -- 0 all costs so don't Check cost or list of costs
	@SortType 			[INT], -- 0 sort by Date , 1 Sort By Cust
	@InOutMode			[INT], -- 0 in+out+, 1 in+out-, 2 in-out+
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0X00 ,
	@VeiwCFlds 	VARCHAR (8000) = '' 	-- New Parameter to check veiwing of Custom Fields			
AS
	SET NOCOUNT ON
	-- Creating temporary tables
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl](	[MatGuid] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSecurity] [INTEGER])
	CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT])

	--Filling temporary tables
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID,-1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList2] @SrcTypesguid
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID

	-- don't change the place of prcCheckMatSec cause we delete no sec records from #MatTbl 
	-- Add count of no sec of mats to [#SecViol]
	-- or use
	-- Create Tmp Tbl Insert Into TmpTbl Select * From #MatTbl where @UserMatSec >= MtSecurity
	CREATE TABLE [#Result]
	(
		[biMatPtr]				[UNIQUEIDENTIFIER] ,
		[biUnity]				[FLOAT],
		[Security]				[INT],
		[UserSecurity] 			[INT],
		[UserReadPriceSecurity]	[INT],

		[QntInUnit1]			[FLOAT],
		[QntInUnit2]			[FLOAT],
		[QntInUnit3]			[FLOAT],

		[BonusQntInUnit1]		[FLOAT],
		[BonusQntInUnit2]		[FLOAT],
		[BonusQntInUnit3]		[FLOAT],
		[mtSecurity]			[INT],
		[mtUnit2FactFlag]		[INT],
		[mtUnit3FactFlag]		[INT]
	)

	CREATE TABLE [#ResultWithCalcSec]
	(
		[biMatPtr]			[UNIQUEIDENTIFIER] ,
		--biUnity			[FLOAT],

		[QntInUnit1]		[FLOAT],
		[QntInUnit2]		[FLOAT],
		[QntInUnit3]		[FLOAT],

		[BonusQntInUnit1]	[FLOAT],
		[BonusQntInUnit2]	[FLOAT],
		[BonusQntInUnit3]	[FLOAT]--,
	)
	
	INSERT INTO [#Result]
	SELECT
		[r].[biMatPtr],
		[r].[biUnity],
		[r].[buSecurity],
		CASE [r].[BuIsPosted] WHEN 1 THEN  [bt].[UserSecurity] ELSE [UnPostedSecurity] END,
		3 AS [UserReadPriceSecurity], -- we don't need price so dont hide prices casue it will not appear 

		SUM(CASE [biUnity]
				WHEN 1 THEN ([r].[biBillQty] + [r].[biBillBonusQnt]) * [dbo].[fnGetDirection](@InOutMode, [r].[BuDirection]) 
				ELSE 0 END)	AS [QntInUnit1],

		SUM(CASE
			WHEN ([mtUnit2FactFlag] = 1) OR ([biUnity] = 2)
				THEN ([r].[biQty2] + [r].[biBillBonusQnt]) * [dbo].[fnGetDirection](@InOutMode, [r].[BuDirection])
			ELSE 0 END) AS [QntInUnit2],

		SUM(CASE 
				WHEN ([mtUnit3FactFlag] = 1) OR ([biUnity] = 3)
				THEN ([r].[biQty3] + [r].[biBillBonusQnt]) * [dbo].[fnGetDirection](@InOutMode, [r].[BuDirection])
				ELSE 0 END)	AS [QntInUnit3],


		0 AS [BonusQntInUnit1],
		0 AS [BonusQntInUnit2],
		0 AS [BonusQntInUnit3],
		
		[r].[mtSecurity],
		[mt].[mtUnit2FactFlag],
		[mt].[mtUnit3FactFlag]

	FROM
		[vwExtended_bi] AS [r]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN [vwmt] AS [mt] on [r].[BiMatPtr] = [mt].[mtGUID]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
	WHERE
		[budate] BETWEEN @StartDate AND @EndDate
		--AND( (@IsAllMats = 1) OR (BiMatPtr IN( SELECT MatPtr FROM #MatTbl)))
		AND( (@StoreGUID = 0x0) 				OR ([BiStorePtr] IN( SELECT [StoreGUID] FROM [#StoreTbl])))
		AND( (@CostGUID = 0x0) 					OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))
	GROUP BY
		[r].[biMatPtr],
		[r].[biUnity],
		[r].[buSecurity],
		[bt].[UserSecurity],
		[r].[mtSecurity],
		[mt].[mtUnit2FactFlag],
		[mt].[mtUnit3FactFlag],
		[bt].[UnPostedSecurity],
		[r].[BuIsPosted]

	INSERT INTO [#ResultWithCalcSec]
	SELECT
		[r].[biMatPtr],
		--[r].[biUnity,
		SUM( CASE WHEN [biUnity] = 1 THEN [QntInUnit1] ELSE 0 END ) AS [QntInUnit1],
		SUM( CASE WHEN ([mtUnit2FactFlag] = 1) OR ([biUnity] = 2) THEN [QntInUnit2] ELSE 0 END ) AS [QntInUnit2],
		SUM( CASE WHEN ([mtUnit3FactFlag] = 1) OR ([biUnity] = 3) THEN [QntInUnit3] ELSE 0 END ) AS [QntInUnit3],

		SUM( CASE WHEN [biUnity] = 1 THEN [BonusQntInUnit1] ELSE 0 END ) AS [BonusQntInUnit1],
		SUM( CASE WHEN [biUnity] = 2 THEN [BonusQntInUnit2] ELSE 0 END ) AS [BonusQntInUnit2],
		SUM( CASE WHEN [biUnity] = 3 THEN [BonusQntInUnit3] ELSE 0 END ) AS [BonusQntInUnit3]
	FROM
		[#Result] AS [r]
	WHERE
		[r].[UserSecurity] >= [r].[Security]
		--AND	@UserMatSec >= mtSecurity
	GROUP BY
		[r].[biMatPtr]

	---check sec
	EXEC [prcCheckSecurity]

	--- Return first Result Set -- needed data
	DECLARE @Sql VARCHAR(8000)
	SET @Sql = ' DECLARE @SortType [INT] '
	SET @Sql = @Sql + ' SET @SortType = '+ CONVERT(VARCHAR(5),@SortType)+ ' '
	SET @Sql = @Sql + 
	' SELECT
		[r].[biMatPtr],
		--[r].[biUnity,
		[r].[QntInUnit1],
		[r].[QntInUnit2],
		[r].[QntInUnit3],
		[r].[BonusQntInUnit1],
		[r].[BonusQntInUnit2],
		[r].[BonusQntInUnit3],
		[mt].[mtName] AS [matName],
		--[mt].[mtCode],
		--[mt].[mtLatinName],
		--[mt].[mtBarCode],
		--[mt].[mtBarCode2],
		--[mt].[mtBarCode3],
		--[mt].[grCode],
		--[mt].[grName],
		--[mt].[mtSpec],
		--[mt].[mtOrigin],
		--[mt].[mtCompany],
		--[mt].[mtType],
		--[mt].[mtPos],
		--[mt].[mtDim],
		--[mt].[mtVat],
		--[mt].[mtColor],
		--[mt].[mtProvenance],
		--[mt].[mtQuality],
		--[mt].[mtModel],
		--Units Names
		[mtUnity] AS [matUnity],
		[mtUnit2] AS [matUnit2],
		[mtUnit3] AS [matUnit3]'
	-------------------------------------------------------------------------------------------------------
	-- Checked if there are Custom Fields to View  	
	-------------------------------------------------------------------------------------------------------
	IF @VeiwCFlds <> ''	 
		SET @Sql = @Sql + @VeiwCFlds 
	------------------------------------------------------------------------------------------------------ 
	SET @Sql = @Sql + 
	' FROM
		[#ResultWithCalcSec] AS [r] INNER JOIN [vwmtGr] AS [mt] ON [r].[BiMatPtr] = [mt].[mtGUID] '

	-------------------------------------------------------------------------------------------------------
	-- Custom Fields to View  	
	--------------------------------------------------------------------------------------------------------
	IF @VeiwCFlds <> ''
	BEGIN
		Declare @CF_Table VARCHAR(255) --Mapped Table for Custom Fields
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000')  -- Mapping Table	
		SET @Sql = @Sql + ' LEFT JOIN ' + @CF_Table + ' ON [mt].[mtGUID] = ' + @CF_Table + '.Orginal_Guid ' 	
	END
	-------------------------------------------------------------------------------------------------------  
	/*
	WHERE
		[r].[UserSecurity] >= [r].[Security
	*/
	SET @Sql = @Sql +
	 ' ORDER BY [mt].[mtCode]'
		--CASE 	WHEN @SortType = 1 then [mt].[mtCode]
		--		WHEN @SortType = 2 then [mt].[mtName]
		--		WHEN @SortType = 3 then [mt].[mtLatinName]
		--		WHEN @SortType = 4 then [mt].[mtBarCode]
		--		WHEN @SortType = 5 then [mt].[mtBarCode2]
		--		WHEN @SortType = 6 then [mt].[mtBarCode3]
		--		WHEN @SortType = 7 then [mt].[grCode]
		--		WHEN @SortType = 8 then [mt].[grName]

		--		WHEN @SortType = 9 then [mt].[mtSpec]
		--		WHEN @SortType = 10 then [mt].[mtOrigin]
		--		WHEN @SortType = 11 then [mt].[mtCompany]
		--		WHEN @SortType = 12 then [mt].[mtPos]
		--		WHEN @SortType = 13 then [mt].[mtDim]
		--		WHEN @SortType = 14 then [mt].[mtColor]
		--		WHEN @SortType = 15 then [mt].[mtProvenance]
		--		WHEN @SortType = 16 then [mt].[mtQuality]
		--		WHEN @SortType = 17 then [mt].[mtModel]
		--END '
		EXEC (@Sql)

	--- Return second Result Set -- count of records that will disapear
	SELECT *FROM [#SecViol]

	DROP TABLE [#Result]
	DROP TABLE [#SecViol]
/*
USE amndb090
prcConnections_add 1
select *from mc000 where type = 17
select bimatptr, biunity, biQty2, (select Unit2FactFlag from mt000 where number = biMatPtr) as Unit2FactFlag from vwextended_bi where bimatptr =13
EXEC repMatMoveByUnits
'1/1/1999',		--@StartDate 			[DateTime] ,
'1/1/2004',		--@EndDate 			[DateTime] ,
0x0,			--@SrcTypes [VARCHAR] (2000), 
0x0,			--@MatPtr 			INT, -- 0 All Mat or MatNumber
0x0,			--@GroupPtr 			INT,
0x0,			--@StorePtr 			INT, --0 all stores so don't check store or list of stores
0x0,			--@CostPtr 			INT, -- 0 all costs so don't Check cost or list of costs
1,				--@SortType 			INT -- 0 sort by Date , 1 Sort By Cust
1 				--@InOutMode
*/
###########################################################
#END