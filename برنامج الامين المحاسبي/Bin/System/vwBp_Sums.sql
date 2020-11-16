#########################################################
CREATE VIEW vwBp_SumPay
AS
	SELECT 
		[bpPayGUID],
		SUM([bpPayVal]) AS [bpVal]
	FROM 
		[vwBp]
	WHERE BpTYPE <> 4--�� ��� �� ����� ��� ������  ������ ��������
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
	WHERE BpTYPE <> 4--�� ��� �� ����� ��� ������ ������ ��������
	GROUP BY
		[bpDebtGUID]
#########################################################
#END