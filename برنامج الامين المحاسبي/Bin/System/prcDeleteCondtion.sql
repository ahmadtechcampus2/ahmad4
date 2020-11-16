###############################################################################
CREATE PROCEDURE prcDeleteCondtion
	@ConditionGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	CREATE TABLE #SO(
		[GUID] UNIQUEIDENTIFIER,
		Code NVARCHAR(250),
		Name NVARCHAR(250),
		LatinName NVARCHAR(250))

	IF EXISTS(SELECT * FROM SOItems000 WHERE ItemType = 2 AND ItemGUID = @ConditionGUID)
	BEGIN
		INSERT INTO #SO
		SELECT
			so.[GUID],
			so.Code,
			so.Name,
			so.LatinName
		FROM
			SpecialOffers000 so
			INNER JOIN SOItems000 soi ON so.[GUID] = soi.SpecialOfferGUID
		WHERE
			soi.ItemType = 2 
			AND 
			soi.ItemGUID = @ConditionGUID
	END
	
	IF EXISTS(SELECT * FROM SOOfferedItems000 WHERE ItemType = 2 AND ItemGUID = @ConditionGUID)
	BEGIN
		INSERT INTO #SO
		SELECT
			so.[GUID],
			so.Code,
			so.Name,
			so.LatinName
		FROM
			SpecialOffers000 so
			INNER JOIN SOOfferedItems000 soi ON so.[GUID] = soi.SpecialOfferGUID
		WHERE
			soi.ItemType = 2 
			AND 
			soi.ItemGUID = @ConditionGUID
			AND
			NOT EXISTS(SELECT * FROM #SO WHERE [GUID] = so.[GUID])
	END

	IF EXISTS(SELECT * FROM SOConditionalDiscounts000 WHERE ItemType = 2 AND ItemGUID = @ConditionGUID)
	BEGIN
		INSERT INTO #SO
		SELECT
			so.[GUID],
			so.Code,
			so.Name,
			so.LatinName
		FROM
			SpecialOffers000 so
			INNER JOIN SOConditionalDiscounts000 soi ON so.[GUID] = soi.SpecialOfferGUID
		WHERE
			soi.ItemType = 2 
			AND 
			soi.ItemGUID = @ConditionGUID
			AND
			NOT EXISTS(SELECT * FROM #SO WHERE [GUID] = so.[GUID])
	END

	IF NOT EXISTS(SELECT * FROM #SO)
	BEGIN
		DELETE [dbo].[CondItems000] WHERE [ParentGUID] = @ConditionGUID
		DELETE [dbo].[Cond000] WHERE [GUID] = @ConditionGUID
	END
	ELSE
		SELECT * FROM #SO

################################################################################
#END