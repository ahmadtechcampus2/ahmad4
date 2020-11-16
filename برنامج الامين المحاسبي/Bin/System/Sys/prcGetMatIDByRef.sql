################################################################################
CREATE PROC prcGetMatIDByRef
	@Ref	NVARCHAR(256)
AS
SET NOCOUNT ON
	;WITH res AS
	(
		SELECT
			MtGuid,
			CASE 	WHEN @Ref = mtBarcode THEN 	1
					WHEN @Ref = mtBarcode2 THEN 2
					WHEN @Ref = mtBarcode3 THEN 3
					WHEN @Ref = exBarcode.Barcode THEN exBarcode.MatUnit
					ELSE -1
			END AS Unit,
			mt.mtHasSegments AS HasSegments
		FROM vwMt mt
			LEFT JOIN MatExBarcode000 exBarcode ON mt.mtGUID = exBarcode.MatGuid
				WHERE (mtBarcode = 	@Ref)
					OR (mtBarcode2 = 	@Ref)
					OR (mtBarcode3 = 	@Ref)
					OR (exBarcode.Barcode = @Ref)
					OR (mtCode = 	@Ref)
					OR (mtName LIKE	'%' + @Ref + '%')
					OR (mtLatinName LIKE '%' + @Ref + '%')
		)
		SELECT DISTINCT MtGuid, Unit, HasSegments FROM res
################################################################################
CREATE FUNCTION fnGetMatIDByBarcode
	(@Ref	nvarchar(256))
	RETURNS TABLE
AS
RETURN

SELECT 
	mt.[Number],
	mt.[Name] ,
	mt.[Code] ,
	mt.[LatinName],
	mx.[BarCode] AS BarCode,--CASE mx.MatUnit WHEN 1 THEN mx.[BarCode] ELSE '' END AS BarCode ,
	[CodedCode] ,
	mt.[Unity] AS  Unity,
	[Spec],
	[Qty],
	[High],
	[Low],
	[Whole],
	[Half],
	[Retail],
	[EndUser],
	[Export],
	[Vendor],
	[MaxPrice],
	[AvgPrice] ,
	[LastPrice] ,
	[PriceType],
	[SellType] ,
	[BonusOne],
	[CurrencyVal],
	[UseFlag],
	[Origin] ,
	[Company],
	mt.[Type] ,
	mt.[Security],
	[LastPriceDate],
	[Bonus],
	[Unit2] ,
	[Unit2Fact],
	[Unit3] ,
	[Unit3Fact],
	[Flag] ,
	[Pos] ,
	[Dim],
	[ExpireFlag],
	[ProductionFlag],
	[Unit2FactFlag],
	[Unit3FactFlag],
	mx.[BarCode] AS BarCode2,--CASE mx.MatUnit WHEN 2 THEN mx.[BarCode] ELSE '' END AS BarCode2,
	mx.[BarCode] AS BarCode3,--CASE mx.MatUnit WHEN 3 THEN mx.[BarCode] ELSE '' END AS BarCode3,
	[SNFlag] ,
	[ForceInSN] ,
	[ForceOutSN],
	mt.[VAT] ,
	[Color],
	[Provenance] ,
	[Quality],
	[Model] ,
	[Whole2],
	[Half2] ,
	[Retail2] ,
	[EndUser2] ,
	[Export2] ,
	[Vendor2],
	[MaxPrice2],
	[LastPrice2],
	[Whole3] ,
	[Half3] ,
	[Retail3] ,
	[EndUser3],
	[Export3] ,
	[Vendor3],
	[MaxPrice3] ,
	[LastPrice3] ,
	mt.[GUID],
	[GroupGUID] ,
	mt.[PictureGUID],
	[CurrencyGUID],
	[DefUnit] ,
	[bHide] ,
	mt.[branchMask] ,
	[OldGUID] ,
	[NewGUID] ,
	[Assemble]  ,
	[OrderLimit]  ,
	[CalPriceFromDetail],
	[ForceInExpire] ,
	[ForceOutExpire] ,
	[CreateDate],
	[IsIntegerQuantity],
	[gr].[Code] AS [grCode], 
	[gr].[Name] AS [grName], 
	[gr].[LatinName] AS [grLatinName]
 FROM 
	[mt000] [mt] LEFT JOIN [MatExBarcode000] mx ON [mt].Guid = mx.MatGuid  
	INNER JOIN [vbGr] AS [gr] ON [mt].[GroupGUID] = [gr].[GUID] 
  WHERE mx.Barcode = @Ref	
