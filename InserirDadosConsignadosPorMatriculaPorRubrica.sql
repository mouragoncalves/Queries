-- SELECT * FROM XMLContent WHERE ReferenceId = 18338850

DECLARE @RelatedYear INT = 2025, @RelatedMonth INT = 7;

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
        AND e.Id = 18410586
), Events_EConsignado AS (
    SELECT *--top 1 * 
    FROM Events_S1200
    WHERE ContentXML.exist('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha') = 1
)
SELECT 
    EventId, RelatedYear, RelatedMonth, ContentXML 
INTO #EventsToUpdate
FROM Events_S1200

SELECT eu.EventId, wc.*
INTO #Events_WithCredits
FROM (
    SELECT 
        EventId,
        t.n.value('(../../matricula)[1]', 'varchar(50)') AS Matricula,
        t.n.value('(../../../nrInsc)[1]', 'varchar(14)') AS Estabelecimento,
        t.n.value('(../codRubr)[1]', 'varchar(10)') AS CodigoRubrica,
        t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF
        -- ROW_NUMBER() OVER (PARTITION BY EventId ORDER BY (SELECT NULL)) AS OrdemDescFolha,
        -- DENSE_RANK() OVER (
        --     PARTITION BY EventId 
        --     ORDER BY t.n.value('(../../../nrInsc)[1]', 'varchar(14)'), 
        --             t.n.value('(../../matricula)[1]', 'varchar(50)')
        -- ) AS PosicaoDmDev
        -- ROW_NUMBER() OVER (
        --     PARTITION BY EventId,
        --                 t.n.value('(../../../nrInsc)[1]', 'varchar(14)'), 
        --                 t.n.value('(../../matricula)[1]', 'varchar(50)')
        --     ORDER BY t.n.value('(../codRubr)[1]', 'varchar(10)')
        -- ) AS PosicaoItensRemunNoDmDev
    FROM #EventsToUpdate
    CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
) eu
JOIN WorkerCredit wc ON wc.Matricula = eu.Matricula AND wc.Rubrica = eu.CodigoRubrica
    AND wc.Competencia = RIGHT(CONCAT('0', @RelatedMonth, '/', @RelatedYear), 7)

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
        DECLARE @InstFinancXML XML = '<instFinanc>' + @InstFinanc + '</instFinanc>', @ContratoXML XML = '<nrDoc>' + @NrContrato + '</nrDoc>';
        
        SET @XML.modify('
            delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@Matricula")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/instFinanc
        ');
        
        SET @XML.modify('
            delete /eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@Matricula")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha/nrDoc
        ');

        SET @XML.modify('
            insert sql:variable("@InstFinancXML")
            as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@Matricula")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]
        ');
        
        SET @XML.modify('
            insert sql:variable("@ContratoXML")
            as last into (/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur[matricula=sql:variable("@Matricula")]/itensRemun[codRubr=sql:variable("@Rubrica")]/descFolha)[1]
        ');

        -- SELECT @XML;

        FETCH NEXT FROM descfolha_cursor INTO @InstFinanc, @NrContrato, @Matricula, @Rubrica;
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

--SELECT * FROM #EventsToUpdate;

-- Limpar tabelas temporárias
DROP TABLE #Events_WithCredits;
DROP TABLE #EventsToUpdate;