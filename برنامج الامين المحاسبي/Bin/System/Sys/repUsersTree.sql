##########################################################################
CREATE PROCEDURE repUsersTree
AS 
	SET NOCOUNT ON 
	CREATE TABLE [#Result]
	( 
		[Guid]	[UNIQUEIDENTIFIER], 
		[Name]	[NVARCHAR](250) COLLATE ARABIC_CI_AI
	)

	INSERT INTO [#Result]  
		SELECT [usGUID], [usLoginName]	FROM [vwus]	WHERE [usType] = 1
	UNION ALL 
		SELECT 0x0, ''

	SELECT * FROM [#Result] ORDER BY [Name]

#############################################################################3
CREATE PROCEDURE repGetUsersList
	@RoleGUID [UNIQUEIDENTIFIER] = 0x0
AS 
	SET NOCOUNT ON 
	set @RoleGUID = ISNULL( @RoleGUID, 0x0)

	CREATE TABLE [#Result]
	( 
		[Guid]		[UNIQUEIDENTIFIER], 
		[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[bAdmin]	[BIT]
	) 
	 
	IF @RoleGUID != 0x0 
	BEGIN 
		INSERT INTO [#Result]  
		SELECT  
			[us].[usGUID],
			[us].[usLoginName],
			0
		FROM 
			[vwus] [us]
			INNER JOIN [rt000] [rt] ON [rt].[ChildGUID] = [us].[usGUID]
			INNER JOIN [vwus] [r] ON [rt].[ParentGUID] = [r].[usGUID]
		WHERE 
			[r].[usGUID] = @RoleGUID AND [us].[usType] = 0
			
		INSERT INTO [#Result]  
		SELECT  
			[us].[usGUID],
			[us].[usLoginName],
			1
		FROM 
			[vwus] [us]
		WHERE 
			[usType] = 0
			AND 
			[usbAdmin] = 1
		
	END ELSE BEGIN 

		INSERT INTO [#Result]
		SELECT  
			[us].[usGUID],
			[us].[usLoginName],
			0
		FROM 
			[vwus] [us]
			LEFT JOIN [rt000] [rt] ON [rt].[ChildGUID] = [us].[usGUID]
		WHERE 
			[rt].[GUID] IS NULL
			AND 
			[usType] = 0
			AND 
			[usbAdmin] = 0
	END 

	SELECT * FROM [#Result] ORDER BY [bAdmin] DESC, [Name]
#############################################################################3
#END