################################################################################
CREATE TRIGGER trg_SpecialOffer000_Insert
	ON SpecialOffer000 FOR INSERT
	NOT FOR REPLICATION
AS
	SET NOCOUNT ON

	UPDATE s
		SET [OfferIndex] = (SELECT ISNULL(MAX([OfferIndex]), 0) + 1 FROM SpecialOffer000)
	FROM SpecialOffer000 s
	INNER JOIN inserted i ON s.[Guid] = i.[Guid]
################################################################################
#END