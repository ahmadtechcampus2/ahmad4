#########################################################
CREATE VIEW vwBp_SumPay
AS
	SELECT 
		[bpPayGUID],
		SUM([bpPayVal]) AS [bpVal]
	FROM 
		[vwBp]
	WHERE BpTYPE <> 4--„‰ «Ã· ·« Ì ﬂ—— Ã„⁄ «‰⁄ﬂ«”  ›Ê« Ì— «·ÿ·»Ì« 
	GROUP BY
		[bpPayGUID]
#########################################################
CREATE VIEW vwBp_SumDebt
AS
	SELECT 
		[BpDebtGUID],
		SUM([bpVal]) AS [bpVal]
	FROM 
		[vwBp]
	WHERE BpTYPE <> 4--„‰ «Ã· ·« Ì ﬂ—— Ã„⁄ «‰⁄ﬂ«” ›Ê« Ì— «·ÿ·»Ì« 
	GROUP BY
		[bpDebtGUID]
#########################################################
#END