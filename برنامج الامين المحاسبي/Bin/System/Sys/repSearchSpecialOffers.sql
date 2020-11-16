#######################################################################################
CREATE PROCEDURE repSearchSpecialOffers
	@MaterialGUID UNIQUEIDENTIFIER,
	@AccountGUID UNIQUEIDENTIFIER,
	@CostGUID UNIQUEIDENTIFIER,
	@ActiveFlag INT,
	@UseFlag INT
AS 

	SET NOCOUNT ON 
	
	CREATE TABLE [#Result](
		[SpecialOfferGuid] UNIQUEIDENTIFIER,
		IsUsed BIT)
	
	INSERT INTO #Result
	SELECT
		[GUID],
		vwSo.IsUsed
	FROM
		SpecialOffers000 so
		INNER JOIN vwSO_Items vwSo ON so.GUID = vwSo.soGUID
	WHERE
		(@AccountGUID = 0x0 OR EXISTS(SELECT * FROM [dbo].[fnGetAccountsList](@AccountGUID, DEFAULT) WHERE [Guid] = so.AccountGUID))
		AND
		(@CostGUID = 0x0 OR EXISTS(SELECT * FROM [dbo].[fnGetCostsList](@CostGUID) WHERE [Guid] = so.CostGUID))
		AND
		(
			(@ActiveFlag = 3)
			OR 
			((@ActiveFlag = 1) AND ((GetDate() BETWEEN [StartDate] AND [EndDate]) AND ([IsActive] = 1)))
			OR 
			((@ActiveFlag = 2) AND ((GetDate() NOT BETWEEN [StartDate] AND [EndDate]) OR ([IsActive] = 0)))
		)
		AND
		(
			(@UseFlag = 3)
			OR
			(@UseFlag = 1 AND vwSo.IsUsed = 1)
			OR
			(@UseFlag = 2 AND vwSo.IsUsed = 0)
		)
		AND
		(@MaterialGUID = 0x0 OR EXISTS(SELECT * FROM SoItems000 WHERE SpecialOfferGuid = so.GUID AND ItemType = 0 AND ItemGUID = @MaterialGUID))
		AND
		[Type] IN(0, 1)
		
	SELECT
		so.GUID SOGUID,
		so.Code SOCode,
		so.Name SOName,
		so.Type SOType,
		r.IsUsed SOIsUsed,
		(CASE so.IsActive
			WHEN 1 THEN (CASE WHEN GetDate() BETWEEN so.[StartDate] AND so.[EndDate] THEN 1 ELSE 0 END) 
			ELSE 0
		END) SOIsActive,
		soi.ItemType,
		soi.ItemGUID,
		CASE soi.ItemType
			WHEN 0 THEN (SELECT Code FROM mt000 WHERE Guid = soi.ItemGuid)
			WHEN 1 THEN (SELECT Code FROM gr000 WHERE Guid = soi.ItemGuid)
		END ItemCode,
		CASE dbo.fnConnections_GetLanguage()
			WHEN 0 THEN
				CASE soi.ItemType
					WHEN 0 THEN (SELECT name FROM mt000 WHERE Guid = soi.ItemGuid)
					WHEN 1 THEN (SELECT name FROM gr000 WHERE Guid = soi.ItemGuid)
					WHEN 2 THEN (SELECT cndName FROM vwConditions WHERE cndGuid = soi.ItemGuid)
				END
			WHEN 1 THEN
				CASE soi.ItemType
					WHEN 0 THEN (SELECT LatinName FROM mt000 WHERE Guid = soi.ItemGuid)
					WHEN 1 THEN (SELECT LatinName FROM gr000 WHERE Guid = soi.ItemGuid)
				END
		END ItemName,
		ISNULL([co].[coGuid], 0x0) AS [coGuid],
		ISNULL([co].[coCode], '')AS [coCode],
		ISNULL((CASE dbo.fnConnections_GetLanguage() 
			WHEN 0 THEN  + [co].[coName] 
			ELSE 
				(CASE [co].[coLatinName] 
					WHEN '' THEN [co].[coName]
					ELSE [co].[coLatinName]
				END)
		END), '') AS [coName],
		ISNULL([ac].[acGuid], 0x0) AS [acGuid],
		ISNULL([ac].[acCode], '') AS [acCode],
		ISNULL((CASE dbo.fnConnections_GetLanguage() 
			WHEN 0 THEN  + [ac].[acName] 
			ELSE 
				(CASE [ac].[acLatinName] 
					WHEN '' THEN [ac].[acName]
					ELSE [ac].[acLatinName]
				END)
		END), '') AS [acName]
	FROM
		SpecialOffers000 so
		INNER JOIN #Result r ON so.GUID = r.SpecialOfferGUID
		INNER JOIN SoItems000 soi ON soi.SpecialOfferGuid = so.GUID
		LEFT JOIN vwCo co ON so.CostGuid = co.coGuid
		LEFT JOIN vwAC ac ON so.AccountGuid = ac.acGuid
#######################################################################################
#END

