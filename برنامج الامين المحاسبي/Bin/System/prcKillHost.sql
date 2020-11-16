#########################################################
CREATE PROC prcKillHost
	@HostName [NVARCHAR](255) = '',
	@HostId [NVARCHAR](255) = ''
AS 
	SET NOCOUNT ON 
	IF ISNULL( @HostName, '') = '' OR ISNULL( @HostId, '') = '' 
		RETURN
	CREATE TABLE #PROC 
	(
		[spid] [INT],
		[HostId] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL, 
		[HostName] [NVARCHAR](255) COLLATE ARABIC_CI_AI NOT NULL 
	)
	INSERT INTO #PROC 
	SELECT 
		[session_id],
		[host_process_id],
		[host_name]
	FROM 
		sys.dm_exec_sessions
	WHERE 
		[host_name]= @HostName AND [host_process_id] = @HostId AND [session_id] <> @@SPID
	DECLARE 
		@c CURSOR,
		@spid [INT],
		@sql [NVARCHAR](250)
	SET @c = CURSOR FAST_FORWARD FOR SELECT [spid] FROM [#PROC] ORDER BY [spid]
	OPEN @c FETCH NEXT FROM @c INTO @spid
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		SET @sql = 'KILL ' + CAST( @spid AS [NVARCHAR](250))
		EXEC (@sql)
		FETCH NEXT FROM @c INTO @spid
	END 
	CLOSE @c DEALLOCATE @c
#########################################################
#END
