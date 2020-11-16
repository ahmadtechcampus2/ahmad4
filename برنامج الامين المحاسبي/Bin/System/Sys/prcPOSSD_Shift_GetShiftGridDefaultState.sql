################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetShiftGridDefaultState
-- Params ------------------------------------
	@StateType      INT -- 1: cloumns order
						-- 2: columns visible
						-- 3: columns grouping
						-- 4: columns fixed 
----------------------------------------------
AS
    SET NOCOUNT ON
---------------------------------------------------------------------
	DECLARE @ColumnsOrderStateName	    NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Order'
	DECLARE @ColumnsVisibilityStateName NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Visibility'
	DECLARE @ColumnsGroupingStateName   NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Grouping'
	DECLARE @ColumnsFixedStateName      NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Fixed'
	DECLARE @FilterStateName		    NVARCHAR(50) = 'AmnCfg_Grid_POSSDShiftGrid_Filter'

	SELECT 
		Value AS [State]
	FROM 
		op000 
	WHERE 
		(@StateType = 1 AND Name = @ColumnsOrderStateName)
	  OR(@StateType = 2 AND Name = @ColumnsVisibilityStateName)
	  OR(@StateType = 3 AND Name = @ColumnsGroupingStateName)
	  OR(@StateType = 4 AND Name = @ColumnsFixedStateName)
	  OR(@StateType = 5 AND Name = @FilterStateName)
#################################################################
#END

 

