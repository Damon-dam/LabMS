-- LabCore Database Schema
-- Based on: Lab Management System UI Mockup & Functionality Blueprint
-- Database: MySQL 8.0+ / XAMPP
-- IMPORTANT: Review school-specific roles, class/level rules, and responsibility-mark rubric before production.

CREATE DATABASE IF NOT EXISTS `labcore`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `labcore`;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS `v_active_loans`;
DROP VIEW IF EXISTS `v_resource_inventory`;

DROP TABLE IF EXISTS `audit_logs`;
DROP TABLE IF EXISTS `notifications`;
DROP TABLE IF EXISTS `correction_approvals`;
DROP TABLE IF EXISTS `correction_requests`;
DROP TABLE IF EXISTS `maintenance_records`;
DROP TABLE IF EXISTS `returns`;
DROP TABLE IF EXISTS `loan_accessories`;
DROP TABLE IF EXISTS `loans`;
DROP TABLE IF EXISTS `inspection_accessories`;
DROP TABLE IF EXISTS `resource_inspections`;
DROP TABLE IF EXISTS `resource_accessories`;
DROP TABLE IF EXISTS `resources`;
DROP TABLE IF EXISTS `locations`;
DROP TABLE IF EXISTS `categories`;
DROP TABLE IF EXISTS `role_permissions`;
DROP TABLE IF EXISTS `permissions`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `roles`;

SET FOREIGN_KEY_CHECKS = 1;

-- 1. Roles and permissions
CREATE TABLE `roles` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `role_name` VARCHAR(80) NOT NULL UNIQUE,
  `description` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE `permissions` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `permission_key` VARCHAR(100) NOT NULL UNIQUE,
  `description` VARCHAR(255) NULL
) ENGINE=InnoDB;

CREATE TABLE `role_permissions` (
  `role_id` BIGINT UNSIGNED NOT NULL,
  `permission_id` BIGINT UNSIGNED NOT NULL,
  `granted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`role_id`, `permission_id`),
  CONSTRAINT `fk_role_permissions_role`
    FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_role_permissions_permission`
    FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2. User accounts
CREATE TABLE `users` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_code` VARCHAR(40) NOT NULL UNIQUE,
  `full_name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(190) NULL UNIQUE,
  `phone` VARCHAR(30) NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `role_id` BIGINT UNSIGNED NOT NULL,
  `class_name` VARCHAR(80) NULL,
  `program_name` VARCHAR(120) NULL,
  `level_name` VARCHAR(40) NULL,
  `account_status` ENUM('active','inactive','suspended') NOT NULL DEFAULT 'active',
  `last_login_at` DATETIME NULL,
  `created_by` BIGINT UNSIGNED NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_users_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`),
  CONSTRAINT `fk_users_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  INDEX `idx_users_name` (`full_name`),
  INDEX `idx_users_class_program` (`class_name`, `program_name`, `level_name`),
  INDEX `idx_users_status` (`account_status`)
) ENGINE=InnoDB;

-- 3. Resource categories and locations
CREATE TABLE `categories` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `category_name` VARCHAR(100) NOT NULL UNIQUE,
  `description` VARCHAR(255) NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE `locations` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `location_name` VARCHAR(120) NOT NULL,
  `building` VARCHAR(120) NULL,
  `room` VARCHAR(80) NULL,
  `shelf_reference` VARCHAR(80) NULL,
  `description` VARCHAR(255) NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uq_location_reference` (`location_name`, `building`, `room`, `shelf_reference`)
) ENGINE=InnoDB;

-- 4. Inventory resources
CREATE TABLE `resources` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `asset_code` VARCHAR(80) NOT NULL UNIQUE,
  `display_code` VARCHAR(80) NULL,
  `name` VARCHAR(160) NOT NULL,
  `description` TEXT NULL,
  `category_id` BIGINT UNSIGNED NOT NULL,
  `location_id` BIGINT UNSIGNED NULL,
  `serial_number` VARCHAR(150) NULL,
  `condition_status` ENUM('excellent','good','damaged','faulty') NOT NULL DEFAULT 'good',
  `operational_status` ENUM('available','borrowed','under_maintenance','retired','unavailable') NOT NULL DEFAULT 'available',
  `purchase_date` DATE NULL,
  `notes` TEXT NULL,
  `created_by` BIGINT UNSIGNED NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_resources_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`),
  CONSTRAINT `fk_resources_location` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_resources_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  INDEX `idx_resources_name` (`name`),
  INDEX `idx_resources_status` (`operational_status`),
  INDEX `idx_resources_condition` (`condition_status`),
  INDEX `idx_resources_category_location` (`category_id`, `location_id`)
) ENGINE=InnoDB;

