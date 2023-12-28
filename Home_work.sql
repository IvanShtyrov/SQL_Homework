-- Промежуточные таблицы
--drop table orders_data;
select * from orders_data; -- удалено
--drop table corrected_orders_data;
select * from corrected_orders_data; -- удалено
--drop table corrected_orders_data_02;
select * from corrected_orders_data_02; -- удалено
--drop table corrected_orders_data_03;
select * from corrected_orders_data_03; -- удалено

-- Основные
select * from clients;
select * from staff;
select * from cargo;
select * from orders;



--1 таблица, куда заливал данные из Excel - файла
CREATE TABLE orders_data (
    --id serial PRIMARY KEY,
    staf_name text,
    staff_age int,
    staff_id text, -- Тип данных изменен на текстовый (VARCHAR)
    staff_lang text,
    order_pk text,
    order_address text,
    order_country text,
    order_company text,
    order_price numeric,
    order_dt date,
    order_list text[],
    cli_name text, 
    cli_email text,
    cli_phone text,
    cli_secret text,
    c_token text,
    c_pin text,
    c_gen text,    
    c_type text
);

COPY orders_data
FROM '<data-folder>\sample_5.csv'
DELIMITER ',' CSV HEADER
;
-- Производил проверки на типы данных, имеющихся в созданных таблицах
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders_data'; 

--drop table corrected_orders_data;
-- скорректировал некоторые поля по типам данных, названиям и разделил имена и адрес
create table corrected_orders_data as 
select 
CAST(staff_age AS numeric) AS staff_age, 
CAST(order_price AS numeric) AS order_price,
order_dt, 
CAST(order_pk AS numeric) AS order_pk,
CAST(split_part(order_address, ' ', 1) AS INTEGER) AS street_number,
split_part(order_address, ' ', 2) AS street_name,
order_country, 
order_company, 
order_list, 
split_part(cli_name, ' ', 1) AS cli_first_name,
split_part(cli_name, ' ', 2) AS cli_last_name,
cli_email, 
cli_phone, 
cli_secret, 
c_token, 
CAST(c_pin AS numeric) AS c_pin, 
c_gen, 
split_part(staf_name, ' ', 1) AS staff_first_name,
split_part(staf_name, ' ', 2) AS staff_last_name,
c_type, 
staff_id, 
staff_lang 
from orders_data;

-- информация по типам данных, использовал для проверок
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'corrected_orders_data_03';


--! Если я правильно понял задание, нормализация данных в ключе этого задания состоит главным образом из зачистки дублей для разных табличек
select distinct staff_id, staff_age, staff_first_name, staff_last_name, staff_lang  from corrected_orders_data
where staff_id = '84-14/62';
-- Так напримере этого id сотрудника, мы видим что это Миллард Леон, и с разными вариациями записей его имени существует 3 уникальные строчки + строчка где отсутствует id сотрудника, но есть другие данные относящиеся к этому сотруднику
-- Поэтому тут и ниже я буду приводить такие записи к единой строчке

--drop table staff cascade;
-- Создание таблицы Staff (Сотрудники)
CREATE TABLE staff (
    id SERIAL PRIMARY KEY,
    staff_id text,
    age numeric,
    first_name text,
    last_name text,
    lang text
);
-- Создание индекса для Staff
CREATE INDEX staff_id_index ON staff (id);

-- Создание таблицы Clients (Клиенты)
-- drop table clients cascade;
CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    first_name text,
    last_name text,
    email text,
    phone text,
    secret text
);
-- Создание индекса для Clients
CREATE INDEX clients_id_index ON clients (id);

--drop table cargo cascade;
-- Таблица cargo
CREATE TABLE cargo (
    id SERIAL PRIMARY KEY,
    c_token TEXT,
    pin NUMERIC,
    gen TEXT,
    c_type TEXT
);
-- Создание индекса для Cargo
CREATE INDEX cargo_id_index ON cargo (id);

--drop table orders cascade;
-- Таблица orders. Она будет основная и связующая для всех таблиц
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
	user_id INT references staff(id),
    person_id INT references clients(id),
    cargo_id INT references cargo(id),
    street_name TEXT,
    street_number INT,
    country TEXT,
    company TEXT,
    price NUMERIC,
    dt DATE,
    list TEXT[],
    pk INT
);


