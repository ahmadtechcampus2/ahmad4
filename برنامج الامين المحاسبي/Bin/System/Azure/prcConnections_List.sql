###########################################################################################
CREATE PROCEDURE prcConnections_List
	@CleanMe [BIT] = 0 
AS
	SET NOCOUNT ON 
	-- clean first:
	EXEC [prcConnections_Clean] @CleanMe

	CREATE TABLE [#Connections](
		[SPID] [INT],
		[dbid] [INT],
		[loginname] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[hostprocess] [NVARCHAR](100) COLLATE ARABIC_CI_AI,
		[hostname] [NVARCHAR](255) COLLATE ARABIC_CI_AI)

	INSERT INTO [#Connections]
	SELECT -- DISTINCT	
		[session_id],
		[database_id],
		[login_name],
		[host_process_id],
		[host_name]
	FROM 
		[sys].[dm_exec_sessions]	
	WHERE
		[database_id] = db_id() -- (SELECT TOP 1 [dbid] FROM [master]..[sysprocesses] WHERE [HostName] = HOST_NAME() AND [hostprocess] = HOST_ID())
	
	SELECT
		[b].[SPID],
		[b].[hostprocess] AS [HostId],
		ISNULL([m].[LoginName], [b].[loginname]) AS [UserName],
		ISNULL([c].[Start], 0) AS [Start],
		[b].[HostName] AS [HostName],
		CAST (ISNULL([c].[HostId], 0) AS [BIT]) [IsAmeenUser],
		ISNULL( [c].[Exclusive], 0) AS [Exclusive]
	FROM
		[#Connections] AS [b] LEFT JOIN 
		([Connections] AS [c] INNER JOIN [us000] AS [m] ON [c].[UserGUID] = [m].[GUID]) 
		ON  [b].[HostName] = [c].[HostName]  AND [c].[HostId] = [b].[hostprocess]
	ORDER BY
		[IsAmeenUser] DESC,
		[UserName]

###########################################################################################
#END