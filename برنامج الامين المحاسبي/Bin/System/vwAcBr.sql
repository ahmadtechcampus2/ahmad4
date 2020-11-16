#########################################################
CREATE VIEW vwAcBr
AS
SELECT * FROM
vwAc inner join vwbr ON (POWER(2, vwbr.brNumber-1) &  vwAc.acBranchMask) >0
#########################################################
#END