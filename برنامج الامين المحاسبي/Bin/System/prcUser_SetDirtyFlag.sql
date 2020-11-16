#########################################################
CREATE PROCEDURE prcUser_SetDirtyFlag 	
	@userGUID [UNIQUEIDENTIFIER] = NULL
AS
	IF @userGUID IS NULL
	BEGIN
		UPDATE [us000] SET [DIRTY] = 1 WHERE [Type] = 0 /*Users*/
		DELETE [UIX] FROM [UIX] LEFT JOIN [Connections] ON [UIX].[UserGuid] = [Connections].[UserGUID] WHERE [Connections].[UserGUID] IS NULL
	END ELSE
		UPDATE [us000] SET [DIRTY] = 1 WHERE @UserGUID = [GUID]	