-- Accessories that may be included with a resource (for example, power cable or mouse)
CREATE TABLE `resource_accessories` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `resource_id` BIGINT UNSIGNED NOT NULL,
  `accessory_name` VARCHAR(120) NOT NULL,
  `quantity` INT UNSIGNED NOT NULL DEFAULT 1,
  `condition_status` ENUM('excellent','good','damaged','faulty') NOT NULL DEFAULT 'good',
  `notes` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_resource_accessories_resource`
    FOREIGN KEY (`resource_id`) REFERENCES `resources` (`id`) ON DELETE CASCADE,
  INDEX `idx_resource_accessories_resource` (`resource_id`)
) ENGINE=InnoDB;

-- 5. Inspections: a required pre-lending inspection and a return inspection
CREATE TABLE `resource_inspections` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `resource_id` BIGINT UNSIGNED NOT NULL,
  `inspector_id` BIGINT UNSIGNED NOT NULL,
  `inspection_type` ENUM('pre_lending','return','routine','maintenance') NOT NULL,
  `condition_status` ENUM('excellent','good','damaged','faulty') NOT NULL,
  `operational_status` ENUM('available','borrowed','under_maintenance','retired','unavailable') NULL,
  `notes` TEXT NULL,
  `evidence_photo_path` VARCHAR(500) NULL,
  `inspected_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_inspections_resource` FOREIGN KEY (`resource_id`) REFERENCES `resources` (`id`),
  CONSTRAINT `fk_inspections_inspector` FOREIGN KEY (`inspector_id`) REFERENCES `users` (`id`),
  INDEX `idx_inspections_resource_date` (`resource_id`, `inspected_at`),
  INDEX `idx_inspections_inspector` (`inspector_id`)
) ENGINE=InnoDB;

CREATE TABLE `inspection_accessories` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `inspection_id` BIGINT UNSIGNED NOT NULL,
  `accessory_name` VARCHAR(120) NOT NULL,
  `quantity_expected` INT UNSIGNED NOT NULL DEFAULT 1,
  `quantity_present` INT UNSIGNED NOT NULL DEFAULT 1,
  `condition_status` ENUM('excellent','good','damaged','faulty','missing') NOT NULL DEFAULT 'good',
  `notes` VARCHAR(255) NULL,
  CONSTRAINT `fk_inspection_accessories_inspection`
    FOREIGN KEY (`inspection_id`) REFERENCES `resource_inspections` (`id`) ON DELETE CASCADE,
  INDEX `idx_inspection_accessories_inspection` (`inspection_id`)
) ENGINE=InnoDB;

-- 6. Lending transactions
CREATE TABLE `loans` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `loan_code` VARCHAR(50) NOT NULL UNIQUE,
  `resource_id` BIGINT UNSIGNED NOT NULL,
  `borrower_id` BIGINT UNSIGNED NOT NULL,
  `issued_by` BIGINT UNSIGNED NOT NULL,
  `issue_inspection_id` BIGINT UNSIGNED NOT NULL,
  `issued_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `due_at` DATETIME NULL,
  `status` ENUM('active','returned','overdue','cancelled') NOT NULL DEFAULT 'active',
  `borrower_acknowledged` BOOLEAN NOT NULL DEFAULT FALSE,
  `acknowledged_at` DATETIME NULL,
  `notes` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_loans_resource` FOREIGN KEY (`resource_id`) REFERENCES `resources` (`id`),
  CONSTRAINT `fk_loans_borrower` FOREIGN KEY (`borrower_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_loans_issued_by` FOREIGN KEY (`issued_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_loans_inspection` FOREIGN KEY (`issue_inspection_id`) REFERENCES `resource_inspections` (`id`),
  INDEX `idx_loans_borrower_status` (`borrower_id`, `status`),
  INDEX `idx_loans_resource_status` (`resource_id`, `status`),
  INDEX `idx_loans_due_status` (`due_at`, `status`),
  INDEX `idx_loans_issued_at` (`issued_at`)
) ENGINE=InnoDB;

CREATE TABLE `loan_accessories` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `loan_id` BIGINT UNSIGNED NOT NULL,
  `accessory_name` VARCHAR(120) NOT NULL,
  `quantity_issued` INT UNSIGNED NOT NULL DEFAULT 1,
  `condition_at_issue` ENUM('excellent','good','damaged','faulty') NOT NULL DEFAULT 'good',
  `quantity_returned` INT UNSIGNED NULL,
  `notes` VARCHAR(255) NULL,
  CONSTRAINT `fk_loan_accessories_loan`
    FOREIGN KEY (`loan_id`) REFERENCES `loans` (`id`) ON DELETE CASCADE,
  INDEX `idx_loan_accessories_loan` (`loan_id`)
) ENGINE=InnoDB;

-- 7. Return records. Completed return records should not be silently overwritten by application code.
CREATE TABLE `returns` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `loan_id` BIGINT UNSIGNED NOT NULL UNIQUE,
  `received_by` BIGINT UNSIGNED NOT NULL,
  `return_inspection_id` BIGINT UNSIGNED NOT NULL,
  `returned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `condition_at_return` ENUM('excellent','good','damaged','faulty') NOT NULL,
  `accessories_complete` BOOLEAN NOT NULL DEFAULT TRUE,
  `borrower_acknowledgement` ENUM('pending','acknowledged','disputed') NOT NULL DEFAULT 'pending',
  `acknowledged_at` DATETIME NULL,
  `responsibility_mark` DECIMAL(6,2) NULL,
  `mark_reason` TEXT NULL,
  `mark_recorded_by` BIGINT UNSIGNED NULL,
  `return_notes` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_returns_loan` FOREIGN KEY (`loan_id`) REFERENCES `loans` (`id`),
  CONSTRAINT `fk_returns_received_by` FOREIGN KEY (`received_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_returns_inspection` FOREIGN KEY (`return_inspection_id`) REFERENCES `resource_inspections` (`id`),
  CONSTRAINT `fk_returns_mark_recorder` FOREIGN KEY (`mark_recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  INDEX `idx_returns_returned_at` (`returned_at`),
  INDEX `idx_returns_acknowledgement` (`borrower_acknowledgement`)
) ENGINE=InnoDB;

