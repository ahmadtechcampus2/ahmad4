##############################################################
CREATE PROC prcPOSFindReturnVoucher
	@VoucherNumber	NVARCHAR(256),
	@VoucherType	UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	SELECT 
		Val				AS VoucherValue,
		GUID			AS VoucherID,
		CAST(0 AS BIT)	AS IsReturned
	INTO 
		#ch
	FROM 
		ch000 ch
	WHERE 	
		(TypeGUID = @VoucherType)
		AND  	
		(Num = @VoucherNumber)
		AND 	
		([State] = 0)

	UPDATE ch
	SET IsReturned = 1
	FROM #ch ch
	WHERE 
		EXISTS (
			SELECT 1 
			FROM 
				POSPaymentsPackage000 pak
				INNER JOIN POSOrder000 o ON pak.GUID = o.PaymentsPackageID
			WHERE 
				pak.ReturnVoucherID = ch.VoucherID)

	SELECT TOP 1 * FROM #ch
##############################################################
#END