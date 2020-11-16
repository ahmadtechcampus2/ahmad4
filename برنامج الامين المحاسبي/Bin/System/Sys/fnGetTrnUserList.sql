##############################################
CREATE FUNCTION fnGetTrnUserList ( @Sorted [INT] = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)   
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], 
	[Level] [INT] DEFAULT 0, 
	[Path] [NVARCHAR] (1000) COLLATE ARABIC_CI_AI, 
	[Name] [NVARCHAR] (100) COLLATE ARABIC_CI_AI ,
	Code [NVARCHAR] (200) COLLATE ARABIC_CI_AI,
	ParentGuid	[UNIQUEIDENTIFIER],	
	[ID] [INT] IDENTITY( 1, 1))    
AS 
BEGIN   
	 
	 
		DECLARE  @Continue_S [INT], @Level_S [INT]   
		SET @Level_S = 0     
		   
		INSERT INTO @Result ( [GUID], [Level], [Path], [Name], [Code], ParentGuid) 
			SELECT GUID, 0, '', [Name], [Code], 0x0
			FROM TrnBranch000
			ORDER BY CASE @Sorted WHEN 1 THEN [Code] ELSE [Name] END   
		
		UPDATE @Result  SET [Path] = CAST( ( 0.0000001 * ID) AS [NVARCHAR](40))    
	   
		INSERT INTO @Result ( [GUID], [Level], [Path], [Name], [Code], ParentGuid)
			SELECT Center.GUID, 1, Parent.Path, Center.[Name], Center.[Code], Parent.GUID
			FROM TrnCenter000 AS Center
				INNER JOIN @Result AS Parent ON Parent.GUID = Center.BranchGuid
			ORDER BY CASE @Sorted WHEN 1 THEN Center.[Code] ELSE Center.[Name] END   
			
		UPDATE @Result  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS [NVARCHAR](40))    
	    WHERE [Level] = 1
	    
		INSERT INTO @Result ( [GUID], [Level], [Path], [Name], [Code], ParentGuid) 
			SELECT us.GUID, 2, Parent.Path, us.[LoginName], usconfig.Number, Parent.Guid
			FROM TrnUserConfig000 AS usconfig
				INNER JOIN Us000 AS us ON us.Guid = usconfig.UserGuid 
				INNER JOIN @Result AS Parent ON Parent.GUID = usconfig.CenterGuid
			ORDER BY us.[LoginName]
			
		UPDATE @Result  SET [Path] =  [Path] + CAST( ( 0.0000001 * ID) AS [NVARCHAR](40))    
	    WHERE [Level] = 2
		
	RETURN   
END  
##############################################
CREATE FUNCTION FnTrnState()
RETURNS TABLE 
AS
RETURN 
	(
		SELECT 	-1 AS State, '���� ��� �����' AS [Name], '���� ��� �����' AS Notes
		UNION SELECT 0, '����� �����' , '������' 
		UNION SELECT 1, '������ ��� �����', '��� ������'
		UNION SELECT 2, '������ �� ������', '������'
		UNION SELECT 3, '����� �� �����', '��� ������'
		UNION SELECT 4, '������ ����', '��� ������'
		UNION SELECT 5, '����� ����� �� ������', '������'
		UNION SELECT 6, '����� ����� �� �������', '������'
		UNION SELECT 7, '�� �������', '������'
		UNION SELECT 8, '������ �������', '������'
		UNION SELECT 9, '����� ����', '������'
		UNION SELECT 10, '���� ���� ������', '������'
		UNION SELECT 11, '����� �� ���', '������'
		UNION SELECT 12, '������', '��� ������'
		UNION SELECT 13, '�����', '������'
		UNION SELECT 14, '������ �� ������ �����', '��� ������'
		UNION SELECT 15, '�����', '������'
		UNION SELECT 16, '������', '������'
		UNION SELECT 17, '���� ���� �������', '������'
		UNION SELECT 18, '����� ������', '������'
		UNION SELECT 19, '����� ���� �� ������� ������� ������', '����� ������'
	)
##############################################
#END