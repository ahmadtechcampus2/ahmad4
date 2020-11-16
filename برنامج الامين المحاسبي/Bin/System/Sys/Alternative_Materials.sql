#########################################################
CREATE VIEW vwAlternativeMats
AS
	SELECT * FROM AlternativeMats000
#########################################################
CREATE VIEW vwAlternativeMatsItems
AS
	SELECT 
		   altm.[Number],
		   altm.[AltMatsGuid],
		   altm.[MatGUID],
		   altm.[Qty],
		   altm.[Unity],
		   altm.[Price],
		   mt.Name,
		   mt.LatinName,
		   mt.Code,
		   mt.isIntegerQuantity,
		   CASE altm.Unity WHEN 1 THEN mt.Unity
						   WHEN 2 THEN mt.Unit2
						   ELSE mt.Unit3 END UnitName
	FROM AlternativeMatsItems000 altm INNER JOIN mt000 mt ON Altm.MatGUID = mt.GUID
#########################################################
CREATE function fnGetAltMats(@MatGuid UNIQUEIDENTIFIER)
	RETURNS TABLE
AS

RETURN 
	SELECT  mt.Code,
			mt.Name,
		    altmt.Qty,
			CASE altmt.Unity WHEN 1 THEN mt.Unity
							 WHEN 2 THEN mt.Unit2
							 ELSE mt.Unit3 END UnitName,
		   altmt.Price,
		   altmt.Price * altmt.Qty TotalPrice,
		   altmt.MatGuid GUID
	FROM AlternativeMatsItems000 altmt
	INNER JOIN mt000 mt on altmt.MatGuid = mt.Guid
	WHERE AltMatsGuid = ( 
							SELECT AltMatsGuid 
							FROM AlternativeMatsItems000 
							WHERE MatGuid = @MatGuid
						)
	 AND MatGuid <> @MatGuid
