##################################
CREATE FUNCTION fnGetRelatedBills (@BillGuid UNIQUEIDENTIFIER) 
RETURNS TABLE   
AS 
 
return 
(

	SELECT 
	[bu].[Guid] BillGuid, 
	[bu].[TypeGUID] BillTypeGuid, 
	[bu].[Number] BillNo, 
	[bt].[Name] BillTypeName,
	br.RelatedBillGuid ParentBill,
	bu.Notes BillNotes,
	bu.branch BillBranch
		
	FROM  
		BillRelations000 br
		INNER JOIN bu000  bu ON br.[BillGuid] = bu.[GUID]
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
	WHERE  
		RelatedBillGuid = @BillGuid 

UNION ALL 
	
	SELECT 
	[bu].[Guid] BillGuid, 
	[bu].[TypeGUID] BillTypeGuid, 
	[bu].[Number] BillNo, 
	[bt].[Name] BillTypeName,
	br.[BillGuid] ParentBill,
	bu.Notes BillNotes,
	bu.branch BillBranch
	FROM  
		BillRelations000 br
		INNER JOIN bu000  bu ON br.RelatedBillGuid = bu.[GUID]
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
	WHERE  
		[BillGuid] = @BillGuid 
) 
##################################
CREATE PROCEDURE repRelatedBills
	@BillType UNIQUEIDENTIFIER, 
	@BillNo INT, 
	@BranchGuid UNIQUEIDENTIFIER ,
	@NoteSearch NVARCHAR(500) = '' 
