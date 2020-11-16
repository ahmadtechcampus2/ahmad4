###########################################################################################
CREATE PROC prcGetSQLProccess
	@ShowSystemReservedProccess BIT = 0,
	@ShowAmeenProccessOnly BIT = 0
AS
	SET NOCOUNT ON
	CREATE TABLE #TEMP(spid SMALLINT, EventInfo NVARCHAR(MAX) NULL)

	IF EXISTS (SELECT * FROM   sys.all_objects WHERE name = 'dm_exec_input_buffer')
	BEGIN
	DECLARE @SQL NVARCHAR(MAX) = ' 
		INSERT INTO #TEMP
		SELECT p.spid , d.event_info
		FROM 
		sys.dm_exec_requests AS R
		LEFT JOIN master.dbo.sysprocesses AS P ON P.spid = R.session_id
		OUTER APPLY sys.dm_exec_input_buffer(P.spid, NULL) as d'
		EXEC (@SQL)
	END
	ELSE
	BEGIN
		CREATE TABLE #InputbufferTemp(EventType NVARCHAR(100) NULL, Parameters INT NULL, EventInfo  NVARCHAR(MAX) NULL)
		DECLARE @SId NVARCHAR(256)
		DECLARE @PeoplePhoneCursor as CURSOR;
		SET @PeoplePhoneCursor = CURSOR FAST_FORWARD FOR
		SELECT CONVERT(NVARCHAR, session_id) FROM sys.dm_exec_sessions
		OPEN @PeoplePhoneCursor;
		FETCH NEXT FROM @PeoplePhoneCursor INTO @SId;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			INSERT #TEMP (spid) (SELECT CONVERT(SMALLINT, @SId))
			INSERT #InputbufferTemp EXEC('DBCC INPUTBUFFER('+ @SId +')') 
			UPDATE #TEMP
				SET EventInfo = source.EventInfo
			FROM #InputbufferTemp as source
			WHERE spid = CONVERT(SMALLINT, @SId)
			DELETE #InputbufferTemp
			FETCH NEXT FROM @PeoplePhoneCursor INTO @SId
		END
		CLOSE @PeoplePhoneCursor;
		DEALLOCATE @PeoplePhoneCursor;
		DROP TABLE #InputbufferTemp
	END

	SELECT
		P.spid,
		R.total_elapsed_time,
		right(CONVERT(VARCHAR, 
				DATEADD(ms,R.total_elapsed_time, '1900-01-01'), 
				121), 12) AS 'batch_duration',
		RTRIM(P.program_name) AS program_name,
		RTRIM(P.hostname) AS hostname,
		RTRIM(P.loginame) AS SQLLoginName,
		R.cpu_time,
		R.reads,
		R.writes,
		DB_NAME(R.database_id) AS DBName,
		US.LoginName AS AmnLoginName,
		RTRIM(p.cmd) AS cmd,
		--T.text AS SQLCmd
		RTRIM(ISNULL(temp.EventInfo, '')) AS SQLCmd
	FROM 
		sys.dm_exec_requests AS R
		LEFT JOIN master.dbo.sysprocesses AS P ON P.spid = R.session_id
		LEFT JOIN #TEMP AS temp ON temp.spid = P.spid
		--OUTER APPLY sys.dm_exec_sql_text(P.sql_handle) AS txt
		LEFT JOIN Connections AS C ON C.SPID = P.spid
		LEFT JOIN us000 AS US ON US.GUID = C.UserGUID
	WHERE 
		(
			@ShowSystemReservedProccess = 1
			OR
			(
				@ShowSystemReservedProccess = 0 AND
				(P.spid > 50
					AND P.[status] NOT IN ('background', 'sleeping')
					AND P.cmd NOT IN ('AWAITING COMMAND'
							,'MIRROR HANDLER'
							,'LAZY WRITER'
							,'CHECKPOINT SLEEP'
							,'RA MANAGER'))
			)
		)
		AND
		(
			@ShowAmeenProccessOnly = 0 
			OR
			(
				@ShowAmeenProccessOnly = 1
				AND
				(P.program_name LIKE N'%Al-Ameen90%' OR P.program_name LIKE N'%.Net SqlClient Data Provider%')
			)
		)
	ORDER BY 
		batch_duration 
	DESC

###########################################################################################
CREATE PROC prcGetSQLRecentExpensiveQueries
AS
	SET NOCOUNT ON

	SELECT TOP 20    
	        DatabaseName = DB_NAME(CONVERT(int, epa.value)), 
	        [Execution count] = qs.execution_count,
	        [CpuPerExecution] = total_worker_time / qs.execution_count ,
	        [TotalCPU] = total_worker_time,
			[Average Duration] = total_elapsed_time / qs.execution_count,        
			[Query] = qt.text,
			qs.total_logical_reads,
			qs.total_logical_writes,
			qs.total_physical_reads   
	    FROM sys.dm_exec_query_stats qs
	    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
	    OUTER APPLY sys.dm_exec_plan_attributes(plan_handle) AS epa
	    WHERE epa.attribute = 'dbid'
	        AND epa.value = db_id()
	    ORDER BY [TotalCPU] DESC;
	
###########################################################################################
#END