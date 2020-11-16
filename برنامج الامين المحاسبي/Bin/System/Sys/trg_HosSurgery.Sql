#########################################################
CREATE TRIGGER trg_HosSurgery_Delete ON hosFSurgery000 FOR DELETE
 NOT FOR REPLICATION
As
SET NOCOUNT ON 
	DECLARE	@G 					UniqueIdentifier,
			@SBG 				UniqueIdentifier,
			@PBG 				UniqueIdentifier,
			@RoomCostEntry		UniqueIdentifier,
			@WorkersEntry		UniqueIdentifier,
			@AnesthetistEntry	UniqueIdentifier

	--SELECT * from HosFSurgery000

	SELECT
			@G = Guid ,
			@SBG = SurgeryBillGUID,
			@PBG = PatientBillGuid,
			@RoomCostEntry	= 	RoomCostEntryGuid,
			@WorkersEntry	= 	WorkersEntryGuid,
			@AnesthetistEntry = AnesthetistEntryGuid
	FROM deleted

DELETE FROM  HosSurgeryMat000		WHERE ParentGUID  = @G
DELETE FROM  HosSurgeryWorker000 	WHERE ParentGUID  = @G

DELETE FROM  BillRel000 WHERE BillGUID = @SBG
DELETE FROM  BillRel000 WHERE BillGUID = @PBG

EXEC prcEntry_delete 	@RoomCostEntry
EXEC prcEntry_delete 	@WorkersEntry
EXEC prcEntry_delete 	@AnesthetistEntry
#########################################################
CREATE TRIGGER trg_HosCons_Delete ON hosCons000 FOR DELETE
NOT FOR REPLICATION
As
SET NOCOUNT ON 
delete er000 
	FROM [deleted] d inner join er000 er ON d.Guid = er.parentGuid	
#########################################################
CREATE TRIGGER trg_HosConsumedMaster_Delete ON HosConsumedMaster000 FOR DELETE
NOT FOR REPLICATION
As
SET NOCOUNT ON 
	declare @billGuid uniqueidentifier
	SELECT @billGuid = BillGuid FROM [deleted]
	UPDATE bu000 SET IsPosted = 0 WHERE [Guid] = @billGuid
	DELETE bu000
	WHERE [Guid] = @billGuid 
#########################################################
CREATE TRIGGER trg_HosStay_Delete ON hosstay000 FOR DELETE
NOT FOR REPLICATION
As
SET NOCOUNT ON 
	DELETE ER
	FROM
		er000 AS ER
		JOIN DELETED AS D ON ER.ParentGUID = D.[GUID]
#########################################################
CREATE TRIGGER trg_HosGeneralTest_Delete ON hosGeneralTest000 FOR DELETE
NOT FOR REPLICATION
AS
	SET NOCOUNT ON;
	DELETE ER
	FROM
		er000 AS ER
		JOIN deleted AS D ON ER.ParentGUID = D.[GUID];
#########################################################
CREATE TRIGGER trg_HospFile_Delete ON hosPFile000 FOR DELETE
NOT FOR REPLICATION
As
	SET NOCOUNT ON 
	
	DECLARE @fileGuid uniqueidentifier
	SELECT @fileGuid = [guid] FROM [deleted]
	
	UPDATE bu000 SET IsPosted = 0 WHERE GUID IN (SELECT SurgeryBillGuid FROM HosFSurgery000 WHERE fileGuid = @fileGuid)
	DELETE FROM bu000 WHERE GUID IN (SELECT SurgeryBillGuid FROM HosFSurgery000 WHERE fileGuid = @fileGuid)
	UPDATE bu000 SET IsPosted = 0 WHERE GUID IN (SELECT PatientBillGuid FROM HosFSurgery000 WHERE fileGuid = @fileGuid)
	DELETE FROM bu000 WHERE GUID IN (SELECT PatientBillGuid FROM HosFSurgery000 WHERE fileGuid = @fileGuid)
	UPDATE bu000 SET IsPosted = 0 WHERE GUID IN (SELECT BillGuid FROM hosConsumedMaster000 WHERE fileGuid = @fileGuid)
	DELETE FROM bu000 WHERE GUID IN (SELECT BillGuid FROM hosConsumedMaster000 WHERE fileGuid = @fileGuid)

	DELETE hosclinicaltests000 WHERE fileGuid = @fileGuid
	DELETE hosstay000 WHERE fileGuid = @fileGuid
	DELETE hosGeneralTest000 WHERE fileGuid = @fileGuid
	DELETE hosFSurgery000 WHERE fileGuid = @fileGuid
	DELETE hosCons000 WHERE fileGuid = @fileGuid
	DELETE hosFDailyFollowing000 WHERE fileGuid = @fileGuid
	DELETE hosConsumed000 WHERE fileGuid = @fileGuid
	DELETE hosConsumedMaster000 WHERE fileGuid = @fileGuid
	
	SELECT 
		EntryGuid AS pyGuid
	INTO #pys
	FROM er000 AS er
	INNER JOIN [deleted] AS d ON d.Guid = er.ParentGuid
	INNER JOIN Py000 AS py ON py.Guid = er.EntryGuid
	WHERE er.ParentType = 305
	
	DELETE er000
	FROM er000 AS er
	INNER JOIN #pys AS p ON p.pyGuid = er.ParentGuid 
	
	
	DELETE er000
	FROM er000 AS er
	INNER JOIN #pys AS p ON p.pyGuid = er.EntryGuid
	
	DELETE py000 WHERE [GUID] IN (SELECT * FROM #pys)
	
	DELETE er000
	WHERE parentGuid = @fileGuid

	DELETE hosPatientAccounts000 WHERE PatientGuid = @fileGuid
#########################################################
#END