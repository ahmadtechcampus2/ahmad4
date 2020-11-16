#########################################################
CREATE VIEW vwGrBr
AS
SELECT * FROM
vwGr inner join vwbr ON (POWER(2, vwbr.brNumber-1) &  vwGr.grBranchMask) >0
#########################################################
#END