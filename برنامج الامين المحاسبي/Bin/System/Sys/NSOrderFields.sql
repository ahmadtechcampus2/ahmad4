################################################################################
CREATE FUNCTION NSFnOrderInfo(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
returns @OrderInfo table 
(
		AADATE						DATE,
		AccountNumber				NVARCHAR(100),
		ADDATE						DATE,
		APDATE						DATE,
		ArrivalPosition				NVARCHAR(100),
		ASDATE						DATE,
		Bank						NVARCHAR(100),
		CreditNumber				NVARCHAR(100),
		DeliveryConditions			NVARCHAR(100),
		ExpectedDate				DATE,
		FDATE						DATE,
		ORDERSHIPCONDITION			NVARCHAR(100),
		PTDate						DATE,
		PTOrderDate					DATETIME,
		SADATE						DATE,
		SDDATE						DATE,
		ShippingCompany				NVARCHAR(100),
		ShippingType				NVARCHAR(100),
		SPDATE						DATE,
		SSDATE						DATE,
		Branch						NVARCHAR(50)
)
AS 
BEGIN
	INSERT INTO @OrderInfo
	SELECT 
	 o.AADATE,
	 o.AccountNumber,
	 o.ADDATE,
	 o.APDATE ,
	 o.ArrivalPosition,
	 o.ASDATE,
	 o.Bank,
	 o.CreditNumber,
	 o.DeliveryConditions,
	 o.ExpectedDate ,
	 o.FDATE,
	 o.ORDERSHIPCONDITION,
	 o.PTDate,
	 o.PTOrderDate,
	 o.SADATE,
	 o.SDDATE,
	 o.ShippingCompany,
	 o.ShippingType,
	 o.SPDATE,
	 o.SSDATE,
	 br.brName

	FROM vwOrderInformation o
	left JOIN vwOrders ord ON ord.Guid = o.ParentGuid
	left JOIN vwbu bu ON (bu.buNumber = ord.BuNumber and bu.buType=ord.BtGuid)
	left JOIN vwbr br ON br.brGUID = bu.buBranch   
	WHERE buGUID = @ObjectGuid
	RETURN
end
################################################################################
CREATE FUNCTION NSFnOrderDueDateInfo(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
returns @OrderInfo table 
(
		PaymentDate					DATE,
		PaymentNumber				INT,
		PaymentValue				FLOAT
)
AS 
BEGIN
		DECLARE @eventConditonGuid UNIQUEIDENTIFIER = (SELECT EventConditionGuid FROM NSMessage000 WHERE Guid = @messageGuid)
		DECLARE @beforeDays INT =  (SELECT DC.BeforeDays from NSScheduleEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid)

		INSERT INTO @OrderInfo
		SELECT 
			[DueDate],
			[Number], 
			[Remainder]
			
		FROM fnGetOrdersDueDates()
		WHERE [ParentGuid] = @ObjectGuid
		and DATEDIFF(day, DueDate, GETDATE()) = -1 * @beforeDays
		RETURN
END
################################################################################
#END