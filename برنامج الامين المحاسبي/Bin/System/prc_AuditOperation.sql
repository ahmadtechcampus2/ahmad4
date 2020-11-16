##################################################################
CREATE PROC prc_AuditOperation
	@Audit     BIT,
	@NonAudit  BIT,
	@Auditdate BIT,
	@FromDate DATETIME,
    @ToDate   DATETIME,
	@UserGuid    UNIQUEIDENTIFIER,
	@StoreGuid   UNIQUEIDENTIFIER,
	@CostGuid    UNIQUEIDENTIFIER,
	@CustomerGuid  UNIQUEIDENTIFIER,
	@BranchGuid    UNIQUEIDENTIFIER,
	@RepSrc        UNIQUEIDENTIFIER
AS

	SELECT 
		Au.*,
		BI.buGUID,BI.biBillQty
	FROM 
		vwExtended_bi AS BI LEFT JOIN  Audit000 AS AU ON AU.AuditRelGuid = BI.buGUID
		INNER JOIN RepSrcs AS RS ON bi.buType = RS.IdType
	WHERE 
		 rs.IdTbl = @RepSrc  
		 AND (@UserGuid = 0x0 OR BI.buUserGUID = @UserGuid) 
		 AND (@StoreGuid = 0x0 OR BI.biStorePtr = @StoreGuid) 
		 AND (@CostGuid = 0x0 OR BI.biCostPtr = @CostGuid) 
		 AND (@CustomerGuid = 0x0 OR BI.buCustPtr = @CustomerGuid) 
		 AND (@BranchGuid = 0x0 OR bi.buBranch = @BranchGuid)
		 AND ((BI.buDate BETWEEN @FromDate AND @ToDate) OR (AU.AuditDate BETWEEN @FromDate AND @ToDate))
		 AND ISNULL(AU.AuditGuidType,0) IN (CASE @Audit WHEN 1 THEN 1 ELSE -1 END,CASE @NonAudit WHEN 1 THEN 0 ELSE -1 END)
#################################################################
#END