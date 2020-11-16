#####################################################
CREATE PROC prcSaveOrderInitiateInfo
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
           ,CASE WHEN @buPayType =0 THEN 2 ELSE 0 END 
           ,''
           ,''
           ,0
           ,0
           ,''
           ,''
           ,''
           ,''
           ,''
           ,''
           ,''
           ,@buDate)
	END
###########################################################################
#END