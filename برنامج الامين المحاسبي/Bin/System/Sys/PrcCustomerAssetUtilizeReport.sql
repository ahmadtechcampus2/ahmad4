######################################################
CREATE PROCEDURE PrcCustomerAssetUtilizeReport
	@AssetGuid				UNIQUEIDENTIFIER	
	,@MaterialGuid				UNIQUEIDENTIFIER	
	,@GroupGuid				UNIQUEIDENTIFIER	
	,@AccountGuid				UNIQUEIDENTIFIER
	,@FromDate				DATETIME			
	,@ToDate				DATETIME			
	,@CurrencyGuid				UNIQUEIDENTIFIER
	,@MaterialConditionGuid			UNIQUEIDENTIFIER	
	,@CusotmerConditionGuid			UNIQUEIDENTIFIER	
	,@SourceGuid				UNIQUEIDENTIFIER
	,@CustomerGuid				UNIQUEIDENTIFIER = 0x0	
		
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @CurrencyVal FLOAT
	SET @CurrencyVal = 1
	IF(ISNULL(@CurrencyGuid, 0x0) <> 0x0)
		SELECT @CurrencyVal = CurrencyVal FROM My000 WHERE Guid = @CurrencyGuid
	
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MaterialGuid, @GroupGuid, -1,@MaterialConditionGuid
	
	CREATE TABLE [#Cust] ( [CustGuid] [UNIQUEIDENTIFIER], [Sec] [INT])   
    	INSERT INTO [#Cust] EXEC [prcGetCustsList]  0x0, 0x0, @CusotmerConditionGuid

	SELECT 
		AUC.Date ContractDate
		,CAST(AUC.CloseDate as nvarchar(100)) CloseContractDate 
		,AUC.IsCloseDateActive IsCloseDateAcitve
		,Ad.Sn Asset
		,CustomerSales.TotalCustomerSales
		,Mt.Name MaterialName
		,Mt.GUID MaterialGUID
		,Mt.Code MaterialCode
		,Mt.LatinName LatineMaterialName
		,Mt.Barcode MaterialBarcode
		,Mt.Barcode2 MaterialUnit2_Barcode
		,Mt.Barcode3 MaterialUnit3_Barcode
		,Mt.Qty Quantity
		,Mt.Unity UnitName
		,1 UnitFactor
		,Mt.AvgPrice Price
		,Mt.Type MaterialType
		,Mt.Spec MaterialSpecification
		,Mt.Dim Dimension
		,Mt.Origin Origin
		,Mt.Pos Position
		,Mt.Company Company
		,Gr.Name GroupName
		,Gr.Code GroupCode
		,Mt.Color Color
		,Mt.Provenance Provenance
		,Mt.Quality Quality
		,Mt.Model Model
		,Cu.GUID CustomerGUID
		,Cu.Number CustomerNumber
		,Cu.Prefix CustomerPrefix
		,Cu.CustomerName CustomerName
		,Cu.LatinName CustomerLatinName
		,Cu.Suffix CustomerSuffix
		,Cu.Nationality CustomerNationality
		,Cu.Phone1 CustomerPhone1
		,Cu.Phone2 CustomerPhone2
		,Cu.Fax CustomerFax
		,Cu.Telex CustomerTelex
		,Cu.Mobile CustomerMobile
		,Cu.Pager CustomerPager
		,Cu.Notes CustomerNotes
		,Cu.EMail CustomerEMail
		,Cu.HomePage CustomerHomePage
		,Cu.DiscRatio CustomerDiscRatio
		,Cu.Country CustomerCountry
		,Cu.City CustomerCity
		,Cu.Area CustomerArea
		,Cu.Street CustomerStreet
		,Cu.Address CustomerAddress
		,Cu.ZipCode CustomerZipCode
		,Cu.POBox CustomerPOBox
		,Cu.Certificate CustomerCertificate
		,Cu.Job CustomerJob
		,Cu.JobCategory CustomerJobCategory
		,Cu.UserFld1 CustomerUserFld1
		,Cu.UserFld2 CustomerUserFld2
		,Cu.UserFld3 CustomerUserFld3
		,Cu.UserFld4 CustomerUserFld4
		,Cu.DateOfBirth CustomerDateOfBirth
		,Cu.Gender CustomerGender
		,Cu.Hoppies CustomerHoppies
	FROM AssetUtilizeContract000 AUC
	INNER JOIN vexcu Cu  ON Cu.Guid  = AUC.Customer
	INNER JOIN Ad000 Ad  ON Ad.Guid  = AUC.Asset
	INNER JOIN As000 Ass ON Ass.Guid = Ad.ParentGuid
	INNER JOIN Mt000 Mt  ON Mt.Guid  = Ass.ParentGuid
	INNER JOIN #MatTbl MatTbl  ON Mt.Guid  = MatTbl.MatGUID
	INNER JOIN Gr000 Gr  ON Gr.Guid  = Mt.GroupGuid
	INNER JOIN Bu000 Bu ON Bu.Guid	 = AUC.OutBillGuid
	INNER JOIN #Cust Cust ON Cust.CustGuid  = AUC.Customer
	LEFT JOIN 
	(
		SELECT CustGuid Customer, SUM(Bi.Price * Bi.Qty * Bi.CurrencyVal / @CurrencyVal) TotalCustomerSales 
		FROM Bu000 Bu
		INNER JOIN Bi000 Bi ON Bu.Guid = Bi.ParentGuid
		INNER JOIN RepSrcs RepSrc ON  RepSrc.idType	= Bu.TypeGUID
		WHERE RepSrc.IdTbl = @SourceGuid
			AND ( ISNULL(@AccountGuid, 0x0) = 0x0 OR Bu.CustAccGuid = @AccountGuid )
		GROUP BY CustGuid
	)CustomerSales ON CustomerSales.Customer = AUC.Customer
	WHERE		( ISNULL(@AssetGuid, 0x0) = 0x0 OR (Ad.Guid = @AssetGuid) )
		AND		( AUC.Date BETWEEN AUC.Date AND (CASE WHEN AUC.IsCloseDateActive = 0 THEN @ToDate ELSE AUC.CloseDate END  )  )
		AND		((ISNULL(@CustomerGuid, 0x0) = 0x0)  OR (AUC.Customer =  @CustomerGuid))
		AND		((ISNULL(@AccountGuid, 0x0) = 0x0)  OR (Bu.CustAccGuid =  @AccountGuid))
END

######################################################
#END