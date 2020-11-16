#########################################################
CREATE  TRIGGER trg_as000_CheckConstraints ON [as000] FOR DELETE
AS
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  
	IF (
		EXISTS(SELECT * FROM [ad000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[parentGUID] = [d].[GUID] 
											INNER JOIN dd000 dd on dd.AdGuid = a.Guid) 
		Or
		EXISTS(SELECT * FROM [ad000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[parentGUID] = [d].[GUID] 
											INNER JOIN ax000 ax on ax.AdGuid = a.Guid)
		) 

		INSERT INTO [ErrorLog] 
			([level], [type], [c1]) 
		SELECT 
			1, 0, 'AmnE0120: Can''t delete asset(s), details found depending' 

	ELSE
	DELETE ad000 FROM ad000 ad INNER JOIN [deleted] [d] ON [d].[guid] = [ad].[parentGuid]
#########################################################
CREATE TRIGGER trg_as000_useFlag
	ON [as000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION

AS 
/* 
This trigger: 
  - updates UseFlag of concerned accounts. 
  - deletes related records: ax 
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	IF EXISTS(SELECT * FROM [deleted]) 
	BEGIN 
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[AccGUID] 
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DepAccGUID] 
		UPDATE [ac000] SET [UseFlag] = [UseFlag]- 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[AccuDepAccGUID] 
		IF NOT EXISTS (SELECT * FROM [inserted]) 
			DELETE [ax000] FROM [ax000] INNER JOIN [deleted] ON [ax000].[GUID] = [deleted].[GUID] 
	END 

	IF EXISTS(SELECT * FROM [inserted]) 
	BEGIN 
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[AccGUID] 
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DepAccGUID] 
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[AccuDepAccGUID] 
	END 

#########################################################
#END