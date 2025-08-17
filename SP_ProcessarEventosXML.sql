SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_ProcessarEventosXML]
    @EventIds VARCHAR(MAX)
AS
BEGIN
    DROP TABLE IF EXISTS #EventsToUpdate;
    DROP TABLE IF EXISTS #Events_WithCredits;

    WITH Events AS (
        SELECT 
            e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, CONVERT(XML, c.Content) ContentXML
        FROM Event e 
        JOIN XMLContent c ON c.ReferenceId = e.Id
        WHERE e.EventTypeEnum = 8
            AND e.Id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@EventIds, ','))
            AND e.EventStatusEnum = 0
            AND c.ContentReferenceEnum = 0
    ), Events_EConsignado AS (
        SELECT 
            *
        FROM Events
        WHERE ContentXML.value('count(/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha)', 'int') > 0
    )
    SELECT 
        EventId, RelatedYear, RelatedMonth, ContentXML 
    INTO #EventsToUpdate
    FROM Events;

    SELECT eu.EventId, wc.*
    INTO #Events_WithCredits
    FROM (
        SELECT 
            EventId, RelatedYear, RelatedMonth,
            t.n.value('(../../matricula)[1]', 'varchar(50)') AS Matricula,
            t.n.value('(../../../nrInsc)[1]', 'varchar(14)') AS Estabelecimento,
            t.n.value('(../codRubr)[1]', 'varchar(10)') AS CodigoRubrica,
            t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF
        FROM #EventsToUpdate
        CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
    ) eu
    JOIN WorkerCredit wc ON UPPER(wc.Matricula) = UPPER(eu.Matricula) AND wc.Rubrica = eu.CodigoRubrica
        AND wc.Competencia = RIGHT(CONCAT('0', eu.RelatedMonth, '/', eu.RelatedYear), 7);

    DECLARE @EventId INT, @XML XML;
    DECLARE events_cursor CURSOR FOR
    SELECT DISTINCT EventId 
    FROM #EventsToUpdate;

    OPEN events_cursor;
    FETCH NEXT FROM events_cursor INTO @EventId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @XML = ContentXML 
        FROM #EventsToUpdate 
        WHERE EventId = @EventId;
        
        DECLARE @Matricula VARCHAR(50), @Rubrica VARCHAR(10), @InstFinanc VARCHAR(3), @NrContrato VARCHAR(50);
        
        DECLARE descfolha_cursor CURSOR FOR
        SELECT IfConcessoraCodigo, Contrato, Matricula, Rubrica
        FROM #Events_WithCredits
        WHERE EventId = @EventId;
        
        OPEN descfolha_cursor;
        FETCH NEXT FROM descfolha_cursor INTO @InstFinanc, @NrContrato, @Matricula, @Rubrica;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @InstFinanc = ISNULL(@InstFinanc, '');
            SET @NrContrato = ISNULL(@NrContrato, '');
            
            DECLARE @InstFinancXML XML = '<instFinanc>' + RIGHT('000' + @InstFinanc, 3) + '</instFinanc>';
            DECLARE @ContratoXML XML = '<nrDoc>' + @NrContrato + '</nrDoc>';
            
            DECLARE @MatriculaUpper VARCHAR(50) = UPPER(@Matricula);
            
            DECLARE @MatriculaXML VARCHAR(50);
            SELECT @MatriculaXML = t.n.value('.', 'varchar(50)')
            FROM @XML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/matricula') AS t(n)
            WHERE UPPER(t.n.value('.', 'varchar(50)')) = @MatriculaUpper;
            
            DECLARE @DescFolhaCount INT = 0;
            IF @MatriculaXML IS NOT NULL
            BEGIN
                SET @DescFolhaCount = @XML.value(
                    'count(/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaXML")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)', 
                    'int'
                );
            END
            
            IF @DescFolhaCount > 0 AND @MatriculaXML IS NOT NULL
            BEGIN
                SET @XML.modify('
                    delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaXML")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/instFinanc
                ');
                
                SET @XML.modify('
                    delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaXML")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/nrDoc
                ');

                SET @XML.modify('
                    insert sql:variable("@InstFinancXML")
                    as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaXML")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]
                ');
                
                SET @XML.modify('
                    insert sql:variable("@ContratoXML")
                    as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaXML")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]
                ');
            END
            ELSE
            BEGIN
                IF @MatriculaXML IS NOT NULL
                BEGIN
                    DECLARE @AvisoXML XML = '<observacao>AVISO: Dados do credito nao encontrados na WorkerCredit para Matricula: ' + @Matricula + ', Rubrica: ' + @Rubrica + '</observacao>';
                    
                    SET @XML.modify('
                        delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaXML")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/observacao
                    ');
                    
                    SET @XML.modify('
                        insert sql:variable("@AvisoXML")
                        as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaXML")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]
                    ');
                END
            END

            FETCH NEXT FROM descfolha_cursor INTO @InstFinanc, @NrContrato, @Matricula, @Rubrica;
        END
        
        CLOSE descfolha_cursor;
        DEALLOCATE descfolha_cursor;
        
        UPDATE XMLContent
        SET Content = CONVERT(NVARCHAR(MAX), @XML)
        WHERE ReferenceId = @EventId AND ContentReferenceEnum = 0;
        
        FETCH NEXT FROM events_cursor INTO @EventId;
    END

    CLOSE events_cursor;
    DEALLOCATE events_cursor;

    DROP TABLE #Events_WithCredits;
    DROP TABLE #EventsToUpdate;
END
GO
