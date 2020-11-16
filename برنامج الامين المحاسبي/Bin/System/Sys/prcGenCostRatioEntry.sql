################################################################################
##  Ê·Ìœ ”‰œ »‰”»… „—ﬂ“ «·ﬂ·›…
CREATE PROCEDURE prcGenCostRatioEntry
@entryTypeGuid  UNIQUEIDENTIFIER,  
	@DebitAccGuid UNIQUEIDENTIFIER,  
	@CreditAccGuid UNIQUEIDENTIFIER, 
	@DebitCostCenterGuid  UNIQUEIDENTIFIER,  
	@CreditCostCenterGuid  UNIQUEIDENTIFIER,  
	@costratio float,
	@Notes NVARCHAR(80)
AS  
	SET NOCOUNT ON 
	DECLARE
		@EntryGuid UNIQUEIDENTIFIER, 
		@CurrencyGuid  UNIQUEIDENTIFIER,
		@CurrencyVal float,
		@EntryNumber int,
		@PyNumber int,
		@coName NVARCHAR(150),
		@Date datetime = GETDATE(), @PostDate date =  '1905-06-02',@PyGuid UNIQUEIDENTIFIER
	  
	SET @coName = (select name from co000 where guid = @DebitCostCenterGuid)
	SET @Notes = @Notes +cast ((cast (@Date as DATE) )AS NVARCHAR (20))
	SET @EntryGuid = NEWID()
	IF(@entryTypeGuid <> 0x0)
		SET @PyGuid	   = NEWID() 
	ELSE 
		SET @PyGuid	   = 0x0 
	SELECT @EntryNumber = ISNULL(MAX(number), 0) + 1 FROM ce000	
	SELECT @PyNumber    = ISNULL(MAX(number), 0) + 1 FROM py000  
	SELECT  @CurrencyGuid = Guid, @CurrencyVal = CurrencyVal FROM my000 WHERE Number = 1  

	INSERT INTO ce000 (type, number, date, debit, credit, notes, guid, security, branch, currencyGuid, currencyval, isposted, PostDate)  
		VALUES (1, @EntryNumber, @Date, @costratio, @costratio, @Notes, @EntryGuid, 1, 0x0, @CurrencyGuid, 1, 0, @PostDate)
			  
	IF (@entryTypeGuid <> 0x0)
	BEGIN
		DECLARE @DefAccGUID UNIQUEIDENTIFIER = (SELECT  DefAccGUID  FROM et000 WHERE guid = @entryTypeGuid)

		INSERT INTO py000(Number, Date, Notes, currencyval, skip, Security, GUID, TypeGuid, AccountGUID, CurrencyGUID,BranchGuid)   
		VALUES(@PyNumber, @Date, @Notes, @currencyVal, 0, 1, @PyGuid, @entryTypeGuid, CASE @DefAccGUID WHEN 0X0 THEN 0X0 ELSE @DebitAccGuid END, @CurrencyGuid, 0x0)	
		    
		INSERT INTO er000(GUID, EntryGUID, ParentGUID, ParentType,ParentNumber)  
		VALUES(NEWID(), @EntryGuid, @PyGuid, 4, @PyNumber) 
	END

	SELECT @EntryGuid as EntryGuid
	IF @entryTypeGuid <> 0x0
		SELECT @PyGuid as PyGuid
################################################################################
## «÷«›… ﬁ·„ ·”‰œ „ Ê·œ  ·‰”»… „—ﬂ“ «·ﬂ·›…
CREATE PROCEDURE prcAddCostratioEntryToCe
@entryGuid  UNIQUEIDENTIFIER,  
	@DebitAccGuid UNIQUEIDENTIFIER,  
	@CreditAccGuid UNIQUEIDENTIFIER, 
	@DebitCostCenterGuid  UNIQUEIDENTIFIER,  
	@CreditCostCenterGuid  UNIQUEIDENTIFIER,  
	@costratio FLOAT,
	@Notes NVARCHAR(150)
AS  
	SET NOCOUNT ON 

	DECLARE 
			@CurrencyGuid  UNIQUEIDENTIFIER,
			@CurrencyVal float,
			@Date datetime = GETDATE(),
			@PostDate date =  '1905-06-02',
			@coName NVARCHAR(150),
			@coName1 NVARCHAR(150),
			@PyGuid UNIQUEIDENTIFIER,
			@Notes1 NVARCHAR(150)
			 
	SET @Notes1 = @Notes
	SET @coName = (select name from co000 where guid = @DebitCostCenterGuid)
	SET @coName1 = (select name from co000 where guid = @CreditCostCenterGuid)
	SET @Notes = @Notes + @coName +' '+cast ((cast (@Date as DATE) )AS NVARCHAR (20))
	SET @Notes1 = @Notes1 + @coName1 +' '+cast ((cast (@Date as DATE) )AS NVARCHAR (20))
	SELECT  @CurrencyGuid = Guid, @CurrencyVal = CurrencyVal FROM my000 WHERE Number = 1  
		
	INSERT INTO en000(Number, Date, Debit, Credit, Notes, GUID, currencyval, ParentGUID, AccountGUID, CurrencyGUID, CostGuid, ContraAccGUID)  
		VALUES(0, @Date, @costratio, 0, @Notes, NEWID(), @currencyVal, @EntryGuid, @DebitAccGuid, @CurrencyGuid,@DebitCostCenterGuid, @CreditAccGuid )  
		  
	INSERT INTO en000(Number, Date, Debit, Credit, Notes, GUID, currencyval, ParentGUID, AccountGUID, CurrencyGUID, CostGuid, ContraAccGUID)  
		VALUES(1, @Date, 0, @costratio, @Notes1, NEWID(), @currencyVal, @EntryGuid, @CreditAccGuid, @CurrencyGuid, @CreditCostCenterGuid, @DebitAccGuid)  
##################################################################################