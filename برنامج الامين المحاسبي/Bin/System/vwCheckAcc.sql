#########################################################
CREATE VIEW vwCheckAcc
AS
SELECT ca.* FROM CheckAcc000 ca
INNER JOIN vwAc ac ON ac.acGUID = ca.AccGUID
#########################################################
#END
