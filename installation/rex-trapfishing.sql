CREATE TABLE IF NOT EXISTS `rex_trapfishing` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(50)  DEFAULT NULL COMMENT 'Player identifier (e.g. license/citizenid)',
    `owner`      VARCHAR(50)  DEFAULT NULL COMMENT 'Optional display name or secondary owner',
    `properties` TEXT         NOT NULL COMMENT 'JSON/string with coordinates, zone, etc.',
    `propid`     INT(11)      NOT NULL COMMENT 'Unique prop/spawn ID in the world',
    `proptype`   VARCHAR(50)  DEFAULT NULL COMMENT 'Type of trap model',
    `crayfish`   INT(11)      NOT NULL DEFAULT 0,
    `lobster`    INT(11)      NOT NULL DEFAULT 0,
    `crab`       INT(11)      NOT NULL DEFAULT 0,
    `bluecrab`   INT(11)      NOT NULL DEFAULT 0,
    `bait`       TINYINT(2)   NOT NULL DEFAULT 0 COMMENT '0 = no bait, 1 = baited (or amount if you expand later)',
    `quality`    TINYINT(3)   UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Trap durability/health 0-100',
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_propid` (`propid`),
    UNIQUE KEY `uniq_propid` (`propid`)  -- prevents duplicate traps with same propid
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;