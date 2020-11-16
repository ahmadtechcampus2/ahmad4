###########################################################################
CREATE FUNCTION fnGetUserSec(@UserGUID [UNIQUEIDENTIFIER], @ReportID AS [BIGINT], @SubID [UNIQUEIDENTIFIER], @System [INT], @PermType [INT])
	RETURNS [INT]
AS BEGIN
/*
PermType:
	0: Enter
	1: Browse
	2: Modify
	3: Delete
	4: Post
	5: GenEntry
	6: PostEntry
	7: ChangePrice
	8: ReadPrice

System:
	1: Ameen
	2: Orders
	3: Payroll
*/


	DECLARE @Result AS [INT]

	SET @UserGUID = ISNULL(@UserGUID, [dbo].[fnGetCurrentUserGUID]())
	IF [dbo].[fnIsAdmin](@UserGUID) > 0
		RETURN [dbo].[fnGetMaxSecurityLevel]()

	SELECT
		@ReportID = ISNULL(@ReportID, 0),
		@SubID = ISNULL(@SubID, 0x0)

	SELECT @Result = [uiPermission]
	FROM [vwUIX]
	WHERE 
		[uiUserGUID] = @UserGUID
		AND [uiReportId] = @ReportID
		AND [uiSubID] = @SubID
		AND [uiSystem] = @System
		AND [uiPermType] = @PermType

	RETURN ISNULL(@Result, 0)
END

###########################################################################
#END