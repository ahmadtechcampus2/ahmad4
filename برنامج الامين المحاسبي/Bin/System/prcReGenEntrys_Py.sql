##################################################################
CREATE PROC prcReGenEntrys_Py
	@SrcGuid uniqueidentifier,
	@StartDate datetime,
	@EndDate datetime
AS
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid

	DECLARE @Number INT, @id INT ,@Guid UNIQUEIDENTIFIER
	SELECT @Number = 0, @Guid = 0x0, @id = 0

	CREATE Table #Py( [Guid] [uniqueidentifier], [Number][INT] identity(1,1))
	INSERT INTO [#Py] ([Guid])
		SELECT [Py].[Guid]
		FROM
			[Py000][py]
			INNER JOIN [#EntryTbl] [Src] On [Src].[Type] = [Py].[TypeGuid]
		WHERE
			[Py].[Date] BETWEEN @StartDate AND @EndDate
		ORDER BY 
			[Py].[TypeGuid], [Py].[Number]

	SET @Number = @@rowcount
	
	WHILE @id != @Number
	BEGIN 
		SET @id = @id + 1
		SELECT @Guid = Guid FROM #Py WHERE Number = @id
		IF( ISNULL( @Guid, 0x0) = 0x0)
			RETURN
		EXEC prcReGenEntry_Py @Guid
	END
##################################################################
#END
