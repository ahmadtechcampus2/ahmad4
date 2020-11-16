################################################################################
CREATE PROC CheckImpMatInvLineGuid (
	@ImpGuid UNIQUEIDENTIFIER,
	@ImpBarcode NVARCHAR(100),
	@ImpState BIT
) AS
BEGIN
SET NOCOUNT ON
	DECLARE
		@MatGuid UNIQUEIDENTIFIER;
			SET @MatGuid =(SELECT [GUID] FROM mt000 WHERE [GUID] = @ImpGuid)
			IF (ISNULL(@MatGuid,0x00) = 0x00)
			BEGIN
				SET @MatGuid =(
				SELECT [GUID] FROM mt000 
				WHERE ([BarCode] = @ImpBarcode OR [BarCode2] = @ImpBarcode OR [BarCode3] = @ImpBarcode ) 
				AND ((SELECT COUNT(*) FROM mt000 WHERE ([BarCode] = @ImpBarcode OR [BarCode2] = @ImpBarcode OR [BarCode3] = @ImpBarcode)) = 1) 
				AND (@ImpState = 1))
				IF (ISNULL(@MatGuid,0x00) = 0x00)
					SET @MatGuid = (SELECT 0x00)
			END
	SELECT @MatGuid AS [GUID]
END
################################################################################
#END
