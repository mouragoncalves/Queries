DECLARE @eConsignado TABLE (
	Matricula VARCHAR(40) NOT Null,
	Rubrica VARCHAR(5) NOT Null,
	Parcela DECIMAL(8,2) NOT Null
);
 
INSERT INTO @eConsignado VALUES 
	('USB09031998R0002', '16965', 100.2),
	('USB09031998R0002', '16966', 527.75);
    
DECLARE @DataBase TABLE (
    Matricula VARCHAR(40),
    Rubrica VARCHAR(5),
    Parcela DECIMAL(8,2),
    id_enrollment INT NULL, 
    id_allowance INT NULL, 
    id_object INT NULL, 
    id_type_payment INT NULL, 
    existing_id_allowance_object INT,
    existing_money_2 DECIMAL(8,2)
)

INSERT INTO @DataBase
SELECT 
    ec.Matricula,
    ec.Rubrica,
    ec.Parcela,
    ee.id_enrollment,
    a.id_allowance,
    o.id_object,
    tp.id_type_payment,
    ao.id_allowance_object,
    ao.money_2
FROM @eConsignado ec
INNER JOIN Enrollment_Employee ee ON ee.matricula = ec.Matricula
INNER JOIN Allowance a ON a.code = ec.Rubrica
CROSS JOIN (
    SELECT id_object 
    FROM Object 
    WHERE Object = 'ENROLLMENT_EMPLOYEE'
) o
CROSS JOIN (
    SELECT id_type_payment 
    FROM v_type_payment 
    WHERE object IN ('RESCISAO', 'CONTRA_CHEQUE')
) tp
LEFT JOIN Allowance_Object ao ON ao.pk = ee.id_enrollment 
    AND ao.id_allowance = a.id_allowance
    AND ao.id_object = o.id_object
    AND ao.id_type_payment = tp.id_type_payment;

BEGIN TRY
    BEGIN TRANSACTION

    -- UPDATE ao
    -- SET money_2 = db.Parcela
    -- FROM Allowance_Object ao
    -- INNER JOIN @DataBase db ON ao.id_allowance_object = db.existing_id_allowance_object
    -- WHERE db.existing_id_allowance_object IS NOT NULL
    -- AND db.existing_money_2 != db.Parcela;

    -- INSERT INTO Allowance_Object (pk, id_allowance, id_object, id_type_payment, char_1, money_2)
    -- SELECT 
    --     db.id_enrollment,
    --     db.id_allowance,
    --     db.id_object,
    --     db.id_type_payment,
    --     'ABM',
    --     db.Parcela
    -- FROM @DataBase db
    -- WHERE db.existing_id_allowance_object IS NULL;

    SELECT * FROM @DataBase

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION
END CATCH;