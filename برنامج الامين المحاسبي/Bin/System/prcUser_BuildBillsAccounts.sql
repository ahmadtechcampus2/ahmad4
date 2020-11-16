#########################################################
CREATE PROC prcUser_BuildBillAccounts 
	@userGUID [UNIQUEIDENTIFIER] 
AS 
	DECLARE @t TABLE( 
		[billTypeGUID] [UNIQUEIDENTIFIER], 
		[matAccGUID] [UNIQUEIDENTIFIER], 
		[discAccGUID] [UNIQUEIDENTIFIER], 
		[extraAccGUID] [UNIQUEIDENTIFIER], 
		[VATAccGUID] [UNIQUEIDENTIFIER], 
		[storeAccGUID] [UNIQUEIDENTIFIER], 
		[costAccGUID] [UNIQUEIDENTIFIER],
		[bonusAccGUID] [UNIQUEIDENTIFIER],
		[bonusContraAccGUID] [UNIQUEIDENTIFIER])


	EXEC prcDisableTriggers 'ma000'

	-- prepare roles: 
	INSERT INTO @t 
		SELECT 
			[billTypeGUID], 
			[matAccGUID], 
			[discAccGUID], 
			[extraAccGUID], 
			[VATAccGUID], 
			[storeAccGUID], 
			[costAccGUID], 
			[bonusAccGUID],
			[bonusContraAccGUID]
		FROM [ma000] AS [m] INNER JOIN [fnGetUserRolesList](@userGUID) AS [f] ON [m].[objGUID] = [f].[GUID]

	-- delete current data 
	DELETE FROM [ma000] WHERE [type] = 5 AND [objGUID] = @userGUID 
	
	-- insert data from bt 
	INSERT INTO [ma000] ([type], [objGUID], [billTypeGUID], [matAccGUID], [discAccGUID], [extraAccGUID], [VATAccGUID], [storeAccGUID], [costAccGUID], [bonusAccGUID], [bonusContraAccGUID]) 
		SELECT 5, @userGUID, GUID, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
		FROM [bt000]

	--IF EXISTS (SELECT * FROM [ma000] WHERE [type] = 3)
	--BEGIN	
		-- update data from user roles: 
		IF (SELECT COUNT(*) FROM @t WHERE [matAccGUID] <> 0x0) = 1 
			UPDATE [ma000] SET [matAccGUID] = [t].[matAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [t] ON [m].[billTypeGUID] = [t].[billTypeGUID] 
					WHERE [m].[objGUID] = @userGUID AND [m].[Type] = 5 AND [matAccGUID] <> 0x0 

		IF (SELECT COUNT(*) FROM @t WHERE [discAccGUID] <> 0x0) = 1 
			UPDATE [ma000] SET [discAccGUID] = [t].[discAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [t] ON [m].[billTypeGUID] = [t].[billTypeGUID] 
					WHERE [m].[objGUID] = @userGUID AND [m].[Type] = 5 AND [discAccGUID] <> 0x0 
		 
		IF (SELECT COUNT(*) FROM @t WHERE [extraAccGUID] <> 0x0) = 1 
			UPDATE [ma000] SET [extraAccGUID] = [t].[extraAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [t] ON [m].[billTypeGUID] = [t].[billTypeGUID] 
					WHERE [m].[objGUID] = @userGUID AND [m].[Type] = 5 AND [extraAccGUID] <> 0x0 
		 
		IF (SELECT COUNT(*) FROM @t WHERE [VATAccGUID] <> 0x0) = 1 
			UPDATE [ma000] SET [VATAccGUID] = [t].[VATAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [t] ON [m].[billTypeGUID] = [t].[billTypeGUID] 
					WHERE [m].[objGUID] = @userGUID AND [m].[Type] = 5 AND [VATAccGUID] <> 0x0 
		 
		IF (SELECT COUNT(*) FROM @t WHERE [storeAccGUID] <> 0x0) = 1 
			UPDATE [ma000] SET [storeAccGUID] = [t].[storeAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [t] ON [m].[billTypeGUID] = [t].[billTypeGUID] 
					WHERE [m].[objGUID] = @userGUID AND [m].[Type] = 5 AND [storeAccGUID] <> 0x0 
		 
		IF (SELECT COUNT(*) FROM @t WHERE [costAccGUID] <> 0x0) = 1 
			UPDATE [ma000] SET [costAccGUID] = [t].[costAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [t] ON [m].[billTypeGUID] = [t].[billTypeGUID] 
					WHERE [m].[objGUID] = @userGUID AND [m].[Type] = 5 AND [costAccGUID] <> 0x0 
	--END
	
	--IF EXISTS (SELECT * FROM [ma000] WHERE [type] = 4)
	--BEGIN	
		-- update from user ma 
		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [matAccGUID] <> 0x0) 
			UPDATE [m] SET [matAccGUID] = [u].[matAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[matAccGUID] <> 0x0 
		 
		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [discAccGUID] <> 0x0) 
			UPDATE [m] SET [discAccGUID] = [u].[discAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[discAccGUID] <> 0x0 
		 
		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [extraAccGUID] <> 0x0) 
			UPDATE [m] SET [extraAccGUID] = [u].[extraAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[extraAccGUID] <> 0x0 
		 
		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [VATAccGUID] <> 0x0) 
			UPDATE [m] SET [VATAccGUID] = [u].[VATAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[VATAccGUID] <> 0x0 
		 
		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [storeAccGUID] <> 0x0) 
			UPDATE [m] SET [storeAccGUID] = [u].[storeAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[storeAccGUID] <> 0x0 
		 
		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [costAccGUID] <> 0x0) 
			UPDATE [m] SET [costAccGUID] = [u].[costAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[costAccGUID] <> 0x0 

		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [bonusAccGUID] <> 0x0) 
			UPDATE [m] SET [bonusAccGUID] = [u].[bonusAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[bonusAccGUID] <> 0x0 

		IF EXISTS(SELECT * FROM [ma000] WHERE [type] = 3 AND [objGUID] = @userGUID AND [bonusContraAccGUID] <> 0x0) 
			UPDATE [m] SET [bonusContraAccGUID] = [u].[bonusContraAccGUID] 
				FROM [ma000] AS [m] INNER JOIN [ma000] AS [u] ON [m].[billTypeGUID] = [u].[billTypeGUID] AND [m].[objGUID] = [u].[objGUID] 
				WHERE [m].[objGUID] = @userGUID AND [m].[type] = 5 AND [u].[type] = 3 AND [u].[bonusContraAccGUID] <> 0x0 
	--END
	ALTER TABLE [ma000] ENABLE TRIGGER ALL

#########################################################
#END