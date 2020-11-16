##################################################################################
CREATE PROC prcSaveReportState
	@TypeGuid	UNIQUEIDENTIFIER,
	@ReortId	INT,
	@State		NVARCHAR(MAX)
AS
BEGIN
	IF EXISTS(SELECT * FROM rvState000 WHERE UserGuid = dbo.fnGetCurrentUserGUID() AND TypeGuid = @TypeGuid AND ReportId = @ReortId)
		UPDATE rvState000
			SET State = @State
		WHERE
			UserGuid = dbo.fnGetCurrentUserGUID() AND TypeGuid = @TypeGuid AND ReportId = @ReortId;
	ELSE
		INSERT INTO rvState000(Guid, UserGuid, TypeGuid, ReportId, State)
			VALUES(NEWID(), dbo.fnGetCurrentUserGUID(), @TypeGuid, @ReortId, @State);
END
##################################################################################
#END