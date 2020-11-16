#########################################################
CREATE PROCEDURE prcConnections_Clean 
	@CleanMe [BIT] = 0 
AS 
	SET NOCOUNT ON 

	BEGIN TRAN 

	CREATE TABLE [#Connections](
		[dbid] int,
		[login_time] [datetime],
		[loginname] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[hostprocess] [NVARCHAR](100) COLLATE ARABIC_CI_AI,
		[hostname] [NVARCHAR](255) COLLATE ARABIC_CI_AI)

	INSERT INTO [#Connections]
	SELECT 
		[dbid],
		[login_time],
		[loginame],
		[hostprocess],
		[hostname]
	FROM 
		[master]..[sysprocesses]

	DECLARE @Days INT -- Constant
	
	SET @Days = -3
	
	DELETE [Connections]
	FROM 
		[Connections] AS [c]
		LEFT JOIN [#Connections] [t] ON ([c].[HostId] COLLATE ARABIC_CI_AI)= ([t].[hostprocess] COLLATE ARABIC_CI_AI) AND ([c].[HostName] COLLATE ARABIC_CI_AI) = ([t].[hostname] COLLATE ARABIC_CI_AI)
	WHERE 
		[t].[hostname] IS NULL
		AND 
		(([c].[Exclusive] = 0 AND [c].[login_time] < DATEADD(DAY, @Days, GETDATE())) OR [c].[Exclusive] = 1)

	DECLARE @CurrentDate [DATETIME],@ExpireTime [INT]
	SET @ExpireTime = [dbo].[fnGetSrcExpiryTime]()
	SET @CurrentDate =  GETDATE()
	DELETE [repSrcs] WHERE DATEDIFF ( mi , [CreateDate] , @CurrentDate ) >= @ExpireTime  
	DELETE  [InsertedSn] WHERE DATEDIFF ( mi , [CreatedDate] , @CurrentDate ) >= @ExpireTime  
	IF @CleanMe = 1
	BEGIN
		DELETE [Connections] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()
		DELETE [RepSrcs] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()
		DELETE [TempBills000] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()

	END

	COMMIT TRAN
#########################################################
#END
