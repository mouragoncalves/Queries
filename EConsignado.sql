-- EXEC sp_ProcessarEventosXML @EventIds = '18141986'

DECLARE @xml XML;

-- -- Obtém o conteúdo XML da linha específica
SELECT @xml = CAST(Content AS XML)
FROM XMLContent
WHERE ReferenceId = 17978371 AND ContentReferenceEnum = 0;

SELECT @xml.exist('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha')

SELECT @xml.value('count(/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha)', 'int')

SELECT 
    t.n.value('(../../matricula)[1]', 'varchar(50)') AS Matricula,
    t.n.value('(../../../nrInsc)[1]', 'varchar(14)') AS Estabelecimento,
    t.n.value('(../codRubr)[1]', 'varchar(10)') AS CodigoRubrica,
    t.n.value('(../vrRubr)[1]', 'decimal(15,2)') AS ValorRubrica,
    t.n.value('(instFinanc)[1]', 'varchar(10)') AS InstituicaoFinanceira,
    t.n.value('(nrDoc)[1]', 'varchar(50)') AS NumeroDocumento,
    t.n.value('(cnpjDescFolha)[1]', 'varchar(14)') AS CNPJDescFolha,
    t.n.value('(tpDesc)[1]', 'varchar(5)') AS TipoDesconto,
    t.n.value('(observacao)[1]', 'varchar(255)') AS Observacao,
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS OrdemDescFolha
FROM @xml.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
ORDER BY Matricula, CodigoRubrica;
-- -- Aplica a modificação no XML
-- SET @xml.modify('delete //dmDev[not(.//instFinanc[text()])]');

-- -- Atualiza a coluna com o XML modificado convertido de volta para NVARCHAR(MAX)
-- UPDATE XMLContent
-- SET Content = CAST(@xml AS NVARCHAR(MAX))
-- WHERE ReferenceId = 18130922 AND ContentReferenceEnum = 0;

-- UPDATE Event SET EventStatusEnum = 0 WHERE Id = 18130922

-- SELECT * FROM Event WHERE Id = 18130922
-- SELECT * FROM Event WHERE Id IN (18141986, 18130922)
-- SELECT * FROM XMLContent WHERE ReferenceId = 18141986
-- UPDATE Event SET ToAnalyze = 0 WHERE Id = 18141986

