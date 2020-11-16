#########################################################
CREATE TRIGGER trg_DMSTblDocumentFieldValue_INSERT
	ON [DMSTblDocumentFieldValue] AFTER INSERT
	NOT FOR REPLICATION

AS 
	SET NOCOUNT ON 

	IF NOT EXISTS (SELECT * FROM [inserted] WHERE  FieldID = 'ac544a47-a89e-463d-9989-c69d8a00331f')
		RETURN

	DECLARE @AutoNameSettingId UNIQUEIDENTIFIER
	DECLARE @SourceID UNIQUEIDENTIFIER
	DECLARE @IsActive BIT
	
	SET @SourceID = 
			(
				SELECT value 
				FROM 
					[inserted]
				WHERE 
					 FieldID = 'ac544a47-a89e-463d-9989-c69d8a00331f'
				)

	SELECT 
		@AutoNameSettingId = ID
		,@IsActive = IsActive
	FROM 
		ArchivingAutoNamingSettings 
	WHERE 
		SourceID = @SourceID

	IF(@AutoNameSettingId IS NOT NULL AND @IsActive = 1)
	BEGIN
		UPDATE ArchivingAutoNamingSettings
		SET LastSerialNumber = (SELECT dbo.[fnGetDocumentDefaultNameNextSerialNumber](@SourceID))
		WHERE ID = @AutoNameSettingId
	END
#########################################################
#END