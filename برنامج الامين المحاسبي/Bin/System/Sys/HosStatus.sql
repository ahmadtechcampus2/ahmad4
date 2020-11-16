##################################################################################
CREATE FUNCTION fnHosStatus ( @Type INT )
RETURNS TABLE 
RETURN SELECT * FROM HosSiteStatus000 WHERE Type = @Type
##################################################################################
#END
