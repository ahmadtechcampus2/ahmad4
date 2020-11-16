##################################################################################
CREATE PROCEDURE prcCopyUsersPermession
	@SourceUserGuid			[UNIQUEIDENTIFIER],
	@DestinationUserGuid	[UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	DELETE FROM [ui000]
	WHERE [UserGUID] = @DestinationUserGuid
	
	INSERT INTO [ui000] ([UserGUID], [ReportId], [SubId], [System], [PermType], [Permission])
	SELECT  @DestinationUserGuid,
			[ReportId],
			[SubId],
			[System],
			[PermType],
			[Permission]
	FROM [ui000]
	WHERE [UserGUID] = @SourceUserGuid
	
	DELETE FROM [rt000]
	WHERE [ChildGUID] = @DestinationUserGuid
	
	INSERT INTO [rt000] ([ChildGUID], [ParentGUID])
	SELECT  @DestinationUserGuid,
			[ParentGUID]
	FROM [rt000]
	WHERE [ChildGUID] = @SourceUserGuid
	
	UPDATE [us000] 
	SET [Dirty] = 1
	WHERE [GUID] = @DestinationUserGuid
	
##################################################################################
#END