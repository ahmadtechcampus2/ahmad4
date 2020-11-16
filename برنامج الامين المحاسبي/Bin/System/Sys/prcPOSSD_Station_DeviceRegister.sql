#################################################################
CREATE PROCEDURE prcPOSSD_Station_DeviceInsert(
	@StationGuid UNIQUEIDENTIFIER,	
	@DeviceId NVARCHAR(250),
	@LastConnectedOn	DATETIME,
	@DeviceName	NVARCHAR(300),
	@DeviceModel	NVARCHAR(300),
	@DevicePlatform	NVARCHAR(300),
	@DeviceVersion	NVARCHAR(300),
	@DeviceIdiom	NVARCHAR(300),
	@DeviceManufacture	NVARCHAR(300),
	@MaxDevicesCount	INT,
	@ErrorNumber INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
		
	)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_DeviceInsert
	Purpose: save POS device hardware into POSSDStationDevice000 table
	How to Call: EXEC prcPOSSD_Station_DeviceRegister 'CC008441-C78E-47DC-86B7-F8DDBD4D3330','1234446','2019-05-02 10:36:00', 'abc','tuf gaming','Windows','10.0.12345','Desktop','Asus'
	Create By: Hanadi Salka													Created On: 05 May 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @Success					INT	 				= 0;
	DECLARE @DeviceMaxNumber			INT					= 0;
	DECLARE @ActiveFlag					BIT					= 0;	
	DECLARE @DeviceGuid					UNIQUEIDENTIFIER	= NULL;
	DECLARE @Count						INT					= 0;
	-- *********************************************************************************************************
	SET @ErrorMessage   = '';			-- Initialize error message to blank
	SET @ErrorNumber    = @Success;		-- Initialize error number as success
	BEGIN TRY 	
	IF (@ErrorNumber = @Success) 
		BEGIN
			SELECT @Count = COUNT(*) FROM POSSDStationDevice000;
			IF @Count >= @MaxDevicesCount
				BEGIN
					SET @ErrorNumber = 1
					SET @ErrorMessage = 'You can not register the device because you have reached the maximum number of allowed devices'; 
					RETURN;
				END;
			ELSE
				BEGIN					
					SELECT @DeviceMaxNumber = ISNULL(MAX(Number),0) FROM POSSDStationDevice000;
					SET @DeviceGuid = NEWID();
					INSERT INTO POSSDStationDevice000
						([Number]
						,[GUID]
						,[StationGUID]
						,[DeviceID]			   
						,[ActiveFlag]
						,[LastConnectedOn]
						,[DeviceName]
						,[DeviceModel]
						,[DevicePlatform]
						,[DeviceVersion]
						,[DeviceIdiom]
						,[DeviceManufacture])
						VALUES
						(
						(@DeviceMaxNumber + 1)
						,@DeviceGuid
						,@StationGuid 
						,@DeviceId				   
						,@ActiveFlag
						,@LastConnectedOn
						,@DeviceName
						,@DeviceModel
						,@DevicePlatform
						,@DeviceVersion
						,@DeviceIdiom
						,@DeviceManufacture);
					END;
		END;
	END TRY 
	BEGIN CATCH  -- set error number and error message
		SELECT  
			@ErrorNumber = ERROR_NUMBER(),
			@ErrorMessage = ERROR_MESSAGE(); 
	END CATCH;

