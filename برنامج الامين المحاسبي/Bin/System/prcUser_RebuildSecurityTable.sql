#########################################################
CREATE PROCEDURE prcUser_RebuildSecurityTable
	@userGUID [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON 
	DECLARE 
		@isAdmin [BIT], 
		@pessimisticSecurity [BIT], 
		@maxDiscount [FLOAT], 
		@minPrice [INT], 
		@bActive [BIT], 
		@branchReadMask [BIGINT], 
		@branchWriteMask [BIGINT], 
		@manufacBillGuid [uniqueidentifier],
		@maxPrice [INT]
	DECLARE 
		@c CURSOR, 
		@mask [BIGINT], 
		@permission [INT]
	
 	DECLARE @t_Roles TABLE([GUID] [UNIQUEIDENTIFIER]) 
	DECLARE @t_permissions TABLE([reportID] [BIGINT], [subID] [UNIQUEIDENTIFIER], [permType] [INT], [Permission] [INT], [system] [INT]) 
	INSERT INTO @t_Roles SELECT [GUID] FROM [dbo].[fnGetUserRolesList](@userGUID) 
	INSERT INTO @t_Roles SELECT @userGUID 
	-- get isAdmin: 
	IF EXISTS(SELECT * FROM @t_Roles AS [r] INNER JOIN [us000] AS [u] on [r].[GUID] = [u].[GUID] WHERE [bAdmin] = 1) 
		SET @isAdmin = 1 
	ELSE 
		SET @isAdmin = 0 
	-- get AmnCfg_PessimisticSecurity: 
	SET @pessimisticSecurity = [dbo].[fnOption_GetBit]('AmnCfg_PessimisticSecurity', DEFAULT) 
	-- prepare ui000 

	-- rebuild security items for in/ou bills for store transfer template
	DELETE [ui000]
	FROM 
		[ui000] [u] INNER JOIN [tt000] [t]
		ON [u].[subID] = [t].[inTypeGuid] 
	WHERE 
		[u].[UserGuid] = @userGUID
	
	-- this wil remove old values for inTypeGuids of tt 
	INSERT INTO [ui000] ([UserGuid], [ReportID], [SubID], [System], [PermType], [Permission]) 
			SELECT [UserGuid], [ReportID], t.[InTypeGuid], [System], [PermType], [Permission]
			FROM [ui000] [u] INNER JOIN [tt000] [t] ON [u].[subID] = [t].[OutTypeGuid]
			WHERE [u].[UserGuid] = @userGUID

	-- prepare usx and uix 
	DELETE [usx] WHERE [guid] = @userGUID 
	DELETE [uix] WHERE [userGUID] = @userGUID 
	-- check if user is Admin: 
	IF @isAdmin = 1 -- use is admin: 
	BEGIN 
		-- insert usx as admin: 
		INSERT INTO [usx] ([guid], [bAdmin], [maxDiscount], [minPrice], [bActive], [branchReadMask], [branchWriteMask], [maxPrice]) 
			SELECT @userGUID, @isAdmin, 0, 0, 1, 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF, 0 FROM [us000] WHERE [guid] = @userGUID 
		-- insert uix as admin: 
		INSERT INTO [uix] ([userGUID], [reportID], [subID])  
			SELECT @userGUID, 0, 0x0 
		-- insert all branches: 
		-- INSERT INTO uix( userGUID, reportID, subID, permType, Permission) SELECT @userGUID, CAST( 0x1001F000 AS BIGINT), GUID, 0, 1 FROM br000 
	END 
	ELSE BEGIN 
		INSERT INTO @t_permissions SELECT [reportID], [subID], [permType], [Permission], [System] FROM [ui000] AS [i] INNER JOIN @t_Roles AS [r] ON [i].[userGUID] = [r].[GUID] 
	--	INSERT INTO @t_permissions SELECT 1, 0x0, 1, MaxDiscount, 1 FROM @t_Roles AS r INNER JOIN us000 u ON r.GUID = u.GUID 
	--	INSERT INTO @t_permissions SELECT 1, 0x0, 2, MinPrice, 1 FROM @t_Roles AS r INNER JOIN us000 u ON r.GUID = u.GUID 
		 
		-- remove inheritors: 
		DELETE FROM @t_permissions WHERE [Permission] = -1 
		-- remove denyed: 
		DELETE [mstr]
			FROM @t_permissions [mstr] INNER JOIN @t_permissions [slv] ON 
				[mstr].[reportID] = [slv].[reportID] AND 
				[mstr].[subID] = [slv].[subID] AND 
				[mstr].[permType] = [slv].[permType] AND 
				[mstr].[System] = [slv].[system] 
			WHERE [mstr].[Permission] <> -2 AND [slv].[Permission] = -2 
		-- insert uix: 
		INSERT INTO [uix] ([userGUID], [reportID], [subID], [permType], [Permission], [System]) 
			SELECT @userGUID, [reportID], [subID], [permType], (CASE @pessimisticSecurity WHEN 1 THEN MIN([Permission]) ELSE MAX([Permission]) END), [System] 
			FROM @t_permissions 
			GROUP BY [reportID], [subID], [permType], [System] 
		-- now to usx: 
		SELECT 
			@maxDiscount =	CASE @pessimisticSecurity WHEN 1 THEN MIN([u].[maxDiscount])				ELSE MAX([u].[maxDiscount])			END, 
			@minPrice =		CASE @pessimisticSecurity WHEN 1 THEN MIN([u].[minPrice])					ELSE MAX([u].[minPrice])				END, 
			@bActive =			CASE @pessimisticSecurity WHEN 1 THEN MIN(CAST([u].[bActive] AS INT))	ELSE MAX(CAST([u].[bActive] AS INT))	END,
			@maxPrice =		CASE @pessimisticSecurity WHEN 1 THEN MIN([u].[maxPrice])					ELSE MAX([u].[maxPrice])				END 
		FROM @t_Roles AS r INNER JOIN [us000] AS [u] on [r].[GUID] = [u].[GUID] 
		-- calc branch Read and Write masks: 
		IF [dbo].[fnOption_getBit]('EnableBranches', 0) = 0 
			SELECT 
				@branchReadMask = 0xFFFFFFFFFFFFFFFF, 
				@branchWriteMask = 0xFFFFFFFFFFFFFFFF 
		ELSE BEGIN	 
			-- get the branchRead and branchWrite masks: 
			-- remove denied: 
			DELETE @t_permissions FROM @t_permissions [p] INNER JOIN [br000] [b] ON [p].[subid] = [b].[guid] WHERE [p].[permission]  = -2 
			-- add 0: 
			-- INSERT INTO @t_permissions (reportID, subID, permType, Permission, [System]) SELECT 0x1001F000, guid, 0, 0, 1 FROM br000 
			-- select * FROM @t_permissions p INNER JOIN br000 b ON p.subid = b.guid 
			-- select @pessimisticSecurity 
			SET @c = CURSOR FAST_FORWARD FOR 
						SELECT DISTINCT [b].[branchMask], CASE @pessimisticSecurity WHEN 1 THEN MIN([p].[permission]) ELSE MAX([p].[permission]) END 
						FROM @t_permissions AS [p] INNER JOIN [vtbr] AS [b] ON [p].[subID] = [b].[GUID] 
						GROUP BY [b].[BranchMask], [p].[reportID], [p].[subID], [p].[permType], [System] 
			-- permission from cursor is either 1 or 2 for sure: 
			OPEN @c FETCH FROM @c INTO @mask, @permission 
			SET @branchReadMask = 0 
			SET @branchWriteMask = 0 
			WHILE @@FETCH_STATUS = 0 
			BEGIN 
				IF @permission >= 1 
				BEGIN 
					SET @branchReadMask = @branchReadMask | @mask 
					IF @permission = 2 -- write enabled: 
						SET @branchWriteMask = @branchWriteMask | @mask 
				END 
				FETCH FROM @c INTO @mask, @permission 
			END 
			CLOSE @c DEALLOCATE @c 
		END 
		INSERT INTO [usx] ([guid], [bAdmin], [maxDiscount], [minPrice], [bActive], [branchReadMask], [branchWriteMask], [maxPrice]) 
			SELECT @userGUID, @isAdmin, @maxDiscount, @minPrice, @bActive, @branchReadMask, @branchWriteMask, @maxPrice FROM [us000] WHERE [guid] = @userGUID 
	END -- ELSE 
		UPDATE [us000] SET [Dirty] = 0 WHERE [GUID] = @UserGUID
