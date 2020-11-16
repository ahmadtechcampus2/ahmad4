CREATE PROC prcDistGetAllDistsForCust 
	@AccGuid 	[UNIQUEIDENTIFIER] = 0x00
AS
	SET NOCOUNT ON

	CREATE TABLE #Dists 	( [DistGuid] [UNIQUEIDENTIFIER], 	[DistCode] [NVARCHAR](255) COLLATE Arabic_CI_AI, [DistName] [NVARCHAR](255) COLLATE Arabic_CI_AI ) 
	CREATE TABLE #CustDists	( [CustGUID] [UNIQUEIDENTIFIER], 	[AccGUID] [UNIQUEIDENTIFIER], 			[AllDistNames] [NVARCHAR](4000) COLLATE Arabic_CI_AI ) 

	INSERT INTO #Dists ([DistGuid], [DistCode], [DistName]) SELECT [Guid], [Code], [Name] FROM Distributor000 
	CREATE INDEX Dist_GdInd  ON #Dists(DistGuid)
	
	INSERT INTO #CustDists ([CustGuid], [AccGuid], [AllDistNames]) 
	SELECT DISTINCT cu.cuGuid, ac.GUID, '' 
	FROM 	vwCu AS cu
		INNER JOIN fnGetAcDescList( @AccGuid ) AS ac ON cu.cuAccount = ac.Guid
 
	DECLARE
		@C		CURSOR, 
		@DistGUID	[UNIQUEIDENTIFIER],
		@DistName	[NVARCHAR](255) -- COLLATE Arabic_CI_AI 

	SET @C = CURSOR FAST_FORWARD FOR 
		SELECT DistGuid, DistName FROM #Dists 
	OPEN @C FETCH FROM @C INTO @DistGuid, @DistName
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		UPDATE Cd SET AllDistNames = CASE AllDistNames WHEN '' THEN @DistName ELSE AllDistNames + '-' + @DistName END
		FROM #CustDists AS Cd INNER JOIN DistDistributionLines000 AS Dl ON Cd.CustGuid = Dl.CustGuid
		WHERE Dl.DistGuid = @DistGuid	
		FETCH FROM @C INTO @DistGuid, @DistName
	END 
	CLOSE @C DEALLOCATE @C 

	SELECT * FROM #CustDists 


/*
Exec prcConnections_Add2 '„œÌ—'
Exec prcDistGetAllDistsForCust 0x00
*/

