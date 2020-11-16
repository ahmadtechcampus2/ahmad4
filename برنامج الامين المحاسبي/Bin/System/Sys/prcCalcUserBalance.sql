#########################################################
CREATE PROCEDURE prcUserBalance
(
	@CurrencyGuid			UNIQUEIDENTIFIER,
	@Guid					UNIQUEIDENTIFIER,
	@StartDate				DATE,
	@EndDate				DATE,
	@isUserAccounts			BIT,
	@CenterGuid				UNIQUEIDENTIFIER ,
	@isAll					BIT 
) AS
	SET NOCOUNT ON

	IF @isUserAccounts=1 
	BEGIN
		SELECT 
			distinct
			m.Name,
			u.LoginName  AS DisplyName,
			SUM(bcd.Number * ccd.Value) AS EntryedStock,
			(SELECT bcds.Number FROM TrnUserBalanceByCatigoryDetails000 AS bcds WHERE bcds.ParentGuid = bcd.ParentGuid AND bcds.CurrGuid = bcd.CurrGuid AND bcds.DetailGuid = 0x) AS Balance,
			bc.Date,
			bc.UserGuid 
		FROM 
			TrnUserBalanceByCatigory000 AS bc
			INNER JOIN TrnUserBalanceByCatigoryDetails000 AS bcd ON bc.Guid = bcd.ParentGuid
			INNER JOIN TrnCurrencyCatigoriesDetails000 AS ccd ON bcd.DetailGuid = ccd.Guid
			INNER JOIN my000 AS m ON m.GUID = bcd.CurrGuid
			LEFT JOIN us000 AS u ON u.GUID = bc.UserGuid 
		WHERE 
			(bc.Date >= @StartDate AND bc.Date <= DATEADD(DAY,1, @EndDate))
			AND ( (bc.UserGuid = 0x0  AND @isAll=1 )  OR ((@Guid =0x  AND @isAll = 0) OR bc.UserGuid = @Guid ))	
			AND (@CurrencyGuid = 0x OR @CurrencyGuid = bcd.CurrGuid)
			AND ((((bc.UserGuid  IN (SELECT [tc].GUID FROM TrnCenter000 AS [tc]
				  		INNER JOIN[TrnBranch000] AS[tbr] ON[tc].[BranchGuid] = [tbr].[GUID] 
								INNER JOIN[vwBr] AS[br] ON[br].[brGUID] = [tbr].[AmnBranchGUID] ) AND @CenterGuid = 0x0)OR
				(bc.UserGuid = @CenterGuid AND @CenterGuid <> 0x0 )) AND @isAll=1 )
				OR ((bc.UserGuid IN (SELECT UserGuid FROM TrnUserConfig000 WHERE CenterGuid = @CenterGuid) AND @isAll=0 )
				OR ((@Guid =0x0 AND @CenterGuid = 0x AND
				bc.UserGuid IN(SELECT tc.UserGuid FROM  [TrnBranch000] AS [tbr] 
			INNER JOIN [vwBr] AS [br] ON [br].[brGUID] = [tbr].[AmnBranchGUID]
			INNER JOIN TrnCenter000 AS tr ON tbr.GUID = tr.BranchGuid
			INNER JOIN TrnUserConfig000 AS tc ON tc.CenterGuid = tr.GUID)
			OR bc.UserGuid IN
				(SELECT [tc].GUID FROM TrnCenter000 AS tc
				INNER JOIN TrnBranch000 AS tb ON tc.BranchGuid=tb.GUID
				INNER JOIN vwBr AS b ON b.brGUID = tb.AmnBranchGUID)
			) OR (@Guid =0x0 AND bc.UserGuid  =@CenterGuid))))
			AND bc.UserGuid <> 0x0
		GROUP BY 
			bcd.ParentGuid,
			bcd.CurrGuid, 
			m.Name, 
			u.LoginName, 
			bc.Date,
			bc.UserGuid
		ORDER BY 
			bc.Date DESC
	END
	ELSE
	BEGIN
		SELECT 
				m.Name,
				et.Name  AS DisplyName,
				SUM(bcd.Number * ccd.Value) AS EntryedStock,
				(SELECT bcds.Number FROM TrnUserBalanceByCatigoryDetails000 AS bcds WHERE bcds.ParentGuid = bcd.ParentGuid AND bcds.CurrGuid = bcd.CurrGuid AND bcds.DetailGuid = 0x) AS Balance,
				bc.Date,
				bc.UserGuid  
		FROM 
				TrnUserBalanceByCatigory000 AS bc
				INNER JOIN TrnUserBalanceByCatigoryDetails000 AS bcd ON bc.Guid = bcd.ParentGuid
				INNER JOIN TrnCurrencyCatigoriesDetails000 AS ccd ON bcd.DetailGuid = ccd.Guid
				INNER JOIN my000 AS m ON m.GUID = bcd.CurrGuid
				INNER JOIN TrnExchangeTypes000 AS et ON et.GUID = bc.ExchangeTypesGuid 
		WHERE 
				(bc.Date >= @StartDate AND bc.Date <= DATEADD(DAY,1, @EndDate))
				AND (@CurrencyGuid = 0x OR @CurrencyGuid = bcd.CurrGuid)
				AND ((bc.UserGuid IN (SELECT UserGuid FROM TrnUserConfig000 WHERE CenterGuid = @CenterGuid) OR @Guid = 0x) OR @CenterGuid = 0x )
				AND (bc.ExchangeTypesGuid = @Guid OR @Guid =0x  )
		GROUP BY 
			bcd.ParentGuid,
			bcd.CurrGuid, 
			m.Name, 
			et.Name , 
			bc.Date,
			bc.UserGuid
		ORDER BY 
			bc.Date DESC
	END
#########################################################
#END
