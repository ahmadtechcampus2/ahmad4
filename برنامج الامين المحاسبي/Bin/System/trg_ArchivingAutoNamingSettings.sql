#########################################################
CREATE TRIGGER trg_ArchivingAutoNamingSettings_UPDATE
	ON [ArchivingAutoNamingSettings] AFTER UPDATE
	NOT FOR REPLICATION

AS 
	SET NOCOUNT ON 
 
	IF EXISTS (SELECT i.ID 
			FROM [deleted]  d 
			INNER JOIN [inserted] i ON i.ID = d.ID 
			WHERE d.DigitsCnt <> i.DigitsCnt OR d.StartNumber <> i.StartNumber)
	BEGIN 
		DECLARE @ID UNIQUEIDENTIFIER = (
			SELECT i.ID 
			FROM [deleted]  d INNER JOIN [inserted] i ON i.ID = d.ID
			WHERE 
				d.DigitsCnt <> i.DigitsCnt 
				OR d.StartNumber <> i.StartNumber
				)

		UPDATE ArchivingAutoNamingSettings
		SET LastSerialNumber = ''
		WHERE ID = @ID
	END
#########################################################
#END