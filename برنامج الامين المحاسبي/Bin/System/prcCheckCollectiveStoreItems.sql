##############################################################
CREATE PROC prcCheckCollectiveStoreItems(@ids NVARCHAR(MAX))
AS
	SET NOCOUNT ON;

	DECLARE @tbl TABLE(Guid UNIQUEIDENTIFIER);
	DECLARE @start INT = 0, 
			@pos INT = 1, 
			@id UNIQUEIDENTIFIER;

	WHILE @pos > 0
	BEGIN
		SET @pos = CHARINDEX(',', @ids, @start);
		INSERT INTO @tbl VALUES(SUBSTRING(@ids, @start, CASE WHEN @pos > 0 THEN @pos - @start ELSE LEN(@ids) - @start + 1 END));
		SET @start = @pos + 1;
	END

	DECLARE C CURSOR FOR SELECT * FROM @tbl;

	OPEN C;
	FETCH FROM C INTO @id;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF EXISTS(SELECT * FROM fnGetStoresList(@id) L JOIN @tbl T ON L.GUID = T.Guid AND T.Guid <> @id)
		BEGIN
			SELECT 0 AS Valid;
			RETURN
		END
		FETCH FROM C INTO @id;
	END

	CLOSE C;
	DEALLOCATE C;

	SELECT 1 AS Valid;
###########################################################
#END