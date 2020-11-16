#######################################################
CREATE VIEW vwlg
AS 
	SELECT * FROM [lg000]

#######################################################
CREATE VIEW vwlog
AS 
	SELECT * FROM [log000] WHERE OperationType <> 100

#######################################################
#END