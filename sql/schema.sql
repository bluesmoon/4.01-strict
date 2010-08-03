CREATE TABLE If Not Exists strip (
	n		SMALLINT UNSIGNED AUTO_INCREMENT NOT NULL,
	date_posted	TIMESTAMP NOT NULL,
	id		VARCHAR(255) NOT NULL,
	farm		SMALLINT NOT NULL,
	secret		VARCHAR(255) NOT NULL,
	server		VARCHAR(255) NOT NULL,
	title		TEXT NOT NULL,
	description	TEXT NULL,

	PRIMARY KEY (n),
	INDEX (date_posted)
) Engine=InnoDB, CHARACTER SET=utf8, COLLATE=utf8_unicode_ci;
