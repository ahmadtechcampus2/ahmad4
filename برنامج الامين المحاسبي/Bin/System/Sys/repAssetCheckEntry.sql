###########################################################################
CREATE PROC repAssetCheckEntry
				@AssGuid UNIQUEIDENTIFIER,
				@AssCode NVARCHAR(256),
				@AssName NVARCHAR(256),
				@MatGUID UNIQUEIDENTIFIER
AS
	DECLARE @Result TABLE( Type INT)
	IF( EXISTS( SELECT * FROM as000 WHERE ParentGUID = @MatGUID AND GUID <> @AssGuid))
		INSERT INTO @Result VALUES( 2)
	SELECT * FROM @Result
###########################################################################
#END