################################################################################
CREATE FUNCTION fnGetPOSCurrencyVal(@mtCurrGuid UNIQUEIDENTIFIER,@mtCurrVal FLOAT)
RETURNS FLOAT
AS 
BEGIN
	
	DECLARE @DefCurrGuid UNIQUEIDENTIFIER,
			@DefCurrVal FLOAT
	
	SELECT @DefCurrGuid = [Value] FROM FileOP000 
	WHERE [Name] = 'AmnPOS_DefaultCurrencyID'
	IF ISNULL(@DefCurrGuid,0X0) = 0X0
		RETURN 1
	ELSE 
		SET @DefCurrVal = dbo.fnGetCurVal(@DefCurrGuid,GetDate()) 
	IF(@mtCurrGuid = @DefCurrGuid ) 
		RETURN 1 / @mtCurrVal
	ELSE
	    RETURN (1 / @mtCurrVal) * dbo.fnGetCurVal(@mtCurrGuid,GetDate()) / @DefCurrVal

	RETURN 1
END
################################################################################
CREATE FUNCTION fnGetMatPriceByPosCurrency()
	RETURNS TABLE
AS
RETURN

SELECT 
	mt.[Number],
	mt.[Name],
	mt.[Code],
	mt.[LatinName],
	mt.barCode,
	[CodedCode] ,
	mt.[Unity] AS  Unity,
	[Spec],
	[Qty],
	[High],
	[Low],
	[Whole]		* c.currVal AS  [Whole],
	[Half]		* c.currVal  AS  [Half],
	[Retail]	* c.currVal AS  [Retail],
	[EndUser]	* c.currVal AS [EndUser],
	[Export]	* c.currVal AS  [Export],
	[Vendor]	* c.currVal AS  [Vendor],
	[MaxPrice]  * c.currVal AS [MaxPrice],
	[AvgPrice]  * c.currVal AS [AvgPrice],
	[LastPrice] * c.currVal AS [LastPrice],
	[PriceType],
	[SellType] ,
	[BonusOne],
	[CurrencyVal],
	[UseFlag],
	[Origin] ,
	[Company],
	mt.[Type] ,
	mt.[Security],
	[LastPriceDate],
	[Bonus],
	[Unit2] ,
	[Unit2Fact],
	[Unit3] ,
	[Unit3Fact],
	[Flag] ,
	[Pos] ,
	[Dim],
	[ExpireFlag],
	[ProductionFlag],
	[Unit2FactFlag],
	[Unit3FactFlag],
	[BarCode2],
	[BarCode3],
	[SNFlag] ,
	[ForceInSN] ,
	[ForceOutSN],
	mt.[VAT] ,
	[Color],
	[Provenance] ,
	[Quality],
	[Model] ,
	[Whole2]	* c.currVal  AS  [Whole2],
	[Half2]		* c.currVal  AS  [Half2],
	[Retail2]	* c.currVal  AS  [Retail2],
	[EndUser2]  * c.currVal  AS  [EndUser2],
	[Export2]   * c.currVal  AS  [Export2],
	[Vendor2]   * c.currVal  AS  [Vendor2],
	[MaxPrice2] * c.currVal  AS  [MaxPrice2],
	[LastPrice2]* c.currVal  AS  [LastPrice2],
	[Whole3]	* c.currVal  AS  [Whole3],
	[Half3]		* c.currVal  AS  [Half3],
	[Retail3]	* c.currVal  AS  [Retail3],
	[EndUser3]  * c.currVal  AS  [EndUser3],
	[Export3]   * c.currVal  AS  [Export3],
	[Vendor3]	* c.currVal  AS  [Vendor3],
	[MaxPrice3] * c.currVal  AS  [MaxPrice3],
	[LastPrice3]* c.currVal  AS  [LastPrice3],
	mt.[GUID],
	[GroupGUID] ,
	mt.[PictureGUID],
	[CurrencyGUID],
	[DefUnit] ,
	[bHide] ,
	mt.[branchMask] ,
	[OldGUID] ,
	[NewGUID] ,
	[Assemble]  ,
	[OrderLimit]  ,
	[CalPriceFromDetail],
	[ForceInExpire] ,
	[ForceOutExpire] ,
	[CreateDate],
	[IsIntegerQuantity],
	[gr].[Code] AS [grCode], 
	[gr].[Name] AS [grName], 
	[gr].[LatinName] AS [grLatinName]
 FROM 
	vdMt [mt] 
	INNER JOIN [vbGr] AS [gr] ON [mt].[GroupGUID] = [gr].[GUID] 
	CROSS APPLY (SELECT dbo.fnGetPOSCurrencyVal(CurrencyGuid,CurrencyVal) AS currVal ) AS c
##################################################################################################	
#END