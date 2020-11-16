#########################################################
CREATE TRIGGER trg_assetExcludeDetails000_useFlag
	ON [assetExcludeDetails000] FOR INSERT, UPDATE, DELETE 
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
			UPDATE [ad000] SET [UseFlag] = [UseFlag] - 1 FROM [ad000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[adGuid]
	END 
	 
	IF EXISTS(SELECT * FROM [inserted]) 
	BEGIN 
			UPDATE [ad000] SET [UseFlag] = [UseFlag] + 1 FROM [ad000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[adGuid] 
	END 
#########################################################
#END