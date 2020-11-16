#########################################################
CREATE PROCEDURE prcGetEntriesTypesOfBillsTypesList
	@BillSrc [NVARCHAR](max) = 'ALL', 
	@UserID [INT] = 0 
AS
	SET NOCOUNT ON
	
	DECLARE
		@t TABLE([Number] [INT])

	DECLARE 
		@c CURSOR,
		@EntrySrc [NVARCHAR](2000),
		@Number [INT]

	IF @UserID = 0 
		SET @UserID = [dbo].[fnGetCurrentUserID]() 

	IF ISNULL(@BillSrc, 'ALL') = 'ALL'
		INSERT INTO @t SELECT [Number] + 1 FROM [vwBt] WHERE [Type] = 1
	ELSE BEGIN
		INSERT INTO @t SELECT [Data] FROM [fnTextToRows](@BillSrc)
		UPDATE @t SET [Number] = [Number] + 1
	END

	SET @EntrySrc = ''
	SET @c = CURSOR FAST_FORWARD FOR SELECT [Number] FROM @t ORDER BY [Number]
	OPEN @c FETCH FROM @c INTO @Number
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @EntrySrc = @EntrySrc + CAST(@Number AS NVARCHAR) + ','
		FETCH FROM @c INTO @Number
	END
	CLOSE @c
	DEALLOCATE @c

	IF @EntrySrc <> ''
		SET @EntrySrc = Left(@EntrySrc, Len(@EntrySrc) - 1)

	EXEC [prcGetEntriesTypesList] @EntrySrc, @UserID
	
#########################################################