CREATE INDEX orders_id_index ON clients (id);

-- Создаю таблицу corrected_orders_data_02 на основе corrected_orders_data, основная задача запроса состоит в том, чтобы заполнить NULL-значения на схожие в сути значения
select 
   coalesce (s.staff_first_name, (select od.staff_first_name from corrected_orders_data od where od.staff_first_name is not null and od.staff_id = s.staff_id limit 1)) as staff_first_name, 
   s.staff_last_name, s.staff_age, s.staff_id, s.staff_lang, 
   coalesce (s.order_pk, 
      (select od.order_pk from corrected_orders_data od where od.order_pk is not null and od.order_list = s.order_list limit 1), 
      (select od.order_pk from corrected_orders_data od where od.order_pk is not null and od.street_name = s.street_name and od.street_number = od.street_number and od.order_country = s.order_country and od.order_company = s.order_company limit 1)) as order_pk,
   s.street_name, s.street_number, s.order_country, s.order_company, s.order_price, s.order_dt, s.order_list,
   coalesce (s.cli_first_name, (select od.cli_first_name from corrected_orders_data od where od.cli_first_name is not null and od.cli_email = s.cli_email limit 1)) as cli_first_name,
   s.cli_last_name, s.cli_email, s.cli_phone, s.cli_secret,    
   coalesce (s.c_token, 
       (select od.c_token from corrected_orders_data od where od.c_token is not null and od.c_pin = s.c_pin limit 1),
       (concat('generated_', cast (c_pin as varchar)))) as c_token,
   s.c_pin, s.c_gen, s.c_type
into corrected_orders_data_02
from corrected_orders_data s
order by 1 asc;

-- Создаю таблицу corrected_orders_data_03 на основе corrected_orders_data_02, тут задача запроса состоит в том, чтобы заполнить оставшиеся NULL-значения
select 
   s.staff_first_name, 
   coalesce (s.staff_last_name, (select od.staff_last_name from corrected_orders_data_02 od where od.staff_last_name is not null and od.staff_first_name = s.staff_first_name limit 1)) as staff_last_name, 
   coalesce (s.staff_age, (select od.staff_age from corrected_orders_data_02 od where od.staff_age is not null and od.staff_first_name = s.staff_first_name limit 1)) as staff_age, 
   coalesce (s.staff_id, (select od.staff_id from corrected_orders_data_02 od where od.staff_id is not null and od.staff_first_name = s.staff_first_name limit 1)) as staff_id, 
   coalesce (s.staff_lang, (select od.staff_lang from corrected_orders_data_02 od where od.staff_lang is not null and od.staff_first_name = s.staff_first_name limit 1)) as staff_lang,
   s.order_pk,
   coalesce (s.street_name, (select od.street_name from corrected_orders_data_02 od where od.street_name is not null and od.order_pk = s.order_pk limit 1)) as street_name,
   coalesce (s.street_number, (select od.street_number from corrected_orders_data_02 od where od.street_number is not null and od.order_pk = s.order_pk limit 1)) as street_number,
   coalesce (s.order_country, (select od.order_country from corrected_orders_data_02 od where od.order_country is not null and od.order_pk = s.order_pk limit 1)) as order_country,
   coalesce (s.order_company, (select od.order_company from corrected_orders_data_02 od where od.order_company is not null and od.order_pk = s.order_pk limit 1)) as order_company,
   coalesce (s.order_price, (select od.order_price from corrected_orders_data_02 od where od.order_price is not null and od.order_pk = s.order_pk limit 1)) as order_price,
   coalesce (s.order_dt, (select od.order_dt from corrected_orders_data_02 od where od.order_dt is not null and od.order_pk = s.order_pk limit 1)) as order_dt,
   coalesce (s.order_list, (select od.order_list from corrected_orders_data_02 od where od.order_list is not null and od.order_pk = s.order_pk limit 1)) as order_list, 
   s.cli_first_name,
   coalesce (s.cli_last_name, (select od.cli_last_name from corrected_orders_data_02 od where od.cli_last_name is not null and od.cli_first_name = s.cli_first_name limit 1)) as cli_last_name,
   coalesce (s.cli_email, (select od.cli_email from corrected_orders_data_02 od where od.cli_email is not null and od.cli_first_name = s.cli_first_name limit 1)) as cli_email,
   coalesce (s.cli_phone, (select od.cli_phone from corrected_orders_data_02 od where od.cli_phone is not null and od.cli_first_name = s.cli_first_name limit 1)) as cli_phone,
   coalesce (s.cli_secret, (select od.cli_secret from corrected_orders_data_02 od where od.cli_secret is not null and od.cli_first_name = s.cli_first_name limit 1)) as cli_secret,  
   s.c_token, 
   coalesce (s.c_pin, (select od.c_pin from corrected_orders_data_02 od where od.c_pin is not null and od.c_token = s.c_token limit 1)) as c_pin,
   coalesce (s.c_gen, (select od.c_gen from corrected_orders_data_02 od where od.c_gen is not null and od.c_token = s.c_token limit 1)) as c_gen,
   coalesce (s.c_type, (select od.c_type from corrected_orders_data_02 od where od.c_type is not null and od.c_token = s.c_token limit 1)) as c_type
