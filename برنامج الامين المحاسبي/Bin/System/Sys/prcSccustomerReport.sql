#########################################################
CREATE PROC prcSccustomerReport 
      (
      @offeredBranch uniqueidentifier, 
      @customerGuid uniqueidentifier,
      @stateGuid uniqueidentifier,
      @cardType uniqueidentifier,
      @filterDateField INT = 0,
      @Month INT = 0,
      @DAY INT = 0,
      @justdisplayCardNotOwners BIT = 0,
      @startDate DateTime,
      @endDate DateTime)

AS 

SELECT LTRIM(RIGHT(CONVERT(VARCHAR(20), bestTime, 100), 7)) AS callTime, * 
FROM vwSCCustomerinfo  
WHERE 
((@offeredBranch = 0x0 OR offeredBranchGuid = @offeredBranch  ) AND
(@customerGuid = 0x0 OR customerGuid = @customerGuid) AND
(@stateGuid = 0x0 OR statusGuid =@stateGuid )AND
(@cardType = 0x0 OR cardTypeGuid = @cardType) AND
(@month = 0 OR DATEPART(month, birthdate) = @month) AND
(@day = 0 OR DATEPART(day, birthdate) = @day) 
AND
(
      (@filterDateField = 1 AND formReceiptDate BETWEEN @StartDate AND @endDate) 
      OR
      (@filterDateField = 2 AND formSubmitDate BETWEEN @StartDate and @endDate)  
      OR
      (@filterDateField = 3 AND firstAffiliationDate BETWEEN @StartDate AND @endDate) 
      OR 
      (@filterDateField = 0  
            AND
                  (
                        formReceiptDate BETWEEN @StartDate and @endDate
                  OR
                        formSubmitDate BETWEEN @StartDate and @endDate
                  OR
                        firstAffiliationDate BETWEEN @StartDate and @endDate
                  )
      )
)     
AND 
	@justdisplayCardNotOwners = 0
	)
OR 
	(@justdisplayCardNotOwners = 1 AND code = '')
#########################################################
#end