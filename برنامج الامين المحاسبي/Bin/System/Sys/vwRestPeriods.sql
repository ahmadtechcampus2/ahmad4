###########################################################################
CREATE VIEW vwRestPeriods
AS
SELECT us.[GUID] usID, us.LoginName usName, p.Number, p.[Guid] ID, p.IsClosed Closed, p.IsOpend Opened, p.StartTime, p.ClosedTime FROM us000 us
	INNER JOIN RestPeriod000 p ON p.UserID=us.[GUID]
###########################################################################
CREATE VIEW vwRestClosedPeriods
AS
SELECT us.[GUID] usID, us.LoginName usName, p.Number, p.[Guid] ID, p.IsClosed Closed, p.IsOpend Opened, p.StartTime, p.ClosedTime FROM us000 us
	INNER JOIN RestPeriod000 p ON p.UserID=us.[GUID] 
WHERE  p.IsClosed = 1
###########################################################################
#END