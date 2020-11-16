###################################################
CREATE FUNCTION fnGetOrderItemTypes()
	RETURNS TABLE
AS
	RETURN( 
		SELECT
			[GUID],
			[Number],
			[Type],
			[Name],
			[LatinName],
			[PostQty],
			[Operation]
		FROM 
			[oit000]
		)
##################################################################################
CREATE PROCEDURE GetOrderFlds
	@OrderFldsFlag	BIGINT = 0, 		 
	@OrderCFlds 	NVARCHAR (max) = ''
AS
	EXECUTE prcNotSupportedInAzureYet
	/*
	EXECUTE prcDropTable '##OrderFlds'

	DECLARE @SelectStr AS NVARCHAR(max)
	SET @SelectStr = 'SELECT bu.Guid OrderFldGuid'
	IF (@OrderFldsFlag <> 0)
	BEGIN
		IF (@OrderFldsFlag & 0x00000001 > 0)
			SET @SelectStr = @SelectStr + ',bu.number OrderFldNumber'
		IF (@OrderFldsFlag & 0x00000002 > 0 )
			SET @SelectStr = @SelectStr + ',bu.SalesManPtr OrderFldSalesManPtr' 
		IF (@OrderFldsFlag & 0x00000004 > 0 )
			SET @SelectStr = @SelectStr + ',bu.Vendor OrderFldVendor' 
		IF (@OrderFldsFlag & 0x00000008 > 0 )
			SET @SelectStr = @SelectStr + ',info.ssdate OrderFldSSDate'
		IF (@OrderFldsFlag & 0x00000010 > 0 )
			SET @SelectStr = @SelectStr + ',info.sadate OrderFldSADate'
		IF (@OrderFldsFlag & 0x00000020 > 0 )
			SET @SelectStr = @SelectStr + ',info.sddate OrderFldSDDate'
		IF (@OrderFldsFlag & 0x00000040 > 0 )
			SET @SelectStr = @SelectStr + ',info.spdate OrderFldSPDate'
		IF (@OrderFldsFlag & 0x00000080 > 0 )
			SET @SelectStr = @SelectStr + ',info.asdate OrderFldASDate'
		IF (@OrderFldsFlag & 0x00000100 > 0 )
			SET @SelectStr = @SelectStr + ',info.aadate OrderFldAADate'
		IF (@OrderFldsFlag & 0x00000200 > 0 )
			SET @SelectStr = @SelectStr + ',info.addate OrderFldADDate'
		
		IF (@OrderFldsFlag & 0x00000400 > 0 )
			SET @SelectStr = @SelectStr + ',info.OrderShipCondition OrderFldShipCondition'
		IF (@OrderFldsFlag & 0x00000800 > 0 )
			SET @SelectStr = @SelectStr + ',info.ExpectedDate OrderFldPredictedDate'
		IF (@OrderFldsFlag & 0x00001000 > 0 )
			SET @SelectStr = @SelectStr + ',bu.Notes OrderFldNotes'
		IF (@OrderFldsFlag & 0x00002000 > 0 )
			SET @SelectStr = @SelectStr + ',info.ShippingType OrderFldShipType'
		IF (@OrderFldsFlag & 0x00004000 > 0 )
			SET @SelectStr = @SelectStr + ',info.ShippingCompany OrderFldShipCompany'
		IF (@OrderFldsFlag & 0x00008000 > 0 )
			SET @SelectStr = @SelectStr + ',info.DeliveryConditions OrderFldReceiveCond'
		IF (@OrderFldsFlag &  0x00010000 > 0 )
			SET @SelectStr = @SelectStr + ',info.ArrivalPosition OrderFldArrivalPosition'
		IF (@OrderFldsFlag &  0x00020000 > 0 )
			SET @SelectStr = @SelectStr + ',info.Bank OrderFldBank'
		IF (@OrderFldsFlag &  0x00040000 > 0 )
			SET @SelectStr = @SelectStr + ',info.AccountNumber OrderFldAccountNumber'
		IF (@OrderFldsFlag &  0x00080000 > 0 )
			SET @SelectStr = @SelectStr + ',info.CreditNumber OrderFldCreditNumber'
		IF (@OrderFldsFlag &  0x00100000 > 0 )
			SET @SelectStr = @SelectStr + ',bu.TextFld1 OrderFldFirstField'
		IF (@OrderFldsFlag & 0x00200000 > 0 )
			SET @SelectStr = @SelectStr + ',bu.TextFld2 OrderFldSecondField'
		IF (@OrderFldsFlag &  0x00400000 > 0 )
			SET @SelectStr = @SelectStr + ',bu.TextFld3 OrderFldThirdField'
		IF (@OrderFldsFlag &  0x00800000 > 0 )
			SET @SelectStr = @SelectStr + ',bu.TextFld4 OrderFldFourthField'

	END

	IF @OrderCFlds <> ''	  
		SET @SelectStr = @SelectStr + @OrderCFlds

	SET @SelectStr = @SelectStr + ' INTO ##OrderFlds FROM bu000 AS bu INNER JOIN OrAddInfo000 AS info ON info.ParentGuid = bu.Guid'
	
	DECLARE	@CF_Table NVARCHAR(255)  
	SET @CF_Table = ''

	IF @OrderCFlds  <> '' 
	BEGIN		 
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000')  -- Mapping Table	  
		SET @SelectStr = @SelectStr + ' LEFT JOIN ' + @CF_Table + ' bu_' + @CF_Table + ' ON bu.Guid = bu_' + @CF_Table + '.Orginal_Guid ' 	   
	END 

	EXEC (@SelectStr)
	*/
