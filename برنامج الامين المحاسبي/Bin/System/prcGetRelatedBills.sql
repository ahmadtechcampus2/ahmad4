###########################
CREATE PROCEDURE prcGetRelatedBills 
	@BillGuid UNIQUEIDENTIFIER  
AS
	SET NOCOUNT ON
	
	CREATE TABLE #Result(
		[buGuid] UNIQUEIDENTIFIER, 
		buNumber INT, 
		buDate DATETIME,
		[Security] INT, 
		[UserSecurity] INT,
		[UserReadPriceSecurity] INT,
		btName NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		btGuid UNIQUEIDENTIFIER,
		CustomerName NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		BranchName NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		BranchGuid UNIQUEIDENTIFIER,
		buTotal FLOAT,
		IsRefundFromBill BIT)
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpostedSecurity] [INTEGER]) 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2]
	CREATE TABLE #RelatedBill([Guid] [UNIQUEIDENTIFIER], IsRefundFromBill BIT)
	INSERT INTO  #RelatedBill
	SELECT
		[BillGuid],
		IsRefundFromBill
	FROM 
		BillRelations000 
	WHERE 
		RelatedBillGuid = @BillGuid 
	INSERT INTO  #RelatedBill
	SELECT 
		[RelatedBillGuid] ,
		IsRefundFromBill
	FROM 
		BillRelations000
	WHERE 
		billguid = @BillGuid
	DECLARE @lang INT
	SET @lang = dbo.fnConnections_GetLanguage()
	INSERT INTO #Result
	SELECT 
		[bu].buGuid,
		[bu].buNumber,
		[bu].buDate,
		[bu].buSecurity,
		src.UserSecurity,
		src.[UserReadPriceSecurity],
		CASE @lang
			WHEN 0 THEN bt.btName 
			ELSE (CASE bt.btLatinName WHEN '' THEN bt.btName ELSE bt.btLatinName END)
		END, 
		bt.btGuid,
		bu.buCust_Name,
		CASE 
			WHEN br.brGuid IS NULL THEN ''
			ELSE 
				(CASE @lang
					WHEN 0 THEN br.brName 
					ELSE (CASE br.brLatinName WHEN '' THEN br.brName ELSE br.brLatinName END)
				END)
		END,
		ISNULL(br.brGuid, 0x0),
		bu.buTotal ,
		rb.IsRefundFromBill
	FROM 
		vwbu bu 
		INNER JOIN #RelatedBill rb ON bu.buGUID = rb.GUID
		INNER JOIN vwbt bt ON bt.btGUID = bu.buType
		INNER JOIN [#BillsTypesTbl] src ON src.TypeGuid = bu.buType
		LEFT JOIN vwBr br ON br.brGuid = bu.buBranch
	EXEC prcCheckSecurity
	Update #ResuLt
	SET	buTotal = 0
	WHERE [Security] > [UserReadPriceSecurity]
	SELECT 
		[buGuid], 
		buNumber, 
		buDate,
		btGuid,
		btName, 
		CustomerName,
		BranchGuid,
		BranchName, 
		buTotal,
		IsRefundFromBill
	FROM 
		#Result
	SELECT * FROM [#SecViol]
###########################
#END