AS 
	SET NOCOUNT ON 
	DECLARE
		@Str NVARCHAR(500) 
		SET @Str = '%'+ @NoteSearch +'%' 
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INTEGER])  
	
	CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpostedSecurity] [INTEGER])  
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] 
	
	CREATE TABLE #Result( 
		[buGuid] UNIQUEIDENTIFIER,  
		[RelatedGuid] UNIQUEIDENTIFIER, 
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
		IsMainBillRow INT) 	

	CREATE TABLE #Temp (  
		buGuid UNIQUEIDENTIFIER,
		[Parent] UNIQUEIDENTIFIER,
		buNumber INT, 
		buDate DATETIME, 
		[Security] INT, 
		UserSecurity INT,
		[UserReadPriceSecurity] INT, 
		[r] NVARCHAR(256),  
		btGuid UNIQUEIDENTIFIER, 
		buCust_Name NVARCHAR(256), 
		[s] NVARCHAR(256), 
		[b] UNIQUEIDENTIFIER, 
		buTotal FLOAT,
		[is] INT)
		
	DECLARE @lang INT 
	SET @lang = dbo.fnConnections_GetLanguage() 
	
	INSERT INTO #Temp
	SELECT  
		bu.buGuid ,
		bu.buGUID [Parent],
		bu.buNumber , 
		bu.buDate, 
		bu.buSecurity [Security], 
		src.UserSecurity,
		src.[UserReadPriceSecurity], 
		CASE @lang 
			WHEN 0 THEN bt.btName  
			ELSE (CASE bt.btLatinName WHEN '' THEN bt.btName ELSE bt.btLatinName END) 
		END [r],  
		bt.btGuid, 
		bu.buCust_Name, 
		CASE  
			WHEN br.brGuid IS NULL THEN '' 
			ELSE  
				(CASE @lang 
					WHEN 0 THEN br.brName  
					ELSE (CASE br.brLatinName WHEN '' THEN br.brName ELSE br.brLatinName END) 
				END) 
		END [s], 
		ISNULL(br.brGuid, 0x0) [b], 
		bu.buTotal,
		1 [is]
	FROM  
		vwbu bu  
		INNER JOIN BillRelations000 rb ON bu.buGUID = rb.[BillGuid] OR bu.buGUID = rb.[RelatedBillGuid]
		INNER JOIN vwbt bt ON bt.btGUID = bu.buType 
		INNER JOIN [#BillsTypesTbl] src ON src.TypeGuid = bu.buType 
		LEFT JOIN vwBr br ON ( br.brGuid = bu.buBranch )  
	WHERE
		bu.buType = @BillType
		AND ( bu.buNumber = @BillNo OR @BillNo = 0 )
		AND ( bu.buNotes LIKE @Str OR @NoteSearch = '')
		AND (bu.buBranch = @BranchGuid OR @BranchGuid = 0x0)
		
	INSERT INTO #Result
		SELECT * From #Temp
		
	INSERT INTO #Result
	SELECT  
		[bu].buGuid,
		rs.[buGuid],
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
		bu.buTotal,
		0
	FROM  
		vwbu bu
		INNER JOIN BillRelations000 rb ON bu.buGUID = rb.[RelatedBillGuid] OR bu.buGUID = rb.[BillGuid] 
		INNER JOIN #Temp rs ON (bu.buGUID = rb.[RelatedBillGuid] AND rs.buGUID = rb.[BillGuid]) OR (rs.buGUID = rb.[RelatedBillGuid] AND bu.buGUID = rb.[BillGuid])
		INNER JOIN vwbt bt ON bt.btGUID = bu.buType 
		INNER JOIN [#BillsTypesTbl] src ON src.TypeGuid = bu.buType 
		LEFT JOIN vwBr br ON ( br.brGuid = bu.buBranch )  
	WHERE
		bu.buBranch = @BranchGuid OR @BranchGuid = 0x0

		
	Update #ResuLt
	SET	buTotal = 0
	WHERE [Security] > [UserReadPriceSecurity]
	
	EXEC prcCheckSecurity 

	SELECT  Distinct
		[buGuid] [BillGuid],
		[RelatedGuid], 
		buNumber [BillNo],  
		buDate,
		btGuid [BillTypeGuid], 
		btName [BillTypeName],  
		CustomerName , 
		BranchGuid [BillBranchGuid], 
		BranchName [BillBranchName],  
		buTotal,
		IsMainBillRow
	FROM  
		#Result R
	WHERE R.btGuid = @BillType
	ORDER By
		[RelatedGuid],
		IsMainBillRow desc,
		btGuid, 
		buNumber 

	--details

	SELECT  Distinct
		[buGuid] [BillGuid],
		[RelatedGuid], 
		buNumber [BillNo],  
		buDate,
		btGuid [BillTypeGuid], 
		btName [BillTypeName],  
		CustomerName , 
		BranchGuid [BillBranchGuid], 
		BranchName [BillBranchName],  
		buTotal,
		IsMainBillRow
	FROM  
		#Result R
	WHERE R.btGuid != @BillType
	
	ORDER By
		[RelatedGuid],
		IsMainBillRow desc,
		btGuid, 
		buNumber 

	SELECT * FROM [#SecViol] 
##################################
CREATE PROCEDURE prcFindBills 
	@BillGuid UNIQUEIDENTIFIER,
	@BillType UNIQUEIDENTIFIER,
	@BillNo  INT,
	@NoteSearch  NVARCHAR(500) ,
	@BranchGuid   UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

DECLARE @Str  NVARCHAR(500) 
SET @Str= '%'+ @NoteSearch+'%'

CREATE TABLE #RelatedBill(Guid UNIQUEIDENTIFIER)

INSERT INTO  #RelatedBill 
SELECT 
	billguid  
FROM
	BillRelations000
WHERE 
	RelatedBillGuid = @BillGuid 

INSERT INTO  #RelatedBill 
SELECT 
RelatedBillGuid   
FROM 
	BillRelations000 
WHERE 
	billguid = @BillGuid

IF @BillNo <> 0
	SELECT bu.guid BillGuid,
		bu.typeguid BillTypeGuid,
		bu.number BillNo,
		bt.Name BillTypeName
	FROM 
		bu000 bu inner join bt000 bt ON bt.GUID = bu.TypeGUID
	WHERE 
		TypeGUID = @BillType
		AND @BranchGuid = bu.branch
		AND @BillNo = bu.number
		AND bu.GUID <> @BillGuid
		AND bu.GUID not in (SELECT GUID FROM #RelatedBill)
ELSE
	SELECT
		bu.GUID BillGuid,
		bu.typeguid BillTypeGuid,
		bu.number BillNo,
		bt.Name BillTypeName

	FROM
		bu000 bu inner join bt000 bt on bt.GUID = bu.TypeGUID
	WHERE 
		TypeGUID = @BillType
		AND @BranchGuid = bu.branch
		AND bu.GUID <> @BillGuid
		AND bu.GUID not in (SELECT GUID FROM #relatedbill)
		AND bu.NOTES  like (SELECT @Str)
###########################
#END

