###########################################################
###  Ê“Ì⁄ «·„’«—Ì›

CREATE PROCEDURE repManufCostAccCross
(
	@AccountGuid		UNIQUEIDENTIFIER   = 0x0 ,  
	@CostGuid			UNIQUEIDENTIFIER   = 0x0,
	@DistributionType   INT				   = 1, --  1-«·“„‰ «·„⁄Ì«—Ì , 2-«·“„‰ «·›⁄·Ì, 3-‰”»… À«» …, 4-Õ—ﬂ… Õ”«», 5-’—› «·„Ê«œ
	@SrcTypesguid		UNIQUEIDENTIFIER   = 0x0 ,
	@MatGuid			UNIQUEIDENTIFIER   = 0x0 , 
	@GrpGuid			UNIQUEIDENTIFIER   = 0x0 ,
	@MatCalcType		INT				   = 1   ,
	@RelatedAccGuid		UNIQUEIDENTIFIER   = 0x0 , 
	@FromDate			DATETIME		   = '1-1-1980'      , 
	@ToDate				DATETIME		   = '1-1-2070' 
) 
AS 	 
SET NOCOUNT ON  
	/*
		 ≈‰‘«¡ ÃœÊ· «·Õ”«»«  Ê Õ”«» —’Ìœ ﬂ· Õ”«»
		 -----------------------------------------------
	*/
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	CREATE TABLE #AccountsGuids ( Guid UNIQUEIDENTIFIER)
	IF(ISNULL(@AccountGuid ,0x0) <> 0x0)
		INSERT INTO #AccountsGuids SELECT Guid From dbo.fnGetAccountsList(@AccountGuid, 0)
	ELSE
		INSERT INTO #AccountsGuids SELECT ActualAccountGuid From MAN_ACTUALSTDACC000

	SELECT [ac].[Guid], [ac].[Name], ( SUM(en.[Debit])- SUM(en.[Credit]) ) Balance
	INTO #AccountsList
	From #AccountsGuids ag
	INNER JOIN ac000 ac ON [ac].[GUID] = [ag].[Guid]
	INNER JOIN en000 en ON  [en].[AccountGUID] = [ag].[Guid]
	WHERE en.[CostGUID] = 0x0 AND en.[Date] >= @FromDate AND en.[Date] <= @ToDate 
	GROUP BY [ac].[Guid], [ac].[Name]
	DROP TABLE #AccountsGuids
	
	/*
		 -----------------------------------------------
	*/
	
	/*
		 ≈‰‘«¡ ÃœÊ· „—«ﬂ“ «·ﬂ·›
		 -----------------------------------------------
	*/
		CREATE TABLE #CostGuids ( Guid UNIQUEIDENTIFIER )
		IF( ISNULL( @CostGuid, 0x0 ) = 0x0 )			
				INSERT INTO #CostGuids 
					SELECT DISTINCT(OutCostGuid) Guid FROM mn000
		ELSE
				INSERT INTO #CostGuids 
					SELECT fn.Guid from dbo.fnGetCostsList(@CostGuid) fn
					INNER JOIN Co000 co ON co.Guid = fn.Guid
					WHERE co.Guid Not In ( SELECT DISTINCT ParentGuid FROM co000 ) -- Â–« «·‘—ÿ ·Õ’— √Ê—«ﬁ «·‘Ã—… ›ﬁÿ √Ì „—«ﬂ“ «·ﬂ·› «· Ì ·Ì” ·Â« √»‰«¡
	
		SELECT co.Guid, CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE co.Name END AS Name , Cast( 0 AS FLOAT ) Percentage, Cast( 0 AS FLOAT ) Value
		INTO #CostList 
			FROM #CostGuids cg 
			INNER JOIN co000 co ON co.Guid = cg.Guid
		DROP TABLE #CostGuids
		
	/*
		 -----------------------------------------------
	*/ 
	DECLARE @Total FLOAT
	IF( @DistributionType = 1 OR @DistributionType = 2 ) -- Õ”» «·“„‰  select * from fm000
		BEGIN
			UPDATE #CostList SET Percentage = a.Total, Value = a.Total
				FROM #CostList cl
				INNER JOIN (
					SELECT mn.OutCostGuid Guid, CASE @DistributionType WHEN 1 THEN SUM( mn.Qty * fm.StandardTime) WHEN 2 THEN SUM(mn.ProductionTime) END Total
					FROM MN000 mn 
					INNER JOIN #CostList cl ON mn.OutCostGuid = cl.Guid
					INNER JOIN fm000 fm on fm.guid = mn.formguid
					WHERE mn.Type = 1 AND mn.Date >= @FromDate AND mn.Date <= @ToDate
					GROUP BY mn.OutCostGuid
				) a ON a.Guid = cl.Guid
		END
	ELSE IF ( @DistributionType = 3 )
		UPDATE #CostList SET Percentage = 1, Value = 1
	ELSE IF ( @DistributionType = 4 )
		UPDATE #CostList SET Percentage = a.Balance,  Value = a.Balance
				FROM #CostList cl
				INNER JOIN (
					SELECT en.CostGuid Guid,SUM(en.[Debit])- SUM(en.[Credit]) Balance 
					FROM en000 en
						INNER JOIN #CostList cl ON cl.Guid = en.CostGuid
						WHERE en.AccountGuid In ( SELECT Guid FROM  dbo.fnGetAccountsList(@RelatedAccGuid, 0))
							  AND en.Date BETWEEN @FromDate AND @ToDate
						GROUP BY en.CostGuid
					)a ON a.Guid = cl.Guid	
	ELSE IF ( @DistributionType = 5 )
		UPDATE #CostList SET Percentage = a.Total, Value = a.Total
					FROM #CostList cl
					INNER JOIN (
						SELECT 
							CASE ISNULL(bi.CostGuid,0x0) WHEN 0x0 THEN bu.CostGuid ELSE bi.CostGuid END Guid    , 
							SUM( CASE @MatCalcType WHEN 0 THEN bi.Qty WHEN 1 THEN ( bi.Price * bi.Qty ) END * CASE bt.BillType  
												WHEN 0 THEN  1 --„‘ —Ì«  
												WHEN 1 THEN -1 --„»Ì⁄«  
												WHEN 2 THEN -1 --„— Ã⁄ „‘ —Ì«  
												WHEN 3 THEN  1 --„— Ã⁄ „»Ì⁄«  
												WHEN 4 THEN  1 --≈œŒ«· 
												WHEN 5 THEN -1 --≈Œ—«Ã 
												ELSE 0 END
												) Total
						 FROM Bi000 bi
							INNER JOIN Bu000 bu ON bu.Guid = bi.ParentGuid
							INNER JOIN bt000 bt ON bt.Guid = bu.TypeGuid
							INNER JOIN mt000 mt ON mt.Guid = bi.MatGuid
							INNER JOIN RepSrcs RepSrc ON  RepSrc.idType     = bu.TypeGUID
							WHERE bu.Date >= @FromDate AND bu.Date <= @ToDate
								AND ( @MatGuid = 0x0 OR bi.MatGuid = @MatGuid ) 
								AND ( @GrpGuid = 0x0 OR mt.GroupGuid IN ( SELECT Guid from  dbo.fnGetGroupsList(@GrpGuid)))
								AND RepSrc.IdTbl = @SrcTypesguid
							GROUP BY CASE ISNULL(bi.CostGuid,0x0) WHEN 0x0 THEN bu.CostGuid ELSE bi.CostGuid END
						)a ON a.Guid = cl.Guid
						
	SELECT @Total = SUM(Percentage) FROM #CostList
			IF( @Total <> 0 )
				UPDATE #CostList SET Percentage = ( Percentage / @Total ) * 100		
	
	SELECT cl.Guid CostGuid, al.Guid AccountGuid, cl.Name CostName, al.Name AccountName ,cl.Percentage DistributionRate, al.Balance AccountBalance, cl.Value Value , ( cl.Percentage * al.Balance ) / 100 DistributedValue FROM #CostList cl
	CROSS JOIN #AccountsList al
###########################################################
#END
