-- ============================================================================
-- LOGISTOCK S1 — Initialisation de la base de données (VULNÉRABLE)
-- ============================================================================
-- Cette base contient volontairement des mots de passe EN CLAIR
-- pour illustrer la faille en S1 avant l'implémentation du hachage en S2
-- ============================================================================

USE logistock;

-- ==========================================================================
-- Table users — Comptes utilisateurs LogiStock
-- ==========================================================================
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(50) NOT NULL,  -- ⚠️ Stockage EN CLAIR (faille critique)
  email VARCHAR(100) NOT NULL,
  role ENUM('admin', 'employee', 'manager') DEFAULT 'employee',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insertion des utilisateurs avec mots de passe EN CLAIR
INSERT INTO users (username, password, email, role) VALUES
('alice', 'LogiStock2023', 'alice@logistock.fr', 'employee'),
('bob', 'Azerty123', 'bob@logistock.fr', 'employee'),
('daf', 'PdgLogistik!', 'daf@logistock.fr', 'manager'),
('admin', 'admin123', 'admin@logistock.fr', 'admin'),
('charlie', 'Password1', 'charlie@logistock.fr', 'employee');

-- ==========================================================================
-- Table documents — Fichiers sensibles référencés
-- ==========================================================================
CREATE TABLE IF NOT EXISTS documents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  filename VARCHAR(255) NOT NULL,
  category ENUM('rh', 'finance', 'logistique') NOT NULL,
  confidential BOOLEAN DEFAULT FALSE,
  uploaded_by INT,
  upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (uploaded_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Fichiers RH confidentiels (référencés mais stockés sur le NAS)
INSERT INTO documents (filename, category, confidential, uploaded_by) VALUES
('fiches_paie_2023.xlsx', 'rh', TRUE, 3),
('contrats_employes.pdf', 'rh', TRUE, 3),
('bilan_financier_2023.xlsx', 'finance', TRUE, 3),
('inventaire_entrepot.csv', 'logistique', FALSE, 2);

-- ==========================================================================
-- Table logs_acces — Journalisation (quasi inexistante en S1)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS logs_acces (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  action VARCHAR(100),
  ip_address VARCHAR(45),
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Quelques logs pour montrer l'absence de surveillance
INSERT INTO logs_acces (user_id, action, ip_address) VALUES
(1, 'login', '192.168.1.50'),
(2, 'login', '192.168.1.51'),
(3, 'access_file_rh', '192.168.1.52');

-- ==========================================================================
-- Vue pour les statistiques (exercice S1)
-- ==========================================================================
CREATE VIEW stats_users AS
SELECT 
  role,
  COUNT(*) as nombre_utilisateurs,
  GROUP_CONCAT(username) as liste_users
FROM users
GROUP BY role;

-- ==========================================================================
-- Informations de diagnostic
-- ==========================================================================
SELECT 'Base de données LogiStock S1 initialisée' AS Status;
SELECT '⚠️ ATTENTION : Mots de passe stockés EN CLAIR' AS Warning;
SELECT CONCAT('Nombre d\'utilisateurs : ', COUNT(*)) AS Info FROM users;
