#################################################################
CREATE PROCEDURE prcPOSGetPosInfo
@deviceId NVARCHAR(50)
AS 
BEGIN

	SELECT PC.* 
	 FROM POSCard000 PC 
	 INNER JOIN POSCardDevice000 PD 
	 ON PC.Guid = PD.POSCardGuid
	WHERE PD.DeviceID = @deviceId

END 
#################################################################
CREATE FUNCTION GetAmeenPosProAPIVersion()
RETURNS NVARCHAR(50)
AS
BEGIN
	DECLARE @ameenPosProAPIVersion NVARCHAR(50)

	SELECT @ameenPosProAPIVersion = CONVERT(NVARCHAR(50), value) FROM sys.extended_properties WHERE name = 'AmnPosProAPIVersion'

	RETURN @ameenPosProAPIVersion

END
#################################################################
#END 