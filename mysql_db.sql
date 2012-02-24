CREATE DATABASE mbbscalendar;
USE mbbscalendar;

CREATE TABLE users (
	username VARCHAR(60) PRIMARY KEY,
	password VARCHAR(60)
);

GRANT ALL PRIVILEGES on mbbscalendar.* TO mbbscalendar@localhost IDENTIFIED BY 'NEWPASSWORDGOESHERE';
