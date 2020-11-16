################################################################################
CREATE PROCEDURE prcGetBillMaterialsAndPrices
	@BillGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	SELECT
		mt.[GUID],
		mt.Code + '-' + mt.Name AS Name,
		mt.CompositionName,
		bi.Price,
		mt.Unity
	FROM
		bi000 bi
		INNER JOIN mt000 mt ON bi.MatGUID = mt.GUID
	WHERE
		bi.ParentGUID = @BillGuid
################################################################################
#END
