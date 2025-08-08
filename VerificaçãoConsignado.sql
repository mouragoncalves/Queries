    DECLARE @RelatedYear INT = 2025, @RelatedMonth INT = 6;

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
    ), Events_EConsignado AS (
        SELECT top 1  * 
        FROM Events_S1200
        WHERE ContentXML.exist('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha') = 1
    )
    SELECT 
        EventId, RelatedYear, RelatedMonth, ContentXML 
    INTO #EventsToUpdate
    FROM Events_S1200

    SELECT eu.EventId, eu.OrdemDescFolha, eu.PosicaoDmDev, eu.PosicaoItensRemunNoDmDev--, wc.*
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