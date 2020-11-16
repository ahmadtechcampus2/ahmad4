##############################################
CREATE PROCEDURE repMatSalesFact
	@GrGuid UNIQUEIDENTIFIER,
	@State INT = -1-- -1 Both 0 Active 1 Not Active
AS
	SET NOCOUNT ON
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])    
	CREATE TABLE #Result 
		(
			[mtGuid]			[UNIQUEIDENTIFIER],
			[MatSecurity] 		[INT],
			[SalesUnitFact1]	[FLOAT],
			[SalesUnitFact2]	[FLOAT],
			[State]				[INT]
		)
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] 0X00, @GrGuid ,-1
	EXEC [prcCheckSecurity]
	INSERT INTO [#Result] 
		SELECT [MatGUID],[mtSecurity],ISNULL([SalesFactor1],0),ISNULL([SalesFactor2],0), ISNULL([State],0)
			FROM [#MatTbl] AS [m] LEFT JOIN [DistMe000] AS [me] ON [me].[mtGuid] = [m].[MatGUID]
			WHERE (@State = -1) OR (ISNULL(State,0) =  @State)
	SELECT [r].[mtGuid],[Code] AS [mtCode],[Name] AS [mtName],CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END AS  [mtLatinName],[SalesUnitFact1],[SalesUnitFact2], [r].[State] 	
		FROM  [#Result] AS [r] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [r].[mtGuid]
		ORDER BY [Code]
/*
prcConnections_add2 '„œÌ—'
exec repMatSalesFact 0x0
*/
################################################################################
#END		