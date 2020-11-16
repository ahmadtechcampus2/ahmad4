######################################
CREATE PROCEDURE prcSCChargedCardsReport
      @CustomerGuid UNIQUEIDENTIFIER      
AS
BEGIN
      SET NOCOUNT ON
      SELECT  
				  DiscountCard.GUID AS GUID,
                  sccustomers.GUID AS CustomerGuid, 
                  (sccustomers.FirstName + ' '+ sccustomers.LastName)  AS CustomerName, 
                  DiscountCard.Code AS SubscriptionCode, 
                  DiscountCard.ID AS CardNo, 
                  DiscountCard.StartDate AS ExpireStartDate, 
                  DiscountCard.EndDate AS ExpireEndDate, 
                  DiscountTypesCard.Name AS DiscountCardType, 
                  DiscountCardStatus.Name AS SmartCardState, 
                  CASE DiscountCard.Locked WHEN 0 THEN 1 ELSE 0 END As IsActive
                   
      FROM 
            DiscountCard000 AS DiscountCard 
            INNER JOIN sccustomers000 AS sccustomers ON DiscountCard.CustomerGuid = sccustomers.CustomerSupplier 
            INNER JOIN DiscountTypesCard000 AS DiscountTypesCard ON DiscountCard.Type = DiscountTypesCard.Guid 
            INNER JOIN DiscountCardStatus000 AS  DiscountCardStatus ON DiscountCard.State = DiscountCardStatus.Guid 
       
      WHERE  
			(sccustomers.GUID = @CustomerGuid) OR (@CustomerGuid = 0x00) 
END
######################################
CREATE PROC repChangeStateFromReport
            @cardGuid [UNIQUEIDENTIFIER], 
            @IsCheck [INT]
AS    
      UPDATE DiscountCard000 
      SET Locked = @IsCheck
      WHERE Guid = @cardGuid
######################################
CREATE PROCEDURE prcGetCustomerCardId
      @CustomerGuid UNIQUEIDENTIFIER      
AS
BEGIN
      SET NOCOUNT ON
      
	  DECLARE @customerSupplier UNIQUEIDENTIFIER 
       
      SELECT @customerSupplier = customerSupplier FROM SCCUSTOMERS000 WHERE Guid = @customerguid

      IF (EXISTS(select top 1 id from discountcard000 where customerguid = @customerSupplier))
      BEGIN
            SELECT TOP 1
                  (FirstName + ' ' +MidName + ' ' +LastName) AS CustomerName,
                  (LatinFirstName + ' ' +LatinMidName+ ' ' +LatinLastName) AS CustomerLatinName,
                  subscriptioncode AS SubscriptionCode,
                  (DiscountCard.ID) AS CardId
            FROM sccustomers000 AS ScCustomers        
            INNER JOIN discountcard000 AS DiscountCard 
            ON ScCustomers.GUID = DiscountCard.CustomerGuid 
            WHERE (ScCustomers.Guid = @CustomerGuid)
            ORDER BY DiscountCard.id DESC
      END   
      ELSE 
      BEGIN
            SELECT TOP 1
                        (FirstName + ' ' +MidName + ' ' +LastName) AS CustomerName,
                        (LatinFirstName + ' ' +LatinMidName+ ' ' +LatinLastName) AS CustomerLatinName,
                        subscriptioncode AS SubscriptionCode,
                        0 AS CardId
            FROM sccustomers000 AS ScCustomers        
            WHERE (ScCustomers.Guid = @CustomerGuid)
      END
END
######################################
CREATE PROC smartCardhistory(@customerGuid uniqueidentifier)
AS 
BEGIN
SELECT 
      CustomerNumber,
      TotalBuy,
      CardID,
      DateOfBuy,
      ISNULL(br.brName, '') AS BranchName,
      BillNumber,
      OrderID,
      Points,
      SCpurchases000.[Type]
FROM SCpurchases000 
      JOIN SCCustomers000  ON SCpurchases000.customerNumber = SCCustomers000.subscriptionCode 
      LEFT JOIN vwbr AS br on SCpurchases000.branch = br.brguid
      LEFT JOIN op000 AS op ON op.[Name] = 'EnableBranches'
WHERE 
      SCCustomers000.[guid] = @customerGuid 
      --AND (op.[Time] = (SELECT MAX(Time) FROM op000 WHERE[Name] = 'EnableBranches'))
      AND 
      (
            ISNULL(op.[Value], 0) = 0 
            OR
            ISNULL(SCpurchases000.branch, 0x0) = 0x0
            OR
            (op.[Value] = 1 AND br.[brName] IS NOT NULL) 
      )     
END
######################################
#END