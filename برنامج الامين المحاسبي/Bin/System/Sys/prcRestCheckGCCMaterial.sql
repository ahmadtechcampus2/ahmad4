################################################################
CREATE PROCEDURE prcRestCheckGCCMaterial
		@ConfigGUID UNIQUEIDENTIFIER = 0x0
AS

SELECT * FROM bg000 bg
	INNER JOIN bgi000 bgi ON bg.Guid = bgi.ParentID
	INNER JOIN mt000 mt ON mt.GUID = bgi.ItemID
	LEFT JOIN GCCMaterialTax000 tax ON mt.GUID = tax.MatGUID
		WHERE bg.ConfigID = @ConfigGUID
			AND ISNULL(tax.TaxCode, 0) <= 0 

IF @@ROWCOUNT > 0
	RETURN 0
ELSE
	RETURN 1
####################################################################
#END