END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_DeviceRegister(
	@StationGuid UNIQUEIDENTIFIER,	
	@DeviceId NVARCHAR(250),
	@LastConnectedOn	DATETIME,
	@DeviceName	NVARCHAR(300),
	@DeviceModel	NVARCHAR(300),
	@DevicePlatform	NVARCHAR(300),
	@DeviceVersion	NVARCHAR(300),
	@DeviceIdiom	NVARCHAR(300),
	@DeviceManufacture	NVARCHAR(300),
	@MaxDevicesCount	INT,
	@ErrorNumber INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
		
	)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_DeviceRegister
	Purpose: save POS device hardware into POSSDStationDevice000 table
	How to Call: EXEC prcPOSSD_Station_DeviceRegister 'CC008441-C78E-47DC-86B7-F8DDBD4D3330','1234446','2019-05-02 10:36:00', 'abc','tuf gaming','Windows','10.0.12345','Desktop','Asus'
	Create By: Hanadi Salka													Created On: 05 May 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @Success					INT	 				= 0;
	DECLARE @DeviceMaxNumber			INT					= 0;
	DECLARE @ActiveFlag					BIT					= 0;
	DECLARE @InActiveFlag				BIT					= 0;
	DECLARE @DeviceGuid					UNIQUEIDENTIFIER	= NULL;
	DECLARE @Count						INT					= 0;
	-- *********************************************************************************************************
	SET @ErrorMessage   = '';			-- Initialize error message to blank
	SET @ErrorNumber    = @Success;		-- Initialize error number as success
	BEGIN TRY 	
	IF (@ErrorNumber = @Success) 
		BEGIN		
		   
			-- SELECT @Count = COUNT(*) FROM POSSDStationDevice000 WHERE DeviceID = @DeviceId;		
			SELECT @Count = COUNT(*) FROM POSSDStationDevice000 WHERE StationGUID = @StationGuid;		
			IF @Count > 0 
				BEGIN	
					-- Check if the device is associated with POS station other than the current pos station,
					--  if yes then deactive the device for all POS other than the current pos station
					SELECT @Count = COUNT(*) FROM POSSDStationDevice000 WHERE DeviceID != @DeviceId AND StationGUID = @StationGuid;
					IF @Count > 0 
						BEGIN
							-- **********************************************************************************************
							-- count of open shift associated with the specified device id with pos station otherthan the specified  @StationGuid
							SELECT 				
								@Count = COUNT(DISTINCT SH.StationGUID) 
							FROM POSSDStation000 AS S INNER JOIN POSSDShift000 AS SH ON (S.GUID = SH.StationGUID )
							INNER JOIN POSSDShiftDetail000 AS SD ON (SD.ShiftGUID = SH.GUID )
							WHERE S.DataTransferMode != 0
								AND SD.DeviceID != @DeviceId
								AND SH.StationGUID = @StationGuid
								AND  SH.CloseDate IS NULL;
							IF @Count > 0 
								BEGIN
								SET @ErrorNumber = 2
								SET @ErrorMessage = 'You can not register the device because the POS station has an open shift on a different device and data transfer mode is offline'; 
								RETURN;
								END;
							END;
					-- check if the device is associated with current pos station
					-- if yes then update its information and activate it
					-- of not then create it.
					SELECT @Count = COUNT(*) FROM POSSDStationDevice000 WHERE DeviceID = @DeviceId AND StationGUID = @StationGuid;
					IF @Count > 0 
							BEGIN
							-- UPDATE THE DEVICE INFO and activate the current pos
								UPDATE POSSDStationDevice000
								   SET 
									   [DeviceID] = @DeviceId		
									  ,[LastConnectedOn] = @LastConnectedOn
									  ,[DeviceName] = @DeviceName
									  ,[DeviceModel] = @DeviceModel
									  ,[DevicePlatform] = @DevicePlatform
									  ,[DeviceVersion] = @DeviceVersion
									  ,[DeviceIdiom] = @DeviceIdiom
									  ,[DeviceManufacture] = @DeviceManufacture
									  ,[ActiveFlag] = @ActiveFlag
								 WHERE DeviceID = @DeviceId AND StationGUID = @StationGuid;
							END;
					ELSE
						BEGIN
							EXEC prcPOSSD_Station_DeviceInsert @StationGuid ,@DeviceId, @LastConnectedOn, @DeviceName, @DeviceModel, @DevicePlatform, @DeviceVersion, @DeviceIdiom, @DeviceManufacture, @MaxDevicesCount, @ErrorNumber OUTPUT, @ErrorMessage OUTPUT;					
						END;					
				END;
			ELSE
				BEGIN
					EXEC prcPOSSD_Station_DeviceInsert @StationGuid ,@DeviceId, @LastConnectedOn, @DeviceName, @DeviceModel, @DevicePlatform, @DeviceVersion, @DeviceIdiom, @DeviceManufacture, @MaxDevicesCount, @ErrorNumber OUTPUT, @ErrorMessage OUTPUT;					
				END;			
		END;
	END TRY 
	BEGIN CATCH  -- set error number and error message
		SELECT  
			@ErrorNumber = ERROR_NUMBER(),
			@ErrorMessage = ERROR_MESSAGE(); 
	END CATCH;
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_SetActiveDeviceState (
	@DeviceId NVARCHAR(250),
	@StationGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	UPDATE dbo.POSSDStationDevice000
	SET    ActiveFlag = CASE
                        WHEN StationGUID = @StationGuid AND DeviceID = @DeviceId THEN 1
                        WHEN StationGUID <> @StationGuid AND DeviceID <> @DeviceId THEN ActiveFlag                        
						ELSE 0 END
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetActiveDeviceConnectionID (
	@StationGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	Select DeviceConnectionID 
	FROM POSSDStationDevice000 
	WHERE StationGUID = @StationGuid AND ActiveFlag = 1 
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_SetDeviceConnectionID (
	@DeviceId NVARCHAR(250),
	@DeviceConnectionID NVARCHAR(300),
	@StationGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	UPDATE dbo.POSSDStationDevice000
	SET    DeviceConnectionID = @DeviceConnectionID 
	WHERE DeviceID = @DeviceId AND StationGUID = @StationGuid 
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetActiveDeviceID(
	@StationGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	Select DeviceID
	FROM POSSDStationDevice000 
	WHERE StationGUID = @StationGuid AND ActiveFlag = 1 
END

#################################################################
CREATE PROCEDURE prcPOSSD_Station_ManageSwitchDevices  (
	@DeviceId NVARCHAR(250),
	@DeviceConnectionID NVARCHAR(300),
	@StationGuid UNIQUEIDENTIFIER,
	@ShiftGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	
	UPDATE dbo.POSSDTicket000
	SET    [State] = 1
    WHERE 
		 ShiftGUID = @ShiftGuid AND [State] = -1 AND DeviceID <> @DeviceId
	
	EXEC prcPOSSD_Station_SetDeviceConnectionID @DeviceId,@DeviceConnectionID,@StationGuid
	EXEC prcPOSSD_Station_SetActiveDeviceState  @DeviceId,@StationGuid
END 
#################################################################
#END 