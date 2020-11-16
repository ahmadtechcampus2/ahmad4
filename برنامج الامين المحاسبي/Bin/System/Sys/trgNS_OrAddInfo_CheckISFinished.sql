################################################################################
CREATE TRIGGER trg_OrAddInfo000_NSCheckISFinished
ON [ORADDINFO000] AFTER UPDATE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON
	IF NOT(UPDATE([Finished]))
		RETURN 
	DECLARE @objectGuid [UNIQUEIDENTIFIER] = (SELECT TOP 1 parentguid From [inserted])
	
	-- Finished = 1 represent finish manual or by dividing 
	-- Finished = 2 represent finish by Post all order
	IF((SELECT TOP 1 [Finished] FROM [inserted]) = 1 or (SELECT TOP 1 [Finished] FROM [inserted]) = 2 )

	-- ObjectID 1 represent to Order
	-- EventID -5 represent to finished event
	EXEC NSPrcObjectEvent  @objectGuid,1,-5
################################################################################
#END
