###########################################################################
CREATE FUNCTION fnGetMatsOfGroups(@GroupGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN(
		SELECT [mtGUID], [mtGroup]
		FROM [vwMt] AS [mt] INNER JOIN [dbo].[fnGetGroupsList](@GroupGUID) AS [gr] ON [mt].[mtGroup] = [gr].[GUID])

###########################################################################
CREATE FUNCTION fnGetMatUnit(@MatGuid UNIQUEIDENTIFIER, @Barcode NVARCHAR(500))
RETURNS TABLE
AS
RETURN
	(SELECT DISTINCT MatUnit , Notes  FROM MatExBarcode000 WHERE MatGuid = @MatGuid AND Barcode = @Barcode)
###########################################################################
#END
