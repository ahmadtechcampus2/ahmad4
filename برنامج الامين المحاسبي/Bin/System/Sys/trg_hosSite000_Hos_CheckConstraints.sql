################
CREATE TRIGGER trg_hosSite000_Hos_CheckConstraints
	ON hosSite000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
SET NOCOUNT ON 
############
#END