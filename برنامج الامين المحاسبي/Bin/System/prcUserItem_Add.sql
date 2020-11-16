########################################################
CREATE PROCEDURE prcUserItem_Add
	@UserGUID [UNIQUEIDENTIFIER],
	@ReportID [FLOAT],
	@SubID [UNIQUEIDENTIFIER],
	@System [INT],
	@PermType [INT],
	@Permission [INT]
AS 

	SET NOCOUNT ON

	INSERT INTO [ui000]( [UserGUID], [ReportId], [SubId], [System], [PermType], [Permission])
	VALUES( @UserGUID, @ReportID, @SubID, @System, @PermType, @Permission)

########################################################
#END 