into corrected_orders_data_03
from corrected_orders_data_02 s;

-- Загружаю в таблицу сотрудников информацию по сотрудникам
insert into staff(staff_id, age, first_name, last_name, lang)
select distinct 
staff_id staff_id,
staff_age age, 
staff_first_name first_name, 
staff_last_name last_name, 
staff_lang lang
from corrected_orders_data_03;

-- Загружаю в таблицу клиентов информацию по клиентам
INSERT INTO clients (first_name, last_name, email, phone, secret)
select distinct 
cli_first_name first_name, 
cli_last_name last_name, 
cli_email email, 
cli_phone phone, 
cli_secret secret
from corrected_orders_data_03;

-- Загружаю в таблицу доставок основную информацию по доставкасм
insert into cargo (c_token, pin, gen, c_type)
select distinct
c_token,
c_pin pin,
c_gen gen,
c_type
from corrected_orders_data_03;

-- Загружаю в таблицу заказов информацию по заказам, а также ключи для связки к таблицам staff, clients и cargo
insert into orders (user_id, person_id, cargo_id, pk, country, street_name, street_number, company, price, dt, list)
select
s.id user_id,
c.id person_id,
ca.id cargo_id,
od.order_pk pk,
od.order_country country,
od.street_name,
od.street_number,
od.order_company company,
od.order_price price,
od.order_dt dt,
od.order_list list
from corrected_orders_data_03 od
left join staff s on s.first_name = od.staff_first_name and s.last_name = od.staff_last_name and s.age = od.staff_age and s.staff_id = od.staff_id and s.lang = od.staff_lang
left join clients c on c.first_name = od.cli_first_name and c.last_name = od.cli_last_name and c.email = od.cli_email and c.phone = od.cli_phone and c.secret = od.cli_secret
left join cargo ca 
on coalesce(od.c_token,'') = coalesce(ca.c_token,'')
and coalesce(od.c_pin,01) = coalesce(ca.pin,01)
and coalesce(od.c_gen,'') = coalesce(ca.gen,'')
and coalesce(od.c_type,'') = coalesce(ca.c_type,'')
;

-- Итоговый вариант
select 
o.id, -- id заказов
s.id, -- id сотрудников
c.id, -- id клиентов
ca.id, -- id доставки
s.staff_id, s.age, s.first_name, s.last_name, s.lang, -- основная информация по сотрудникам
c.first_name, c.last_name, c.email, c.phone, c.secret, -- основная информация по клиентам
ca.c_token, ca.pin, ca.gen, ca.c_type,  -- основная информация по доставке
o.street_name, o.street_number, o.country, o.company, o.price, o.dt, o.list, o.pk -- основная информация по заказам
from orders o
join staff s on s.id = o.user_id
join clients c on c.id = o.person_id
join cargo ca on ca.id = o.cargo_id;
