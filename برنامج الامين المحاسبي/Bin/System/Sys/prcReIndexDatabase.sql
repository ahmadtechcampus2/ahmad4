##########################################################################
CREATE PROCEDURE prcReIndexDatabase
AS 
    DECLARE @DBName      NVARCHAR(255) = DB_NAME(),
                    @TableName    NVARCHAR(255),
                    @SchemaName NVARCHAR(255),
                    @IndexName    NVARCHAR(255),
                    @PctFrag      DECIMAL,
                    @Defrag       NVARCHAR(MAX),
                    @id                  INT

                    IF EXISTS ( SELECT 1
                                        FROM sys.objects
                                        WHERE object_id = OBJECT_ID(N'#Frag') )
                        DROP TABLE #Frag ;
                           
    CREATE TABLE #Frag
            (id                  INT identity (1,1),
            TableName     NVARCHAR(255),
            SchemaName    NVARCHAR(255),
            IndexName     NVARCHAR(255),
            AvgFragment DECIMAL
            )
              
            SET @Defrag = 
            'INSERT INTO #Frag ( TableName, SchemaName, IndexName, AvgFragment ) 
            SELECT t.Name AS TableName ,sc.Name AS SchemaName ,i.name AS IndexName ,s.avg_fragmentation_in_percent 
            FROM sys.dm_db_index_physical_stats(DB_ID('''+ @DBName + '''), NULL, NULL, NULL, ''Sampled'') AS s 
            JOIN sys.indexes i ON s.Object_Id = i.Object_id AND s.Index_id = i.Index_id 
            JOIN sys.tables t ON i.Object_id = t.Object_Id 
            JOIN sys.schemas sc ON t.schema_id = sc.SCHEMA_ID
            WHERE s.avg_fragmentation_in_percent > 20
            AND t.TYPE = ''U''
            ORDER BY TableName,IndexName' ;

            EXEC sp_executesql @Defrag 

            WHILE EXISTS (SELECT 1 FROM #Frag)
            BEGIN
                    SELECT TOP 1 @id = id, 
                                        @TableName = TableName, 
                                        @SchemaName = SchemaName, 
                                        @IndexName = IndexName, 
                                        @PctFrag = AvgFragment
                    FROM #Frag
					
					IF @PctFrag BETWEEN 20.0 AND 40.0
                    BEGIN
                        SET @Defrag = N'ALTER INDEX ' + @IndexName + ' ON [' + @DBName
                                + '].' + @SchemaName + '.' + @TableName + ' REORGANIZE' ;
                        EXEC sp_executesql @Defrag;
                    END
                    ELSE
                    IF @PctFrag > 40.0
                    BEGIN
                        SET @Defrag = N'ALTER INDEX ' + @IndexName + ' ON ['
                                + @DBName + '].' + @SchemaName + '.' + @TableName
                                + ' REBUILD' ;
                        EXEC sp_executesql @Defrag ;
                    END

                    DELETE #Frag WHERE id = @id
            END
    DROP TABLE #Frag ;
##########################################################################
CREATE PROCEDURE prcPostReindex
AS
	SET NOCOUNT ON
	
	/*
		ReCreate MatExBarcode000 unique index
	*/
	DECLARE @sql NVARCHAR(MAX);

	SET @sql = N'ALTER TABLE MatExBarcode000 ADD CONSTRAINT barcode_uniqueConstraint UNIQUE NONCLUSTERED (';
	IF [dbo].[fnOption_GetInt]('AmnCfg_MatUniqueBarcode', '0') = 1 
		SET @sql = @sql + N'Barcode)';
	ELSE
		SET @sql = @sql + N'Barcode, MatGuid)';

	EXEC(@sql);
##########################################################################
#END