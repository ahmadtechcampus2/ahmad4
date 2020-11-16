#################################################
CREATE  proc prcHosGenPayEntry 
	@FileGuid UNIQUEIDENTIFIER,
	@TypeGuid UNIQUEIDENTIFIER,
	@pay float,
	@CurrencyGuid UNIQUEIDENTIFIER,
	@CurrencyVal float,
	@DepitAcc UNIQUEIDENTIFIER,
	@Date	 DateTime,
	@sec	 int,
	@notes  NVarchar(511)	
	
AS 
	SET NOCOUNT ON  
	Declare @entryGUID	UNIQUEIDENTIFIER, 
			@payGuid  	UNIQUEIDENTIFIER, 
			@EntryNum 	INT, 
			@PayNumber	INT,	 
			@Branch		UNIQUEIDENTIFIER,  
			@FileAcc	UNIQUEIDENTIFIER,   
			@FileCost 	UNIQUEIDENTIFIER   
	SELECT  
		@Branch = Branch  
	FROM hospfile000 
	WHERE GUID = @FileGuid 
	 
	IF (@Branch IS NULL ) 
		SET @Branch = 0X0 
		 
	set @entryGUID = NewID() 
	SET @entryNum =  [dbo].[fnEntry_getNewNum](@Branch) --(@BranchGUID)      
	Set @payGuid = NEWID() 
	SELECT @PayNumber = ISNULL(Max(Number) + 1, 1) FROM Py000  where typeGUID = @TypeGuid 
	SELECT   
		@FileAcc = AccGUID,  
		@FileCost = CostGuid  
	from HosPfile000 
	where guid = @FileGuid 
	 
	insert INTO py000 
			([Number],[Date],[Notes], [Guid], [typeGUID],[AccountGuid],  
			 [CurrencyGUID], [CurrencyVal],  
			 [Security], [BranchGuid])  
		select 
			@PayNumber, 
			@Date, 
			@notes  ,   
			@payGuid, 
			@TypeGuid, 
			@depitAcc, 
			@CurrencyGuid, 
			@CurrencyVal, 
			@sec, 
			@Branch 
	 
	INSERT INTO [er000]   
		SELECT    
		newID(),   
		@entryGUID,  
		@payGuid,  
		4,   
		@PayNumber  
 	 
 		 
	INSERT INTO [ce000]   
	    	([typeGUID], [Type],  [Number], [Date],[PostDate], [Debit],   
		 [Credit], [Notes], [CurrencyVal], [IsPosted],   
		 [Security], [Branch],[GUID], [CurrencyGUID])     
	select  
		0x0,   
		1,   
		@entryNum,   
		@Date, 
		@Date,  
		@pay,  
		@pay,  
		@notes  ,   
		@CurrencyVal,  
		0,  
		@sec,--security,   
		@Branch,  
		@entryGUID,  
		@CurrencyGuid   
			  
	INSERT INTO [en000]   
	  
		 ([Number],   
		 [Date],   
		 [Debit],   
		 [Credit],   
		 [Notes],   
		 [CurrencyVal],   
		 [ParentGUID],  
		 [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID] )  
	select    
		0,     
		@Date,     
		@pay,     
		0,     
		@notes  ,   
		@CurrencyVal,     
		@entryGUID,     
		@DepitAcc,     
		@CurrencyGuid ,  
		@FileCost,     
		@Fileacc   
	INSERT INTO [en000]  
		([Number],   
		 [Date],   
		 [Debit],   
		 [Credit],   
		 [Notes],  
		 [CurrencyVal], [ParentGUID], [accountGUID],   
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])     
	select 
		1,       
		@Date,     
		0,       
		@pay,       
		@notes  ,   
		@CurrencyVal,       
		@entryGUID,       
		@Fileacc,     
		@CurrencyGuid,       
		@FileCost,       
		@DepitAcc    

	INSERT INTO er000(entryguid, parentguid, ParentType) values (@payGuid, @FileGuid, 305)			 
	
	CREATE TABLE #PostedTbl (CeGUID UNIQUEIDENTIFIER, IsPosted INT)

	INSERT INTO #PostedTbl 
	SELECT 
		ce.GUID, 
		et.bAutoPost   
	FROM 
		et000 AS et  
		INNER JOIN py000 AS py ON et.GUID = py.TypeGUID 
		INNER JOIN er000 AS er ON er.ParentGUID = py.GUID 
		INNER JOIN ce000 AS ce ON ce.GUID = er.EntryGUID 
	WHERE 
		ce.GUID = @entryGUID
	
	UPDATE ce000   
	SET IsPosted = pTbl.IsPosted 
	FROM 
		#PostedTbl AS pTbl , ce000 as ce 
	WHERE 
		ce.GUID = pTbl.CeGUID 
#################################################
#END