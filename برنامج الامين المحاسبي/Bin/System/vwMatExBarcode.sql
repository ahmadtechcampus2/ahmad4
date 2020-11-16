#########################################################
CREATE VIEW vwMatExBarcode
AS
	SELECT
		ExBarcode.[MatGuid]													AS MatGuid,
		ExBarcode.[Number]													AS Number,
		ExBarcode.[Barcode]													AS Barcode,
		CASE ExBarcode.[MatUnit] WHEN 1 THEN ExBarcode.Barcode ELSE '' END	AS MatBarcode,
		CASE ExBarcode.[MatUnit] WHEN 2 THEN ExBarcode.Barcode ELSE '' END	AS MatBarcode2,
		CASE ExBarcode.[MatUnit] WHEN 3 THEN ExBarcode.Barcode ELSE '' END	AS MatBarcode3,
		ExBarcode.[MatUnit]													AS MatUnit,
		ExBarcode.[IsDefault]												AS [IsDefault]
	FROM
		MatExBarcode000 AS ExBarcode
GO
#########################################################
#END