-- 8. Correction workflow with borrower and authorized-administrator decisions
CREATE TABLE `correction_requests` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `request_code` VARCHAR(50) NOT NULL UNIQUE,
  `target_record_type` ENUM('return','loan','resource','inspection','other') NOT NULL DEFAULT 'return',
  `target_record_id` BIGINT UNSIGNED NOT NULL,
  `requester_id` BIGINT UNSIGNED NOT NULL,
  `affected_borrower_id` BIGINT UNSIGNED NULL,
  `reason` TEXT NOT NULL,
  `original_snapshot` JSON NOT NULL,
  `proposed_values` JSON NOT NULL,
  `status` ENUM('pending','awaiting_borrower','awaiting_admin','approved','rejected','disputed','applied') NOT NULL DEFAULT 'pending',
  `applied_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_correction_requester` FOREIGN KEY (`requester_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_correction_affected_borrower` FOREIGN KEY (`affected_borrower_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  INDEX `idx_correction_status_created` (`status`, `created_at`),
  INDEX `idx_correction_target` (`target_record_type`, `target_record_id`)
) ENGINE=InnoDB;

CREATE TABLE `correction_approvals` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `request_id` BIGINT UNSIGNED NOT NULL,
  `approver_id` BIGINT UNSIGNED NOT NULL,
  `approval_type` ENUM('borrower','administrator') NOT NULL,
  `decision` ENUM('approved','rejected','disputed') NOT NULL,
  `comment` TEXT NULL,
  `decided_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_correction_approvals_request`
    FOREIGN KEY (`request_id`) REFERENCES `correction_requests` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_correction_approvals_approver`
    FOREIGN KEY (`approver_id`) REFERENCES `users` (`id`),
  UNIQUE KEY `uq_correction_approval_type` (`request_id`, `approval_type`),
  INDEX `idx_correction_approvals_approver` (`approver_id`)
) ENGINE=InnoDB;

-- 9. Maintenance tracking
CREATE TABLE `maintenance_records` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `resource_id` BIGINT UNSIGNED NOT NULL,
  `reported_by` BIGINT UNSIGNED NOT NULL,
  `issue_description` TEXT NOT NULL,
  `status` ENUM('open','in_progress','resolved','cancelled') NOT NULL DEFAULT 'open',
  `opened_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at` DATETIME NULL,
  `resolution` TEXT NULL,
  `closed_by` BIGINT UNSIGNED NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_maintenance_resource` FOREIGN KEY (`resource_id`) REFERENCES `resources` (`id`),
  CONSTRAINT `fk_maintenance_reporter` FOREIGN KEY (`reported_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_maintenance_closed_by` FOREIGN KEY (`closed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  INDEX `idx_maintenance_status` (`status`),
  INDEX `idx_maintenance_resource` (`resource_id`)
) ENGINE=InnoDB;

