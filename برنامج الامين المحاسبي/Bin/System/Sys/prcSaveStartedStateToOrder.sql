#####################################################
CREATE PROC prcSaveStartedStateToOrder
	@BuGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON;

	DELETE FROM Ori000 WHERE Number = 0 AND POGuid = @BuGuid
	DECLARE @postGuid UNIQUEIDENTIFIER = NEWID()
	DECLARE @typeGuid UNIQUEIDENTIFIER =
					(
					SELECT 
						oit.GUID
						FROM oit000 oit
						INNER JOIN OITVS000 oitv ON oit.GUID = oitv.ParentGuid
						WHERE oitv.OTGUID = (SELECT TypeGUID FROM bu000 WHERE GUID = @BuGuid)
						AND oitv.StateOrder = 0
					)

	IF EXISTS (
			    SELECT TypeGUID FROM bu000 bu 
				INNER JOIN bt000  bt ON bt.GUID = bu.TypeGUID
				WHERE 
					bu.GUID = @BuGuid
					AND (bt.Type = 5 OR bt.Type = 6 ))
	BEGIN
		INSERT INTO ori000
		       ([Number]
		       ,[GUID]
		       ,[POIGUID]
		       ,[Qty]
		       ,[Type]
		       ,[Date]
		       ,[Notes]
		       ,[POGUID]
		       ,[BuGuid]
		       ,[TypeGuid]
		       ,[BonusPostedQty]
		       ,[bIsRecycled]
		       ,[PostGuid]
		       ,[PostNumber]
		       ,[BiGuid])

		SELECT 
			   0
			   ,NEWID()
			   ,bi.GUID
			   ,bi.Qty
			   ,0
			   ,bu.Date
			   ,bi.Notes
			   ,@BuGuid
			   ,0x0
			   ,@typeGuid
			   ,0
		       ,0
		       ,@postGuid
		       ,0
		       ,0x0

		FROM 
			bi000 bi 
			LEFT JOIN bu000 bu ON bi.ParentGUID = bu.GUID
		WHERE 
			bu.GUID = @BuGuid
   
   END
###########################################################################
#END