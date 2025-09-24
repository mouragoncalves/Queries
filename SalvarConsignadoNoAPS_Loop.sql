--SELECT 
--    pk,
--	ee.matricula,
--    ao.id_allowance,
--    a.name,
--    a.code,
--    ao.id_object,
--    o.[object],
--    ao.id_type_payment,
--    tp.[object],
--	id_allowance_object,
--    ao.money_2
--FROM Allowance_Object ao
--    JOIN Allowance a ON a.id_allowance = ao.id_allowance
--    JOIN [Object] o ON o.id_object = ao.id_object
--    JOIN v_type_payment tp ON tp.id_type_payment = ao.id_type_payment
--	--JOIN v_employee e ON e.id_employee = ao.pk
--	JOIN Enrollment_Employee ee ON ee.id_enrollment = ao.pk
----WHERE ao.datetime_1 > '2025-08-01'
--	  --WHERE a.code = '16965'
--	  WHERE ee.matricula = 'BASIE22062023R292224'
 
--SELECT * FROM Allowance_Object WHERE pk = 93562
 
 
DECLARE @eConsignado TABLE (
	Matricula VARCHAR(40) NOT Null,
	Rubrica VARCHAR(5) NOT Null,
	Parcela DECIMAL(8,2) NOT Null
);
 
INSERT INTO @eConsignado VALUES 
	('USB09031998R0002', '16965', 100.2),
	('USB09031998R0002', '16966', 527.75),
	('USB09031998R0003', '16965', 15.37);
 
DECLARE c_consignado CURSOR FOR
SELECT Matricula, Rubrica, Parcela FROM @eConsignado
 
DECLARE @matricula VARCHAR(40), @rubrica VARCHAR(5), @parcela DECIMAL(8,2);
 
OPEN c_consignado
FETCH NEXT FROM c_consignado INTO @matricula, @rubrica, @parcela
 
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @id_enrollment INT = NULL, @id_allowance INT = NULL, @id_object INT = NULL, @id_type_payment INT = NULL, @ex BIT = 0, @dif BIT = 0, @id_allowance_object INT;
 
	SELECT 
		@id_enrollment = id_enrollment 
	FROM Enrollment_Employee 
	WHERE matricula = @matricula
 
	SELECT 
		@id_allowance = id_allowance 
	FROM Allowance 
	WHERE code = @rubrica
 
	SELECT 
		@id_object = id_object 
	FROM Object 
	WHERE Object = 'ENROLLMENT_EMPLOYEE'
 
	SELECT 
		@id_type_payment = id_type_payment 
	FROM v_type_payment 
	WHERE object = 'CONTRA_CHEQUE'
 
	-- select @matricula, @rubrica, @parcela, @id_enrollment
 
	SELECT @ex = 1, @dif = IIF(@parcela = money_2, 1, 0), @id_allowance_object = id_allowance_object
	FROM Allowance_Object 
	WHERE pk = @id_enrollment 
		AND id_allowance = @id_allowance
		AND id_object = @id_object
		AND id_type_payment = @id_type_payment
 
	IF(@ex = 1)
		BEGIN 
			IF(@dif <> 1)
			BEGIN
				UPDATE Allowance_Object SET money_2 = @parcela
				WHERE id_allowance_object = @id_allowance_object
			END
		END
	ELSE
		BEGIN
			INSERT INTO Allowance_Object (pk, id_allowance, id_object, id_type_payment, char_1, money_2)
			VALUES (@id_enrollment, @id_allowance, @id_object, @id_type_payment, 'ABM', @parcela);
		END
 
	
	FETCH NEXT FROM c_consignado INTO @matricula, @rubrica, @parcela
END
CLOSE c_consignado
DEALLOCATE c_consignado