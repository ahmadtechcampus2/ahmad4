#########################################################
CREATE VIEW vdAc
AS
	SELECT 
		*
		-- [dbo].[fnAccount_getDebit]([GUID], [CurrencyGUID]) AS [CalcDebit],
		-- [dbo].[fnAccount_getCredit]([GUID], [CurrencyGUID]) AS [CalcCredit]
	FROM 
		[vbAc]
###########################################################################
CREATE VIEW vdAc_WithoutPOSSDAcc
AS

	SELECT 
		AC.*
	FROM 
		[vbAc] AC
		LEFT JOIN POSSDStation000 ShiftControlAcc  ON AC.[GUID] = ShiftControlAcc.ShiftControlGUID
		LEFT JOIN POSSDStation000 ContinuesCashAcc ON AC.[GUID] = ContinuesCashAcc.ContinuesCashGUID
	WHERE 
		ShiftControlAcc.ShiftControlGUID   IS NULL
	AND ContinuesCashAcc.ContinuesCashGUID IS NULL
###########################################################################
CREATE VIEW vCollectionAcc
AS
	SELECT * FROM vdAc
	WHERE GUID in (SELECT [CollectionAccGUID] FROM ChequesPortfolio000)
###########################################################################
CREATE VIEW vEndorsementAcc
AS
	SELECT * FROM vdAc
	WHERE GUID in (SELECT [EndorsementAccGUID] FROM ChequesPortfolio000)
###########################################################################
CREATE VIEW vDiscountingAcc
AS
	SELECT * FROM vdAc
	WHERE GUID in (SELECT [DiscountingAccGUID] FROM ChequesPortfolio000)
###########################################################################
CREATE VIEW vUnderDiscountingAcc
AS
	SELECT * FROM vdAc
	WHERE GUID in (SELECT [UnderDiscountingAccGUID] FROM ChequesPortfolio000)
###########################################################################
CREATE VIEW vReceivePayAcc
AS
	SELECT * FROM vdAc
	WHERE GUID in (SELECT [ReceivePayAccGUID] FROM ChequesPortfolio000)
###########################################################################
CREATE VIEW vReceiveAcc
AS
	SELECT * FROM vdAc
	WHERE GUID in (SELECT [ReceiveAccGUID] FROM ChequesPortfolio000)
###########################################################################
CREATE VIEW vPayAcc
AS
	SELECT * FROM vdAc
	WHERE GUID in (SELECT  [PayAccGUID] FROM ChequesPortfolio000)

###########################################################################
CREATE VIEW  vCommChargeAcc
AS
	SELECT * FROM vdAc
	WHERE GUID not  in 
	(
		SELECT [ReceiveAccGUID] FROM ChequesPortfolio000 WHERE [ReceiveAccGUID] is not null
		
		UNION
		SELECT  [PayAccGUID] FROM ChequesPortfolio000 WHERE [PayAccGUID] is not null
		UNION
		SELECT [UnderDiscountingAccGUID] FROM ChequesPortfolio000  WHERE [UnderDiscountingAccGUID] is not null
		UNION
		SELECT [DiscountingAccGUID] FROM ChequesPortfolio000 WHERE [DiscountingAccGUID] is not null
		UNION
		SELECT [EndorsementAccGUID] FROM ChequesPortfolio000 WHERE [EndorsementAccGUID] is not null
		UNION
		SELECT [CollectionAccGUID] FROM ChequesPortfolio000  WHERE [CollectionAccGUID] is not null

	  )
###########################################################################
CREATE VIEW  vAccWithoutPort
AS
	SELECT * FROM vdAc
	WHERE GUID not  in 
	(
		SELECT [ReceiveAccGUID] FROM ChequesPortfolio000 WHERE [ReceiveAccGUID] is not null
		
		UNION
		SELECT  [PayAccGUID] FROM ChequesPortfolio000 WHERE [PayAccGUID] is not null
		UNION
		SELECT [UnderDiscountingAccGUID] FROM ChequesPortfolio000  WHERE [UnderDiscountingAccGUID] is not null
		UNION
		SELECT [DiscountingAccGUID] FROM ChequesPortfolio000 WHERE [DiscountingAccGUID] is not null
		UNION
		SELECT [EndorsementAccGUID] FROM ChequesPortfolio000 WHERE [EndorsementAccGUID] is not null
		UNION
		SELECT [CollectionAccGUID] FROM ChequesPortfolio000  WHERE [CollectionAccGUID] is not null
		UNION
		SELECT [ReceivePayAccGUID] FROM ChequesPortfolio000  WHERE [ReceivePayAccGUID] is not null
)
###############################################################################
CREATE VIEW vwPortfolioChequesAcCu
AS
	SELECT 
		AC.*
	FROM 
		vwAcCu AC
		LEFT JOIN POSSDStation000 ShiftControlAcc  ON AC.[GUID] = ShiftControlAcc.ShiftControlGUID
		LEFT JOIN POSSDStation000 ContinuesCashAcc ON AC.[GUID] = ContinuesCashAcc.ContinuesCashGUID
	WHERE 
		ShiftControlAcc.ShiftControlGUID IS NULL
		AND ContinuesCashAcc.ContinuesCashGUID IS NULL
###############################################################################
#END