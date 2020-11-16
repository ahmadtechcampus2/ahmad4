##################################################################################
CREATE PROC prcGetReportState
	@TypeGuid	UNIQUEIDENTIFIER,
	@ReortId	INT
AS
BEGIN
	SELECT State
	FROM rvState000
	WHERE UserGuid = dbo.fnGetCurrentUserGUID() AND TypeGuid = @TypeGuid AND ReportId = @ReortId;
END
##################################################################################
#END