#########################################################
CREATE FUNCTION fnGetAltMatInfo
(
	@OriginalMatGuid		UNIQUEIDENTIFIER,
	@OriginalMatInFormQty	FLOAT,
	@OriginalMatInFormUnity INT,
	@AltMatGuid				UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN 
	SELECT
		mt.Guid AS AltMatGuid,
		altmt.Price AS AltMatPrice,
		altmt.Unity AS AltMatUnity,
		CASE altmt.Unity
			WHEN 1 THEN altmt.Qty
			WHEN 2 THEN altmt.Qty * (CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END)
			ELSE altmt.Qty * (CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END)			
		END AS AltMatQty,
		CASE altmt.Unity
			WHEN 1 THEN 1
			WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END
			ELSE CASE Unit3Fact	WHEN 0 THEN 1 ELSE Unit3Fact END
		END AS AltMatFact,
		(
			SELECT 
				CASE altmt2.Unity
					WHEN 1 THEN altmt2.Qty
					WHEN 2 THEN altmt2.Qty * (CASE mt2.Unit2Fact WHEN 0 THEN 1 ELSE mt2.Unit2Fact END)
					ELSE altmt2.Qty * (CASE mt2.Unit3Fact WHEN 0 THEN 1 ELSE mt2.Unit3Fact END)
				END 
			FROM
				AlternativeMatsItems000 AS altmt2
				INNER JOIN mt000 AS mt2 ON altmt2.MatGuid = mt2.Guid
			WHERE MatGuid = @OriginalMatGuid
		) AS OriginalMatQty,
		(
			SELECT 
				CASE @OriginalMatInFormUnity
					WHEN 1 THEN @OriginalMatInFormQty
					WHEN 2 THEN @OriginalMatInFormQty * (CASE mt3.Unit2Fact WHEN 0 THEN 1 ELSE mt3.Unit2Fact END)
					WHEN 3 THEN @OriginalMatInFormQty * (CASE mt3.Unit3Fact WHEN 0 THEN 1 ELSE mt3.Unit3Fact END)
					ELSE
						CASE mt3.DefUnit
							WHEN 1 THEN @OriginalMatInFormQty
							WHEN 2 THEN @OriginalMatInFormQty * (CASE mt3.Unit2Fact WHEN 0 THEN 1 ELSE mt3.Unit2Fact END)
							ELSE @OriginalMatInFormQty * (CASE mt3.Unit3Fact WHEN 0 THEN 1 ELSE mt3.Unit3Fact END)
						END						
				END 
				FROM mt000 AS mt3
				WHERE GUID = @OriginalMatGuid
		) AS ASOriginalMatInFormQty
	FROM
		AlternativeMatsItems000 AS altmt
		INNER JOIN mt000 AS mt ON altmt.MatGuid = mt.Guid
	WHERE MatGuid = @AltMatGuid

#########################################################
CREATE FUNCTION fnGetStoreQty
(
	@MatGUID		UNIQUEIDENTIFIER = 0x0,
	@StoreGUID		UNIQUEIDENTIFIER = 0x0,
	@CostGUID		UNIQUEIDENTIFIER = 0x0,
	@DateFlag		BIT = 0,
	@FromDate		DATETIME = '1980-1-1',
	@ToDate			DATETIME = '2099-1-1'
)
RETURNS TABLE
AS
RETURN
	SELECT
	BI.MatGUID AS MatGUID,
	SUM
	(
		CASE BT.BILLTYPE 
			WHEN 0 THEN BI.QTY 
			WHEN 3 THEN BI.QTY 
			WHEN 4 THEN BI.QTY 
			WHEN 1 THEN -BI.QTY 
			WHEN 2 THEN -BI.QTY 
			WHEN 5 THEN -BI.QTY 
		END
	) AS QTY
	FROM
		BI000 AS BI
		INNER JOIN BU000 AS BU ON BU.GUID = BI.ParentGuid
		INNER JOIN BT000 AS BT ON BT.GUID = BU.TypeGUID			
	WHERE
		(BI.MatGUID = @MatGUID OR @MatGUID = 0x0)
		AND (Bu.Date >= @FromDate OR @DateFlag = 0)
		AND (BU.Date <= @ToDate OR @DateFlag = 0)
		AND BU.isposted = 1 -- ÍÕÑÇ ÇáÝæÇÊíÑ ÇáãÑÍáÉ
		AND (@StoreGUID = 0x0 OR BU.StoreGUID = @StoreGuid)		
		AND (@CostGUID = 0x0 OR (BU.CostGUID = @CostGUID AND BI.CostGUID = 0x0)OR (@CostGUID = BI.CostGUID AND BU.CostGUID <> @CostGUID))
	GROUP BY BI.MatGuid

#########################################################
CREATE PROCEDURE repAlternativeMaterials
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@Sort    int = 0
AS

SET NOCOUNT ON

DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
SELECT AltMatsGuid Guid
INTO  #AltMats
FROM  AlternativeMatsItems000 
WHERE (MatGuid = @MatGuid OR @MatGuid = 0x0)

SELECT  Alt.Number AltNumber,
		Alt.Name AltName,
		Alt.GUID AltGuid,
		mt.mtGuid MatFldGuid,
		mt.mtLatinName MatFldLatinName,
		mt.mtCode MatFldCode,
		CASE WHEN @lang > 0 THEN CASE WHEN mt.mtLatinName = '' THEN  mt.mtName ELSE mt.mtLatinName END ELSE mt.mtName END MatFldName,
		CASE Altmat.Unity WHEN 1 THEN mt.mtUnity
						  WHEN 2 THEN mt.mtUnit2
					      ELSE mt.mtUnit3 END AltUnitName,
	    Altmat.Qty AltQty,
	    Altmat.Price AltPrice,
	    mt.mtLastPrice AltLastPrice,
	    Altmat.Qty * mt.mtLastPrice AltMatValue,
	    mt.mtQty AvailableQty,
		mt.mtBarCode MatFldBarcode,
		CASE Altmat.Unity WHEN 1 THEN 1
						  WHEN 2 THEN mt.mtUnit2Fact
					      ELSE mt.mtUnit3Fact END mtUnitFact,
		mt.mtType MatFldType,
	    mt.mtSpec MatFldSpec,
	    mt.mtDim MatFldDim,
	    mt.mtOrigin MatFldOrigin,
	    mt.mtPos MatFldPos,
	    mt.mtCompany MatFldCompany,
		gr.Name MatFldGroup,
		gr.Code MatFldGroupCode,
	    mt.mtColor MatFldColor,
	    mt.mtProvenance MatFldProvenance,
	    mt.mtQuality MatFldQuality,
	    mt.mtModel  MatFldModel
INTO #Result
FROM AlternativeMatsItems000 Altmat
	 INNER JOIN vwMt mt ON Altmat.MatGuid = mt.mtGuid
	 INNER JOIN AlternativeMats000 Alt ON Alt.Guid = Altmat.AltMatsGuid
	 INNER JOIN gr000 gr ON gr.GUID = mt.mtGroup
WHERE Alt.Guid IN (SELECT Guid FROM #AltMats)
	
DECLARE @Str NVarchar(250)
SET @Str = 'SELECT * FROM #Result ORDER BY '
IF (@Sort = 0)
	SET @Str = @Str + 'AltNumber, AltMatValue'
ELSE
	SET @Str = @Str + 'AltNumber, AvailableQty Desc'

EXEC(@Str)

SELECT Alt.GUID,Alt.Number,Alt.Code,CASE WHEN @lang > 0 THEN CASE WHEN Alt.LatinName = '' THEN  Alt.Name ELSE Alt.LatinName END ELSE Alt.Name END AS Name ,ALt.LatinName,Alt.Notes
FROM  AlternativeMats000 Alt 
WHERE  Alt.Guid IN (SELECT Guid FROM #AltMats) 
ORDER BY Alt.Number
#########################################################	
CREATE PROCEDURE prcGetAltMats
	@rawMatGuid[UNIQUEIDENTIFIER], 
	@parentGuid[UNIQUEIDENTIFIER]
AS
	SELECT DISTINCT mi.* 
	FROM  AltMat000 AS altm INNER JOIN (SELECT * FROM mi000  WHERE TYPE = 2 AND parentGuid = @parentGuid ) mi
		ON mi.matGuid = altm.AltMatGuid AND altm.matGuid = @rawMatGuid
#########################################################	
CREATE PROCEDURE prcAltMatDelete 
	@rawMatGuid[UNIQUEIDENTIFIER], 
	@formGuid[UNIQUEIDENTIFIER]
AS 
	DELETE FROM mi000 WHERE parentGuid = @formGuid
	AND matGuid IN(	SELECT AltMatGuid 
					FROM AltMat000 
					WHERE MatGuid = @rawMatGuid	 AND FormGuid = @FormGuid
					)
	DELETE FROM AltMat000 WHERE MatGuid = @RawMatGuid AND FormGuid = @FormGuid	
#########################################################
#END