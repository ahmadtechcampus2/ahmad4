######################################################### 
create function fnDatabase_size()
	returns [nvarchar](50)
as begin
	return (select CAST(CAST((SELECT SUM([size]) * 8.0 / 1024.0 FROM [sysfiles]) AS [DECIMAL](12, 2)) AS [NVARCHAR](50)) + ' mb' )
end

#########################################################
#END