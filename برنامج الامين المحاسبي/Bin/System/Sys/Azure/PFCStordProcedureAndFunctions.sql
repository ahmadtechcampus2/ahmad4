#################################################################
CREATE PROCEDURE prc_SpecialOffersBelongToPFC
			@SubPFCGuid		UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	SELECT distinct SO.Guid 'SGuid' INTO #Temp
	FROM  
	SpecialOffers000  SO		LEFT JOIN 
	SOBillTypes000 SOBillTypes
	on SO.guid = SOBillTypes.specialofferGUID 
	WHERE SOBillTypes.BillTypeGUID in 
	(	
		SELECT SubPFCBillTypes.TypeGuid FROM 
		SubProfitCenter000 SubPFC inner join 
		SubProfitCenterBill_EN_Type000 SubPFCBillTypes
		on SubPFC.GUID = SubPFCBillTypes.ParentGUID
		WHERE SubPFC.GUID =  @SubPFCGuid
	) OR BillTypeGuid is NULL
		
	SELECT so.* FROM SpecialOffers000  so INNER JOIN #Temp  t on so.guid = t.SGuid
#################################################################
CREATE FUNCTION prc_GetDateOfLastBillUsesOffer( @SOGUID UNIQUEIDENTIFIER) 
      RETURNS DATETIME 
AS  
BEGIN  
     DECLARE @MaxDate1 DATETIME
     DECLARE @MaxDate2 DATETIME
     
	SELECT @MaxDate1 = MAX(bu.buDate)
               FROM vwbubi bu
               INNER JOIN 
               SOItems000 soi ON soi.GUID = bu.biSOGUID    
               INNER JOIN 
               SpecialOffers000 so ON so.GUID = soi.SpecialOfferGUID
               WHERE so.GUID = @SOGUID
                     
    SELECT @MaxDate2 = MAX(bu.buDate)
           FROM vwbubi bu
           INNER JOIN 
           SOOfferedItems000 soi ON soi.GUID = bu.biSOGUID   
           INNER JOIN 
           SpecialOffers000 so ON so.GUID = soi.SpecialOfferGUID
           WHERE so.GUID = @SOGUID
           
           IF (@MaxDate1 > @MaxDate2)   
			RETURN  @MaxDate1
		   
	RETURN  @MaxDate2
END
#################################################################
CREATE PROC PrcAddLinkedPFCServer
			@serverName VARCHAR(50),
			@userName	VARCHAR(50),
			@password	VARCHAR(50),
			@isWindowsAuthintication BIT
AS
	SET NOCOUNT ON
	
	DECLARE @Result	INT
	
	IF ISNULL(@serverName, '') = '' 
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END
	
	IF  EXISTS (SELECT * FROM  sys.sysservers WHERE srvName = @serverName)
	BEGIN
		SELECT 1 AS 'Success' 
		RETURN
	END			
	
	IF @isWindowsAuthintication IS NULL
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN 
	END
	
	IF 	@isWindowsAuthintication = 0
	BEGIN	
		IF ISNULL(@userName, '') = ''
		BEGIN
			SELECT 0 AS 'Success' 
			RETURN 
		END			
		
		EXEC @Result = sp_addlinkedsrvlogin  @serverName, 'FALSE', NULL, @userName, @password
		 
		IF @Result = 1
		BEGIN
			SELECT 0 AS 'Success' 
			RETURN
		END	
		ELSE
		BEGIN
			SELECT 1 AS 'Success' 
			RETURN
		END	
	END
	
	EXEC @Result = sp_addlinkedserver @serverName 
	IF @Result = 1
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END	
	ELSE
	BEGIN
		SELECT 1 AS 'Success' 
		RETURN
	END	
#################################################################
#END