-- SET ANSI_NULLS ON
-- GO
-- SET QUOTED_IDENTIFIER ON
-- GO
-- CREATE OR ALTER PROCEDURE [dbo].[sp_ProcessarEventosXML]
--     @EventIds VARCHAR(MAX)
-- AS
-- BEGIN
    DECLARE @EventIds VARCHAR(MAX) = '18476693'

    DROP TABLE IF EXISTS #EventsToUpdate;
    DROP TABLE IF EXISTS #Events_WithCredits;

    WITH Events_S1200 AS (
        SELECT 
            e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, CONVERT(XML, c.Content) ContentXML
        FROM Event e 
        JOIN XMLContent c ON c.ReferenceId = e.Id
        WHERE e.Id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@EventIds, ','))
            -- AND e.EventStatusEnum = 0
            AND c.ContentReferenceEnum = 0
    ), Events_EConsignado AS (
        SELECT 
            *
        FROM Events_S1200
        WHERE ContentXML.value('count(/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha)', 'int') > 0
    )
    SELECT 
        EventId, RelatedYear, RelatedMonth, ContentXML 
    INTO #EventsToUpdate
    FROM Events_S1200

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
    JOIN WorkerCredit wc ON wc.Matricula = eu.Matricula AND wc.Rubrica = eu.CodigoRubrica
        AND wc.Competencia = RIGHT(CONCAT('0', eu.RelatedMonth, '/', eu.RelatedYear), 7)

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
        
        DECLARE @Matricula VARCHAR(50), @Rubrica VARCHAR(10), @InstFinanc VARCHAR(3), @NrContrato VARCHAR(50), @MatriculaControle VARCHAR(50);
        
        DECLARE descfolha_cursor CURSOR FOR
        SELECT IfConcessoraCodigo, Contrato, Matricula, Rubrica
        FROM #Events_WithCredits
        WHERE EventId = @EventId;
        
        OPEN descfolha_cursor;
        FETCH NEXT FROM descfolha_cursor INTO @InstFinanc, @NrContrato, @Matricula, @Rubrica;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @MatriculaControle = UPPER(REPLACE(@Matricula, '_', ''))

            DECLARE @InstFinancXML XML = '<instFinanc>' + RIGHT('00' + @InstFinanc, 3) + '</instFinanc>', @ContratoXML XML = '<nrDoc>' + @NrContrato + '</nrDoc>';
            
            SELECT @InstFinanc InstFinanc, @NrContrato Contrato, @Matricula Matricula, @MatriculaControle Controle, @Rubrica, @XML ContentXML
            
            IF (@XML.value('count(/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha)', 'int') = 1)
            BEGIN
                SET @XML.modify('delete //itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/instFinanc')
                SET @XML.modify('delete //itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/nrDoc')

                SET @XML.modify('insert sql:variable("@InstFinancXML") as last into (//itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]')
                SET @XML.modify('insert sql:variable("@ContratoXML") as last into (//itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]')
            END
            ELSE
            BEGIN
                -- SET @XML.modify('
                --     replace value of (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/matricula/text())[1] 
                --     with fn:upper-case((/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/matricula/text())[1])
                -- ');
                
                SET @XML.modify('
                    replace value of (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/matricula/text())[1] 
                    with sql:variable("@MatriculaControle")
                ');

                -- SELECT @XML
                
                SET @XML.modify('
                    delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaControle")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/instFinanc
                ');
                
                SET @XML.modify('
                    delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaControle")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/nrDoc
                ');

                SET @XML.modify('
                    insert sql:variable("@InstFinancXML")
                    as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaControle")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]
                ');
                
                SET @XML.modify('
                    insert sql:variable("@ContratoXML")
                    as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@MatriculaControle")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]
                ');

                -- SET @XML.modify('
                --     replace value of (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/matricula/text())[1] 
                --     with fn:upper-case(sql:variable("@Matricula"))
                -- ');

                SELECT @XML NewContentXML
            END

            FETCH NEXT FROM descfolha_cursor INTO @InstFinanc, @NrContrato, @Matricula, @Rubrica;
        END
        
        CLOSE descfolha_cursor;
        DEALLOCATE descfolha_cursor;
        
        -- UPDATE XMLContent
        -- SET Content = CONVERT(NVARCHAR(MAX), @XML)
        -- WHERE ReferenceId = @EventId AND ContentReferenceEnum = 0;

        -- SELECT @xml
        
        FETCH NEXT FROM events_cursor INTO @EventId;
    END

    CLOSE events_cursor;
    DEALLOCATE events_cursor;
    
    DROP TABLE #Events_WithCredits;
    DROP TABLE #EventsToUpdate;
-- END
-- GO
