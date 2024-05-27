create database clgdb;
drop database clgdb;
show databases;

use clgdb;
show tables;

drop table hod;

create table hod(
hod_id varchar(255),
hod_name varchar(255),
depatment char(255),
primary key(hod_id)
);

alter table hod modify hod_id varchar(255) not null;
alter table hod modify hod_name varchar(255) not null;
alter table hod rename column depatment to department;
alter table hod modify department enum("csd","csm","cse","csbs","aids","ece","mech","eee","it","civil","phe") not null ;
alter table hod add constraint one_dept_one_hod unique(department);

insert into hod values ("h1","purna","csd"),("h2","uday","csm");
insert into hod values ("h3","dey","aids");
delete from hod where department="aids";
update hod set department="csbs" where hod_id="h3";

select * from hod;
desc hod;

-- QUERIES
	-- hod for faculty "kbnayak"
		select hod_name from hod where hod_id=(select under_hod from faculty where faculty_name="kbnayak");



create table faculty(
faculty_id varchar(255),
faculty_name varchar(255),
department char(255),
under_hod char(255),
primary key(faculty_id),
foreign key (under_hod) references hod(hod_id)
);

insert into faculty values ("f1","kbnayak","csd","h1"),("f2","kiranmai","csd","h1"),("f3","bullet","csm","h2");
select * from faculty;

-- QUERIES :
	-- faculty under hod "h1"
		select faculty_name from faculty where under_hod="h1";
	-- count of faculty under hod "h1"
		select count(*) from faculty where under_hod="h1";
	-- to see how many faculty are there under respective hod
		select under_hod,count(faculty_id) as faculty_under_hod from faculty group by under_hod;


create table students(
roll varchar(10) primary key unique,
name varchar(255) not null,
department varchar(3) not null,
mentor varchar(255) not null,
foreign key (mentor) references faculty(faculty_id)
);

select * from students;

insert into students values ("21211a6711","anil","csd","f1");
insert into students values ("21211a6712","abhi","csm","f1");
insert into students values ("21211a6713","ram","csd","f3");

-- QUERIES
	-- to see how many students are there in each department
		select department,count(name) as students_in_dept from students group by department;
	




create table subjects(
subject_code varchar(5) primary key not null ,
subject_name varchar(255) not null
);

select * from subjects;
insert into subjects values ("AS101","WPCC"),("AS102","BDMS"),("AS103","DL");
insert into subjects values ("AS104","ML"),("AS105","BDA"),("AS106","UML"),("AS107","FDT");


create table teachers(
faculty_id varchar(255),
subject_code varchar(5),
constraint faculty_subject primary key(faculty_id,subject_code),
foreign key (faculty_id) references faculty(faculty_id),
foreign key (subject_code) references subjects(subject_code)
);

select * from teachers;
select * from faculty;
select * from subjects;
insert into teachers values ("f3","AS102"),("f2","AS103");
insert into teachers values ("f3","AS106");
insert into teachers values ("f2","AS104");


-- QUERIES
-- "f1" says which subject(name)
	select subject_name from subjects where subject_code=(select subject_code from teachers where faculty_id="f1");
    
drop table course_enrolled;

create table course_enrolled(
roll varchar(255) not null,
faculty_id varchar(255),
subject_code varchar(5),
foreign key (roll) references students(roll),
FOREIGN KEY (faculty_id, subject_code) REFERENCES teachers(faculty_id, subject_code),
constraint unique(roll,faculty_id,subject_code)
);


select * from course_enrolled;
alter table course_enrolled add constraint unique(roll,faculty_id,subject_code);
ALTER TABLE course_enrolled add INDEX idx_course_enrolled (roll, subject_code) ;

insert into course_enrolled values ("21211a6711","f1","AS101");
insert into course_enrolled values ("21211a6711","f3","AS102"),("21211a6712","f3","AS102");

insert into course_enrolled values ("21211a6711","f2","AS104");


select * from subjects;
select * from teachers;
insert into teachers values ("f2","AS105");
select * from faculty;
select * from course_enrolled;
insert into course_enrolled values ("21211a6711","f2","AS105");


-- QUERIES
	-- to see how many students enrolled for which course
		select subject_code,count(roll) as students_opted_for_subject from course_enrolled group by subject_code;
	-- to see how many students are there under each teacher
		select faculty_id,count(roll) as students_under_faculty from course_enrolled group by faculty_id;


create table results(
roll varchar(255) not null,
subject_code varchar(5) not null,
sem enum('1','2','3','4','5','6','7','8') not null,
grade enum('O','A+','A','B+','B','C','fail') not null,
foreign key (roll,subject_code) references course_enrolled(roll,subject_code)
);

alter table results add constraint unique(roll,subject_code,sem,grade);

insert into results values ("21211a6713","AS102","2","O"); -- GIVES ERROR, as "21211a6713","AS102" combo is not there in 'course_enrolled table'
insert into results values ("21211a6711","AS102","1","O"); 
insert into results values ("21211a6711","AS104","1","A+");
insert into results values ("21211a6711","AS105","2","B");
insert into results values ("21211a6711","AS101","2","A+"); 



DELIMITER //
CREATE TRIGGER check_if_student_has_already_passed_course
BEFORE INSERT ON results
FOR EACH ROW
BEGIN
    DECLARE count_matches INT;
    
    -- Check if there is already a record for the same student and subject
    SET count_matches = (
        SELECT COUNT(*) 
        FROM results 
        WHERE roll = NEW.roll AND subject_code = NEW.subject_code
    );

    -- If there is already a record, raise an error
    IF count_matches > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Student has already passed this course';
    END IF;

END //
DELIMITER ;

