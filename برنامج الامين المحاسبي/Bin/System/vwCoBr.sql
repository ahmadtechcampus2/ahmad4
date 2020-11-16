#########################################################
CREATE VIEW vwCoBr
AS
SELECT * FROM
vwCo inner join vwbr ON (POWER(2, vwbr.brNumber-1) &  vwCo.coBranchMask) >0
#########################################################
#END