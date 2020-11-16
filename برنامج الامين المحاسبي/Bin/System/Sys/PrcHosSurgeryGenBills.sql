#########################################
create  PROC PrcHosSurgeryGenOneBill
	@SurgeryGuid UNIQUEIDENTIFIER, 
	@Type int --- 1 patient , 2 surgery 
AS 
	DECLARE @BillTypeGuid UNIQUEIDENTIFIER, 
		@DefStoreGuid	UNIQUEIDENTIFIER, 
		@FileAccGuid	UNIQUEIDENTIFIER, 
		@CostGuid		UNIQUEIDENTIFIER, 
		@FileGuid		UNIQUEIDENTIFIER, 
		@NOTES			NVARCHAR(250),  
		@BillNumber		BIGINT,	 -- —ﬁ„ «·›« Ê—…
		@BillDate		DATETIME,	 -- —ﬁ„ «·›« Ê—…
		@CurrencyGuid	UNIQUEIDENTIFIER, -- «·⁄„·… 
		@CustomerGuid	UNIQUEIDENTIFIER, --  «·“»Ê‰
		@DefBillAccGuid UNIQUEIDENTIFIER,
		@CurrencyVal	INT, --
		@Security		int,
		@Branch			UNIQUEIDENTIFIER	
		
	SELECT  @CurrencyGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 WHERE Name = 'AmnCfg_DefaultCurrency'
	SET 	@CurrencyVal  = 1 --  ⁄«œ· «·⁄„·…

  	if (@type  = 1)
	BEGIN
		SELECT  @BillTypeGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 
		WHERE	Name = 'HosCfg_Patient_BillType'
		set	@Notes = '„” Â·ﬂ«  «·„—Ì÷ '	
	END

	else
	BEGIN
  		SELECT  @BillTypeGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 
		WHERE	Name = 'HosCfg_Surgery_BillType'
		set	@Notes = '„” Â·ﬂ«  «·⁄„·Ì… '
	END	

		SELECT  @DefStoreGuid = DefStoreGuid, @DefBillAccGuid = DefBillAccGuid -- Õ”«» «·„Ê«œ
		FROM  bt000 WHERE Guid = @BillTypeGuid


	SELECT	@CostGuid = CostGuid,  -- „—ﬂ“ «·ﬂ·›… 
		@BillDate = dbo.GetJustDate(BeginDate),
		@FileAccGuid = AccGuid, 
		@FileGuid = F.Guid,
		@Security = s.security,
		@CustomerGuid = CustomerGuid, -- «·⁄„Ì·
		@Notes = op.[name]  +' '+ @Notes +  '  «·„—Ì÷: ' + f.Code + F.[Name],
		@Branch = f.Branch
	FROM vwhosfsurgery  as s
		INNER JOIN VwHosOperation as op on op.guid = s.operationguid
		INNER JOIN vwhosfile as f on S.FileGUID = f.Guid 
		WHERE s.GUID = @SurgeryGuid

		SELECT @BillNumber =  ISNULL(MAX(Number), 0 ) + 1 from bu000 where  TypeGuid = @BillTypeGuid 
		print @BillNumber
		DECLARE @NewBillGuid   UNIQUEIDENTIFIER
		SET @NewBillGuid = NEWID()
	
		update hosSurgerymat000
		set storeguid = @DefStoreGuid
		where StoreGuid = 0x0 AND ParentGuid = @SurgeryGuid 	
		
		INSERT INTO Bu000 (Guid, number, [Date], CurrencyVal, Notes, PayType, Security, 
				   TypeGuid, CustGuid, CurrencyGuid, CustAccGuid, StoreGuid, branch)

		VALUES (@NewBillGuid, @BillNumber, @BillDate, @CurrencyVal, @Notes, 1, @security,
			@BillTypeGuid, @CustomerGuid, @CurrencyGuid, @FileAccGuid, @DefStoreGuid, @Branch)


			INSERT  INTO Bi000 
				(Qty, 
					Unity, 
					Price, 
					CurrencyGuid, 
					CurrencyVal, 
					Notes, 
					StoreGuid, 
					ParentGuid, 
					CostGuid, 
					MatGuid
				)
			SELECT  		
					sm.qty,
					sm.Unity, 
					sm.price,
					@CurrencyGuid, 
					@CurrencyVal, 
				 	@Notes + ' «· «—ÌŒ: '+ Cast(@BillDate AS NVARCHAR(250)), 
					--@DefStoreGuid, 
					sm.StoreGuid,
					@NewBillGuid, 
					@CostGuid, 
					MatGuid
			FROM hosSurgerymat000 as sm
			INNER JOIN mt000 as mt on mt.Guid = sm.MatGuid
			where parentguid = @surgeryguid and sm.type = @type	

			exec  prcBill_genEntry @NewBillGuid
			--exec prcBill_post @NewBillGuid, 1
			update bu000 
			set IsPosted = 1	
			where guid = @newbillguid 

	if (@type  = 1)
		UPDATE HosFSurgery000
		Set PatientBillGuid = @newBillGuid
		where guid = @SurgeryGuid
	else
		UPDATE HosFSurgery000
		set SurgeryBillGuid = @newBillGuid
		where guid = 	@SurgeryGuid

	insert into BILLREL000
	values (newid(), 5, @newbillguid, @FileGuid, 1) 
#########################################
create proc PrcHosSurgeryGenBills
	@SurgeryGuid UNIQUEIDENTIFIER
