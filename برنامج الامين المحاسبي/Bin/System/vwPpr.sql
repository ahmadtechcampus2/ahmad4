#########################################################
CREATE  VIEW vwPpr
AS
SELECT
	[GUID]			AS [GUID],
	[Number]		AS [Number],	
	[Type]			AS [Type],
	[Date]			AS [PprDate],
	[Notes]			AS [PprNotes],
	[CurrencyGUID]	AS [PprCurrencyGUID],
	[CurrencyVal]	AS [PprCurrencyVal],
	[FromAccGUID]	AS [PprFromAccGUID],
	[ToAccGUID]		AS [PprToAccGUID],
	[Total]			AS [PprTotal],
	[Security]		AS [PprSecurity],
	[BranchGUID]	AS [PprBranchGUID]
FROM
	[Ppr000]
#########################################################

CREATE  VIEW vwPprEn
AS
SELECT 
	distinct [ppr].[guid], 
	[ppr].[Number],	
	[ppr].[Type],
	[ppr].[PPrDate],
	[ppr].[PPrNotes],
	[ppr].[PPrCurrencyGUID],
	[ppr].[PPrCurrencyVal],
	[ppr].[PPrFromAccGUID],
	[ppr].[PPrToAccGUID],
	[ppr].[PPrTotal],
	[ppr].[PPrSecurity], 
	[PPr].[PPrBranchGUID],
	[enClass],
	[enVendor],
	[enSalesMan],
	[CeGUID],
	[CeNumber]
 FROM 
	[vwPpr] [ppr] 
	INNER JOIN [vwer]	ON [ppr].[Guid] = [erParentGUID]
	INNER JOIN [vwCeEn] ON [CeGUID] = [erEntryGUID]
	
#########################################################
CREATE VIEW vwPprGetReceivable
AS
	SELECT 
		* 
	FROM 
		[vwPprEn]
	WHERE 
		[Type] = 1

#########################################################		
CREATE VIEW vwPprGetPayable
AS
	SELECT 
		* 
	FROM 
		[vwPprEn]
	WHERE 
		[Type] = 2

#########################################################
#END