##################################################################################
CREATE PROCEDURE GetMatFlds
	@MatFldsFlag	BIGINT = 0, 		 
	@MatCFlds 	NVARCHAR (max) = ''
AS
	EXECUTE prcNotSupportedInAzureYet
	/*
	EXECUTE prcDropTable  '##MatFlds'

	DECLARE @SelectStr AS NVARCHAR(max)
	SET @SelectStr = 'SELECT mt.Guid MatFldGuid'
	IF (@MatFldsFlag <> 0)
	BEGIN
		IF (@MatFldsFlag & 0x00000001 > 0)
			SET @SelectStr = @SelectStr + ',mt.code MatFldCode'
		IF (@MatFldsFlag & 0x00000002 > 0)
			SET @SelectStr = @SelectStr + ',mt.Name MatFldName'
		IF (@MatFldsFlag & 0x00000004 > 0)
			SET @SelectStr = @SelectStr + ',mt.LatinName MatFldLatinName'
		IF (@MatFldsFlag & 0x00000008 > 0)
			SET @SelectStr = @SelectStr + ',mt.Barcode MatFldBarcode'
--		IF (@MatFldsFlag & 0x00000010 > 0)
--			SET @SelectStr = @SelectStr + ',bi.Qty MatFldQty'
		IF (@MatFldsFlag & 0x00000020 > 0)
			SET @SelectStr = @SelectStr + ',mt.Unity MatFldUnity'
--		IF (@MatFldsFlag & 0x00000040 > 0)
--			SET @SelectStr = @SelectStr + ',bi.Price MatFldPrice'
--		IF (@MatFldsFlag & 0x00000080 > 0)
--			SET @SelectStr = @SelectStr + ',mt.GrandPric MatFldGrandPrice'
		IF (@MatFldsFlag & 0x00000100 > 0)
			SET @SelectStr = @SelectStr + ',mt.Type MatFldType'
		IF (@MatFldsFlag & 0x00000200 > 0)
			SET @SelectStr = @SelectStr + ',mt.Spec MatFldSpec'
		IF (@MatFldsFlag & 0x00000400 > 0)
			SET @SelectStr = @SelectStr + ',mt.Dim MatFldDim'
		IF (@MatFldsFlag & 0x00000800 > 0)
			SET @SelectStr = @SelectStr + ',mt.Origin MatFldOrigin'
--		IF (@MatFldsFlag & 0x00001000 > 0)
--			SET @SelectStr = @SelectStr + ',mt.Location MatFldLocation'
		IF (@MatFldsFlag & 0x00002000 > 0)
			SET @SelectStr = @SelectStr + ',mt.Company MatFldCompany'
		IF (@MatFldsFlag & 0x00004000 > 0)
			SET @SelectStr = @SelectStr + ',gr.Name MatFldGroup'
		IF (@MatFldsFlag & 0x00008000 > 0)
			SET @SelectStr = @SelectStr + ',gr.Code MatFldGroupCode'
		IF (@MatFldsFlag & 0x00010000 > 0)
			SET @SelectStr = @SelectStr + ',mt.Color MatFldColor'
		IF (@MatFldsFlag & 0x00020000 > 0)
			SET @SelectStr = @SelectStr + ',mt.Provenance MatFldProvenance'
		IF (@MatFldsFlag & 0x00040000 > 0)
			SET @SelectStr = @SelectStr + ',mt.Quality MatFldQuality'
		IF (@MatFldsFlag & 0x00080000 > 0)
			SET @SelectStr = @SelectStr + ',mt.Model MatFldModel'
		IF (@MatFldsFlag & 0x00100000 > 0)
			SET @SelectStr = @SelectStr + ',mt.Barcode2 MatFldBarcode2'
		IF (@MatFldsFlag & 0x00200000 > 0)
			SET @SelectStr = @SelectStr + ',mt.Barcode3 MatFldBarcode3'
--		IF (@MatFldsFlag & 0x00400000 > 0)
--			SET @SelectStr = @SelectStr + ',mt.UnitFact MatFldUnitFact'
	END

	IF @MatCFlds <> ''	  
		SET @SelectStr = @SelectStr + @MatCFlds

	SET @SelectStr = @SelectStr + ' INTO ##MatFlds FROM mt000 AS mt '+
                                                       'INNER JOIN gr000 AS gr ON mt.GroupGuid = gr.Guid'

	DECLARE	@CF_Table NVARCHAR(255)  
	SET @CF_Table = ''

	IF @MatCFlds  <> '' 
	BEGIN		 
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000')  -- Mapping Table	  
		SET @SelectStr = @SelectStr + ' LEFT JOIN ' + @CF_Table + ' mt_' + @CF_Table + ' ON mt.Guid = mt_' + @CF_Table + '.Orginal_Guid ' 	   
	END 

	EXEC (@SelectStr)
	*/
