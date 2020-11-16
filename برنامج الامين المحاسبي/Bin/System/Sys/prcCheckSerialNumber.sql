################################################################################
CREATE PROCEDURE prcCheckSerialNumber
	@MatID		UNIQUEIDENTIFIER, 
	@BillsID		UNIQUEIDENTIFIER,
	@SerialNumber	NVARCHAR(1000) = ''
AS  
SET NOCOUNT ON

	DECLARE @SaleID UNIQUEIDENTIFIER,@RSaleID UNIQUEIDENTIFIER
	SELECT @SaleID = SalesID, @RSaleID=ReturnedID FROM posuserbills000 WHERE GUID = @BillsID
	

	SELECT TOP 1 ISNULL(MAX(SNC.Qty), 0) Qty, MT.ForceInSN ForceInSN, MT.ForceOutSN ForceOutSN
    FROM MT000 MT 
		LEFT JOIN Snc000 SNC ON SNC.MatGuid = MT.Guid
		LEFT JOIN Snt000 Snt ON Snt.ParentGUID=Snc.GUID AND Snt.stGUID IN 
		(
			SELECT DefStoreGUID FROM BT000 
			WHERE GUID=@SaleID OR GUID=@RSaleID
		)
	WHERE (MatGuid = @MatID) AND (ISNULL(Sn, '') = @SerialNumber OR @SerialNumber='')
	GROUP BY MT.ForceInSN, MT.ForceOutSN 
	ORDER BY  Qty DESC
################################################################################
#END
