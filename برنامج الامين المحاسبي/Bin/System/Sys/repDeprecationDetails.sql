###################################################
CREATE PROC repDeprecationDetails
		@Guid UNIQUEIDENTIFIER   
AS   
	SELECT    
		dd.GUID AS AssDepDetailGUID,   
		dd.ParentGUID AS AssDepGUID,   
		dd.ADGUID AS AssDetailGUID,   
		dd.[Percent] AS AssPercent,   
		AD.InVal AS AssInVal,   
		AD.ScrapValue AS AssScrapValue,  
		dd.Value AS AssDepVal,   
		dd.AddedVal AS AssAddedVal,   
		dd.DeductVal AS AssDeductVal,   
		dd.TotalDep AS AssTotalDep,   
		dd.PrevDep AS AssPrevDep,   
		dd.CurrAssVal AS AssCurrAssVal,   
		dd.ReCalcVal AS AssReCalcVal,   
		dd.FromDate AS AssFromDate,   
		dd.ToDate AS AssToDate,   
		dd.CostGUID AS AssCostGUID,  
		dd.StoreGuid,
		st.stName StoreName,
		dd.Notes AS AssNotes,  
		dd.CurrencyGUID AS AssCurrencyGUID,  
		dd.CurrencyVal  AS AssCurrencyVal, 
		co.coCode + '-'+ CASE  [dbo].fnConnections_GetLanguage() WHEN  1  THEN CASE coLatinName  WHEN  '' THEN coName END ELSE coName END AS coCodeName, 
		ad.Sn + '-'+ CASE  [dbo].fnConnections_GetLanguage() WHEN  1  THEN CASE mtLatinName  WHEN  '' THEN mtName END ELSE mtName END AS adCodeName, 
		case dd.CurrencyGUID when 0x0 then '' else my.myCode end	AS Currency, 
		CASE dp.CalcMethod WHEN 0 THEN DATEDIFF(DAY , dd.FromDate, dd.ToDate) ELSE DATEDIFF(MONTH , (CASE WHEN DATEPART( DAY , dd.FromDate) = 1 THEN dd.FromDate -1 ELSE dd.FromDate END) , (CASE WHEN DATEPART( DAY , dd.ToDate) = 1 THEN dd.ToDate -1 ELSE dd.ToDate END)) END AS DayCnt 
		  
	FROM    
		Dd000 AS dd INNER JOIN AD000 AS AD   ON dd.ADGUID = AD.GUID    
					LEFT  JOIN vwST AS  st   ON st.stGUID = DD.StoreGUID    
					INNER JOIN vwAs AS Ass ON ad.ParentGUID = ass.asGUID 
					INNER JOIN vwmt AS mt ON ass.asParentGUID = mt.mtGUID 
					LEFT JOIN vwco AS co ON co.coGUID = dd.CostGUID 
					INNER JOIN vwMy AS my ON my.myGUID = dd.CurrencyGUID 
					INNER JOIN dp000 AS dp ON dp.GUID = dd.ParentGUID 
	WHERE    
		dd.ParentGUID = @Guid   
	ORDER BY  
		dd.Number  
-- select * from vwst
#####################################################
CREATE FUNCTION fnAssetsHaveDepLater(@DepGuid UNIQUEIDENTIFIER)
RETURNS INT 
BEGIN
	DECLARE @ddToDate DATETIME, @ParentGUID  UNIQUEIDENTIFIER, @ddAdGuid  UNIQUEIDENTIFIER
	DECLARE ddCursor Cursor FOR     
            SELECT ADGUID, ParentGUID, ToDate FROM dd000 WHERE ParentGUID = @DepGuid
	OPEN ddCursor    
	FETCH NEXT FROM ddCursor    
	INTO     
		@ddAdGuid,@ParentGUID, @ddToDate
    
		WHILE @@FETCH_STATUS = 0    
		BEGIN    
			IF EXISTS(SELECT * FROM dd000 
					WHERE 
					ADGUID = @ddAdGuid 
					AND ParentGUID <> @DepGuid
					AND FromDate >= @ddToDate )
			RETURN 1;
		
		FETCH NEXT FROM ddCursor    
		INTO     
			@ddAdGuid,@ParentGUID, @ddToDate
		END    
	CLOSE ddCursor    
	DEALLOCATE ddCursor    
	RETURN 0;
END
#####################################################
#END
