############################################################
CREATE FUNCTION fnDateString( @Date AS [DATETIME]) 
	RETURNS [NVARCHAR](25)
AS 
BEGIN  
	RETURN '''' + CAST( MONTH( @Date) AS [NVARCHAR](5)) + '/' + CAST( DATEPART ( DAY , @Date ) AS [NVARCHAR](5))+ '/' + CAST( YEAR( @Date) AS [NVARCHAR](10)) + ' ' + CAST( DATEPART(HH, @Date) AS [NVARCHAR](10)) + ':' + CAST( DATEPART(mi, @Date) AS [NVARCHAR](10))+ ':' + CAST( DATEPART(SS, @Date) AS [NVARCHAR](10))+ '.' + CAST( DATEPART(ms, @Date) AS [NVARCHAR](10)) +  ''''
END 
############################################################
#END  