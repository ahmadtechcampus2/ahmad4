################################################################################
CREATE TRIGGER trg_ms000_UpdateMTPreviousQty
	ON [dbo].[ms000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

		IF EXISTS(SELECT * FROM [deleted])
		BEGIN
			UPDATE MT 
				SET PrevQty = MT.Qty 
			FROM 
				mt000 AS MT
				INNER JOIN deleted AS d ON MT.GUID = d.MatGUID
		END
		ELSE
		BEGIN
			UPDATE MT 
				SET PrevQty = MT.Qty 
			FROM 
				mt000 AS MT
				INNER JOIN inserted AS d ON MT.GUID = d.MatGUID
		END
################################################################################
#END
