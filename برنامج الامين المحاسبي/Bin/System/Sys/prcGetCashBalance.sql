################################################################################
CREATE PROC prcGetCashBalance
	@CashierID UNIQUEIDENTIFIER,
	@BillsID	UNIQUEIDENTIFIER,
	@UserNumber	float = 0
AS
SET NOCOUNT ON

DECLARE @BranchID UNIQUEIDENTIFIER
SELECT @BranchID = BranchID from posuserbills000 where GUID=@BillsID
;WITH CashDrawers AS
(
	SELECT DISTINCT CashAccID FROM POSCurrencyItem000 WHERE UserID = @CashierID
)
SELECT 
	My.Guid AS CurrencyID,
	My.CurrencyVal AS CurrencyValue, 
	Sum( (En.Debit / En.CurrencyVal)- (En.Credit / En.CurrencyVal)) As Balance 
FROM En000 En
	INNER JOIN ce000 ce on ce.guid=en.parentguid
	INNER JOIN Ac000 Ac 	ON En.AccountGuid = Ac.Guid 
	LEFT JOIN My000 My	ON En.CurrencyGuid = My.Guid
WHERE	(Ac.Guid in (SELECT CashAccID FROM CashDrawers)) 
	AND (@UserNumber=0 or en.SalesMan=@UserNumber)
Group BY Ac.Guid, My.Guid, My.CurrencyVal, My.Number
HAVING Sum( (En.Debit / En.CurrencyVal)- (En.Credit / En.CurrencyVal)) > 0
ORDER BY My.Number
################################################################################
#END	