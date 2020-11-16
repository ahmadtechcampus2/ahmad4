#########################################################
CREATE TRIGGER trg_billRelations000_CheckConstraints 
	ON [billRelations000] FOR INSERT, UPDATE 
	NOT FOR REPLICATION

AS  
/*  
This trigger checks:
	-if bill related to itselfe
	-if the guid pair don't exist  in same sort for example (item1, item2) , (item1, item2)  
	-if the guid pair don't exist  in different sort for example (item1, item2) , (item2, item1)
*/  
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON 

	DECLARE
		@BillGUID UNIQUEIDENTIFIER,
		@RelatedBillGuid UNIQUEIDENTIFIER

	SET @BillGUID = (SELECT[BillGUID] FROM [inserted] )
	SET @RelatedBillGuid = (SELECT[RelatedBillGuid] FROM [inserted])

	IF @BillGUID = @RelatedBillGuid
		insert into [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0001: Can''t insert relation,with itself'
	IF EXISTS( SELECT * FROM billRelations000  WHERE [RelatedBillGuid] = @BillGUID AND  [BillGUID] = @RelatedBillGuid)
		insert into [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0001: Can''t insert relation, its already related'
--#########################################################
--CREATE TRIGGER trg_billRelations000_delete
--	ON [billRelations000] FOR DELETE
--AS
--/* 
--This trigger: 
--	when delete (item1, item2) also delete (item2, item1)
--*/ 
--	IF @@ROWCOUNT = 0 RETURN 
--	SET NOCOUNT ON

--	DECLARE
--		@BillGUID UNIQUEIDENTIFIER,
--		@RelatedBillGuid UNIQUEIDENTIFIER

--	SET @BillGUID = (SELECT[BillGUID] FROM [deleted] )
--	SET @RelatedBillGuid = (SELECT[RelatedBillGuid] FROM [deleted])

--	DELETE[billRelations000] WHERE ([RelatedBillGuid] = @BillGUID) AND  ([BillGUID] = @RelatedBillGuid)
#########################################################
#END