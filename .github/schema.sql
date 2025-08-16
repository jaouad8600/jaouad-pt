CREATE TABLE IF NOT EXISTS sessions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date DATE NOT NULL,
  group_name VARCHAR(100) NOT NULL,
  youth_count INT NOT NULL DEFAULT 0,
  kind VARCHAR(20) NOT NULL,             -- 'sport' of 'creatief'
  progress TEXT,
  mood VARCHAR(100),
  interventions TEXT,
  remarks TEXT,
  submitted_by VARCHAR(100) NOT NULL,
  INDEX(date), INDEX(group_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS incidents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date DATE NOT NULL,
  time_at TIME NOT NULL,
  youth_first VARCHAR(100),
  youth_last VARCHAR(100),
  summary TEXT,
  reported TINYINT(1) NOT NULL DEFAULT 0,
  heard TINYINT(1) NOT NULL DEFAULT 0,
  measure VARCHAR(255),
  submitted_by VARCHAR(100) NOT NULL,
  INDEX(date), INDEX(time_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notes (
  for_date DATE PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  special_attention TEXT,
  sport_appointments TEXT,
  group_agreements TEXT,
  submitted_by VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
