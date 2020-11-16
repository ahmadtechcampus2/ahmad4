##############################################################
CREATE  Proc RepFastReport_Bills
	@MatGuid UNIQUEIDENTIFIER = 0x0, 
	@GroupGuid UNIQUEIDENTIFIER = 0x0, 
	@StoreGuid UNIQUEIDENTIFIER = 0x0, 
	@CostGuid UNIQUEIDENTIFIER = 0x0, 
	@Acc UNIQUEIDENTIFIER = 0x0, 
	@CurPtr UNIQUEIDENTIFIER = 0x0,
	@FromDate  DATETIME = '1-1-2008',
	@ToDate  DATETIME = '1-1-2008',
	@SrcTypesguid UNIQUEIDENTIFIER = 0x0,
	@Contain NVARCHAR(250) ,
	@NotContain NVARCHAR(250), 
	@Branch UNIQUEIDENTIFIER ,
	@Posted INT, 
	@UnPosted INT
AS
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl](	[StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT],[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI) 

	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] 		@MatGuid, @GroupGUID, -1, 0x0 
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGUID 
	INSERT INTO [#CostTbl]([CostGuid], [Security])		EXEC [prcGetCostsList] 			@CostGUID 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] 	@SrcTypesguid
	IF (ISNULL(@CostGUID,0X0) = 0X0) 
		INSERT INTO [#CostTbl] VALUES (0X0,0,'') 
	select 
			bu.Date buDate, 
			bu.isPosted BuIsPosted,	
			bu.Number buNumber,
			bu.Notes buNotes,
			bi.Qty BiQty,
			bi.Price BiPrice,
			bt.Guid buType,
			bt.Name btName,
			mt.Name mtName,
			mt.Code mtCode,
			gr.Name grName, 
			br.Name BrName,
			*
	 
FROM 
		bu000 bu INNER JOIN bi000 bi ON bu.Guid = bi.ParentGuid 
				 INNER JOIN  #MatTbl mt1 ON bi.MatGuid = mt1.MatGUID
				 INNER JOIN mt000 mt ON bi.matGuid = mt.Guid 
				 INNER JOIN gr000 gr ON mt.GroupGuid = gr.Guid 
				 INNER JOIN bt000 bt ON bt.Guid = bu.TypeGuid 
				 INNER JOIN br000 br ON br.Guid = bu.Branch
				 INNER JOIN [#BillsTypesTbl] bt1  On  bt.Guid = bt1.TypeGuid
				 INNER JOIN  #CostTbl co ON bu.CostGuid = co.CostGuid
				 INNER JOIN  #StoreTbl st ON bu.StoreGuid = St.StoreGuid
WHERE 
	(bu.Date > @FromDate AND bu.Date <= @ToDate) 
AND	(bu.CustAccGuid = @Acc or @Acc = 0x0 )
AND (@CurPtr = bu.CurrencyGuid OR  @CurPtr = 0x0)
AND (bu.Notes like '%'+ @Contain +'%' OR  @Contain = '')
AND (bu.Notes not like '%'+ @NotContain +'%' OR  @NotContain = '')
AND (bu.Branch  = @Branch Or  @Branch = 0x0)
AND ((@Posted = 1 AND bu.IsPosted = 1) OR (@UnPosted = 1 AND bu.IsPosted = 0))
ORDER BY bt.Name, bu.Number 
##############################################################
#END