-- 10. Notifications
CREATE TABLE `notifications` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `recipient_id` BIGINT UNSIGNED NOT NULL,
  `notification_type` VARCHAR(80) NOT NULL,
  `title` VARCHAR(180) NULL,
  `message` TEXT NOT NULL,
  `related_record_type` VARCHAR(80) NULL,
  `related_record_id` BIGINT UNSIGNED NULL,
  `read_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_notifications_recipient` FOREIGN KEY (`recipient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  INDEX `idx_notifications_recipient_read` (`recipient_id`, `read_at`),
  INDEX `idx_notifications_created` (`created_at`)
) ENGINE=InnoDB;

-- 11. Audit trail. Treat as append-only in application permissions and normal UI workflows.
CREATE TABLE `audit_logs` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `actor_id` BIGINT UNSIGNED NULL,
  `action` VARCHAR(120) NOT NULL,
  `entity_type` VARCHAR(100) NOT NULL,
  `entity_id` BIGINT UNSIGNED NULL,
  `before_snapshot` JSON NULL,
  `after_snapshot` JSON NULL,
  `reason` TEXT NULL,
  `ip_address` VARCHAR(45) NULL,
  `user_agent` VARCHAR(500) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_audit_actor` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  INDEX `idx_audit_entity` (`entity_type`, `entity_id`),
  INDEX `idx_audit_actor_date` (`actor_id`, `created_at`),
  INDEX `idx_audit_action_date` (`action`, `created_at`)
) ENGINE=InnoDB;

-- Helpful read-only views
CREATE VIEW `v_active_loans` AS
SELECT
  l.id AS loan_id,
  l.loan_code,
  l.issued_at,
  l.due_at,
  l.status AS loan_status,
  r.id AS resource_id,
  r.asset_code,
  r.display_code,
  r.name AS resource_name,
  u.id AS borrower_id,
  u.user_code AS borrower_code,
  u.full_name AS borrower_name,
  issuer.full_name AS issued_by_name
FROM loans l
JOIN resources r ON r.id = l.resource_id
JOIN users u ON u.id = l.borrower_id
JOIN users issuer ON issuer.id = l.issued_by
WHERE l.status IN ('active','overdue');

CREATE VIEW `v_resource_inventory` AS
SELECT
  r.id,
  r.asset_code,
  r.display_code,
  r.name,
  c.category_name,
  loc.location_name,
  loc.building,
  loc.room,
  r.condition_status,
  r.operational_status,
  r.serial_number,
  r.created_at
FROM resources r
JOIN categories c ON c.id = r.category_id
LEFT JOIN locations loc ON loc.id = r.location_id;

-- 12. Initial role and permission data
INSERT INTO roles (role_name, description) VALUES
('Lab Assistant / Lab Technician', 'Manage inventory, inspect resources, issue and receive materials.'),
('Student', 'View own loans, returns and notifications; acknowledge or dispute relevant records.'),
('Teacher / School Staff', 'Borrow eligible items and view own borrowing history.'),
('Head of Department (HOD)', 'View authorized departmental reports; approve only when permission is granted.'),
('Director of Studies (DOS)', 'View authorized class/program summaries and reports.'),
('Director of Discipline (DOD)', 'View permitted incidents and overdue summaries.'),
('School Administrator', 'Manage accounts, roles, reports and audit history; approve corrections when authorized.');

