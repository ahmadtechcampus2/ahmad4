################################################################################
CREATE TRIGGER trg_OrAddInfo000_delete
ON orAddInfo000 FOR DELETE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN	
	SET NOCOUNT ON

	DELETE bp
	FROM 
		bp000 bp
		LEFT JOIN OrderPayments000 p ON p.[GUID] = [bp].[DebtGUID] OR p.[GUID] = [bp].[PAYGUID] 
		INNER JOIN deleted d ON (p.BillGuid = d.ParentGuid AND d.PTType = 3) OR (d.GUID = [bp].[DebtGUID] OR d.GUID = [bp].[PAYGUID])

	DELETE p  
	FROM 
		OrderPayments000 p 
		INNER JOIN deleted d ON p.BillGuid = d.ParentGuid 
################################################################################
CREATE TRIGGER trg_OrAddInfo000_Update
ON orAddInfo000 FOR UPDATE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN	
	SET NOCOUNT ON

   IF EXISTS(SELECT * FROM bu000 bu INNER JOIN inserted i ON bu.GUID = i.ParentGuid WHERE bu.PayType = 1 )
   BEGIN
	   IF UPDATE([SSDATE]) OR UPDATE([SADATE]) OR UPDATE([SDDATE]) OR UPDATE([ASDATE]) OR UPDATE([AADATE]) OR UPDATE([ADDATE]) OR UPDATE([FDATE]) OR UPDATE([ExpectedDate])
		  OR UPDATE([SPDATE]) OR UPDATE([APDATE])
		BEGIN
		UPDATE OrderPayments000 SET PayDate = CASE i.PTType
												WHEN 1 THEN DATEADD(DAY, i.[PTDaysCount], dbo.fnGetOrderDate(i.GUID, i.PTOrderDate))
												WHEN 2 THEN i.PTDate
												WHEN 3 THEN p.PayDate
												ELSE [dbo].fnGetOrderDate(i.GUID, i.PTOrderDate)
											  END 
		FROM 
			inserted i
			INNER JOIN OrderPayments000 p ON p.BillGuid = i.ParentGuid
		END 
	END
################################################################################
#END
