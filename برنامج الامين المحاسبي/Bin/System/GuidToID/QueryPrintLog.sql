select 
	number, Printed, Duration, Duration2, p2Printed
FROM 
	[LogDB]..[vwPrintLogEx]
ORDER BY 
	--LEFT(Printed, 15), 
	number DESC
