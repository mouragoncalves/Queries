BEGIN TRANSACTION;

    DECLARE @RelatedYear INT = 2025, @RelatedMonth INT = 8;

    DROP TABLE IF EXISTS #EventsToUpdate;
    DROP TABLE IF EXISTS #Events_WithCredits;

    WITH Events_S1200 AS (
        SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, CONVERT(XML, c.Content) ContentXML
        FROM Event e 
        JOIN XMLContent c ON c.ReferenceId = e.Id
        WHERE e.EventTypeEnum = 8
            AND e.RelatedYear = @RelatedYear
            AND e.RelatedMonth = @RelatedMonth
            AND e.EventStatusEnum <= 7
            AND c.ContentReferenceEnum = 0
            AND e.Id = 18338850
    ), Events_EConsignado AS (
        SELECT *--top 1 * 
        FROM Events_S1200
        WHERE ContentXML.exist('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha') = 1
    )
    SELECT 
        EventId, RelatedYear, RelatedMonth, ContentXML 
    INTO #EventsToUpdate
    FROM Events_S1200

    SELECT eu.EventId, eu.OrdemDescFolha, PosicaoDmDev, PosicaoItensRemunNoDmDev, wc.*
    --INTO #Events_WithCredits
    FROM (
        SELECT 
            EventId,
            t.n.value('(../../matricula)[1]', 'varchar(50)') AS Matricula,
            t.n.value('(../../../nrInsc)[1]', 'varchar(14)') AS Estabelecimento,
            t.n.value('(../codRubr)[1]', 'varchar(10)') AS CodigoRubrica,
            t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF,
            ROW_NUMBER() OVER (PARTITION BY EventId ORDER BY (SELECT NULL)) AS OrdemDescFolha,
            DENSE_RANK() OVER (
                PARTITION BY EventId 
                ORDER BY t.n.value('(../../../nrInsc)[1]', 'varchar(14)'), 
                        t.n.value('(../../matricula)[1]', 'varchar(50)')
            ) AS PosicaoDmDev,
            ROW_NUMBER() OVER (
                PARTITION BY EventId,
                            t.n.value('(../../../nrInsc)[1]', 'varchar(14)'), 
                            t.n.value('(../../matricula)[1]', 'varchar(50)')
                ORDER BY t.n.value('(../codRubr)[1]', 'varchar(10)')
            ) AS PosicaoItensRemunNoDmDev
        FROM #EventsToUpdate
        CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
    ) eu
    LEFT JOIN WorkerCredit wc ON wc.Matricula = eu.Matricula 
        AND wc.Competencia = RIGHT(CONCAT('0', @RelatedMonth, '/', @RelatedYear), 7)

    DECLARE @EventId INT, @XML XML;
    DECLARE events_cursor CURSOR FOR
    SELECT DISTINCT EventId 
    FROM #EventsToUpdate;

    OPEN events_cursor;
    FETCH NEXT FROM events_cursor INTO @EventId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Obter o XML atual
        SELECT @XML = ContentXML 
        FROM #EventsToUpdate 
        WHERE EventId = @EventId;
        
        -- Processar cada descFolha deste evento
        DECLARE @Posicao INT, @InstFinanc VARCHAR(3), @NrDoc VARCHAR(60);
        DECLARE descfolha_cursor CURSOR FOR
        SELECT OrdemDescFolha, IfConcessoraCodigo NovoInstFinanc, Contrato NovoNrDoc
        FROM #Events_WithCredits
        WHERE EventId = @EventId;
        
        OPEN descfolha_cursor;
        FETCH NEXT FROM descfolha_cursor INTO @Posicao, @InstFinanc, @NrDoc;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @XML.modify('delete (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha)[sql:variable("@Posicao")]/instFinanc');
            SET @XML.modify('delete (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha)[sql:variable("@Posicao")]/nrDoc');
            
            DECLARE @InstFinancXML XML = '<instFinanc>' + @InstFinanc + '</instFinanc>';
            DECLARE @NrDocXML XML = '<nrDoc>' + @NrDoc + '</nrDoc>';
            
            SET @InstFinancXML = '<instFinanc>' + @InstFinanc + '</instFinanc>';

            SET @XML.modify('
                insert sql:variable("@InstFinancXML")
                as last into (/eSocial/evtRemun/dmDev)[sql:variable("@PosicaoDmDev")]/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha][sql:variable("@PosicaoItens")]/descFolha[1]
            ');
            
            SET @XML.modify('
                insert sql:variable("@NrDocXML")
                as last into (/eSocial/evtRemun/dmDev)[sql:variable("@PosicaoDmDev")]/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha][sql:variable("@PosicaoItens")]/descFolha[1]
            ');

            -- SET @XML.modify('insert sql:variable("@InstFinancXML") as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha)[sql:variable("@Posicao")]');
            -- SET @XML.modify('insert sql:variable("@NrDocXML") as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha)[sql:variable("@Posicao")]');
            
            FETCH NEXT FROM descfolha_cursor INTO @Posicao, @InstFinanc, @NrDoc;
        END
        
        CLOSE descfolha_cursor;
        DEALLOCATE descfolha_cursor;
        SELECT @XML;
        -- Atualizar o XML no banco
        UPDATE XMLContent
        SET Content = CONVERT(NVARCHAR(MAX), @XML)
        WHERE ReferenceId = @EventId AND ContentReferenceEnum = 0;
        
        FETCH NEXT FROM events_cursor INTO @EventId;
    END

    CLOSE events_cursor;
    DEALLOCATE events_cursor;

    SELECT * FROM #EventsToUpdate;

    -- Limpar tabelas temporárias
    DROP TABLE #Events_WithCredits;
    DROP TABLE #EventsToUpdate;

ROLLBACK TRANSACTION;