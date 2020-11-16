#########################################################
CREATE VIEW vwFmBr
AS
SELECT * FROM
vwFm inner join vwbr ON (POWER(2, vwbr.brNumber-1) &  vwFm.fmBranchMask) >0
#########################################################
#END