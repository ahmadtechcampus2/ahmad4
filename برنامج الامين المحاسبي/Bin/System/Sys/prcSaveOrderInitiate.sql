############################################################## 
CREATE PROC prcSaveOrderInitiate
	@BuGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON;
	DECLARE @buDate DATETIME 
	DECLARE @buPayType INT
	SELECT @buDate = Date , @buPayType = PayType FROM bu000 WHERE GUID = @BuGuid
	IF EXISTS (
			    SELECT TypeGUID FROM bu000 bu 
				INNER JOIN bt000  bt ON bt.GUID = bu.TypeGUID
				WHERE 
					bu.GUID = @BuGuid
					AND (bt.Type = 5 OR bt.Type = 6 ))
	BEGIN
		-- insert general order info
		INSERT INTO [dbo].[ORADDINFO000]
		       ([GUID]
		       ,[ParentGuid]
		       ,[ORDERSHIPCONDITION]
		       ,[SADATE]
		       ,[SDDATE]
		       ,[SPDATE]
		       ,[SSDATE]
		       ,[AADATE]
		       ,[ADDATE]
		       ,[APDATE]
		       ,[ASDATE]
		       ,[Finished]
		       ,[Add1]
		       ,[Add2]
		       ,[Add3]
		       ,[Add4]
		       ,[PTType]
			   ,[PTOrderDate]
		       ,[PTDaysCount]
		       ,[ShippingType]
		       ,[ShippingCompany]
		       ,[DeliveryConditions]
		       ,[ArrivalPosition]
		       ,[Bank]
		       ,[AccountNumber]
		       ,[CreditNumber]
		       ,[ExpectedDate])
		 VALUES
		       (
			   NEWID()
		       ,@BuGuid
		       ,''
		       ,@buDate
		       ,@buDate
		       ,@buDate
		       ,@buDate
		       ,@buDate
		       ,@buDate
		       ,@buDate
		       ,@buDate
		       ,0
		       ,0
		       ,CASE WHEN @buPayType =1 THEN 0 ELSE 2 END 
		       ,''
		       ,''
		       ,0
			   ,CASE WHEN @buPayType =1 THEN 5 ELSE 0 END 
		       ,0
		       ,''
		       ,''
		       ,''
		       ,''
		       ,''
		       ,''
		       ,''
		       ,@buDate)
		
		-- insert order post info
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
		
		-- insert order payments
		IF (@buPayType = 1)
		BEGIN
			INSERT INTO OrderPayments000
					([GUID]
					  ,[BillGuid]
					  ,[Number]
					  ,[PayDate]
					  ,[Value]
					  ,[Percentage]
					  ,[UpdatedValue])
			SELECT 
					NEWID()
					,@BuGuid
					,1
					,bu.Date
					,bu.Total
					,100
					,bu.Total
			FROM 
				bu000 bu
			WHERE 
				bu.GUID = @BuGuid
		END
		
		-- insert order approvals
		EXEC prcOrder_ResetApprovals @BuGuid
	END
#################################################################
#END     