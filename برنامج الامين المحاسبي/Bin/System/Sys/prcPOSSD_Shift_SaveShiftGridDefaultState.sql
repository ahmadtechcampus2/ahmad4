################################################################################
CREATE PROCEDURE prcPOSSD_Shift_SaveShiftGridDefaultState
-- Params -------------------------------
	@ColumnsOrderState      NVARCHAR(250),
	@ColumnsVisibilityState NVARCHAR(250),
	@ColumnsGroupingState   NVARCHAR(250),
	@ColumnsFixedState		NVARCHAR(250),
	@FilterState			NVARCHAR(10)
-----------------------------------------   
AS
    SET NOCOUNT ON
---------------------------------------------------------------------
	DECLARE @ColumnsOrderStateName	    NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Order'
	DECLARE @ColumnsVisibilityStateName NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Visibility'
	DECLARE @ColumnsGroupingStateName   NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Grouping'
	DECLARE @ColumnsFixedStateName      NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Fixed'
	DECLARE @FilterStateName		    NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Filter'
	

	

	--=================== COLUMNS ORDER STATE
	IF EXISTS(SELECT Name From op000 where  name = @ColumnsOrderStateName)
	BEGIN
		UPDATE op000 SET Value = @ColumnsOrderState WHERE Name = @ColumnsOrderStateName
	END
	ELSE
	BEGIN
		INSERT INTO op000([GUID], Name, Value, PrevValue, Computer, [Time], [Type], OwnerGUID, UserGUID)
		VALUES(NEWID(), @ColumnsOrderStateName, @ColumnsOrderState, '', HOST_NAME(), GETDATE(), 1, 0x0, 0x0)
	END 

	--=================== COLUMNS VISIBILITY STATE
	IF EXISTS(SELECT Name From op000 where  name = @ColumnsVisibilityStateName)
	BEGIN
		UPDATE op000 SET Value = @ColumnsVisibilityState WHERE Name = @ColumnsVisibilityStateName
	END
	ELSE
	BEGIN
		INSERT INTO op000([GUID], Name, Value, PrevValue, Computer, [Time], [Type], OwnerGUID, UserGUID)
		VALUES(NEWID(), @ColumnsVisibilityStateName, @ColumnsVisibilityState, '', HOST_NAME(), GETDATE(), 1, 0x0, 0x0)
	END

	--=================== COLUMNS GROUPING STATE
	IF EXISTS(SELECT Name From op000 where  name = @ColumnsGroupingStateName)
	BEGIN
		UPDATE op000 SET Value = @ColumnsGroupingState WHERE Name = @ColumnsGroupingStateName
	END
	ELSE
	BEGIN
		INSERT INTO op000([GUID], Name, Value, PrevValue, Computer, [Time], [Type], OwnerGUID, UserGUID)
		VALUES(NEWID(), @ColumnsGroupingStateName, @ColumnsGroupingState, '', HOST_NAME(), GETDATE(), 1, 0x0, 0x0)
	END

	--=================== COLUMNS FIXED STATE
	IF EXISTS(SELECT Name From op000 where  name = @ColumnsFixedStateName)
	BEGIN
		UPDATE op000 SET Value = @ColumnsFixedState WHERE Name = @ColumnsFixedStateName
	END
	ELSE
	BEGIN
		INSERT INTO op000([GUID], Name, Value, PrevValue, Computer, [Time], [Type], OwnerGUID, UserGUID)
		VALUES(NEWID(), @ColumnsFixedStateName, @ColumnsFixedState, '', HOST_NAME(), GETDATE(), 1, 0x0, 0x0)
	END

	--=================== COLUMNS FIXED STATE
	IF EXISTS(SELECT Name From op000 where  name = @FilterStateName)
	BEGIN
		UPDATE op000 SET Value = @FilterState WHERE Name = @FilterStateName
	END
	ELSE
	BEGIN
		INSERT INTO op000([GUID], Name, Value, PrevValue, Computer, [Time], [Type], OwnerGUID, UserGUID)
		VALUES(NEWID(), @FilterStateName, @FilterState, '', HOST_NAME(), GETDATE(), 1, 0x0, 0x0)
	END
#################################################################
#END

 

