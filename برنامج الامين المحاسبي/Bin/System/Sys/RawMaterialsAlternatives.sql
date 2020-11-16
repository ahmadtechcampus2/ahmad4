#########################################################
CREATE VIEW vwRawMaterialsGridItems
AS
	SELECT MatAlt.* ,
		   mt.Name,
		   mt.LatinName,
		   mt.Code,
		   mt.isIntegerQuantity,
		   CASE MatAlt.Unity WHEN 1 THEN mt.Unity
						   WHEN 2 THEN mt.Unit2
						   ELSE mt.Unit3 END UnitName
		   ,MatsCrd.Number AS CrdNumber
	FROM MaterialAlternatives000 MatAlt INNER JOIN mt000 mt ON MatAlt.MatAltGuid = mt.GUID
	INNER JOIN MaterialAlternativesCard000 AS MatsCrd ON MatAlt.ParentGUID=MatsCrd.GUID

#########################################################
CREATE VIEW MatItemsCard
AS
SELECT ALTERNATIVESCARD.*,ALTERNATIVESITEM.MatAltGuid,ALTERNATIVESITEM.Qty,ALTERNATIVESITEM.Unity,ALTERNATIVESITEM.Number AS MatItemNum ,ALTERNATIVESITEM.UnitName
FROM vwRawMaterialsGridItems AS ALTERNATIVESITEM
INNER JOIN MaterialAlternativesCard000 AS ALTERNATIVESCARD
ON ALTERNATIVESITEM.ParentGUID=ALTERNATIVESCARD.GUID
#########################################################
CREATE PROCEDURE GetAlternativesWithQTYUnit 
	@CardGuid UNIQUEIDENTIFIER,
	@MaterialGuid UNIQUEIDENTIFIER,
	@Materialunit INT,
	@MaterialQTY FLOAT
AS
	SET NOCOUNT ON
CREATE TABLE  #RESULT  
	(
		MATGUID UNIQUEIDENTIFIER,
		MATNAME NVARCHAR(250),
		MATLATINNAME NVARCHAR(250),
		MATUNIT INT,
		RATIO FLOAT,
		STANDARDQTY FLOAT,
		REMAINING FLOAT,
		MATUNITNAME NVARCHAR(100),
		BALANCE FLOAT,
		UNIT2FACT FLOAT,
		UNIT3FACT FLOAT,
		Number INT
	) 
	
DECLARE @UNITS TABLE 
(
UNIT INT ,
FACT FLOAT
)
INSERT INTO  @UNITS VALUES (1,1)
INSERT INTO  @UNITS VALUES (2 , (SELECT UNIT2FACT FROM mt000 WHERE GUID=@MaterialGuid))
INSERT INTO  @UNITS VALUES (3,(SELECT UNIT3FACT FROM mt000 WHERE GUID=@MaterialGuid))
-----------------------------------------------------------------------------
DECLARE @FromCardUnitToSelectedUnit FLOAt 
DECLARE @CARDUNIT INT 
DECLARE @SELECTEDMATERIALNAME NVARCHAR(100)=(SELECT Unity FROM MaterialAlternatives000 WHERE MatAltGuid=@MaterialGuid)
DECLARE @SelectedMaterialRatioInCard FLOAT = (SELECT Qty FROM MaterialAlternatives000 WHERE MatAltGuid=@MaterialGuid)
SELECT @CARDUNIT= (SELECT Unity FROM MaterialAlternatives000 WHERE ParentGUID=@CardGuid AND MatAltGuid=@MaterialGuid)
SELECT @FromCardUnitToSelectedUnit= (SELECT FACT FROM @UNITS WHERE UNIT=@Materialunit)/(SELECT FACT FROM @UNITS WHERE UNIT=@CARDUNIT)
---------------------------------------------------------------------------------
--FILL RESULT
	INSERT INTO #RESULT
		SELECT MatAltGuid,mt000.Name,mt000.LatinName,MatItemsCard.Unity,
		MatItemsCard.Qty ,--‰”»… «·„«œ… »«·‰”»… ··„Ê«œ «·«Œ—Ï œ«Œ· «·»ÿ«ﬁ…
		((MatItemsCard.Qty/@SelectedMaterialRatioInCard)*(@MaterialQTY*@FromCardUnitToSelectedUnit)),--«·ﬂ„Ì… «·„ÊÃÊœ… œ«Œ· »ÿ«ﬁ… «·‰„Ê–Ã * «·‰”»… »Ì‰ ﬂ„Ì… «·„«œ… »«·ÊÕœ… «·„ÊÃÊœ… ›Ï »ÿ«ﬁ… «·»œ«∆· Ê «·„œŒ·… ›Ï »ÿ«ﬁ… «·‰„Ê–Ã * «·‰”»… »Ì‰ »Ì‰ «·„«œ Ì‰ 
		((MatItemsCard.Qty/@SelectedMaterialRatioInCard)*(@MaterialQTY*@FromCardUnitToSelectedUnit)),MatItemsCard.UnitName,MResult.MBALANCE,mt000.Unit2Fact,mt000.Unit3Fact
		,MatItemNum AS Number
			FROM MatItemsCard 
			INNER JOIN
			mt000 ON mt000.GUID= MatItemsCard.MatAltGuid
			LEFT JOIN 	( SELECT S.biMatPtr , SUM (S.QTY) AS MBALANCE FROM (
			SELECT biMatPtr ,CASE WHEN  btIsInput=1 THEN SUM (biQty) ELSE SUM (-biQty)  END AS QTY
			FROM vwExtended_bi_st
			GROUP BY 
				biMatPtr,btIsInput ) S
				GROUP BY  S.biMatPtr) AS MResult
			ON MResult.biMatPtr=MatItemsCard.MatAltGuid
			WHERE MatItemsCard.GUID=@CardGuid  	
			ORDER BY MatItemsCard.MatItemNum
			
	UPDATE #RESULT SET BALANCE= CASE WHEN MATUNIT=2 THEN BALANCE/UNIT2FACT WHEN MATUNIT=3 THEN BALANCE/ UNIT3FACT ELSE BALANCE END 

