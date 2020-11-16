##################################################################################
CREATE TRIGGER trg_DiscCardStatus_Del 
ON DiscountCardStatus000 
FOR DELETE
	NOT FOR REPLICATION

AS
	INSERT INTO ErrorLog (level, type, c1, g1) 
	SELECT 1, 0, 'AmnE0270: This card is used in a discount card.', D.guid 
	FROM Deleted D LEFT JOIN DiscountCard000 Dc on D.Guid = Dc.State
	WHERE Dc.Type IS NOT NULL 
##################################################################################
#END