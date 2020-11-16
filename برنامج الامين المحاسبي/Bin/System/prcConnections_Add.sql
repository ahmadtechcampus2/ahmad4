#############################################################################################
CREATE PROCEDURE prcConnections_Add
	@userGUID [UNIQUEIDENTIFIER],
	@bExclusiveMode	[BIT] = 1
AS
/*
This procedure:
	- cleans the connections table.
	- adds a record in the connections table indicating current user connection.
	- usually called once an ameen user logs in to the database
*/
	SET NOCOUNT ON
	-- clean first:
	EXEC [prcConnections_Clean] 1 -- CleanMe

	IF (@bExclusiveMode = 1) and (EXISTS(SELECT * FROM [Connections] WHERE Exclusive <> 0))
	BEGIN
		RAISERROR('AmnE0900: Can''t add connection, database found oppened in Ameen Exclusive Mode', 16, 1)
		RETURN
	END
	declare @UserNum INT ,@BrMask BIGINT
	SET @UserNum = 0
	SELECT @UserNum = Number FROM us000 WHERE Guid = @userGUID
	-- For creating opening entry type
	IF NOT EXISTS ( SELECT * FROM et000 WHERE [GUID] =  'EA69BA80-662D-4FA4-90EE-4D2E1988A8EA' )
	BEGIN 
		IF EXISTS(SELECT *  FROM et000 WHERE [EntryType] =0 AND [SortNum] = 1)
		BEGIN
			UPDATE et000 SET [SortNum] = [SortNum] + 1 WHERE [EntryType] =0
		END
		INSERT INTO et000([Guid],Name,LatinName,
		FldAccName,FldCustomerName,FldDebit,FldCredit,FldCostPtr,FldCurName,FldCurVal,FldCurEqu,
		FldNotes,FldStat,FldDate,FldVendor,FldSalesMan,
		FldAccParent,FldAccFinal,FldAccCredit,FldAccDebit,
		FldAccBalance,FldContraAcc,EntryType,SortNum,[BranchMask],[bAutoPost],[Color1],[Color2],[Abbrev],[LatinAbbrev])
		 VALUES('EA69BA80-662D-4FA4-90EE-4D2E1988A8EA',N'القيد الافتتاحي','Opening Entry'
		 ,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,0,1,[dbo].[fnBranch_GetDefaultMask](),1,16777190,14545480,N'ق.إ',N'O.E')
	 END 
	 ----------
	DELETE [Connections] WHERE [spid] = @@spid
	-- this was ment to be a string to avoid an upgrade problem where UserGUID field used to be User.
	
	INSERT INTO 
		[Connections] ([login_time], [userGUID], [UserNumber]) 
	SELECT TOP 1 [login_time], @userGUID, @UserNum FROM [sys].[dm_exec_sessions] WHERE ISNULL([host_name], '') = HOST_NAME() AND ISNULL([host_process_id], 0) = HOST_ID()
	ORDER BY [login_time] DESC
	
	EXECUTE [prcUser_BuildSecurityTable] @userGUID
	SELECT @BrMask = usBranchReadMask from [dbo].[vwUSX_OfCurrentUser]
	IF @BrMask IS NULL
		SET @BrMask = -1
	UPDATE  [Connections] SET [BranchMask] = @BrMask WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()
	-- clean the errorLog:
	DELETE [ErrorLog] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()

#############################################################################################
#END