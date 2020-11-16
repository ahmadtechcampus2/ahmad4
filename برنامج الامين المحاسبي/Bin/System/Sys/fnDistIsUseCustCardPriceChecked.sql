#########################################################
CREATE FUNCTION fnDistIsUseCustCardPriceChecked(@DistGuid UNIQUEIDENTIFIER)
RETURNS BIT
AS Begin
	Declare @val INT
	SELECT @val = 
		(
			-- count used bt in DistributorCard
			SELECT COUNT(*) FROM Distdd000 WHERE ObjectType = 1 AND DistributorGuid = @DistGuid
		)
			- 
		(
			-- count Distributor bt which it's price is custCardPride
			SELECT COUNT(*) FROM bt000 
			WHERE GUID IN (SELECT ObjectGuid FROM Distdd000 WHERE ObjectType = 1 
															AND DistributorGuid = @DistGuid)
					AND DefPrice = 2048
		) 

	IF @val > 0
		BEGIN
			return 0 
		END
	ELSE
		BEGIN
			SELECT @val = CASE UseCustLastPrice WHEN 0 THEN 1 ELSE 0 END
						  FROM Distributor000
						  WHERE GUID = @DistGuid
			
		END
		return @val 
END		
/*
select dbo.fnDistIsUseCustCardPriceChecked ('AAF1782B-C23C-4521-8CDC-FE401AB94B14')
*/
#########################################################
#END 