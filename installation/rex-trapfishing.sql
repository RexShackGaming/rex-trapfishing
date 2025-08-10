CREATE TABLE IF NOT EXISTS `rex_trapfishing` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `properties` text NOT NULL,
  `propid` int(11) NOT NULL,
  `proptype` varchar(50) DEFAULT NULL,
  `crayfish` int(11) NOT NULL DEFAULT 0,
  `lobster` int(11) NOT NULL DEFAULT 0,
  `crab` int(11) NOT NULL DEFAULT 0,
  `bluecrab` int(11) NOT NULL DEFAULT 0,
  `bait` int(2) NOT NULL DEFAULT 0,
  `quality` int(3) NOT NULL DEFAULT 100,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;