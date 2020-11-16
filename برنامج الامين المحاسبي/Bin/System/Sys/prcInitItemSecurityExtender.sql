####################################################################################################################################
CREATE PROCEDURE prcItemSecurity_InstallTable
	@TableName [NVARCHAR] (128)
AS
	INSERT INTO [ist] ([Guid], [TableName])
		NewId(), @TableName
		
####################################################################################################################################
CREATE PROCEDURE prcInitItemSecurityExtender @Active INT = 1
AS
	EXECUTE [prcItemSecurity_InstallTable] 'ac'
	EXECUTE [prcItemSecurity_InstallTable] 'mt'
	EXECUTE [prcItemSecurity_InstallTable] 'gr'
	EXECUTE [prcItemSecurity_InstallTable] 'co'
	EXECUTE [prcItemSecurity_InstallTable] 'st'
	
	-------------------------------------------------------------------------
	-------------------------------------------------------------------------
	-- gr type = 1
	-- mt type = 2
	-- ac type = 3
	-- co type = 4
	-- st type = 5
	if( @Active = 1)
	begin
		---------------------------------------------------------------------------------------
		INSERT INTO [is000]( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4]) 
			SELECT [i].[guid], 1, 0, 0, 0, 0 
				FROM [gr000] [i] WHERE [Guid] NOT IN ( SELECT [ObjGuid] FROM [is000])
		---------------------------------------------------------------------------------------
		INSERT INTO [is000]( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4]) 
			SELECT [i].[guid], 2, 0, 0, 0, 0 
				FROM [mt000] [i] WHERE [Guid] NOT IN ( SELECT [ObjGuid] FROM [is000])
		---------------------------------------------------------------------------------------
		INSERT INTO [is000]( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4]) 
			SELECT [i].[guid], 3, 0, 0, 0, 0 
				FROM [ac000] [i] WHERE [Guid] NOT IN ( SELECT [ObjGuid] FROM [is000])
		---------------------------------------------------------------------------------------
		INSERT INTO [is000]( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4]) 
			SELECT [i].[guid], 4, 0, 0, 0, 0 
				FROM [co000] [i] WHERE [Guid] NOT IN ( SELECT [ObjGuid] FROM [is000])
		---------------------------------------------------------------------------------------
		INSERT INTO [is000]( [ObjGuid], [Type], [Mask1], [Mask2], [Mask3], [Mask4]) 
			SELECT [i].[guid], 5, 0, 0, 0, 0 
				FROM [st000] [i] where [Guid] not in ( select [ObjGuid] from [is000])
		---------------------------------------------------------------------------------------
	
		DECLARE @AdmMask1 BIGINT, @AdmMask2 BIGINT, @AdmMask3 BIGINT, @AdmMask4 BIGINT
	
		SELECT
			@AdmMask1 = SUM( CASE WHEN  u.Number between 0 and 64 	 THEN dbo.fnGetBranchMask( u.Number) 	  ELSE 0 END),
			@AdmMask2 = SUM( CASE WHEN  u.Number between 65 and 128  THEN dbo.fnGetBranchMask( u.Number - 64) ELSE 0 END),
			@AdmMask3 = SUM( CASE WHEN  u.Number between 129 and 192 THEN dbo.fnGetBranchMask( u.Number - 128)ELSE 0 END),
			@AdmMask4 = SUM( CASE WHEN  u.Number between 193 and 256 THEN dbo.fnGetBranchMask( u.Number - 192)ELSE 0 END)
		FROM
			us000 u
		WHERE
			u.bAdmin = 1 and Type = 0
	
		-------------------------------------------------------------------------	
		update iss set
			Mask1 = iss.Mask1 | @AdmMask1,
			Mask2 = iss.Mask2 | @AdmMask2, 
			Mask3 = iss.Mask3 | @AdmMask3,
			Mask4 = iss.Mask4 | @AdmMask4
		from
			is000 iss
		-------------------------------------------------------------------------	
		
		EXEC ('alter view vtGr as
			select x.* from 
				gr000 x inner join is000 i on x.guid = i.objGuid 
			where dbo.fnGetCurrentUserMask( i.Mask1, i.Mask2, i.Mask3, i.Mask4) != 0')

		EXEC ('alter view vtMt as
			select x.* from mt000 x 
				inner join is000 i on x.guid = i.objGuid
			where dbo.fnGetCurrentUserMask( i.Mask1, i.Mask2, i.Mask3, i.Mask4) != 0')

		EXEC ('alter view vtAc as
			select x.* from ac000 x 
				inner join is000 i on x.guid = i.objGuid
			where dbo.fnGetCurrentUserMask( i.Mask1, i.Mask2, i.Mask3, i.Mask4) != 0')
		
		EXEC ('alter view vtSt as
			select x.* from st000 x 
				inner join is000 i on x.guid = i.objGuid
			where dbo.fnGetCurrentUserMask( i.Mask1, i.Mask2, i.Mask3, i.Mask4) != 0')
	
		EXEC ('alter view vtCo as
			select x.* from co000 x 
				inner join is000 i on x.guid = i.objGuid
			where dbo.fnGetCurrentUserMask( i.Mask1, i.Mask2, i.Mask3, i.Mask4) != 0')
	
		
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_ac000_ItemSecurity')
			drop trigger trg_ac000_ItemSecurity
		
		EXEC ('
		CREATE TRIGGER trg_ac000_ItemSecurity ON ac000 FOR INSERT, DELETE
		NOT FOR REPLICATION
		AS
			delete i 
			FROM 
				is000 i 
				INNER JOIN deleted d ON i.objGuid = d.guid
				left JOIN inserted ins ON ins.Guid = d.guid
			where 
				ins.Guid is null
			
			if( @@rowcount != 0)
				return
		
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 3, i.Mask1, i.Mask2, i.Mask3, i.Mask4
				FROM
					inserted ins 
					inner join is000 i on i.objGuid = ins.parentGuid
			
			if( @@rowcount != 0)
				return
	
			DECLARE @AdmMask1 BIGINT, @AdmMask2 BIGINT, @AdmMask3 BIGINT, @AdmMask4 BIGINT
		
			SELECT
				@AdmMask1 = SUM( CASE WHEN  u.Number between 0   and 64   THEN dbo.fnGetBranchMask( u.Number	  ) ELSE 0 END),
				@AdmMask2 = SUM( CASE WHEN  u.Number between 65  and 128  THEN dbo.fnGetBranchMask( u.Number - 64 ) ELSE 0 END),
				@AdmMask3 = SUM( CASE WHEN  u.Number between 129 and 192  THEN dbo.fnGetBranchMask( u.Number - 128) ELSE 0 END),
				@AdmMask4 = SUM( CASE WHEN  u.Number between 193 and 256  THEN dbo.fnGetBranchMask( u.Number - 192) ELSE 0 END)
			FROM
				us000 u
			WHERE
				u.bAdmin = 1 and Type = 0
	
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 3, @AdmMask1, @AdmMask2, @AdmMask3, @AdmMask4
				FROM
					inserted ins 
				where 
					isnull( ins.parentGuid, 0x0) = 0x0')
		
		
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_mt000_ItemSecurity')
			drop trigger trg_mt000_ItemSecurity
	
		EXEC ('
		CREATE TRIGGER trg_mt000_ItemSecurity ON mt000 FOR INSERT, DELETE
		NOT FOR REPLICATION
		AS
			delete i 
			FROM 
				is000 i 
				INNER JOIN deleted d ON i.objGuid = d.guid
				left JOIN inserted ins ON ins.Guid = d.guid
			where 
				ins.Guid is null
			
			if( @@rowcount != 0)
				return
		
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 2, i.Mask1, i.Mask2, i.Mask3, i.Mask4
				FROM 
					inserted ins 
					inner join is000 i on i.objGuid = ins.GroupGuid')
		
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_gr000_ItemSecurity')
			drop trigger trg_gr000_ItemSecurity
		
		EXEC ('
		CREATE TRIGGER trg_gr000_ItemSecurity ON gr000 FOR INSERT, DELETE
		NOT FOR REPLICATION
		AS
			delete i 
			FROM 
				is000 i 
				INNER JOIN deleted d ON i.objGuid = d.guid
				left JOIN inserted ins ON ins.Guid = d.guid
			where 
				ins.Guid is null
			
			if( @@rowcount != 0)
				return
		
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 1, i.Mask1, i.Mask2, i.Mask3, i.Mask4
				FROM 
					inserted ins 
					inner join is000 i on i.objGuid = ins.parentGuid
			if( @@rowcount != 0)
				return
	
			DECLARE @AdmMask1 BIGINT, @AdmMask2 BIGINT, @AdmMask3 BIGINT, @AdmMask4 BIGINT
		
			SELECT
				@AdmMask1 = SUM( CASE WHEN  u.Number between 0 and 64 THEN dbo.fnGetBranchMask( u.Number) ELSE 0 END),
				@AdmMask2 = SUM( CASE WHEN  u.Number between 65 and 128 THEN dbo.fnGetBranchMask( u.Number - 64) ELSE 0 END),
				@AdmMask3 = SUM( CASE WHEN  u.Number between 129 and 192  THEN dbo.fnGetBranchMask( u.Number - 128) ELSE 0 END),
				@AdmMask4 = SUM( CASE WHEN  u.Number between 193 and 256  THEN dbo.fnGetBranchMask( u.Number - 192) ELSE 0 END)
			FROM
				us000 u
			WHERE
				u.bAdmin = 1 and Type = 0
	
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 1, @AdmMask1, @AdmMask2, @AdmMask3, @AdmMask4
				FROM
					inserted ins 
				where 
					isnull( ins.parentGuid, 0x0) = 0x0')
		
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_st000_ItemSecurity')
			drop trigger trg_st000_ItemSecurity
		
		EXEC ('
		CREATE TRIGGER trg_st000_ItemSecurity ON st000 FOR INSERT, DELETE
		NOT FOR REPLICATION
		AS
			delete i 
			FROM 
				is000 i 
				INNER JOIN deleted d ON i.objGuid = d.guid
				left JOIN inserted ins ON ins.Guid = d.guid
			where 
				ins.Guid is null
			
			if( @@rowcount != 0)
				return
		
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 5, i.Mask1, i.Mask2, i.Mask3, i.Mask4
				FROM 
					inserted ins 
					inner join is000 i on i.objGuid = ins.parentGuid
			if( @@rowcount != 0)
				return
	
			DECLARE @AdmMask1 BIGINT, @AdmMask2 BIGINT, @AdmMask3 BIGINT, @AdmMask4 BIGINT
		
			SELECT
				@AdmMask1 = SUM( CASE WHEN  u.Number between 0 and 64 THEN dbo.fnGetBranchMask( u.Number) ELSE 0 END),
				@AdmMask2 = SUM( CASE WHEN  u.Number between 65 and 128 THEN dbo.fnGetBranchMask( u.Number - 64) ELSE 0 END),
				@AdmMask3 = SUM( CASE WHEN  u.Number between 129 and 192  THEN dbo.fnGetBranchMask( u.Number - 128) ELSE 0 END),
				@AdmMask4 = SUM( CASE WHEN  u.Number between 193 and 256  THEN dbo.fnGetBranchMask( u.Number - 192) ELSE 0 END)
			FROM
				us000 u
			WHERE
				u.bAdmin = 1 and Type = 0
	
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 5, @AdmMask1, @AdmMask2, @AdmMask3, @AdmMask4
				FROM
					inserted ins 
				where 
					isnull( ins.parentGuid, 0x0) = 0x0')
		
		
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_co000_ItemSecurity')
			drop trigger trg_co000_ItemSecurity

		EXEC ('
		CREATE TRIGGER trg_co000_ItemSecurity ON co000 FOR INSERT, DELETE
		NOT FOR REPLICATION
		AS
			delete i 
			FROM 
				is000 i 
				INNER JOIN deleted d ON i.objGuid = d.guid
				left JOIN inserted ins ON ins.Guid = d.guid
			where 
				ins.Guid is null
			
			if( @@rowcount != 0)
				return
		
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 4, i.Mask1, i.Mask2, i.Mask3, i.Mask4
				FROM 
					inserted ins 
					inner join is000 i on i.objGuid = ins.parentGuid
			if( @@rowcount != 0)
				return
	
			DECLARE @AdmMask1 BIGINT, @AdmMask2 BIGINT, @AdmMask3 BIGINT, @AdmMask4 BIGINT
		
			SELECT
				@AdmMask1 = SUM( CASE WHEN  u.Number between 0 and 64 THEN dbo.fnGetBranchMask( u.Number) ELSE 0 END),
				@AdmMask2 = SUM( CASE WHEN  u.Number between 65 and 128 THEN dbo.fnGetBranchMask( u.Number - 64) ELSE 0 END),
				@AdmMask3 = SUM( CASE WHEN  u.Number between 129 and 192  THEN dbo.fnGetBranchMask( u.Number - 128) ELSE 0 END),
				@AdmMask4 = SUM( CASE WHEN  u.Number between 193 and 256  THEN dbo.fnGetBranchMask( u.Number - 192) ELSE 0 END)
			FROM
				us000 u
			WHERE
				u.bAdmin = 1 and Type = 0
	
			insert into is000 ( ObjGuid, Type, Mask1, Mask2, Mask3, Mask4)
				SELECT  ins.guid, 4, @AdmMask1, @AdmMask2, @AdmMask3, @AdmMask4
				FROM
					inserted ins 
				where
					isnull( ins.parentGuid, 0x0) = 0x0')
	end
	else -- @Active = 0
	begin
		EXEC ('alter view vtGr as select * from gr000')
		EXEC ('alter view vtMt as select * from mt000')
		EXEC ('alter view vtAc as select * from ac000')
		EXEC ('alter view vtSt as select * from st000')
		EXEC ('alter view vtCo as select * from co000')

		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_co000_ItemSecurity')
			drop trigger trg_co000_ItemSecurity
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_st000_ItemSecurity')
			drop trigger trg_st000_ItemSecurity
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_gr000_ItemSecurity')
			drop trigger trg_gr000_ItemSecurity
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_mt000_ItemSecurity')
			drop trigger trg_mt000_ItemSecurity
		if exists(select * from sysobjects where xtype = 'tr' and name = 'trg_ac000_ItemSecurity')
			drop trigger trg_ac000_ItemSecurity
	end
####################################################################################################################################
#END
