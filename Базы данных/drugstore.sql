-- #### СТРУКТУРА БД ####

-- Лекарства
CREATE TABLE drugs (
	id INT AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	price DECIMAL(10, 2) NOT NULL,
	needs_prescription BOOLEAN NOT NULL,
	stock MEDIUMINT NOT NULL DEFAULT 0
);

-- Сотрудники
CREATE TABLE employees (
	id INT AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	hired_at DATE NOT NULL,
	fired_at DATE
);

-- Клиенты
CREATE TABLE customers (
	id INT AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	phone VARCHAR(15) NOT NULL,
	date_of_birth DATE NOT NULL
);

-- Рецепты клиентов
CREATE TABLE customer_prescriptions (
	id INT AUTO_INCREMENT PRIMARY KEY,
	customer_id INT NOT NULL,
	drug_id INT NOT NULL,
	starts_at DATE NOT NULL,
	expires_at DATE NOT NULL,
	FOREIGN KEY (customer_id) REFERENCES customers(id),
	FOREIGN KEY (drug_id) REFERENCES drugs(id)
);

-- Заказы
CREATE TABLE orders (
	id INT AUTO_INCREMENT PRIMARY KEY,
	customer_id INT NOT NULL,
	employee_id INT NOT NULL,
	drug_id INT NOT NULL,
	prescription_id INT,
	date DATE NOT NULL,
	FOREIGN KEY (customer_id) REFERENCES customers(id),
	FOREIGN KEY (employee_id) REFERENCES employees(id)
);



-- #### ПРОЦЕДУРЫ ####

DELIMITER //

CREATE PROCEDURE make_order (
    IN customer_id INT,
    IN drug_id INT,
    IN quantity MEDIUMINT,
    IN employee_id INT,
    IN prescription_id INT
)
BEGIN
    DECLARE prescription_required BOOLEAN;
    DECLARE valid_prescription BOOLEAN;
    DECLARE valid_employee BOOLEAN;
    DECLARE drug_in_stock BOOLEAN;

    -- Проверка статуса сотрудника
    SELECT EXISTS (SELECT 1 FROM employees WHERE id = employee_id AND fired_at IS NULL) INTO valid_employee;
    IF NOT valid_employee THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Сотрудник не найден или уволен';
    END IF;

    -- Проверка наличия лекарства на складе
    SELECT stock >= quantity INTO drug_in_stock FROM drugs WHERE id = drug_id;
    IF NOT drug_in_stock THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Недостаточное количество лекарства на складе';
    END IF;

    -- Проверка рецепта
    IF prescription_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM customer_prescriptions
            WHERE id = prescription_id
            AND customer_id = customer_id
            AND drug_id = drug_id
            AND CURDATE() >= starts_at
            AND CURDATE() <= expires_at
        ) INTO valid_prescription;
    ELSE
        SET valid_prescription = FALSE;
    END IF;

    SELECT needs_prescription INTO prescription_required FROM drugs WHERE id = drug_id;
    IF prescription_required AND NOT valid_prescription THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Требуется действующий рецепт';
    END IF;

    -- Если все проверки пройдены, выполняем транзакцию
    START TRANSACTION;
        INSERT INTO orders (customer_id, employee_id, drug_id, prescription_id, date)
        VALUES (customer_id, employee_id, drug_id, prescription_id, CURDATE());
        
        UPDATE drugs SET stock = stock - quantity WHERE id = drug_id;
    COMMIT;

    -- Возвращаем сообщение об успешном выполнении
    SELECT 'Заказ успешно оформлен' AS result;

END//

DELIMITER ;




-- #### ДАННЫЕ ####

INSERT INTO drugs (name, price, needs_prescription, stock)
VALUES 
	('Парацетамол', 50.00, FALSE, 111),
	('Доравирус', 70.50, TRUE, 87),
	('Метронидазол', 119.99, TRUE, 13);

INSERT INTO employees (name, hired_at, fired_at)
VALUES 
	('Иванов Иван', '2023-03-14', NULL),
	('Петров Петр', '2024-01-23', NULL);

INSERT INTO customers (name, phone, date_of_birth)
VALUES 
	('Смирнов Игорь', '+79500762409', '1985-10-15'),
	('Потёмкин Олег', '+89500600934', '1990-05-20'),
	('Козырева Акулина', '+79990447217', '1978-12-03');

INSERT INTO customer_prescriptions (customer_id, drug_id, starts_at, expires_at)
VALUES 
	(3, 3, '2024-01-31', '2025-01-31');

CALL make_order(3, 3, 2, 1, 1);