SELECT * FROM #RESULT ORDER BY Number

#########################################################
CREATE FUNCTION GetMaterialsBalanceInStore
(
@CardGuid UNIQUEIDENTIFIER,
@StoreGuid UNIQUEIDENTIFIER
)
RETURNS  @RESULT TABLE 
	(
		MaterialBalance FLOAT,
		MaterialUnit INT,
		UNIT2FACT FLOAT,
		UNIT3FACT FLOAT
	) 
	
AS 
BEGIN
	INSERT INTO @RESULT
		SELECT MResult.MBALANCE,MatItemsCard.Unity,mt000.Unit2Fact,Unit3Fact
			FROM MatItemsCard 
			LEFT JOIN 	( SELECT S.biMatPtr , SUM (S.QTY) AS MBALANCE FROM (
			SELECT biMatPtr ,CASE WHEN  btIsInput=1 THEN SUM (biQty) ELSE SUM (-biQty)  END AS QTY
			FROM vwExtended_bi_st
			WHERE @StoreGuid=CASE WHEN  ISNULL (@StoreGuid,0x0)=0x0  THEN 0x0 ELSE biStorePtr END 
			GROUP BY 
				biMatPtr,btIsInput) S
				GROUP BY  S.biMatPtr) AS MResult
			ON MResult.biMatPtr=MatItemsCard.MatAltGuid
			INNER JOIN mt000
			ON mt000.GUID=MatItemsCard.MatAltGuid
			WHERE MatItemsCard.GUID=@CardGuid  	
			ORDER BY MatItemsCard.MatItemNum
	RETURN
END

#########################################################
CREATE VIEW vwMatAlternativesCards
AS
	SELECT MatAlt.MatAltGuid Material, AltCard.GUID CardGuid
	FROM MaterialAlternatives000 MatAlt INNER JOIN MaterialAlternativesCard000 AltCard ON MatAlt.ParentGUID = AltCard.GUID
#########################################################
CREATE FUNCTION fn_BOMMaterialsGet(@BOMGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN ( 
		select * from JOCBOMRawMaterials000 rawMat where rawMat.JOCBOMGuid = @BOMGuid
 )
#########################################################
CREATE FUNCTION fn_BOMMaterialAlternativesGet(@BOMGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN ( 
    select TOP 1000 Mat.[GUID],Mat.Code,Mat.Name,Mat.LatinName, BOMMats.Number from

	(
	select MatPtr [Guid], 0 AS Number from fn_BOMMaterialsGet(@BOMGuid)
	union
    select AltMats.MatAltGuid [Guid], AltMats.Number from MaterialAlternatives000 AltMats where  AltMats.ParentGUID in 
	(select Alts.CardGuid from (select * from fn_BOMMaterialsGet(@BOMGuid) BOMMats inner join vwMatAlternativesCards AltCards   on BOMMats.MatPtr = AltCards.Material) Alts )
		) BOMMats inner join mt000 Mat on BOMMats.[Guid] = Mat.[Guid]
		ORDER BY Number
 )

#########################################################
CREATE VIEW AllMaterialWithAlternatives 
AS
SELECT  MAT.GUID ,CASE WHEN ISNULL( ALTMat.ParentGUID,0x0)=0x0 THEN MAT.Name ELSE MAT.Name+'  * ' END AS MatName,
CASE WHEN ISNULL( ALTMat.ParentGUID,0x0)=0x0 THEN MAT.LatinName  ELSE MAT.LatinName +'  * ' END AS MatLatinName
		FROM mt000 AS MAT
			 LEFT JOIN MaterialAlternatives000 ALTMat
				ON MAT.GUID=ALTMat.MatAltGuid
#########################################################
CREATE VIEW JocVwMaterialsWithAlternatives
AS
SELECT 
MAT.* 
, CASE WHEN ISNULL( ALTMat.ParentGUID,0x0)=0x0 THEN 0 ELSE 1 END AS HasAlterMat 
,CASE WHEN ISNULL( ALTMat.ParentGUID,0x0)=0x0 THEN MAT.Name ELSE MAT.Name+'  * ' END AS MatName,
CASE WHEN ISNULL( ALTMat.ParentGUID,0x0)=0x0 THEN MAT.LatinName  ELSE MAT.LatinName +'  * ' END AS MatLatinName
		FROM mt000 AS MAT
			 LEFT JOIN MaterialAlternatives000 ALTMat
				ON MAT.GUID=ALTMat.MatAltGuid
#########################################################
#END