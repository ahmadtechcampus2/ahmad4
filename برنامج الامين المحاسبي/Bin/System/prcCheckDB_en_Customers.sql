############################################################################################
CREATE PROCEDURE prcCheckDB_en_Customers
	@Correct [INT] = 0
AS

	IF @Correct <> 1
	BEGIN 
		-- no customer in en0000 
		INSERT INTO [ErrorLog]([Type], [g1])
		SELECT 0x616, [en].[ParentGUID]
		FROM 
			[en000] AS [en] 
			INNER JOIN [ac000] AS [ac] ON [ac].[GUID] = [en].[AccountGUID]
		WHERE ISNULL(en.CustomerGUID, 0x0) = 0x0 AND EXISTS(SELECT * FROM cu000 WHERE AccountGUID = ac.GUID)

		-- customer not related to account 
		INSERT INTO [ErrorLog]([Type], [g1])
		SELECT 0x617, [en].[ParentGUID]
		FROM 
			[en000] AS [en] 
			INNER JOIN [ac000] AS [ac] ON [ac].[GUID] = [en].[AccountGUID]
		WHERE 
			ISNULL(en.CustomerGUID, 0x0) != 0x0 
			AND EXISTS(SELECT * FROM cu000 WHERE AccountGUID = ac.GUID)
			AND NOT EXISTS(SELECT * FROM cu000 WHERE GUID = en.CustomerGUID AND AccountGUID = ac.GUID)
	END 

	IF @Correct <> 0
	BEGIN
		DECLARE @cnt INT 
		SET @cnt = 0

		EXEC prcDisableTriggers 'en000'

		UPDATE en000 
		SET CustomerGUID = cu.GUID
		FROM 
			en000 en 
			INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
			INNER JOIN 
			(SELECT a.GUID FROM ac000 a INNER JOIN cu000 cu ON a.GUID = cu.AccountGUID GROUP BY a.GUID HAVING COUNT(*) = 1) fn ON fn.GUID = ac.GUID
			INNER JOIN cu000 cu ON fn.GUID = cu.AccountGUID
		WHERE 
			en.CustomerGUID = 0x0
		SET @cnt = @@ROWCOUNT

		UPDATE en000 
		SET CustomerGUID = cu.GUID
		FROM 
			en000 en 
			INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
			INNER JOIN 
			(SELECT a.GUID FROM ac000 a INNER JOIN cu000 cu ON a.GUID = cu.AccountGUID GROUP BY a.GUID HAVING COUNT(*) = 1) fn ON fn.GUID = ac.GUID
			INNER JOIN cu000 cu ON fn.GUID = cu.AccountGUID
		WHERE 
			en.CustomerGUID != cu.GUID 
		SET @cnt = @@ROWCOUNT + @cnt

		EXEC prcEnableTriggers 'en000'

		IF @cnt > 0
			EXEC prcEntry_rePost 
		
	END
############################################################################################
#END