DROP TRIGGER IF EXISTS check_if_student_has_already_passed_course;





DELIMITER //
CREATE TRIGGER calculate_and_insert_gpa
AFTER INSERT ON results
FOR EACH ROW
BEGIN
    DECLARE sem_avg DECIMAL(4,2);

    -- Calculate the average GPA for the semester
    SELECT AVG(
        CASE grade
            WHEN 'O' THEN 10
            WHEN 'A+' THEN 9
            WHEN 'A' THEN 8
            WHEN 'B+' THEN 7
            WHEN 'B' THEN 6
            WHEN 'C' THEN 5
            ELSE 0
        END
    ) 
    INTO sem_avg
    FROM results
    WHERE roll = NEW.roll AND sem = NEW.sem;

    -- Check if there is already a GPA record for the given roll and sem
    IF NOT EXISTS (
        SELECT 1 FROM gpa
        WHERE roll = NEW.roll AND sem = NEW.sem
    ) THEN
        -- If no record exists, insert a new row
        INSERT INTO gpa (roll, sem, gpa)
        VALUES (NEW.roll, NEW.sem, sem_avg);
    ELSE
        -- If a record exists, update the existing row
        UPDATE gpa
        SET gpa = sem_avg
        WHERE roll = NEW.roll AND sem = NEW.sem;
    END IF;

END //
DELIMITER ;

DROP TRIGGER IF EXISTS calculate_and_insert_gpa;


create table gpa(
roll varchar(255) not null,
sem enum('1','2','3','4','5','6','7','8') not null,
gpa decimal(4,2),
constraint check_gpa_range check(gpa >= 0 AND gpa <= 10),
foreign key (roll) references results(roll)
);


drop table gpa;
select * from gpa;


CREATE TABLE hostellers (
    roll VARCHAR(10),
    year ENUM('1', '2', '3', '4') NOT NULL,
    fee_payed ENUM('yes', 'no') NOT NULL,
    PRIMARY KEY (roll, year),
    FOREIGN KEY (roll) REFERENCES students(roll)
);

ALTER TABLE hostellers ADD CONSTRAINT chk_fee_payed CHECK (fee_payed IN ('yes', 'no'));



-- QUERIES
	-- Students who are hostellers and have not paid the fee
		SELECT s.name, h.roll FROM hostellers h
		JOIN students s ON h.roll = s.roll
		WHERE h.fee_payed = 'no';



CREATE TABLE dayscholars (
    roll VARCHAR(10),
    year ENUM('1', '2', '3', '4') NOT NULL,
    clgbus_or_not ENUM('yes', 'no') NOT NULL,
    fee_payed ENUM('yes', 'no') NOT NULL,
    PRIMARY KEY (roll, year),
    FOREIGN KEY (roll) REFERENCES students(roll)
);

ALTER TABLE dayscholars ADD CONSTRAINT chk_fee_payed_ds CHECK (fee_payed IN ('yes', 'no'));
ALTER TABLE dayscholars ADD CONSTRAINT chk_clgbus_or_not CHECK (clgbus_or_not IN ('yes', 'no'));

-- QUERIES 
	-- Students who are day scholars, use the college bus, and have not paid the fee
		SELECT s.name, d.roll FROM dayscholars d
		JOIN students s ON d.roll = s.roll
		WHERE d.clgbus_or_not = 'yes' AND d.fee_payed = 'no';


select * from students;
select * from hostellers;
select * from dayscholars;


insert into hostellers values ("21211a6713",'3',"yes");
insert into dayscholars values ("21211a6713",'4',"yes","yes");

DELIMITER //
CREATE TRIGGER check_unique_student_status
BEFORE INSERT ON hostellers
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM dayscholars
        WHERE roll = NEW.roll AND year = NEW.year
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'This student is already registered as a day scholar for the same year';
    END IF;
END //


CREATE TRIGGER check_unique_student_status_dayscholars
BEFORE INSERT ON dayscholars
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM hostellers
        WHERE roll = NEW.roll AND year = NEW.year
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'This student is already registered as a hosteller for the same year';
    END IF;
END //
DELIMITER ;


CREATE TABLE alumni (
    roll VARCHAR(10),
    department VARCHAR(3),
    graduation_year YEAR NOT NULL,
    phone_no VARCHAR(15),
    email VARCHAR(255),
    current_position VARCHAR(255),
    current_company VARCHAR(255),
    PRIMARY KEY (roll),
    FOREIGN KEY (roll) REFERENCES students(roll)
);


-- prevent further operations on a specific roll once it exists in the alumni table across all tables
DELIMITER //
CREATE TRIGGER prevent_alumni_operations_all_tables
BEFORE INSERT ON students
FOR EACH ROW
BEGIN
    DECLARE alumni_count INT;
    
    -- Check if the roll exists in the alumni table
    SELECT COUNT(*)
    INTO alumni_count
    FROM alumni
    WHERE roll = NEW.roll;

    -- If the roll exists in the alumni table, raise an error
    IF alumni_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot perform operation. The student is already an alumni.';
    END IF;
END //
DELIMITER ;



DROP TRIGGER IF EXISTS check_student_exists_in_students;

-- Ensure the roll, department, and name combination exists in the students table before inserting into alumni
DELIMITER //
CREATE TRIGGER check_student_exists_in_students
BEFORE INSERT ON alumni
FOR EACH ROW
BEGIN
    DECLARE student_count INT;
    SELECT COUNT(*)
    INTO student_count
    FROM students
    WHERE roll = NEW.roll AND department = NEW.department;

    IF student_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The roll and department combination does not exist in the students table';
    END IF;
END //
DELIMITER ;









