####################################################################
CREATE PROCEDURE prcDriverAddress_Insert
	@DriverGUID UNIQUEIDENTIFIER,
	@AddressGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	IF NOT EXISTS(SELECT * FROM RestVendor000 WHERE GUID = @DriverGUID)
		RETURN 

	--IF NOT EXISTS(SELECT * FROM RestAddress000 WHERE GUID = @AddressGUID)
	--	RETURN 

	INSERT INTO RestDriverAddress000(Number, GUID, DriverGUID, AddressGUID)
	SELECT 
		ISNULL((SELECT MAX(Number) FROM RestDriverAddress000 WHERE DriverGUID = @DriverGUID), 0) + 1,
		NEWID(),
		@DriverGUID, 
		@AddressGUID 
####################################################################
CREATE PROCEDURE prcDriverAddress_Delete
	@DriverGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	DELETE RestDriverAddress000 WHERE DriverGUID = @DriverGUID
####################################################################
#END