AS
if exists  (select top 1 guid from HosSurgeryMat000 where parentGuid = @SurgeryGuid And type = 1)
		exec PrcHosSurgeryGenOneBill @SurgeryGuid, 1
if exists  (select top 1 guid from HosSurgeryMat000 where parentGuid = @SurgeryGuid And type = 2)
	exec PrcHosSurgeryGenOneBill @SurgeryGuid, 2
	
#########################################
create  PROC PrcHosGenConsumedBill
	@ConsumedMasterGuid UNIQUEIDENTIFIER
AS 
	DECLARE @BillTypeGuid UNIQUEIDENTIFIER, 
		@DefStoreGuid UNIQUEIDENTIFIER, 
		@FileAccGuid UNIQUEIDENTIFIER, 
		@CostGuid  UNIQUEIDENTIFIER, 
		@FileGuid UNIQUEIDENTIFIER, 
		@NOTES  NVARCHAR(250),  
		@BillNumber BIGINT,	 -- —ﬁ„ «·›« Ê—…
		@BillDate DATETIME,	 -- —ﬁ„ «·›« Ê—…
		@CurrencyGuid  UNIQUEIDENTIFIER, -- «·⁄„·… 
		@CustomerGuid  UNIQUEIDENTIFIER, --  «·“»Ê‰
		@DefBillAccGuid UNIQUEIDENTIFIER,
		@CurrencyVal  INT, --
		@Security int,
		@SmallNotes NVARCHAR(100)


	SELECT  @CurrencyGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 WHERE Name = 'AmnCfg_DefaultCurrency'
	SET 	@CurrencyVal  = 1 --  ⁄«œ· «·⁄„·…

	SELECT  @BillTypeGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 
	WHERE	Name = 'HosCfg_Consumed_BillType'

	DECLARE	@StrToAddItToNote  NVARCHAR(100)
	SET @StrToAddItToNote = [dbo].[fnStrings_get]('HOSPITAL\CONSUMABLES', DEFAULT) 


	SELECT  @DefStoreGuid = DefStoreGuid, @DefBillAccGuid = DefBillAccGuid -- Õ”«» «·„Ê«œ
	FROM  bt000 WHERE Guid = @BillTypeGuid


	SELECT	@CostGuid = CostGuid,  -- „—ﬂ“ «·ﬂ·›… 
		@BillDate = dbo.GetJustDate([Date]),
		@FileAccGuid = AccGuid, 
		@FileGuid = F.Guid,
		@Security = master.security,
		@CustomerGuid = f.CustomerGuid, -- «·⁄„Ì·
		@SmallNotes = @StrToAddItToNote + F.Code + '-'+ F.[Name],
		@Notes = @StrToAddItToNote + F.Code + '-'+ F.[Name] + ' ' + master.notes,
		@security = MASTER.security	
	FROM HosConsumedMaster000  as master
	INNER JOIN HosConsumed000 as c on c.parentguid = master.guid
	INNER JOIN vwhosfile as f on master.FileGUID = f.Guid
	--INNER JOIN CU000 AS CU ON cu.accountguid = F.accguid
	WHERE master.GUID = @ConsumedMasterGuid

	SELECT	@CostGuid, 
		@BillDate, 
		@FileAccGuid,
		@FileGuid, 
		@Security, 
		@CustomerGuid, 
		@Notes

	SELECT @BillNumber =  ISNULL(MAX(Number), 0 ) + 1 from bu000 where  TypeGuid = @BillTypeGuid 
	--print @BillNumber

	DECLARE @NewBillGuid   UNIQUEIDENTIFIER
	SET @NewBillGuid = NEWID()

	INSERT INTO Bu000 (Guid, number, [Date], CurrencyVal, Notes, PayType, Security, 
			   TypeGuid, CustGuid, CurrencyGuid, CustAccGuid, StoreGuid)

	VALUES (@NewBillGuid, @BillNumber, @BillDate, @CurrencyVal, @Notes, 1, @security,
		@BillTypeGuid, @CustomerGuid, @CurrencyGuid, @FileAccGuid, @DefStoreGuid)

	declare @Smallest int 

	select 	@Smallest = min(number)
			from HosConsumed000 
			where ParentGuid = @ConsumedMasterGuid 

	update HosConsumed000
	set storeguid = @DefStoreGuid
	where StoreGuid = 0x0 AND ParentGuid = @ConsumedMasterGuid 	

	INSERT  INTO Bi000 
			(Number,
			Qty, 
			Unity, 
			Price, 
			CurrencyGuid, 
			CurrencyVal, 
			Notes, 
			StoreGuid, 
			ParentGuid, 
			CostGuid, 
			MatGuid
			)
	SELECT  	
			c.number - @Smallest,
			c.qty,
			c.Unity, 
			c.price,
			@CurrencyGuid, 
			@CurrencyVal, 
		 	@SmallNotes,
			c.StoreGuid, 
			@NewBillGuid, 
			@CostGuid, 
			c.MatGuid 
	FROM HosConsumed000 as c
	INNER JOIN mt000 as mt on mt.Guid = c.MatGuid
	where parentguid = @ConsumedMasterGuid
	order by c.number 

	exec  prcBill_genEntry @NewBillGuid
	--exec prcBill_post @NewBillGuid, 1
	update bu000 
	set IsPosted = 1	
	where guid = @newbillguid 
	
	
	UPDATE HosConsumedMaster000 
	SET BillGuid = @newbillguid
	where guid = @ConsumedMasterGuid 
##################################################################################
#END	
	