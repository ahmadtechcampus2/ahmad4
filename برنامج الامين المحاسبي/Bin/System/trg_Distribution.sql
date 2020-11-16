#########################################################
CREATE TRIGGER trg_DistDisc000_CheckConstraints
	ON [DistDisc000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION 
AS 
/* 
This trigger checks: 
	- not to delete used DistDisc000
*/
	return
#########################################################
CREATE TRIGGER trg_DistDisc000_DeleteDistDiscDistributor000
	ON [DistDisc000] FOR DELETE 
	NOT FOR REPLICATION
AS 
/*  
This trigger delete:  
	- the records in DistDiscDistributor000 that related to discounts in DistDisc000 
*/ 
	DECLARE @DiscGuid UNIQUEIDENTIFIER
	SELECT @DiscGuid = Guid FROM deleted
	DELETE FROM DistDiscDistributor000 WHERE ParentGuid = @DiscGuid
#########################################################
CREATE TRIGGER trg_DistCt000_CheckConstraints
	ON [DistCt000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger checks: 
	- not to delete used DistCt000
*/
	declare @t table([g] [uniqueidentifier]) 
	--study a case when deleting used accounts: 
	IF NOT EXISTS(SELECT * FROM [inserted]) AND EXISTS(SELECT * FROM [deleted]) 
	begin 
		delete @t 
		insert into @t select [guid] from [deleted] where [dbo].[fnDistCt_IsUsed]([guid]) != 0
		IF @@rowcount != 0 
			insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0050: Can''t delete DistCustType, it''s being used...', [g] from @t
	end 
#########################################################
CREATE TRIGGER trg_DistTch000_CheckConstraints
	ON [DistTch000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger checks: 
	- not to delete used DistTch000
*/
	declare @t table([g] [uniqueidentifier]) 
	--study a case when deleting used accounts: 
	IF NOT EXISTS(SELECT * FROM [inserted]) AND EXISTS(SELECT * FROM [deleted]) 
	begin 
		delete @t 
		insert into @t select [guid] from [deleted] where [dbo].[fnDistTch_IsUsed]([guid]) != 0
		IF @@rowcount != 0 
			insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0050: Can''t delete DistTradeChannel, it''s being used...', [g] from @t
	end 
#########################################################	
CREATE TRIGGER trg_DistCt_Delete ON DistCt000 FOR DELETE 
NOT FOR REPLICATION
AS 
	-- DELETE FROM DistCtd000 WHERE ParentGuid in (SELECT Guid FROM DELETED) 
	DELETE DistCtd000 
		FROM DistCtd000 AS ctd INNER JOIN deleted AS d ON ctd.ParentGuid = d.Guid
#########################################################	
CREATE TRIGGER trg_DistTr_Delete ON DistTr000 FOR DELETE 
NOT FOR REPLICATION
AS 
	DELETE DistVi000 
		FROM DistVi000 AS vi INNER JOIN deleted AS d ON vi.TripGuid = d.Guid
#########################################################	
CREATE TRIGGER trg_DistVi_Delete ON DistVi000 FOR DELETE 
NOT FOR REPLICATION
AS 
	DELETE DistVd000 
		FROM DistVd000 AS vd INNER JOIN deleted AS d ON vd.VistGuid = d.Guid
#########################################################	
CREATE TRIGGER trg_Distributor_Delete ON Distributor000 FOR DELETE 
NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0
		RETURN
	
	SET NOCOUNT ON

	IF EXISTS ( SELECT * FROM DistDistributionLines000 WHERE DistGuid IN (SELECT Guid FROM deleted))
	OR EXISTS ( SELECT * FROM DistDiscDistributor000 WHERE DistGuid IN (SELECT Guid FROM deleted))
	OR EXISTS ( SELECT * FROM DistDistributorTarget000 WHERE DistGuid IN (SELECT Guid FROM deleted))
	OR EXISTS ( SELECT * FROM DistPromotionsBudget000 WHERE DistributorGuid IN (SELECT Guid FROM deleted))
	OR EXISTS ( SELECT * FROM DistTR000 WHERE DistributorGUID IN (SELECT Guid FROM deleted))
		INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0601: Can''t Delete Used Distributor'
	ELSE
		DELETE FROM DistDd000 WHERE DistributorGuid IN (SELECT Guid FROM DELETED )
	
#########################################################	
CREATE  TRIGGER trg_DistDistMatTemplates_Delete ON DistMatTemplates000 FOR DELETE 
AS 
	IF @@ROWCOUNT = 0 RETURN    
	SET NOCOUNT ON    
	DECLARE @Used INT 
	SET @Used = 0	    

	IF EXISTS ( SELECT * FROM DistCC000 WHERE MatTemplateGuid IN (SELECT Guid FROM deleted)) 
		SET @Used = 1
	IF EXISTS ( SELECT * FROM DistCustClassesTarget000 WHERE MatTemplateGuid  IN (SELECT Guid FROM deleted)) 
		SET @Used = 1

	IF (@Used = 1) 
		INSERT INTO [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0602: Can''t Delete Used Mat Template'   
#########################################################	
CREATE  TRIGGER trg_DistCustClasses_Delete ON DistCustClasses000 FOR DELETE 
AS 
	IF @@ROWCOUNT = 0 RETURN    
	SET NOCOUNT ON    
	DECLARE @Used INT 
	SET @Used = 0	    

	IF EXISTS ( SELECT * FROM DistCC000 WHERE CustClassGuid IN (SELECT Guid FROM deleted)) 
		SET @Used = 1
	IF EXISTS ( SELECT * FROM DistCustClassesTarget000 WHERE CustClassGuid IN (SELECT Guid FROM deleted)) 
		SET @Used = 1

	IF (@Used = 1) 
		INSERT INTO [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0602: Can''t Delete Used Cust Class'   
#########################################################	
CREATE TRIGGER trg_DistGeneralTarget_Delete ON DisGeneralTarget000 FOR DELETE 
NOT FOR REPLICATION
AS 
	DELETE DisTchTarget000 
		FROM DisTchTarget000 AS tch INNER JOIN deleted AS d ON tch.PeriodGuid = d.PeriodGuid AND tch.BranchGuid = d.BranchGuid
#########################################################
CREATE TRIGGER trg_DistQuestionnaire000_DeleteDistQuestQuestion000
	ON [DistQuestionnaire000] FOR DELETE 
	NOT FOR REPLICATION
AS 
/*  
This trigger delete:  
	- the records in DistQuestQuestion000 that related to questionnaire in DistQuestionnaire000 
*/ 
	DELETE FROM DistQuestQuestion000 WHERE ParentGuid IN (SELECT Guid FROM deleted)
#########################################################
CREATE TRIGGER trg_DistQuestQuestion000_DeleteDistQuestChoices000
	ON [DistQuestQuestion000] FOR DELETE 
	NOT FOR REPLICATION
AS 
/*  
This trigger delete:  
	- the records in DistQuestChoices000 that related to questions in DistQuestQuestion000 
*/ 
	DELETE FROM DistQuestChoices000 WHERE ParentGuid IN (SELECT Guid FROM deleted)
#########################################################
CREATE TRIGGER trg_DistRequiredMaterials000_DeleteDistReqMatsDetails000
	ON [DistRequiredMaterials000] FOR DELETE 
	NOT FOR REPLICATION
AS 
/*  
This trigger delete:  
	- the records in DistReqMatsDetails000 that related to the master record in DistRequiredMaterials000 
*/ 
	DELETE FROM DistReqMatsDetails000 WHERE ParentGuid IN (SELECT Guid FROM deleted)
#########################################################	
#END