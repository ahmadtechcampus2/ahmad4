#########################################################
CREATE TRIGGER trg_ax000_CheckConstraints
	ON [ax000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to use main CostJobs.						(AmnE0181)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- study a case when using main CostJobs (NSons <> 0):
--	IF EXISTS(SELECT * FROM inserted AS i INNER JOIN co000 AS c ON i.CostGuid = c.Guid INNER JOIN co000 AS c2 ON c.Guid = c2.ParentGuid)
		-- insert into ErrorLog (level, type, c1) select 1, 0, 'AmnE0181: Can''t use main CostJobs'
#########################################################
CREATE TRIGGER trg_ax000_useFlag
	ON [ax000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION

AS 

/* 
This trigger: 
  - updates UseFlag of ad000. 
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	 
	IF EXISTS(SELECT * FROM [deleted]) 
	BEGIN 
			UPDATE [ad000] SET [UseFlag] = [UseFlag] - 1 FROM [ad000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[ADGUID]
	END 
	 
	IF EXISTS(SELECT * FROM [inserted]) 
	BEGIN 
			UPDATE [ad000] SET [UseFlag] = [UseFlag] + 1 FROM [ad000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[ADGUID] 
	END 
#########################################################
CREATE TRIGGER trg_ax000_general ON [ax000] FOR INSERT, DELETE
	NOT FOR REPLICATION

AS 
	SET NOCOUNT ON  
	 
	DECLARE 
		@c CURSOR, 
		@GUID			[UNIQUEIDENTIFIER], 
		@entryTypeGUID	[UNIQUEIDENTIFIER], 
		@entryGUID		[UNIQUEIDENTIFIER], 
		@entryNum		[INT], 
		@isInsert		[BIT] 
	SET @c = CURSOR FAST_FORWARD FOR  
					SELECT [GUID], [entryTypeGUID], [entryGUID], [entryNum], 0 AS [state] FROM [deleted] 
					UNION ALL 
					SELECT [GUID], [entryTypeGUID], [entryGUID], [entryNum], 1 FROM [inserted] 
					ORDER BY [state] 
	OPEN @c FETCH FROM @c INTO @GUID, @entryTypeGUID, @entryGUID, @entryNum, @isInsert 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 		
		IF @isInsert = 1 
			EXEC [prcAX_genEntry] @GUID
		ELSE 
			EXEC [prcAX_DeleteEntry] @entryGUID 
		FETCH FROM @c INTO @GUID, @entryTypeGUID, @entryGUID, @entryNum, @isInsert 
	END 
	CLOSE @c DEALLOCATE @c 	
#########################################################
#END