##################################################################################
CREATE PROCEDURE GetCustFlds
	@CustFldsFlag	BIGINT = 0, 		 
	@CustCFlds 	NVARCHAR (max) = ''
AS
	EXECUTE prcNotSupportedInAzureYet
	/*
	EXECUTE prcDropTable '##CustFlds'

	DECLARE @SelectStr AS NVARCHAR(max)
	SET @SelectStr = 'SELECT cu.Guid CustFldGuid'
	IF (@CustFldsFlag <> 0)
	BEGIN
		IF (@CustFldsFlag & 0x00000001 > 0)
			SET @SelectStr = @SelectStr + ',cu.Number CustFldNumber'
		IF (@CustFldsFlag & 0x00000002 > 0)
			SET @SelectStr = @SelectStr + ',cu.CustomerName CustFldName'
		IF (@CustFldsFlag & 0x00000004 > 0)
			SET @SelectStr = @SelectStr + ',cu.LatinName CustFldLatinName'
		IF (@CustFldsFlag & 0x00000008 > 0)
			SET @SelectStr = @SelectStr + ',cu.Prefix CustFldPrefix'
		IF (@CustFldsFlag & 0x00000010 > 0)
			SET @SelectStr = @SelectStr + ',cu.Suffix CustFldSuffix'
		IF (@CustFldsFlag & 0x00000020 > 0)
			SET @SelectStr = @SelectStr + ',ac.Name CustFldAccount'
		IF (@CustFldsFlag & 0x00000040 > 0)
			SET @SelectStr = @SelectStr + ',cu.Nationality CustFldNation'
		IF (@CustFldsFlag & 0x00000080 > 0)
			SET @SelectStr = @SelectStr + ',cu.Phone1 CustFldPhone1'
		IF (@CustFldsFlag & 0x00000100 > 0)
			SET @SelectStr = @SelectStr + ',cu.Phone2 CustFldPhone2'
		IF (@CustFldsFlag & 0x00000200 > 0)
			SET @SelectStr = @SelectStr + ',cu.Fax CustFldFax'
		IF (@CustFldsFlag & 0x00000400 > 0)
			SET @SelectStr = @SelectStr + ',cu.Telex CustFldTelex'
		IF (@CustFldsFlag & 0x00000800 > 0)
			SET @SelectStr = @SelectStr + ',cu.Mobile CustFldMobile'
		IF (@CustFldsFlag & 0x00001000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Pager CustFldPager'
		IF (@CustFldsFlag & 0x00002000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Notes CustFldNotes'
		IF (@CustFldsFlag & 0x00004000 > 0)
			SET @SelectStr = @SelectStr + ',cu.EMail CustFldEMail'
--		IF (@CustFldsFlag & 0x00008000 > 0)
--			SET @SelectStr = @SelectStr + ',cu.WebSite CustFldWebSite'
--		IF (@CustFldsFlag & 0x00010000 > 0)
--			SET @SelectStr = @SelectStr + ',cu.Policy CustFldPolicy'
--		IF (@CustFldsFlag & 0x00020000 > 0)
--			SET @SelectStr = @SelectStr + ',cu.Discount CustFldDiscount'
--		IF (@CustFldsFlag & 0x00040000 > 0)
--			SET @SelectStr = @SelectStr + ',cu.Balance CustFldBalance'
		IF (@CustFldsFlag & 0x00080000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Country CustFldCountry'
		IF (@CustFldsFlag & 0x00100000 > 0)
			SET @SelectStr = @SelectStr + ',cu.City CustFldCity'
		IF (@CustFldsFlag & 0x00200000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Area CustFldArea'
		IF (@CustFldsFlag & 0x00400000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Street CustFldStreet'
		IF (@CustFldsFlag & 0x00800000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Address CustFldAddress'
		IF (@CustFldsFlag & 0x01000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.ZipCode CustFldZipCode'
		IF (@CustFldsFlag & 0x02000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.POBox CustFldPOBox'
		IF (@CustFldsFlag & 0x04000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Certificate CustFldCertificate'
		IF (@CustFldsFlag & 0x08000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Job CustFldJob'
		IF (@CustFldsFlag & 0x10000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.JobCategory CustFldJobCategory'
		IF (@CustFldsFlag & 0x20000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.DateOfBirth CustFldDateOfBirth'
		IF (@CustFldsFlag & 0x40000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Gender CustFldGender'
		IF (@CustFldsFlag & 0x80000000 > 0)
			SET @SelectStr = @SelectStr + ',cu.Barcode CustFldBarcode'				
	END

	IF @CustCFlds <> ''	  
		SET @SelectStr = @SelectStr + @CustCFlds

	SET @SelectStr = @SelectStr + ' INTO ##CustFlds FROM cu000 AS cu INNER JOIN ac000 AS ac ON ac.Guid = cu.AccountGuid'

	DECLARE	@CF_Table NVARCHAR(255)  
	SET @CF_Table = ''

	IF @CustCFlds  <> '' 
	BEGIN		 
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000')  -- Mapping Table	  
		SET @SelectStr = @SelectStr + ' LEFT JOIN ' + @CF_Table + ' cu_' + @CF_Table + ' ON cu.Guid = cu_' + @CF_Table + '.Orginal_Guid ' 	   
	END 

	EXEC (@SelectStr)
	*/
##################################################################################
CREATE FUNCTION fnGetFinalState (@TypeGuid UNIQUEIDENTIFIER)
RETURNS	UNIQUEIDENTIFIER
AS 
BEGIN
	RETURN 
	(
		SELECT TOP 1 
			OIT.Guid AS FinalStateGuid
		FROM
			oit000 OIT
			INNER JOIN oitvs000 OITVS ON OIT.Guid = OITVS.ParentGuid
		WHERE OITVS.OtGuid = @TypeGuid AND OITVS.Selected = 1
		ORDER BY OITVS.StateOrder DESC 
	)
END
##################################################################################
CREATE FUNCTION fnIsFinalState (@TypeGuid UNIQUEIDENTIFIER, @StateGuid UNIQUEIDENTIFIER)
RETURNS	INT
AS 
BEGIN
	DECLARE @Result INT	
	IF @StateGuid = dbo.fnGetFinalState(@TypeGuid)
		SET @Result = 1
	ELSE
		SET @Result = 0	
		
	RETURN @Result
END
##################################################################################
#END