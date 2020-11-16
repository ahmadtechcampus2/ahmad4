######################################################
CREATE function fnPOSGetVoucherCheck (@type UNIQUEIDENTIFIER)
	RETURNS TABLE
AS
	RETURN (
		SELECT 
			Num, 
			GUID,
			CAST(YEAR([Date]) AS NVARCHAR(4)) +'-'+ CAST(MONTH([Date]) AS NVARCHAR(2)) +'-'+  CAST(Day([Date]) AS NVARCHAR(2)) AS DateString,
			Val / (CASE CurrencyVal WHEN 0 THEN 1 ELSE CurrencyVal END) AS [Value]  
		FROM 
			ch000 ch
		WHERE 
			[State] = 0 
			AND 
			Dir = 2 
			AND 
			TypeGUID = @type
			AND 
			NOT EXISTS (
				SELECT 1 
				FROM 
					POSPaymentsPackage000 pak
					INNER JOIN POSOrder000 o ON pak.GUID = o.PaymentsPackageID
				WHERE 
					pak.ReturnVoucherID = ch.GUID)
		)
######################################################
#END