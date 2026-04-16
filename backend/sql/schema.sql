CREATE DATABASE IF NOT EXISTS coliz 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;
USE coliz;

CREATE TABLE IF NOT EXISTS users (
    username           VARCHAR(32) NOT NULL DEFAULT 'coliz member',
    user_id            CHAR(36) NOT NULL,
    email              VARCHAR(255) NOT NULL,
    password_hash      VARCHAR(255) NOT NULL,
    device_id          VARCHAR(64),
    avatar_version     INT UNSIGNED NOT NULL DEFAULT 0,
    avatar_updated_at  TIMESTAMP NULL DEFAULT NULL,

    rtk_hash           CHAR(64),
    rtk_pepper_version VARCHAR(16),
    rtk_expired_at     TIMESTAMP,
    rtk_revoked_at     TIMESTAMP DEFAULT NULL,

    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id),
    UNIQUE (email),
    UNIQUE (rtk_hash, rtk_pepper_version),
    INDEX (username)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS friend_requests (
    id          CHAR(36) NOT NULL,
    from_user   CHAR(36) NOT NULL,
    to_user     CHAR(36) NOT NULL,  
    `message`   VARCHAR(64) NOT NULL,
    `status`    TINYINT NOT NULL DEFAULT 0, -- 0: pending, 1: accepted, 2: rejected, 3: canceled
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expired_at  TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    pending_pair_key VARCHAR(73)
        GENERATED ALWAYS AS (
            CASE
                WHEN `status` = 0 THEN CONCAT(LEAST(from_user, to_user), ':', GREATEST(from_user, to_user))
                ELSE NULL
            END
        ) VIRTUAL,

    PRIMARY KEY (id),
    UNIQUE KEY uk_friend_requests_pending_pair (pending_pair_key),
    INDEX idx_from_to_status (from_user, to_user, `status`),
    INDEX idx_to_status_time (to_user, `status`, created_at),
    INDEX idx_from_status_time (from_user, `status`, created_at),
    INDEX idx_expired_at (expired_at),
    CONSTRAINT chk_friend_request_users_distinct CHECK (from_user <> to_user),
    CONSTRAINT chk_friend_request_status CHECK (`status` IN (0, 1, 2, 3)),
    CONSTRAINT fk_friend_request_from_user 
        FOREIGN KEY (from_user) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_friend_request_to_user 
        FOREIGN KEY (to_user) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS friendships (
    user_low       CHAR(36) NOT NULL,
    user_high      CHAR(36) NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_low, user_high),
    INDEX idx_friendship_user_low (user_low),
    INDEX idx_friendship_user_high (user_high),
    CONSTRAINT chk_friendship_order CHECK (user_low < user_high),
    CONSTRAINT fk_friendship_user_low 
        FOREIGN KEY (user_low) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_friendship_user_high 
        FOREIGN KEY (user_high) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `groups` (
    id                 CHAR(36) NOT NULL,
    `name`             VARCHAR(32) NOT NULL,
    owner              CHAR(36) NOT NULL,
    avatar_version     INT UNSIGNED NOT NULL DEFAULT 0,
    avatar_updated_at  TIMESTAMP NULL DEFAULT NULL,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE (owner, name),
    CONSTRAINT fk_group_owner 
        FOREIGN KEY (owner) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS group_members (
    group_id    CHAR(36) NOT NULL,
    user_id     CHAR(36) NOT NULL,
    join_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (group_id, user_id),
    INDEX idx_group_members_user_group (user_id, group_id),
    CONSTRAINT fk_group_member_group 
        FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT fk_group_member_user 
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_friendships_block_delete_shared_group;
DELIMITER //
CREATE TRIGGER trg_friendships_block_delete_shared_group
BEFORE DELETE ON friendships
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM group_members gm_low
        JOIN group_members gm_high
          ON gm_high.group_id = gm_low.group_id
        WHERE gm_low.user_id = OLD.user_low
          AND gm_high.user_id = OLD.user_high
        LIMIT 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'cannot delete friendship while users share a group';
    END IF;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS todos (
    id          CHAR(36) NOT NULL,
    group_id    CHAR(36) NOT NULL,
    `message`   VARCHAR(64) NOT NULL,
    `done`      TINYINT NOT NULL DEFAULT 0,
    created_by  CHAR(36) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    CONSTRAINT fk_todo_group 
        FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT fk_todo_created_by 
        FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_todo_group_member 
        FOREIGN KEY (group_id, created_by) REFERENCES group_members(group_id, user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS expenses (
    id          CHAR(36) NOT NULL,
    group_id    CHAR(36) NOT NULL,
    `name`      VARCHAR(32) NOT NULL,
    category    VARCHAR(32) NOT NULL DEFAULT 'other',
    `amount`    DECIMAL(10, 2) NOT NULL,
    `paid_by`   CHAR(36) NOT NULL,
    is_transaction BOOLEAN NOT NULL DEFAULT FALSE,
    split_method ENUM('equal', 'fixed') NOT NULL DEFAULT 'equal',
    note        VARCHAR(255),
    created_by  CHAR(36) NOT NULL,
    occurred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    INDEX idx_expense_group_created (group_id, created_at),
    INDEX idx_expense_group_paid_by_created (group_id, paid_by, created_at),
    CONSTRAINT fk_expense_group 
        FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT fk_expense_paid_by 
        FOREIGN KEY (paid_by) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_expense_created_by
        FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS expense_splits (
    expense_id        CHAR(36) NOT NULL,
    group_id       CHAR(36) NOT NULL,
    user_id        CHAR(36) NOT NULL,
    `amount`       DECIMAL(10, 2) NOT NULL,
    fixed_amount   DECIMAL(10, 2),
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (expense_id, user_id),
    INDEX idx_expense_split_group_user (group_id, user_id),
    CONSTRAINT fk_expense_split_expense
        FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE,
    CONSTRAINT fk_expense_split_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_expense_splits_validate_before_insert;
DROP TRIGGER IF EXISTS trg_expense_splits_validate_before_update;
DELIMITER //
CREATE TRIGGER trg_expense_splits_validate_before_insert
BEFORE INSERT ON expense_splits
FOR EACH ROW
BEGIN
    DECLARE method VARCHAR(16);

    SELECT e.split_method INTO method
    FROM expenses e
    WHERE e.id = NEW.expense_id
      AND e.group_id = NEW.group_id
    LIMIT 1;

    IF method IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'invalid expense split reference';
    END IF;

    IF method = 'equal' AND NEW.fixed_amount IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'equal split cannot set fixed_amount';
    END IF;

    IF method = 'fixed' AND NEW.fixed_amount IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'fixed split requires fixed_amount';
    END IF;

    IF method = 'fixed' AND NEW.amount <> NEW.fixed_amount THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'fixed split amount mismatch';
    END IF;
END//

CREATE TRIGGER trg_expense_splits_validate_before_update
BEFORE UPDATE ON expense_splits
FOR EACH ROW
BEGIN
    DECLARE method VARCHAR(16);

    SELECT e.split_method INTO method
    FROM expenses e
    WHERE e.id = NEW.expense_id
      AND e.group_id = NEW.group_id
    LIMIT 1;

    IF method IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'invalid expense split reference';
    END IF;

    IF method = 'equal' AND NEW.fixed_amount IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'equal split cannot set fixed_amount';
    END IF;

    IF method = 'fixed' AND NEW.fixed_amount IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'fixed split requires fixed_amount';
    END IF;

    IF method = 'fixed' AND NEW.amount <> NEW.fixed_amount THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'fixed split amount mismatch';
    END IF;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS device_tokens (
    user_id     CHAR(36) NOT NULL,
    token       VARCHAR(200) NOT NULL,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id),
    CONSTRAINT fk_device_token_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS email_dlq (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code_id     CHAR(36) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    scene       VARCHAR(32) NOT NULL,
    attempts    INT NOT NULL DEFAULT 0,
    status      ENUM('failed','sent','dead') NOT NULL DEFAULT 'failed',
    last_error  TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    INDEX idx_email_dlq_status_created (status, created_at),
    INDEX idx_email_dlq_code_id (code_id),
    INDEX idx_email_dlq_email_created (email, created_at)
) ENGINE=InnoDB;
