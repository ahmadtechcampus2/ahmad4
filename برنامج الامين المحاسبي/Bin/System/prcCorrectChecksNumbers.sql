###########################################################################
CREATE PROCEDURE prcCorrectChecksNumbers
AS
	-- repeat all steps for all types
	SET NOCOUNT ON

	DECLARE
		@c CURSOR,
		@Type [UNIQUEIDENTIFIER]

	--setup cursor:
	SET @c = CURSOR FAST_FORWARD FOR SELECT DISTINCT [TypeGUID] FROM [ch000]
	OPEN @c FETCH FROM @c INTO @Type

	-- start:
	WHILE @@FETCH_STATUS = 0
	BEGIN
		CREATE TABLE [#tch]([ID] [INT] IDENTITY, [GUID] [UNIQUEIDENTIFIER])
		INSERT INTO [#tch](GUID) SELECT [GUID] FROM [ch000] WHERE [TypeGUID] = @Type
		UPDATE [ch000] SET [Number] = [#tch].[ID] FROM [#tch] WHERE [ch000].[GUID] = [#tch].[GUID]
		DROP TABLE [#tch]
		FETCH FROM @c INTO @Type
	END
	CLOSE @c
	DEALLOCATE @c
###########################################################################
#END