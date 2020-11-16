##################################################################################
CREATE PROC prcClearReportState
	@TypeGuid	UNIQUEIDENTIFIER,
	@ReortId	INT
AS
BEGIN
	DELETE rvState000
	WHERE UserGuid = dbo.fnGetCurrentUserGUID() AND TypeGuid = @TypeGuid AND ReportId = @ReortId;
END
##################################################################################
#END