INSERT INTO permissions (permission_key, description) VALUES
('dashboard.view', 'View role-appropriate dashboard'),
('inventory.view', 'View inventory'),
('inventory.create', 'Create resources'),
('inventory.update', 'Update resource details'),
('inventory.retire', 'Retire or write off resources'),
('inspection.create', 'Record resource inspections'),
('loan.create', 'Issue resources'),
('loan.view_own', 'View own loans'),
('loan.view_all', 'View permitted loans'),
('return.create', 'Record returned resources'),
('return.acknowledge_own', 'Acknowledge or dispute own return'),
('correction.request', 'Request a record correction'),
('correction.approve_borrower', 'Approve correction as affected borrower'),
('correction.approve_admin', 'Approve correction as authorized administrator'),
('users.view', 'View user accounts as permitted'),
('users.manage', 'Create and manage accounts'),
('roles.manage', 'Assign roles and permissions'),
('notifications.view_own', 'View own notifications'),
('reports.view', 'View permitted reports'),
('reports.export', 'Export permitted reports'),
('audit.view', 'View audit history'),
('maintenance.manage', 'Manage maintenance records'),
('settings.manage', 'Manage system settings');

-- Default permissions are a starting point only. Review and adjust grants to match school policy.
-- Backend authorization must enforce permissions; hiding UI controls is not sufficient.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON
  (r.role_name = 'Lab Assistant / Lab Technician' AND p.permission_key IN (
    'dashboard.view','inventory.view','inventory.create','inventory.update','inspection.create',
    'loan.create','loan.view_all','return.create','correction.request','users.view',
    'notifications.view_own','reports.view','maintenance.manage'
  ))
  OR
  (r.role_name = 'Student' AND p.permission_key IN (
    'dashboard.view','inventory.view','loan.view_own','return.acknowledge_own',
    'correction.approve_borrower','notifications.view_own'
  ))
  OR
  (r.role_name = 'Teacher / School Staff' AND p.permission_key IN (
    'dashboard.view','inventory.view','loan.view_own','return.acknowledge_own',
    'correction.approve_borrower','notifications.view_own'
  ))
  OR
  (r.role_name = 'Head of Department (HOD)' AND p.permission_key IN (
    'dashboard.view','inventory.view','loan.view_all','notifications.view_own','reports.view'
  ))
  OR
  (r.role_name = 'Director of Studies (DOS)' AND p.permission_key IN (
    'dashboard.view','notifications.view_own','reports.view'
  ))
  OR
  (r.role_name = 'Director of Discipline (DOD)' AND p.permission_key IN (
    'dashboard.view','notifications.view_own','reports.view'
  ))
  OR
  (r.role_name = 'School Administrator' AND p.permission_key IN (
    'dashboard.view','inventory.view','inventory.create','inventory.update','inventory.retire',
    'inspection.create','loan.view_all','users.view','users.manage','roles.manage',
    'correction.approve_admin','notifications.view_own','reports.view','reports.export',
    'audit.view','maintenance.manage','settings.manage'
  ));

-- Suggested initial categories (safe to remove or edit)
INSERT INTO categories (category_name, description) VALUES
('Computer', 'Desktop or laptop computers'),
('Monitor', 'Computer displays'),
('Keyboard', 'Computer keyboards'),
('Mouse', 'Computer mice'),
('Cable', 'Power or data cables'),
('Adapter', 'Power or connectivity adapters'),
('Projector', 'Projectors and presentation equipment'),
('Other', 'Other laboratory resources');

-- IMPORTANT IMPLEMENTATION NOTES:
-- 1. A pre-lending inspection is required by the application before creating a loan.
-- 2. In a transaction, lock/check the resource and reject lending unless operational_status='available'
--    and condition_status is not 'faulty' or 'damaged' under the school's policy.
-- 3. Set resource operational_status='borrowed' when issuing and restore an eligible status on return.
-- 4. Correction application must require both borrower and authorized administrator approvals.
--    Reject/dispute from either party must prevent automatic application.
-- 5. Use database transactions for issue/return; use server-side timestamps and authorization.
-- 6. Do not silently update/delete completed return or audit records; append correction/audit history.
-- 7. Passwords must be securely hashed by the backend; never store plain-text passwords.
