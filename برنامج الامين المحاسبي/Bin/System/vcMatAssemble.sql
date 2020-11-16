#####################################################
CREATE VIEW vcMatAssemble
AS
	SELECT * FROM [vdMt2] WHERE [Assemble] = 1
#######################################################
CREATE VIEW vcMatNotAssemble
AS
	SELECT * FROM [vdMt2] WHERE [Assemble] = 0
#######################################################
#END