##################################################################################
CREATE TRIGGER  trg_bu000_DeleteOrderLinks
ON [bu000] FOR DELETE  
NOT FOR REPLICATION 
AS    
/*   
THIS TRIGGER IS AUTO Delete records OF ori000 which INNER JOIN ori000 ON  
bu000.Guid = ori000.buGUID. for posted Qty to bill  
bu000.Guid = ori000.PoGUID. for join with orders System   
*/  
IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1     
	RETURN      
SET NOCOUNT ON    
DECLARE @Type INT  , 
	@buGuid  [UNIQUEIDENTIFIER]  
SET @buGuid = (SELECT Guid from DELETED) 	 
SET @Type = (SELECT Type FROM bt000 INNER JOIN DELETED ON bt000.Guid = DELETED.TypeGuid ) 
if (@Type = 5 OR @Type = 6) 
BEGIN 
		 
	DELETE ori000 WHERE PoGuid = @buGuid  
	DELETE PPI000 WHERE SOGuid = @buGuid	 
END
--ELSE 
--BEGIN 
--	IF EXISTS(SELECT buGuid FROM ori000 WHERE buGuid = @buGuid)
--	BEGIN			
--		UPDATE ORADDINFO000 
--		SET Finished = 0
--		WHERE ParentGuid IN (SELECT  POGuid from ori000 WHERE buGuid = @buGuid )
--		DELETE FROM ori000 WHERE buGuid = @buGuid		
--	END
--END
##################################################################################
CREATE TRIGGER trg_ppo000_delete
ON [ppo000] FOR DELETE
NOT FOR REPLICATION
AS 
/* 
This trigger: 
	- deletes related records: ppo000
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 	 
	-- deleting related data ppi000: 
	DELETE [ppi000] FROM [ppi000] INNER JOIN [deleted] ON [ppi000].[PPoGUID] = [deleted].[GUID]
##################################################################################
CREATE TRIGGER trg_ppi000_delete
	ON [ppi000] FOR DELETE  
	NOT FOR REPLICATION
AS   
/*   
This trigger:   
	- deletes related records: ppo000  
*/   
	IF @@ROWCOUNT = 0 OR @@ROWCOUNT > 1
		RETURN   
	SET NOCOUNT ON  	   
	-- deleting related data ppo000:
	DELETE ppo000 
	FROM 
		deleted d 
		INNER JOIN ppo000 ppo ON ppo.guid = d.PPoGUID
		LEFT JOIN ppi000 ppi ON ppo.guid = ppi.PPoGUID
	WHERE 
		ppi.guid IS NULL 
##################################################################################
CREATE TRIGGER  trg_ori000_SetSequanceOrderNumber
	ON [ori000] FOR INSERT
	NOT FOR REPLICATION
AS   
/*  
THIS TRIGGER IS AUTO numbering records OF ori000 which INNER JOIN bi000 ON 
bi000.Guid = ori000.POIGUID. for posted Qty from state to sate
*/ 
IF @@ROWCOUNT = 0 or @@ROWCOUNT > 1    
	RETURN     
SET NOCOUNT ON   

DECLARE @Number INT  ,
	@biGuid  [UNIQUEIDENTIFIER] ,
	@Guid [UNIQUEIDENTIFIER] 
SET @Number = (SELECT Number FROM INSERTED )
IF(@Number > 0)
BEGIN
	SET @biGuid = (SELECT POIGuid from INSERTED) 	
	SET @Guid = (SELECT Guid from INSERTED) 
	SET @Number = (SELECT MAX (Number) FROM ori000 WHERE POIGuid = @biGuid)
	UPDATE ori000
	SET Number = @Number + 1 
	WHERE Guid = @Guid
END
##################################################################################
#END