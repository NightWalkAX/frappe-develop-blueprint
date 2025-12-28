-- Initialize MariaDB with proper user permissions
-- This script is executed when MariaDB starts for the first time

-- Create frappe user if it doesn't exist
CREATE USER IF NOT EXISTS 'frappe'@'%' IDENTIFIED BY 'frappe_password';

-- Grant all privileges on all databases to frappe user
GRANT ALL PRIVILEGES ON *.* TO 'frappe'@'%' WITH GRANT OPTION;

-- Create the frappe_db database if it doesn't exist
CREATE DATABASE IF NOT EXISTS frappe_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant all privileges on frappe_db to frappe user
GRANT ALL PRIVILEGES ON frappe_db.* TO 'frappe'@'%' WITH GRANT OPTION;

-- Flush privileges to apply changes
FLUSH PRIVILEGES;
